import 'dart:math';

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/pending_batch_row.dart';
import '../../models/scanned_line.dart';
import '../../models/session_user.dart';
import '../../models/stock_submit_outcome.dart';
import '../local_db.dart';
import '../query_api.dart';
import '../../utils/friendly_error_message.dart';

class StockSubmitService {
  const StockSubmitService();

  static const sendOk = 'Sim';
  static const sendPending = 'Não';

  static const _quotedVenda = '"saidaProduto"';
  static const _quotedInv = 'inventarioproduto';

  /// Próximo `id_venda` no servidor: `MAX(id_venda) + 1` (mínimo 1).
  static Future<int> fetchNextIdVenda() async {
    final payload = await QueryApi.postSql(
      'SELECT COALESCE(MAX(id_venda), 0) AS m FROM VendaProdutos',
    );
    final rows = QueryApi.coerceRows(payload);
    if (rows.isEmpty) return 1;
    final raw = rows.first['m'] ?? rows.first['M'];
    final n = switch (raw) {
      int i => i,
      num x => x.toInt(),
      _ => int.tryParse('$raw') ?? 0,
    };
    return n + 1;
  }

  String _batchId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${100000 + Random().nextInt(900000)}';

  String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<StockSubmitOutcome> concludeSaida({
    required SessionUser user,
    required List<ScannedLine> lines,
    int? idVenda,
    String? tipoPagamento,
    double? valorRecebido,
    String? desconto,
  }) {
    return _conclude(
      user: user,
      lines: lines,
      quotedTable: _quotedVenda,
      idVenda: idVenda,
      tipoPagamento: tipoPagamento,
      valorRecebido: valorRecebido,
      desconto: desconto,
      insertRemoteSql: (d, u, dep, ls, vr, desc) => _insertVendaSql(
        d,
        u,
        dep,
        ls,
        idVenda: idVenda,
        tipoPagamento: tipoPagamento,
        desconto: desc,
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
      insertRemoteSql: (d, u, dep, ls, vr, desc) =>
          _insertInventarioSql(d, u, dep, ls),
    );
  }

  Future<StockSubmitOutcome> _conclude({
    required SessionUser user,
    required List<ScannedLine> lines,
    required String quotedTable,
    int? idVenda,
    String? tipoPagamento,
    double? valorRecebido,
    String? desconto,
    required String Function(
      String dia,
      String usuario,
      String deposito,
      List<ScannedLine> lines,
      double? valorRecebido,
      String? desconto,
    )
        insertRemoteSql,
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
              idVenda,
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

    final sql = insertRemoteSql(dia, user.displayName, user.deposito, lines, valorRecebido, desconto);
    try {
      await QueryApi.postSql(sql);
      await db.rawUpdate(
        'UPDATE $quotedTable SET send = ?, last_error = ?, http_status = ? WHERE lote_id = ?',
        [sendOk, null, null, loteId],
      );
      return StockSubmitOutcome.ok(loteId);
    } on QueryApiException catch (e) {
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

  String _insertVendaSql(
    String dia,
    String usuario,
    String deposito,
    List<ScannedLine> lines, {
    int? idVenda,
    String? tipoPagamento,
    String? desconto,
  }) {
    final d = QueryApi.sqlEscape(dia);
    final u = QueryApi.sqlEscape(usuario);
    final dep = QueryApi.sqlEscape(deposito);
    final idSql = idVenda == null ? 'NULL' : '$idVenda';
    final tpSql =
        tipoPagamento == null ? 'NULL' : "'${QueryApi.sqlEscape(tipoPagamento)}'";
    final descSql =
        desconto == null || desconto.isEmpty ? 'NULL' : "'${QueryApi.sqlEscape(desconto)}'";

    final totalBruto = lines.fold<double>(0, (s, l) => s + l.lineTotal);
    double? valorDescontoNum;
    if (desconto != null && desconto.isNotEmpty) {
      final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(desconto);
      if (m != null) {
        valorDescontoNum = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      }
    }
    final totalVenda = valorDescontoNum == null
        ? totalBruto
        : (totalBruto - valorDescontoNum).clamp(0, double.infinity).toDouble();
    final totalVendaSql = totalVenda.toStringAsFixed(2);

    final tuples = lines
        .map((line) {
          final ci = line.codigoInterno;
          final ciSql = ci == null ? 'NULL' : '$ci';
          final cb = QueryApi.sqlEscape(line.barcode);
          final p = QueryApi.sqlEscape(line.name);
          final vu = line.unitPrice.toStringAsFixed(2);
          final vt = line.lineTotal.toStringAsFixed(2);
          return "('$d','$u',$ciSql,'$cb','$p',${line.quantity},'$dep',"
              "$idSql,$tpSql,$vu,$vt,$descSql,$totalVendaSql)";
        })
        .join(', ');
    return 'INSERT INTO VendaProdutos ('
        '`dia`, `usuario`, `codigo_interno`, `codigo_barra`, `produto`, `quantidade`, `deposito`, '
        '`id_venda`, `tipo_pagamento`, `valor_unitario`, `valor_total`, '
        '`desconto`, `valor_total_venda`'
        ') VALUES $tuples';
  }

  String _insertInventarioSql(
    String dia,
    String usuario,
    String deposito,
    List<ScannedLine> lines,
  ) {
    final d = QueryApi.sqlEscape(dia);
    final u = QueryApi.sqlEscape(usuario);
    final dep = QueryApi.sqlEscape(deposito);
    final tuples = lines
        .map((line) {
          final ci = line.codigoInterno;
          final ciSql = ci == null ? 'NULL' : '$ci';
          final cb = QueryApi.sqlEscape(line.barcode);
          final p = QueryApi.sqlEscape(line.name);
          return "('$d','$u',$ciSql,'$cb','$p',${line.quantity},'$dep')";
        })
        .join(', ');
    return 'INSERT INTO inventarioProduto (`dia`, `usuario`, `codigo_interno`, `codigo_barra`, `produto`, `quantidade`, `deposito`) VALUES $tuples';
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

    int? idVenda;
    String? tipoPagamento;
    String? desconto;
    if (isVenda) {
      final rawId = rows.first['id_venda'];
      if (rawId is int) {
        idVenda = rawId;
      } else if (rawId != null) {
        idVenda = int.tryParse(rawId.toString());
      }
      final tp = rows.first['tipo_pagamento'];
      if (tp != null && tp.toString().trim().isNotEmpty) {
        tipoPagamento = tp.toString();
      }
      final desc = rows.first['desconto'];
      if (desc != null && desc.toString().trim().isNotEmpty) {
        desconto = desc.toString();
      }
      // Vendas da feira gravadas offline vêm sem id; demais vendas seguem com NULL no INSERT.
      if (idVenda == null && tipoPagamento != null) {
        try {
          idVenda = await fetchNextIdVenda();
        } catch (e) {
          final friendly = friendlyErrorMessage(e);
          await db.rawUpdate(
            'UPDATE $quotedTable SET last_error = ?, http_status = ? WHERE lote_id = ?',
            [friendly, null, batchId],
          );
          return StockSubmitOutcome.failed(batchId, friendly, null);
        }
      }
    }

    final sql = isVenda
        ? _insertVendaSql(
            dia,
            usuario,
            deposito,
            lines,
            idVenda: idVenda,
            tipoPagamento: tipoPagamento,
            desconto: desconto,
          )
        : _insertInventarioSql(dia, usuario, deposito, lines);

    try {
      await QueryApi.postSql(sql);
      await db.rawUpdate(
        'UPDATE $quotedTable SET send = ?, last_error = ?, http_status = ? WHERE lote_id = ?',
        [sendOk, null, null, batchId],
      );
      return StockSubmitOutcome.ok(batchId);
    } on QueryApiException catch (e) {
      final friendly = friendlyErrorMessage(e);
      await db.rawUpdate(
        'UPDATE $quotedTable SET last_error = ?, http_status = ? WHERE lote_id = ?',
        [friendly, e.statusCode, batchId],
      );
      return StockSubmitOutcome.failed(batchId, friendly, e.statusCode);
    } catch (e) {
      final friendly = friendlyErrorMessage(e);
      await db.rawUpdate(
        'UPDATE $quotedTable SET last_error = ?, http_status = ? WHERE lote_id = ?',
        [friendly, null, batchId],
      );
      return StockSubmitOutcome.failed(batchId, friendly, null);
    }
  }
}
