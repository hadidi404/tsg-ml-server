import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/pose_evaluation.dart';

class PoseService extends ChangeNotifier {
  // TODO: Change this to your backend server IP address
  // Example: 'http://192.168.1.100:8000' or 'http://YOUR_LAPTOP_IP:8000'
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

  /// Evaluate a static image
  Future<PoseEvaluation?> evaluateImage(Uint8List imageBytes) async {
    try {
      _errorMessage = null;
      notifyListeners();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/evaluate-image'),
      );
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'pose.jpg',
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final data = json.decode(responseData);
        return PoseEvaluation.fromJson(data);
      } else {
        _errorMessage = 'Server error: ${response.statusCode}';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error: $e. Make sure backend is running!';
      notifyListeners();
      return null;
    }
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
