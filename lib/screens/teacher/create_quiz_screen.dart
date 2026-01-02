import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/quiz_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import 'package:go_router/go_router.dart';

class CreateQuizScreen extends StatefulWidget {
  final QuizModel? quizToEdit;
  const CreateQuizScreen({super.key, this.quizToEdit});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController();
  final _marksController = TextEditingController();

  final List<Question> _questions = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.quizToEdit != null) {
      _titleController.text = widget.quizToEdit!.title;
      _durationController.text = widget.quizToEdit!.durationMinutes.toString();
      _marksController.text = widget.quizToEdit!.totalMarks.toString();
      _questions.addAll(widget.quizToEdit!.questions);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _marksController.dispose();
    super.dispose();
  }

  void _addOrEditQuestion({Question? questionToEdit, int? index}) {
    showDialog(
      context: context,
      builder: (context) => _AddQuestionDialog(
        questionToEdit: questionToEdit,
        onSave: (question) {
          setState(() {
            if (questionToEdit != null && index != null) {
              _questions[index] = question;
            } else {
              _questions.add(question);
            }
          });
        },
      ),
    );
  }

  Future<void> _submitQuiz() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one question')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = context.read<UserProvider>().user;
      // If editing, keep original ID. If new, generate ID.
      final quizId = widget.quizToEdit?.id ?? const Uuid().v4();

      int totalMarks = int.tryParse(_marksController.text) ?? 0;

      final quiz = QuizModel(
        id: quizId,
        title: _titleController.text.trim(),
        createdByUid: widget.quizToEdit?.createdByUid ?? user?.uid ?? 'unknown',
        createdAt: widget.quizToEdit?.createdAt ?? DateTime.now(),
        totalMarks: totalMarks,
        durationMinutes: int.parse(_durationController.text),
        questions: _questions,
        isPaused: widget.quizToEdit?.isPaused ?? false,
      );

      await FirestoreService().createQuiz(quiz); // createQuiz uses set() so it overwrites/updates
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.quizToEdit != null ? 'Quiz Updated!' : 'Quiz Created!')));
         context.pop();
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.quizToEdit != null;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(isEditing ? 'Edit Quiz' : 'Create New Quiz')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Title Card
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           const Text('Quiz Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                           const SizedBox(height: 16),
                           TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(labelText: 'Quiz Title', prefixIcon: Icon(Icons.title)),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _durationController,
                                  decoration: const InputDecoration(labelText: 'Duration (Min)', prefixIcon: Icon(Icons.timer_outlined)),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v!.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _marksController,
                                  decoration: const InputDecoration(labelText: 'Total Marks', prefixIcon: Icon(Icons.emoji_events_outlined)),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v!.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Questions Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Questions (${_questions.length})', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      FilledButton.icon(
                        onPressed: () => _addOrEditQuestion(), 
                        icon: const Icon(Icons.add),
                        label: const Text('Add Question'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Smaller padding
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Questions List
                  if (_questions.isEmpty)
                    Container(
                      height: 200,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 2),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.withValues(alpha: 0.05),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.quiz_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('No questions added yet.', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  else
                    ..._questions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final q = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                          ),
                          title: Text(q.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            'Correct: ${q.options.isNotEmpty && q.correctOptionIndex < q.options.length ? q.options[q.correctOptionIndex] : "Invalid"}',
                            style: TextStyle(color: Colors.green[700]),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _addOrEditQuestion(questionToEdit: q, index: index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _questions.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                          onTap: () => _addOrEditQuestion(questionToEdit: q, index: index),
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 80), // Specs for FAB or bottom button
                ],
              ),
            ),
            
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
                ]
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18)
                  ),
                  onPressed: _isSubmitting ? null : _submitQuiz,
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEditing ? 'Update Quiz' : 'Save & Publish Quiz', style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddQuestionDialog extends StatefulWidget {
  final Question? questionToEdit;
  final Function(Question) onSave;

  const _AddQuestionDialog({this.questionToEdit, required this.onSave});

  @override
  State<_AddQuestionDialog> createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<_AddQuestionDialog> {
  final _qTextController = TextEditingController();
  final List<TextEditingController> _optionControllers = 
      List.generate(4, (_) => TextEditingController());
  int _correctIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.questionToEdit != null) {
      _qTextController.text = widget.questionToEdit!.text;
      _correctIndex = widget.questionToEdit!.correctOptionIndex;
      for (int i = 0; i < 4; i++) {
        if (i < widget.questionToEdit!.options.length) {
          _optionControllers[i].text = widget.questionToEdit!.options[i];
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.questionToEdit != null ? 'Edit Question' : 'Add Question'),
      content: SizedBox(
        width: 600, // Make dialog wider
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _qTextController,
                decoration: InputDecoration(
                  labelText: 'Question Text', 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.05),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Options (Select correct answer):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
              ),
              const SizedBox(height: 12),
              ...List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _correctIndex == index ? Colors.green : Colors.grey.withValues(alpha: 0.3),
                      width: _correctIndex == index ? 2 : 1
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: _correctIndex == index ? Colors.green.withValues(alpha: 0.05) : Colors.white,
                  ),
                  child: RadioListTile<int>(
                    value: index,
                    groupValue: _correctIndex,
                    activeColor: Colors.green,
                    onChanged: (val) => setState(() => _correctIndex = val!),
                    title: TextFormField(
                      controller: _optionControllers[index],
                      decoration: InputDecoration(
                        hintText: 'Option ${index + 1}',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                        isDense: true,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_qTextController.text.isEmpty) return;
            if (_optionControllers.any((c) => c.text.isEmpty)) return;

            final q = Question(
              id: widget.questionToEdit?.id ?? const Uuid().v4(),
              text: _qTextController.text,
              options: _optionControllers.map((c) => c.text).toList(),
              correctOptionIndex: _correctIndex,
            );
            widget.onSave(q);
            Navigator.pop(context);
          },
          child: Text(widget.questionToEdit != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
