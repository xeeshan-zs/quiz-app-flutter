import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../providers/user_provider.dart';
import 'manage_classes_dialog.dart';

class EditUserDialog extends StatefulWidget {
  final UserModel user;
  final Function(UserModel)? onUserUpdated;

  const EditUserDialog({
    super.key,
    required this.user,
    this.onUserUpdated,
  });

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _contactEmailController;
  // late TextEditingController _classController; // REPLACED by Dropdown
  // String? _selectedClass; // Now using Dropdown state
  late TextEditingController _rollNoController;
  late UserRole _selectedRole;
  late List<String> _enabledClasses;

  // New State for Class Dropdown
  List<String> _availableClasses = [];
  String? _selectedClass; // For Student class selection
  bool _isLoadingClasses = true;

  // Admin Reassignment (Super Admin Only)
  List<UserModel> _availableAdmins = [];
  UserModel? _selectedAdmin;
  bool _isLoadingAdmins = false;

  bool _isSubmitting = false;
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _contactEmailController = TextEditingController(text: widget.user.email);
    _selectedRole = widget.user.role;
    
    // Metadata extract
    _selectedClass = widget.user.metadata['classLevel']; // Can be null or string
    _rollNoController = TextEditingController(text: widget.user.metadata['rollNumber'] ?? '');
    
    // Enabled classes for Admin/Teacher
    _enabledClasses = List<String>.from(widget.user.metadata['subscribedClasses'] ?? []);

