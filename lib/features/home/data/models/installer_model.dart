import '../../domain/entities/installer.dart';

class InstallerModel extends Installer {
  const InstallerModel({
    required super.name,
    required super.id,
    required super.role,
    required super.avatar,
  });

  factory InstallerModel.fromJson(Map<String, dynamic> json) {
    return InstallerModel(
      name: json['name'] as String? ?? 'Desconocido',
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? '',
      avatar: json['avatar'] as String? ?? 'avatar.png',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'role': role,
      'avatar': avatar,
    };
  }
}
