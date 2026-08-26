import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDb {
  LocalDb._();

  static final LocalDb instance = LocalDb._();

  static const String _assetPath = 'assets/db/espmeu.db';
  static const String _dbFileName = 'espmeu.db';

  static const _createSaidaProduto = '''
CREATE TABLE "saidaProduto" (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  lote_id TEXT NOT NULL,
  dia TEXT NOT NULL,
  usuario TEXT NOT NULL,
  codigo_interno INTEGER,
  codigo_barras TEXT NOT NULL,
  produto TEXT NOT NULL,
  quantidade INTEGER NOT NULL,
  preco_venda REAL NOT NULL,
  deposito TEXT NOT NULL,
  id_venda INTEGER,
  tipo_pagamento TEXT,
  valor_unitario REAL,
  valor_total REAL,
  desconto TEXT,
  valor_total_venda REAL,
  valor_recebido REAL,
  send TEXT NOT NULL DEFAULT 'Não',
  last_error TEXT,
  http_status INTEGER
)
''';

  static const _createInventarioProduto = '''
CREATE TABLE inventarioproduto (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  lote_id TEXT NOT NULL,
  dia TEXT NOT NULL,
  usuario TEXT NOT NULL,
  codigo_interno INTEGER,
  codigo_barras TEXT NOT NULL,
  produto TEXT NOT NULL,
  quantidade INTEGER NOT NULL,
  preco_venda REAL NOT NULL,
  deposito TEXT NOT NULL,
  send TEXT NOT NULL DEFAULT 'Não',
  last_error TEXT,
  http_status INTEGER
)
''';

  Database? _db;

  Future<Database> get database async {
    final db = _db;
    if (db != null) return db;
    return init();
  }

  Future<Database> init() async {
    if (_db != null) return _db!;

    final dbDir = await getDatabasesPath();
    final targetPath = p.join(dbDir, _dbFileName);

    await _ensurePrebuiltDbCopiedIfNeeded(targetPath);

    final opened = await openDatabase(
      targetPath,
      readOnly: false,
      onOpen: (db) async => _ensureOutboundTables(db),
    );
    _db = opened;
    return opened;
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    await db?.close();
  }

  Future<void> _ensurePrebuiltDbCopiedIfNeeded(String targetPath) async {
    final targetFile = File(targetPath);
    if (await targetFile.exists()) return;

    final data = await rootBundle.load(_assetPath);
    final bytes = data.buffer.asUint8List();

    const magic = <int>[
      0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66,
      0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00,
    ];
    final isSQLite = bytes.length >= magic.length &&
        List<int>.generate(magic.length, (i) => i)
            .every((i) => bytes[i] == magic[i]);

    if (!isSQLite) {
      throw StateError(
        'Asset database "$_assetPath" não é um SQLite válido. '
        'Verifique o arquivo assets/db/espmeu.db (precisa ser um .db SQLite real).',
      );
    }

    await Directory(p.dirname(targetPath)).create(recursive: true);
    await targetFile.writeAsBytes(bytes, flush: true);
  }

  Future<void> _ensureOutboundTables(Database db) async {
    await _migrateOutboundTable(
      db,
      tableSqlName: '"saidaProduto"',
      pragmaName: '"saidaProduto"',
      legacySuffix: 'saidaProduto_legacy',
      createSql: _createSaidaProduto,
    );
    await _migrateOutboundTable(
      db,
      tableSqlName: 'inventarioproduto',
      pragmaName: 'inventarioproduto',
      legacySuffix: 'inventarioproduto_legacy',
      createSql: _createInventarioProduto,
    );
  }

  Future<void> _migrateOutboundTable(
    Database db, {
    required String tableSqlName,
    required String pragmaName,
    required String legacySuffix,
    required String createSql,
  }) async {
    final info = await db.rawQuery('PRAGMA table_info($pragmaName)');
    if (info.isEmpty) {
      await db.execute(createSql);
      return;
    }

    final names = info.map((e) => e['name'] as String).toSet();
    final hasBatchId = names.contains('batch_id');
    final hasLoteId = names.contains('lote_id');

    final idRow = info.cast<Map<String, Object?>>().where((e) => e['name'] == 'id').toList();
    final idType =
        idRow.isEmpty ? '' : (idRow.first['type'] as String? ?? '').toUpperCase();
    final idIsText = idType.contains('TEXT') || idType.contains('CHAR');
    final idIsInteger = idType.contains('INT');

    final looksLikeCurrent = hasLoteId &&
        idIsInteger &&
        !idIsText &&
        !hasBatchId &&
        names.contains('dia') &&
        names.contains('usuario');

    if (looksLikeCurrent) {
      if (!names.contains('last_error')) {
        await db.execute('ALTER TABLE $tableSqlName ADD COLUMN last_error TEXT');
      }
      if (!names.contains('http_status')) {
        await db.execute('ALTER TABLE $tableSqlName ADD COLUMN http_status INTEGER');
      }
      if (pragmaName == '"saidaProduto"') {
        if (!names.contains('id_venda')) {
          await db.execute('ALTER TABLE $tableSqlName ADD COLUMN id_venda INTEGER');
        }
        if (!names.contains('tipo_pagamento')) {
          await db.execute('ALTER TABLE $tableSqlName ADD COLUMN tipo_pagamento TEXT');
        }
        if (!names.contains('valor_unitario')) {
          await db.execute('ALTER TABLE $tableSqlName ADD COLUMN valor_unitario REAL');
        }
        if (!names.contains('valor_total')) {
          await db.execute('ALTER TABLE $tableSqlName ADD COLUMN valor_total REAL');
        }
        if (!names.contains('desconto')) {
          await db.execute('ALTER TABLE $tableSqlName ADD COLUMN desconto TEXT');
        }
        if (!names.contains('valor_total_venda')) {
          await db.execute('ALTER TABLE $tableSqlName ADD COLUMN valor_total_venda REAL');
        }
        if (!names.contains('valor_recebido')) {
          await db.execute('ALTER TABLE $tableSqlName ADD COLUMN valor_recebido REAL');
        }
      }
      return;
    }

    await db.execute('ALTER TABLE $tableSqlName RENAME TO $legacySuffix');

    await db.execute(createSql);

    final loteExpr = _loteIdSqlExpr(names: names, idIsText: idIsText, hasBatchId: hasBatchId);

    await _copyLegacyOutbound(
      db,
      destTable: tableSqlName,
      legacyTable: legacySuffix,
      loteIdExpr: loteExpr,
    );

    await db.execute('DROP TABLE $legacySuffix');
  }

  /// Expressão SQL que define o identificador do lote na tabela antiga.
  static String _loteIdSqlExpr({
    required Set<String> names,
    required bool idIsText,
    required bool hasBatchId,
  }) {
    if (hasBatchId) return 'batch_id';
    if (idIsText && names.contains('id')) return 'id';
    return 'CAST(rowid AS TEXT)';
  }

  Future<void> _copyLegacyOutbound(
    Database db, {
    required String destTable,
    required String legacyTable,
    required String loteIdExpr,
  }) async {
    final cols = await db.rawQuery('PRAGMA table_info($legacyTable)');
    final names = cols.map((e) => e['name'] as String).toSet();

    String colOrNull(String n) => names.contains(n) ? n : 'NULL';

    final sendCol = names.contains('send') ? 'send' : "'Não'";

    final isSaida = destTable == '"saidaProduto"';
    final extraCols =
        isSaida ? ', id_venda, tipo_pagamento, valor_unitario, valor_total, desconto, valor_total_venda, valor_recebido' : '';
    final extraSelect = isSaida ? ', NULL, NULL, NULL, NULL, NULL, NULL, NULL' : '';

    await db.execute('''
INSERT INTO $destTable (
  lote_id, dia, usuario, codigo_interno, codigo_barras, produto,
  quantidade, preco_venda, deposito$extraCols, send, last_error, http_status
)
SELECT
  $loteIdExpr,
  ${colOrNull('dia')},
  ${colOrNull('usuario')},
  ${colOrNull('codigo_interno')},
  ${colOrNull('codigo_barras')},
  ${colOrNull('produto')},
  ${colOrNull('quantidade')},
  ${colOrNull('preco_venda')},
  ${colOrNull('deposito')}$extraSelect,
  COALESCE($sendCol, 'Não'),
  ${colOrNull('last_error')},
  ${colOrNull('http_status')}
FROM $legacyTable
''');
  }
}
