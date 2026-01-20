import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/quiz_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/quiz_app_bar.dart';
import '../../widgets/quiz_app_drawer.dart';

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

  final List<String> _availableClasses = [];
  String? _selectedClass;
  bool _isLoadingClasses = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    if (widget.quizToEdit != null) {
      _titleController.text = widget.quizToEdit!.title;
      _durationController.text = widget.quizToEdit!.durationMinutes.toString();
      _marksController.text = widget.quizToEdit!.totalMarks.toString();
      _questions.addAll(widget.quizToEdit!.questions);
      _selectedClass = widget.quizToEdit!.classLevel;
    }
  }

  Future<void> _loadClasses() async {
    try {
      if (!mounted) return;
      // Use microtask to access provider safely
      await Future.microtask(() async {
         final user = context.read<UserProvider>().user;
         List<String> loadedClasses = [];

         if (user != null) {
             if (user.role == UserRole.admin || user.role == UserRole.super_admin) {
                 // Admin uses their own subscribed classes
                 loadedClasses = List.from(user.subscribedClasses);
             } else if (user.role == UserRole.teacher) {
                 // Teacher uses THEIR OWN assigned classes from metadata
                 // This list is populated by the Admin via EditUserDialog
                 if (user.subscribedClasses.isNotEmpty) {
                    loadedClasses = List.from(user.subscribedClasses);
                 } else {
                    // If Teacher has NO classes assigned, they should probably see NOTHING,
                    // or default to nothing. 
                    // Fetching Admin's list would defeat the purpose of "restriction".
                    // However, if we want to support "Default = All", we'd check that here,
                    // but the requirement is Strict Filtering.
                    // So we leave loadedClasses empty, which triggers the "No allowed classes" warning.
                 }
             }
         }

         // Fallback logic
         // Only fallback to global settings if we are in a context where that makes sense (e.g. maybe SuperAdmin failure)
         // OR if we decide that "Empty List" means "Broken Config" rather than "Restricted Access".
         // For now, if a Teacher has empty list, we do NOT fallback to globals, we show empty.
         // BUT, for Admins, if they have empty list, it means they rely on globals.
         if (loadedClasses.isEmpty && user?.role == UserRole.admin) {
           final settings = await FirestoreService().getAppSettings().first;
           loadedClasses = List.from(settings.availableClasses);
         }

         if (mounted) {
           setState(() {
             _availableClasses.clear();
             _availableClasses.addAll(loadedClasses);
             
             // If editing an old quiz with a class that is no longer in the allowed list,
             // we should probably add it temporarily so the UI doesn't break, 
             // OR force valid selection. Adding it safest for display.
             if (_selectedClass != null && !_availableClasses.contains(_selectedClass)) {
               _availableClasses.add(_selectedClass!);
             }
             _isLoadingClasses = false;
           });
         }
      });
    } catch (e) {
      debugPrint('Error loading classes: $e');
      if (mounted) setState(() => _isLoadingClasses = false);
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

  Future<void> _submitQuiz({bool isDraft = false}) async {
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
        isDraft: isDraft,
        adminId: widget.quizToEdit?.adminId ?? user?.adminId, // Preserve existing or use current
        classLevel: _selectedClass ?? user?.metadata['classLevel']?.toString(),
      );

      await FirestoreService().createQuiz(quiz); 
      
      if (mounted) {
         final message = isDraft ? 'Quiz Saved as Draft!' : (widget.quizToEdit != null ? 'Quiz Updated!' : 'Quiz Published!');
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  Widget _buildMinimalTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 22, color: Colors.grey[700]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(color: Colors.grey[600]),
        ),
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
    );
  }

  // --- WIDGET FRAGMENTS ---
  
  Widget _buildMetadataCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(4, 8)),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             children: [
               Icon(Icons.settings_rounded, color: Theme.of(context).primaryColor),
               const SizedBox(width: 12),
               const Text('Quiz Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
             ],
           ),
           const SizedBox(height: 24),
           
           _buildMinimalTextField(controller: _titleController, label: 'Quiz Title', icon: Icons.title_rounded),
           const SizedBox(height: 20),
           
           // Class Dropdown
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 16),
             decoration: BoxDecoration(
               color: Colors.grey.withOpacity(0.05),
               borderRadius: BorderRadius.circular(16),
             ),
             child: _isLoadingClasses 
                ? const SizedBox(height: 50, child: Center(child: LinearProgressIndicator()))
                : DropdownButtonFormField<String>(
                   value: (_availableClasses.contains(_selectedClass)) ? _selectedClass : null,
                   decoration: const InputDecoration(
                     labelText: 'Target Class',
                     prefixIcon: Icon(Icons.class_rounded),
                     border: InputBorder.none,
                   ),
                   items: _availableClasses.map((cls) {
                     return DropdownMenuItem(value: cls, child: Text(cls));
                   }).toList(),
                   onChanged: (val) => setState(() => _selectedClass = val),
                   validator: (v) => v == null ? 'Please select a class' : null,
                 ),
           ),
           const SizedBox(height: 20),

           Row(
             children: [
               Expanded(child: _buildMinimalTextField(
                 controller: _durationController, 
                 label: 'Duration (Min)', 
                 icon: Icons.timer_rounded,
                 isNumber: true
               )),
               const SizedBox(width: 20),
               Expanded(child: _buildMinimalTextField(
                 controller: _marksController, 
                 label: 'Total Marks', 
                 icon: Icons.emoji_events_rounded,
                 isNumber: true
               )),
             ],
           ),
           
           // Warning if no classes allowed
           if (!_isLoadingClasses && _availableClasses.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text("No allowed classes found. Contact Admin.", style: TextStyle(color: Colors.orange[800], fontSize: 13))),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList(BuildContext context) {
      if (_questions.isEmpty) {
        return Container(
          height: 300,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withOpacity(0.5),
            border: Border.all(color: Colors.grey.withOpacity(0.1), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.quiz_outlined, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('Start by adding your first question!', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _addOrEditQuestion(),
                icon: const Icon(Icons.add),
                label: const Text('Add Question'),
              )
            ],
          ),
        );
      }

      return Column(
        children: [
           ..._questions.asMap().entries.map((entry) {
            final index = entry.key;
            final q = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                   BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(4, 8)),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: Container(
                  width: 40, height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                ),
                title: Text(q.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Correct: ${q.options.isNotEmpty && q.correctOptionIndex < q.options.length ? q.options[q.correctOptionIndex] : "Invalid"}',
                  style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
                      onPressed: () => _addOrEditQuestion(questionToEdit: q, index: index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
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
          
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _addOrEditQuestion(),
            icon: const Icon(Icons.add),
            label: const Text('Add Another Question'),
             style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
             ),
          ),
          const SizedBox(height: 80), // Space for bottom bar
        ],
      );
  }

  Widget _buildBottomBar(BuildContext context) {
      final isEditing = widget.quizToEdit != null;
      return Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
          ]
        ),
        child: SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
                onPressed: _isSubmitting ? null : () => _submitQuiz(isDraft: true),
                child: _isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Text('Save as Draft', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32)
                ),
                onPressed: _isSubmitting ? null : () => _submitQuiz(isDraft: false),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEditing ? 'Update & Publish' : 'Publish Quiz', style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    
    return Scaffold(
      backgroundColor: Colors.grey[50], // Slightly off-white background
      appBar: QuizAppBar(user: user, isTransparent: false),
      drawer: QuizAppDrawer(user: user),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // DESKTOP LAYOUT
            if (constraints.maxWidth > 900) {
                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                // Left Panel: Metadata
                                Expanded(
                                    flex: 4,
                                    child: SingleChildScrollView(child: _buildMetadataCard(context)),
                                ),
                                const SizedBox(width: 32),
                                // Right Panel: Questions
                                Expanded(
                                    flex: 6,
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            Text('Questions (${_questions.length})', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 16),
                                            Expanded(
                                                child: SingleChildScrollView(
                                                    child: _buildQuestionsList(context),
                                                ),
                                            ),
                                        ],
                                    ),
                                ),
                            ],
                        ),
                      ),
                    ),
                    _buildBottomBar(context),
                  ],
                );
            }

            // MOBILE / TABLET LAYOUT
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildMetadataCard(context),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Questions (${_questions.length})', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildQuestionsList(context),
                    ],
                  ),
                ),
                _buildBottomBar(context),
              ],
            );
          }
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
                  fillColor: Colors.grey.withOpacity(0.05),
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
                      color: _correctIndex == index ? Colors.green : Colors.grey.withOpacity(0.3),
                      width: _correctIndex == index ? 2 : 1
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: _correctIndex == index ? Colors.green.withOpacity(0.05) : Colors.white,
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
