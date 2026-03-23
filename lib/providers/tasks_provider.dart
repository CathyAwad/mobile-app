import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../core/api/api_client.dart';
import '../features/task/domain/task_model.dart';

final tasksProvider = FutureProvider<List<TaskModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/tasks');
  
  final List<dynamic> data = response.data;
  return data.map((json) => TaskModel.fromJson(json)).toList();
});

final deleteTaskProvider = Provider<Future<void> Function(String)>((ref) {
  return (taskId) async {
    final dio = ref.read(dioProvider);
    await dio.delete('/tasks/$taskId');
    ref.invalidate(tasksProvider);
  };
});
