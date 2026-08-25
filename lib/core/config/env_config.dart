enum Environment { development, staging, production }

class EnvConfig {
  final Environment environment;
  final String apiBaseUrl;
  final String hubspotApiKey;
  final int connectTimeoutMs;

  /// Cuando es true, los repositorios usan datasources Mock (sin backend).
  /// Cambiar a false enchufa el backend real (mismo contrato). Es el switch
  /// central del enfoque contract-first: desarrollar contra mock y luego
  /// apuntar al API sin tocar la UI.
  final bool useMock;

  const EnvConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.hubspotApiKey,
    this.connectTimeoutMs = 15000,
    this.useMock = true,
  });

  bool get isDevelopment => environment == Environment.development;
  bool get isStaging => environment == Environment.staging;
  bool get isProduction => environment == Environment.production;
}
