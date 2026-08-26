enum UserRole {
  admin,
  /// Operador de filial: apenas saída e entrada de produtos.
  standard,
  /// Mesmo escopo do usuário padrão, com campos extras na venda (ex.: forma de pagamento).
  feira,
}

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.admin => 'Administrador',
        UserRole.standard => 'Usuário padrão',
        UserRole.feira => 'Feira',
      };
}
