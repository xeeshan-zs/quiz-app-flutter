import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/adaptive_layout.dart';
import '../../widgets/quiz_app_bar.dart';
import '../../widgets/manage_classes_dialog.dart';
import '../../widgets/edit_user_dialog.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = '';
  String _selectedRoleFilter = 'All';
  int _selectedIndex = 0;

  void _onNavTapped(int index) {
      if (index == _selectedIndex) return;
      setState(() => _selectedIndex = index);
      switch (index) {
        case 0: break; // User Directory (Home)
        case 1: context.push('/all-quizzes'); break;
        case 2: context.push('/profile'); break;
      }
  }

  // Pagination State
  final List<UserModel> _users = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final ScrollController _scrollController = ScrollController();
  
  // Stats
  int _totalLoaded = 0;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchUsers();
    }
  }

  Future<void> _fetchUsers({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      if (mounted) {
        setState(() {
          _users.clear();
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
      final newUsers = await _firestoreService.getUsersPaginated(
        limit: 20,
        lastDocument: _lastDocument,
        roleFilter: _selectedRoleFilter,
        allowedRoles: ['admin', 'teacher', 'student'], 
        searchQuery: _searchQuery,
      );

      DocumentSnapshot? newLastDoc;
      if (newUsers.isNotEmpty) {
        newLastDoc = await _firestoreService.getUserDoc(newUsers.last.uid);
      }

      if (mounted) {
        setState(() {
          if (newUsers.length < 20) _hasMore = false;
          if (newLastDoc != null) _lastDocument = newLastDoc;
           _users.addAll(newUsers);
           _totalLoaded = _users.length;
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

  // Helper method no longer needed in flow, but could be kept if used elsewhere. 
  // For cleanliness, removing or leaving it unused is fine. 
  // I will just remove the separate async call to it in the flow above.
  Future<void> _updateLastDoc(String uid) async {
      _lastDocument = await _firestoreService.getUserDoc(uid);
  }

  void _onFilterChanged(String val) {
    setState(() => _selectedRoleFilter = val);
    _fetchUsers(refresh: true);
  }

  void _onSearchChanged(String val) {
    setState(() => _searchQuery = val);
    _fetchUsers(refresh: true);
  }



  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;


    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return AdaptiveLayout(
      currentIndex: _selectedIndex,
      onDestinationSelected: _onNavTapped,
      mobileAppBar: QuizAppBar(user: user),
      destinations: const [
        AdaptiveDestination(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Users'),
        AdaptiveDestination(icon: Icons.assignment_outlined, selectedIcon: Icons.assignment, label: 'Quizzes'),
        AdaptiveDestination(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
      ],
      body: RefreshIndicator(
        onRefresh: () async => _fetchUsers(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Hero Section
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(32, 120, 32, 40),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${user.name}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Manage platform users and system settings.',
                                style: TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _buildStatBadge(Icons.people, '${_users.length} Loaded'),
                                  if (_isLoading) _buildStatBadge(Icons.sync, 'Loading...'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Desktop Buttons
                        if (MediaQuery.of(context).size.width > 600) ...[
                             ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF8B5CF6),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () => context.push('/all-quizzes', extra: true),
                                icon: const Icon(Icons.assignment, size: 24), 
                                label: const Text('View All Quizzes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                             ),
                             const SizedBox(width: 16),
                             ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () => _showCreateUserDialog(context),
                                icon: const Icon(Icons.person_add, size: 24), 
                                label: const Text('Add User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                             ),
                             const SizedBox(width: 16),
                             ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () => _showManageClassesDialog(context),
                                icon: const Icon(Icons.class_outlined, size: 24), 
                                label: const Text('Classes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                             ),
                        ]
                      ],
                    ),
                    // Mobile Buttons
                    if (MediaQuery.of(context).size.width <= 600) ...[
                       const SizedBox(height: 24),
                       Row(
                         children: [
                           Expanded(
                             child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF8B5CF6),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () => context.push('/all-quizzes', extra: true),
                                icon: const Icon(Icons.assignment), 
                                label: const Text('Quizzes'),
                             ),
                           ),
                           const SizedBox(width: 8),
                           Expanded(
                             child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () => _showCreateUserDialog(context),
                                icon: const Icon(Icons.person_add), 
                                label: const Text('Add User'),
                             ),
                           ),
                            const SizedBox(width: 8),
                            Expanded(
                             child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () => _showManageClassesDialog(context),
                                icon: const Icon(Icons.class_outlined), 
                                label: const Text('Classes'),
                             ),
                           ),
                         ],
                       )
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Title & Search & Filter
             SliverToBoxAdapter(
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
                        Text('User Directory', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
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
                                value: _selectedRoleFilter,
                                items: ['All', 'Student', 'Teacher', 'Admin']
                                    .map((role) => DropdownMenuItem(
                                          value: role,
                                          child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                        ))
                                    .toList(),
                                onChanged: (val) => _onFilterChanged(val!),
                              ),
                            ),
                          ),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 250),
                            child: TextField(
                              onChanged: (v) => _onSearchChanged(v),
                              decoration: InputDecoration(
                                hintText: 'Search user...',
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
            ),

            // User List (Cards)
            if (_users.isEmpty && !_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No users found.')),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _users.length) {
                         return _hasMore 
                           ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())) 
                           : const SizedBox(height: 40);
                      }

                      final u = _users[index];
                      final isSmallScreen = MediaQuery.of(context).size.width <= 600;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: isSmallScreen
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: _getRoleColor(u.role).withOpacity(0.1),
                                          child: Icon(Icons.person, color: _getRoleColor(u.role)),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              const SizedBox(height: 4),
                                              Text(u.email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _getRoleColor(u.role).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(u.role.name.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getRoleColor(u.role))),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: u.isDisabled ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(u.isDisabled ? 'Disabled' : 'Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: u.isDisabled ? Colors.red : Colors.green)),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Switch(
                                                value: !u.isDisabled, 
                                                activeThumbColor: Colors.green,
                                                onChanged: (u.role == UserRole.admin) ? null : (val) async {
                                                   if (u.role == UserRole.super_admin) return;
                                                   try {
                                                     await _firestoreService.toggleUserDisabled(u.uid, u.isDisabled);
                                                     if (mounted) {
                                                       setState(() {
                                                         final index = _users.indexWhere((user) => user.uid == u.uid);
                                                         if (index != -1) {
                                                           _users[index] = _users[index].copyWith(isDisabled: !u.isDisabled);
                                                         }
                                                       });
                                                     }
                                                   } catch (e) {
                                                     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                                   }
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.info_outline, color: Colors.blueGrey),
                                                tooltip: 'Details',
                                                onPressed: () => _showUserDetails(context, u),
                                              )
                                            ],
                                          ),
                                      ],
                                    )
                                  ],
                                )
                              : Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: _getRoleColor(u.role).withOpacity(0.1),
                                      child: Icon(Icons.person, color: _getRoleColor(u.role)),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(height: 4),
                                          Text(u.email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getRoleColor(u.role).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(u.role.name.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getRoleColor(u.role))),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: u.isDisabled ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(u.isDisabled ? 'Disabled' : 'Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: u.isDisabled ? Colors.red : Colors.green)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                             Switch(
                                              value: !u.isDisabled, 
                                              activeThumbColor: Colors.green,
                                              onChanged: (u.role == UserRole.admin) ? null : (val) async {
                                                 if (u.role == UserRole.super_admin) return;
                                                 try {
                                                   await _firestoreService.toggleUserDisabled(u.uid, u.isDisabled);
                                                   if (mounted) {
                                                     setState(() {
                                                       final index = _users.indexWhere((user) => user.uid == u.uid);
                                                       if (index != -1) {
                                                         _users[index] = _users[index].copyWith(isDisabled: !u.isDisabled);
                                                       }
                                                     });
                                                   }
                                                 } catch (e) {
                                                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                                 }
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                              tooltip: 'Edit User',
                                              onPressed: () {
                                                 showDialog(
                                                   context: context,
                                                   builder: (c) => EditUserDialog(
                                                     user: u,
                                                     onUserUpdated: (updatedUser) {
                                                        // Refresh trigger if needed, though StreamBuilder usually handles it
                                                        setState(() {
                                                           final idx = _users.indexWhere((x) => x.uid == u.uid);
                                                           if (idx != -1) _users[idx] = updatedUser;
                                                        });
                                                     },
                                                   ),
                                                 );
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.info_outline, color: Colors.blueGrey),
                                              tooltip: 'Details',
                                              onPressed: () => _showUserDetails(context, u),
                                            )
                                          ],
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                        ),
                      );
                    },
                    childCount: _users.length + 1,
                  ),
                ),
              ),const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  // --- Manage Classes Dialog ---
  void _showManageClassesDialog(BuildContext context) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user; // Ensure latest
    if (user == null) return;

    // Show loading dialog while fetching settings
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    try {
      final settings = await _firestoreService.getAppSettings().first;
      if (context.mounted) Navigator.pop(context); // Dismiss loading

      // Current subscriptions
      final List<String> currentSubs = user.subscribedClasses; // using helper

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => ManageClassesDialog(
            availableClasses: settings.availableClasses, 
            initialSelection: currentSubs,
            onSave: (newSelection) async {
               // Update Provider & Firestore
               final newMetadata = Map<String, dynamic>.from(user.metadata);
               newMetadata['subscribedClasses'] = newSelection;
               
               await userProvider.updateProfile(user.name, metadata: newMetadata);
               if (context.mounted) Navigator.pop(context);
               if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Classes updated successfully')));
            },
          ),
        );
      }

    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Dismiss loading
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching classes: $e')));
    }
  }


  int get activeCount => 0; // handled in builder

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.super_admin: return Colors.orange;
      case UserRole.admin: return Colors.blue;
      case UserRole.teacher: return Colors.teal;
      case UserRole.student: return Colors.purple;
      default: return Colors.grey;
    }
  }

  Widget _buildStatBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
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

  void _showUserDetails(BuildContext context, UserModel user) {
      showDialog(context: context, builder: (c) => AlertDialog(
          title: Row(
            children: [
              CircleAvatar(backgroundColor: _getRoleColor(user.role).withOpacity(0.1), child: Icon(Icons.person, color: _getRoleColor(user.role))),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: const TextStyle(fontSize: 16)),
                  Text(user.role.name.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              )
            ],
          ),
          content: Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                _detailRow('Email', user.email),
                _detailRow('UID', user.uid),
                const Divider(),
                const Text('Metadata', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (user.metadata.isEmpty) 
                  const Text('No additional data', style: TextStyle(color: Colors.grey))
                else 
                  ...user.metadata.entries.map((e) => _detailRow(e.key, e.value.toString())),
             ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
      ));
  }
  
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _showCreateUserDialog(BuildContext context) {
      showDialog(context: context, builder: (context) => const _CreateUserDialog());
  }
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
    final _formKey = GlobalKey<FormState>();
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController(); 
    final _nameController = TextEditingController();
    UserRole _selectedRole = UserRole.student;
    
    final _rollNoController = TextEditingController();
    
    // Class Dropdown Logic
    final List<String> _availableClasses = [];
    String? _selectedClass;
    bool _isLoadingClasses = true;

    bool _isSubmitting = false;

    @override
    void initState() {
      super.initState();
      _loadClasses();
    }

    Future<void> _loadClasses() async {
      try {
        final user = context.read<UserProvider>().user;
        final adminClasses = user?.subscribedClasses ?? [];

        if (adminClasses.isNotEmpty) {
           if (mounted) {
             setState(() {
               _availableClasses.clear();
               _availableClasses.addAll(adminClasses);
               _isLoadingClasses = false;
             });
           }
        } else {
           // Fallback to Global Settings if Admin hasn't defined any
            final settings = await FirestoreService().getAppSettings().first;
            if (mounted) {
              setState(() {
                _availableClasses.clear();
                _availableClasses.addAll(settings.availableClasses);
                _isLoadingClasses = false;
              });
            }
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingClasses = false);
        debugPrint('Error loading classes: $e');
      }
    }

    @override
    Widget build(BuildContext context) {
        return AlertDialog(
            title: const Text('Add New User'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                  child: Form(
                      key: _formKey,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              TextFormField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    labelText: 'Email', 
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    prefixIcon: const Icon(Icons.email_outlined),
                                  ),
                                  validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField( // Password Field
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    prefixIcon: const Icon(Icons.lock_outline),
                                  ),
                                  validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Full Name', 
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    prefixIcon: const Icon(Icons.person_outline),
                                  ),
                                  validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<UserRole>(
                                  initialValue: _selectedRole,
                                  items: UserRole.values
                                      .where((role) => role == UserRole.student || role == UserRole.teacher)
                                      .map((role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(role.name.toUpperCase()),
                                  )).toList(),
                                  onChanged: (val) => setState(() => _selectedRole = val!),
                                  decoration: InputDecoration(
                                    labelText: 'Role',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    prefixIcon: const Icon(Icons.badge_outlined),
                                  ),
                              ),
                              if (_selectedRole == UserRole.student) ...[
                                  const SizedBox(height: 16),
                                  TextFormField(
                                      controller: _rollNoController,
                                      decoration: InputDecoration(
                                        labelText: 'Roll Number',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        prefixIcon: const Icon(Icons.numbers),
                                      ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Class Dropdown
                                  DropdownButtonFormField<String>(
                                      value: _selectedClass,
                                      decoration: InputDecoration(
                                        labelText: _isLoadingClasses ? 'Loading classes...' : 'Class',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        prefixIcon: const Icon(Icons.class_outlined),
                                      ),
                                      items: _availableClasses.map((cls) {
                                          return DropdownMenuItem(value: cls, child: Text(cls));
                                      }).toList(),
                                      onChanged: (val) => setState(() => _selectedClass = val),
                                      validator: (v) => v == null ? 'Please select a class' : null,
                                  ),
                              ]
                          ],
                      ),
                  ),
              ),
            ),
            actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                    onPressed: _isSubmitting ? null : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _isSubmitting = true);
                        
                        try {
                           // 0. Check for Duplicates
                           final firestore = FirestoreService();
                           final emailExists = await firestore.checkEmailExists(_emailController.text);
                           if (emailExists) {
                             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Email already exists.')));
                             setState(() => _isSubmitting = false);
                             return;
                           }

                           if (_selectedRole == UserRole.student && _rollNoController.text.isNotEmpty) {
                              final rollExists = await firestore.checkRollNumberExists(_rollNoController.text);
                              if (rollExists) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Roll Number already exists.')));
                                setState(() => _isSubmitting = false);
                                return;
                              }
                           }

                           // 1. Create User in Auth to get UID
                           final uid = await AuthService().createUserByAdmin(
                             _emailController.text, 
                             _passwordController.text
                           );
                        
                           final metadata = <String, dynamic>{};
                           if (_selectedRole == UserRole.student) {
                               metadata['rollNumber'] = _rollNoController.text;
                               metadata['degree'] = 'BSCS';
                               metadata['className'] = _selectedClass;
                           }
                           
                           final newUser = UserModel(
                               uid: uid, // Use actual Auth UID
                               email: _emailController.text,
                               name: _nameController.text,
                               role: _selectedRole,
                               metadata: metadata,
                           );
                        
                           // 2. Create User Document in Firestore
                           await FirestoreService().createUser(newUser, "pw"); // Password not strictly needed here if we don't save it
                           
                           if (mounted) {
                               Navigator.pop(context);
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User account created successfully')));
                           }
                        } catch (e) {
                             if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                             }
                        } finally {
                            if (mounted) setState(() => _isSubmitting = false);
                        }
                    },
                    child: const Text('Create User'),
                ),
            ],
        );
    }
}
