
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/quiz_model.dart';
import '../models/result_model.dart';

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
      return null;
      // You might want to rethrow for UI handling
    }
  }

  // --- Quiz Methods ---

  Future<void> createQuiz(QuizModel quiz) async {
    await _db.collection('quizzes').doc(quiz.id).set(quiz.toMap());
  }

  Stream<List<QuizModel>> getQuizzesForStudent() {
    return _db
        .collection('quizzes')
        .where('isPaused', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return QuizModel.fromMap(data);
            })
            .toList());
  }
  
  // Method for teacher/admin to see all quizzes
   Stream<List<QuizModel>> getAllQuizzes() {
    return _db
        .collection('quizzes')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return QuizModel.fromMap(data);
            })
            .toList());
  }

  Future<QuizModel?> getQuizById(String quizId) async {
    try {
      final doc = await _db.collection('quizzes').doc(quizId).get();
      if (doc.exists) {
        return QuizModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> toggleQuizStatus(String quizId, bool currentStatus) async {
      await _db.collection('quizzes').doc(quizId).update({'isPaused': !currentStatus});
  }

  Future<void> deleteQuiz(String quizId) async {
    await _db.collection('quizzes').doc(quizId).delete();
  }

  // --- Result Methods ---

  Future<void> submitResult(ResultModel result) async {
    await _db.collection('results').doc(result.id).set(result.toMap());
  }

  Stream<List<ResultModel>> getResultsForStudent(String studentId) {
    return _db
        .collection('results')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ResultModel.fromMap(doc.data()))
            .toList());
  }

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
  
  Future<void> createUser(UserModel user, String password) async {
     // NOTE: This usually runs in cloud function or secondary app, 
     // but here we might use the client SDK if the signed in user is admin 
     // HOWEVER, client SDK creating another user signs out the current user.
     // For this simulation, we'll assume we just create the document and Auth is handled separately 
     // OR we rely on a specific flow. 
     // Since this is a detailed app, we simply save the user doc here.
     await _db.collection('users').doc(user.uid).set(user.toMap());
  }
}
