import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../core/api/api_client.dart';
import '../features/chat/domain/space_model.dart';

final navigationProvider = FutureProvider<NavigationModel>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/navigation');
  return NavigationModel.fromJson(response.data);
});

final spacesProvider = FutureProvider<List<SpaceModel>>((ref) async {
  final nav = await ref.watch(navigationProvider.future);
  return nav.spaces;
});

final createSpaceProvider = Provider<Future<void> Function(String)>((ref) {
  return (name) async {
    final dio = ref.read(dioProvider);
    await dio.post('/spaces', data: {'name': name});
    ref.invalidate(spacesProvider);
    ref.invalidate(navigationProvider);
  };
});

final deleteSpaceProvider = Provider<Future<void> Function(String)>((ref) {
  return (spaceId) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/spaces/$spaceId');
    ref.invalidate(spacesProvider);
    ref.invalidate(navigationProvider);
  };
});
