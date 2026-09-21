// HomeChefScreen.dart - AVEC NOTIFICATION SERVICE + BADGE APP ✅
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'DetailUserScreen.dart';
import 'AddMembreScreen.dart';
import 'DemandeAccesScreen.dart';
import 'Notifchef.dart';
import 'RoleSelectionScreen.dart';
import 'services/notification_service.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1E2235);
const Color purple = Color(0xFF6046F4);
const Color pink = Color(0xFFE91E9B);
const Color grey = Color(0xFF9E9EAE);
const Color lightPurple = Color(0xFF9C27B0);
const Color borderPurple = Color(0xFF890CC2);
const Color onlineGreen = Color(0xFF33C56A);
const Color birthdayGold = Color(0xFFFFB020);

// ============================================================
// HELPER GLOBAL - DÉCODAGE BASE64 SÉCURISÉ
// ============================================================

Uint8List? decodeBase64Image(String? photoUrl) {
  if (photoUrl == null || photoUrl.isEmpty) return null;
  if (photoUrl.startsWith('assets/') ||
      photoUrl.startsWith('http://') ||
      photoUrl.startsWith('https://')) {
    return null;
  }
  try {
    String base64String = photoUrl;
    if (base64String.contains(',')) {
      base64String = base64String.split(',').last;
    }
    base64String = base64String
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll(' ', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll('\t', '')
        .trim();
    if (base64String.isEmpty) return null;
    final mod = base64String.length % 4;
    if (mod != 0) {
      base64String =
          base64String.padRight(base64String.length + (4 - mod), '=');
    }
    return base64Decode(base64String);
  } catch (e) {
    debugPrint('⚠️ Erreur décodage Base64: $e');
    return null;
  }
}

Widget buildUniversalAvatar(String? photoUrl, {double radius = 36}) {
  if (photoUrl == null || photoUrl.isEmpty) return _defaultAvatar(radius);
  if (photoUrl.startsWith('assets/')) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFF0F0F2),
      child: ClipOval(
        child: Image.asset(
          photoUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAvatarChild(radius),
        ),
      ),
    );
  }
  if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFF0F0F2),
      child: ClipOval(
        child: Image.network(
          photoUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAvatarChild(radius),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _defaultAvatarChild(radius);
          },
        ),
      ),
    );
  }
  final bytes = decodeBase64Image(photoUrl);
  if (bytes != null && bytes.isNotEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFF0F0F2),
      child: ClipOval(
        child: Image.memory(
          bytes,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _defaultAvatarChild(radius),
        ),
      ),
    );
  }
  return _defaultAvatar(radius);
}

Widget _defaultAvatar(double radius) {
  return CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFF0F0F2),
    child: _defaultAvatarChild(radius),
  );
}

Widget _defaultAvatarChild(double radius) {
  return Icon(Icons.person, color: grey, size: radius * 1.2);
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
// ⭐ BOUTON ANIMÉ "AJOUTER UN MEMBRE"
// ============================================================

class _AnimatedAddMemberButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedAddMemberButton({required this.onTap});

  @override
  State<_AnimatedAddMemberButton> createState() =>
      _AnimatedAddMemberButtonState();
}

