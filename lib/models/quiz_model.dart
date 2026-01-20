import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.isNaN ? 0 : value.toInt();
  if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? 0;
  return 0;
}

class Question {
  final String id;
  final String text;
  final List<String> options;
  final int correctOptionIndex;

  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctOptionIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] ?? const Uuid().v4(),
      text: map['text'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctOptionIndex: map['correctOptionIndex'] ?? 0,
    );
  }
}

class QuizModel {
  final String id;
  final String title;
  final String createdByUid;
  final DateTime createdAt;
  final int totalMarks;
  final int durationMinutes;
  final bool isPaused;
  final List<Question> questions;
  
  // Hierarchy & Filtering
  final String? adminId;    // The Admin (Tenant) owning this quiz
  final String? classLevel; // e.g., '10', '11'
  final bool isDraft;       // Teacher "Quiz Bank"

  QuizModel({
    required this.id,
    required this.title,
    required this.createdByUid,
    required this.createdAt,
    required this.totalMarks,
    required this.durationMinutes,
    this.isPaused = false,
    required this.questions,
    this.adminId,
    this.classLevel,
    this.isDraft = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdByUid': createdByUid,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'totalMarks': totalMarks,
      'durationMinutes': durationMinutes,
      'isPaused': isPaused,
      'questions': questions.map((q) => q.toMap()).toList(),
      'adminId': adminId,
      'classLevel': classLevel,
      'isDraft': isDraft,
    };
  }

  factory QuizModel.fromMap(Map<String, dynamic> map) {
    return QuizModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      createdByUid: map['createdByUid'] ?? map['createdBy'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      totalMarks: _parseInt(map['totalMarks']),
      durationMinutes: _parseInt(map['durationMinutes']),
      isPaused: map['isPaused'] ?? false,
      questions: (map['questions'] as List<dynamic>?)
              ?.map((q) => Question.fromMap(q))
              .toList() ??
          [],
      adminId: map['adminId'],
      classLevel: map['classLevel']?.toString(), // Ensure string
      isDraft: map['isDraft'] ?? false,
    );
  }
}
