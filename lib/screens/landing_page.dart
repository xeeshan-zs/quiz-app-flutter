import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_app_bar.dart';
import '../widgets/quiz_app_drawer.dart';
import '../services/firestore_service.dart';
import '../models/app_settings_model.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isLoggedIn = userProvider.isLoggedIn;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: QuizAppBar(user: userProvider.user),
      drawer: QuizAppDrawer(user: userProvider.user),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 800;
          
          return Stack(
            children: [
              // Background Elements
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E1B2E), Color(0xFF2E236C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              // Animated Blobs (Hidden on mobile for performance/clutter)
              if (!isMobile) ...[
                Positioned(
                  top: -100,
                  right: -100,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Colors.purpleAccent.withOpacity(0.2), Colors.transparent],
                      ),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .scale(duration: 4.seconds, begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
                ),
                Positioned(
                  bottom: 100,
                  left: -50,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Colors.blueAccent.withOpacity(0.2), Colors.transparent],
                      ),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .moveY(duration: 5.seconds, begin: 0, end: 50),
                ),
              ],

              // Scrollable Content
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Hero Section with Curve
                    ClipPath(
                      clipper: _HeroClipper(),
                      child: Container(
                        constraints: BoxConstraints(minHeight: isMobile ? 500 : 700),
                        padding: EdgeInsets.fromLTRB(24, isMobile ? 100 : 140, 24, 100),
                        decoration: BoxDecoration(
                           gradient: LinearGradient(
                            colors: [
                              const Color(0xFF2E236C).withOpacity(0.8), 
                              const Color(0xFF433D8B).withOpacity(0.8)
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                 Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                                    ]
                                  ),
                                  child: const Text(
                                    '✨ The Future of Learning is Here',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 1),
                                  ),
                                ).animate().fadeIn().slideY(begin: -0.5, end: 0),
                                const SizedBox(height: 32),
                                Text(
                                  'Master knowledge with\nEduSync Smart Quizzes',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: isMobile ? 40 : 56,
                                    height: 1.1,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                                    ]
                                  ),
                                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                                const SizedBox(height: 24),
                                Text(
                                  'Join thousands of students and teachers in the ultimate quiz platform.\nCreating, taking, and tracking quizzes has never been easier.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isMobile ? 16 : 18,
                                    height: 1.6,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ).animate().fadeIn(delay: 400.ms),
                                const SizedBox(height: 48),
                                
                                // Action Buttons
                                Wrap(
                                  spacing: 20,
                                  runSpacing: 20,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    if (!isLoggedIn)
                                      _buildShinyButton(
                                        label: 'Get Started', 
                                        onTap: () => context.go('/login'),
                                        isPrimary: true
                                      )
                                    else
                                      _buildShinyButton(
                                        label: 'Dashboard', 
                                        onTap: () => _navigateToDashboard(context, userProvider.user?.role),
                                        isPrimary: true,
                                        icon: Icons.dashboard_rounded
                                      ),
                                    
                                    _buildShinyButton(
                                      label: 'Learn More', 
                                      onTap: () {
                                        // Scroll down or go to about
                                        context.push('/about');
                                      },
                                      isPrimary: false
                                    ),
                                  ],
                                ).animate().scale(delay: 600.ms),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Features Section
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            children: [
                              Text(
                                'Why Choose EduSync?',
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile ? 28 : 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 60),
                              Wrap(
                                spacing: 40,
                                runSpacing: 40,
                                alignment: WrapAlignment.center,
                                children: [
                                  _buildGlassFeatureCard(
                                    icon: Icons.bolt_rounded,
                                    title: 'Fast & Responsive',
                                    description: 'Lightning fast performance on any device, anywhere.',
                                    color: Colors.amberAccent,
                                    delay: 0,
                                    width: isMobile ? constraints.maxWidth : 320,
                                  ),
                                  _buildGlassFeatureCard(
                                    icon: Icons.check_circle_outline_rounded,
                                    title: 'Instant Results',
                                    description: 'Get immediate feedback on your performance and review answers.',
                                    color: Colors.cyanAccent,
                                    delay: 100,
                                    width: isMobile ? constraints.maxWidth : 320,
                                  ),
                                  _buildGlassFeatureCard(
                                    icon: Icons.security_rounded,
                                    title: 'Secure & Reliable',
                                    description: 'Enterprise-grade security for your assessments.',
                                    color: Colors.greenAccent,
                                    delay: 200,
                                    width: isMobile ? constraints.maxWidth : 320,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Footer
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 60, horizontal: isMobile ? 24 : 40),
                      color: Colors.black26,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: Column(
                            children: [
                              isMobile 
                              ? Column( // Stack vertically on mobile
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildBrandColumn(),
                                    const SizedBox(height: 40),
                                    _buildQuickLinks(context),
                                    const SizedBox(height: 40),
                                    _buildContactInfo(),
                                  ],
                                )
                              : Wrap(
                                spacing: 60,
                                runSpacing: 40,
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.start,
                                children: [
                                  SizedBox(width: 250, child: _buildBrandColumn()),
                                  _buildQuickLinks(context),
                                  _buildContactInfo(),
                                ],
                              ),
                              const SizedBox(height: 60),
                              const Divider(color: Colors.white12),
                              const SizedBox(height: 32),
                                StreamBuilder<AppSettingsModel>(
                                  stream: FirestoreService().getAppSettings(),
                                  builder: (context, snapshot) {
                                    final teamName = snapshot.data?.teamName ?? 'Runtime Terrors';
                                    return Text(
                                      '© 2026 EduSync. Developed by $teamName.',
                                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                                      textAlign: TextAlign.center,
                                    );
                                  }
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildBrandColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse('https://quiz-flutter.netlify.app/');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, webOnlyWindowName: '_blank');
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Row(
              children: [
                const Icon(Icons.school_rounded, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Text(
                  'EduSync',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Empowering education through smart, secure, and seamless assessments.',
          style: TextStyle(color: Colors.white.withOpacity(0.6), height: 1.5),
        ),
      ],
    );
  }

  Widget _buildQuickLinks(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Links', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 20),
        _FooterLink(label: 'Home', onTap: () => context.go('/welcome')),
        const SizedBox(height: 12),
        _FooterLink(label: 'About Us', onTap: () => context.go('/about')),
        const SizedBox(height: 12),
        _FooterLink(label: 'Contact Support', onTap: () => context.push('/contact')),
      ],
    );
  }

  Widget _buildContactInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contact Us', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.email_outlined, color: Colors.white.withOpacity(0.7), size: 18),
            const SizedBox(width: 8),
            Text('zeeshan303.3.1@gmail.com', style: TextStyle(color: Colors.white.withOpacity(0.6))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.phone_outlined, color: Colors.white.withOpacity(0.7), size: 18),
            const SizedBox(width: 8),
            Text('+92 310 9233844', style: TextStyle(color: Colors.white.withOpacity(0.6))),
          ],
        ),
      ],
    );
  }

  Widget _buildShinyButton({required String label, required VoidCallback onTap, bool isPrimary = true, IconData? icon}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: isPrimary 
            ? const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)])
            : LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
          border: isPrimary ? null : Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: isPrimary 
            ? [
                BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))
              ]
            : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, color: Colors.white), const SizedBox(width: 12)],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required int delay,
    double? width,
  }) {
    return Container(
      width: width ?? 320,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: delay)).fadeIn().slideY(begin: 0.2, end: 0);
  }

  void _navigateToDashboard(BuildContext context, dynamic role) {
     final r = role.toString();
     if (r.contains('student')) {
       context.go('/student');
     } else if (r.contains('teacher')) context.go('/teacher');
     else if (r.contains('super_admin')) context.go('/super_admin');
     else if (r.contains('admin')) context.go('/admin');
     else context.go('/login');
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(color: Colors.white.withOpacity(0.7)),
      ),
    );
  }
}

class _HeroClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 50);
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 50);
    var secondControlPoint = Offset(size.width * 3 / 4, size.height - 100);
    var secondEndPoint = Offset(size.width, size.height - 50);

    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
