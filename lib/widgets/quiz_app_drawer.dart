import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/user_model.dart';
// For UserRole

class QuizAppDrawer extends StatelessWidget {
  final UserModel? user;

  const QuizAppDrawer({super.key, required this.user});

  @override
  @override
  Widget build(BuildContext context) {
    // Removed early return to allow drawer for guests

    return Drawer(
      child: Column(
        children: [
          if (user != null)
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                 gradient: LinearGradient(
                    colors: [Color(0xFF2E236C), Color(0xFF433D8B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
              ),
              accountName: Text(user!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: Text(user!.email),
              currentAccountPicture: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/profile');
                },
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: user!.photoUrl != null && user!.photoUrl!.isNotEmpty
                      ? NetworkImage(user!.photoUrl!)
                      : null,
                  child: user!.photoUrl == null || user!.photoUrl!.isEmpty
                      ? Text(
                          user!.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2E236C)),
                        )
                      : null,
                ),
              ),
            )
          else
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E236C), Color(0xFF433D8B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.school_rounded, size: 48, color: Colors.white),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.go('/login');
                        },
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Login'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2E236C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          if (user != null)
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('My Profile'),
            selected: GoRouterState.of(context).uri.path == '/profile',
            selectedColor: Colors.deepPurple,
            onTap: () {
              Navigator.pop(context); 
              context.push('/profile');
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.home_rounded),
            title: const Text('Home'),
            selected: GoRouterState.of(context).uri.path == '/welcome' || GoRouterState.of(context).uri.path == '/',
            selectedColor: Colors.deepPurple,
            onTap: () {
              Navigator.pop(context); 
              context.go('/welcome');
            },
          ),

          if (user != null)
          ListTile(
            leading: const Icon(Icons.dashboard_rounded),
            title: const Text('Dashboard'),
            selected: (GoRouterState.of(context).uri.path.startsWith('/student') && !GoRouterState.of(context).uri.path.contains('history')) ||
                      (GoRouterState.of(context).uri.path.startsWith('/teacher') && !GoRouterState.of(context).uri.path.contains('create-quiz')) ||
                      GoRouterState.of(context).uri.path.startsWith('/admin') ||
                      GoRouterState.of(context).uri.path.startsWith('/super_admin'),
            selectedColor: Colors.deepPurple,
            onTap: () {
              Navigator.pop(context); // Close drawer
               if (user!.role == UserRole.student) context.go('/student');
               if (user!.role == UserRole.teacher) context.go('/teacher');
               if (user!.role == UserRole.admin) context.go('/admin');
               if (user!.role == UserRole.super_admin) context.go('/super_admin');
            },
          ),
          
          if (user != null && user!.role == UserRole.student)
            ListTile(
              leading: const Icon(Icons.history_edu),
              title: const Text('History'),
              selected: GoRouterState.of(context).uri.path.contains('/student/history'),
              selectedColor: Colors.deepPurple,
              onTap: () {
                Navigator.pop(context);
                context.push('/student/history');
              },
            ),

          if (user != null && user!.role == UserRole.teacher)
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Create New Quiz'),
              selected: GoRouterState.of(context).uri.path.contains('/teacher/create-quiz'),
              selectedColor: Colors.deepPurple,
              onTap: () {
                Navigator.pop(context);
                context.push('/teacher/create-quiz');
              },
            ),

          if (user != null && (user!.role == UserRole.admin || user!.role == UserRole.super_admin))
             ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Quiz List'),
              selected: GoRouterState.of(context).uri.path == '/all-quizzes', 
              selectedColor: Colors.deepPurple,
              onTap: () {
                 Navigator.pop(context);
                 context.push('/all-quizzes', extra: true);
              },
            ),

          ListTile(
            leading: const Icon(Icons.install_desktop, color: Colors.deepPurpleAccent),
            title: const Text('Our App', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
            selected: GoRouterState.of(context).uri.path == '/our-app',
            selectedColor: Colors.deepPurple,
            onTap: () {
              Navigator.pop(context);
              context.push('/our-app');
            },
          ),

          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('User Guide'),
            selected: GoRouterState.of(context).uri.path == '/user-guide',
            selectedColor: Colors.deepPurple,
            onTap: () {
              Navigator.pop(context);
              context.push('/user-guide');
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.contact_support_outlined),
            title: const Text('Contact Us'),
            selected: GoRouterState.of(context).uri.path == '/contact',
            selectedColor: Colors.deepPurple,
            onTap: () {
              Navigator.pop(context);
              context.push('/contact');
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            selected: GoRouterState.of(context).uri.path == '/about',
            selectedColor: Colors.deepPurple,
            onTap: () {
              Navigator.pop(context);
              context.push('/about');
            },
          ),
          
          if (user != null) ...[
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.deepPurple),
              title: const Text('Logout', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
              onTap: () {
                 context.read<UserProvider>().logout();
              },
            ),
            const SizedBox(height: 20),
          ] else ...[
             const Spacer(),
          ]
        ],
      ),
    );
  }
}
