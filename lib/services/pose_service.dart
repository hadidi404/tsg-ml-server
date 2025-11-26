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
  PoseEvaluation? _currentEvaluation;
  bool _isConnected = false;
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
      notifyListeners();
      
      // Listen for responses
      _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            _currentEvaluation = PoseEvaluation.fromJson(data);
            notifyListeners();
          } catch (e) {
            _errorMessage = 'Error parsing response: $e';
            notifyListeners();
          }
        },
        onError: (error) {
          _errorMessage = 'WebSocket error: $error';
          _isConnected = false;
          notifyListeners();
        },
        onDone: () {
          _isConnected = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = 'Failed to connect: $e';
      _isConnected = false;
      notifyListeners();
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
    _channel?.sink.close();
    _isConnected = false;
    _currentEvaluation = null;
    notifyListeners();
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
    disconnect();
    super.dispose();
  }
}
