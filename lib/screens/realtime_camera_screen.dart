import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  PoseService? _poseService;

  @override
  void initState() {
    super.initState();
    // Lock to landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    _initializeCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectWebSocket();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _poseService = context.read<PoseService>();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No cameras available')));
        }
        return;
      }

      final camera = _cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    }
  }

  Future<void> _connectWebSocket() async {
    final poseService = context.read<PoseService>();
    await poseService.connectWebSocket();
  }

  void _startFrameProcessing() {
    _frameTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      if (_isProcessing ||
          _cameraController == null ||
          !_cameraController!.value.isInitialized) {
        return;
      }

      _isProcessing = true;
      try {
        final image = await _cameraController!.takePicture();
        final bytes = await image.readAsBytes();

        final poseService = context.read<PoseService>();
        poseService.sendFrame(bytes);
      } catch (e) {
        // Ignore frame capture errors
      } finally {
        _isProcessing = false;
      }
    });
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _cameraController?.dispose();
    _poseService?.disconnect();
    // Restore orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Feature scores bar at top
                Consumer<PoseService>(
                  builder: (context, service, _) {
                    final evaluation = service.currentEvaluation;

                    return Container(
                      width: double.infinity,
                      color: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // Connection status indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: service.isConnected
                                  ? Colors.green
                                  : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  service.isConnected
                                      ? Icons.wifi
                                      : Icons.wifi_off,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  service.isConnected ? 'LIVE' : 'OFFLINE',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Feature scores (keep Expanded always so close button stays right)
                          Expanded(
                            child: (evaluation != null && evaluation.isComplete)
                                ? Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: evaluation.featureScores.entries.map((
                                      entry,
                                    ) {
                                      final score = entry.value;
                                      final color = score > 80
                                          ? Colors.green
                                          : score > 50
                                          ? Colors.yellow
                                          : Colors.red;

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: color,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '${entry.key}: ${score.toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  )
                                : const SizedBox(),
                          ),

                          // Back button
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Main content
                Expanded(
                  child: Row(
                    children: [
                      // Camera preview (70%)
                      Expanded(
                        flex: 7,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: _cameraController!
                                        .value
                                        .previewSize!
                                        .width,
                                    height: _cameraController!
                                        .value
                                        .previewSize!
                                        .height,
                                    child: CameraPreview(_cameraController!),
                                  ),
                                ),

                                // Pose overlay
                                Consumer<PoseService>(
                                  builder: (context, service, _) {
                                    final evaluation =
                                        service.currentEvaluation;
                                    return CustomPaint(
                                      painter: PoseOverlayPainter(evaluation),
                                      child: Container(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Feedback panel (30%)
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: double.infinity,
                          color: Colors.black87,
                          padding: const EdgeInsets.all(16),
                          child: Consumer<PoseService>(
                            builder: (context, service, _) {
                              final evaluation = service.currentEvaluation;

                              if (evaluation == null) {
                                return const Center(
                                  child: Text(
                                    'Waiting for pose detection...',
                                    style: TextStyle(
                                      color: Colors.yellow,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }

                              if (!evaluation.isComplete) {
                                return Center(
                                  child: Text(
                                    evaluation.message ?? 'No pose detected',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }

                              return SingleChildScrollView(
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
                                      const Text(
                                        'Suggestions:',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...evaluation.feedback.map(
                                        (fb) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                '• ',
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  fb,
                                                  style: const TextStyle(
                                                    color: Colors.redAccent,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ] else
                                      const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                          '✓ Great form! Keep it up!',
                                          style: TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),

                                    const SizedBox(height: 16),
                                    const Divider(color: Colors.white30),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