class _AnimatedAddMemberButtonState extends State<_AnimatedAddMemberButton>
    with TickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final AnimationController _shimmerController;
  late final AnimationController _iconController;
  late final Animation<double> _iconRotate;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _iconRotate = Tween<double>(begin: 0.0, end: 0.25).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (!mounted) return;
    setState(() => _pressed = value);
    if (value) {
      _iconController.forward();
    } else {
      _iconController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnim, _shimmerController]),
          builder: (context, child) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: borderPurple
                        .withOpacity(0.10 + (_pulseAnim.value * 0.12)),
                    blurRadius: 16 + (_pulseAnim.value * 10),
                    spreadRadius: _pulseAnim.value * 2,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Color.lerp(
                          borderPurple.withOpacity(0.7),
                          borderPurple,
                          _pulseAnim.value,
                        )!,
                        width: 1.2 + (_pulseAnim.value * 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        AnimatedBuilder(
                          animation: _iconRotate,
                          builder: (context, _) {
                            return Transform.rotate(
                              angle: _iconRotate.value * 3.14159,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E8FF),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: lightPurple.withOpacity(
                                          0.15 + _pulseAnim.value * 0.15),
                                      blurRadius: 8 + _pulseAnim.value * 8,
                                      spreadRadius: _pulseAnim.value * 1.5,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/plus.png',
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.person_add_alt_1,
                                      color: lightPurple,
                                      size: 24,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ajouter un Membre',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: navy,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Inviter un nouveau Membre',
                                style: TextStyle(fontSize: 12, color: grey),
                              ),
                            ],
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, _) {
                            return Transform.translate(
                              offset: Offset(_pulseAnim.value * 4, 0),
                              child: const Icon(
                                Icons.chevron_right,
                                color: navy,
                                size: 24,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, _) {
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: 0.35,
                              child: Transform.translate(
                                offset: Offset(
                                  (_shimmerController.value * 4 - 1) *
                                      MediaQuery.of(context).size.width,
                                  0,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.white.withOpacity(0.0),
                                        Colors.white.withOpacity(0.55),
                                        Colors.white.withOpacity(0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// HOME CHEF SCREEN
// ============================================================

class HomeChefScreen extends StatefulWidget {
  const HomeChefScreen({Key? key}) : super(key: key);

  @override
  State<HomeChefScreen> createState() => _HomeChefScreenState();
}

class _HomeChefScreenState extends State<HomeChefScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = -1;
  late final AnimationController _menuAnimController;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _familyId;

  String? _chefPhotoUrl;
  String? _chefFullName;
  String? _chefBirthDate;
  int _notificationCount = 0;
  int _birthdayCount = 0;

  bool _isSelectionMode = false;
  String? _selectedMemberId;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  StreamSubscription<DocumentSnapshot>? _chefSubscription;
  StreamSubscription<QuerySnapshot>? _membersSubscription;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;
  StreamSubscription<QuerySnapshot>? _presenceSubscription;

  Set<String> _authorizedMemberIds = {};
  Set<String> _onlineMemberIds = {};

  // ⭐ Cache lastSeen + timers présence
  final Map<String, DateTime> _lastSeenCache = {};
  Timer? _presenceRefreshTimer;
  Timer? _presenceHeartbeat;

  @override
  void initState() {
    super.initState();
    _menuAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      NotificationService.startListening();
      _updateAppBadge(0);
      await _publishPresence();
    });

    _loadData();
    _setupRealtimeListeners();
    _searchController.addListener(_filterMembers);
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐⭐⭐ BADGE DE L'ICÔNE DE L'APP ⭐⭐⭐
  // ═══════════════════════════════════════════════════════════

  void _updateAppBadge(int count) {
    try {
      if (count > 0) {
        FlutterAppBadger.updateBadgeCount(count);
        debugPrint('🔴 Badge mis à jour : $count');
      } else {
        FlutterAppBadger.removeBadge();
        debugPrint('⚪ Badge retiré');
      }
    } catch (e) {
      debugPrint('❌ Erreur badge : $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐⭐⭐ PRÉSENCE DU CHEF ⭐⭐⭐
  // ═══════════════════════════════════════════════════════════

  Future<void> _publishPresence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance.collection('Presence').doc(user.uid);

    Future<void> ping() async {
      try {
        await ref.set({
          'memberId': user.uid,
          'isActive': true,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('⚠️ presence ping: $e');
      }
    }

    await ping();
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat =
        Timer.periodic(const Duration(seconds: 15), (_) => ping());
  }

  Future<void> _unpublishPresence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('Presence')
          .doc(user.uid)
          .set({
        'isActive': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ⭐ Recalcule qui est en ligne : isActive + lastSeen < 30s
  void _recomputeOnlineIds() {
    if (!mounted) return;
    final now = DateTime.now();
    final Set<String> online = {};
    _lastSeenCache.forEach((id, lastSeen) {
      if (now.difference(lastSeen).inSeconds < 30) {
        online.add(id);
      }
    });
    if (online.length != _onlineMemberIds.length ||
        !online.every(_onlineMemberIds.contains)) {
      setState(() => _onlineMemberIds = online);
    }
  }

  DateTime? _parseBirthDate(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return null;
    try {
      if (birthDateStr.contains('-') && birthDateStr.length == 10) {
        return DateTime.parse(birthDateStr);
      }
      if (birthDateStr.contains('/')) {
        final parts = birthDateStr.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          if (year > 1900 &&
              year < 2100 &&
              month >= 1 &&
              month <= 12 &&
              day >= 1 &&
              day <= 31) {
            return DateTime(year, month, day);
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  int _countBirthdaysToday(List<Map<String, dynamic>> members) {
    DateTime now = DateTime.now();
    int count = 0;
    for (var member in members) {
      String? birthDateStr = member['birthDate'] ?? member['birth_date'];
      if (birthDateStr != null && birthDateStr.isNotEmpty) {
        final DateTime? birthDate = _parseBirthDate(birthDateStr);
        if (birthDate != null) {
          if (birthDate.month == now.month && birthDate.day == now.day) {
            count++;
          }
        }
      }
    }
    return count;
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐⭐⭐ COMPTEUR "EN LIGNE" ⭐⭐⭐
  // = Chef (auto-autorisé) + membres autorisés
  //   qui sont en train de consulter.
  // Visiteurs + non-autorisés = IGNORÉS.
  // ═══════════════════════════════════════════════════════════

  int _countOnlineAuthorizedMembers() {
    int count = 0;

    for (var m in _members) {
      final String userId =
          (m['userId'] ?? m['user_id'] ?? m['id'] ?? '').toString();
      final String memberDocId = m['id']?.toString() ?? '';
      final bool isHead = m['isHead'] ?? m['is_head'] ?? false;

      // ✅ Chef = auto-autorisé
      // ✅ Membre = autorisé seulement s'il est dans _authorizedMemberIds
      final bool isAuthorized = isHead ||
          _authorizedMemberIds.contains(userId) ||
          _authorizedMemberIds.contains(memberDocId);

      // ⛔ Visiteur (ni chef, ni autorisé) → ignoré
      if (!isAuthorized) continue;

      // ✅ Compté seulement s'il est réellement en ligne maintenant
      final bool isOnline = _onlineMemberIds.contains(userId) ||
          _onlineMemberIds.contains(memberDocId);
      if (isOnline) count++;
    }

    debugPrint('🟢 En ligne (chef + autorisés) : $count');
    return count;
  }

  bool _isBirthdayToday(Map<String, dynamic> member) {
    DateTime now = DateTime.now();
    String? birthDateStr = member['birthDate'] ?? member['birth_date'];
    if (birthDateStr != null && birthDateStr.isNotEmpty) {
      final DateTime? birthDate = _parseBirthDate(birthDateStr);
      if (birthDate != null) {
        return birthDate.month == now.month && birthDate.day == now.day;
      }
    }
    return false;
  }

  bool _isChefBirthdayToday() {
    if (_chefBirthDate == null || _chefBirthDate!.isEmpty) return false;
    final DateTime? birthDate = _parseBirthDate(_chefBirthDate);
    if (birthDate == null) return false;
    final now = DateTime.now();
    return birthDate.month == now.month && birthDate.day == now.day;
  }

  void _filterMembers() {
    final String query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredMembers = List.from(_members);
        _birthdayCount = _countBirthdaysToday(_members);
      });
      return;
    }
    setState(() {
      _filteredMembers = _members.where((member) {
        final String fullName =
            (member['fullName'] ?? member['full_name'] ?? '')
                .toString()
                .toLowerCase();
        final String email = (member['email'] ?? '').toString().toLowerCase();
        final String phone = (member['phone'] ?? '').toString().toLowerCase();
        final String address =
            (member['address'] ?? '').toString().toLowerCase();
        final String gender = (member['gender'] ?? '').toString().toLowerCase();
        final String birthDate =
            (member['birthDate'] ?? member['birth_date'] ?? '')
                .toString()
                .toLowerCase();
        final String role = (member['role'] ?? '').toString().toLowerCase();
        final String relationship =
            (member['relationship'] ?? '').toString().toLowerCase();
        final String relation =
            (member['relation'] ?? '').toString().toLowerCase();
        final String lien = (member['lien'] ?? '').toString().toLowerCase();
        final String allRelations =
            '$role $relationship $relation $lien'.toLowerCase();

        return fullName.contains(query) ||
            allRelations.contains(query) ||
            email.contains(query) ||
            phone.contains(query) ||
            address.contains(query) ||
            gender.contains(query) ||
            birthDate.contains(query);
      }).toList();
      _birthdayCount = _countBirthdaysToday(_filteredMembers);
    });
  }

  void _setupRealtimeListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _currentUserId = user.uid;

    _chefSubscription = FirebaseFirestore.instance
        .collection('Chef de Famille')
        .doc(user.uid)
        .snapshots()
        .listen((chefSnapshot) {
      if (!mounted) return;
      if (chefSnapshot.exists) {
        final chefData = chefSnapshot.data()!;
        _familyId = chefData['familyId'] ?? chefData['family_id'];
        _chefFullName = chefData['fullName'] ?? chefData['full_name'] ?? 'Chef';
        _chefPhotoUrl = chefData['photoUrl'] ??
            chefData['photo_url'] ??
            'assets/images/profilpat.jpg';
        _chefBirthDate = chefData['birthDate'] ?? chefData['birth_date'] ?? '';
        if (_familyId != null && _familyId!.isNotEmpty) {
          _listenToMembers();
        }
      }
    }, onError: (error) {
      debugPrint('❌ Erreur écoute chef: $error');
    });

    _notificationsSubscription = FirebaseFirestore.instance
        .collection('DemandesAcces')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      int count = 0;
      final Set<String> authorizedIds = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final chefId = data['chefId']?.toString() ?? '';
        final statut = data['statut']?.toString() ?? '';
        final isRead = data['isRead'] == true;
        final membresAutorises = data['membresAutorises'];

        if (chefId == user.uid && statut == 'en_attente' && !isRead) {
          count++;
        }

        if (chefId == user.uid && statut == 'acceptee') {
          if (membresAutorises is List) {
            for (var m in membresAutorises) {
              if (m != null && m.toString().isNotEmpty) {
                authorizedIds.add(m.toString());
              }
            }
          }
        }
      }

      setState(() {
        _notificationCount = count;
        _authorizedMemberIds = authorizedIds;
      });

      _updateAppBadge(count);
    }, onError: (error) {
      debugPrint('❌ Erreur écoute demandes: $error');
    });

    // ⭐ Présence : cache local + refresh toutes les 5s
    _presenceSubscription = FirebaseFirestore.instance
        .collection('Presence')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      _lastSeenCache.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['isActive'] != true) continue;

        final memberId = data['memberId']?.toString() ?? doc.id;
        final lastSeen = data['lastSeen'];
        if (lastSeen is Timestamp) {
          _lastSeenCache[memberId] = lastSeen.toDate();
        }
      }
      _recomputeOnlineIds();
    }, onError: (e) {
      debugPrint('❌ Erreur présence: $e');
    });

    _presenceRefreshTimer?.cancel();
    _presenceRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _recomputeOnlineIds(),
    );
  }

  Future<void> _marquerToutesLues() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final demandes = await FirebaseFirestore.instance
          .collection('DemandesAcces')
          .where('chefId', isEqualTo: user.uid)
          .where('statut', isEqualTo: 'en_attente')
          .get();
      final nonLues =
          demandes.docs.where((doc) => doc.data()['isRead'] != true).toList();
      if (nonLues.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in nonLues) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ Erreur marquage: $e');
    }
  }

  void _listenToMembers() {
    _membersSubscription?.cancel();
    if (_familyId == null || _familyId!.isEmpty) return;

    _membersSubscription = FirebaseFirestore.instance
        .collection('Membres Famille')
        .where('familyId', isEqualTo: _familyId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      List<Map<String, dynamic>> membersList = [];

      membersList.add({
        'id': _currentUserId ?? '',
        'fullName': _chefFullName ?? 'Chef',
        'email': '',
        'phone': '',
        'address': '',
        'role': 'Chef de famille',
        'isHead': true,
        'photoUrl': _chefPhotoUrl ?? 'assets/images/profilpat.jpg',
        'userId': _currentUserId,
        'familyId': _familyId,
        'birthDate': _chefBirthDate ?? '',
        'birth_date': _chefBirthDate ?? '',
        'gender': '',
        'relationship': 'Chef de famille',
        'relation': 'Chef de famille',
        'lien': 'Chef de famille',
      });

      FirebaseFirestore.instance
          .collection('Chef de Famille')
          .doc(_currentUserId)
          .get()
          .then((chefDoc) {
        if (!mounted) return;
        if (chefDoc.exists) {
          final chefData = chefDoc.data()!;
          setState(() {
            final chefIndex =
                membersList.indexWhere((m) => m['id'] == _currentUserId);
            if (chefIndex != -1) {
              membersList[chefIndex]['birthDate'] =
                  chefData['birthDate'] ?? chefData['birth_date'] ?? '';
              membersList[chefIndex]['birth_date'] =
                  chefData['birthDate'] ?? chefData['birth_date'] ?? '';
              membersList[chefIndex]['gender'] = chefData['gender'] ?? '';
              membersList[chefIndex]['email'] = chefData['email'] ?? '';
              membersList[chefIndex]['phone'] = chefData['phone'] ?? '';
              membersList[chefIndex]['address'] = chefData['address'] ?? '';
            }
            _birthdayCount = _countBirthdaysToday(membersList);
          });
        }
      });

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] ?? data['user_id'] ?? '';
        if (userId == _currentUserId) continue;
        final String roleValue = data['relationship'] ??
            data['role'] ??
            data['relation'] ??
            data['lien'] ??
            'Membre';
        membersList.add({
          'id': doc.id,
          'fullName': data['fullName'] ?? data['full_name'] ?? 'Membre',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'address': data['address'] ?? '',
          'role': roleValue,
          'relationship': data['relationship'] ?? roleValue,
          'relation': data['relation'] ?? roleValue,
          'lien': data['lien'] ?? roleValue,
          'isHead': data['isHead'] ?? data['is_head'] ?? false,
          'photoUrl': data['photoUrl'] ??
              data['photo_url'] ??
              'assets/images/profilpat.jpg',
          'userId': userId,
          'familyId': data['familyId'] ?? data['family_id'] ?? _familyId,
          'birthDate': data['birthDate'] ?? data['birth_date'] ?? '',
          'birth_date': data['birthDate'] ?? data['birth_date'] ?? '',
          'gender': data['gender'] ?? '',
        });
      }

      setState(() {
        _members = membersList;
        _filteredMembers = List.from(membersList);
        _birthdayCount = _countBirthdaysToday(membersList);
        _isLoading = false;
      });
    }, onError: (error) {
      debugPrint('❌ Erreur écoute membres: $error');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _loadData() async {
    await _loadMembers();
    await _loadNotificationCount();
  }

  Future<void> _loadNotificationCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final allDemandes = await FirebaseFirestore.instance
          .collection('DemandesAcces')
          .where('chefId', isEqualTo: user.uid)
          .where('statut', isEqualTo: 'en_attente')
          .get();
      int count = 0;
      for (var doc in allDemandes.docs) {
        if (doc.data()['isRead'] != true) count++;
      }
      if (mounted) {
        setState(() => _notificationCount = count);
        _updateAppBadge(count);
      }
    } catch (e) {
      debugPrint('⚠️ Erreur notifs: $e');
    }
  }

  Future<void> _loadMembers() async {
    try {
      setState(() => _isLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      _currentUserId = user.uid;
      final chefDoc = await FirebaseFirestore.instance
          .collection('Chef de Famille')
          .doc(_currentUserId)
          .get();
      if (!chefDoc.exists) {
        setState(() => _isLoading = false);
        return;
      }
      final chefData = chefDoc.data()!;
      _familyId = chefData['familyId'] ?? chefData['family_id'];
      if (_familyId == null || _familyId!.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      _chefFullName = chefData['fullName'] ?? chefData['full_name'] ?? 'Chef';
      _chefPhotoUrl = chefData['photoUrl'] ??
          chefData['photo_url'] ??
          'assets/images/profilpat.jpg';
      _chefBirthDate = chefData['birthDate'] ?? chefData['birth_date'] ?? '';

      List<Map<String, dynamic>> membersList = [];
      membersList.add({
        'id': chefDoc.id,
        'fullName': _chefFullName,
        'email': chefData['email'] ?? '',
        'phone': chefData['phone'] ?? '',
        'address': chefData['address'] ?? '',
        'role': 'Chef de famille',
        'relationship': 'Chef de famille',
        'relation': 'Chef de famille',
        'lien': 'Chef de famille',
        'isHead': true,
        'photoUrl': _chefPhotoUrl,
        'userId': _currentUserId,
        'familyId': _familyId,
        'birthDate': chefData['birthDate'] ?? chefData['birth_date'] ?? '',
        'birth_date': chefData['birthDate'] ?? chefData['birth_date'] ?? '',
        'gender': chefData['gender'] ?? '',
      });

      try {
        final membersQuery = await FirebaseFirestore.instance
            .collection('Membres Famille')
            .where('familyId', isEqualTo: _familyId)
            .get();
        for (var doc in membersQuery.docs) {
          final data = doc.data();
          final userId = data['userId'] ?? data['user_id'] ?? '';
          if (userId == _currentUserId) continue;
          final String roleValue = data['relationship'] ??
              data['role'] ??
              data['relation'] ??
              data['lien'] ??
              'Membre';
          membersList.add({
            'id': doc.id,
            'fullName': data['fullName'] ?? data['full_name'] ?? 'Membre',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? '',
            'address': data['address'] ?? '',
            'role': roleValue,
            'relationship': data['relationship'] ?? roleValue,
            'relation': data['relation'] ?? roleValue,
            'lien': data['lien'] ?? roleValue,
            'isHead': data['isHead'] ?? data['is_head'] ?? false,
            'photoUrl': data['photoUrl'] ??
                data['photo_url'] ??
                'assets/images/profilpat.jpg',
            'userId': userId,
            'familyId': data['familyId'] ?? data['family_id'] ?? _familyId,
            'birthDate': data['birthDate'] ?? data['birth_date'] ?? '',
            'birth_date': data['birthDate'] ?? data['birth_date'] ?? '',
            'gender': data['gender'] ?? '',
          });
        }
      } catch (e) {
        debugPrint('⚠️ Erreur requête membres: $e');
      }

      if (mounted) {
        setState(() {
          _members = membersList;
          _filteredMembers = List.from(membersList);
          _birthdayCount = _countBirthdaysToday(membersList);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ ERREUR: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Erreur de chargement: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _addMemberToFirestore(Map<String, dynamic> memberData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Vous devez être connecté');
        return;
      }
      String? familyId = _familyId;
      if (familyId == null || familyId.isEmpty) {
        final chefDoc = await FirebaseFirestore.instance
            .collection('Chef de Famille')
            .doc(user.uid)
            .get();
        if (chefDoc.exists) {
          familyId =
              chefDoc.data()!['familyId'] ?? chefDoc.data()!['family_id'];
          _familyId = familyId;
        }
      }
      if (familyId == null || familyId.isEmpty) {
        _showError('Aucun ID de famille trouvé');
        return;
      }
      final newMemberRef =
          FirebaseFirestore.instance.collection('Membres Famille').doc();
      String photoUrl = 'assets/images/profilpat.jpg';
      if (memberData['profileImage'] != null &&
          memberData['profileImage'].toString().isNotEmpty) {
        final img = memberData['profileImage'].toString();
        if (img.startsWith('data:image') ||
            img.startsWith('http') ||
            img.startsWith('assets/') ||
            img.length > 100) {
          photoUrl = img;
        }
      }
      final String roleValue =
          memberData['relation'] ?? memberData['relationship'] ?? 'Membre';
      final Map<String, dynamic> newMember = {
        'fullName': memberData['fullName'] ?? memberData['full_name'] ?? '',
        'full_name': memberData['fullName'] ?? memberData['full_name'] ?? '',
        'email': memberData['email'] ?? '',
        'phone': memberData['phone'] ?? '',
        'address': memberData['address'] ?? '',
        'relationship': roleValue,
        'role': roleValue,
        'relation': roleValue,
        'lien': roleValue,
        'birthDate': memberData['birthDate'] ?? memberData['birth_date'] ?? '',
        'birth_date': memberData['birthDate'] ?? memberData['birth_date'] ?? '',
        'gender': memberData['gender'] ?? 'Femme',
        'isHead': false,
        'is_head': false,
        'familyId': familyId,
        'family_id': familyId,
        'userId': newMemberRef.id,
        'user_id': newMemberRef.id,
        'photoUrl': photoUrl,
        'photo_url': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      };
      await newMemberRef.set(newMember);
      await FirebaseFirestore.instance
          .collection('Chef de Famille')
          .doc(user.uid)
          .update({
        'familyMembers': FieldValue.arrayUnion([newMemberRef.id]),
        'family_members': FieldValue.arrayUnion([newMemberRef.id]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Membre ajouté avec succès!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur ajout: $e');
      if (mounted) _showError('Erreur: $e');
    }
  }

  void _openAddMemberScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMembreScreen()),
    );
    if (result != null && result is Map<String, dynamic>) {
      await _addMemberToFirestore(result);
    }
  }

  void _logout() async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Déconnexion',
            style: TextStyle(color: navy, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Voulez-vous vraiment vous déconnecter ?',
            style: TextStyle(color: navy, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler', style: TextStyle(color: grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Déconnecter',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      if (!mounted) return;

      // ⭐ Arrêt présence avant signOut
      _presenceHeartbeat?.cancel();
      await _unpublishPresence();

      await FirebaseAuth.instance.signOut();

      try {
        FlutterAppBadger.removeBadge();
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const RoleSelectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
              ),
            );
            final slideAnim = Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
              ),
            );
            final scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
              ),
            );
            return FadeTransition(
              opacity: fadeAnim,
              child: SlideTransition(
                position: slideAnim,
                child: ScaleTransition(scale: scaleAnim, child: child),
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 700),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      debugPrint('❌ Erreur déconnexion: $e');
    }
  }

  void _annulerSuppression() {
    setState(() {
      _isSelectionMode = false;
      _selectedMemberId = null;
    });
  }

  void _confirmerSuppression() async {
    if (_selectedMemberId == null) return;
    final memberToDelete = _members.firstWhere(
      (m) => m['id'] == _selectedMemberId,
      orElse: () => {},
    );
    if (memberToDelete.isEmpty) {
      _annulerSuppression();
      return;
    }
    final String name = memberToDelete['fullName'] ?? 'Membre';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Supprimer le membre',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voulez-vous vraiment supprimer "$name" de votre famille ?',
              style: const TextStyle(color: navy, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cette action est irréversible.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) {
      _annulerSuppression();
      return;
    }
    try {
      final memberId = _selectedMemberId!;
      await FirebaseFirestore.instance
          .collection('Membres Famille')
          .doc(memberId)
          .delete();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('Chef de Famille')
            .doc(user.uid)
            .update({
          'familyMembers': FieldValue.arrayRemove([memberId]),
          'family_members': FieldValue.arrayRemove([memberId]),
        });
      }
      setState(() {
        _members.removeWhere((m) => m['id'] == memberId);
        _filteredMembers.removeWhere((m) => m['id'] == memberId);
        _isSelectionMode = false;
        _selectedMemberId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $name a été supprimé de la famille'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('❌ Erreur suppression: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
      );
      _annulerSuppression();
    }
  }

  Widget _buildMemberAvatar(String? photoUrl, {double radius = 36}) {
    return buildUniversalAvatar(photoUrl, radius: radius);
  }

  Widget _buildChefAvatar({double radius = 22}) {
    return _buildMemberAvatar(_chefPhotoUrl, radius: radius);
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9A9CC5), Color(0xFFE88BCF)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderPurple.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.14),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: navy)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 11, color: grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberItem(Map<String, dynamic> member) {
    final String name = member['fullName'] ?? member['full_name'] ?? 'Membre';
    final String role = member['role'] ??
        member['relationship'] ??
        member['relation'] ??
        member['lien'] ??
        'Membre';
    final String photoUrl = member['photoUrl'] ??
        member['photo_url'] ??
        'assets/images/profilpat.jpg';
    final bool isHead = member['isHead'] ?? member['is_head'] ?? false;
    final String userId =
        member['userId'] ?? member['user_id'] ?? member['id'] ?? '';
    final String memberDocId = member['id']?.toString() ?? '';
    final bool isBirthday = _isBirthdayToday(member);
    final bool isSelected = _isSelectionMode && _selectedMemberId == userId;

    final bool isAuthorized = isHead ||
        _authorizedMemberIds.contains(userId) ||
        _authorizedMemberIds.contains(memberDocId);
    final bool isOnline = _onlineMemberIds.contains(userId) ||
        _onlineMemberIds.contains(memberDocId);

    // ✅ Badge vert : chef auto-autorisé OU membre autorisé, en ligne
    final bool showOnline = isOnline && isAuthorized;

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _annulerSuppression();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DetailUserScreen(userId: userId, isChef: isHead),
          ),
        );
      },
      onLongPress: () {
        if (isHead) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('⚠️ Vous ne pouvez pas supprimer le chef de famille'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        setState(() {
          _isSelectionMode = true;
          _selectedMemberId = userId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('👆 Appuyez sur "Supprimer" pour supprimer $name'),
            backgroundColor: Colors.red.shade100,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: 115,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildMemberAvatar(photoUrl, radius: 38),
                if (showOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: onlineGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: onlineGreen.withOpacity(0.5),
                            blurRadius: 5,
                            spreadRadius: 1.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isBirthday)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: birthdayGold,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child:
                          const Icon(Icons.cake, color: Colors.white, size: 14),
                    ),
                  ),
                if (isSelected)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.red : navy,
              ),
            ),
            const SizedBox(height: 5),
            _buildRoleBadge(role),
          ],
        ),
      ),
    );
  }

  void _voirTousLesMembres() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllFamilyMembersScreen(
          members: _members,
          authorizedMemberIds: _authorizedMemberIds,
          onlineMemberIds: _onlineMemberIds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> displayMembers =
        _searchController.text.isNotEmpty ? _filteredMembers : _members;
    bool chefBirthday = _isChefBirthdayToday();

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      drawer: Drawer(
        width: 260,
        backgroundColor: Colors.white,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(top: 16),
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  children: [
                    _buildChefAvatar(radius: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _chefFullName ?? 'Chef',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: navy,
                                  ),
                                ),
                              ),
                              if (chefBirthday) ...[
                                const SizedBox(width: 5),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: birthdayGold,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.cake,
                                      color: Colors.white, size: 14),
                                ),
                              ],
                            ],
                          ),
                          const Text(
                            'Chef de famille',
                            style: TextStyle(color: grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              if (_birthdayCount > 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: birthdayGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: birthdayGold, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake, color: birthdayGold, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '🎂 $_birthdayCount membre${_birthdayCount > 1 ? 's' : ''} fête${_birthdayCount > 1 ? 'nt' : ''} son anniversaire aujourd\'hui !',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ListTile(
                leading: const Icon(Icons.notifications_none,
                    size: 22, color: lightPurple),
                title: const Text('Notification',
                    style: TextStyle(fontSize: 14, color: navy)),
                onTap: () async {
                  await _marquerToutesLues();
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Notifchef()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment_outlined,
                    size: 22, color: lightPurple),
                title: const Text('Demandes',
                    style: TextStyle(fontSize: 14, color: navy)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DemandeAccesScreen()),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.logout, size: 22, color: Colors.redAccent),
                title: const Text('Déconnecter',
                    style: TextStyle(fontSize: 14, color: Colors.redAccent)),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFEDEBFB), Color(0xFFFBE8F3)],
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Builder(
                                builder: (context) {
                                  return IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.menu_rounded,
                                        color: navy, size: 28),
                                    onPressed: () {
                                      Scaffold.of(context).openDrawer();
                                    },
                                  );
                                },
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Image.asset(
                                  'assets/images/ab.png',
                                  height: 38,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.centerLeft,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Text(
                                      'AB Fitness Family',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF1E2A78),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await _marquerToutesLues();
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const Notifchef()),
                                  );
                                },
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Image.asset(
                                      'assets/images/notif.png',
                                      width: 26,
                                      height: 26,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Icon(Icons.notifications,
                                            color: navy, size: 26);
                                      },
                                    ),
                                    if (_notificationCount > 0)
                                      Positioned(
                                        right: -6,
                                        top: -8,
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            minWidth: 20,
                                            minHeight: 20,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 2),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE53E6B),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: Colors.white, width: 2),
                                          ),
                                          child: Text(
                                            _notificationCount > 99
                                                ? '99+'
                                                : '$_notificationCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              height: 1.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              _buildChefAvatar(radius: 24),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border:
                                  Border.all(color: borderPurple, width: 1.2),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 16),
                                const Icon(Icons.search,
                                    color: lightPurple, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    textAlign: TextAlign.start,
                                    style: const TextStyle(
                                        fontSize: 14, color: navy),
                                    decoration: const InputDecoration(
                                      hintText: 'Cherche un membre de famille',
                                      hintStyle: TextStyle(
                                          color: Color(0xFFB0B0C3),
                                          fontSize: 14),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    onChanged: (value) {
                                      _filterMembers();
                                    },
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear,
                                        color: grey, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      _searchFocusNode.unfocus();
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                const SizedBox(width: 14),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildStatCard(
                                icon: Icons.groups_rounded,
                                value: '${_members.length}',
                                label: 'Membres',
                                color: purple,
                              ),
                              const SizedBox(width: 12),
                              // ⭐ Chef (auto-autorisé) + membres autorisés en ligne
                              _buildStatCard(
                                icon: Icons.circle,
                                value: '${_countOnlineAuthorizedMembers()}',
                                label: 'En ligne',
                                color: onlineGreen,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                icon: Icons.cake_rounded,
                                value: '$_birthdayCount',
                                label: 'Anniversaires',
                                color: birthdayGold,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ma Famille',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: navy,
                                    ),
                                  ),
                                  Text(
                                    '${displayMembers.length} membres ${_searchController.text.isNotEmpty ? "trouvés" : "de votre famille"}',
                                    style: const TextStyle(
                                        fontSize: 13, color: grey),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: _voirTousLesMembres,
                                child: const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Voir tous',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: borderPurple,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          _isLoading
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(40),
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF4439B8),
                                    ),
                                  ),
                                )
                              : displayMembers.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(40),
                                        child: Text(
                                          _searchController.text.isNotEmpty
                                              ? 'Aucun membre ne correspond à "${_searchController.text}"'
                                              : 'Aucun membre dans votre famille',
                                          style: const TextStyle(
                                              fontSize: 16, color: grey),
                                        ),
                                      ),
                                    )
                                  : SizedBox(
                                      height: 165,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: displayMembers.length,
                                        itemBuilder: (context, index) {
                                          return _AnimatedMemberItem(
                                            index: index,
                                            child: _buildMemberItem(
                                                displayMembers[index]),
                                          );
                                        },
                                      ),
                                    ),
                          const SizedBox(height: 18),
                          if (_isSelectionMode) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _annulerSuppression,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Annuler',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: navy,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _confirmerSuppression,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withOpacity(0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            Icons.delete_outline,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Supprimer',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _AnimatedAddMemberButton(
                  onTap: _openAddMemberScreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    NotificationService.stopListening();

    // ⭐ Arrêt présence + timers
    _presenceHeartbeat?.cancel();
    _presenceRefreshTimer?.cancel();
    _unpublishPresence();

    _searchController.removeListener(_filterMembers);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _chefSubscription?.cancel();
    _membersSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _presenceSubscription?.cancel();
    _menuAnimController.dispose();
    super.dispose();
  }
}

