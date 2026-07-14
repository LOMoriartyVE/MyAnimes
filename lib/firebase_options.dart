// File generated manually from google-services.json
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android; // fallback
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB5yF36RQP0bKhKXcD-L89xJYs7UqbKNIU',
    appId: '1:610655386541:android:bbbb8adee9f4951df7ff24',
    messagingSenderId: '610655386541',
    projectId: 'myanimes-a629e',
    storageBucket: 'myanimes-a629e.firebasestorage.app',
  );
}
