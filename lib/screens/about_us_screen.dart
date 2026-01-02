import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Hero Section
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1B2E),
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF2E236C),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       // Brand
                       const Row(
                         children: [
                           Icon(Icons.info_outline, color: Colors.white, size: 28),
                           SizedBox(width: 8),
                           Text(
                             'About QuizApp', 
                             style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                           ),
                         ],
                       ),
                       // Back Button
                       FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Back'),
                      ),
                    ],
                   ),
                   const SizedBox(height: 60),
                   const Text(
                     'Empowering Education',
                     style: TextStyle(
                       color: Colors.white,
                       fontSize: 32,
                       fontWeight: FontWeight.bold,
                     ),
                     textAlign: TextAlign.center,
                   ),
                   const SizedBox(height: 16),
                   const Text(
                     'QuizApp is a comprehensive platform designed to streamline assessments and enhance learning outcomes for students and teachers alike.',
                     style: TextStyle(color: Colors.white70, fontSize: 16),
                     textAlign: TextAlign.center,
                   ),
                   const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // About App Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Our Mission',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Our goal is to provide a seamless, secure, and engaging environment for online examinations. With features like real-time grading, detailed analytics, and role-based access control, we ensure that the focus remains on what matters most: learning.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ),

          // Meet the Team Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                   Icon(Icons.people_outline, color: Theme.of(context).colorScheme.primary),
                   const SizedBox(width: 8),
                   Text(
                     'Meet the Team',
                     style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                   ),
                ],
              ),
            ),
          ),

          // Team Grid
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400,
                mainAxisExtent: 380, // Taller for avatars
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              delegate: SliverChildListDelegate([
                 _buildTeamCard(
                   context, 
                   'Zeeshan Sarfraz', 
                   'Team Lead', 
                   'Visionary leader driving the project\'s success with strategic oversight and technical expertise.',
                   'C:/Users/Shani/.gemini/antigravity/brain/2cef3a18-322a-413c-8d90-55602bddb641/avatar_zeeshan_leader_1767188954581.png'
                 ),
                 _buildTeamCard(
                   context, 
                   'Muneeb Ali', 
                   'Backend Engineer', 
                   'Dedicated developer focused on backend stability, data integrity, and API performance.',
                   'C:/Users/Shani/.gemini/antigravity/brain/2cef3a18-322a-413c-8d90-55602bddb641/avatar_muneeb_backend_1767188974113.png'
                 ),
                 _buildTeamCard(
                   context, 
                   'Hammad Saleem', 
                   'Frontend Specialist', 
                   'Creative developer ensuring a seamless, responsive, and engaging user experience.',
                   'C:/Users/Shani/.gemini/antigravity/brain/2cef3a18-322a-413c-8d90-55602bddb641/avatar_hammad_frontend_1767189002065.png'
                 ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildTeamCard(BuildContext context, String name, String role, String description, String imagePath) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Icon(Icons.person, size: 60, color: Colors.grey));
              },
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.bold, 
                        color: Theme.of(context).colorScheme.primary
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2, end: 0);
  }
}
