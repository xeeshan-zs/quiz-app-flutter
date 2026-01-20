class AppSettingsModel {
  final String teamName;
  final List<String> availableClasses;

  AppSettingsModel({
    required this.teamName,
    this.availableClasses = const ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'],
  });

  factory AppSettingsModel.fromMap(Map<String, dynamic> map) {
    return AppSettingsModel(
      teamName: map['teamName'] ?? 'Runtime Terrors',
      availableClasses: List<String>.from(map['availableClasses'] ?? ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamName': teamName,
      'availableClasses': availableClasses,
    };
  }
}

class TeamMemberModel {
  final String id;
  final String name;
  final String role;
  final String description;
  final String imageUrl;
  final List<SocialLink> socialLinks;
  final int order; // To sort members

  TeamMemberModel({
    required this.id,
    required this.name,
    required this.role,
    required this.description,
    required this.imageUrl,
    required this.socialLinks,
    this.order = 0,
  });

  factory TeamMemberModel.fromMap(String id, Map<String, dynamic> map) {
    return TeamMemberModel(
      id: id,
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      order: map['order'] ?? 0,
      socialLinks: (map['socialLinks'] as List<dynamic>?)
              ?.map((e) => SocialLink.fromMap(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'description': description,
      'imageUrl': imageUrl,
      'order': order,
      'socialLinks': socialLinks.map((e) => e.toMap()).toList(),
    };
  }
}

class SocialLink {
  final String platform;
  final String url;
  final String iconKey; // Store a key like 'linkedin', 'github', 'web'

  SocialLink({required this.platform, required this.url, required this.iconKey});

  factory SocialLink.fromMap(Map<String, dynamic> map) {
    return SocialLink(
      platform: map['platform'] ?? '',
      url: map['url'] ?? '',
      iconKey: map['iconKey'] ?? 'web',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'platform': platform,
      'url': url,
      'iconKey': iconKey,
    };
  }
}
