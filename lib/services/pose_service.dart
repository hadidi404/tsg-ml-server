import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/pose_evaluation.dart';

class PoseService extends ChangeNotifier {
  // TODO: Change this to your backend server IP address
  static const String baseUrl = 'http://192.168.0.237:8000';
  static const String wsUrl = 'ws://192.168.0.237:8000';

  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  PoseEvaluation? _currentEvaluation;
  bool _isConnected = false;
  bool _isDisposed = false;
  String? _errorMessage;

  PoseEvaluation? get currentEvaluation => _currentEvaluation;
  bool get isConnected => _isConnected;
  String? get errorMessage => _errorMessage;

  /// Connect to WebSocket for real-time evaluation
  Future<void> connectWebSocket() async {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/pose-evaluation'),
      );

      _isConnected = true;
      _errorMessage = null;
      if (!_isDisposed) notifyListeners();

      // Listen for responses
      _streamSubscription = _channel!.stream.listen(
        (message) {
          if (_isDisposed) return;
          try {
            final data = json.decode(message);
            _currentEvaluation = PoseEvaluation.fromJson(data);
            if (!_isDisposed) notifyListeners();
          } catch (e) {
            _errorMessage = 'Error parsing response: $e';
            if (!_isDisposed) notifyListeners();
          }
        },
        onError: (error) {
          if (_isDisposed) return;
          _errorMessage = 'WebSocket error: $error';
          _isConnected = false;
          if (!_isDisposed) notifyListeners();
        },
        onDone: () {
          if (_isDisposed) return;
          _isConnected = false;
          if (!_isDisposed) notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = 'Failed to connect: $e';
      _isConnected = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Send frame to backend for evaluation
  void sendFrame(Uint8List imageBytes) {
    if (!_isConnected || _channel == null) return;

    try {
      final base64Image = base64Encode(imageBytes);
      _channel!.sink.add(json.encode({'frame': base64Image}));
    } catch (e) {
      _errorMessage = 'Error sending frame: $e';
      notifyListeners();
    }
  }

  /// Disconnect WebSocket
  void disconnect() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _currentEvaluation = null;
    if (!_isDisposed) notifyListeners();
  }

  /// Check if backend is online
  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _streamSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
