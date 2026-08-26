/// Mensagens curtas em português para o usuário explicar o problema ao suporte.
String friendlyErrorMessage(Object? error) {
  if (error == null) return 'Algo deu errado. Tente de novo.';
  return friendlyErrorMessageFromString(error.toString());
}

String friendlyErrorMessageFromString(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return 'Não foi possível conectar. Verifique a internet e tente de novo.';
  }

  final lower = trimmed.toLowerCase();
  final looksTechnical = lower.contains('exception') ||
      lower.contains('errno') ||
      lower.contains('socket') ||
      lower.contains('failed host') ||
      lower.contains('clientexception') ||
      lower.contains('httpexception') ||
      trimmed.length > 220;

  if (!looksTechnical) return trimmed;

  if (lower.contains('failed host lookup') ||
      lower.contains('no address associated with hostname') ||
      lower.contains('network is unreachable') ||
      lower.contains('name not resolved')) {
    return 'Sem internet ou o Wi‑Fi/dados não encontraram o servidor. Ative a conexão e tente de novo.';
  }

  if (lower.contains('connection refused')) {
    return 'O servidor não aceitou a conexão. Tente mais tarde.';
  }

  if (lower.contains('timed out') || lower.contains('timeout')) {
    return 'A internet ficou lenta ou caiu. Espere um pouco e tente de novo.';
  }

  if (lower.contains('certificate') ||
      lower.contains('handshake') ||
      lower.contains('ssl') && lower.contains('error')) {
    return 'Problema de segurança na rede. Tente outra rede ou atualize o sistema.';
  }

  if (lower.contains('403') || lower.contains('401')) {
    return 'Acesso negado. Saia e entre de novo no app.';
  }

  if (lower.contains('404')) {
    return 'Serviço não encontrado. Avise o suporte.';
  }

  if (lower.contains('500') ||
      lower.contains('502') ||
      lower.contains('503') ||
      lower.contains('504')) {
    return 'Servidor ocupado ou em manutenção. Tente mais tarde.';
  }

  return 'Não foi possível conectar. Verifique a internet e tente de novo.';
}
