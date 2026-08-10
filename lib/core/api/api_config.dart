/// Configuração da API pública do backend Next.js.
///
/// A base pode ser sobrescrita em build/run com:
///   flutter run --dart-define=API_BASE_URL=https://jurandir.app.br/api/public
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Dev: backend Next.js local. No emulador Android use 10.0.2.2 no lugar de localhost.
    defaultValue: 'http://localhost:3000/api/public',
  );
}
