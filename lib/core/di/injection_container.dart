import '../config/env_config.dart';
import '../network/dio_client.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/data/datasources/home_remote_data_source.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/ordenes/data/datasources/ordenes_data_source.dart';
import '../../features/ordenes/data/datasources/ordenes_mock_data_source.dart';
import '../../features/ordenes/data/datasources/ordenes_remote_data_source.dart';
import '../../features/ordenes/data/repositories/ordenes_repository_impl.dart';
import '../../features/ordenes/domain/repositories/ordenes_repository.dart';
import '../../features/auth/data/datasources/auth_data_source.dart';
import '../../features/auth/data/datasources/auth_mock_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/perfil/data/datasources/perfil_data_source.dart';
import '../../features/perfil/data/datasources/perfil_mock_data_source.dart';
import '../../features/perfil/data/datasources/perfil_remote_data_source.dart';
import '../../features/perfil/data/repositories/perfil_repository_impl.dart';
import '../../features/perfil/domain/repositories/perfil_repository.dart';

class sl {
  static final Map<Type, dynamic> _instances = {};
  static final Map<Type, dynamic Function()> _factories = {};

  static void registerSingleton<T>(T instance) {
    _instances[T] = instance;
  }

  static void registerLazySingleton<T>(T Function() factory) {
    _factories[T] = factory;
  }

  static T get<T>() {
    if (_instances.containsKey(T)) {
      return _instances[T] as T;
    }
    if (_factories.containsKey(T)) {
      final instance = _factories[T]!();
      _instances[T] = instance;
      return instance as T;
    }
    throw Exception("No dependency registered for type: $T");
  }

  static Future<void> init(EnvConfig envConfig) async {
    // Core Dependencies
    registerSingleton<EnvConfig>(envConfig);
    registerLazySingleton<DioClient>(() => DioClient(envConfig: get<EnvConfig>()));

    // Features dependencies
    registerLazySingleton<HomeRemoteDataSource>(
      () => HomeRemoteDataSourceImpl(dioClient: get<DioClient>()),
    );
    registerLazySingleton<HomeRepository>(
      () => HomeRepositoryImpl(remoteDataSource: get<HomeRemoteDataSource>()),
    );

    // Órdenes de servicio: Mock o Api según el flag useMock (contract-first).
    registerLazySingleton<OrdenesDataSource>(
      () => envConfig.useMock
          ? OrdenesMockDataSource()
          : OrdenesRemoteDataSource(dioClient: get<DioClient>()),
    );
    registerLazySingleton<OrdenesRepository>(
      () => OrdenesRepositoryImpl(dataSource: get<OrdenesDataSource>()),
    );

    // Auth: login del instalador (contra Odoo vía API); Mock o Api por flag.
    registerLazySingleton<AuthDataSource>(
      () => envConfig.useMock
          ? AuthMockDataSource()
          : AuthRemoteDataSource(dioClient: get<DioClient>()),
    );
    registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(dataSource: get<AuthDataSource>()),
    );

    // Perfil del instalador (onboarding: datos, constancia, contraseña).
    registerLazySingleton<PerfilDataSource>(
      () => envConfig.useMock
          ? PerfilMockDataSource()
          : PerfilRemoteDataSource(dioClient: get<DioClient>()),
    );
    registerLazySingleton<PerfilRepository>(
      () => PerfilRepositoryImpl(dataSource: get<PerfilDataSource>()),
    );
  }
}
