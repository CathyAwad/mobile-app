import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../core/api/api_client.dart';
import '../features/agent/domain/agent_model.dart';

final agentsProvider = FutureProvider<List<Agent>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/agents');
  
  final List<dynamic> data = response.data;
  return data.map((json) => Agent.fromJson(json)).toList();
});
