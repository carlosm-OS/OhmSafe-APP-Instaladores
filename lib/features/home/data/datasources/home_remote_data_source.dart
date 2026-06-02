import '../../../../core/network/dio_client.dart';
import '../models/installer_model.dart';

abstract class HomeRemoteDataSource {
  Future<InstallerModel> getInstallerInfo(String id);
  Future<Map<String, int>> getSyncCounts();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final DioClient dioClient;

  HomeRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<InstallerModel> getInstallerInfo(String id) async {
    final response = await dioClient.get("/installer/$id");
    return InstallerModel.fromJson(response);
  }

  @override
  Future<Map<String, int>> getSyncCounts() async {
    final response = await dioClient.get("/hubspot/counts");
    return Map<String, int>.from(response);
  }
}
