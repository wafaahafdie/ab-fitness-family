// lib/main.dart - VERSION CORRIGÉE (UN SEUL SERVICE DE NOTIFICATIONS)
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';
import 'services/notification_service.dart'; // ⭐ UN SEUL SERVICE

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════
  // 1. FIREBASE
  // ═══════════════════════════════════════════════════════
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Firebase timeout'),
    );
    debugPrint('✅ Firebase initialisé avec succès');

    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      debugPrint('✅ Auth persistance OK');
    } catch (e) {
      debugPrint('⚠️ Erreur persistance: $e');
    }

    // ⭐ Initialisation UNIQUE du service de notifications
    try {
      await NotificationService.init().timeout(
        const Duration(seconds: 8),
      );
      debugPrint('✅ NotificationService initialisé');
    } catch (e) {
      debugPrint('⚠️ Erreur NotificationService: $e');
    }
  } catch (e) {
    debugPrint('❌ Erreur Firebase: $e');
  }

  // ═══════════════════════════════════════════════════════
  // 2. SUPABASE
  // ═══════════════════════════════════════════════════════
  try {
    await Supabase.initialize(
      url: 'https://zpagcqpaybrzhwnekuhh.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpwYWdjcXBheWJyemh3bmVrdWhoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg0Mjg1OTQsImV4cCI6MjEwNDAwNDU5NH0.Ne3gHMzZGvIEvj8mx3SPzuTfiPCqSRN0hVnKCUZ0pa8',
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Supabase timeout'),
    );
    debugPrint('✅ Supabase initialisé avec succès');
  } catch (e) {
    debugPrint('❌ Erreur Supabase: $e');
  }

  // ═══════════════════════════════════════════════════════
  // 3. Lancer l'app
  // ═══════════════════════════════════════════════════════
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    debugPrint('🎧 Configuration de l\'écoute Auth');

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        debugPrint('👤 Utilisateur connecté: ${user.uid}');

        // ⭐ Petit délai pour laisser Firebase Auth se stabiliser
        Future.delayed(const Duration(seconds: 1), () {
          debugPrint('🎧 Démarrage écoute notifications temps réel');
          NotificationService.startListening(); // ⭐ SERVICE UNIQUE
        });
      } else {
        debugPrint('👤 Utilisateur déconnecté');
        NotificationService.stopListening(); // ⭐ SERVICE UNIQUE
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AB Fitness Family',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}