import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/quiz_model.dart';
import '../../models/result_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/quiz_app_bar.dart';
import '../../widgets/skeleton_quiz_card.dart';
import '../../widgets/adaptive_layout.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}



 class _StudentDashboardState extends State<StudentDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedIndex = 0;
  String _searchQuery = '';
  String _sortOption = 'Title (A-Z)';

  void _onNavTapped(int index) {
      if (index == _selectedIndex) return;
      setState(() => _selectedIndex = index);
      switch (index) {
        case 0: break; // Home
        case 1: context.push('/student/history'); break;
        case 2: context.push('/profile'); break;
      }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final theme = Theme.of(context);

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return AdaptiveLayout(
      currentIndex: _selectedIndex,
      onDestinationSelected: _onNavTapped,
      mobileAppBar: QuizAppBar(user: user),
      destinations: const [
        AdaptiveDestination(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Home'),
        AdaptiveDestination(icon: Icons.history_edu, selectedIcon: Icons.history_edu, label: 'History'),
        AdaptiveDestination(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
      ],
      body: StreamBuilder<List<QuizModel>>(
        stream: _firestoreService.getQuizzesForStudent(
          (user.metadata['classLevel'] ?? '').toString(),
          user.adminId ?? '',
        ),
        builder: (context, quizSnapshot) {
          
          // ------------------------------------------------
          // 1. Loading State
          // ------------------------------------------------
          if (quizSnapshot.connectionState == ConnectionState.waiting) {
             return CustomScrollView(
                slivers: [
                   _buildHeroSection(context, user),
                   _buildSearchSection(context),
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
          if (quizSnapshot.hasError) return Center(child: Text('Error: ${quizSnapshot.error}'));

          var quizzes = quizSnapshot.data ?? [];

          // ------------------------------------------------
          // 2. Client-Side Filtering & Sorting
          // ------------------------------------------------
          
          // Search
          if (_searchQuery.isNotEmpty) {
            quizzes = quizzes.where((q) => q.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          }

          // Sort
          if (_sortOption == 'Title (A-Z)') {
            quizzes.sort((a, b) => a.title.compareTo(b.title));
          } else if (_sortOption == 'Title (Z-A)') {
            quizzes.sort((a, b) => b.title.compareTo(a.title));
          } else if (_sortOption == 'Duration (Shortest)') {
            quizzes.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
          } else if (_sortOption == 'Duration (Longest)') {
            quizzes.sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));
          }

          // ------------------------------------------------
          // 3. Main Content & Result Filtering
          // ------------------------------------------------
          return StreamBuilder<List<ResultModel>>(
            stream: _firestoreService.getResultsForStudent(user.uid),
            builder: (context, resultSnapshot) {
              final results = resultSnapshot.data ?? [];
              // Only consider non-cancelled results as "Attempted" logic
              final validResults = results.where((r) => !r.isCancelled).toList();
              final attemptedQuizIds = validResults.map((r) => r.quizId).toSet();
              // Fallback for old data
              final attemptedQuizTitles = results.where((r) => r.quizId.isEmpty).map((r) => r.quizTitle).toSet();

              final availableQuizzes = quizzes.where((q) { 
                final isIdMatch = attemptedQuizIds.contains(q.id);
                final isTitleMatch = attemptedQuizTitles.contains(q.title);
                return !isIdMatch && !isTitleMatch;
              }).toList();

              return CustomScrollView(
                slivers: [
                  // Hero Section
                  _buildHeroSection(context, user),

                  // Controls
                  _buildSearchSection(context),

                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          Icon(Icons.play_circle_fill, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Available Quizzes',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${availableQuizzes.length} Active',
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Quiz Grid
                  if (availableQuizzes.isEmpty)
                     SliverToBoxAdapter(
                        child:Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_outline, size: 60, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  "You're all caught up!", 
                                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.grey[600])
                                ),
                                const SizedBox(height: 8),
                                const Text("No new quizzes available right now.", style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                     )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400, 
                          mainAxisExtent: 260, // Optimized height
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final quiz = availableQuizzes[index];
                            return _buildQuizCard(context, quiz);
                          },
                          childCount: availableQuizzes.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, dynamic user) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 40),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primaryContainer,
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Welcome back, ${user.name}!',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 28,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Ready to challenge yourself? Select an active quiz below.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                 decoration: InputDecoration(
                   hintText: 'Search quizzes...',
                   prefixIcon: const Icon(Icons.search),
                   // Theme takes care of the rest
                 ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortOption,
                  icon: const Icon(Icons.sort),
                  borderRadius: BorderRadius.circular(16),
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
    );
  }

  Widget _buildQuizCard(BuildContext context, QuizModel quiz) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'New',
                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'ID: ${quiz.id.substring(0, 4).toUpperCase()}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 10, letterSpacing: 1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              quiz.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold, 
                fontSize: 18,
                height: 1.2
              ),
            ),
            const Spacer(),
            Row(
              children: [
                _buildInfoBadge(context, Icons.timer_outlined, '${quiz.durationMinutes}m'),
                const SizedBox(width: 12),
                _buildInfoBadge(context, Icons.star_outline, '${quiz.totalMarks} pts'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary, 
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                ),
                onPressed: () => context.push('/attempt-quiz', extra: quiz),
                child: const Text('Start Quiz →', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBadge(BuildContext context, IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.grey[700]),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
