import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  Future<UserModel?> signIn(String email, String password) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user == null) {
        throw Exception("Authentication failed");
      }

      // Fetch user details immediately to check role and status
      UserModel? user = await _firestoreService.getUser(cred.user!.uid);

      if (user == null) {
        await _auth.signOut();
        throw Exception("User record not found in database");
      }

      if (user.isDisabled) {
        await _auth.signOut();
        throw Exception("Your account has been disabled. Contact admin.");
      }

      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> updatePassword(String newPassword) async {
    if (_auth.currentUser != null) {
      await _auth.currentUser!.updatePassword(newPassword);
    } else {
      throw Exception('No user logged in');
    }
  }

  // Helper to get current user from firestore if already logged in (e.g. on app restart)
  Future<UserModel?> getCurrentUser() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return null;
    return await _firestoreService.getUser(currentUser.uid);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Create user using a secondary app instance to preserve current admin session
  Future<String> createUserByAdmin(String email, String password) async {
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'tempApp',
      options: Firebase.app().options,
    );

    try {
      UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user!.uid;
    } finally {
      await tempApp.delete();
    }
  }
}
