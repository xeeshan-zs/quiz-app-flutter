import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/quiz_app_bar.dart';
import '../../widgets/quiz_app_drawer.dart';
import '../../widgets/edit_user_dialog.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  // State for Hierarchy
  UserModel? _selectedAdmin; // If null, showing my Admins. If set, showing that Admin's users.
  
  // Search & Filter State
  String _searchQuery = '';
  String _selectedRoleFilter = 'All';

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
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final myUid = userProvider.user?.uid;
      
      List<UserModel> newUsers = [];
      
      if (_selectedAdmin == null) {
          // MODE 1: Show ALL Admins (Global)
          // Removed createdBy filter so Super Admin sees everyone
          newUsers = await FirestoreService().getUsersPaginated(
            limit: 20,
            lastDocument: _lastDocument,
            roleFilter: 'admin', 
            // createdBy: myUid, // REMOVED to show all admins
            searchQuery: _searchQuery,
          );
      } else {
          // MODE 2: Show Users BELONGING to the selected Admin (Silo)
          newUsers = await FirestoreService().getUsersPaginated(
            limit: 20,
            lastDocument: _lastDocument,
            roleFilter: _selectedRoleFilter == 'All' ? null : _selectedRoleFilter,
            adminId: _selectedAdmin!.uid, // SHOW SILO
            searchQuery: _searchQuery,
          );
      }

      DocumentSnapshot? newLastDoc;
      if (newUsers.isNotEmpty) {
        newLastDoc = await FirestoreService().getUserDoc(newUsers.last.uid);
      }

      if (mounted) {
        setState(() {
          if (newUsers.length < 20) _hasMore = false;
          if (newLastDoc != null) {
            _lastDocument = newLastDoc;
          }
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

  void _onFilterChanged(String val) {
    setState(() => _selectedRoleFilter = val);
    _fetchUsers(refresh: true);
  }

  void _onSearchChanged(String val) {
    setState(() => _searchQuery = val);
    _fetchUsers(refresh: true);
  }
  
  void _selectAdmin(UserModel admin) {
    setState(() {
      _selectedAdmin = admin;
      _searchQuery = ''; // Reset search for new context
      _selectedRoleFilter = 'All'; // Reset filter
    });
    _fetchUsers(refresh: true);
  }
  
  void _clearSelection() {
    setState(() {
      _selectedAdmin = null;
      _searchQuery = '';
    });
    _fetchUsers(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: QuizAppBar(user: user),
      drawer: QuizAppDrawer(user: user),
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                    // Dashboard Main Content
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'System Overview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Full access stats and user management.',
                                style: TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _buildStatBadge(Icons.storage, '${_users.length} Loaded'),
                                  // Removed specific role counts as we don't have full list
                                  if (_isLoading) 
                                     _buildStatBadge(Icons.sync, 'Loading...'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Create Buttons (Responsive)
                        if (MediaQuery.of(context).size.width > 700) ...[
                           ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                elevation: 8,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => context.go('/super_admin/manage-app-content'),
                              icon: const Icon(Icons.edit_note, size: 24),
                              label: const Text('Manage Content', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                           ),
                           const SizedBox(width: 16),
                           ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.orangeAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                elevation: 8,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => context.push('/all-quizzes', extra: true), // true = canPause
                              icon: const Icon(Icons.assignment, size: 24),
                              label: const Text('Manage Quizzes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                           ),
                           const SizedBox(width: 16),
                           ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orangeAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                elevation: 8,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => _showCreateUserDialog(context),
                              icon: const Icon(Icons.add_moderator, size: 24), 
                              label: const Text('Add User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                           ),
                        ],
                      ],
                    ),
                    // Mobile Buttons
                    if (MediaQuery.of(context).size.width <= 700) ...[
                       const SizedBox(height: 24),
                       Row(
                         children: [
                           Expanded(
                             child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.orangeAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () => context.push('/all-quizzes', extra: true),
                                icon: const Icon(Icons.assignment),
                                label: const Text('Quizzes'),
                             ),
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                             child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orangeAccent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () => _showCreateUserDialog(context),
                                icon: const Icon(Icons.add_moderator), 
                                label: const Text('Add User'),
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 16),
                       ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed: () => context.go('/super_admin/manage-app-content'),
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Manage Content'),
                       ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Title & Search
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
                        if (_selectedAdmin != null)
                          IconButton.filledTonal(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _clearSelection,
                            tooltip: 'Back to Admins',
                          ),
                        if (_selectedAdmin != null) const SizedBox(width: 12),
                        Icon(_selectedAdmin == null ? Icons.admin_panel_settings : Icons.people_alt, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedAdmin == null ? 'My Admins' : '${_selectedAdmin!.name}\'s Users', 
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
                            ),
                            if (_selectedAdmin != null)
                               Text(
                                  'Managing users for ${_selectedAdmin!.email}', 
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)
                               ),
                          ],
                        ),
                      ],
                    ),
                    
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Role Filter (Only show when drilling down, otherwise we only see Admins)
                          if (_selectedAdmin != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedRoleFilter,
                                items: ['All', 'Student', 'Teacher'] // Constrain choices
                                    .map((role) => DropdownMenuItem(
                                          value: role,
                                          child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                        ))
                                    .toList(),
                                onChanged: (val) => _onFilterChanged(val!),
                              ),
                            ),
                          ),
                          // Search Bar
                          Container(
                            constraints: const BoxConstraints(maxWidth: 250),
                              child: TextField(
                                controller: TextEditingController(text: _searchQuery), // Sync text
                                onChanged: (v) => _onSearchChanged(v),
                                decoration: InputDecoration(
                                  hintText: 'Search Name...',
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(_selectedAdmin == null ? 'No Admins found.\nAdd one to get started.' : 'This Admin has no users yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
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

                      return _buildUserCard(context, _users[index], firestoreService, user);
                    },
                    childCount: _users.length + 1, // +1 for loader
                  ),
                ),
              ),const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, UserModel u, FirestoreService firestoreService, UserModel? text) {
      final isSelf = u.uid == text?.uid;
      // Clickable if we are at root level (not drilled down) AND the row is an Admin
      final isClickable = _selectedAdmin == null && u.role == UserRole.admin;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), // Added some horizontal margin for shadow visibility and vertical spacing
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
             BoxShadow(
               color: Colors.grey.withOpacity(0.1),
               blurRadius: 10,
               offset: const Offset(0, 4),
               spreadRadius: 1,
             ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isClickable ? () => _selectAdmin(u) : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Balanced padding
              child: Row(
                children: [
                  // Left: Avatar
                  Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFEEEE),
                        shape: BoxShape.circle,
                        boxShadow: const [
                            BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
                            BoxShadow(color: Color(0xFFA7A9AF), offset: Offset(2, 2), blurRadius: 4),
                        ],
                      ),
                      child: ClipOval(
                        child: u.photoUrl != null && u.photoUrl!.isNotEmpty
                          ? Image.network(u.photoUrl!, fit: BoxFit.cover, 
                              errorBuilder: (c, o, s) => Icon(Icons.person, color: _getRoleColor(u.role)))
                          : Icon(Icons.person, color: _getRoleColor(u.role)),
                      ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Middle: Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Row(
                           children: [
                             Flexible(
                               child: Text(
                                 u.name + (isSelf ? ' (You)' : ''), 
                                 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                 overflow: TextOverflow.ellipsis,
                               ),
                             ),
                             const SizedBox(width: 8),
                             _buildStatusBadge(u.role.name.toUpperCase(), _getRoleColor(u.role)),
                           ],
                         ),
                         const SizedBox(height: 4),
                         Text(u.email, style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),

                  // Right: Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       if (isClickable) ...[
                          IconButton(
                            icon: const Icon(Icons.groups, color: Colors.deepPurple, size: 20),
                            tooltip: 'Manage Users',
                            splashRadius: 20,
                            onPressed: () => _selectAdmin(u),
                          ),
                          const SizedBox(width: 8),
                       ],
                       
                       Switch(
                          value: !u.isDisabled, 
                          activeColor: Colors.green,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: isSelf ? null : (val) => _toggleUserStatus(u, firestoreService),
                       ),
                       const SizedBox(width: 8),
                       
                       IconButton(
                         icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 20),
                         tooltip: 'Edit',
                         splashRadius: 20,
                         constraints: const BoxConstraints(),
                         padding: EdgeInsets.zero,
                         onPressed: () => showDialog(
                           context: context,
                           builder: (c) => EditUserDialog(user: u),
                         ),
                       ),
                       const SizedBox(width: 12),
                       
                       if (!isSelf)
                         IconButton(
                           icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                           tooltip: 'Delete',
                           splashRadius: 20,
                           constraints: const BoxConstraints(),
                           padding: EdgeInsets.zero,
                           onPressed: () => _confirmDeleteUser(context, u, firestoreService),
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

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Future<void> _toggleUserStatus(UserModel u, FirestoreService firestoreService) async {
      try {
        await firestoreService.toggleUserDisabled(u.uid, u.isDisabled);
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
  }

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
        color: Colors.white.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity( 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.orangeAccent, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showUserDetails(BuildContext context, UserModel user) {
      showDialog(context: context, builder: (c) => AlertDialog(
          title: Text(user.name),
          content: Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                _detailRow('Email', user.email),
                _detailRow('Role', user.role.name),
                _detailRow('UID', user.uid),
                const Divider(),
                const Text('Metadata:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(user.metadata.toString()),
             ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
      ));
  }

  void _confirmDeleteUser(BuildContext context, UserModel user, FirestoreService firestore) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${user.name}"?'),
            const SizedBox(height: 12),
            const Text(
              'Warning:', 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const Text('• The user will be removed from the database.'),
            const Text('• They will immediately lose access.'),
            const Text('• They will strictly NOT be able to log in again.'),
            const SizedBox(height: 12),
            const Text('This action cannot be undone.', style: TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
             style: FilledButton.styleFrom(backgroundColor: Colors.red),
             onPressed: () async {
               Navigator.pop(context); // Close Confirmation
               try {
                 await firestore.deleteUser(user.uid);
                 if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User "${user.name}" deleted.')));
                 }
               } catch (e) {
                 if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
                 }
               }
             },
             child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _showCreateUserDialog(BuildContext context) {
      // Pass the currently selected admin (if any) to the dialog as a pre-selection
      showDialog(
        context: context, 
        builder: (context) => _CreateUserDialog(preselectedAdmin: _selectedAdmin)
      );
  }
}

class _CreateUserDialog extends StatefulWidget {
  final UserModel? preselectedAdmin;
  const _CreateUserDialog({this.preselectedAdmin});

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
    final _formKey = GlobalKey<FormState>();
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();
    final _nameController = TextEditingController();
    UserRole _selectedRole = UserRole.student;
    
    // Admin Selection
    List<UserModel> _availableAdmins = [];
    UserModel? _selectedAdmin;
    bool _isLoadingAdmins = false;

    // Student fields
    final _rollNoController = TextEditingController();
    // Replaced _classController with Dropdown logic
    List<String> _availableClasses = [];
    String? _selectedClass;
    
    bool _isSubmitting = false;

    @override
    void initState() {
      super.initState();
      _selectedAdmin = widget.preselectedAdmin;
      _loadAdmins();
      _loadClasses();
    }

    Future<void> _loadAdmins() async {
      setState(() => _isLoadingAdmins = true);
      try {
        final admins = await FirestoreService().getUsersPaginated(
          limit: 100, roleFilter: 'admin',
        );
        if (mounted) {
          setState(() {
            _availableAdmins = admins;
            // Ensure pre-selected admin is in the list
            if (_selectedAdmin != null && _availableAdmins.indexWhere((a) => a.uid == _selectedAdmin!.uid) == -1) {
               _availableAdmins.add(_selectedAdmin!);
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading admins: $e');
      } finally {
        if (mounted) setState(() => _isLoadingAdmins = false);
      }
    }

    void _loadClasses() {
       setState(() {
          if (_selectedAdmin != null) {
             _availableClasses = _selectedAdmin!.subscribedClasses;
          } else {
             _availableClasses = [];
          }
          // Reset selection if it's no longer valid, or just reset to force user choice
          if (_selectedClass != null && !_availableClasses.contains(_selectedClass)) {
             _selectedClass = null;
          }
       });
    }

    @override
    Widget build(BuildContext context) {
        return AlertDialog(
            title: const Text('New System User'),
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
                                  value: _selectedRole,
                                  items: UserRole.values
                                      .where((role) => role != UserRole.unknown && role != UserRole.super_admin)
                                      .map((role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(role.name.toUpperCase()),
                                  )).toList(),
                                  onChanged: (val) {
                                      setState(() {
                                          _selectedRole = val!;
                                          // Logic to clear/restore admin selection
                                          if (_selectedRole == UserRole.admin) {
                                              _selectedAdmin = null;
                                              _loadClasses(); 
                                          } else if (_selectedAdmin == null && widget.preselectedAdmin != null) {
                                              _selectedAdmin = widget.preselectedAdmin;
                                              _loadClasses();
                                          }
                                      });
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Role', 
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    prefixIcon: const Icon(Icons.shield_outlined),
                                  ),
                              ),

                              // Admin Selection Dropdown (Only for Non-Admins)
                              if (_selectedRole != UserRole.admin) ...[
                                  const SizedBox(height: 16),
                                  _isLoadingAdmins 
                                    ? const LinearProgressIndicator()
                                    : DropdownButtonFormField<UserModel>(
                                        value: _selectedAdmin != null && _availableAdmins.indexWhere((a) => a.uid == _selectedAdmin!.uid) != -1
                                            ? _availableAdmins.firstWhere((a) => a.uid == _selectedAdmin!.uid) 
                                            : null,
                                        items: _availableAdmins.map((admin) => DropdownMenuItem(
                                          value: admin,
                                          child: Text('${admin.name} (${admin.email})', overflow: TextOverflow.ellipsis),
                                        )).toList(),
                                        onChanged: (val) {
                                           setState(() {
                                              _selectedAdmin = val;
                                              _loadClasses();
                                           });
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'Assign to Admin',
                                          helperText: 'Select the Admin who manages this user.',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                          prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                                        ),
                                        validator: (val) {
                                           if (_selectedRole != UserRole.admin && val == null) {
                                              return 'Please select an Admin';
                                           }
                                           return null;
                                        },
                                      ),
                              ],

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
                                      items: _availableClasses.map((c) => DropdownMenuItem(
                                          value: c, 
                                          child: Text(c)
                                      )).toList(),
                                      onChanged: (val) => setState(() => _selectedClass = val),
                                      decoration: InputDecoration(
                                        labelText: 'Class',
                                        helperText: _availableClasses.isEmpty 
                                          ? (_selectedAdmin == null ? 'Select an Admin first' : 'No classes found for this Admin') 
                                          : null,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        prefixIcon: const Icon(Icons.class_outlined),
                                      ),
                                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                  ),
                              ]
                          ],
                      )
                  )
              ),
            ),
            actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting 
                     ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                     : const Text('Create User'),
                ),
            ],
        );
    }

    Future<void> _submit() async {
        if (!_formKey.currentState!.validate()) return;
        setState(() => _isSubmitting = true);
        
        try {
            final firestore = FirestoreService();
            // 0. Check for Duplicates
            final emailExists = await firestore.checkEmailExists(_emailController.text.trim());
            if (emailExists) {
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Email already exists.')));
               setState(() => _isSubmitting = false);
               return;
            }

            if (_selectedRole == UserRole.student && _rollNoController.text.isNotEmpty) {
               final rollExists = await firestore.checkRollNumberExists(_rollNoController.text.trim());
               if (rollExists) {
                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Roll Number already exists.')));
                 setState(() => _isSubmitting = false);
                 return;
               }
            }

            // 1. Create in Firebase Auth (Secondary App)
            final newUid = await AuthService().createUserByAdmin(
                _emailController.text.trim(), 
                _passwordController.text.trim()
            );

            final currentUser = context.read<UserProvider>().user;
            final metadata = <String, dynamic>{};
            
            if (_selectedRole == UserRole.student) {
                if (_rollNoController.text.isNotEmpty) metadata['rollNumber'] = _rollNoController.text.trim();
                // Use selected class
                if (_selectedClass != null) metadata['classLevel'] = _selectedClass;
            }

            final newUser = UserModel(
                uid: newUid,
                email: _emailController.text.trim(),
                name: _nameController.text.trim(),
                role: _selectedRole,
                createdBy: currentUser?.uid,
                adminId: (_selectedRole == UserRole.admin) ? currentUser?.uid : _selectedAdmin?.uid, 
                metadata: metadata,
            );

            // 2. Create in Firestore
            await firestore.createUser(newUser, _passwordController.text.trim());
            
            if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User record created successfully')));
            }
        } catch (e) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        } finally {
            if (mounted) setState(() => _isSubmitting = false);
        }
    }
}
