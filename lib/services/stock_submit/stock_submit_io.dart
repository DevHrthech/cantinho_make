import 'dart:math';

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/pending_batch_row.dart';
import '../../models/scanned_line.dart';
import '../../models/session_user.dart';
import '../../models/stock_submit_outcome.dart';
import '../local_db.dart';
import '../api_client.dart';
import '../../utils/friendly_error_message.dart';

class StockSubmitService {
  const StockSubmitService();

  static const sendOk = 'Sim';
  static const sendPending = 'Não';

  static const _quotedVenda = '"saidaProduto"';
  static const _quotedInv = 'inventarioproduto';

  String _batchId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${100000 + Random().nextInt(900000)}';

  String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<StockSubmitOutcome> concludeSaida({
    required SessionUser user,
    required List<ScannedLine> lines,
    String? tipoPagamento,
    double? valorRecebido,
    String? desconto,
  }) {
    return _conclude(
      user: user,
      lines: lines,
      quotedTable: _quotedVenda,
      tipoPagamento: tipoPagamento,
      valorRecebido: valorRecebido,
      desconto: desconto,
      enviar: (lote, d, u, dep, ls) => _enviarVenda(
        lote,
        d,
        u,
        dep,
        ls,
        tipoPagamento: tipoPagamento,
        desconto: desconto,
      ),
    );
  }

  Future<StockSubmitOutcome> concludeEntrada({
    required SessionUser user,
    required List<ScannedLine> lines,
  }) {
    return _conclude(
      user: user,
      lines: lines,
      quotedTable: _quotedInv,
      enviar: _enviarInventario,
    );
  }

