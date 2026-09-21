// lib/HomeVisiteur.dart - AVEC NOTIFICATION SERVICE + BADGE APP ✅
// ⭐ AJOUTÉ : le compteur rouge inclut les demandes supprimées par le chef
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'DetailUserScreen.dart';
import 'RechercheF.dart';
import 'MesDemandesV.dart';
import 'NotifV.dart';
import 'ProfilV.dart';
import 'services/notification_service.dart';

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF6046F4);
const Color pink = Color(0xFFE91E9B);
const Color grey = Color(0xFF9E9EAE);
const Color lightPurple = Color(0xFF9C27B0);
const Color darkPurple = Color(0xFF890CC2);
const Color lavenderBg = Color(0xFFE9E7F7);

// ============================================================
// ⭐ HELPER BASE64
// ============================================================

Uint8List? decodeBase64Image(String? photoUrl) {
  if (photoUrl == null || photoUrl.isEmpty) return null;

  if (photoUrl.startsWith('assets/') ||
      photoUrl.startsWith('http://') ||
      photoUrl.startsWith('https://')) {
    return null;
  }

  try {
    String b64 = photoUrl;
    if (b64.contains(',')) {
      b64 = b64.split(',').last;
    }
    b64 = b64
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('-', '+')
        .replaceAll('_', '/');

    if (b64.isEmpty) return null;

    final mod = b64.length % 4;
    if (mod != 0) {
      b64 = b64.padRight(b64.length + (4 - mod), '=');
    }

    final bytes = base64Decode(b64);
    if (bytes.isEmpty) return null;

    return bytes;
  } catch (e) {
    debugPrint('❌ Erreur Base64: $e');
    return null;
  }
}

// ============================================================
// ⭐ BOUTON RETOUR ÉLÉGANT
// ============================================================

class _ElegantBackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ElegantBackButton({required this.onTap});

  @override
  State<_ElegantBackButton> createState() => _ElegantBackButtonState();
}

class _ElegantBackButtonState extends State<_ElegantBackButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              'assets/images/xx.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: navy,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME VISITEUR
// ============================================================

class HomeVisiteur extends StatefulWidget {
  const HomeVisiteur({super.key});

  @override
  State<HomeVisiteur> createState() => _HomeVisiteurState();
}

class _HomeVisiteurState extends State<HomeVisiteur> {
  String _prenomVisiteur = 'Visiteur';
  String _photoUrl = '';
  Uint8List? _photoBytes;
  bool _isLoading = true;

  // ⭐ Compteurs séparés : demandes traitées + demandes supprimées par le chef
  int _countDemandes = 0; // acceptées / refusées non lues
  int _countSupprimees = 0; // supprimées par le chef, non lues

  /// ⭐ Total affiché dans la pastille rouge + badge de l'icône de l'app
  int get _notifCount => _countDemandes + _countSupprimees;

