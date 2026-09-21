// lib/MembreDetailScreen.dart - AVEC PRÉSENCE + AUTORISATION "telechargement"
// ⭐ NOUVEAU : Mise à jour EN TEMPS RÉEL du lien de parenté depuis Firestore
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF6046F4);
const Color grey = Color(0xFF9E9EAE);
const Color lightPurple = Color(0xFF9C27B0);
const Color borderPurple = Color(0xFF890CC2);
const Color surfaceLight = Color(0xFFF8F7FC);
const Color cardShadow = Color(0x0A000000);

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
// MODÈLES
// ============================================================

class DocItem {
  final String cle;
  final String nom;
  final String iconPath;
  final Color color;
  final Color iconBg;
  final String? sousTitre;
  final String? docId;

  DocItem({
    required this.cle,
    required this.nom,
    required this.iconPath,
    required this.color,
    required this.iconBg,
    this.sousTitre,
    this.docId,
  });
}

class _SectionModel {
  final String titre;
  final String iconPath;
  final Color color;
  final Color iconBg;
  final List<DocItem> items;

  _SectionModel({
    required this.titre,
    required this.iconPath,
    required this.color,
    required this.iconBg,
    required this.items,
  });
}

class DocTypeInfo {
  final String iconPath;
  final Color color;
  final Color iconBg;
  final String nomAffiche;

  const DocTypeInfo({
    required this.iconPath,
    required this.color,
    required this.iconBg,
    required this.nomAffiche,
  });
}

final Map<String, DocTypeInfo> kDocTypes = {
  'cv': const DocTypeInfo(
    iconPath: 'assets/icons/ic_cv.png',
    color: borderPurple,
    iconBg: Color(0xFFF3EEFF),
    nomAffiche: 'CV',
  ),
  'diplome': const DocTypeInfo(
    iconPath: 'assets/icons/ic_diploma.png',
    color: borderPurple,
    iconBg: Color(0xFFF3EEFF),
    nomAffiche: 'Diplômes',
  ),
  'certificat': const DocTypeInfo(
    iconPath: 'assets/icons/ic_certificat.png',
    color: borderPurple,
    iconBg: Color(0xFFF3EEFF),
    nomAffiche: 'Certificats',
  ),
};

DocTypeInfo getDocTypeInfo(String type) {
  final key = type.toLowerCase().trim();
  if (kDocTypes.containsKey(key)) return kDocTypes[key]!;
  for (final entry in kDocTypes.entries) {
    if (key.contains(entry.key) || entry.key.contains(key)) {
      return entry.value;
    }
  }
  final nomPropre =
      type.isNotEmpty ? type[0].toUpperCase() + type.substring(1) : 'Document';
  return DocTypeInfo(
    iconPath: 'assets/icons/ic_document.png',
    color: borderPurple,
    iconBg: const Color(0xFFF3EEFF),
    nomAffiche: nomPropre,
  );
}

// ============================================================
// MEMBRE DETAIL SCREEN
// ============================================================

class MembreDetailScreen extends StatefulWidget {
  final String membreId;
  final String membreNom;
  final String membrePhoto;
  final String lienParente;
  final Map<String, bool> initialAut;

  const MembreDetailScreen({
    super.key,
    required this.membreId,
    required this.membreNom,
    required this.membrePhoto,
    required this.lienParente,
    this.initialAut = const {},
  });

  @override
  State<MembreDetailScreen> createState() => _MembreDetailScreenState();
}

