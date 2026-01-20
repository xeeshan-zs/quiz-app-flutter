
enum UserRole { super_admin, admin, teacher, student, unknown }

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? photoUrl;
  final UserRole role;
  final bool isDisabled;
  
  // Hierarchy Fields
  final String? createdBy; // UID of the user who created this user
  final String? adminId;   // UID of the Admin (Tenant) who owns this user hierarchy
  
  final Map<String, dynamic> metadata;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.photoUrl,
    this.isDisabled = false,
    this.createdBy,
    this.adminId,
    this.metadata = const {},
  });

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? photoUrl,
    UserRole? role,
    bool? isDisabled,
    String? createdBy,
    String? adminId,
    Map<String, dynamic>? metadata,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      isDisabled: isDisabled ?? this.isDisabled,
      createdBy: createdBy ?? this.createdBy,
      adminId: adminId ?? this.adminId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'role': role.name,
      'isDisabled': isDisabled,
      'createdBy': createdBy,
      'adminId': adminId,
      'metadata': metadata,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'],
      role: UserRole.values.firstWhere(
        (e) => e.name == (map['role'] ?? 'unknown'),
        orElse: () => UserRole.unknown,
      ),
      isDisabled: map['isDisabled'] ?? false,
      createdBy: map['createdBy'],
      adminId: map['adminId'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  // Helpers specific to roles
  String? get department => metadata['department'];
  String? get rollNumber => metadata['rollNumber'];
  String? get degree => metadata['degree'];
  String? get semester => metadata['semester'];
  String? get section => metadata['section'];
  
  // Admin Specific
  List<String> get subscribedClasses => List<String>.from(metadata['subscribedClasses'] ?? []);

  String get className {
    if (degree != null && semester != null) {
      return '$degree-$semester${section ?? ""}';
    }
    return 'N/A';
  }
}
