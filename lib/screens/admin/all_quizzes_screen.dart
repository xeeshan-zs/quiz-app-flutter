import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/quiz_model.dart';
import '../../services/firestore_service.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/quiz_app_bar.dart';
import '../../widgets/quiz_app_drawer.dart';

class AllQuizzesScreen extends StatefulWidget {
  final bool canPause;

  const AllQuizzesScreen({super.key, required this.canPause});

  @override
  State<AllQuizzesScreen> createState() => _AllQuizzesScreenState();
}

class _AllQuizzesScreenState extends State<AllQuizzesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ScrollController _scrollController = ScrollController();
  
  final List<QuizModel> _quizzes = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchQuizzes();
    }
  }

  Future<void> _fetchQuizzes({bool refresh = false}) async {
    if (_isLoading) return;
    
    if (refresh) {
      if (mounted) {
        setState(() {
          _quizzes.clear();
          _lastDocument = null;
          _hasMore = true;
          _isLoading = true;
        });
      }
    } else {
      if (!_hasMore) return;
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final newQuizzes = await _firestoreService.getQuizzesPaginated(
        limit: 20,
        lastDocument: _lastDocument,
        searchQuery: _searchQuery,
      );

      DocumentSnapshot? newLastDoc;
      if (newQuizzes.isNotEmpty) {
        newLastDoc = await _firestoreService.getQuizDoc(newQuizzes.last.id);
      }

      if (mounted) {
        setState(() {
          if (newQuizzes.length < 20) _hasMore = false;
          if (newLastDoc != null) _lastDocument = newLastDoc;
          
          _quizzes.addAll(newQuizzes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _updateLastDoc(String id) async {
     _lastDocument = await _firestoreService.getQuizDoc(id);
  }

  void _onSearchChanged(String query) {
     // Debounce could be added here preferably, but for now direct call
     setState(() => _searchQuery = query);
     _fetchQuizzes(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: QuizAppBar(user: user, isTransparent: false),
      drawer: QuizAppDrawer(user: user),
      body: RefreshIndicator(
        onRefresh: () async => _fetchQuizzes(refresh: true),
        child: Column(
          children: [
            // Header title block with Search
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: const Color(0xFF2E236C).withOpacity(0.05),
              child: Column(
                children: [
                   Row(
                    children: [
                      Icon(widget.canPause ? Icons.settings_applications : Icons.assignment, color: const Color(0xFF2E236C)),
                      const SizedBox(width: 12),
                      Text(
                        widget.canPause ? 'Manage All Quizzes' : 'All Quizzes',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF2E236C)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search Quiz Title...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: (_quizzes.isEmpty && !_isLoading)
                ? const Center(
                    child: Text(
                      'No quizzes available.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(24),
                        sliver: SliverGrid(
                          gridDelegate: MediaQuery.of(context).size.width < 600 
                            ? const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 1,
                                mainAxisExtent: 240,
                                mainAxisSpacing: 20,
                              )
                            : const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 400,
                                mainAxisExtent: 240,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index >= _quizzes.length) {
                                return _hasMore 
                                  ? const Center(child: CircularProgressIndicator()) 
                                  : const SizedBox.shrink();
                              }

                              final quiz = _quizzes[index];
                              return _buildQuizCard(context, quiz, _firestoreService);
                            },
                            childCount: _quizzes.length + 1,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard(BuildContext context, QuizModel quiz, FirestoreService firestoreService) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Gradient decoration (subtle)
           Positioned(
            top: -20,
            right: -20,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF2E236C).withOpacity(0.05),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                       decoration: BoxDecoration(
                         color: quiz.isPaused ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                         borderRadius: BorderRadius.circular(20),
                       ),
                       child: Text(
                         quiz.isPaused ? 'Paused' : 'Active',
                         style: TextStyle(
                           color: quiz.isPaused ? Colors.red : Colors.green,
                           fontWeight: FontWeight.bold,
                           fontSize: 12,
                          ),
                       ),
                     ),
                     if (widget.canPause)
                       SizedBox(
                         height: 24,
                         child: Switch(
                           value: !quiz.isPaused, 
                           onChanged: (val) async {
                             await firestoreService.toggleQuizStatus(quiz.id, quiz.isPaused);
                             // Optimistic update or refresh? Refresh logic is safer but slower.
                             // Let's manually toggle in local list to avoid full refresh flicker
                             setState(() {
                               // Assuming QuizModel is immutable, replacing item in list
                               final index = _quizzes.indexWhere((q) => q.id == quiz.id);
                               if (index != -1) {
                                 // Create copy with toggled status
                                 // But QuizModel properties are final. Need copyWith or new instance.
                                 // Let's create new instance manually as copyWith might not exist.
                                 _quizzes[index] = QuizModel(
                                   id: quiz.id,
                                   title: quiz.title,
                                   createdByUid: quiz.createdByUid,
                                   createdAt: quiz.createdAt,
                                   totalMarks: quiz.totalMarks,
                                   durationMinutes: quiz.durationMinutes,
                                   isPaused: !quiz.isPaused,
                                   questions: quiz.questions,
                                 );
                               }
                             });
                           },
                           activeThumbColor: Colors.green,
                           inactiveTrackColor: Colors.red.withOpacity(0.3),
                         ),
                       ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  quiz.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'ID: ${quiz.id.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'monospace'),
                ),
                const Spacer(),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                           context.push('/quiz-results/${quiz.id}', extra: quiz);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E236C),
                          side: const BorderSide(color: Color(0xFF2E236C)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.analytics_outlined, size: 18),
                        label: const Text('Results'),
                      ),
                    ),
                    
                    if (context.read<UserProvider>().user?.role == UserRole.super_admin) ...[
                      const SizedBox(width: 8),
                      // Edit Button
                      IconButton(
                        onPressed: () => context.push('/teacher/create-quiz', extra: quiz),
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'Edit Quiz',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Delete Button
                      IconButton(
                        onPressed: () => _confirmDelete(context, quiz.id, firestoreService),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete Quiz',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String quizId, FirestoreService firestoreService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quiz'),
        content: const Text('Are you sure you want to delete this quiz? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await firestoreService.deleteQuiz(quizId);
              _fetchQuizzes(refresh: true); // Refresh list
              if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quiz deleted.')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
