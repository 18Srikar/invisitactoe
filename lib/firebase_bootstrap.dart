import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseBootstrap {
  static bool _inited = false;
  static Future<void> ensureInitialized() async {
    if (_inited) return;
    await Firebase.initializeApp(); // uses your flutterfire config if present
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    _inited = true;
  }
}
