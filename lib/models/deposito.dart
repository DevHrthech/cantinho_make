class Deposito {
  const Deposito({required this.id, required this.nome, required this.status});

  final int id;
  final String nome;
  final String status; // Ativo | Inativo

  bool get isAtivo => status.toLowerCase() == 'ativo';
}
