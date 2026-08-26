/// Implementação "vazia" usada no Web (e outras plataformas sem dart:io).
/// No Web, o app deve operar 100% via API.
class LocalDb {
  LocalDb._();

  static final LocalDb instance = LocalDb._();

  Future<void> init() async {
    // Intencionalmente não faz nada no Web.
  }

  Future<Object> get database =>
      throw UnsupportedError('SQLite local não é suportado no Web.');

  Future<void> close() async {}
}

