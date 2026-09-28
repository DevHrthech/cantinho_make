import '../models/app_user.dart';
import 'api_client.dart';

abstract final class UsersApi {
  static AppUser _fromRow(Map<String, dynamic> r) => AppUser(
        idUsuario: int.tryParse('${r['id_usuario']}') ?? 0,
        nome: (r['nome'] ?? '').toString(),
        email: (r['email'] ?? '').toString(),
        telefone: (r['telefone'] ?? '').toString(),
        cpf: (r['cpf'] ?? '').toString(),
        cidade: (r['cidade'] ?? '').toString(),
        deposito: (r['deposito'] ?? '').toString(),
        perfil: (r['perfil'] ?? '').toString(),
        status: (r['status'] ?? '').toString(),
      );

  static Future<List<AppUser>> list() async {
    final payload = await ApiClient.get('/usuarios');
    return ApiClient.rows(payload).map(_fromRow).where((u) => u.idUsuario != 0).toList();
  }

  static Future<AppUser> getById(int idUsuario) async {
    final payload = await ApiClient.get('/usuarios/$idUsuario');
    return _fromRow(ApiClient.item(payload));
  }

  static Future<void> create({
    required String nome,
    required String email,
    required String senha,
    required String telefone,
    required String cpf,
    required String cidade,
    required String deposito,
    required String perfil,
    required String status,
  }) async {
    await ApiClient.post('/usuarios', {
      'nome': nome,
      'email': email,
      'senha': senha,
      'telefone': telefone,
      'cpf': cpf,
      'cidade': cidade,
      'deposito': deposito,
      'perfil': perfil,
      'status': status,
    });
  }

  static Future<void> update({
    required int idUsuario,
    required String nome,
    required String email,
    String? senha,
    required String telefone,
    required String cpf,
    required String cidade,
    required String deposito,
    required String perfil,
    required String status,
  }) async {
    await ApiClient.put('/usuarios/$idUsuario', {
      'nome': nome,
      'email': email,
      if (senha != null && senha.trim().isNotEmpty) 'senha': senha,
      'telefone': telefone,
      'cpf': cpf,
      'cidade': cidade,
      'deposito': deposito,
      'perfil': perfil,
      'status': status,
    });
  }
}
