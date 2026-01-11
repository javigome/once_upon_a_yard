import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';


class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream to listen to auth state changes (Logged In vs Logged Out)
  Stream<User?> get user => _auth.authStateChanges();

  // Get current user ID (Safe getter)
  String get currentUserId => _auth.currentUser?.uid ?? '';
  String get currentUserName => _auth.currentUser?.displayName ?? 'Neighbor';

  // --- SIGN UP (Email/Password) ---
  Future<User?> signUp(String email, String password, String name) async {
    try {
      // 1. Create Auth User
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      User? user = result.user;

      // 2. Update Display Name
      await user?.updateDisplayName(name);

      // 3. Create User Document in Firestore (For badges, karma, etc.)
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'displayName': name,
          'karma': 0,
          'badges': [],
          'joinedAt': FieldValue.serverTimestamp(),
        });
      }
      return user;
    } catch (e) {
      print("Sign Up Error: $e");
      rethrow; // Pass error to UI
    }
  }

  // --- SIGN IN ---
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      print("Sign In Error: $e");
      rethrow;
    }
  }

  // --- SIGN OUT ---
  Future<void> signOut() async {
    await _auth.signOut();
  }


 Future<UserCredential?> signInWithGoogle() async {
          final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
          if (googleUser == null) return null; // User cancelled

          final GoogleSignInAuthentication? googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth?.accessToken,
            idToken: googleAuth?.idToken,
          );

          return await FirebaseAuth.instance.signInWithCredential(credential);
        }
}