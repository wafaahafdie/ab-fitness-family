// lib/DocumentsVisiteurScreen.dart - VERSION CORRIGÉE ✅
// ⭐ CORRIGÉ : bouton retour élégant
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'CvScreen.dart';
import 'Diplome.dart';
import 'Certaficat.dart';
import 'MesPhotosScreen.dart';
import 'MesVideosScreen.dart';

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
  final bool autorise;

  DocItem({
    required this.cle,
    required this.nom,
    required this.iconPath,
    required this.color,
    required this.iconBg,
    this.sousTitre,
    this.autorise = false,
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
// DOCUMENTS VISITEUR SCREEN
// ============================================================

class DocumentsVisiteurScreen extends StatefulWidget {
  final String membreId;
  final String membreNom;
  final String membrePhoto;
  final String lienParente;
  final Map<String, bool> autorisationsChef;

  const DocumentsVisiteurScreen({
    super.key,
    required this.membreId,
    required this.membreNom,
    required this.membrePhoto,
    required this.lienParente,
    required this.autorisationsChef,
  });

  @override
  State<DocumentsVisiteurScreen> createState() =>
      _DocumentsVisiteurScreenState();
}

class _DocumentsVisiteurScreenState extends State<DocumentsVisiteurScreen>
    with TickerProviderStateMixin {
  List<DocItem> _tousDocuments = [];
  List<DocItem> _photosPerso = [];
  List<DocItem> _videosPerso = [];

  bool _isLoading = true;
  String? _errorMessage;

  List<String> _tousLesIdsPossibles = [];
  final Map<String, String> _mapCategoryIdVersNom = {};

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _charger();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

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

  Future<void> _collecterTousLesIds() async {
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

  Future<void> _chargerCategoriesPersonnalisees() async {
    for (final id in _tousLesIdsPossibles) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('Membres Famille')
            .doc(id)
            .get();
        if (!doc.exists) continue;
        final cats = doc.data()!['categories'];
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

  Future<List<Map<String, dynamic>>> _chercherDocs(String collection) async {
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

  bool _isAutorise(String cle) {
    return widget.autorisationsChef[cle] ?? false;
  }

  Future<void> _charger() async {
    try {
      await _collecterTousLesIds();
      await _chargerCategoriesPersonnalisees();

      final tousDocuments = <DocItem>[];

      const Map<String, String> collectionsStandards = {
        'CvFiles': 'cv',
        'DiplomeFiles': 'diplome',
        'CertificatFiles': 'certificat',
      };

      for (final entry in collectionsStandards.entries) {
        final docs = await _chercherDocs(entry.key);
        final Map<String, int> compteurs = {};
        for (var doc in docs) {
          final nom = _nomReelDuDoc(doc);
          compteurs[nom] = (compteurs[nom] ?? 0) + 1;
        }

        compteurs.forEach((nom, count) {
          final cle =
              'std_${entry.value}_${nom.toLowerCase().replaceAll(' ', '_')}';
          final info = getDocTypeInfo(entry.value);
          final autorise = _isAutorise(cle);

          tousDocuments.add(DocItem(
            cle: cle,
            nom: nom,
            iconPath: info.iconPath,
            color: autorise ? info.color : grey,
            iconBg: autorise ? info.iconBg : const Color(0xFFF0F0F2),
            sousTitre: count > 1 ? '$count fichiers' : '1 fichier',
            autorise: autorise,
          ));
        });
      }

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
        final autorise = _isAutorise(cle);

        tousDocuments.add(DocItem(
          cle: cle,
          nom: nom,
          iconPath: info.iconPath,
          color: autorise ? info.color : grey,
          iconBg: autorise ? info.iconBg : const Color(0xFFF0F0F2),
          sousTitre: count > 1 ? '$count fichiers' : '1 fichier',
          autorise: autorise,
        ));
      }

      final photos = await _chercherDocs('Photos');
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
        final autorise = _isAutorise(cle);
        photosPerso.add(DocItem(
          cle: cle,
          nom: cat,
          iconPath: 'assets/icons/ic_photo_item.png',
          color: autorise ? navy : grey,
          iconBg: autorise ? const Color(0xFFEEF0FA) : const Color(0xFFF0F0F2),
          sousTitre: '$count photo(s)',
          autorise: autorise,
        ));
      });

      final videos = await _chercherDocs('video');
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
        final autorise = _isAutorise(cle);
        videosPerso.add(DocItem(
          cle: cle,
          nom: cat,
          iconPath: 'assets/icons/ic_video_item.png',
          color: autorise ? lightPurple : grey,
          iconBg: autorise ? const Color(0xFFF6EEFB) : const Color(0xFFF0F0F2),
          sousTitre: '$count vidéo(s)',
          autorise: autorise,
        ));
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

  void _ouvrirDocument(DocItem item) {
    if (!item.autorise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Ce document n\'est pas autorisé'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    final cle = item.cle.toLowerCase();

    try {
      if (cle.contains('cv')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CvScreen(
              memberId: widget.membreId,
            ),
          ),
        );
      } else if (cle.contains('diplome')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DiplomeScreen(
              memberId: widget.membreId,
            ),
          ),
        );
      } else if (cle.contains('certificat')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Certaficat(
              memberId: widget.membreId,
            ),
          ),
        );
      } else if (cle.startsWith('photo_')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MesPhotosScreen(),
          ),
        );
      } else if (cle.startsWith('video_')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MesVideosScreen(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📂 Ouverture: ${item.nom}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur d\'ouverture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
    return Icons.folder_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceLight,
      // ⭐ APPBAR avec bouton retour élégant
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: const BoxDecoration(color: Colors.white),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                _ElegantBackButton(
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.membreNom,
                    style: const TextStyle(
                      color: purple,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: navy.withOpacity(0.8), width: 1.5),
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
                    color: borderPurple.withOpacity(0.25),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFEDE9FE), Color(0xFFF3E8FF)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(widget.lienParente,
                      style: const TextStyle(
                          color: borderPurple,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.4)),
            ),
            child: const Text('Accès autorisé',
                style: TextStyle(
                    color: Colors.green,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 14, color: grey),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Cliquez sur un document autorisé pour le consulter',
                style: TextStyle(
                    color: grey, fontSize: 11.5, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListe() {
    final sections = <_SectionModel>[];

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

    if (sections.isEmpty) {
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
            const Text('Le chef n\'a rien ajouté',
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
    final bool autorise = item.autorise;

    return GestureDetector(
      onTap: () => _ouvrirDocument(item),
      child: Container(
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: autorise
                    ? Colors.green.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: autorise
                      ? Colors.green.withOpacity(0.4)
                      : Colors.grey.withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    autorise ? Icons.check_circle : Icons.lock_outline,
                    size: 12,
                    color: autorise ? Colors.green : grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    autorise ? 'Autorisé' : 'Bloqué',
                    style: TextStyle(
                      color: autorise ? Colors.green : grey,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (autorise) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: navy, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ⭐ BOUTON RETOUR ÉLÉGANT (design RoleSelectionScreen)
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
                color: Color(0xFF1F2A6B),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
