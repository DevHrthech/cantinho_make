import 'package:sqflite/sqflite.dart';

import '../local_db.dart';
import '../query_api.dart';

class UsersSyncService {
  const UsersSyncService();

  static const String _sql =
      'SELECT nome, email, senha, telefone, cpf, cidade, deposito, perfil, status FROM usuarios';

  Future<int> syncUsuarios() async {
    final payload = await QueryApi.postSql(_sql);
    final rows = QueryApi.coerceRows(payload);

    final db = (await LocalDb.instance.database) as Database;

    return db.transaction<int>((txn) async {
      await txn.delete('usuarios');

      final batch = txn.batch();
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        batch.insert(
          'usuarios',
          <String, Object?>{
            // tabela local tem id_usuario NOT NULL; geramos um id estável por ordem.
            'id_usuario': i + 1,
            'nome': (r['nome'] ?? '').toString(),
            'email': (r['email'] ?? '').toString(),
            'senha': (r['senha'] ?? '').toString(),
            'telefone': (r['telefone'] ?? '').toString(),
            'cpf': (r['cpf'] ?? '').toString(),
            'cidade': (r['cidade'] ?? '').toString(),
            'deposito': (r['deposito'] ?? '').toString(),
            'perfil': (r['perfil'] ?? '').toString(),
            'status': (r['status'] ?? '').toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      return rows.length;
    });
  }
}