class _MembreDetailScreenState extends State<MembreDetailScreen>
    with TickerProviderStateMixin {
  final Map<String, bool> _aut = {};

  List<DocItem> _tousDocuments = [];
  List<DocItem> _photosPerso = [];
  List<DocItem> _videosPerso = [];

  bool _isLoading = true;
  String? _errorMessage;

  List<String> _tousLesIdsPossibles = [];
  final Map<String, String> _mapCategoryIdVersNom = {};

  late AnimationController _fadeController;

  // ⭐ PRÉSENCE
  Timer? _presenceTimer;
  bool _isVisitor = false;

  // ⭐ NOUVEAU : lien de parenté en temps réel
  late String _lienParenteActuel;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _lienSub;

  @override
  void initState() {
    super.initState();
    _aut.addAll(widget.initialAut);
    _lienParenteActuel = widget.lienParente; // ⭐ valeur initiale

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _verifierEtMarquerPresence();
    _ecouterLienParenteTempsReel(); // ⭐ NOUVEAU
    _charger();
  }

  // ═══════════════════════════════════════════════════════
  // ⭐ NOUVEAU : ÉCOUTE LE LIEN DE PARENTÉ EN TEMPS RÉEL
  // ═══════════════════════════════════════════════════════

  Future<void> _ecouterLienParenteTempsReel() async {
    try {
      final id = widget.membreId;

      // ⭐ Essayer d'abord "Membres Famille"
      final membreDoc = await FirebaseFirestore.instance
          .collection('Membres Famille')
          .doc(id)
          .get();

      String collection = 'Membres Famille';
      if (!membreDoc.exists) {
        // ⭐ Sinon "Chef de Famille"
        final chefDoc = await FirebaseFirestore.instance
            .collection('Chef de Famille')
            .doc(id)
            .get();
        if (!chefDoc.exists) {
          debugPrint('⚠️ Membre introuvable dans les 2 collections');
          return;
        }
        collection = 'Chef de Famille';
      }

      debugPrint('🔄 Écoute lien de parenté activée sur $collection/$id');

      // ⭐ Écouter en temps réel
      _lienSub = FirebaseFirestore.instance
          .collection(collection)
          .doc(id)
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

        if (newLien != _lienParenteActuel) {
          setState(() => _lienParenteActuel = newLien);
          debugPrint('✅ Lien de parenté mis à jour : "$newLien"');
        }
      }, onError: (e) {
        debugPrint('⚠️ Erreur écoute lien: $e');
      });
    } catch (e) {
      debugPrint('❌ Erreur init lien parenté: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // PRÉSENCE EN LIGNE
  // ═══════════════════════════════════════════════════════

  Future<void> _verifierEtMarquerPresence() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final visiteurDoc = await FirebaseFirestore.instance
          .collection('Visiteurs')
          .doc(user.uid)
          .get();

      if (!visiteurDoc.exists) {
        debugPrint('ℹ️ Pas un visiteur → pas de présence');
        return;
      }

      _isVisitor = true;
      await _marquerEnLigne();

      _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _marquerEnLigne();
      });
    } catch (e) {
      debugPrint('❌ Erreur vérif présence: $e');
    }
  }

  Future<void> _marquerEnLigne() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !_isVisitor) return;

      String visiteurNom = 'Visiteur';
      try {
        final vDoc = await FirebaseFirestore.instance
            .collection('Visiteurs')
            .doc(user.uid)
            .get();
        if (vDoc.exists) {
          visiteurNom = vDoc.data()?['nomComplet']?.toString() ??
              vDoc.data()?['prenom']?.toString() ??
              'Visiteur';
        }
      } catch (_) {}

      await FirebaseFirestore.instance
          .collection('Presence')
          .doc('${widget.membreId}_${user.uid}')
          .set({
        'memberId': widget.membreId,
        'visiteurId': user.uid,
        'visiteurNom': visiteurNom,
        'isActive': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('🟢 Présence ON pour ${widget.membreNom}');
    } catch (e) {
      debugPrint('❌ Erreur présence: $e');
    }
  }

  Future<void> _marquerHorsLigne() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !_isVisitor) return;

      await FirebaseFirestore.instance
          .collection('Presence')
          .doc('${widget.membreId}_${user.uid}')
          .set({
        'isActive': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('⚪ Présence OFF pour ${widget.membreNom}');
    } catch (e) {
      debugPrint('❌ Erreur: $e');
    }
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _lienSub?.cancel(); // ⭐ Annuler le stream du lien
    _marquerHorsLigne();
    _fadeController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // UTILITAIRES
  // ═══════════════════════════════════════════════════════

  bool _contientUnFichier(Map<String, dynamic> data) {
    const champsFichier = [
      'url',
      'fileUrl',
      'downloadUrl',
      'path',
      'filePath',
      'bytes',
      'base64',
      'imageUrl',
      'videoUrl',
      'photoUrl',
      'pdfUrl',
      'storagePath',
      'file',
      'fichier',
    ];
    for (final champ in champsFichier) {
      final valeur = data[champ];
      if (valeur != null) {
        if (valeur is String && valeur.trim().isNotEmpty) return true;
        if (valeur is List && valeur.isNotEmpty) return true;
        if (valeur is Map && valeur.isNotEmpty) return true;
      }
    }
    return false;
  }

  String _nomReelDuDoc(Map<String, dynamic> data) {
    final champsCatId = [
      'categoryId',
      'category_id',
      'catId',
      'cat_id',
      'folderId',
      'folder_id',
      'categorieId',
      'categorie_id',
      'category',
      'categorie',
      'type',
    ];

    for (final champ in champsCatId) {
      final val = data[champ]?.toString().trim() ?? '';
      if (val.isEmpty) continue;
      if (_mapCategoryIdVersNom.containsKey(val)) {
        return _mapCategoryIdVersNom[val]!;
      }
    }

    for (final champ in champsCatId) {
      final val = data[champ]?.toString().trim() ?? '';
      if (val.isEmpty) continue;
      if (!RegExp(r'^\d+$').hasMatch(val) && val.length > 1) {
        if (val.toLowerCase() != 'document' &&
            val.toLowerCase() != 'file' &&
            val.toLowerCase() != 'pdf') {
          return val;
        }
      }
    }

    final champsNom = ['name', 'fileName', 'file_name', 'title', 'nom'];
    for (final champ in champsNom) {
      final val = data[champ]?.toString().trim() ?? '';
      if (val.isEmpty) continue;
      String nomPropre = val;
      if (nomPropre.contains('.')) nomPropre = nomPropre.split('.').first;
      nomPropre = nomPropre.replaceAll('_', ' ').trim();
      if (nomPropre.isNotEmpty && !RegExp(r'^\d+$').hasMatch(nomPropre)) {
        return nomPropre;
      }
    }

    return 'Document';
  }

  Future<void> _collecterTousLesIds(StringBuffer buffer) async {
    final ids = <String>{widget.membreId};

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Membres Famille')
          .doc(widget.membreId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        for (final champ in ['userId', 'user_id', 'uid', 'memberId', 'id']) {
          final val = data[champ]?.toString();
          if (val != null && val.isNotEmpty && val != 'null') {
            ids.add(val);
          }
        }
      }
    } catch (_) {}

    _tousLesIdsPossibles = ids.where((e) => e.isNotEmpty).toList();
  }

  Future<void> _chargerCategoriesPersonnalisees(StringBuffer buffer) async {
    for (final id in _tousLesIdsPossibles) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('Membres Famille')
            .doc(id)
            .get();
        if (!doc.exists) continue;

        final data = doc.data()!;
        final cats = data['categories'];
        if (cats is! List) continue;

        for (final cat in cats) {
          if (cat is! Map) continue;
          final catId = (cat['id'] ?? cat['_id'] ?? '').toString().trim();
          final nom = (cat['nom'] ?? cat['name'] ?? '').toString().trim();

          if (catId.isNotEmpty && nom.isNotEmpty) {
            _mapCategoryIdVersNom[catId] = nom;
          }
        }
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> _chercherDocs(
    String collection,
    StringBuffer buffer,
  ) async {
    final tousDocs = <String, Map<String, dynamic>>{};
    final champsPossibles = [
      'memberId',
      'userId',
      'uid',
      'ownerId',
      'chefId',
      'createdBy',
    ];
    for (final champ in champsPossibles) {
      for (final id in _tousLesIdsPossibles) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection(collection)
              .where(champ, isEqualTo: id)
              .get();
          for (var doc in snap.docs) {
            final data = doc.data();
            if (data.isNotEmpty && _contientUnFichier(data)) {
              data['_docId'] = doc.id;
              tousDocs[doc.id] = data;
            }
          }
        } catch (_) {}
      }
    }
    return tousDocs.values.toList();
  }

  // ═══════════════════════════════════════════════════════
  // CHARGEMENT PRINCIPAL
  // ═══════════════════════════════════════════════════════

  Future<void> _charger() async {
    try {
      _aut.putIfAbsent('profil', () => true);
      _aut.putIfAbsent('telechargement', () => true);

      final buffer = StringBuffer();
      await _collecterTousLesIds(buffer);
      await _chargerCategoriesPersonnalisees(buffer);

      final tousDocuments = <DocItem>[];

      // 1. Collections standards
      const Map<String, String> collectionsStandards = {
        'CvFiles': 'CV',
        'DiplomeFiles': 'Diplômes',
        'CertificatFiles': 'Certificats',
      };

      for (final entry in collectionsStandards.entries) {
        final docs = await _chercherDocs(entry.key, buffer);

        final Map<String, int> compteurs = {};
        for (var doc in docs) {
          final nom = _nomReelDuDoc(doc);
          compteurs[nom] = (compteurs[nom] ?? 0) + 1;
        }

        compteurs.forEach((nom, count) {
          final cle =
              'std_${entry.value}_${nom.toLowerCase().replaceAll(' ', '_')}';
          final info = getDocTypeInfo(entry.value);
          tousDocuments.add(DocItem(
            cle: cle,
            nom: nom,
            iconPath: info.iconPath,
            color: info.color,
            iconBg: info.iconBg,
            sousTitre: count > 1 ? '$count fichiers' : '1 fichier',
          ));
          _aut.putIfAbsent(cle, () => true);
        });
      }

      // 2. UserDocuments
      final Map<String, int> compteursPerso = {};
      for (final champ in [
        'memberId',
        'userId',
        'uid',
        'ownerId',
        'chefId',
        'createdBy'
      ]) {
        for (final id in _tousLesIdsPossibles) {
          try {
            final snap = await FirebaseFirestore.instance
                .collection('UserDocuments')
                .where(champ, isEqualTo: id)
                .get();
            for (var doc in snap.docs) {
              final data = doc.data();
              if (!_contientUnFichier(data)) continue;
              final nomReel = _nomReelDuDoc(data);
              compteursPerso[nomReel] = (compteursPerso[nomReel] ?? 0) + 1;
            }
          } catch (_) {}
        }
      }

      final clesTries = compteursPerso.keys.toList()..sort();
      for (final nom in clesTries) {
        final count = compteursPerso[nom]!;
        final cle = 'perso_${nom.toLowerCase().replaceAll(' ', '_')}';
        final info = getDocTypeInfo(nom);
        tousDocuments.add(DocItem(
          cle: cle,
          nom: nom,
          iconPath: info.iconPath,
          color: info.color,
          iconBg: info.iconBg,
          sousTitre: count > 1 ? '$count fichiers' : '1 fichier',
        ));
        _aut.putIfAbsent(cle, () => true);
      }

      // 3. Photos
      final photos = await _chercherDocs('Photos', buffer);
      final Map<String, int> compteursPhotos = {};
      for (var data in photos) {
        final cat = (data['category'] ?? data['categorie'] ?? 'Photos')
            .toString()
            .trim();
        if (cat.isNotEmpty) {
          compteursPhotos[cat] = (compteursPhotos[cat] ?? 0) + 1;
        }
      }

      final photosPerso = <DocItem>[];
      compteursPhotos.forEach((cat, count) {
        final cle = 'photo_${cat.toLowerCase().replaceAll(' ', '_')}';
        photosPerso.add(DocItem(
          cle: cle,
          nom: cat,
          iconPath: 'assets/icons/ic_photo_item.png',
          color: navy,
          iconBg: const Color(0xFFEEF0FA),
          sousTitre: count > 1 ? '$count photos' : '1 photo',
        ));
        _aut.putIfAbsent(cle, () => true);
      });

      // 4. Vidéos
      final videos = await _chercherDocs('video', buffer);
      final Map<String, int> compteursVideos = {};
      for (var data in videos) {
        final cat = (data['category'] ?? data['categorie'] ?? 'Vidéos')
            .toString()
            .trim();
        if (cat.isNotEmpty) {
          compteursVideos[cat] = (compteursVideos[cat] ?? 0) + 1;
        }
      }

      final videosPerso = <DocItem>[];
      compteursVideos.forEach((cat, count) {
        final cle = 'video_${cat.toLowerCase().replaceAll(' ', '_')}';
        videosPerso.add(DocItem(
          cle: cle,
          nom: cat,
          iconPath: 'assets/icons/ic_video_item.png',
          color: lightPurple,
          iconBg: const Color(0xFFF6EEFB),
          sousTitre: count > 1 ? '$count vidéos' : '1 vidéo',
        ));
        _aut.putIfAbsent(cle, () => true);
      });

      if (!mounted) return;
      _fadeController.forward();
      setState(() {
        _tousDocuments = tousDocuments;
        _photosPerso = photosPerso;
        _videosPerso = videosPerso;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  // Avatar
  Widget _buildAvatar(String photo, {double size = 56}) {
    if (photo.isEmpty) return _avatarFallback(size);
    final bytes = _decodeBase64Image(photo);
    if (bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.memory(bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _avatarFallback(size)),
      );
    }
    if (photo.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(photo,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _avatarFallback(size)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.asset('assets/images/$photo',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback(size)),
    );
  }

  Widget _avatarFallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration:
          const BoxDecoration(color: Color(0xFFF0EDFF), shape: BoxShape.circle),
      child: Icon(Icons.person, color: borderPurple, size: size * 0.4),
    );
  }

  Widget _buildIconImage(String path, Color color, double size) {
    return Image.asset(path,
        width: size,
        height: size,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, __, ___) =>
            Icon(_fallbackIconData(path), color: color, size: size));
  }

  IconData _fallbackIconData(String path) {
    if (path.contains('cv')) return Icons.badge_outlined;
    if (path.contains('diploma') || path.contains('school')) {
      return Icons.school_outlined;
    }
    if (path.contains('certificat') || path.contains('premium')) {
      return Icons.workspace_premium_outlined;
    }
    if (path.contains('document') || path.contains('file')) {
      return Icons.insert_drive_file_outlined;
    }
    if (path.contains('photo') || path.contains('image')) {
      return Icons.photo_outlined;
    }
    if (path.contains('video') || path.contains('film')) {
      return Icons.videocam_outlined;
    }
    if (path.contains('person')) return Icons.person_outline;
    if (path.contains('download')) return Icons.download_outlined;
    return Icons.folder_outlined;
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildProfileCard(),
          const SizedBox(height: 20),
          _buildSectionLabel(),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: borderPurple))
                : _errorMessage != null
                    ? Center(
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12)))
                    : FadeTransition(
                        opacity: _fadeController,
                        child: _buildListe(),
                      ),
          ),
          _buildValidateButton(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: 70,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: _ElegantBackButton(
            onTap: () => Navigator.pop(context),
          ),
        ),
      ),
      title: Text(widget.membreNom,
          style: const TextStyle(
              color: purple, fontSize: 16, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: navy.withValues(alpha: 0.8), width: 1.5),
        boxShadow: const [
          BoxShadow(color: cardShadow, blurRadius: 16, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  const LinearGradient(colors: [borderPurple, lightPurple]),
              boxShadow: [
                BoxShadow(
                    color: borderPurple.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFFF0EDFF),
              child: _buildAvatar(widget.membrePhoto, size: 56),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.membreNom,
                    style: const TextStyle(
                        color: navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 8),
                // ⭐⭐⭐ LIEN DE PARENTÉ EN TEMPS RÉEL ⭐⭐⭐
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFEDE9FE), Color(0xFFF3E8FF)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _lienParenteActuel, // ⭐ Utilise la valeur temps réel
                    style: const TextStyle(
                        color: borderPurple,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.green.withValues(alpha: 0.35),
                    blurRadius: 6,
                    spreadRadius: 1)
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 22),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('Choisissez les accès autorisés',
            style: TextStyle(
                color: grey, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildListe() {
    final sections = <_SectionModel>[];

    sections.add(_SectionModel(
      titre: 'Accès général',
      iconPath: 'assets/icons/ic_person.png',
      color: borderPurple,
      iconBg: const Color(0xFFF3EEFF),
      items: [
        DocItem(
          cle: 'profil',
          nom: 'Voir le profil',
          iconPath: 'assets/icons/ic_person.png',
          color: borderPurple,
          iconBg: const Color(0xFFF3EEFF),
          sousTitre: 'Autoriser l\'accès aux informations du profil',
        ),
        DocItem(
          cle: 'telechargement',
          nom: 'Télécharger les documents',
          iconPath: 'assets/icons/ic_download.png',
          color: borderPurple,
          iconBg: const Color(0xFFF3EEFF),
          sousTitre: 'Autoriser le téléchargement des fichiers',
        ),
      ],
    ));

    if (_tousDocuments.isNotEmpty) {
      sections.add(_SectionModel(
        titre: 'Documents',
        iconPath: 'assets/icons/ic_document.png',
        color: borderPurple,
        iconBg: const Color(0xFFF3EEFF),
        items: _tousDocuments,
      ));
    }

    if (_photosPerso.isNotEmpty) {
      sections.add(_SectionModel(
        titre: 'Photos',
        iconPath: 'assets/icons/ic_photo.png',
        color: navy,
        iconBg: const Color(0xFFEEF0FA),
        items: _photosPerso,
      ));
    }

    if (_videosPerso.isNotEmpty) {
      sections.add(_SectionModel(
        titre: 'Vidéos',
        iconPath: 'assets/icons/ic_video.png',
        color: lightPurple,
        iconBg: const Color(0xFFF6EEFB),
        items: _videosPerso,
      ));
    }

    if (sections.length <= 1) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                  color: Color(0xFFF0EDFF), shape: BoxShape.circle),
              child: const Icon(Icons.folder_open_outlined,
                  color: borderPurple, size: 38),
            ),
            const SizedBox(height: 14),
            const Text('Aucun document',
                style: TextStyle(
                    color: navy, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Ce membre n\'a rien ajouté',
                style: TextStyle(color: grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      itemCount: sections.length,
      itemBuilder: (context, idx) => _buildSectionCard(sections[idx]),
    );
  }

  Widget _buildSectionCard(_SectionModel section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: cardShadow, blurRadius: 12, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: section.iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: _buildIconImage(section.iconPath, section.color, 18),
                  ),
                ),
                const SizedBox(width: 10),
                Text(section.titre,
                    style: const TextStyle(
                        color: navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3)),
              ],
            ),
          ),
          ...section.items.asMap().entries.map((entry) {
            return _buildPermissionRow(entry.value, isFirst: entry.key == 0);
          }),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(DocItem item, {bool isFirst = false}) {
    final bool autorise = _aut[item.cle] ?? true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: isFirst
              ? const BorderSide(color: Color(0xFFF3F4F6), width: 1)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: _buildIconImage(item.iconPath, item.color, 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nom,
                    style: TextStyle(
                      color: autorise ? navy : grey,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    )),
                if (item.sousTitre != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(item.sousTitre!,
                        style: const TextStyle(color: grey, fontSize: 11.5)),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: autorise
                      ? item.color.withValues(alpha: 0.12)
                      : const Color(0xFFF0F0F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(autorise ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: autorise ? item.color : grey,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 30,
                child: FittedBox(
                  child: Switch(
                    value: autorise,
                    activeTrackColor: item.color,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFE0E0E0),
                    onChanged: (v) {
                      setState(() => _aut[item.cle] = v);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidateButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context, Map<String, bool>.from(_aut));
        },
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [purple, lightPurple],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: purple.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6))
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Valider les autorisations',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
            ],
          ),
        ),
      ),
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
                color: Colors.black.withValues(alpha: 0.06),
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
