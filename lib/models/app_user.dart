class AppUser {
  const AppUser({
    required this.idUsuario,
    required this.nome,
    required this.email,
    required this.telefone,
    required this.cpf,
    required this.cidade,
    required this.deposito,
    required this.perfil,
    required this.status,
  });

  final int idUsuario;
  final String nome;
  final String email;
  final String telefone;
  final String cpf;
  final String cidade;
  /// Pode vir como id ou nome dependendo do backend.
  final String deposito;
  /// Administrador | Usuario
  final String perfil;
  /// Ativo | Inativo
  final String status;

  bool get isAtivo => status.trim().toLowerCase() == 'ativo';
}

