
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart'; // Ensure this exists or is handled
import 'providers/user_provider.dart';
import 'models/user_model.dart';
import 'models/quiz_model.dart';
import 'models/result_model.dart';
import 'screens/auth/login_screen.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const QuizApp());
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

class MainAppRouter extends StatelessWidget {
  const MainAppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch user provider to trigger redirects on auth state change
    final userProvider = context.watch<UserProvider>();

    final router = GoRouter(
      refreshListenable: userProvider,
      initialLocation: '/',
      redirect: (context, state) {
        final isLoggedIn = userProvider.isLoggedIn;
        final isLoggingIn = state.uri.toString() == '/login';
        final isAbout = state.uri.toString() == '/about';
        
        if (userProvider.isLoading) return null; // Or specific splash path

        if (!isLoggedIn) {
          return (isLoggingIn || isAbout) ? null : '/login';
        }

        // If logged in, prevent going to login, but allow About
        if (isLoggingIn) {
          return _getHomeRoute(userProvider.user?.role);
        }

        // Handle root redirect
        if (state.uri.toString() == '/') {
          return _getHomeRoute(userProvider.user?.role);
        }

        return null; // Allow navigation to other valid routes
      },
      routes: [
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
              path: 'results',
              builder: (context, state) {
                final quiz = state.extra as QuizModel;
                return QuizResultsScreen(quiz: quiz);
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
            final quiz = state.extra as QuizModel;
            return QuizAttemptScreen(quiz: quiz);
          },
        ),
        GoRoute(
          path: '/review-quiz',
          builder: (context, state) {
            final result = state.extra as ResultModel;
            return ReviewQuizScreen(result: result);
          },
        ),
      ],
      // Theme Configuration with Google Fonts & Material 3
    );

    if (userProvider.isLoading) {
      return const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }

    return MaterialApp.router(
      title: 'Quiz App',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4), // Deep Purple base
          brightness: Brightness.light,
          primary: const Color(0xFF6750A4),
          secondary: const Color(0xFF625B71),
          tertiary: const Color(0xFF7D5260),
          surface: const Color(0xFFFFFBFE),
          background: const Color(0xFFFFFBFE),
        ),
        textTheme: GoogleFonts.outfitTextTheme(), // Modern geometric sans
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent, // For slivers
        ),
        // cardTheme: CardTheme(
        //   elevation: 0, 
        //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        //   color: const Color(0xFFF3F0F5), 
        //   margin: const EdgeInsets.symmetric(vertical: 8),
        // ),
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
        return '/login'; // Or an error page
    }
  }
}