// ============================================================
// ANIMATED MEMBER ITEM
// ============================================================

class _AnimatedMemberItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedMemberItem({
    required this.index,
    required this.child,
  });

  @override
  State<_AnimatedMemberItem> createState() => _AnimatedMemberItemState();
}

class _AnimatedMemberItemState extends State<_AnimatedMemberItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.18),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ============================================================
// ⭐ ALL FAMILY MEMBERS SCREEN
// ============================================================

class AllFamilyMembersScreen extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final Set<String> authorizedMemberIds;
  final Set<String> onlineMemberIds;

  const AllFamilyMembersScreen({
    Key? key,
    required this.members,
    this.authorizedMemberIds = const {},
    this.onlineMemberIds = const {},
  }) : super(key: key);

  DateTime? _parseBirthDate(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return null;
    try {
      if (birthDateStr.contains('-') && birthDateStr.length == 10) {
        return DateTime.parse(birthDateStr);
      }
      if (birthDateStr.contains('/')) {
        final parts = birthDateStr.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          if (year > 1900 && year < 2100) {
            return DateTime(year, month, day);
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  bool _isBirthdayToday(Map<String, dynamic> member) {
    DateTime now = DateTime.now();
    String? birthDateStr = member['birthDate'] ?? member['birth_date'];
    if (birthDateStr != null && birthDateStr.isNotEmpty) {
      final DateTime? birthDate = _parseBirthDate(birthDateStr);
      if (birthDate != null) {
        return birthDate.month == now.month && birthDate.day == now.day;
      }
    }
    return false;
  }

  // ⭐ Chef auto-autorisé OU membre autorisé, en ligne
  bool _isOnline(Map<String, dynamic> member) {
    final String userId =
        member['userId'] ?? member['user_id'] ?? member['id'] ?? '';
    final String memberDocId = member['id']?.toString() ?? '';
    final bool isHead = member['isHead'] ?? member['is_head'] ?? false;

    final bool isAuthorized = isHead ||
        authorizedMemberIds.contains(userId) ||
        authorizedMemberIds.contains(memberDocId);
    final bool isOnline = onlineMemberIds.contains(userId) ||
        onlineMemberIds.contains(memberDocId);

    return isOnline && isAuthorized;
  }

  Widget _buildMemberAvatar(String? photoUrl, {double radius = 36}) {
    return buildUniversalAvatar(photoUrl, radius: radius);
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9A9CC5), Color(0xFFE88BCF)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEDEBFB), Color(0xFFFBE8F3)],
                ),
              ),
              child: Row(
                children: [
                  _ElegantBackButton(
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tous les membres',
                          style: TextStyle(
                            color: navy,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 26),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final String name =
                      member['fullName'] ?? member['full_name'] ?? 'Membre';
                  final String role = member['role'] ??
                      member['relationship'] ??
                      member['relation'] ??
                      member['lien'] ??
                      'Membre';
                  final String photoUrl = member['photoUrl'] ??
                      member['photo_url'] ??
                      'assets/images/profilpat.jpg';
                  final bool isHead =
                      member['isHead'] ?? member['is_head'] ?? false;
                  final String userId = member['userId'] ??
                      member['user_id'] ??
                      member['id'] ??
                      '';
                  final bool isBirthday = _isBirthdayToday(member);
                  final bool isOnline = _isOnline(member);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailUserScreen(
                            userId: userId,
                            isChef: isHead,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderPurple, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: lightPurple.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _buildMemberAvatar(photoUrl, radius: 34),
                              if (isOnline)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: onlineGreen,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: onlineGreen.withOpacity(0.5),
                                          blurRadius: 5,
                                          spreadRadius: 1.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (isBirthday)
                                Positioned(
                                  left: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: birthdayGold,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.cake,
                                      color: Colors.white,
                                      size: 13,
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
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: navy,
                                        ),
                                      ),
                                    ),
                                    if (isBirthday) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: birthdayGold,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          '🎂 Anniv.',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _buildRoleBadge(role),
                                const SizedBox(height: 8),
                                if ((member['email'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Text(
                                    member['email'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 12, color: grey),
                                  ),
                                if ((member['phone'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Text(
                                    member['phone'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 12, color: grey),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: navy, size: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
