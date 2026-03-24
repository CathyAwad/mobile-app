import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frona_mobile/providers/auth_provider.dart';
import 'package:frona_mobile/core/api/api_client.dart';
import 'package:frona_mobile/core/api/sse_client.dart';
import 'package:frona_mobile/features/chat/domain/chat_event.dart';

final chatStreamProvider = Provider<Stream<ChatEvent>>((ref) {
  final authState = ref.watch(authStateProvider);
  
  if (authState.user == null) {
    return const Stream.empty();
  }

  final controller = StreamController<ChatEvent>.broadcast();

  // We need to handle the async token retrieval
  SharedPreferences.getInstance().then((prefs) {
    final token = prefs.getString('auth_token');
    if (token == null) {
      controller.close();
      return;
    }

    // Use a fresh Dio instance specifically for SSE to avoid global receiveTimeout
    final sseDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      // Set infinite receiveTimeout for SSE streams
      receiveTimeout: const Duration(milliseconds: 0),
      contentType: 'text/event-stream',
    ));
    
    final sseUrl = '$baseUrl/stream';
    
    final sseClient = SseClient(
      sseDio, 
      sseUrl,
      headers: {'Authorization': 'Bearer $token'},
    );

    sseClient.stream.listen(
      (event) {
        try {
          final data = jsonDecode(event.data) as Map<String, dynamic>;
          final chatEvent = ChatEvent.fromJson(event.event ?? 'unknown', data);
          controller.add(chatEvent);
        } catch (e) {
          print('ChatStreamProvider: Error parsing SSE event: $e');
        }
      },
      onError: (e) => controller.addError(e),
      onDone: () => controller.close(),
    );
  });

  return controller.stream;
});
