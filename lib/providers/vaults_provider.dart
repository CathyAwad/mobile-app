import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../core/api/api_client.dart';

class VaultConnection {
  final String id;
  final String name;
  final String provider;
  final bool enabled;

  VaultConnection({
    required this.id,
    required this.name,
    required this.provider,
    required this.enabled,
  });

  factory VaultConnection.fromJson(Map<String, dynamic> json) {
    return VaultConnection(
      id: json['id'] as String,
      name: json['name'] as String,
      provider: json['provider'] as String,
      enabled: json['enabled'] as bool,
    );
  }
}

class VaultItem {
  final String id;
  final String name;
  final String? username;

  VaultItem({
    required this.id,
    required this.name,
    this.username,
  });

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String?,
    );
  }
}

final vaultsProvider = FutureProvider<List<VaultConnection>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/vaults');
  final List<dynamic> data = response.data;
  return data.map((json) => VaultConnection.fromJson(json)).toList();
});

final vaultItemsProvider = FutureProvider.family<List<VaultItem>, ({String vaultId, String query})>((ref, arg) async {
  if (arg.vaultId.isEmpty) return [];
  
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/vaults/${arg.vaultId}/items', queryParameters: {'q': arg.query});
  final List<dynamic> data = response.data;
  return data.map((json) => VaultItem.fromJson(json)).toList();
});
