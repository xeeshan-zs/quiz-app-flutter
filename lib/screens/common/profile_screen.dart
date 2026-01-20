
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../services/cloudinary_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _rollNoController;
  
  // Password fields
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPasswordFields = false;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _rollNoController = TextEditingController(text: user?.metadata['rollNumber'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _rollNoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }


  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploadingImage = true);

      // final imageBytes = await image.readAsBytes(); // Removed redundant step
      final imageUrl = await CloudinaryService().uploadImage(image);
      
      if (imageUrl != null) {
        if (!mounted) return;
        await context.read<UserProvider>().updateProfile(
          _nameController.text.trim(),
          photoUrl: imageUrl,
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!')));
      } else {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload image')));
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final userProvider = context.read<UserProvider>();
      
      // 1. Update Profile Info
      final currentMetadata = Map<String, dynamic>.from(userProvider.user?.metadata ?? {});
      if (_rollNoController.text.isNotEmpty) {
        currentMetadata['rollNumber'] = _rollNoController.text.trim();
      }

      await userProvider.updateProfile(
        _nameController.text.trim(),
        metadata: currentMetadata,
      );

      // 2. Update Password if requested
      if (_showPasswordFields && _passwordController.text.isNotEmpty) {
        if (_passwordController.text != _confirmPasswordController.text) {
          throw Exception("Passwords do not match");
        }
        await userProvider.updatePassword(_passwordController.text);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
        );
        setState(() {
          _showPasswordFields = false;
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty 
                                  ? NetworkImage(user.photoUrl!) 
                                  : null,
                              child: user.photoUrl == null || user.photoUrl!.isEmpty
                                  ? Text(
                                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                      style: TextStyle(
                                        fontSize: 32, 
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary
                                      ),
                                    )
                                  : null,
                            ),
                            if (_isUploadingImage)
                              const Positioned.fill(child: CircularProgressIndicator()),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickAndUploadImage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user.role.name.toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 12
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTransparencyInfo(context, user),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                    validator: (v) => v!.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    readOnly: true, 
                    decoration: const InputDecoration(
                      labelText: 'Email Address', 
                      prefixIcon: Icon(Icons.email),
                      filled: true,
                      fillColor: Colors.black12, 
                    ),
                  ),
                  
                  if (user.role == UserRole.student) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _rollNoController,
                      decoration: const InputDecoration(labelText: 'Roll Number', prefixIcon: Icon(Icons.numbers)),
                    ),
                  ],

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Password Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showPasswordFields = !_showPasswordFields;
                          });
                        },
                        icon: Icon(_showPasswordFields ? Icons.keyboard_arrow_up : Icons.lock_reset),
                        label: Text(_showPasswordFields ? 'Cancel Password Change' : 'Change Password'),
                      ),
                    ],
                  ),
                  
                  if (_showPasswordFields) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.withOpacity(0.05)
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.lock_outline)),
                            obscureText: true,
                            validator: (v) {
                               if (_showPasswordFields && (v == null || v.length < 6)) {
                                 return 'Password must be at least 6 characters';
                               }
                               return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: const InputDecoration(labelText: 'Confirm Password', prefixIcon: Icon(Icons.lock)),
                            obscureText: true,
                            validator: (v) {
                               if (_showPasswordFields && v != _passwordController.text) {
                                 return 'Passwords do not match';
                               }
                               return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                      child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Changes', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransparencyInfo(BuildContext context, UserModel user) {
    if (user.role == UserRole.super_admin) return const SizedBox.shrink();

    return Column(
      children: [
        if (user.role == UserRole.student)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Class: ${user.className}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ),
        
        if (user.adminId != null && user.role != UserRole.admin)
           Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Institution ID: ...${user.adminId!.substring(user.adminId!.length > 6 ? user.adminId!.length - 6 : 0)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.withOpacity(0.5)),
            ),
          ),

        if (user.role == UserRole.admin)
           Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.withOpacity(0.2)),
              ),
              child: Text(
                '${user.subscribedClasses.length} Active Classes',
                style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}
