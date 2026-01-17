
// File generated manually to bypass CLI error.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // TODO: Replace with your keys from Firebase Console > Project Settings > General > Web App
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCwaCazxXh94E3FRAOqnPLNXOeFROR9wiU',
    appId: '1:164927083458:web:2389328337506589177c5b',
    messagingSenderId: '164927083458',
    projectId: 'battery-quiz',
    authDomain: 'battery-quiz.firebaseapp.com',
    storageBucket: 'battery-quiz.firebasestorage.app',
    measurementId: 'G-S4VLZ6WXXT',
  );

  // TODO: Replace with your keys from Firebase Console > Project Settings > General > Android App
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC9-TLjKDBBByY3ifDnnWlgbvNJXxOxWDI',
    appId: '1:164927083458:android:608e5db52501d756177c5b',
    messagingSenderId: '164927083458',
    projectId: 'battery-quiz',
    storageBucket: 'battery-quiz.firebasestorage.app',
  );

  // TODO: Replace with your keys from Firebase Console > Project Settings > General > iOS App
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_MESSAGING_SENDER_ID',
    projectId: 'battery-quiz',
    storageBucket: 'battery-quiz.appspot.com',
    iosBundleId: 'com.quizapp.quizApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_WITH_MACOS_API_KEY',
    appId: 'REPLACE_WITH_MACOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_MESSAGING_SENDER_ID',
    projectId: 'battery-quiz',
    storageBucket: 'battery-quiz.appspot.com',
    iosBundleId: 'com.quizapp.quizApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCwaCazxXh94E3FRAOqnPLNXOeFROR9wiU',
    appId: '1:164927083458:web:de4c2be8e799e287177c5b',
    messagingSenderId: '164927083458',
    projectId: 'battery-quiz',
    authDomain: 'battery-quiz.firebaseapp.com',
    storageBucket: 'battery-quiz.firebasestorage.app',
    measurementId: 'G-BJ70ZWB0CX',
  );
}