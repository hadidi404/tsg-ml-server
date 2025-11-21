import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/pose_service.dart';
import '../widgets/pose_overlay_painter.dart';

class RealtimeCameraScreen extends StatefulWidget {
  const RealtimeCameraScreen({super.key});

  @override
  State<RealtimeCameraScreen> createState() => _RealtimeCameraScreenState();
}

class _RealtimeCameraScreenState extends State<RealtimeCameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isProcessing = false;
  Timer? _frameTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _connectWebSocket();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras available')),
          );
        }
        return;
      }

      // Use front camera for pose evaluation
      final camera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {});
        _startFrameProcessing();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  Future<void> _connectWebSocket() async {
    final poseService = context.read<PoseService>();
    await poseService.connectWebSocket();
  }

  void _startFrameProcessing() {
    // Send frames at ~10 FPS (100ms interval) to avoid overwhelming the backend
    _frameTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (_isProcessing || _cameraController == null || !_cameraController!.value.isInitialized) {
        return;
      }

      _isProcessing = true;
      try {
        final image = await _cameraController!.takePicture();
        final bytes = await image.readAsBytes();
        
        final poseService = context.read<PoseService>();
        poseService.sendFrame(bytes);
      } catch (e) {
        // Ignore errors during frame capture
      } finally {
        _isProcessing = false;
      }
    });
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _cameraController?.dispose();
    context.read<PoseService>().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Pose Evaluation'),
        actions: [
          Consumer<PoseService>(
            builder: (context, service, _) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: service.isConnected ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      service.isConnected ? 'CONNECTED' : 'OFFLINE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Camera preview - full screen
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize!.height,
                      height: _cameraController!.value.previewSize!.width,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),
                
                // Pose overlay with feedback
                Consumer<PoseService>(
                  builder: (context, service, _) {
                    final evaluation = service.currentEvaluation;
                    
                    return CustomPaint(
                      painter: PoseOverlayPainter(evaluation),
                      child: Container(),
                    );
                  },
                ),
                
                // Feedback overlay at top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Consumer<PoseService>(
                    builder: (context, service, _) {
                      final evaluation = service.currentEvaluation;
                      
                      if (evaluation == null) {
                        return Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.all(16),
                          child: const Text(
                            'Waiting for pose detection...',
                            style: TextStyle(color: Colors.yellow, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      
                      if (!evaluation.isComplete) {
                        return Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            evaluation.message ?? 'No pose detected',
                            style: const TextStyle(color: Colors.orange, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      
                      return Container(
                        color: Colors.black87,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ML Score
                            Row(
                              children: [
                                const Text(
                                  'ML Score: ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${evaluation.mlScore.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: evaluation.scoreColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            
                            if (evaluation.feedback.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ...evaluation.feedback.take(3).map((fb) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      fb,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 14,
                                      ),
                                    ),
                                  )),
                            ] else
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  '✓ Great form!',
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                // Feature scores at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Consumer<PoseService>(
                    builder: (context, service, _) {
                      final evaluation = service.currentEvaluation;
                      
                      if (evaluation == null || !evaluation.isComplete) {
                        return const SizedBox.shrink();
                      }
                      
                      return Container(
                        color: Colors.black87,
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: evaluation.featureScores.entries.map((entry) {
                            final score = entry.value;
                            final color = score > 80
                                ? Colors.green
                                : score > 50
                                    ? Colors.yellow
                                    : Colors.red;
                            
                            return Chip(
                              label: Text(
                                '${entry.key}: ${score.toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: color.withOpacity(0.3),
                              side: BorderSide(color: color, width: 1),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
