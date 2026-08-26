import '../models/deposito.dart';
import 'query_api.dart';

abstract final class DepositsApi {
  static Future<List<Deposito>> list() async {
    const sql = 'SELECT id, nome, status from depositos';
    final payload = await QueryApi.postSql(sql);
    final rows = QueryApi.coerceRows(payload);

    return rows.map((r) {
      final id = int.tryParse('${r['id']}') ?? 0;
      final nome = (r['nome'] ?? '').toString();
      final status = (r['status'] ?? '').toString();
      return Deposito(id: id, nome: nome, status: status);
    }).where((d) => d.id != 0).toList();
  }

  static Future<List<Deposito>> listActive() async {
    final all = await list();
    return all.where((d) => d.isAtivo).toList();
  }

  static Future<Deposito> getById(int id) async {
    final payload = await QueryApi.postSql(
      'SELECT nome, status FROM depositos WHERE id = $id',
    );
    final rows = QueryApi.coerceRows(payload);
    if (rows.isNotEmpty) {
      final r = rows.first;
      return Deposito(
        id: id,
        nome: (r['nome'] ?? '').toString(),
        status: (r['status'] ?? '').toString(),
      );
    }

    if (payload is Map) {
      return Deposito(
        id: id,
        nome: (payload['nome'] ?? '').toString(),
        status: (payload['status'] ?? '').toString(),
      );
    }

    throw QueryApiException('Depósito não encontrado');
  }

  static Future<void> create({required String nome, required String status}) async {
    final n = QueryApi.sqlEscape(nome);
    final s = QueryApi.sqlEscape(status);
    final sql =
        "INSERT INTO `depositos`(`id`, `nome`, `status`) VALUES (NULL,'$n','$s')";
    await QueryApi.postSql(sql);
  }

  static Future<void> update({required int id, required String nome, required String status}) async {
    final n = QueryApi.sqlEscape(nome);
    final s = QueryApi.sqlEscape(status);
    final sql = "UPDATE depositos SET nome = '$n', status = '$s' where id = $id";
    await QueryApi.postSql(sql);
  }
}
