// lib/VoirFamilleScreen.dart - VRAIS NOMS DEPUIS FIRESTORE
// ⭐ CORRIGÉ : Le timer lit dureeAccesMinutes depuis Firestore (5,10,15,20,25,30)
// ⭐ CORRIGÉ : Le timer démarre à la 1ère ouverture du visiteur
// ⭐ NOUVEAU : Mise à jour EN TEMPS RÉEL du lien de parenté (chef + membres)
// ⭐ NOUVEAU : Fermeture automatique de l'application quand le temps est écoulé
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ⭐ AJOUTÉ pour SystemNavigator.pop()
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'CvScreen.dart';
import 'Diplome.dart';
import 'Certaficat.dart';
import 'MesPhotosScreen.dart';
import 'MesVideosScreen.dart';
import 'MonProfilScreen.dart';
import 'DetailUserScreen.dart' show CategorieDocumentsScreen;

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF7B2FF2);
const Color purpleDark = Color(0xFF5A1FB8);
const Color grey = Color(0xFF9E9EAE);
const Color red = Color(0xFFE53E6B);
const Color orange = Color(0xFFFFB300);
const Color green = Color(0xFF2ECC71);
const Color greenBg = Color(0xFFE6F9EE);
const Color cardLight = Color(0xFFF3EEFB);
const Color cardBorder = Color(0xFFECE6F8);

const Color pillVioletBg = Color(0xFFF0EDFF);
const Color pillVioletText = purple;
const Color pillRoseBg = Color(0xFFFBE9EF);
const Color pillRoseText = Color(0xFFC2467D);
const Color pillGreyBg = Color(0xFFF0F0F5);
const Color pillGreyText = grey;

// ============================================================
// VOIR FAMILLE SCREEN
// ============================================================

class VoirFamilleScreen extends StatefulWidget {
  final String demandeId;
  final bool isVisitor;

  const VoirFamilleScreen({
    super.key,
    required this.demandeId,
    this.isVisitor = true,
  });

  @override
  State<VoirFamilleScreen> createState() => _VoirFamilleScreenState();
}

class _VoirFamilleScreenState extends State<VoirFamilleScreen> {
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _demande;
  List<Map<String, dynamic>> _membres = [];

  List<String> _hiddenCategories = [];
  Map<String, List<String>> _hiddenCategoriesParMembre = {};

  Map<String, bool> _permissions = {};
  Map<String, Map<String, bool>> _permissionsParMembre = {};

  Map<String, List<String>> _photosParMembre = {};
  Map<String, List<String>> _videosParMembre = {};
  Map<String, List<String>> _persoParMembre = {};

  final Map<String, String> _vraisNoms = {};

  bool _modeParMembre = false;

  String? _selectedMembreId;
  Map<String, bool> _permissionsAffichees = {};

  String _statut = 'en_attente';

  Duration _tempsRestant = Duration.zero;
  Duration _dureeTotale = const Duration(minutes: 5);
  Timer? _countdownTimer;
  DateTime? _dateExpiration;
  bool _estExpire = false;
  bool _dialogExpireDejaAffiche = false; // ⭐ Évite d'afficher plusieurs fois

  // ⭐ Streams pour mise à jour temps réel du lien de parenté
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _chefLienSub;
  final List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _membresLienSubs = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _chefLienSub?.cancel();
    for (var s in _membresLienSubs) {
      s.cancel();
    }
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // ⭐ MISE À JOUR TEMPS RÉEL DU LIEN DE PARENTÉ
  // ═══════════════════════════════════════════════════════

