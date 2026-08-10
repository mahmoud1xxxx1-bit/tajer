import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';

class MockFirebaseAuthPlatform extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({dynamic app}) {
    return this;
  }
}
void main() {
  FirebaseAuthPlatform.instance = MockFirebaseAuthPlatform();
  print('Success');
}
