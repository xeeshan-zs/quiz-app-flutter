import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/quiz_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  String _searchQuery = '';
  String _sortOption = 'Title (A-Z)';

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: StreamBuilder<List<QuizModel>>(
        stream: firestoreService.getAllQuizzes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          }

          var allQuizzes = snapshot.data ?? [];
          var myQuizzes = allQuizzes.where((q) => q.createdByUid == user?.uid).toList();
          final activeCount = myQuizzes.where((q) => !q.isPaused).length;

          // Search
          if (_searchQuery.isNotEmpty) {
            myQuizzes = myQuizzes.where((q) => q.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          }

          // Sort
          if (_sortOption == 'Title (A-Z)') {
            myQuizzes.sort((a, b) => a.title.compareTo(b.title));
          } else if (_sortOption == 'Title (Z-A)') {
            myQuizzes.sort((a, b) => b.title.compareTo(a.title));
          } else if (_sortOption == 'Duration (Shortest)') {
            myQuizzes.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
          } else if (_sortOption == 'Duration (Longest)') {
            myQuizzes.sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));
          }

          return CustomScrollView(
            slivers: [
              // Hero Section
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(32, 60, 32, 40),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1B2E), // Dark Navy/Purple equivalent for Light Mode context contrast
                    // Or keep it consistent with Light Theme using Primary:
                    // color: Theme.of(context).colorScheme.primaryContainer, 
                    // But user asked to "look like this" (dark dashboard). 
                    // However, previous prompt said "use current color scheme".
                    // I will use a Dark Primary container to capture the "Dashboard" feel while respecting the app's palette density.
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2E236C), // Deep Purple
                        Color(0xFF433D8B),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Bar Area
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                               Icon(Icons.lightbulb_outline, color: Colors.white, size: 28),
                               SizedBox(width: 8),
                               Text('QuizApp', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {}, 
                                icon: const Icon(Icons.dashboard, color: Colors.white70), 
                                label: const Text('Dashboard', style: TextStyle(color: Colors.white70))
                              ),
                              const SizedBox(width: 16),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.redAccent, 
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => context.read<UserProvider>().logout(),
                                icon: const Icon(Icons.logout, size: 18),
                                label: const Text('Logout'),
                              ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 40),
                      
                      // Dashboard Main Content
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Teacher Dashboard',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Manage your quizzes, track student performance, and create new assessments.',
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    _buildStatBadge(Icons.play_circle_fill, '$activeCount Active Quizzes'),
                                    const SizedBox(width: 12),
                                    _buildStatBadge(Icons.library_books, '${myQuizzes.length} Total'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Create Button (Big)
                           ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6), // Bright Purple
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                elevation: 8,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: () => context.push('/teacher/create-quiz'),
                              icon: const Icon(Icons.add, size: 24), 
                              label: const Text('Create New Quiz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                           ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Search Control
              SliverToBoxAdapter(
                 child: Padding(
                   padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                   child: Row(
                     children: [
                       Expanded(
                         child: TextField(
                           onChanged: (val) => setState(() => _searchQuery = val),
                           decoration: InputDecoration(
                             hintText: 'Search your quizzes...',
                             prefixIcon: const Icon(Icons.search),
                             filled: true,
                             fillColor: Colors.white,
                             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                             border: OutlineInputBorder(
                               borderRadius: BorderRadius.circular(12),
                               borderSide: BorderSide.none,
                             ),
                             enabledBorder: OutlineInputBorder(
                               borderRadius: BorderRadius.circular(12),
                               borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                             ),
                           ),
                         ),
                       ),
                       const SizedBox(width: 16),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12),
                         decoration: BoxDecoration(
                           color: Colors.white,
                           borderRadius: BorderRadius.circular(12),
                           border: Border.all(color: Colors.grey.withOpacity(0.1)),
                         ),
                         child: DropdownButtonHideUnderline(
                           child: DropdownButton<String>(
                             value: _sortOption,
                             icon: const Icon(Icons.sort),
                             borderRadius: BorderRadius.circular(12),
                             items: ['Title (A-Z)', 'Title (Z-A)', 'Duration (Shortest)', 'Duration (Longest)']
                                 .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                                 .toList(),
                             onChanged: (val) {
                               if (val != null) setState(() => _sortOption = val);
                             },
                           ),
                         ),
                       ),
                     ],
                   ),
                 ),
              ),

              // Title
               SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
                  child: Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 28),
                      const SizedBox(width: 12),
                      Text('Your Quizzes', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('${myQuizzes.length} found', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
              ),

              // Grid
              if (myQuizzes.isEmpty)
                 const SliverToBoxAdapter(
                   child: Padding(
                     padding: EdgeInsets.all(40),
                     child: Center(child: Text('No quizzes found.')),
                   ),
                 )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      mainAxisExtent: 260,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildQuizCard(context, myQuizzes[index], firestoreService);
                      },
                      childCount: myQuizzes.length,
                    ),
                  ),
                ),
                
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildQuizCard(BuildContext context, QuizModel quiz, FirestoreService service) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: quiz.isPaused ? Colors.grey.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    quiz.isPaused ? 'Paused' : 'Active',
                    style: TextStyle(
                      color: quiz.isPaused ? Colors.grey[700] : Colors.green[700], 
                      fontSize: 12, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'edit') {
                      context.push('/teacher/create-quiz', extra: quiz);
                    } else if (value == 'delete') {
                      showDialog(
                        context: context, 
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Quiz'),
                          content: const Text('Are you sure you want to delete this quiz? This action cannot be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () {
                                service.deleteQuiz(quiz.id);
                                Navigator.pop(context);
                              }, 
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Delete')
                            ),
                          ],
                        )
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              quiz.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Info Row
            Row(
              children: [
                _buildInfoPill(Icons.access_time, '${quiz.durationMinutes} m'),
                const SizedBox(width: 8),
                _buildInfoPill(Icons.emoji_events_outlined, '${quiz.totalMarks} pts'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
               width: double.infinity,
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
               decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Row(
                 children: [
                   const Icon(Icons.people_outline, size: 16, color: Colors.grey),
                   const SizedBox(width: 8),
                   Text(
                     quiz.questions.isNotEmpty ? 'Class: ${quiz.questions.length} Qs' : 'No Data', 
                     style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)
                   ),
                 ],
               ),
            ),
            const Spacer(),
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.cyan,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 0), // Compact
                      minimumSize: const Size(0, 36)
                    ),
                    onPressed: () => context.push('/teacher/results', extra: quiz),
                    icon: const Icon(Icons.bar_chart, size: 16),
                    label: const Text('Results'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 0),
                      minimumSize: const Size(0, 36)
                    ),
                    onPressed: () => service.toggleQuizStatus(quiz.id, quiz.isPaused),
                    icon: Icon(quiz.isPaused ? Icons.play_arrow : Icons.pause, size: 16),
                    label: Text(quiz.isPaused ? 'Resume' : 'Pause'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
       decoration: BoxDecoration(
         color: const Color(0xFF2C2C35).withValues(alpha: 0.05), // Subtle grey
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: Colors.black12),
       ),
       child: Row(
         children: [
           Icon(icon, size: 14, color: Colors.amber[800]),
           const SizedBox(width: 6),
           Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
         ],
       ),
    );
  }
}
