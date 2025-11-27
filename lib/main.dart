import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/pose_service.dart';
import 'screens/realtime_camera_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Set immersive mode for entire app
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(
    ChangeNotifierProvider(create: (_) => PoseService(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TSG Pose Evaluator',
      debugShowCheckedModeBanner: false,
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBackendHealth();
    });
  }

  Future<void> _checkBackendHealth() async {
    final poseService = context.read<PoseService>();
    final isOnline = await poseService.checkServerHealth();
    if (mounted && !isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Backend offline. Run: python BackendServer.py'),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.orange,
        ),
      );
    }
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, size: 100, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Real-time Pose Evaluation',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Get instant feedback on your armwrestling form with live pose analysis',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RealtimeCameraScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.videocam, size: 28),
              label: const Text(
                'Start Real-time Evaluation',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
