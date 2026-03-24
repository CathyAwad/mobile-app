import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class SseEvent {
  final String? id;
  final String? event;
  final String data;

  SseEvent({this.id, this.event, required this.data});

  @override
  String toString() => 'SseEvent(id: $id, event: $event, data: $data)';
}

class SseClient {
  final Dio _dio;
  final String _url;
  final Map<String, dynamic>? _headers;
  
  StreamController<SseEvent>? _controller;
  bool _isConnecting = false;

  SseClient(this._dio, this._url, {Map<String, dynamic>? headers}) : _headers = headers;

  Stream<SseEvent> get stream {
    if (_controller == null) {
      _controller = StreamController<SseEvent>.broadcast(
        onListen: _connect,
        onCancel: _disconnect,
      );
    }
    return _controller!.stream;
  }

  void _connect() async {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      final response = await _dio.get<ResponseBody>(
        _url,
        options: Options(
          headers: {
            ...?_headers,
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
          },
          responseType: ResponseType.stream,
        ),
      );

      String? currentId;
      String? currentEvent;
      String currentData = '';

      final transformer = StreamTransformer<Uint8List, List<int>>.fromHandlers(
        handleData: (Uint8List data, EventSink<List<int>> sink) => sink.add(data),
      );

      await response.data!.stream
          .transform(transformer)
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
        if (line.isEmpty) {
          if (currentData.isNotEmpty) {
            _controller?.add(SseEvent(
              id: currentId,
              event: currentEvent,
              data: currentData.trim(),
            ));
            currentData = '';
          }
          currentEvent = null;
          return;
        }

        if (line.startsWith(':')) {
          // Comment, ignore
          return;
        }

        final index = line.indexOf(':');
        if (index <= 0) return;

        final field = line.substring(0, index);
        final value = line.substring(index + 1).trim();

        switch (field) {
          case 'id':
            currentId = value;
            break;
          case 'event':
            currentEvent = value;
            break;
          case 'data':
            currentData += (currentData.isEmpty ? '' : '\n') + value;
            break;
          case 'retry':
            // Could implement retry logic here if needed
            break;
        }
      });
    } catch (e) {
      print('SseClient reconnecting after error: $e');
      // Reconnect after a delay
      Future.delayed(const Duration(seconds: 2), _connect);
    } finally {
      _isConnecting = false;
    }
  }

  void _disconnect() {
    _controller?.close();
    _controller = null;
    _isConnecting = false;
  }
}