  Future<StockSubmitOutcome> _conclude({
    required SessionUser user,
    required List<ScannedLine> lines,
    required String quotedTable,
    String? tipoPagamento,
    double? valorRecebido,
    String? desconto,
    required _Enviar enviar,
  }) async {
    final loteId = _batchId();
    final dia = _today();
    final db = (await LocalDb.instance.database) as Database;
    final isVenda = quotedTable == _quotedVenda;

    // Para a venda, calculamos valor_unitario, valor_total (por linha) e valor_total_venda.
    // valor_unitario = preco_venda do produto; valor_total = preco_venda * quantidade.
    // valor_total_venda = soma de valor_total - desconto aplicado (se houver).
    final totalVendaBruto = lines.fold<double>(0, (s, l) => s + l.lineTotal);
    double? valorDescontoNum;
    if (desconto != null && desconto.isNotEmpty) {
      // desconto está no formato "R$20.00" – converter para double.
      final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(desconto);
      if (m != null) {
        valorDescontoNum = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      }
    }
    final valorTotalVenda = valorDescontoNum == null
        ? totalVendaBruto
        : (totalVendaBruto - valorDescontoNum).clamp(0, double.infinity).toDouble();

    await db.transaction((txn) async {
      if (isVenda) {
        for (final line in lines) {
          await txn.rawInsert(
            'INSERT INTO $quotedTable '
            '(lote_id, dia, usuario, codigo_interno, codigo_barras, produto, quantidade, preco_venda, deposito, id_venda, tipo_pagamento, valor_unitario, valor_total, desconto, valor_total_venda, send) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              loteId,
              dia,
              user.displayName,
              line.codigoInterno,
              line.barcode,
              line.name,
              line.quantity,
              line.unitPrice,
              user.deposito,
              null, // id_venda: definido pelo servidor no envio
              tipoPagamento,
              line.unitPrice,
              line.lineTotal,
              desconto,
              valorTotalVenda,
              sendPending,
            ],
          );
        }
      } else {
        for (final line in lines) {
          await txn.rawInsert(
            'INSERT INTO $quotedTable '
            '(lote_id, dia, usuario, codigo_interno, codigo_barras, produto, quantidade, preco_venda, deposito, send) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              loteId,
              dia,
              user.displayName,
              line.codigoInterno,
              line.barcode,
              line.name,
              line.quantity,
              line.unitPrice,
              user.deposito,
              sendPending,
            ],
          );
        }
      }
    });

    return _send(
      db: db,
      quotedTable: quotedTable,
      loteId: loteId,
      remote: () => enviar(loteId, dia, user.displayName, user.deposito, lines),
    );
  }

  /// Envia o lote e marca o resultado nas linhas locais.
  Future<StockSubmitOutcome> _send({
    required Database db,
    required String quotedTable,
    required String loteId,
    required Future<int?> Function() remote,
  }) async {
    try {
      final idVenda = await remote();
      await db.rawUpdate(
        'UPDATE $quotedTable SET send = ?, last_error = ?, http_status = ? WHERE lote_id = ?',
        [sendOk, null, null, loteId],
      );
      if (idVenda != null) {
        await db.rawUpdate(
          'UPDATE $quotedTable SET id_venda = ? WHERE lote_id = ?',
          [idVenda, loteId],
        );
      }
      return StockSubmitOutcome.ok(loteId);
    } on ApiException catch (e) {
      final friendly = friendlyErrorMessage(e);
      await db.rawUpdate(
        'UPDATE $quotedTable SET last_error = ?, http_status = ? WHERE lote_id = ?',
        [friendly, e.statusCode, loteId],
      );
      return StockSubmitOutcome.failed(loteId, friendly, e.statusCode);
    } catch (e) {
      final friendly = friendlyErrorMessage(e);
      await db.rawUpdate(
        'UPDATE $quotedTable SET last_error = ?, http_status = ? WHERE lote_id = ?',
        [friendly, null, loteId],
      );
      return StockSubmitOutcome.failed(loteId, friendly, null);
    }
  }

  List<Map<String, Object?>> _itens(List<ScannedLine> lines) => lines
      .map((l) => <String, Object?>{
            'codigo_interno': l.codigoInterno,
            'codigo_barra': l.barcode,
            'produto': l.name,
            'quantidade': l.quantity,
            'valor_unitario': l.unitPrice,
          })
      .toList();

  /// Retorna o `id_venda` gerado pelo servidor. Reenviar o mesmo lote não duplica.
  Future<int?> _enviarVenda(
    String loteId,
    String dia,
    String usuario,
    String deposito,
    List<ScannedLine> lines, {
    String? tipoPagamento,
    String? desconto,
  }) async {
    final payload = await ApiClient.post('/vendas', {
      'lote_id': loteId,
      'dia': dia,
      'usuario': usuario,
      'deposito': deposito,
      'tipo_pagamento': tipoPagamento,
      'desconto': (desconto == null || desconto.isEmpty) ? null : desconto,
      'itens': _itens(lines),
    });
    final id = payload is Map ? payload['id_venda'] : null;
    return id is int ? id : int.tryParse('$id');
  }

  Future<int?> _enviarInventario(
    String loteId,
    String dia,
    String usuario,
    String deposito,
    List<ScannedLine> lines,
  ) async {
    await ApiClient.post('/inventario', {
      'lote_id': loteId,
      'dia': dia,
      'usuario': usuario,
      'deposito': deposito,
      'itens': _itens(lines),
    });
    return null;
  }

  Future<List<PendingBatchRow>> listPendingVendas() async =>
      _listPending(_quotedVenda);

  Future<List<PendingBatchRow>> listPendingInventarios() async =>
      _listPending(_quotedInv);

  Future<List<PendingBatchRow>> _listPending(String quotedTable) async {
    final db = (await LocalDb.instance.database) as Database;
    final rows = await db.rawQuery(
      '''
      SELECT lote_id,
             MIN(dia) AS dia,
             MIN(usuario) AS usuario,
             MIN(deposito) AS deposito,
             COUNT(*) AS cnt,
             MAX(IFNULL(last_error, '')) AS last_error,
             MAX(IFNULL(http_status, -1)) AS http_status
      FROM $quotedTable
      WHERE send <> ?
      GROUP BY lote_id
      ORDER BY MIN(id) DESC
      ''',
      [sendOk],
    );

    return rows.map((r) {
      final hs = r['http_status'];
      int? httpStatus;
      if (hs is int && hs >= 0) httpStatus = hs;

      final errRaw = r['last_error'] as String?;
      final err = (errRaw == null || errRaw.isEmpty) ? null : errRaw;

      return PendingBatchRow(
        batchId: r['lote_id']! as String,
        dia: r['dia']! as String,
        usuario: r['usuario']! as String,
        deposito: r['deposito']! as String,
        itemCount: (r['cnt'] as num).toInt(),
        lastError: err,
        httpStatus: httpStatus,
      );
    }).toList();
  }

  Future<StockSubmitOutcome> retryBatch({
    required bool isVenda,
    required String batchId,
  }) async {
    final quotedTable = isVenda ? _quotedVenda : _quotedInv;

    final db = (await LocalDb.instance.database) as Database;
    final rows = await db.rawQuery(
      isVenda
          ? 'SELECT dia, usuario, deposito, codigo_interno, codigo_barras, produto, quantidade, preco_venda, id_venda, tipo_pagamento, valor_unitario, valor_total, desconto, valor_total_venda '
              'FROM $quotedTable WHERE lote_id = ? ORDER BY id ASC'
          : 'SELECT dia, usuario, deposito, codigo_interno, codigo_barras, produto, quantidade, preco_venda '
              'FROM $quotedTable WHERE lote_id = ? ORDER BY id ASC',
      [batchId],
    );

    if (rows.isEmpty) {
      return StockSubmitOutcome.failed(batchId, 'Lote não encontrado localmente.', null);
    }

    final lines = rows.map((r) {
      final ci = r['codigo_interno'];
      int? codigoInterno;
      if (ci is int) {
        codigoInterno = ci;
      } else if (ci != null) {
        codigoInterno = int.tryParse(ci.toString());
      }
      return ScannedLine(
        barcode: (r['codigo_barras'] ?? '').toString(),
        name: (r['produto'] ?? '').toString(),
        unitPrice: (r['preco_venda'] as num?)?.toDouble() ?? 0,
        quantity: (r['quantidade'] as num?)?.toInt() ?? 0,
        codigoInterno: codigoInterno,
      );
    }).toList();

    final dia = rows.first['dia']! as String;
    final usuario = rows.first['usuario']! as String;
    final deposito = rows.first['deposito']! as String;

    String? tipoPagamento;
    String? desconto;
    if (isVenda) {
      final tp = rows.first['tipo_pagamento'];
      if (tp != null && tp.toString().trim().isNotEmpty) {
        tipoPagamento = tp.toString();
      }
      final desc = rows.first['desconto'];
      if (desc != null && desc.toString().trim().isNotEmpty) {
        desconto = desc.toString();
      }
    }

    return _send(
      db: db,
      quotedTable: quotedTable,
      loteId: batchId,
      remote: () => isVenda
          ? _enviarVenda(
              batchId,
              dia,
              usuario,
              deposito,
              lines,
              tipoPagamento: tipoPagamento,
              desconto: desconto,
            )
          : _enviarInventario(batchId, dia, usuario, deposito, lines),
    );
  }
}

typedef _Enviar = Future<int?> Function(
  String loteId,
  String dia,
  String usuario,
  String deposito,
  List<ScannedLine> lines,
);
