import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseServices {
  final auth = FirebaseAuth.instance;
  final googleSignIn = GoogleSignIn();

  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();
      if (googleSignInAccount != null) {
        final GoogleSignInAuthentication googleSignInAuthentication =
        await googleSignInAccount.authentication;
        final AuthCredential authCredential = GoogleAuthProvider.credential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken: googleSignInAuthentication.idToken,
        );
        await auth.signInWithCredential(authCredential);
        return true;  // Başarılı giriş
      }
      return false; // Kullanıcı girişten vazgeçti
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: $e');
      return false;
    } catch (e) {
      print('Error during Google Sign-In: $e');
      return false;
    }
  }

  // for sign out
  Future<void> googleSignOut() async {
    await googleSignIn.signOut();
    await auth.signOut();
  }
}
