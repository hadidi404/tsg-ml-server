import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'services/pose_service.dart';
import 'screens/realtime_camera_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => PoseService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TSG Pose Evaluator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _picker = ImagePicker();
  File? _image;
  bool _isEvaluating = false;

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();
  }

  Future<void> _checkBackendHealth() async {
    final poseService = context.read<PoseService>();
    final isOnline = await poseService.checkServerHealth();
    if (mounted && !isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Backend offline. Run: python backend_server.py'),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _openCamera() async {
    // On desktop platforms (Linux, Windows, macOS), permissions are handled at OS level
    if (!Platform.isAndroid && !Platform.isIOS) {
      final xfile = await _picker.pickImage(source: ImageSource.camera);
      if (xfile == null) return;
      setState(() {
        _image = File(xfile.path);
        _isEvaluating = true;
      });
      await _evaluatePose(xfile.path);
      return;
    }

    // For mobile platforms, request camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission required')),
      );
      if (status.isPermanentlyDenied) openAppSettings();
      return;
    }

    final xfile = await _picker.pickImage(source: ImageSource.camera);
    if (xfile == null) return;
    setState(() {
      _image = File(xfile.path);
      _isEvaluating = true;
    });
    await _evaluatePose(xfile.path);
  }

  Future<void> _evaluatePose(String imagePath) async {
    final poseService = context.read<PoseService>();
    final imageBytes = await File(imagePath).readAsBytes();
    final evaluation = await poseService.evaluateImage(imageBytes);
    
    setState(() {
      _isEvaluating = false;
    });
    
    if (evaluation != null && mounted) {
      _showEvaluationDialog(evaluation);
    } else if (mounted && poseService.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(poseService.errorMessage!)),
      );
    }
  }

  void _showEvaluationDialog(evaluation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              evaluation.isComplete ? Icons.check_circle : Icons.error,
              color: evaluation.scoreColor,
            ),
            const SizedBox(width: 8),
            const Text('Pose Evaluation'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ML Score: ${evaluation.mlScore.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: evaluation.scoreColor,
                ),
              ),
              const SizedBox(height: 16),
              if (evaluation.feedback.isNotEmpty) ...[
                const Text(
                  'Feedback:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...evaluation.feedback.map((fb) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(fb)),
                        ],
                      ),
                    )),
              ] else
                const Text(
                  '✓ Great form! Keep it up!',
                  style: TextStyle(color: Colors.green, fontSize: 16),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TSG Pose Evaluator'),
        actions: [
          Consumer<PoseService>(
            builder: (context, service, _) {
              return IconButton(
                icon: Icon(
                  Icons.info_outline,
                  color: service.errorMessage != null ? Colors.red : null,
                ),
                onPressed: _checkBackendHealth,
                tooltip: 'Check backend status',
              );
            },
          ),
        ],
      ),
      body: Center(
        child: _isEvaluating
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing pose...'),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_image != null)
                    Image.file(_image!, width: 300, height: 300, fit: BoxFit.cover)
                  else
                    const SizedBox(
                      height: 300,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No photo captured'),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture & Evaluate Pose'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RealtimeCameraScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.videocam),
                    label: const Text('Real-time Pose Evaluation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