  void _ecouterLiensEnTempsReel({
    required String chefId,
    required List<String> membreIds,
  }) {
    _chefLienSub?.cancel();
    for (var s in _membresLienSubs) {
      s.cancel();
    }
    _membresLienSubs.clear();

    // ⭐ 1. Écouter le CHEF
    if (chefId.isNotEmpty) {
      _chefLienSub = FirebaseFirestore.instance
          .collection('Chef de Famille')
          .doc(chefId)
          .snapshots()
          .listen((snap) {
        if (!mounted || !snap.exists) return;
        final data = snap.data()!;
        final newLien = (data['relationship'] ??
                data['relation'] ??
                data['role'] ??
                'Chef de famille')
            .toString();
        _updateMembreLien(chefId, newLien);
      }, onError: (e) {
        debugPrint('⚠️ Erreur écoute chef lien: $e');
      });
    }

    // ⭐ 2. Écouter CHAQUE MEMBRE
    for (final mId in membreIds) {
      if (mId == chefId) continue;
      final sub = FirebaseFirestore.instance
          .collection('Membres Famille')
          .doc(mId)
          .snapshots()
          .listen((snap) {
        if (!mounted || !snap.exists) return;
        final data = snap.data()!;
        final newLien = (data['relationship'] ??
                data['relation'] ??
                data['lien'] ??
                data['role'] ??
                'Membre')
            .toString();
        _updateMembreLien(mId, newLien);
      }, onError: (e) {
        debugPrint('⚠️ Erreur écoute membre $mId: $e');
      });
      _membresLienSubs.add(sub);
    }

    debugPrint(
        '🔄 Écoute temps réel liens activée : chef + ${membreIds.length} membres');
  }

  void _updateMembreLien(String membreId, String newLien) {
    final idx = _membres.indexWhere((m) => m['id']?.toString() == membreId);
    if (idx == -1) return;
    if (_membres[idx]['lien'] == newLien) return;

    setState(() {
      _membres[idx] = {
        ..._membres[idx],
        'lien': newLien,
      };
    });
    debugPrint('✅ Lien mis à jour $membreId → "$newLien"');
  }

  // ═══════════════════════════════════════════════════════
  // CHARGEMENT
  // ═══════════════════════════════════════════════════════

  Future<void> _charger() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('DemandesAcces')
          .doc(widget.demandeId)
          .get();

      if (!doc.exists) {
        setState(() {
          _error = 'Demande introuvable';
          _isLoading = false;
        });
        return;
      }

      final data = doc.data()!;
      final statut = (data['statut'] ?? 'en_attente').toString().toLowerCase();

      if (widget.isVisitor && data['accesUtilise'] == true) {
        final expDate = data['dateExpiration'];
        if (expDate is Timestamp && expDate.toDate().isAfter(DateTime.now())) {
          // Le timer est encore valide, on laisse passer
        } else {
          setState(() {
            _error =
                '🔒 Vous avez déjà utilisé votre accès.\nEnvoyez une nouvelle demande pour voir à nouveau.';
            _isLoading = false;
          });
          return;
        }
      }

      final hiddenCats = data['hiddenDefaultCategories'] as List? ?? [];
      final List<String> hiddenCategories =
          hiddenCats.map((e) => e.toString()).toList();

      final permissions = _emptyPermissions();

      final perms = data['permissions'] as Map<String, dynamic>? ?? {};
      for (final key in permissions.keys) {
        if (perms[key] == true) permissions[key] = true;
      }
      if (perms['voirProfil'] == true || perms['profil'] == true) {
        permissions['voirProfil'] = true;
      }

      final autorisations =
          data['autorisationsParMembre'] as Map<String, dynamic>? ?? {};

      final Map<String, Map<String, bool>> permissionsParMembre = {};
      final Map<String, List<String>> hiddenCategoriesParMembre = {};
      final Map<String, List<String>> photosParMembre = {};
      final Map<String, List<String>> videosParMembre = {};
      final Map<String, List<String>> persoParMembre = {};

