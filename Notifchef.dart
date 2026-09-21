// lib/Notifchef.dart - AVEC BOUTON RETOUR xx.png ✅
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1E2235);
const Color grey = Color(0xFF9E9EAE);
const Color borderPurple = Color(0xFF890CC2);
const Color lightPurple = Color(0xFF9C27B0);
const Color darkBlue = Color(0xFF1F2A6B);

// ============================================================
// HELPER BASE64 → Uint8List
// ============================================================

Uint8List? _decodeBase64Image(String? photoUrl) {
  if (photoUrl == null || photoUrl.isEmpty) return null;
  if (photoUrl.startsWith('assets/') ||
      photoUrl.startsWith('http://') ||
      photoUrl.startsWith('https://')) return null;
  try {
    String b64 = photoUrl;
    if (b64.contains(',')) b64 = b64.split(',').last;
    b64 = b64
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('-', '+')
        .replaceAll('_', '/');
    if (b64.isEmpty) return null;
    final mod = b64.length % 4;
    if (mod != 0) b64 = b64.padRight(b64.length + (4 - mod), '=');
    return base64Decode(b64);
  } catch (e) {
    return null;
  }
}

// ============================================================
// NOTIFICATION CHEF SCREEN
// ============================================================

class Notifchef extends StatefulWidget {
  const Notifchef({Key? key}) : super(key: key);

  @override
  State<Notifchef> createState() => _NotifchefState();
}

class _NotifchefState extends State<Notifchef> {
  String? _chefId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _demandes = [];
  StreamSubscription<QuerySnapshot>? _sub;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('🆕 Notifchef (chef) chargée !');
    _init();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _chefId = user.uid;
    _listenDemandes();
  }

  void _listenDemandes() {
    if (_chefId == null) return;
    _sub?.cancel();

    _sub = FirebaseFirestore.instance
        .collection('DemandesAcces')
        .where('chefId', isEqualTo: _chefId)
        .snapshots()
        .listen((snapshot) async {
      if (!mounted) return;

      final List<Map<String, dynamic>> list = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        final visiteurId = data['visiteurId']?.toString() ?? '';
        if (visiteurId.isNotEmpty) {
          try {
            final vDoc = await FirebaseFirestore.instance
                .collection('Visiteurs')
                .doc(visiteurId)
                .get();

            if (vDoc.exists) {
              final vData = vDoc.data()!;
              String fullName = '';
              if (vData['nomComplet'] != null &&
                  vData['nomComplet'].toString().trim().isNotEmpty) {
                fullName = vData['nomComplet'].toString().trim();
              } else {
                final prenom = vData['prenom']?.toString().trim() ?? '';
                final nom = vData['nom']?.toString().trim() ?? '';
                fullName = '$prenom $nom'.trim();
              }
              if (fullName.isEmpty) {
                fullName = vData['email']?.toString() ?? 'Visiteur';
              }
              data['visiteurNom'] = fullName;
              data['visiteurPhoto'] = vData['photoUrl']?.toString() ?? '';
            }
          } catch (e) {
            debugPrint('⚠️ Erreur chargement visiteur: $e');
          }
        }

        if (data['visiteurNom'] == null ||
            data['visiteurNom'].toString().trim().isEmpty) {
          data['visiteurNom'] = 'Visiteur';
        }

        list.add(data);
      }

      list.sort((a, b) {
        final da = a['dateDemande'];
        final db = b['dateDemande'];
        if (da is Timestamp && db is Timestamp) return db.compareTo(da);
        return 0;
      });

      if (mounted) {
        setState(() {
          _demandes = list;
          _isLoading = false;
        });
      }
    }, onError: (e) {
      debugPrint('❌ Erreur stream: $e');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _formatRelativeTime(dynamic date) {
    if (date == null) return 'Date inconnue';

    DateTime dt;
    if (date is Timestamp) {
      dt = date.toDate();
    } else if (date is String) {
      try {
        dt = DateTime.parse(date);
      } catch (_) {
        return 'Date inconnue';
      }
    } else {
      return 'Date inconnue';
    }

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'Il y a ${diff.inSeconds} sec';
    } else if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays}j';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return 'Il y a ${weeks} sem';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return 'Il y a ${months} mois';
    } else {
      final years = (diff.inDays / 365).floor();
      return 'Il y a ${years} an${years > 1 ? 's' : ''}';
    }
  }

  Map<String, String> _splitName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return {'firstName': 'Visiteur', 'lastName': ''};
    if (parts.length == 1) return {'firstName': parts[0], 'lastName': ''};
    return {
      'firstName': parts.first,
      'lastName': parts.sublist(1).join(' '),
    };
  }

  String _buildActionText(Map<String, dynamic> d) {
    final motif = d['motif']?.toString().trim() ?? '';
    if (motif.isEmpty) {
      return 'veut accéder à votre famille.';
    }
    return 'veut accéder à votre famille pour : "$motif".';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 13, 18, 16),
              color: Colors.white,
              child: Row(
                children: [
                  _ElegantBackButton(
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      color: navy,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Container(height: 1, color: const Color(0xFFF0F0F5)),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: lightPurple))
                  : _demandes.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
                          itemCount: _demandes.length,
                          itemBuilder: (context, index) {
                            final d = _demandes[index];
                            final fullName =
                                d['visiteurNom']?.toString() ?? 'Visiteur';
                            final names = _splitName(fullName);

                            return NotificationCard(
                              photoUrl: d['visiteurPhoto']?.toString() ?? '',
                              visitorType: 'Visiteur',
                              firstName: names['firstName'] ?? '',
                              lastName: names['lastName'] ?? '',
                              action: _buildActionText(d),
                              time: _formatRelativeTime(d['dateDemande']),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFF0EDFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none,
              color: lightPurple,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune notification',
            style: TextStyle(
              color: navy,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Les nouvelles demandes s\'afficheront ici',
            style: TextStyle(color: grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ⭐ BOUTON RETOUR ÉLÉGANT (avec xx.png comme les autres pages)
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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              'assets/images/xx.png', // ⭐ ICÔNE xx.png
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: navy,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// WIDGET : NOTIFICATION CARD
// ============================================================

class NotificationCard extends StatelessWidget {
  final String photoUrl;
  final String visitorType;
  final String firstName;
  final String lastName;
  final String action;
  final String time;

  const NotificationCard({
    Key? key,
    required this.photoUrl,
    required this.visitorType,
    required this.firstName,
    required this.lastName,
    required this.action,
    required this.time,
  }) : super(key: key);

  Widget _buildAvatar() {
    const bg = Color(0xFFF0F0F2);
    const size = 44.0;

    final bytes = _decodeBase64Image(photoUrl);
    if (bytes != null && bytes.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: bg, shape: BoxShape.circle),
        child: ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _defaultAvatar(),
          ),
        ),
      );
    }

    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: bg, shape: BoxShape.circle),
        child: ClipOval(
          child: Image.network(
            photoUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _defaultAvatar(),
          ),
        ),
      );
    }

    if (photoUrl.startsWith('assets/')) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: bg, shape: BoxShape.circle),
        child: ClipOval(
          child: Image.asset(
            photoUrl,
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
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFF0F0F2),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, color: grey, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderPurple.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: navy,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: 'Le $visitorType, ',
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                      TextSpan(
                        text: '$firstName $lastName',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: darkBlue,
                        ),
                      ),
                      TextSpan(
                        text: ' $action',
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: darkBlue,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: const TextStyle(
                        color: darkBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
