import '../models/app_user.dart';
import 'query_api.dart';

abstract final class UsersApi {
  static Future<List<AppUser>> list() async {
    const sql =
        'SELECT id_usuario, nome, email, telefone, cpf, cidade, deposito, perfil, status FROM usuarios';
    final payload = await QueryApi.postSql(sql);
    final rows = QueryApi.coerceRows(payload);

    return rows.map((r) {
      final id = int.tryParse('${r['id_usuario']}') ?? 0;
      return AppUser(
        idUsuario: id,
        nome: (r['nome'] ?? '').toString(),
        email: (r['email'] ?? '').toString(),
        telefone: (r['telefone'] ?? '').toString(),
        cpf: (r['cpf'] ?? '').toString(),
        cidade: (r['cidade'] ?? '').toString(),
        deposito: (r['deposito'] ?? '').toString(),
        perfil: (r['perfil'] ?? '').toString(),
        status: (r['status'] ?? '').toString(),
      );
    }).where((u) => u.idUsuario != 0).toList();
  }

  static Future<AppUser> getById(int idUsuario) async {
    final payload = await QueryApi.postSql(
      'SELECT nome, email, telefone, cpf, cidade, deposito, perfil, status FROM usuarios WHERE id_usuario = $idUsuario',
    );
    final rows = QueryApi.coerceRows(payload);
    if (rows.isNotEmpty) {
      final r = rows.first;
      return AppUser(
        idUsuario: idUsuario,
        nome: (r['nome'] ?? '').toString(),
        email: (r['email'] ?? '').toString(),
        telefone: (r['telefone'] ?? '').toString(),
        cpf: (r['cpf'] ?? '').toString(),
        cidade: (r['cidade'] ?? '').toString(),
        deposito: (r['deposito'] ?? '').toString(),
        perfil: (r['perfil'] ?? '').toString(),
        status: (r['status'] ?? '').toString(),
      );
    }

    if (payload is Map) {
      return AppUser(
        idUsuario: idUsuario,
        nome: (payload['nome'] ?? '').toString(),
        email: (payload['email'] ?? '').toString(),
        telefone: (payload['telefone'] ?? '').toString(),
        cpf: (payload['cpf'] ?? '').toString(),
        cidade: (payload['cidade'] ?? '').toString(),
        deposito: (payload['deposito'] ?? '').toString(),
        perfil: (payload['perfil'] ?? '').toString(),
        status: (payload['status'] ?? '').toString(),
      );
    }

    throw QueryApiException('Usuário não encontrado');
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
    final n = QueryApi.sqlEscape(nome);
    final e = QueryApi.sqlEscape(email);
    final s = QueryApi.sqlEscape(senha);
    final t = QueryApi.sqlEscape(telefone);
    final c = QueryApi.sqlEscape(cpf);
    final ci = QueryApi.sqlEscape(cidade);
    final d = QueryApi.sqlEscape(deposito);
    final p = QueryApi.sqlEscape(perfil);
    final st = QueryApi.sqlEscape(status);

    final sql =
        "INSERT INTO `usuarios`(`id_usuario`, `nome`, `email`, `senha`, `telefone`, `cpf`, `cidade`, `deposito`, `perfil`, `status`) "
        "VALUES (NULL,'$n','$e','$s','$t','$c','$ci','$d','$p','$st')";
    await QueryApi.postSql(sql);
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
    final n = QueryApi.sqlEscape(nome);
    final e = QueryApi.sqlEscape(email);
    final t = QueryApi.sqlEscape(telefone);
    final c = QueryApi.sqlEscape(cpf);
    final ci = QueryApi.sqlEscape(cidade);
    final d = QueryApi.sqlEscape(deposito);
    final p = QueryApi.sqlEscape(perfil);
    final st = QueryApi.sqlEscape(status);

    final sets = <String>[
      "`nome`='$n'",
      "`email`='$e'",
      "`telefone`='$t'",
      "`cpf`='$c'",
      "`cidade`='$ci'",
      "`deposito`='$d'",
      "`perfil`='$p'",
      "`status`='$st'",
    ];
    if (senha != null && senha.trim().isNotEmpty) {
      final s = QueryApi.sqlEscape(senha);
      sets.insert(2, "`senha`='$s'");
    }

    final sql =
        "UPDATE `usuarios` SET ${sets.join(',')} WHERE id_usuario = $idUsuario";
    await QueryApi.postSql(sql);
  }
}

