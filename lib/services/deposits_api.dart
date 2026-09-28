import '../models/deposito.dart';
import 'api_client.dart';

abstract final class DepositsApi {
  static Deposito _fromRow(Map<String, dynamic> r) => Deposito(
        id: int.tryParse('${r['id']}') ?? 0,
        nome: (r['nome'] ?? '').toString(),
        status: (r['status'] ?? '').toString(),
      );

  static Future<List<Deposito>> list() async {
    final payload = await ApiClient.get('/depositos');
    return ApiClient.rows(payload).map(_fromRow).where((d) => d.id != 0).toList();
  }

  static Future<List<Deposito>> listActive() async {
    final all = await list();
    return all.where((d) => d.isAtivo).toList();
  }

  static Future<Deposito> getById(int id) async {
    final payload = await ApiClient.get('/depositos/$id');
    return _fromRow(ApiClient.item(payload));
  }

  static Future<void> create({required String nome, required String status}) async {
    await ApiClient.post('/depositos', {'nome': nome, 'status': status});
  }

  static Future<void> update({required int id, required String nome, required String status}) async {
    await ApiClient.put('/depositos/$id', {'nome': nome, 'status': status});
  }
}