  StreamSubscription<QuerySnapshot>? _notifSub;
  StreamSubscription<QuerySnapshot>? _supprSub; // ⭐ NOUVEAU
  StreamSubscription<DocumentSnapshot>? _visiteurSub;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.startListening();
      _updateAppBadge(0);
    });

    _chargerInfosVisiteur();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    NotificationService.stopListening();

    _notifSub?.cancel();
    _supprSub?.cancel(); // ⭐
    _visiteurSub?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐⭐⭐ BADGE DE L'ICÔNE DE L'APP ⭐⭐⭐
  // ═══════════════════════════════════════════════════════════

  void _updateAppBadge(int count) {
    try {
      if (count > 0) {
        FlutterAppBadger.updateBadgeCount(count);
        debugPrint('🔴 Badge visiteur mis à jour : $count');
      } else {
        FlutterAppBadger.removeBadge();
        debugPrint('⚪ Badge visiteur retiré');
      }
    } catch (e) {
      debugPrint('❌ Erreur badge : $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ⭐ ÉCOUTE TEMPS RÉEL (BADGE + NOTIFS)
  // ═══════════════════════════════════════════════════════

  void _setupRealtimeListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    debugPrint('🔑 VISITEUR UID: ${user.uid}');

    // ── 1) Demandes acceptées / refusées non lues ─────────────
    _notifSub = FirebaseFirestore.instance
        .collection('DemandesAcces')
        .where('visiteurId', isEqualTo: user.uid)
        .where('statut', whereIn: ['acceptee', 'refusee'])
        .where('lue', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          setState(() {
            _countDemandes = snapshot.docs.length;
          });

          _updateAppBadge(_notifCount);
        }, onError: (e) {
          debugPrint('❌ Erreur écoute notifs: $e');
        });

    // ── 2) ⭐ Demandes supprimées par le chef (non lues) ──────
    _supprSub = FirebaseFirestore.instance
        .collection('Notifications')
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'demande_supprimee')
        .where('lue', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      setState(() {
        _countSupprimees = snapshot.docs.length;
      });

      _updateAppBadge(_notifCount);
    }, onError: (e) {
      debugPrint('❌ Erreur écoute suppressions: $e');
    });

    // ── 3) Infos du visiteur ──────────────────────────────────
    _visiteurSub = FirebaseFirestore.instance
        .collection('Visiteurs')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!mounted || !doc.exists) return;

      final data = doc.data()!;

      String prenom = '';
      if (data['prenom'] != null &&
          data['prenom'].toString().trim().isNotEmpty) {
        prenom = data['prenom'].toString().trim();
      } else if (data['nomComplet'] != null &&
          data['nomComplet'].toString().trim().isNotEmpty) {
        final parts = data['nomComplet'].toString().trim().split(' ');
        prenom = parts.length > 1 ? parts.last : parts.first;
      } else {
        prenom = 'Visiteur';
      }

      final photo = data['photoUrl']?.toString() ?? '';
      Uint8List? photoBytes;
      if (photo.isNotEmpty &&
          !photo.startsWith('http') &&
          !photo.startsWith('assets/')) {
        photoBytes = decodeBase64Image(photo);
      }

      setState(() {
        _prenomVisiteur = prenom;
        _photoUrl = photo;
        _photoBytes = photoBytes;
        _isLoading = false;
      });
    }, onError: (e) {
      debugPrint('❌ Erreur écoute visiteur: $e');
    });
  }

  Future<void> _marquerToutesLues() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ── Demandes acceptées / refusées ─────────────────────────
    try {
      final demandes = await FirebaseFirestore.instance
          .collection('DemandesAcces')
          .where('visiteurId', isEqualTo: user.uid)
          .where('statut', whereIn: ['acceptee', 'refusee']).get();

      final nonLues =
          demandes.docs.where((doc) => doc.data()['lue'] != true).toList();

      if (nonLues.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in nonLues) {
          batch.update(doc.reference, {'lue': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('❌ Erreur marquage: $e');
    }

    // ── ⭐ Demandes supprimées par le chef ────────────────────
    try {
      final supprimees = await FirebaseFirestore.instance
          .collection('Notifications')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'demande_supprimee')
          .where('lue', isEqualTo: false)
          .get();

      if (supprimees.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in supprimees.docs) {
          batch.update(doc.reference, {'lue': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('❌ Erreur marquage suppressions: $e');
    }

    _updateAppBadge(0);
  }

  Future<void> _chargerInfosVisiteur() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('Visiteurs')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final data = doc.data()!;

      String prenom = '';
      if (data['prenom'] != null &&
          data['prenom'].toString().trim().isNotEmpty) {
        prenom = data['prenom'].toString().trim();
      } else if (data['nomComplet'] != null &&
          data['nomComplet'].toString().trim().isNotEmpty) {
        final parts = data['nomComplet'].toString().trim().split(' ');
        prenom = parts.length > 1 ? parts.last : parts.first;
      } else {
        prenom = 'Visiteur';
      }

      final photo = data['photoUrl']?.toString() ?? '';
      Uint8List? photoBytes;
      if (photo.isNotEmpty &&
          !photo.startsWith('http') &&
          !photo.startsWith('assets/')) {
        photoBytes = decodeBase64Image(photo);
      }

      // Demandes acceptées / refusées non lues
      int countDemandes = 0;
      try {
        final notifSnapshot = await FirebaseFirestore.instance
            .collection('DemandesAcces')
            .where('visiteurId', isEqualTo: user.uid)
            .where('statut', whereIn: ['acceptee', 'refusee'])
            .where('lue', isEqualTo: false)
            .get();
        countDemandes = notifSnapshot.docs.length;
      } catch (e) {
        debugPrint('⚠️ Erreur notifications: $e');
      }

      // ⭐ Demandes supprimées par le chef (non lues)
      int countSupprimees = 0;
      try {
        final supprSnapshot = await FirebaseFirestore.instance
            .collection('Notifications')
            .where('userId', isEqualTo: user.uid)
            .where('type', isEqualTo: 'demande_supprimee')
            .where('lue', isEqualTo: false)
            .get();
        countSupprimees = supprSnapshot.docs.length;
      } catch (e) {
        debugPrint('⚠️ Erreur notifications suppressions: $e');
      }

      if (mounted) {
        setState(() {
          _prenomVisiteur = prenom;
          _photoUrl = photo;
          _photoBytes = photoBytes;
          _countDemandes = countDemandes;
          _countSupprimees = countSupprimees;
          _isLoading = false;
        });

        _updateAppBadge(_notifCount);
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement visiteur: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _asset(String name,
      {double size = 24, Color? color, IconData? fallback}) {
    return Image.asset(
      'assets/images/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        return Icon(fallback ?? Icons.circle, size: size, color: color ?? navy);
      },
    );
  }

  Widget _buildAvatar() {
    const double size = 46;

    if (_photoBytes != null && _photoBytes!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFF0EDFF),
        ),
        child: ClipOval(
          child: Image.memory(
            _photoBytes!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _defaultAvatar(),
          ),
        ),
      );
    }

    if (_photoUrl.isNotEmpty &&
        (_photoUrl.startsWith('http://') || _photoUrl.startsWith('https://'))) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFF0EDFF),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: _photoUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => _defaultAvatar(),
            errorWidget: (_, __, ___) => _defaultAvatar(),
          ),
        ),
      );
    }

    if (_photoUrl.startsWith('assets/')) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFF0EDFF),
        ),
        child: ClipOval(
          child: Image.asset(
            _photoUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultAvatar(),
          ),
        ),
      );
    }

    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        color: Color(0xFFF0EDFF),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/profilpat.jpg',
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFFF0EDFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: purple, size: 24),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGreetingWithGradientName() {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        children: [
          const TextSpan(
            text: 'Bonjour, ',
            style: TextStyle(color: navy),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF6046F4),
                  Color(0xFF9C27B0),
                  Color(0xFFE91E9B),
                ],
              ).createShader(bounds),
              child: Text(
                _prenomVisiteur,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const TextSpan(
            text: ' !',
            style: TextStyle(color: navy),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientContainer({
    required Widget child,
    double radius = 20,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE2D9F3),
            Color(0xFFF7DDF0),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius - 1.5),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _ElegantBackButton(
                        onTap: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Accueil',
                        style: TextStyle(
                          color: navy,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await _marquerToutesLues();
                          if (!mounted) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotifV(),
                            ),
                          );
                          _chargerInfosVisiteur();
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _asset(
                              'notif',
                              size: 30,
                              fallback: Icons.notifications_none,
                            ),
                            if (_notifCount > 0)
                              Positioned(
                                top: -6,
                                right: -8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                      minWidth: 20, minHeight: 20),
                                  child: Text(
                                    _notifCount > 99 ? '99+' : '$_notifCount',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfilV(),
                            ),
                          );
                          _chargerInfosVisiteur();
                        },
                        child: _buildAvatar(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? Row(
                      children: [
                        Container(
                          width: 150,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    )
                  : _buildGreetingWithGradientName(),
              const SizedBox(height: 6),
              const Text(
                'Que souhaitiez-vous faire ?',
                style: TextStyle(
                  color: grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBigCard(
                        icon: 'rec',
                        fallback: Icons.search,
                        title: 'Recherche une famille',
                        subtitle:
                            'Recherchez une famille et envoyez une demande d\'accès au chef de famille.',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RechercheF(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildGradientContainer(
                        radius: 24,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 16),
                          child: Column(
                            children: [
                              _buildListCard(
                                icon: 'qst',
                                fallback: Icons.help_outline,
                                title: 'Mes demandes',
                                subtitle:
                                    'Voir l\'état de toutes mes demandes.',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const MesDemandesV(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildListCard(
                                icon: 'notif',
                                fallback: Icons.notifications_outlined,
                                title: 'Notifications',
                                subtitle: 'Voir mes notifications récentes.',
                                badgeCount:
                                    _notifCount > 0 ? _notifCount : null,
                                onTap: () async {
                                  await _marquerToutesLues();
                                  if (!mounted) return;
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const NotifV(),
                                    ),
                                  );
                                  _chargerInfosVisiteur();
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildListCard(
                                icon: 'profilpat',
                                fallback: Icons.person_outline,
                                title: 'Mon profil',
                                subtitle:
                                    'Gérer mes informations personnelles.',
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ProfilV(),
                                    ),
                                  );
                                  _chargerInfosVisiteur();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBigCard({
    required String icon,
    required IconData fallback,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _buildGradientContainer(
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _asset(
                    icon,
                    size: 30,
                    color: Colors.white,
                    fallback: fallback,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: grey, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCard({
    required String icon,
    required IconData fallback,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0EDFF)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _asset(
                      icon,
                      size: 26,
                      color: Colors.white,
                      fallback: fallback,
                    ),
                  ),
                ),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: grey, size: 26),
          ],
        ),
      ),
    );
  }
}
