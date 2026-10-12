import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

class AuthService {
  final FirebaseAuth _auth;

  AuthService(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _saveUserToFirestore(credential.user!);
      }
      return credential;
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  Future<UserCredential?> createUserWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _saveUserToFirestore(credential.user!);
      }
      return credential;
    } catch (e) {
      throw Exception('Failed to create account: $e');
    }
  }

  Future<UserCredential?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      if (credential.user != null) {
        await _saveUserToFirestore(credential.user!);
      }
      return credential;
    } catch (e) {
      throw Exception('Failed to sign in as guest: $e');
    }
  }

  static const String googleServerClientId =
      '564307519823-fbite8uu02lfn21jbm60hgk54hp2a3u2.apps.googleusercontent.com';

  static GoogleSignInAuthentication? lastGoogleAuth;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential credential;
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        credential = await _auth.signInWithPopup(googleProvider);
      } else if (_isDesktop) {
        try {
          final GoogleAuthProvider googleProvider = GoogleAuthProvider();
          googleProvider.addScope('email');
          googleProvider.addScope('profile');
          credential = await _auth.signInWithProvider(googleProvider);
        } catch (e) {
          debugPrint('Desktop signInWithProvider error: $e');
          throw Exception(
            'Masaüstünde doğrudan Google girişi açılamadı. Lütfen "📱 Moze Connect (QR ile Giriş)" ile telefonunuzdan saniyeler içinde bağlanın veya E-posta/Şifre kullanın.',
          );
        }
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId: googleServerClientId,
          scopes: ['email', 'profile'],
        );

        // Sign out previous cached session to let user choose account
        try {
          await googleSignIn.signOut();
        } catch (_) {}

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) return null; // User canceled

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        lastGoogleAuth = googleAuth;

        if (googleAuth.idToken == null && googleAuth.accessToken == null) {
          throw Exception('Google kimlik bilgisi alınamadı (idToken/accessToken eksik).');
        }

        final OAuthCredential oauthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        credential = await _auth.signInWithCredential(oauthCredential);
      }

      if (credential.user != null) {
        await _saveUserToFirestore(credential.user!);
      }
      return credential;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Google sign-in failed: $e');
    }
  }

  Future<UserCredential?> signInWithApple() async {
    try {
      UserCredential credential;
      if (kIsWeb) {
        final AppleAuthProvider appleProvider = AppleAuthProvider();
        credential = await _auth.signInWithProvider(appleProvider);
      } else if (_isDesktop) {
        try {
          final AppleAuthProvider appleProvider = AppleAuthProvider();
          credential = await _auth.signInWithProvider(appleProvider);
        } catch (e) {
          throw Exception(
            'Apple Sign-In is not supported on Windows. Please use "Continue as Guest" or Email/Password.',
          );
        }
      } else {
        final AuthorizationCredentialAppleID appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

        final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
        final OAuthCredential oauthCredential = oAuthProvider.credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        );

        credential = await _auth.signInWithCredential(oauthCredential);
      }

      if (credential.user != null) {
        await _saveUserToFirestore(credential.user!);
      }
      return credential;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Apple sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb && !_isDesktop) {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId: googleServerClientId,
          scopes: ['email', 'profile'],
        );
        await googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Google SignOut error: $e');
    }
    lastGoogleAuth = null;
    await _auth.signOut();
  }

  /// Creates a device pair session on Desktop (returns 6-char code)
  Future<String> createDevicePairSession() async {
    final rand = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
    final code = 'MZ-$rand';
    await FirebaseFirestore.instance.collection('device_pair_sessions').doc(code).set({
      'code': code,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  /// Listens to device pair session on Desktop
  Stream<DocumentSnapshot<Map<String, dynamic>>> listenToPairSession(String code) {
    return FirebaseFirestore.instance
        .collection('device_pair_sessions')
        .doc(code)
        .snapshots();
  }

  /// Mobile scans/enters code and approves the session
  Future<void> approvePairSession(String code) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Eşleştirmek için önce bu cihazda giriş yapılmış olmalı.');
    }

    String? idToken = lastGoogleAuth?.idToken;
    String? accessToken = lastGoogleAuth?.accessToken;

    // Try refreshing google tokens if null
    if (idToken == null && !kIsWeb && !_isDesktop) {
      try {
        final googleSignIn = GoogleSignIn(
          serverClientId: googleServerClientId,
          scopes: ['email', 'profile'],
        );
        var currentGUser = googleSignIn.currentUser ?? await googleSignIn.signInSilently();
        currentGUser ??= await googleSignIn.signIn();
        if (currentGUser != null) {
          final auth = await currentGUser.authentication;
          idToken = auth.idToken;
          accessToken = auth.accessToken;
          lastGoogleAuth = auth;
        }
      } catch (e) {
        debugPrint('Google token acquisition error: $e');
      }
    }

    await FirebaseFirestore.instance.collection('device_pair_sessions').doc(code).set({
      'code': code,
      'status': 'approved',
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoURL,
      'idToken': idToken,
      'accessToken': accessToken,
      'approvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Desktop completes sign in using the approved pair session
  Future<UserCredential?> completePairOnDesktop(String code, Map<String, dynamic> data) async {
    final googleIdToken = (data['googleIdToken'] ?? data['idToken']) as String?;
    final googleAccessToken = (data['googleAccessToken'] ?? data['accessToken']) as String?;

    UserCredential? credential;
    if (googleIdToken != null || googleAccessToken != null) {
      try {
        final oauthCred = GoogleAuthProvider.credential(
          idToken: googleIdToken,
          accessToken: googleAccessToken,
        );
        credential = await _auth.signInWithCredential(oauthCred);
      } catch (e) {
        debugPrint('Sign in with pair Google credential error: $e');
      }
    }

    // Fallback: If token expired, sign in anonymously but sync user profile
    if (credential == null) {
      try {
        credential = await _auth.signInAnonymously();
      } catch (e) {
        debugPrint('Anonymous fallback sign in error: $e');
      }
    }

    if (credential?.user != null) {
      final user = credential!.user!;
      if (data['displayName'] != null) {
        try {
          await user.updateDisplayName(data['displayName']);
        } catch (_) {}
      }
      if (data['photoUrl'] != null) {
        try {
          await user.updatePhotoURL(data['photoUrl']);
        } catch (_) {}
      }
      try {
        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userDoc.set({
          'uid': user.uid,
          'googleUid': data['uid'],
          'email': data['email'] ?? user.email,
          'displayName': data['displayName'] ?? user.displayName ?? 'User',
          'photoUrl': data['photoUrl'] ?? user.photoURL,
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error saving paired user to Firestore: $e');
      }
    }

    // Delete temporary pair document
    try {
      await FirebaseFirestore.instance.collection('device_pair_sessions').doc(code).delete();
    } catch (_) {}

    return credential;
  }

  Future<void> _saveUserToFirestore(User user) async {
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? user.email?.split('@').first ?? 'User',
          'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      } else {
        await userDoc.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'displayName': user.displayName ?? docSnapshot.data()?['displayName'] ?? 'User',
          'photoUrl': user.photoURL ?? docSnapshot.data()?['photoUrl'],
        });
      }
    } catch (e) {
      debugPrint('Error saving user to Firestore: $e');
    }
  }
}

