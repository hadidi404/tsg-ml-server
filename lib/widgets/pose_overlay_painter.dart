import 'package:flutter/material.dart';
import '../models/pose_evaluation.dart';

class PoseOverlayPainter extends CustomPainter {
  final PoseEvaluation? evaluation;

  PoseOverlayPainter(this.evaluation);

  @override
  void paint(Canvas canvas, Size size) {
    if (evaluation == null) return;

    final landmarks = evaluation!.landmarks;
    if (landmarks == null) return;

    final jointColors = evaluation!.jointColors;
    
    // Paint for drawing
    final linePaint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    final jointPaint = Paint()
      ..style = PaintingStyle.fill;

    // Draw pose landmarks
    if (landmarks['pose'] != null) {
      final pose = landmarks['pose'] as Map<String, dynamic>;
      
      // Draw connections
      linePaint.color = Colors.white.withOpacity(0.8);
      
      // Draw arm lines
      _drawLine(canvas, size, pose['left_shoulder'], pose['left_elbow'], linePaint);
      _drawLine(canvas, size, pose['left_elbow'], pose['left_wrist'], linePaint);
      _drawLine(canvas, size, pose['right_shoulder'], pose['right_elbow'], linePaint);
      _drawLine(canvas, size, pose['right_elbow'], pose['right_wrist'], linePaint);
      _drawLine(canvas, size, pose['left_shoulder'], pose['right_shoulder'], linePaint);
      
      // Draw joints with color coding
      _drawJoint(canvas, size, pose['left_shoulder'], _getColorFromString(jointColors['shoulders'] ?? 'green'), jointPaint);
      _drawJoint(canvas, size, pose['right_shoulder'], _getColorFromString(jointColors['shoulders'] ?? 'green'), jointPaint);
      _drawJoint(canvas, size, pose['left_elbow'], _getColorFromString(jointColors['left_elbow'] ?? 'green'), jointPaint);
      _drawJoint(canvas, size, pose['right_elbow'], _getColorFromString(jointColors['right_elbow'] ?? 'green'), jointPaint);
      _drawJoint(canvas, size, pose['left_wrist'], _getColorFromString(jointColors['left_hand'] ?? 'green'), jointPaint);
      _drawJoint(canvas, size, pose['right_wrist'], _getColorFromString(jointColors['right_hand'] ?? 'green'), jointPaint);
    }
    
    // Draw hand landmarks
    if (landmarks['left_hand'] != null) {
      final leftHand = landmarks['left_hand'] as List<dynamic>;
      _drawHand(canvas, size, leftHand, Colors.pink.withOpacity(0.6));
    }
    
    if (landmarks['right_hand'] != null) {
      final rightHand = landmarks['right_hand'] as List<dynamic>;
      _drawHand(canvas, size, rightHand, Colors.pink.withOpacity(0.6));
    }
  }

  void _drawLine(Canvas canvas, Size size, dynamic point1, dynamic point2, Paint paint) {
    if (point1 == null || point2 == null) return;
    
    final p1 = point1 as Map<String, dynamic>;
    final p2 = point2 as Map<String, dynamic>;
    
    if ((p1['visibility'] ?? 0) < 0.5 || (p2['visibility'] ?? 0) < 0.5) return;
    
    final offset1 = Offset((1 - p1['x']) * size.width, p1['y'] * size.height);
    final offset2 = Offset((1 - p2['x']) * size.width, p2['y'] * size.height);
    
    canvas.drawLine(offset1, offset2, paint);
  }

  void _drawJoint(Canvas canvas, Size size, dynamic point, Color color, Paint paint) {
    if (point == null) return;
    
    final p = point as Map<String, dynamic>;
    if ((p['visibility'] ?? 0) < 0.5) return;
    
    final offset = Offset((1 - p['x']) * size.width, p['y'] * size.height);
    
    // Draw colored circle
    paint.color = color;
    canvas.drawCircle(offset, 12, paint);
    
    // Draw white border
    paint
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(offset, 12, paint);
    paint
      ..style = PaintingStyle.fill
      ..strokeWidth = 1;
  }

  void _drawHand(Canvas canvas, Size size, List<dynamic> handLandmarks, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final jointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Hand connections (MediaPipe hand topology)
    final connections = [
      [0, 1], [1, 2], [2, 3], [3, 4],  // Thumb
      [0, 5], [5, 6], [6, 7], [7, 8],  // Index
      [0, 9], [9, 10], [10, 11], [11, 12],  // Middle
      [0, 13], [13, 14], [14, 15], [15, 16],  // Ring
      [0, 17], [17, 18], [18, 19], [19, 20],  // Pinky
      [5, 9], [9, 13], [13, 17],  // Palm
    ];
    
    // Draw connections
    for (var conn in connections) {
      final p1 = handLandmarks[conn[0]] as Map<String, dynamic>;
      final p2 = handLandmarks[conn[1]] as Map<String, dynamic>;
      
      final offset1 = Offset((1 - p1['x']) * size.width, p1['y'] * size.height);
      final offset2 = Offset((1 - p2['x']) * size.width, p2['y'] * size.height);
      
      canvas.drawLine(offset1, offset2, paint);
    }
    
    // Draw joints
    for (var landmark in handLandmarks) {
      final lm = landmark as Map<String, dynamic>;
      final offset = Offset((1 - lm['x']) * size.width, lm['y'] * size.height);
      canvas.drawCircle(offset, 4, jointPaint);
    }
  }

  Color _getColorFromString(String colorStr) {
    switch (colorStr.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.yellow;
      case 'green':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  bool shouldRepaint(PoseOverlayPainter oldDelegate) {
    return oldDelegate.evaluation != evaluation;
  }
}
