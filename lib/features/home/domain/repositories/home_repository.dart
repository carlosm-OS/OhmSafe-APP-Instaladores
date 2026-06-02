import '../../../../core/network/result.dart';
import '../entities/installer.dart';

abstract class HomeRepository {
  Future<Result<Installer>> getInstallerInfo(String id);
  Future<Result<Map<String, int>>> getSyncCounts();
}
