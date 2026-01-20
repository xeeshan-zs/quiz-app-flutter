
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/quiz_model.dart';
import '../../models/result_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import 'package:go_router/go_router.dart';

class QuizAttemptScreen extends StatefulWidget {
  final QuizModel quiz;

  const QuizAttemptScreen({super.key, required this.quiz});

  @override
  State<QuizAttemptScreen> createState() => _QuizAttemptScreenState();
}

class _QuizAttemptScreenState extends State<QuizAttemptScreen> {
  late Timer _timer;
  late int _remainingSeconds;
  final PageController _pageController = PageController();
  final Map<String, int> _answers = {}; // questionId : selectedIndex
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.quiz.durationMinutes * 60;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer.cancel();
        _submitQuiz();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    _timer.cancel();

    final user = context.read<UserProvider>().user!;
    
    // Calculate Score
    int score = 0;
    for (var question in widget.quiz.questions) {
        final selected = _answers[question.id];
        if (selected != null && selected == question.correctOptionIndex) {
            score++; // Assuming 1 mark per question for simplicity, or handle complex marking
        }
    }
    
    // Adjust if totalMarks logic is different (e.g., evenly distributed)
    // For now assuming simplified logic: score is count of correct answers.
    // If totalMarks is fixed, we might scale it.
    // Let's assume question weight = totalMarks / questionCount
    double scoreValue = 0;
    if (widget.quiz.questions.isNotEmpty) {
       final double marksPerQ = widget.quiz.totalMarks / widget.quiz.questions.length;
       for (var question in widget.quiz.questions) {
          final selected = _answers[question.id];
          if (selected != null && selected == question.correctOptionIndex) {
              scoreValue += marksPerQ;
          }
       }
    }

    // 4. Get Previous Attempts Count
    int attempts = 0;
    try {
      attempts = await FirestoreService().getAttemptCount(user.uid, widget.quiz.id);
    } catch (_) {} // Ignore error, default to 0 (so new is 1)

    final result = ResultModel(
      id: const Uuid().v4(),
      quizId: widget.quiz.id,
      quizTitle: widget.quiz.title,
      studentId: user.uid,
      studentName: user.name,
      studentRollNumber: user.rollNumber ?? 'N/A',
      className: user.className,
      score: scoreValue.round(),
      totalMarks: widget.quiz.totalMarks,
      answers: _answers,
      submittedAt: DateTime.now(),
      attemptNumber: attempts + 1,
    );

    try {
      await FirestoreService().submitResult(result);
      if (mounted) {
         // Show success and pop
         showDialog(
             context: context, 
             barrierDismissible: false,
             builder: (c) => AlertDialog(
                 title: const Text('Quiz Submitted'),
                 content: Text('Your score: ${result.score} / ${result.totalMarks}'),
                 actions: [
                     TextButton(
                         onPressed: () { 
                             context.go('/student'); // Return to dashboard
                         },
                         child: const Text('OK'),
                     )
                 ],
             ),
         );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting: $e')));
         setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _confirmSubmit() async {
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish Quiz?'),
        content: const Text('Are you sure you want to submit your answers? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (shouldSubmit == true) {
      _submitQuiz();
    }
  }

  Future<void> _handleExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Quiz?'),
        content: const Text(
          'Warning: If you leave now, you will receive 0 marks for this quiz. This cannot be undone.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave & Get 0'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      _submitZeroResult();
    }
  }

  Future<void> _submitZeroResult() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    _timer.cancel();

    final user = context.read<UserProvider>().user!;
    
    final result = ResultModel(
      id: const Uuid().v4(),
      quizId: widget.quiz.id,
      quizTitle: widget.quiz.title,
      studentId: user.uid,
      studentName: user.name,
      studentRollNumber: user.rollNumber ?? 'N/A',
      className: user.className,
      score: 0, // Explicitly 0
      totalMarks: widget.quiz.totalMarks,
      answers: _answers, // Keep answers just for record (optional)
      submittedAt: DateTime.now(),
    );

    try {
      await FirestoreService().submitResult(result);
      if (mounted) {
         context.go('/student');
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exiting: $e')));
         setState(() => _isSubmitting = false);
      }
    }
  }

