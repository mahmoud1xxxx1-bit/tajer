import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/app_user.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._firestore);

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<AppUser> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      
      if (user == null) {
        throw Exception("فشل في تسجيل الدخول المجهول");
      }

      // Check if user exists in Firestore, if not create them
      final docRef = _firestore.collection('users').doc(user.uid);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        final appUser = AppUser(
          id: user.uid,
          createdAt: DateTime.now(),
          isAnonymous: true,
          plan: 'guest',
        );
        await docRef.set(appUser.toJson());
        return appUser;
      } else {
        return AppUser.fromJson(docSnap.data()!);
      }
    } catch (e) {
      throw Exception("حدث خطأ أثناء المصادقة: $e");
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> linkWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return; // User canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.isAnonymous) {
        try {
          await currentUser.linkWithCredential(credential);
          // Successfully linked! Update Firestore user document
          await _firestore.collection('users').doc(currentUser.uid).update({
            'isAnonymous': false,
            'email': googleUser.email,
            'name': googleUser.displayName,
          });
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // The Google account is already linked to another Firebase user.
            // We need to sign in with it and transfer data from anonymous to permanent.
            final anonUid = currentUser.uid;
            
            final userCredential = await _auth.signInWithCredential(credential);
            final permanentUid = userCredential.user!.uid;

            // Optional: Data merging logic can be added here
            // e.g. querying products/customers where merchantId == anonUid
            // and updating them to permanentUid.
            
            // Delete old anonymous user document
            await _firestore.collection('users').doc(anonUid).delete();
            // User is also automatically signed out of anon account 
            // and signed into permanent account by Firebase.
          } else {
            rethrow;
          }
        }
      } else {
        // If not anonymous, just sign in
        await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      throw Exception("حدث خطأ أثناء الربط بحساب جوجل: $e");
    }
  }
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance);
}

@riverpod
Stream<User?> authStateChanges(AuthStateChangesRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
}
