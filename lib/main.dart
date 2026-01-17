
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart'; // Ensure this exists or is handled
import 'providers/user_provider.dart';
import 'models/user_model.dart';
import 'models/quiz_model.dart';
import 'models/result_model.dart';
import 'services/firestore_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/landing_page.dart';
import 'screens/about_us_screen.dart';
import 'screens/dashboards.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/student/quiz_attempt_screen.dart';
import 'screens/student/review_quiz_screen.dart';
import 'screens/student/grade_history_screen.dart';
import 'screens/teacher/teacher_dashboard.dart';
import 'screens/teacher/create_quiz_screen.dart';
import 'screens/teacher/quiz_results_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/super_admin/super_admin_dashboard.dart';
import 'screens/admin/all_quizzes_screen.dart';
import 'screens/common/profile_screen.dart';
import 'screens/common/user_guide_screen.dart';
import 'screens/common/contact_us_screen.dart';
import 'screens/common/our_app_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const QuizApp());
  } catch (e, stackTrace) {
    debugPrint('Firebase initialization failed: $e');
    debugPrint(stackTrace.toString());
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()..loadUser()),
      ],
      child: const MainAppRouter(),
    );
  }
}

class MainAppRouter extends StatefulWidget {
  const MainAppRouter({super.key});

  @override
  State<MainAppRouter> createState() => _MainAppRouterState();
}

class _MainAppRouterState extends State<MainAppRouter> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final userProvider = context.read<UserProvider>();
    
    // Check platform for initial location default
    bool isMobile = defaultTargetPlatform == TargetPlatform.android || 
                    defaultTargetPlatform == TargetPlatform.iOS;

    _router = GoRouter(
      refreshListenable: userProvider,
      initialLocation: isMobile ? '/login' : '/',
      debugLogDiagnostics: true, // Enable debug logs to see routing decisions
      redirect: (context, state) {
        final isLoggedIn = userProvider.isLoggedIn;
        final path = state.uri.path;
        final isLoggingIn = path == '/login';
        final isAbout = path == '/about';
        final isRoot = path == '/';
        final isWelcome = path == '/welcome';

        // Wait for loading to finish before making decisions
        // Note: We handle the loading spinner in build(), but redirect might run.
        // If loading, returning null allows current path (or initial) to be processed? 
        // Actually if we redirect during loading, we might mess up. 
        // But if isLoading is true, build() shows Material app.
        if (userProvider.isLoading) return null;

        // 1. If Logged In, redirect Login -> Dashboard
        if (isLoggedIn && isLoggingIn) {
          return _getHomeRoute(userProvider.user?.role);
        }

        // 2. Allowed Public Paths (About, Welcome, Our App, Contact)
        final isPublic = isAbout || isWelcome || 
                         path == '/our-app' || 
                         path == '/contact';

        if (isPublic) return null;

        // 3. Root Handling
        // If Logged In at Root, redirect to Dashboard
        if (isRoot && isLoggedIn) {
           return _getHomeRoute(userProvider.user?.role);
        }
        
        // 4. If Guest at Root, stay at Root (Landing Page)
        if (isRoot && !isLoggedIn) return null;

        // 5. If Guest and not on public pages -> Login
        if (!isLoggedIn && !isLoggingIn && !isRoot) {
          return '/login';
        }

        return null; // Allow navigation
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LandingPage(),
        ),
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const LandingPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/about',
          builder: (context, state) => const AboutUsScreen(),
        ),
        GoRoute(
          path: '/super_admin',
          builder: (context, state) => const SuperAdminDashboard(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboard(),
        ),
        GoRoute(
          path: '/teacher',
          builder: (context, state) => const TeacherDashboard(),
          routes: [
            GoRoute(
              path: 'create-quiz',
              builder: (context, state) {
                final quizToEdit = state.extra as QuizModel?;
                return CreateQuizScreen(quizToEdit: quizToEdit);
              },
            ),
            GoRoute(
              path: 'results/:id',
              builder: (context, state) {
                final quiz = state.extra as QuizModel?;
                final quizId = state.pathParameters['id']!;
                
                if (quiz != null) return QuizResultsScreen(quiz: quiz);

                return QuizDataLoader(
                  quizId: quizId, 
                  builder: (quiz) => QuizResultsScreen(quiz: quiz)
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/student',
          builder: (context, state) => const StudentDashboard(),
          routes: [
            GoRoute(
              path: 'history',
              builder: (context, state) => const GradeHistoryScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/attempt-quiz',
          builder: (context, state) {
             final quiz = state.extra as QuizModel?;
             if (quiz == null) return const Scaffold(body: Center(child: Text('Error: Quiz data missing')));
             return QuizAttemptScreen(quiz: quiz);
          },
        ),
        GoRoute(
          path: '/review-quiz',
          builder: (context, state) {
            final result = state.extra as ResultModel?;
            if (result == null) return const Scaffold(body: Center(child: Text('Error: Result data missing')));
            return ReviewQuizScreen(result: result);
          },
        ),
        GoRoute(
          path: '/all-quizzes',
          builder: (context, state) {
             final canPause = (state.extra as bool?) ?? false;
             return AllQuizzesScreen(canPause: canPause);
          },
        ),
        GoRoute(
          path: '/quiz-results/:id',
          builder: (context, state) {
            final quiz = state.extra as QuizModel?;
            final quizId = state.pathParameters['id']!;
            
            if (quiz != null) return QuizResultsScreen(quiz: quiz);

            return QuizDataLoader(
              quizId: quizId, 
              builder: (quiz) => QuizResultsScreen(quiz: quiz)
            );
          },
        ),       
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/user-guide',
          builder: (context, state) => const UserGuideScreen(),
        ),
        GoRoute(
          path: '/our-app',
          builder: (context, state) => const OurAppScreen(),
        ),
        GoRoute(
          path: '/contact',
          builder: (context, state) => const ContactUsScreen(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    if (userProvider.isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp.router(
      title: 'EduSync',
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4), 
          brightness: Brightness.light,
          primary: const Color(0xFF6750A4),
          secondary: const Color(0xFF625B71),
          tertiary: const Color(0xFF7D5260),
          surface: const Color(0xFFFFFBFE),
          background: const Color(0xFFFFFBFE),
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6750A4), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  String _getHomeRoute(UserRole? role) {
    switch (role) {
      case UserRole.super_admin:
        return '/super_admin';
      case UserRole.admin:
        return '/admin';
      case UserRole.teacher:
        return '/teacher';
      case UserRole.student:
        return '/student';
      default:
        return '/login'; 
    }
  }
}

// -----------------------------------------------------------------------------
// HELPER: Quiz Data Loader (Handles Missing State on Reload/Deep Link)
// -----------------------------------------------------------------------------

class QuizDataLoader extends StatelessWidget {
  final String quizId;
  final Widget Function(QuizModel quiz) builder;

  const QuizDataLoader({super.key, required this.quizId, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<QuizModel?>(
        future: FirestoreService().getQuizById(quizId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading quiz: ${snapshot.error ?? "Not found"}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Go Home'),
                  ),
                ],
              ),
            );
          }
          return builder(snapshot.data!);
        },
      ),
    );
  }
}
