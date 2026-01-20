
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/quiz_model.dart';
import '../models/result_model.dart';
import '../models/app_settings_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print("Error fetching user: $e");
    } catch (e) {
      print("Error fetching user: $e");
      return null;
    }
    return null;
  }

  Future<DocumentSnapshot> getUserDoc(String uid) {
    return _db.collection('users').doc(uid).get();
  }

  // --- Quiz Methods ---

  Future<void> createQuiz(QuizModel quiz) async {
    await _db.collection('quizzes').doc(quiz.id).set(quiz.toMap());
  }

  Future<void> deleteQuiz(String quizId) async {
    // Delete associated results first
    final resultsSnapshot = await _db.collection('results').where('quizId', isEqualTo: quizId).get();
    for (final doc in resultsSnapshot.docs) {
      await doc.reference.delete();
    }
    await _db.collection('quizzes').doc(quizId).delete();
  }

  Future<void> toggleQuizStatus(String quizId, bool currentStatus) async {
    await _db.collection('quizzes').doc(quizId).update({'isPaused': !currentStatus});
  }

  // Student: View quizzes for their class AND assigned by their admin's teachers
  Stream<List<QuizModel>> getQuizzesForStudent(String classLevel, String adminId) {
    return _db
        .collection('quizzes')
        .where('isPaused', isEqualTo: false)
        .where('classLevel', isEqualTo: classLevel)
        .where('adminId', isEqualTo: adminId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QuizModel.fromMap(doc.data()))
            .toList());
  }

  // Teacher/Admin: View all quizzes for their institution (Silo)
  Stream<List<QuizModel>> getQuizzesForAdmin(String adminId) {
    return _db
        .collection('quizzes')
        .where('adminId', isEqualTo: adminId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QuizModel.fromMap(doc.data()))
            .toList());
  }
  
  // Method for teacher/admin to see all quizzes
  // Paginated Quizzes Fetch
  Future<List<QuizModel>> getQuizzesPaginated({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String? searchQuery,
    String? adminId, // New: Filter by Silo
  }) async {
    Query query = _db.collection('quizzes');
    
    // Silo Filter (Critical)
    if (adminId != null && adminId.isNotEmpty) {
      query = query.where('adminId', isEqualTo: adminId);
    }

    // Search or Default Sort
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
          .orderBy('title')
          .startAt([searchQuery])
          .endAt(['$searchQuery\uf8ff']);
    } else {
      // Default: Newest first
      query = query.orderBy('createdAt', descending: true);
    }

    // Pagination
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    query = query.limit(limit);

    try {
      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Ensure ID is set
        return QuizModel.fromMap(data);
      }).toList();
    } catch (e) {
      print('Firestore Page Quiz Error: $e');
      rethrow;
    }
  }

  Future<DocumentSnapshot> getQuizDoc(String quizId) async {
    return await _db.collection('quizzes').doc(quizId).get();
  }

  // ... (getAllQuizzes deprecated) ...

  Future<QuizModel?> getQuizById(String quizId) async {
    final doc = await _db.collection('quizzes').doc(quizId).get();
    if (doc.exists) {
      return QuizModel.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // ... (toggle, delete same) ...

  // --- Result Methods ---
  Future<void> submitResult(ResultModel result) async {
    await _db.collection('results').add(result.toMap());
  }

  Future<int> getAttemptCount(String studentId, String quizId) async {
    final snapshot = await _db
        .collection('results')
        .where('studentId', isEqualTo: studentId)
        .where('quizId', isEqualTo: quizId)
        .get();
    return snapshot.docs.length;
  }

  Future<void> cancelResult(String resultId) async {
    await _db.collection('results').doc(resultId).delete();
  }

  Stream<List<ResultModel>> getResultsForStudent(String studentId) {
     // No changes needed, filtered by studentId
    return _db
        .collection('results')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ResultModel.fromMap(doc.data()))
            .toList());
  }
  
  // Need to ensure teacher only sees results for their quizzes (which are filtered by adminId)
  Stream<List<ResultModel>> getResultsByQuizId(String quizId) {
    return _db
        .collection('results')
        .where('quizId', isEqualTo: quizId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ResultModel.fromMap(doc.data()))
            .toList());
  }


  // --- User Management (Admin) ---
  
  Stream<List<UserModel>> getAllUsers() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    });
  }

  Future<void> toggleUserDisabled(String uid, bool currentStatus) async {
    await _db.collection('users').doc(uid).update({'isDisabled': !currentStatus});
  }

  Future<void> updateUser(
  String uid, {
  String? name,
  String? email,
  UserRole? role,
  Map<String, dynamic>? metadata,
  String? adminId, // Added support for admin reassignment
}) async {
  final updates = <String, dynamic>{};
  if (name != null) updates['name'] = name;
  if (email != null) updates['email'] = email;
  if (role != null) updates['role'] = role.name;
  if (metadata != null) updates['metadata'] = metadata;
  if (adminId != null) updates['adminId'] = adminId;
  
  if (updates.isNotEmpty) {
    await _db.collection('users').doc(uid).update(updates);
  }
}
  
  Future<void> createUser(UserModel user, String password) async {
     // Saves user with adminId and createdBy
     await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  // Paginated Users Fetch
  Future<List<UserModel>> getUsersPaginated({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String? roleFilter,
    List<String>? allowedRoles,
    String? searchQuery,
    String? adminId, // New: Filter by Silo
    String? createdBy, // New: Filter by direct creator (optional)
  }) async {
    Query query = _db.collection('users');

    // Silo Filter (Critical)
    if (adminId != null && adminId.isNotEmpty) {
      query = query.where('adminId', isEqualTo: adminId);
    }

    // Applied Filters
    if (roleFilter != null && roleFilter != 'All') {
       query = query.where('role', isEqualTo: roleFilter.toLowerCase());
    } else if (allowedRoles != null && allowedRoles.isNotEmpty) {
       query = query.where('role', whereIn: allowedRoles.map((e) => e.toLowerCase()).toList());
    }
    
    // Direct Creator Filter 
    if (createdBy != null && createdBy.isNotEmpty) {
      query = query.where('createdBy', isEqualTo: createdBy);
    }

    // Search or Sort
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query
          .orderBy('name')
          .startAt([searchQuery])
          .endAt(['$searchQuery\uf8ff']);
    } else {
      query = query.orderBy('name');
    }

    // Pagination
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    query = query.limit(limit);

    try {
      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
         final data = doc.data() as Map<String, dynamic>;
         return UserModel.fromMap(data);
      }).toList();
    } catch (e) {
      print('Firestore Pagination Error: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String uid) async {
    // 1. Delete associated results (optional but good for cleanup)
    final resultsSnapshot = await _db.collection('results').where('studentId', isEqualTo: uid).get();
    for (final doc in resultsSnapshot.docs) {
      await doc.reference.delete();
    }

    // 2. Delete the user document
    await _db.collection('users').doc(uid).delete();
  }

  Future<bool> checkEmailExists(String email) async {
    final snapshot = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  Future<bool> checkRollNumberExists(String rollNumber) async {
    // Note: 'metadata.rollNumber' requires an index or map navigation. 
    // If metadata is a map field, we use dot notation.
    final snapshot = await _db.collection('users').where('metadata.rollNumber', isEqualTo: rollNumber).limit(1).get();
    return snapshot.docs.isNotEmpty;
  }
  
  // --- App Settings (Links) ---
  
  Future<Map<String, String>> getAppLinks() async {
    try {
      final doc = await _db.collection('settings').doc('app_links').get();
      if (doc.exists && doc.data() != null) {
        return Map<String, String>.from(doc.data()!);
      }
    } catch (e) {
      print('Error fetching app links: $e');
    }
    return {
      'windows': '',
      'android': '',
      'web': '',
    };
  }

  Future<void> updateAppLinks(String windows, String android, String web) async {
    await _db.collection('settings').doc('app_links').set({
      'windows': windows,
      'android': android,
      'web': web,
    }, SetOptions(merge: true));
  }

  // --- App Content / Team Management ---

  Stream<AppSettingsModel> getAppSettings() {
    return _db.collection('app_settings').doc('general').snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return AppSettingsModel.fromMap(doc.data()!);
      }
      return AppSettingsModel(teamName: 'Runtime Terrors'); // Default
    });
  }

  Future<void> updateAppSettings(AppSettingsModel settings) async {
    await _db.collection('app_settings').doc('general').set(
          settings.toMap(),
          SetOptions(merge: true),
        );
  }

  Stream<List<TeamMemberModel>> getTeamMembers() {
    return _db.collection('team_members').orderBy('order').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return TeamMemberModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Future<void> addTeamMember(TeamMemberModel member) async {
    // Auto-increment order
    final snapshot = await _db.collection('team_members').orderBy('order', descending: true).limit(1).get();
    int nextOrder = 0;
    if (snapshot.docs.isNotEmpty) {
      nextOrder = (snapshot.docs.first.data()['order'] as int? ?? 0) + 1;
    }

    final newMemberData = member.toMap();
    newMemberData['order'] = nextOrder;

    if (member.id.isEmpty) {
      await _db.collection('team_members').add(newMemberData);
    } else {
      await _db.collection('team_members').doc(member.id).set(newMemberData);
    }
  }

  Future<void> updateTeamOrder(List<TeamMemberModel> members) async {
    final batch = _db.batch();
    for (int i = 0; i < members.length; i++) {
        // Create a new map with the updated order
        // We can't modify the model directly as it might be final, so we create a map update
        batch.update(_db.collection('team_members').doc(members[i].id), {'order': i});
    }
    await batch.commit();
  }

  Future<void> updateTeamMember(TeamMemberModel member) async {
    await _db.collection('team_members').doc(member.id).update(member.toMap());
  }

  Future<void> deleteTeamMember(String id) async {
    await _db.collection('team_members').doc(id).delete();
  }
}