  String get _timerText {
    final minutes = (_remainingSeconds / 60).floor();
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color get _timerColor {
    final totalSeconds = widget.quiz.durationMinutes * 60;
    final progress = _remainingSeconds / totalSeconds;
    if (progress > 0.5) return Colors.green;
    if (progress > 0.2) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = widget.quiz.durationMinutes * 60;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Custom Top Bar with Progress
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                   BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                ]
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Row(
                         children: [
                           IconButton(
                             onPressed: _handleExit,
                             icon: const Icon(Icons.close_rounded),
                             tooltip: 'Exit Quiz',
                           ),
                           const SizedBox(width: 8),
                           Text(
                             widget.quiz.title,
                             style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                           ),
                         ],
                       ),
                       Row( // Right side actions
                         children: [
                           TextButton.icon(
                             onPressed: _showQuestionMap,
                             icon: const Icon(Icons.grid_view_rounded, size: 20),
                             label: const Text("Map"),
                             style: TextButton.styleFrom(
                               foregroundColor: Theme.of(context).primaryColor,
                               backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                             ),
                           ),
                           const SizedBox(width: 8),
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                             decoration: BoxDecoration(
                               color: _timerColor.withOpacity(0.1),
                               borderRadius: BorderRadius.circular(20),
                             ),
                             child: Row(
                               children: [
                                 Icon(Icons.timer_outlined, size: 16, color: _timerColor),
                                 const SizedBox(width: 4),
                                 Text(
                                   _timerText,
                                   style: TextStyle(fontWeight: FontWeight.bold, color: _timerColor),
                                 ),
                               ],
                             ),
                           ),
                         ],
                       ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _remainingSeconds / totalSeconds,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(_timerColor),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                ],
              ),
            ),
             Expanded(
               child: PageView.builder(
        controller: _pageController,
        itemCount: widget.quiz.questions.length,
        itemBuilder: (context, index) {
          final question = widget.quiz.questions[index];
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question ${index + 1} of ${widget.quiz.questions.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  question.text,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                ...List.generate(question.options.length, (optIndex) {
                  final option = question.options[optIndex];
                  final isSelected = _answers[question.id] == optIndex;

                  return Card(
                    color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: RadioListTile<int>(
                      value: optIndex,
                      groupValue: _answers[question.id],
                      title: Text(option),
                      onChanged: _isSubmitting ? null : (val) {
                        setState(() {
                          _answers[question.id] = val!;
                        });
                      },
                    ),
                  );
                }),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (index > 0)
                      FilledButton.tonal(
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        child: const Text('Previous'),
                      )
                    else
                      const SizedBox.shrink(),
                    
                    if (index < widget.quiz.questions.length - 1)
                      FilledButton(
                        onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        child: const Text('Next'),
                      )
                    else
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: _confirmSubmit,
                        child: _isSubmitting 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                            : const Text('Submit'),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      ), // Expanded
      ],
     ), // Column
    ), // SafeArea
      ), // Scaffold
    ); // PopScope
  }

  void _showQuestionMap() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Question Map", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: widget.quiz.questions.length,
                  itemBuilder: (context, index) {
                    final isAnswered = _answers.containsKey(widget.quiz.questions[index].id);
                    final isCurrent = (_pageController.page?.round() ?? 0) == index;
                    
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _pageController.jumpToPage(index);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent ? Theme.of(context).primaryColor : (isAnswered ? Colors.green.withOpacity(0.2) : Colors.grey[200]),
                          border: isCurrent ? Border.all(color: Theme.of(context).primaryColor, width: 2) : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isCurrent ? Colors.white : (isAnswered ? Colors.green[800] : Colors.black),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
