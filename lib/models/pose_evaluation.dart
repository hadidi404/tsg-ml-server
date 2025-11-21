import 'package:flutter/material.dart';

class PoseEvaluation {
  final String status;
  final double mlScore;
  final Map<String, double> featureScores;
  final List<String> feedback;
  final Map<String, String> jointColors;
  final String? message;
  final Map<String, dynamic>? landmarks;

  PoseEvaluation({
    required this.status,
    required this.mlScore,
    required this.featureScores,
    required this.feedback,
    required this.jointColors,
    this.message,
    this.landmarks,
  });

  factory PoseEvaluation.fromJson(Map<String, dynamic> json) {
    return PoseEvaluation(
      status: json['status'] ?? 'unknown',
      mlScore: (json['ml_score'] ?? 0).toDouble(),
      featureScores: Map<String, double>.from(
        json['feature_scores']?.map((key, value) => 
          MapEntry(key, (value ?? 0).toDouble())
        ) ?? {},
      ),
      feedback: List<String>.from(json['feedback'] ?? []),
      jointColors: Map<String, String>.from(json['joint_colors'] ?? {}),
      message: json['message'],
      landmarks: json['landmarks'],
    );
  }

  bool get isComplete => status == 'success';
  bool get hasIssues => feedback.isNotEmpty;
  
  Color get scoreColor {
    if (mlScore > 80) return const Color(0xFF4CAF50); // Green
    if (mlScore > 50) return const Color(0xFFFFEB3B); // Yellow
    return const Color(0xFFF44336); // Red
  }
}