      if (autorisations.isNotEmpty) {
        for (final membreEntry in autorisations.entries) {
          final membreId = membreEntry.key;
          final membrePerms = membreEntry.value as Map<String, dynamic>? ?? {};

          final perms2 = _emptyPermissions();
          final List<String> hiddenCatsMembre = [];
          final List<String> photosList = [];
          final List<String> videosList = [];
          final List<String> persoList = [];

          for (final entry in membrePerms.entries) {
            final cle = entry.key.toString().toLowerCase();
            final isAllowed = entry.value == true;

            if (!isAllowed) {
              if (cle.startsWith('photo_')) {
                hiddenCatsMembre.add(cle.substring(6));
              } else if (cle.startsWith('video_')) {
                hiddenCatsMembre.add(cle.substring(6));
              }
              continue;
            }

            if (cle == 'profil' ||
                cle == 'voirprofil' ||
                cle == 'voir_profil') {
              perms2['voirProfil'] = true;
            } else if (cle.startsWith('std_cv_') || cle == 'cv') {
              perms2['voirCv'] = true;
            } else if (cle.startsWith('std_diplôme') ||
                cle.startsWith('std_diplome') ||
                cle == 'diplome' ||
                cle == 'diplomes') {
              perms2['voirDiplomes'] = true;
            } else if (cle.startsWith('std_certificat') ||
                cle == 'certificat' ||
                cle == 'certificats') {
              perms2['voirCertificats'] = true;
            } else if (cle == 'telechargement') {
              perms2['telechargement'] = true;
            } else if (cle.startsWith('photo_')) {
              perms2['voirPhotos'] = true;
              photosList.add(cle);
            } else if (cle.startsWith('video_')) {
              perms2['voirVideos'] = true;
              videosList.add(cle);
            } else if (cle.startsWith('perso_') || cle.startsWith('std_')) {
              perms2['voirDocuments'] = true;
              persoList.add(cle);
            }
          }

          permissionsParMembre[membreId] = perms2;
          hiddenCategoriesParMembre[membreId] = hiddenCatsMembre;
          photosParMembre[membreId] = photosList;
          videosParMembre[membreId] = videosList;
          persoParMembre[membreId] = persoList;
        }
      }

      final bool modeParMembre = permissionsParMembre.isNotEmpty;

      final chefId = data['chefId']?.toString() ?? '';
      final List<Map<String, dynamic>> membres = [];
      final membresIds = permissionsParMembre.keys.toList();

      bool aAuMoinsUnePermission(Map<String, bool>? p) =>
          p != null && p.values.any((v) => v == true);

      if (chefId.isNotEmpty) {
        try {
          final chefDoc = await FirebaseFirestore.instance
              .collection('Chef de Famille')
              .doc(chefId)
              .get();

          if (chefDoc.exists) {
            final chefData = chefDoc.data()!;

            final chefAutorise = !modeParMembre ||
                aAuMoinsUnePermission(permissionsParMembre[chefId]);

            if (chefAutorise) {
              membres.add({
                'id': chefId,
                'nom': chefData['fullName'] ?? 'Chef',
                'photo': chefData['photoUrl'] ?? '',
                'lien': chefData['relationship'] ??
                    chefData['relation'] ??
                    chefData['role'] ??
                    'Chef de famille',
              });
            }

            for (final mId in membresIds) {
              if (mId == chefId) continue;
              if (!aAuMoinsUnePermission(permissionsParMembre[mId])) continue;

              try {
                final mDoc = await FirebaseFirestore.instance
                    .collection('Membres Famille')
                    .doc(mId)
                    .get();

                if (mDoc.exists) {
                  final mData = mDoc.data()!;
                  membres.add({
                    'id': mDoc.id,
                    'nom': mData['fullName'] ?? mData['name'] ?? 'Membre',
                    'photo': mData['photoUrl'] ?? '',
                    'lien': mData['relationship'] ??
                        mData['relation'] ??
                        mData['lien'] ??
                        mData['role'] ??
                        'Membre',
                  });
                }
              } catch (_) {}
            }

            if (!modeParMembre && membres.length == 1) {
              final familyMembers = (chefData['familyMembers'] ??
                      chefData['family_members']) as List? ??
                  [];

              for (final mId in familyMembers) {
                try {
                  final mDoc = await FirebaseFirestore.instance
                      .collection('Membres Famille')
                      .doc(mId.toString())
                      .get();

                  if (mDoc.exists) {
                    final mData = mDoc.data()!;
                    membres.add({
                      'id': mDoc.id,
                      'nom': mData['fullName'] ?? mData['name'] ?? 'Membre',
                      'photo': mData['photoUrl'] ?? '',
                      'lien': mData['relationship'] ??
                          mData['relation'] ??
                          mData['lien'] ??
                          mData['role'] ??
                          'Membre',
                    });
                  }
                } catch (_) {}
              }
            }
          }
        } catch (_) {}
      }

      // ⭐ Charger les vrais noms depuis Firestore
      await _chargerVraisNoms(
          membres, photosParMembre, videosParMembre, persoParMembre);

