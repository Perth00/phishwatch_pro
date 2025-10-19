// Minimal firebase_options.dart derived from your google-services.json
// Platform: Android

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDER0MFC74vQZAwK29Rhb81R30p9aYeoW8',
    appId: '1:84128569045:android:6cc09310693ba2a052b45c',
    messagingSenderId: '84128569045',
    projectId: 'degreefyp-d6811',
    storageBucket: 'degreefyp-d6811.firebasestorage.app',
  );
}
