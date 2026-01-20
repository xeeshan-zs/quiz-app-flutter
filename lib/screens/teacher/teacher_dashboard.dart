import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/quiz_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/quiz_app_bar.dart';
import '../../widgets/skeleton_quiz_card.dart'; // Ensure this matches actual path
import '../../widgets/adaptive_layout.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}



 class _TeacherDashboardState extends State<TeacherDashboard> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  String _sortOption = 'Title (A-Z)';

  void _onNavTapped(int index) {
      if (index == _selectedIndex) return;
      setState(() => _selectedIndex = index);
      switch (index) {
        case 0: break; // Dashboard
        case 1: context.push('/teacher/create-quiz'); break;
        case 2: context.push('/profile'); break;
      }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final firestoreService = FirestoreService();
    final isDesktop = MediaQuery.of(context).size.width >= 800; // Consistent with AdaptiveLayout

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AdaptiveLayout(
        currentIndex: _selectedIndex,
        onDestinationSelected: _onNavTapped,
        mobileAppBar: QuizAppBar(user: user),
        floatingActionButton: (!isDesktop && _selectedIndex == 0)
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/teacher/create-quiz'),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Create', style: TextStyle(color: Colors.white)),
                backgroundColor: Theme.of(context).colorScheme.primary,
              )
            : null,
        destinations: const [
          AdaptiveDestination(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Home'),
          AdaptiveDestination(icon: Icons.add_circle_outline, selectedIcon: Icons.add_circle, label: 'Create'),
          AdaptiveDestination(icon: Icons.person_outlined, selectedIcon: Icons.person, label: 'Profile'),
        ],
        body: StreamBuilder<List<QuizModel>>(
          stream: firestoreService.getQuizzesForAdmin(user.adminId ?? ''),
          builder: (context, snapshot) {
            
            // -----------------------------------------------------
            // 1. Loading State (Skeletons)
            // -----------------------------------------------------
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CustomScrollView(
                slivers: [
                   _buildHeroSection(context, 0, 0), // Placeholders
                   _buildControlsSection(context),
                   SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisExtent: 280,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => const SkeletonQuizCard(),
                          childCount: 4, 
                        ),
                      ),
                   ),
                ],
              );
            }
  
            if (snapshot.hasError) {
               return Center(child: Text('Error: ${snapshot.error}'));
            }
  
            // -----------------------------------------------------
            // 2. Data Processing & Filtering
            // -----------------------------------------------------
            var allQuizzes = snapshot.data ?? [];
            // Filter: Created by Me (since this is 'Your Quizzes')
            var myQuizzes = allQuizzes.where((q) => q.createdByUid == user.uid).toList();
            
            // Split Drafts vs Published
            var drafts = myQuizzes.where((q) => q.isDraft).toList();
            var published = myQuizzes.where((q) => !q.isDraft).toList();

            final activeCount = published.where((q) => !q.isPaused).length;
            final totalCount = published.length;
            final draftCount = drafts.length;

            // Search
            if (_searchQuery.isNotEmpty) {
              drafts = drafts.where((q) => q.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              published = published.where((q) => q.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
            }

            // Sort
            void sortQuizzes(List<QuizModel> list) {
              if (_sortOption == 'Title (A-Z)') {
                list.sort((a, b) => a.title.compareTo(b.title));
              } else if (_sortOption == 'Title (Z-A)') {
                list.sort((a, b) => b.title.compareTo(a.title));
              } else if (_sortOption == 'Duration (Shortest)') {
                list.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
              } else if (_sortOption == 'Duration (Longest)') {
                list.sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));
              }
            }
            sortQuizzes(drafts);
            sortQuizzes(published);

            // -----------------------------------------------------
            // 3. Main Content
            // -----------------------------------------------------
            return CustomScrollView(
              slivers: [
                // Hero Section
                _buildHeroSection(context, activeCount, totalCount),

                // Controls (Search & Sort)
                _buildControlsSection(context),

                if (drafts.isEmpty && published.isEmpty)
                   SliverToBoxAdapter(
                     child: Padding(
                       padding: const EdgeInsets.all(40),
                       child: Center(
                         child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                             const SizedBox(height: 16),
                             Text(
                               _searchQuery.isNotEmpty 
                                 ? 'No matches found.'
                                 : 'You haven\'t created any quizzes yet.',
                               style: TextStyle(color: Colors.grey[600]),
                             ),
                             if (_searchQuery.isEmpty) ...[
                               const SizedBox(height: 16),
                               FilledButton.icon(
                                 onPressed: () => context.push('/teacher/create-quiz'),
                                 icon: const Icon(Icons.add),
                                 label: const Text('Create Your First Quiz'),
                               ),
                             ],
                           ],
                         ),
                       ),
                     ),
                   ),

                // DRAFTS SECTION
                if (drafts.isNotEmpty) ...[
                   SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
                      child: Row(
                        children: [
                          Icon(Icons.edit_note, size: 24, color: Colors.orange),
                          const SizedBox(width: 12),
                          Text('Drafts', style: Theme.of(context).textTheme.headlineSmall),
                          const Spacer(),
                          Text('$draftCount drafts', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildQuizCard(context, drafts[index], firestoreService),
                        childCount: drafts.length,
                      ),
                    ),
                  ),
                ],

                // PUBLISHED SECTION
                if (published.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
                      child: Row(
                        children: [
                          Icon(Icons.grid_view_rounded, size: 24, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text('Published Quizzes', style: Theme.of(context).textTheme.headlineSmall),
                          const Spacer(),
                          Text('$totalCount published', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildQuizCard(context, published[index], firestoreService),
                        childCount: published.length,
                      ),
                    ),
                  ),
                ],
                  
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            );
          },
        ),
    );
  }

  // -----------------------------------------------------
  // Helper Widgets
  // -----------------------------------------------------

  Widget _buildHeroSection(BuildContext context, int active, int total) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(32, 120, 32, 40),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E), 
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary, // Deep Royal Purple from AppTheme
              theme.colorScheme.secondary, // Lighter Purple
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          boxShadow: [
             BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teacher Dashboard',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontSize: isDesktop ? 42 : 32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Manage your quizzes, track student performance, and create new assessments.',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildStatBadge(Icons.play_circle_fill, '$active Active'),
                          const SizedBox(width: 12),
                          _buildStatBadge(Icons.library_books, '$total Total'),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isDesktop)
                   ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => context.push('/teacher/create-quiz'),
                      icon: const Icon(Icons.add, size: 24), 
                      label: const Text('Create Quiz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                   ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlsSection(BuildContext context) {
    return SliverToBoxAdapter(
       child: Padding(
         padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
         child: Wrap(
           alignment: WrapAlignment.spaceBetween,
           crossAxisAlignment: WrapCrossAlignment.center,
           spacing: 16,
           runSpacing: 16,
           children: [
             Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 const Icon(Icons.list_alt, size: 28),
                 const SizedBox(width: 12),
                 Text('Quiz Directory', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
               ],
             ),
             
             Wrap(
               spacing: 12,
               runSpacing: 12,
               crossAxisAlignment: WrapCrossAlignment.center,
               children: [
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12),
                   decoration: BoxDecoration(
                     color: Colors.grey.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(20),
                   ),
                   child: DropdownButtonHideUnderline(
                     child: DropdownButton<String>(
                       value: _sortOption,
                       borderRadius: BorderRadius.circular(16),
                       items: ['Title (A-Z)', 'Title (Z-A)', 'Duration (Shortest)', 'Duration (Longest)']
                           .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))))
                           .toList(),
                       onChanged: (val) {
                         if (val != null) setState(() => _sortOption = val);
                       },
                     ),
                   ),
                 ),
                 Container(
                   constraints: const BoxConstraints(maxWidth: 250),
                   child: TextField(
                     onChanged: (val) => setState(() => _searchQuery = val),
                     decoration: InputDecoration(
                       hintText: 'Search quizzes...',
                       prefixIcon: const Icon(Icons.search),
                       filled: true,
                       fillColor: Colors.grey.withOpacity(0.1),
                       contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                     ),
                   ),
                 ),
               ],
             ),
           ],
         ),
       ),
    );
  }

  Widget _buildStatBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.amberAccent, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildQuizCard(BuildContext context, QuizModel quiz, FirestoreService service) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width <= 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(4, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/teacher/results/${quiz.id}', extra: quiz),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: isSmallScreen
               ? Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       children: [
                         Container(
                           width: 48, height: 48,
                           decoration: BoxDecoration(
                             color: _getStatusColor(quiz).withOpacity(0.1),
                             borderRadius: BorderRadius.circular(16),
                           ),
                           child: Icon(Icons.assignment_rounded, color: _getStatusColor(quiz), size: 24),
                         ),
                         const SizedBox(width: 16),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(quiz.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                               const SizedBox(height: 4),
                               Text('${quiz.durationMinutes} mins • ${quiz.totalMarks} pts', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                             ],
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 16),
                     const Divider(height: 1),
                     const SizedBox(height: 16),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                          _buildQuizStatusBadge(quiz),
                          Row(
                             children: [
                               IconButton(
                                 icon: Icon(quiz.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.orange),
                                 tooltip: quiz.isPaused ? 'Resume' : 'Pause',
                                 onPressed: () => service.toggleQuizStatus(quiz.id, quiz.isPaused),
                               ),
                               IconButton(
                                 icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                                 tooltip: 'Edit',
                                 onPressed: () => context.push('/teacher/create-quiz', extra: quiz),
                               ),
                               IconButton(
                                 icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                 onPressed: () => _showDeleteDialog(context, service, quiz),
                               ),
                            ],
                         ),
                       ],
                     ),
                   ],
               )
               : Row(
                   children: [
                     Container(
                       width: 48, height: 48,
                       decoration: BoxDecoration(
                         color: _getStatusColor(quiz).withOpacity(0.1),
                         borderRadius: BorderRadius.circular(16),
                       ),
                       child: Icon(Icons.assignment_rounded, color: _getStatusColor(quiz), size: 24),
                     ),
                     const SizedBox(width: 20),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(quiz.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                           const SizedBox(height: 4),
                           Text('${quiz.questions.length} Questions • ${quiz.durationMinutes} mins • ${quiz.totalMarks} pts', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                         ],
                       ),
                     ),
                     const SizedBox(width: 20),
                     _buildQuizStatusBadge(quiz),
                     const SizedBox(width: 24),
                     Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            IconButton(
                              icon: Icon(quiz.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.orange),
                              tooltip: quiz.isPaused ? 'Resume' : 'Pause',
                              onPressed: () => service.toggleQuizStatus(quiz.id, quiz.isPaused),
                            ),
                            IconButton(
                               icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                               tooltip: 'Edit',
                               onPressed: () => context.push('/teacher/create-quiz', extra: quiz),
                            ),
                            IconButton(
                               icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                               onPressed: () => _showDeleteDialog(context, service, quiz),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.tonal(
                               style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1), 
                                  foregroundColor: theme.colorScheme.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                               ),
                               onPressed: () => context.push('/teacher/results/${quiz.id}', extra: quiz),
                               child: const Text('Results'),
                            ),
                        ],
                     ),
                   ],
               ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizStatusBadge(QuizModel quiz) {
    Color color = _getStatusColor(quiz);
    String text = quiz.isDraft ? 'DRAFT' : (quiz.isPaused ? 'PAUSED' : 'ACTIVE');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Color _getStatusColor(QuizModel quiz) {
     if (quiz.isDraft) return Colors.orange;
     if (quiz.isPaused) return Colors.grey;
     return Colors.green;
  }

  Widget _buildInfoIcon(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, FirestoreService service, QuizModel quiz) {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text('Delete Quiz'),
        content: const Text('Are you sure you want to delete this quiz? This action cannot be undone and will remove all associated results.'),
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
}