      // ⭐ LIRE LA DURÉE EXACTE CHOISIE PAR LE CHEF
      final int dureeMinutes =
          (data['dureeAccesMinutes'] as num?)?.toInt() ?? 5;
      final Duration dureeTotale = Duration(minutes: dureeMinutes);

      debugPrint('📖 BDD → dureeAccesMinutes = $dureeMinutes min '
          '(${dureeTotale.inSeconds} sec)');

      DateTime? expiration;

      if (data['dateExpiration'] is Timestamp) {
        expiration = (data['dateExpiration'] as Timestamp).toDate();
        debugPrint('🔄 Reprise session → expire à $expiration');
      } else if (widget.isVisitor && statut == 'acceptee') {
        expiration = DateTime.now().add(dureeTotale);

        await FirebaseFirestore.instance
            .collection('DemandesAcces')
            .doc(widget.demandeId)
            .update({
          'dateExpiration': Timestamp.fromDate(expiration),
          'accesUtilise': true,
          'accesUtiliseAt': FieldValue.serverTimestamp(),
        });

        debugPrint('🟢 Timer DÉMARRÉ : $dureeMinutes min '
            '→ expire à $expiration');
      }

      final firstMembreId =
          membres.isNotEmpty ? membres.first['id']?.toString() : null;

      setState(() {
        _demande = data;
        _membres = membres;
        _hiddenCategories = hiddenCategories;
        _hiddenCategoriesParMembre = hiddenCategoriesParMembre;
        _permissions = permissions;
        _permissionsParMembre = permissionsParMembre;
        _photosParMembre = photosParMembre;
        _videosParMembre = videosParMembre;
        _persoParMembre = persoParMembre;
        _modeParMembre = modeParMembre;
        _selectedMembreId = firstMembreId;
        _dureeTotale = dureeTotale;

        if (modeParMembre && firstMembreId != null) {
          _permissionsAffichees =
              permissionsParMembre[firstMembreId] ?? _emptyPermissions();
        } else {
          _permissionsAffichees = permissions;
        }

        _statut = statut;
        _dateExpiration = expiration;
        _isLoading = false;
      });

      // ⭐ Activer l'écoute temps réel du lien de parenté
      _ecouterLiensEnTempsReel(
        chefId: chefId,
        membreIds: membres
            .map((m) => m['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList(),
      );

      if (statut == 'acceptee' && expiration != null) {
        _demarrerCountdown();
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  // ═══════════════════════════════════════════════════════
  // CHARGER LES VRAIS NOMS DES CATÉGORIES
  // ═══════════════════════════════════════════════════════

  Future<void> _chargerVraisNoms(
    List<Map<String, dynamic>> membres,
    Map<String, List<String>> photosParMembre,
    Map<String, List<String>> videosParMembre,
    Map<String, List<String>> persoParMembre,
  ) async {
    for (final m in membres) {
      final mId = m['id'].toString();
      final isChef = mId == _demande?['chefId']?.toString();
      final coll = isChef ? 'Chef de Famille' : 'Membres Famille';

      try {
        final mDoc =
            await FirebaseFirestore.instance.collection(coll).doc(mId).get();

        if (mDoc.exists) {
          final cats = mDoc.data()?['categories'] as List? ?? [];
          for (var cat in cats) {
            if (cat is! Map) continue;
            final nom = cat['nom']?.toString() ?? '';
            final source = cat['source']?.toString() ?? '';
            if (nom.isEmpty) continue;

            final key = nom.toLowerCase().replaceAll(' ', '_');

            if (source == 'photos_screen') {
              _vraisNoms['photo_$key'] = nom;
            } else if (source == 'videos_screen') {
              _vraisNoms['video_$key'] = nom;
            } else if (source == 'detail_screen') {
              _vraisNoms['perso_$key'] = nom;
            }
          }
        }

        try {
          final vSnap = await FirebaseFirestore.instance
              .collection('video')
              .where('memberId', isEqualTo: mId)
              .get();

          for (var doc in vSnap.docs) {
            final cat = doc.data()['category']?.toString() ?? '';
            if (cat.isNotEmpty) {
              final key = cat.toLowerCase().replaceAll(' ', '_');
              _vraisNoms['video_$key'] = cat;
            }
          }
        } catch (_) {}

        try {
          final pSnap = await FirebaseFirestore.instance
              .collection('Photos')
              .where('memberId', isEqualTo: mId)
              .get();

          for (var doc in pSnap.docs) {
            final cat = doc.data()['category']?.toString() ?? '';
            if (cat.isNotEmpty) {
              final key = cat.toLowerCase().replaceAll(' ', '_');
              _vraisNoms['photo_$key'] = cat;
            }
          }
        } catch (_) {}

        try {
          final dSnap = await FirebaseFirestore.instance
              .collection('UserDocuments')
              .where('memberId', isEqualTo: mId)
              .get();

          final Set<String> catIds = {};
          for (var doc in dSnap.docs) {
            final catId = doc.data()['categoryId']?.toString() ?? '';
            if (catId.isNotEmpty) catIds.add(catId);
          }

          for (final catId in catIds) {
            final cats = mDoc.data()?['categories'] as List? ?? [];
            for (var cat in cats) {
              if (cat is Map && cat['id']?.toString() == catId) {
                final nom = cat['nom']?.toString() ?? '';
                if (nom.isNotEmpty) {
                  final key = nom.toLowerCase().replaceAll(' ', '_');
                  _vraisNoms['perso_$key'] = nom;
                }
              }
            }
          }
        } catch (_) {}
      } catch (e) {
        debugPrint('⚠️ Erreur chargement noms pour $mId: $e');
      }
    }
  }

  void _demarrerCountdown() {
    _countdownTimer?.cancel();
    _updateTemps();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateTemps();
    });
  }

  void _updateTemps() {
    if (_dateExpiration == null) return;

    final diff = _dateExpiration!.difference(DateTime.now());

    if (diff.isNegative || diff.inSeconds <= 0) {
      _countdownTimer?.cancel();

      if (_estExpire) return; // ⭐ Évite les appels multiples

      setState(() {
        _tempsRestant = Duration.zero;
        _estExpire = true;
      });

      // ⭐ Afficher la boîte de dialogue UNE SEULE FOIS
      if (!_dialogExpireDejaAffiche) {
        _dialogExpireDejaAffiche = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          _showExpiredDialog();
        });
      }
      return;
    }

