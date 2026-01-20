import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/app_settings_model.dart';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../utils/icon_utils.dart';

class ManageAppContentScreen extends StatefulWidget {
  const ManageAppContentScreen({super.key});

  @override
  State<ManageAppContentScreen> createState() => _ManageAppContentScreenState();
}

class _ManageAppContentScreenState extends State<ManageAppContentScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _teamNameController = TextEditingController();
  bool _isLoadingName = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _firestoreService.getAppSettings().listen((settings) {
      if (mounted) {
        // Only update if not typing to avoid cursor jumps, unless empty
        if (_teamNameController.text.isEmpty) {
          _teamNameController.text = settings.teamName;
        }
      }
    });
  }

  Future<void> _saveTeamName() async {
    setState(() => _isLoadingName = true);
    await _firestoreService.updateAppSettings(AppSettingsModel(teamName: _teamNameController.text));
    setState(() => _isLoadingName = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team Name Updated!')));
  }

  @override
  Widget build(BuildContext context) {
    // Responsive Layout Decision
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Light grey bg for contrast
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Content Management'),
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withOpacity(0.5)),
          ),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background Blobs (Minimalist)
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.1)),
            ),
          ),
          Positioned(
            bottom: 50, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purple.withOpacity(0.1)),
            ),
          ),

          // Main Content
          SafeArea(
            child: isDesktop 
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildGeneralSettingsPanel(context)),
                    Expanded(flex: 3, child: _buildTeamMembersPanel(context)),
                  ],
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Column(
                    children: [
                      _buildGeneralSettingsPanel(context),
                      _buildTeamMembersPanel(context),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettingsPanel(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.settings_outlined, color: Colors.deepPurple),
              ),
              const SizedBox(width: 16),
              const Text('General Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 32),
          
          // --- Team Name ---
          Text('Team Name', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _teamNameController,
            decoration: InputDecoration(
              hintText: 'e.g. Runtime Terrors',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.groups_outlined),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Appears on Login, About Us, and Footer.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          
          const SizedBox(height: 32),
          
          // --- Class Management ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Available Classes', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: _showAddClassDialog,
                icon: const Icon(Icons.add_circle, color: Colors.deepPurple),
                tooltip: 'Add Class',
              )
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<AppSettingsModel>(
            stream: _firestoreService.getAppSettings(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final classes = snapshot.data!.availableClasses;
              // Sort numerically if possible
              classes.sort((a, b) {
                 int? ia = int.tryParse(a);
                 int? ib = int.tryParse(b);
                 if (ia != null && ib != null) return ia.compareTo(ib);
                 return a.compareTo(b);
              });

              return Wrap(
                spacing: 8, runSpacing: 8,
                children: classes.map((c) => Chip(
                  label: Text(c),
                  backgroundColor: Colors.white,
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => _removeClass(c, classes),
                )).toList(),
              );
            },
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoadingName ? null : _saveTeamName,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoadingName 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  void _showAddClassDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Class'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. 13, Kindergarten'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                // Fetch current, add, save
                // Optimistic approach for simplicity or proper fetch
                 // We don't have direct access to 'classes' here without re-fetching
                 // So we'll use a transaction or simple get-set
                 final doc = await _firestoreService.getAppSettings().first; // Get one shot
                 final currentList = List<String>.from(doc.availableClasses);
                 if (!currentList.contains(controller.text)) {
                    currentList.add(controller.text);
                    await _firestoreService.updateAppSettings(AppSettingsModel(teamName: doc.teamName, availableClasses: currentList));
                 }
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          )
        ],
      )
    );
  }

  Future<void> _removeClass(String cls, List<String> currentList) async {
     // currentList is from the stream snapshot, so it's fresh enough
     final doc = await _firestoreService.getAppSettings().first; // Double check
     final list = List<String>.from(doc.availableClasses);
     list.remove(cls);
     await _firestoreService.updateAppSettings(AppSettingsModel(teamName: doc.teamName, availableClasses: list));
  }

  Widget _buildTeamMembersPanel(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.people_alt_outlined, color: Colors.orange),
                  ),
                  const SizedBox(width: 16),
                  const Text('Team Members', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton.filled(
                onPressed: () => _showTeamMemberDialog(context),
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 24),
          StreamBuilder<List<TeamMemberModel>>(
            stream: _firestoreService.getTeamMembers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              // Create a mutable copy for reordering
              final members = List<TeamMemberModel>.from(snapshot.data ?? []);

              if (members.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.supervised_user_circle_outlined, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No team members yet.', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                    ],
                  ),
                );
              }

              return ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                onReorder: (oldIndex, newIndex) {
                   if (oldIndex < newIndex) newIndex -= 1;
                   final item = members.removeAt(oldIndex);
                   members.insert(newIndex, item);
                   
                   // Optimistic update logic if needed, but here we just sync with DB
                   _firestoreService.updateTeamOrder(members);
                },
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return Padding(
                    key: ValueKey(member.id),
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildMemberCard(context, member, index),
                  );
                },
              );
            },
          ),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildMemberCard(BuildContext context, TeamMemberModel member, int index) {
    return Container(
      padding: const EdgeInsets.all(8), // Reduced padding to accommodate handle
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Drag Handle
          ReorderableDragStartListener(
            index: index,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.transparent, // Hit test area
              child: const Icon(Icons.drag_indicator, color: Colors.grey),
            ),
          ),
          // Avatar
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey[100],
              image: member.imageUrl.isNotEmpty 
                  ? DecorationImage(image: NetworkImage(member.imageUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: member.imageUrl.isEmpty 
              ? Center(child: Text(member.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)))
              : null,
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(member.role, style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // Actions
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _showTeamMemberDialog(context, member: member),
                color: Colors.grey[600],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _confirmDelete(context, member.id),
                color: Colors.red[300],
              ),
            ],
          )
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _firestoreService.deleteTeamMember(id);
              Navigator.pop(ctx);
            }, 
            child: const Text('Remove', style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }

  void _showTeamMemberDialog(BuildContext context, {TeamMemberModel? member}) {
    showDialog(
      context: context,
      builder: (context) => TeamMemberDialog(
        member: member, 
        onSave: (newMember) async {
          if (member == null) {
            await _firestoreService.addTeamMember(newMember);
          } else {
            await _firestoreService.updateTeamMember(newMember);
          }
        }
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Team Member Dialog with Image Upload
// -----------------------------------------------------------------------------

class TeamMemberDialog extends StatefulWidget {
  final TeamMemberModel? member;
  final Function(TeamMemberModel) onSave;

  const TeamMemberDialog({super.key, this.member, required this.onSave});

  @override
  State<TeamMemberDialog> createState() => _TeamMemberDialogState();
}

class _TeamMemberDialogState extends State<TeamMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _descController;
  late TextEditingController _imageController;
  
  List<SocialLink> _socialLinks = [];
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member?.name ?? '');
    _roleController = TextEditingController(text: widget.member?.role ?? '');
    _descController = TextEditingController(text: widget.member?.description ?? '');
    _imageController = TextEditingController(text: widget.member?.imageUrl ?? '');
    _socialLinks = widget.member != null ? List.from(widget.member!.socialLinks) : [];
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);

      final url = await CloudinaryService().uploadImage(image);
      
      if (url != null) {
        setState(() => _imageController.text = url);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image Uploaded!')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload Failed. Check console.')));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 15))
          ]
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.member == null ? 'Add New Member' : 'Edit Member',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Image Section
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey[300]!),
                          image: _imageController.text.isNotEmpty 
                            ? DecorationImage(image: NetworkImage(_imageController.text), fit: BoxFit.cover)
                            : null,
                        ),
                        child: _imageController.text.isEmpty && !_isUploading
                             ? const Icon(Icons.person, size: 40, color: Colors.grey)
                             : _isUploading
                                ? const Center(child: CircularProgressIndicator())
                                : null,
                      ),
                      Positioned(
                        bottom: -4, right: -4,
                        child: IconButton.filled(
                          onPressed: _pickAndUploadImage,
                          icon: const Icon(Icons.camera_alt, size: 18),
                          style: IconButton.styleFrom(backgroundColor: Colors.deepPurple),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  decoration: _inputDeco('Full Name', Icons.person_outline),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _roleController,
                  decoration: _inputDeco('Role', Icons.workspace_premium_outlined),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  decoration: _inputDeco('Bio/Description', Icons.article_outlined),
                  maxLines: 3,
                ),
                
                const SizedBox(height: 24),
                const Text('Social Links', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                
                ..._socialLinks.asMap().entries.map((entry) {
                  final index = entry.key;
                  final link = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                         Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                           child: _getSocialIcon(link.iconKey),
                         ),
                         const SizedBox(width: 8),
                         Expanded(
                           child: TextFormField(
                             initialValue: link.url,
                             decoration: _inputDeco('URL', null).copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0)),
                             onChanged: (val) {
                                // Simplified update logic
                                _socialLinks[index] = SocialLink(platform: link.platform, url: val, iconKey: link.iconKey);
                             },
                           ),
                         ),
                         IconButton(
                           icon: const Icon(Icons.close, size: 18, color: Colors.red),
                           onPressed: () => setState(() => _socialLinks.removeAt(index)),
                         ),
                      ],
                    ),
                  );
                }),
                
                OutlinedButton.icon(
                  onPressed: _showAddLinkSheet,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Add Social Link'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),

                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final newMember = TeamMemberModel(
                            id: widget.member?.id ?? '',
                            name: _nameController.text,
                            role: _roleController.text,
                            description: _descController.text,
                            imageUrl: _imageController.text,
                            socialLinks: _socialLinks,
                            order: widget.member?.order ?? 0,
                          );
                          widget.onSave(newMember);
                          Navigator.pop(context);
                        }
                      },
                      style: FilledButton.styleFrom(
                         backgroundColor: Colors.deepPurple,
                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Save Details'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddLinkSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Platform', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16, runSpacing: 16,
                children: [
                  _socialOption('Web', 'web', Icons.language),
                  _socialOption('LinkedIn', 'linkedin', FontAwesomeIcons.linkedin),
                  _socialOption('GitHub', 'github', FontAwesomeIcons.github),
                  _socialOption('Twitter', 'twitter', FontAwesomeIcons.twitter),
                  _socialOption('Instagram', 'instagram', FontAwesomeIcons.instagram),
                  _socialOption('Email', 'email', Icons.email),
                  _socialOption('Others...', '?', Icons.grid_view_rounded), // Triggers picker
                ],
              )
            ],
          ),
        );
      }
    );
  }

  Widget _socialOption(String label, String key, IconData icon) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // Close sheet
        if (key == '?') {
          _showIconPicker();
        } else {
          setState(() => _socialLinks.add(SocialLink(platform: label, url: '', iconKey: key)));
        }
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            child: Icon(icon, size: 24, color: Colors.deepPurple),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _showIconPicker() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 400,
          height: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('Select Icon', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: IconUtils.iconMap.length,
                  itemBuilder: (context, index) {
                    final key = IconUtils.iconMap.keys.elementAt(index);
                    final icon = IconUtils.iconMap.values.elementAt(index);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          // Clean key for display label (e.g., 'laptop-code' -> 'Laptop Code')
                          final label = key.split('-').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
                          _socialLinks.add(SocialLink(platform: label, url: '', iconKey: key));
                        });
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: Colors.deepPurple, size: 20),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ],
          ),
        ),
      ),
    );
  }

  Icon _getSocialIcon(String key) {
    return Icon(IconUtils.getIcon(key), size: 16);
  }

  InputDecoration _inputDeco(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: Colors.deepPurple.withOpacity(0.6)) : null,
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.deepPurple, width: 2)),
    );
  }
}
