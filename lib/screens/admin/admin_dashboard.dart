import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  late Stream<List<UserModel>> _usersStream;
  
  String _searchQuery = '';
  String _selectedRoleFilter = 'All';
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _usersStream = _firestoreService.getAllUsers();
  }

  void _onSort<T>(Comparable<T> Function(UserModel d) getField, int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: StreamBuilder<List<UserModel>>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          }

          var users = snapshot.data ?? [];
          // Filter out Super Admins from Admin view
          users = users.where((u) => u.role != UserRole.super_admin).toList();

          final activeUsersCount = users.where((u) => !u.isDisabled).length;
          final students = users.where((u) => u.role == UserRole.student).length;
          final teachers = users.where((u) => u.role == UserRole.teacher).length;

          // Role Filter
          if (_selectedRoleFilter != 'All') {
            users = users.where((u) => u.role.name.toLowerCase() == _selectedRoleFilter.toLowerCase()).toList();
          }

          // Search Filter
          if (_searchQuery.isNotEmpty) {
             users = users.where((u) {
                final searchLower = _searchQuery.toLowerCase();
                return u.name.toLowerCase().contains(searchLower) || 
                       u.email.toLowerCase().contains(searchLower);
             }).toList();
          }

          // Sort
          if (_sortColumnIndex != null) {
             users.sort((a, b) {
                Comparable<dynamic> aValue;
                Comparable<dynamic> bValue;
                
                switch (_sortColumnIndex) {
                   case 0: // Name
                     aValue = a.name;
                     bValue = b.name;
                     break;
                   case 1: // Role
                     aValue = a.role.name;
                     bValue = b.role.name;
                     break;
                   case 3: // Status (enabled/disabled)
                     aValue = a.isDisabled ? 1 : 0;
                     bValue = b.isDisabled ? 1 : 0;
                     break;
                   default:
                     aValue = a.name;
                     bValue = b.name;
                }
                
                return _sortAscending 
                    ? Comparable.compare(aValue, bValue) 
                    : Comparable.compare(bValue, aValue);
             });
          }

          return CustomScrollView(
            slivers: [
              // Hero Section
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(32, 60, 32, 40),
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
                      // Top Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                               Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                               SizedBox(width: 8),
                               Text('QuizApp Admin', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => context.read<UserProvider>().logout(),
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Logout'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      
                      // Dashboard Main Content
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, ${user?.name ?? "Admin"}',
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
                                Row(
                                  children: [
                                    _buildStatBadge(Icons.people, '$activeUsersCount Active Users'),
                                    const SizedBox(width: 12),
                                    _buildStatBadge(Icons.school, '$students Students'),
                                    const SizedBox(width: 12),
                                    _buildStatBadge(Icons.work, '$teachers Teachers'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Create Button (Big)
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
                              label: const Text('Add New User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                           ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Title & Search & Filter
               SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
                  child: Row(
                    children: [
                      const Icon(Icons.list_alt, size: 28),
                      const SizedBox(width: 12),
                      Text('User Directory', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      // Role Filter Dropdown
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
                            onChanged: (val) => setState(() => _selectedRoleFilter = val!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Search Bar
                      SizedBox(
                        width: 250,
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
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
                ),
              ),

              // Table Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        sortColumnIndex: _sortColumnIndex,
                        sortAscending: _sortAscending,
                        headingRowColor: MaterialStateProperty.all(const Color(0xFF2E236C)),
                        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        dataRowMinHeight: 60,
                        dataRowMaxHeight: 60,
                        columns: [
                          DataColumn(
                            label: const Text('Name'),
                            onSort: (idx, asc) => _onSort((u) => u.name, idx, asc),
                          ),
                          DataColumn(
                            label: const Text('Role'),
                            onSort: (idx, asc) => _onSort((u) => u.role.name, idx, asc),
                          ),
                          const DataColumn(label: Text('Email')), // Not sorting by email for now, simple implementation
                          DataColumn(
                            label: const Text('Status'),
                            onSort: (idx, asc) => _onSort((u) => u.isDisabled ? 1 : 0, idx, asc),
                          ),
                          const DataColumn(label: Text('Actions')),
                        ],
                        rows: users.map((u) {
                          return DataRow(
                            color: MaterialStateProperty.resolveWith((states) {
                               return users.indexOf(u) % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.05);
                            }),
                            cells: [
                              DataCell(Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16, 
                                    backgroundColor: _getRoleColor(u.role).withOpacity(0.1),
                                    child: Icon(Icons.person, size: 16, color: _getRoleColor(u.role)),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              )),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(u.role).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    u.role.name.toUpperCase(), 
                                    style: TextStyle(color: _getRoleColor(u.role), fontWeight: FontWeight.bold, fontSize: 11)
                                  ),
                                )
                              ),
                              DataCell(Text(u.email)),
                              DataCell(
                                 Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: u.isDisabled ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      u.isDisabled ? 'Disabled' : 'Active',
                                      style: TextStyle(
                                        color: u.isDisabled ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11
                                      )
                                    ),
                                 )
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: !u.isDisabled, // Switch represents "Is Active"
                                      activeColor: Colors.green,
                                      onChanged: (u.role == UserRole.admin) ? null : (val) {
                                         if (u.role == UserRole.super_admin) return;
                                         _firestoreService.toggleUserDisabled(u.uid, u.isDisabled);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.info_outline, color: Colors.blueGrey),
                                      tooltip: 'Details',
                                      onPressed: () => _showUserDetails(context, u),
                                    )
                                  ],
                                )
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          );
        },
      ),
    );
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
    final _nameController = TextEditingController();
    UserRole _selectedRole = UserRole.student;
    
    final _rollNoController = TextEditingController();
    final _classController = TextEditingController(); 
    
    bool _isSubmitting = false;

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
                                  TextFormField(
                                      controller: _classController,
                                      decoration: InputDecoration(
                                        labelText: 'Class (e.g. BSCS-4B)',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        prefixIcon: const Icon(Icons.class_outlined),
                                      ),
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
                        
                        final uid = const Uuid().v4(); 
                        
                        final metadata = <String, dynamic>{};
                        if (_selectedRole == UserRole.student) {
                            metadata['rollNumber'] = _rollNoController.text;
                            metadata['degree'] = 'BSCS';
                            metadata['className'] = _classController.text;
                        }
                        
                        final newUser = UserModel(
                            uid: uid,
                            email: _emailController.text,
                            name: _nameController.text,
                            role: _selectedRole,
                            metadata: metadata,
                        );
                        
                        try {
                           await FirestoreService().createUser(newUser, "pw");
                           if (mounted) {
                               Navigator.pop(context);
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User record created')));
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