    setState(() {
      _tempsRestant = diff;
    });
  }

  // ═══════════════════════════════════════════════════════
  // ⭐ DIALOG TEMPS ÉCOULÉ → FERME L'APPLICATION
  // ═══════════════════════════════════════════════════════

  void _showExpiredDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false, // ⭐ Empêche le retour arrière
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.lock_clock, color: red, size: 26),
              SizedBox(width: 10),
              Text('Temps écoulé',
                  style: TextStyle(
                      color: navy, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            '⏰ Votre temps d\'accès est terminé.\n\n'
            'L\'application va se fermer.\n'
            'Pour voir à nouveau ces documents, envoyez une nouvelle demande au chef de famille.',
            style: TextStyle(color: grey, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Ferme la boîte de dialogue

                // ⭐ CORRECTION : Fermer complètement l'application
                SystemNavigator.pop();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [purple, orange]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Fermer',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════

  Widget _asset(String name,
      {double size = 20, Color? color, IconData? fallback}) {
    return Image.asset(
      'assets/images/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        return Icon(fallback ?? Icons.arrow_back,
            size: size, color: color ?? navy);
      },
    );
  }

  Map<String, bool> _emptyPermissions() => {
        'voirProfil': false,
        'voirCv': false,
        'voirDiplomes': false,
        'voirCertificats': false,
        'voirDocuments': false,
        'voirMembres': false,
        'voirPhotos': false,
        'voirVideos': false,
        'telechargement': false,
      };

  void _selectMembre(String membreId) {
    if (membreId == _selectedMembreId) return;
    setState(() {
      _selectedMembreId = membreId;

      if (_modeParMembre) {
        _permissionsAffichees =
            _permissionsParMembre[membreId] ?? _emptyPermissions();
      } else {
        _permissionsAffichees = _permissions;
      }
    });
  }

  Uint8List? _decodeB64(String? p) {
    if (p == null || p.isEmpty) return null;
    if (p.startsWith('http') || p.startsWith('assets/')) return null;
    try {
      String b = p.contains(',') ? p.split(',').last : p;
      b = b.replaceAll(RegExp(r'\s'), '');
      final m = b.length % 4;
      if (m != 0) b = b.padRight(b.length + (4 - m), '=');
      return base64Decode(b);
    } catch (_) {
      return null;
    }
  }

  Widget _avatar(String photo, {double size = 50}) {
    final bytes = _decodeB64(photo);
    Widget child;

    if (bytes != null && bytes.isNotEmpty) {
      child = Image.memory(bytes, fit: BoxFit.cover, width: size, height: size);
    } else if (photo.startsWith('http')) {
      child = Image.network(
        photo,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => _fallback(size),
      );
    } else {
      child = _fallback(size);
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF0EDFF),
      ),
      child: ClipOval(child: child),
    );
  }

  Widget _fallback(double size) => Container(
        color: const Color(0xFFF0EDFF),
        child: Icon(Icons.person, color: purple, size: size * 0.5),
      );

  List<Color> _pillColors(String lien) {
    final l = lien.toLowerCase();
    if (l.contains('père') || l.contains('pere') || l.contains('chef')) {
      return [pillVioletBg, pillVioletText];
    }
    if (l.contains('frère') ||
        l.contains('frere') ||
        l.contains('sœur') ||
        l.contains('soeur')) {
      return [pillRoseBg, pillRoseText];
    }
    return [pillGreyBg, pillGreyText];
  }

  String _getRealName(String cle, String fallbackRawName) {
    if (_vraisNoms.containsKey(cle)) {
      return _vraisNoms[cle]!;
    }

    return fallbackRawName
        .split('_')
        .where((s) => s.isNotEmpty)
        .map((s) => s.length > 1
            ? '${s[0].toUpperCase()}${s.substring(1)}'
            : s.toUpperCase())
        .join(' ');
  }

  Map<String, dynamic> _docVisuals(String key) {
    if (key.startsWith('photo_')) {
      return {
        'icon': Icons.photo_outlined,
        'subtitle': 'Galerie de photos',
      };
    }
    if (key.startsWith('video_')) {
      return {
        'icon': Icons.videocam_outlined,
        'subtitle': 'Galerie de vidéos',
      };
    }
    if (key.startsWith('perso_') || key.startsWith('std_')) {
      return {
        'icon': Icons.folder_outlined,
        'subtitle': 'Documents personnalisés',
      };
    }

    switch (key) {
      case 'voirProfil':
        return {
          'icon': Icons.person_outline,
          'subtitle': 'Informations personnelles',
        };
      case 'voirCv':
        return {
          'icon': Icons.description_outlined,
          'subtitle': 'Curriculum vitae',
        };
      case 'voirDiplomes':
        return {
          'icon': Icons.school_outlined,
          'subtitle': 'Diplômes obtenus',
        };
      case 'voirCertificats':
        return {
          'icon': Icons.workspace_premium_outlined,
          'subtitle': 'Certificats et attestations',
        };
      default:
        return {
          'icon': Icons.insert_drive_file_outlined,
          'subtitle': 'Documents',
        };
    }
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FC),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: purple))
            : _error != null
                ? _buildErreur()
                : _buildContenu(),
      ),
    );
  }

  Widget _buildErreur() => Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.lock_outline, size: 45, color: red),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: const Text('Retour',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  Widget _buildContenu() {
    if (_statut != 'acceptee') return _buildMessageStatut();

    if (_membres.isEmpty) {
      return Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildEmptyState('cette demande'),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildHeader(),
        _buildCountdownCard(),
        const SizedBox(height: 16),
        _buildMembresHorizontaux(),
        const SizedBox(height: 22),
        _buildDocumentsHeader(),
        const SizedBox(height: 12),
        ..._buildPermissionsList(),
      ],
    );
  }

  Widget _buildCountdownCard() {
    if (_dateExpiration == null) return const SizedBox.shrink();

    final isWarning = _tempsRestant.inMinutes < 2;
    final totalSeconds =
        _dureeTotale.inSeconds == 0 ? 1 : _dureeTotale.inSeconds;
    final progress = (_tempsRestant.inSeconds / totalSeconds).clamp(0.0, 1.0);

    final hh = _tempsRestant.inHours.toString().padLeft(2, '0');
    final mm = (_tempsRestant.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (_tempsRestant.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isWarning ? [red, const Color(0xFFB8265A)] : [purple, purpleDark],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (isWarning ? red : purple).withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isWarning
                      ? Icons.warning_amber_rounded
                      : Icons.timer_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isWarning ? 'TEMPS PRESQUE ÉCOULÉ' : 'ACCES EXPIRE DANS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Session sécurisée temporaire',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _timeBox(hh, 'HEURES'),
              _timeSep(),
              _timeBox(mm, 'MIN'),
              _timeSep(),
              _timeBox(ss, 'SEC'),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeSep() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          ':',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Row(
        children: [
          _ElegantBackButton(
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Text(
            'Documents Autorisés',
            style: TextStyle(
              color: navy,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembresHorizontaux() {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
        itemCount: _membres.length,
        itemBuilder: (context, i) {
          final m = _membres[i];
          final mId = m['id']?.toString() ?? '';
          final isSelected = mId == _selectedMembreId;
          final nom = m['nom']?.toString() ?? '';
          final lien = m['lien']?.toString() ?? 'Membre';
          final pillColors = _pillColors(lien);

          return Padding(
            padding: EdgeInsets.only(
              right: i < _membres.length - 1 ? 16 : 0,
            ),
            child: GestureDetector(
              onTap: () => _selectMembre(mId),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? purple : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: purple.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: _avatar(m['photo']?.toString() ?? '', size: 60),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 90,
                    child: Text(
                      nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? purple : navy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          pillColors[0],
                          pillColors[1].withOpacity(0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: pillColors[1].withOpacity(0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      lien,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: pillColors[1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentsHeader() {
    final count = _authorizedDocs().length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'DOCUMENTS AUTORISES',
            style: TextStyle(
              color: grey,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: pillVioletBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count accès',
              style: const TextStyle(
                color: purple,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_DocDef> _authorizedDocs() {
    final chefId = _demande?['chefId']?.toString() ?? '';
    final membreId = _modeParMembre ? (_selectedMembreId ?? chefId) : chefId;

    final bool canDownload = _permissionsAffichees['telechargement'] == true;

    final List<String> hiddenCatsMembre =
        _hiddenCategoriesParMembre[membreId] ?? [];
    final Set<String> allHiddenCategories = {
      ..._hiddenCategories,
      ...hiddenCatsMembre,
    };

    final docDefs = <_DocDef>[];

    // 1. PROFIL
    if (_permissionsAffichees['voirProfil'] == true) {
      docDefs.add(_DocDef(
        key: 'voirProfil',
        label: 'Profil',
        canDownload: false,
        onTap: () {
          final isChef = membreId == chefId;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MonProfilScreen(
                userId: membreId,
                isChef: isChef,
                isVisitor: true,
              ),
            ),
          );
        },
      ));
    }

    // 2. CV
    if (_permissionsAffichees['voirCv'] == true) {
      docDefs.add(_DocDef(
        key: 'voirCv',
        label: 'CV',
        canDownload: canDownload,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CvScreen(
                ownerName: _nomMembre(membreId),
                memberId: membreId,
                isVisitor: true,
                canDownload: canDownload,
              ),
            ),
          );
        },
      ));
    }

    // 3. CERTIFICATS
    if (_permissionsAffichees['voirCertificats'] == true) {
      docDefs.add(_DocDef(
        key: 'voirCertificats',
        label: 'Certificats',
        canDownload: canDownload,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Certaficat(
                ownerName: _nomMembre(membreId),
                memberId: membreId,
                isVisitor: true,
                canDownload: canDownload,
              ),
            ),
          );
        },
      ));
    }

    // 4. DIPLÔMES
    if (_permissionsAffichees['voirDiplomes'] == true) {
      docDefs.add(_DocDef(
        key: 'voirDiplomes',
        label: 'Diplomes',
        canDownload: canDownload,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DiplomeScreen(
                ownerName: _nomMembre(membreId),
                memberId: membreId,
                isVisitor: true,
                canDownload: canDownload,
              ),
            ),
          );
        },
      ));
    }

    // 5. PHOTOS PERSONNALISÉES
    final List<String> photoKeys = _photosParMembre[membreId] ?? [];
    for (final cle in photoKeys) {
      final rawName = cle.replaceAll('photo_', '');
      final label = _getRealName(cle, rawName);

      docDefs.add(_DocDef(
        key: cle,
        label: label,
        canDownload: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MesPhotosScreen(
                memberId: membreId,
                isVisitor: true,
                canDownload: false,
                hiddenCategories: allHiddenCategories.toList(),
              ),
            ),
          );
        },
      ));
    }

    // 6. VIDÉOS PERSONNALISÉES
    final List<String> videoKeys = _videosParMembre[membreId] ?? [];
    for (final cle in videoKeys) {
      final rawName = cle.replaceAll('video_', '');
      final label = _getRealName(cle, rawName);

      docDefs.add(_DocDef(
        key: cle,
        label: label,
        canDownload: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MesVideosScreen(
                memberId: membreId,
                isVisitor: true,
                canDownload: false,
                hiddenCategories: allHiddenCategories.toList(),
              ),
            ),
          );
        },
      ));
    }

    // 7. DOCUMENTS PERSONNALISÉS
    final List<String> persoKeys = _persoParMembre[membreId] ?? [];
    for (final cle in persoKeys) {
      if (cle.startsWith('std_cv_') ||
          cle.startsWith('std_diplome_') ||
          cle.startsWith('std_diplôme_') ||
          cle.startsWith('std_certificat_')) {
        continue;
      }

      final String rawName =
          cle.startsWith('perso_') ? cle.replaceAll('perso_', '') : cle;
      final label = _getRealName(cle, rawName);

      docDefs.add(_DocDef(
        key: cle,
        label: label.isEmpty ? 'Document' : label,
        canDownload: canDownload,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategorieDocumentsScreen(
                categorieNom: label.isEmpty ? 'Document' : label,
                categorieId: rawName,
                documents: const [],
                memberId: membreId,
                canDownload: canDownload,
                isVisitor: true,
              ),
            ),
          );
        },
      ));
    }

    return docDefs;
  }

  String _nomMembre(String membreId) {
    return _membres
            .firstWhere((m) => m['id']?.toString() == membreId,
                orElse: () => {})['nom']
            ?.toString() ??
        'la famille';
  }

  List<Widget> _buildPermissionsList() {
    final chefId = _demande?['chefId']?.toString() ?? '';
    final membreId = _modeParMembre ? (_selectedMembreId ?? chefId) : chefId;
    final nomMembre = _nomMembre(membreId);

    final autorises = _authorizedDocs();

    if (autorises.isEmpty) {
      return [_buildEmptyState(nomMembre)];
    }

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: Column(
          children: autorises
              .map((d) => _buildCard(
                    label: d.label,
                    icon: _docVisuals(d.key)['icon'] as IconData,
                    subtitle: _docVisuals(d.key)['subtitle'] as String,
                    onTap: d.onTap,
                    canDownload: d.canDownload,
                  ))
              .toList(),
        ),
      ),
    ];
  }

  Widget _buildCard({
    required String label,
    required IconData icon,
    required String subtitle,
    required VoidCallback onTap,
    bool canDownload = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: cardLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: purple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: greenBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle, color: green, size: 12),
                SizedBox(width: 4),
                Text(
                  'AUTORISE',
                  style: TextStyle(
                    color: green,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (canDownload) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: purple.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Image.asset(
                  'assets/images/telechargement.png',
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.download_rounded,
                    color: purple,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [purple, purpleDark]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String nom) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Color(0xFFF0EDFF),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.folder_off_outlined, color: purple, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            'Aucun document autorisé pour $nom',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: navy, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageStatut() {
    final isRefusee = _statut == 'refusee';
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: (isRefusee ? red : orange).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRefusee ? Icons.block : Icons.access_time_rounded,
                      size: 50,
                      color: isRefusee ? red : orange,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isRefusee ? 'Demande refusée' : 'En attente de réponse',
                    style: TextStyle(
                      color: isRefusee ? red : orange,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isRefusee
                        ? 'Le chef de famille a refusé votre demande.'
                        : 'Le chef n\'a pas encore répondu.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// BOUTON RETOUR ÉLÉGANT
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
              'assets/images/xx.png',
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

class _DocDef {
  final String key;
  final String label;
  final VoidCallback onTap;
  final bool canDownload;

  _DocDef({
    required this.key,
    required this.label,
    required this.onTap,
    this.canDownload = false,
  });
}
