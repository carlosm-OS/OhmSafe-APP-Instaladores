enum Environment { development, staging, production }

class EnvConfig {
  final Environment environment;
  final String apiBaseUrl;
  final String hubspotApiKey;
  final int connectTimeoutMs;

  const EnvConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.hubspotApiKey,
    this.connectTimeoutMs = 15000,
  });

  bool get isDevelopment => environment == Environment.development;
  bool get isStaging => environment == Environment.staging;
  bool get isProduction => environment == Environment.production;
}
