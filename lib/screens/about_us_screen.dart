import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_app_bar.dart';
import '../widgets/quiz_app_drawer.dart';
import '../services/firestore_service.dart';
import '../models/app_settings_model.dart';
import '../utils/icon_utils.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final firestoreTrace = FirestoreService();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: QuizAppBar(user: user, isTransparent: true),
      drawer: QuizAppDrawer(user: user),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Hero Section
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 120, 24, 40), 
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                   SizedBox(height: 20),
                   Text(
                     'Empowering Education',
                     style: TextStyle(
                       color: Colors.white,
                       fontSize: 32,
                       fontWeight: FontWeight.bold,
                     ),
                     textAlign: TextAlign.center,
                   ),
                   SizedBox(height: 16),
                   Text(
                     'EduSync is a comprehensive platform designed to streamline assessments and enhance learning outcomes for students and teachers alike.',
                     style: TextStyle(color: Colors.white70, fontSize: 16),
                     textAlign: TextAlign.center,
                   ),
                   SizedBox(height: 40),
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
              child: StreamBuilder<AppSettingsModel>(
                stream: firestoreTrace.getAppSettings(),
                builder: (context, snapshot) {
                  final teamName = snapshot.data?.teamName ?? 'Runtime Terrors';
                  return Row(
                    children: [
                       Icon(Icons.people_outline, color: Theme.of(context).colorScheme.primary),
                       const SizedBox(width: 8),
                       Expanded(
                         child: Text(
                           'Meet the $teamName Team',
                           style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                         ),
                       ),
                    ],
                  );
                }
              ),
            ),
          ),

          // Team Grid
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: StreamBuilder<List<TeamMemberModel>>(
              stream: firestoreTrace.getTeamMembers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                }
                
                final members = snapshot.data ?? [];
                
                if (members.isEmpty) {
                   return const SliverToBoxAdapter(child: Text('No team members found.'));
                }

                return SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 380, // Taller for avatars
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                       final member = members[index];
                       return _buildTeamCard(context, member, index);
                    },
                    childCount: members.length,
                  ),
                );
              },
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  static Widget _buildTeamCard(BuildContext context, TeamMemberModel member, int index) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          image: member.imageUrl.isNotEmpty 
            ? DecorationImage(
                image: NetworkImage(member.imageUrl),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              )
            : null,
          color: member.imageUrl.isEmpty ? Colors.grey.shade800 : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.1),
                Colors.black.withOpacity(0.7),
                Colors.black.withOpacity(0.95),
              ],
              stops: const [0.0, 0.4, 0.7, 1.0],
            ),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (member.imageUrl.isEmpty) ...[
                 Center(child: Text(member.name[0], style: const TextStyle(fontSize: 48, color: Colors.white24))),
                 const Spacer(),
              ] else 
                 const SizedBox(height: 120), // Spacer to push text down

              Text(
                member.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              if (member.role.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  member.role,
                  style: TextStyle(
                    color: Colors.blueAccent.shade100,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (member.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  member.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (member.socialLinks.isNotEmpty) ...[
                const SizedBox(height: 16),
                // Social Icons
                Row(
                  children: member.socialLinks.map((link) => _buildSocialIcon(link)).toList(),
                ),
              ]
            ],
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: 150 * index))
      .fadeIn(duration: 600.ms)
      .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutBack);
  }

  static Widget _buildSocialIcon(SocialLink link) {
    IconData icon = IconUtils.getIcon(link.iconKey);

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse(link.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}