    _initializeAdminAndClasses();
  }

  Future<void> _initializeAdminAndClasses() async {
      // 1. If Super Admin, load available admins
      if (!mounted) return;
      final currentUser = context.read<UserProvider>().user;
      
      if (currentUser?.role == UserRole.super_admin) {
           await _loadAdmins();
           // Try to match existing adminId
           final currentAdminId = widget.user.adminId;
           if (currentAdminId != null && _availableAdmins.isNotEmpty) {
               final idx = _availableAdmins.indexWhere((a) => a.uid == currentAdminId);
               if (idx != -1) {
                  _selectedAdmin = _availableAdmins[idx];
               } else {
                  // Admin not in first 100? Fetch specifically? 
                  // For now, if not found, we might fetch it individually or leave null (which forces re-selection)
                  // Let's try to fetch it if not found
                  try {
                      final doc = await _firestoreService.getUserDoc(currentAdminId);
                      if (doc.exists) {
                           final adminUser = UserModel.fromMap(doc.data() as Map<String, dynamic>);
                           setState(() {
                               _availableAdmins.add(adminUser);
                               _selectedAdmin = adminUser;
                           });
                      }
                  } catch (e) {
                      print('Error fetching assigned admin details: $e');
                  }
               }
           }
      }

      // 2. Load classes based on selection (or lack thereof)
      await _loadClasses();
  }

  Future<void> _loadAdmins() async {
      setState(() => _isLoadingAdmins = true);
      try {
        final admins = await _firestoreService.getUsersPaginated(limit: 100, roleFilter: 'admin');
        if (mounted) {
            setState(() => _availableAdmins = admins);
        }
      } catch (e) {
         print('Error loading admins: $e');
      } finally {
         if (mounted) setState(() => _isLoadingAdmins = false);
      }
  }

  Future<void> _loadClasses() async {
     if (!mounted) return;
     setState(() => _isLoadingClasses = true);

     try {
       // Defer to next frame to access context safely
       await Future.microtask(() async {
          if (!mounted) return;
          final userProvider = context.read<UserProvider>();
          final currentUser = userProvider.user;
          
          List<String> classes = [];
          
          if (currentUser != null) {
              if (currentUser.role == UserRole.admin) {
                  // Case 1: I am an Admin editing a user. Use MY defined classes.
                  // If I have defined/subscribed to specific classes, usage those.
                  // If my list is empty, it usually means I haven't configured it -> Fallback to global.
                  if (currentUser.subscribedClasses.isNotEmpty) {
                      classes = List.from(currentUser.subscribedClasses);
                  }
              } else if (currentUser.role == UserRole.super_admin) {
                  // Super Admin: Use Selected Admin's classes
                  if (_selectedAdmin != null) {
                      classes = List.from(_selectedAdmin!.subscribedClasses);
                  } else {
                      // Fallback: If no admin selected, maybe try to load from widget.user.adminId if we hadn't loaded _selectedAdmin yet?
                      // But _initializeAdminAndClasses handles that sequence.
                      // So if _selectedAdmin is null, we show global or empty.
                  }
              }
          }

          // Case 3: Fallback to Global AppSettings if no specific lists found
          if (classes.isEmpty) {
             final settings = await _firestoreService.getAppSettings().first;
             classes = List.from(settings.availableClasses);
          }
          
          if (mounted) {
             setState(() {
               _availableClasses = classes;
               // Ensure currently selected class (if any) is included in the list
               if (_selectedClass != null && _selectedClass!.isNotEmpty && !_availableClasses.contains(_selectedClass)) {
                  _availableClasses.insert(0, _selectedClass!);
               }
               _isLoadingClasses = false;
             });
          }
       });
     } catch (e) {
       print('Error loading classes: $e');
       if (mounted) setState(() => _isLoadingClasses = false);
     }
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final newMetadata = Map<String, dynamic>.from(widget.user.metadata);
      
      // Update metadata based on role logic
      if (_selectedRole == UserRole.student) {
        newMetadata['classLevel'] = _selectedClass;
        newMetadata['rollNumber'] = _rollNoController.text.trim();
      }
      
      if (_selectedRole == UserRole.admin || _selectedRole == UserRole.teacher) {
        newMetadata['subscribedClasses'] = _enabledClasses;
      }

      await _firestoreService.updateUser(
        widget.user.uid,
        name: _nameController.text.trim(),
        email: _contactEmailController.text.trim(), // Display email only
        role: _selectedRole,
        metadata: newMetadata,
        // Update Admin ID if changed (Super Admin only trigger basically, or if role changed logic?)
        // If I am admin, I can't change adminId.
        // If I am Super Admin, I pass _selectedAdmin?.uid
        adminId: _selectedAdmin?.uid, 
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User details updated successfully')),
        );
        if (widget.onUserUpdated != null) {
           // On success
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: widget.user.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to ${widget.user.email}')),
        );
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.user;

    // Filter Roles
    List<UserRole> allowedRoles = UserRole.values.toList();
    bool isSuperAdmin = currentUser?.role == UserRole.super_admin;

    if (currentUser != null && currentUser.role == UserRole.admin) {
        // Admins can only assign Student or Teacher
        // But if the user being edited IS ALREADY Admin/SuperAdmin, we should probably allow keeping it or warn?
        // User request: "admin can not make someone a super admin or admin"
        allowedRoles = [UserRole.student, UserRole.teacher];
        
        // Safety: If current target role is NOT in list (e.g. they are Admin), add it so we don't crash
        // But effectively this means they can't switch BACK to Admin if they change it.
        if (allowedRoles.contains(widget.user.role) == false) {
           allowedRoles.add(widget.user.role);
        }
        
        // Also exclude unknown if wanted, but standard values are fine
    }

    return AlertDialog(
      title: const Text('Edit User Details'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                // Display Email (Editable for DB record, but Auth is separate)
                TextFormField(
                  controller: _contactEmailController,
                  decoration: const InputDecoration(
                      labelText: 'Contact Email', 
                      prefixIcon: Icon(Icons.email),
                      helperText: 'Updates display email only. Login email requires reset.'
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.admin_panel_settings)),
                  items: allowedRoles.map((r) => DropdownMenuItem(
                    value: r, 
                    child: Text(r.toString().split('.').last.toUpperCase())
                  )).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                       _selectedRole = v;
                       if (_selectedRole == UserRole.admin) {
                          _selectedAdmin = null; // Admins are top level
                       }
                    });
                  },
                ),
                
                if (isSuperAdmin && _selectedRole != UserRole.admin && _selectedRole != UserRole.super_admin) ...[
                     const SizedBox(height: 16),
                     _isLoadingAdmins 
                       ? const LinearProgressIndicator()
                       : DropdownButtonFormField<UserModel>(
                           value: _selectedAdmin != null && _availableAdmins.indexWhere((a) => a.uid == _selectedAdmin!.uid) != -1
                               ? _availableAdmins.firstWhere((a) => a.uid == _selectedAdmin!.uid) 
                               : null,
                           decoration: const InputDecoration(
                              labelText: 'Assigned Admin',
                              prefixIcon: Icon(Icons.business),
                              helperText: 'Reassign user to a different Admin'
                           ),
                           items: _availableAdmins.map((a) => DropdownMenuItem(
                             value: a,
                             child: Text('${a.name} (${a.email})', overflow: TextOverflow.ellipsis),
                           )).toList(),
                           onChanged: (val) {
                              setState(() {
                                 _selectedAdmin = val;
                                 _loadClasses(); // Reload classes tags for this admin
                              });
                           },
                       ),
                ],

                const SizedBox(height: 16),

                if (_selectedRole == UserRole.student) ...[
                   // Class Dropdown
                   _isLoadingClasses 
                      ? const Center(child: LinearProgressIndicator())
                      : DropdownButtonFormField<String>(
                          value: (_availableClasses.contains(_selectedClass)) ? _selectedClass : null,
                          decoration: const InputDecoration(
                             labelText: 'Class', 
                             prefixIcon: Icon(Icons.class_),
                             helperText: 'Select current class level'
                          ),
                          items: _availableClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => _selectedClass = v),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                     
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _rollNoController,
                    decoration: const InputDecoration(labelText: 'Roll No', prefixIcon: Icon(Icons.numbers)),
                  ),
                ],

                if (_selectedRole == UserRole.admin || _selectedRole == UserRole.teacher) ...[
                   const SizedBox(height: 8),
                   OutlinedButton.icon(
                     onPressed: () async {
                        // Fetch global settings for fallback
                         final settings = await FirestoreService().getAppSettings().first;
                         if (!context.mounted) return;
                         
                         showDialog(
                           context: context,
                           builder: (c) => ManageClassesDialog(
                             availableClasses: settings.availableClasses,
                             initialSelection: _enabledClasses,
                             onSave: (list) {
                               setState(() => _enabledClasses = list);
                               Navigator.pop(context);
                             },
                           ),
                         );
                     },
                     icon: const Icon(Icons.list),
                     label: Text('Manage Enabled Classes (${_enabledClasses.length})'),
                   ),
                ],

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                
                // Dangerous Actions Area
                const Text('Security & Access', style: TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 8),
                 Wrap(
                   spacing: 8,
                   children: [
                     TextButton.icon(
                       onPressed: _sendPasswordReset,
                       icon: const Icon(Icons.lock_reset, color: Colors.orange),
                       label: const Text('Send Reset Password Email', style: TextStyle(color: Colors.orange)),
                     ),
                     // Add Delete User logic here if needed, but risky.
                   ],
                 )
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isSubmitting ? null : _handleUpdate,
          child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Update User'),
        ),
      ],
    );
  }
}
