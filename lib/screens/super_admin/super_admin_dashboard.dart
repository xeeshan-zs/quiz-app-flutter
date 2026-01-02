import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  String _searchQuery = '';
  int? _sortColumnIndex;
  bool _sortAscending = true;
  late Stream<List<UserModel>> _usersStream;
  String _selectedRoleFilter = 'All';

  @override
  void initState() {
    super.initState();
    _usersStream = FirestoreService().getAllUsers();
  }

  void _onSort<T>(Comparable<T> Function(UserModel d) getField, int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
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
          final systemTotal = users.length;
          final activeUsersCount = users.where((u) => !u.isDisabled).length;
          final admins = users.where((u) => u.role == UserRole.admin).length;

          // Role Filter
          if (_selectedRoleFilter != 'All') {
            users = users.where((u) => u.role.name.toLowerCase() == _selectedRoleFilter.toLowerCase()).toList();
          }

          // Search Filter
          if (_searchQuery.isNotEmpty) {
             users = users.where((u) {
                final searchLower = _searchQuery.toLowerCase();
                return u.name.toLowerCase().contains(searchLower) || 
                       u.email.toLowerCase().contains(searchLower) ||
                       u.uid.toLowerCase().contains(searchLower);
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
                   case 3: // UID
                     aValue = a.uid;
                     bValue = b.uid;
                     break;
                   case 4: // Status
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
                               Icon(Icons.shield, color: Colors.orangeAccent, size: 28),
                               SizedBox(width: 8),
                               Text('QuizApp SuperAdmin', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity( 0.1),
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
                                Row(
                                  children: [
                                    _buildStatBadge(Icons.storage, '$systemTotal Total Records'),
                                    const SizedBox(width: 12),
                                    _buildStatBadge(Icons.admin_panel_settings, '$admins Admins'),
                                    const SizedBox(width: 12),
                                    _buildStatBadge(Icons.check_circle, '$activeUsersCount Active'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Create Button (Big)
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
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Title & Search
               SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
                  child: Row(
                    children: [
                      const Icon(Icons.table_chart_outlined, size: 28),
                      const SizedBox(width: 12),
                      Text('Master User List', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      // Role Filter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRoleFilter,
                            items: ['All', 'Student', 'Teacher', 'Admin', 'Super_admin'] // Keep raw enum names or readable? enum names are lowercase usually in my logic, but here I used display strings.
                                // In AdminDashboard I used: ['All', 'Student', 'Teacher', 'Admin']
                                // Here I need to match what I did in AdminDashboard logic:
                                // users.where((u) => u.role.name.toLowerCase() == _selectedRoleFilter.toLowerCase())
                                // So 'Super_admin' -> 'super_admin' match works.
                                .map((role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(role.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedRoleFilter = val!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 280,
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search Name, Email, UID...',
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
                          const DataColumn(label: Text('Email')),
                          DataColumn(
                            label: const Text('UID'),
                            onSort: (idx, asc) => _onSort((u) => u.uid, idx, asc),
                          ),
                          DataColumn(
                            label: const Text('Status'),
                            onSort: (idx, asc) => _onSort((u) => u.isDisabled ? 1 : 0, idx, asc),
                          ),
                          const DataColumn(label: Text('Actions')),
                        ],
                        rows: users.map((u) {
                          final isSelf = u.uid == user?.uid;
                          return DataRow(
                            color: MaterialStateProperty.resolveWith((states) {
                               return users.indexOf(u) % 2 == 0 ? Colors.white : Colors.grey.withOpacity(0.05);
                            }),
                            cells: [
                              DataCell(Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16, 
                                    backgroundColor: _getRoleColor(u.role).withOpacity( 0.1),
                                    child: Icon(Icons.person, size: 16, color: _getRoleColor(u.role)),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(u.name + (isSelf ? ' (You)' : ''), style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              )),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(u.role).withOpacity( 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    u.role.name.toUpperCase(), 
                                    style: TextStyle(color: _getRoleColor(u.role), fontWeight: FontWeight.bold, fontSize: 11)
                                  ),
                                )
                              ),
                              DataCell(Text(u.email)),
                              DataCell(Text(u.uid.substring(0, 8), style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                              DataCell(
                                 Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: u.isDisabled ? Colors.red.withOpacity( 0.1) : Colors.green.withOpacity( 0.1),
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
                                      value: !u.isDisabled,
                                      activeColor: Colors.green,
                                      onChanged: isSelf ? null : (val) {
                                         firestoreService.toggleUserDisabled(u.uid, u.isDisabled);
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
                                      .where((role) => role != UserRole.unknown)
                                      .map((role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(role.name.toUpperCase()),
                                  )).toList(),
                                  onChanged: (val) => setState(() => _selectedRole = val!),
                                  decoration: InputDecoration(
                                    labelText: 'Role', 
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    prefixIcon: const Icon(Icons.shield_outlined),
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
                              ],
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
