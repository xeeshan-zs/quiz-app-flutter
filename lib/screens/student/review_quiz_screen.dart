import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/quiz_model.dart';
import '../../models/result_model.dart';
import '../../services/firestore_service.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/quiz_app_bar.dart';
import '../../widgets/quiz_app_drawer.dart';

class ReviewQuizScreen extends StatefulWidget {
  final ResultModel result;

  const ReviewQuizScreen({super.key, required this.result});

  @override
  State<ReviewQuizScreen> createState() => _ReviewQuizScreenState();
}

class _ReviewQuizScreenState extends State<ReviewQuizScreen> {
  QuizModel? _quiz;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchQuiz();
  }

  Future<void> _fetchQuiz() async {
    final quiz = await FirestoreService().getQuizById(widget.result.quizId);
    if (mounted) {
      setState(() {
        _quiz = quiz;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    return Scaffold(
      appBar: QuizAppBar(user: user, isTransparent: false),
      drawer: QuizAppDrawer(user: user),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _quiz == null
              ? const Center(child: Text('Quiz details not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummaryCard(),
                    const SizedBox(height: 24),
                    const Text(
                      'Detailed Analysis',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(_quiz!.questions.length, (index) {
                      return _buildQuestionCard(index, _quiz!.questions[index]);
                    }),
                  ],
                ),
    );
  }

  Widget _buildSummaryCard() {
    final percentage = (widget.result.score / widget.result.totalMarks) * 100;
    final isPass = percentage >= 50;

    return Card(
      color: isPass ? Colors.green.shade50 : Colors.red.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isPass ? Colors.green.shade200 : Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Your Score',
              style: TextStyle(color: isPass ? Colors.green.shade900 : Colors.red.shade900),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.result.score} / ${widget.result.totalMarks}',
              style: TextStyle(
                fontSize: 32, 
                fontWeight: FontWeight.bold,
                color: isPass ? Colors.green.shade900 : Colors.red.shade900
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isPass ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isPass ? 'PASSED' : 'FAILED',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
      ),
    ).animate().scale();
  }

  Widget _buildQuestionCard(int index, Question question) {
    final userAnsIndex = widget.result.answers[question.id]; // Nullable format? Map<String, int>
    // Note: answers map key is question ID.
    
    final isCorrect = userAnsIndex == question.correctOptionIndex;
    final isSkipped = userAnsIndex == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(question.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(question.options.length, (optIndex) {
               final option = question.options[optIndex];
               Color? bgColor;
               Color? textColor;
               IconData? icon;

               // Logic:
               // 1. If this is the correct answer -> Green
               // 2. If this is what user picked AND it's wrong -> Red
               // 3. User picked this AND it's correct -> Green (already covered)
               
               bool isThisCorrect = optIndex == question.correctOptionIndex;
               bool isThisUserPick = optIndex == userAnsIndex;

               if (isThisCorrect) {
                  bgColor = Colors.green.shade100;
                  textColor = Colors.green.shade900;
                  icon = Icons.check_circle;
               } else if (isThisUserPick && !isCorrect) {
                  bgColor = Colors.red.shade100;
                  textColor = Colors.red.shade900;
                  icon = Icons.cancel;
               }

               return Container(
                 margin: const EdgeInsets.only(bottom: 8),
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                 decoration: BoxDecoration(
                   color: bgColor ?? Colors.grey.shade100,
                   borderRadius: BorderRadius.circular(8),
                   border: isThisUserPick || isThisCorrect 
                      ? Border.all(color: textColor ?? Colors.grey) 
                      : null,
                 ),
                 child: Row(
                   children: [
                     Expanded(child: Text(option, style: TextStyle(color: textColor ?? Colors.black87, fontWeight: FontWeight.w500))),
                     if (icon != null) Icon(icon, color: textColor, size: 20),
                   ],
                 ),
               );
            }),
            if (isSkipped)
               const Padding(
                 padding: EdgeInsets.only(top: 8.0),
                 child: Text('You skipped this question', style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic)),
               ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (100 * index).ms);
  }
}
