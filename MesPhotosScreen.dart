// lib/MesPhotosScreen.dart - AVEC VISITEUR + TÉLÉCHARGEMENT
// ⭐ CORRECTION : récupération photo du Chef via doc ID direct
// ⭐ CORRECTION : badge du rôle à largeur DYNAMIQUE
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/photos.dart';
import 'services/supabase_service.dart';
import 'VoyageScreen.dart';
import 'SportScreen.dart';
import 'AmisScreen.dart';
import 'FamilleScreen .dart';
import 'AnniversaireScreen.dart';
import 'MariageScreen.dart';
import 'AjouterDocumentPScreen.dart';

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF6046F4);
const Color pink = Color(0xFFE91E9B);
const Color grey = Color(0xFF9E9EAE);
const Color violetBtn = Color(0xFF6C20E8);
const Color lightPink = Color(0xFFFFE4E8);
const Color selectedGreen = Color(0xFF4CAF50);

// ============================================================
// MODELE CATEGORIE
// ============================================================

class PhotoCategory {
  final String title;
  final String navType;
  final String count;
  final Color iconColor;
  final Color numberColor;
  final String badge;
  final IconData icon;
  final bool isDefault;

  const PhotoCategory({
    required this.title,
    required this.navType,
    required this.count,
    required this.iconColor,
    required this.numberColor,
    required this.badge,
    required this.icon,
    this.isDefault = false,
  });
}

class _CategoryInfo {
  final String title;
  final String navType;
  final bool isDefault;

  _CategoryInfo({
    required this.title,
    required this.navType,
    required this.isDefault,
  });
}

// ============================================================
// CATÉGORIES PAR DÉFAUT
// ============================================================

final Map<String, IconData> _defaultCategoryIcons = {
  'Voyage': Icons.flight,
  'Sport': Icons.sports_soccer,
  'Amis': Icons.people_outline,
  'Anniversaire': Icons.cake_outlined,
  'Mariage': Icons.favorite_border,
  'Famille': Icons.groups_outlined,
};

final Map<String, Color> _categoryColors = {
  'Voyage': const Color(0xFF10B8AD),
  'Sport': const Color(0xFF62C93D),
  'Amis': const Color(0xFF4777F5),
  'Anniversaire': const Color(0xFFFF7D27),
  'Mariage': const Color(0xFFE91E9B),
  'Famille': const Color(0xFF8048E9),
};

final Map<String, Color> _badgeColors = {
  'Voyage': const Color(0xFF74E58C),
  'Sport': const Color(0xFFF0A23A),
  'Amis': const Color(0xFF7184E8),
  'Anniversaire': const Color(0xFFE77474),
  'Mariage': const Color(0xFFE77AB5),
  'Famille': const Color(0xFFE0D34D),
};

// ============================================================
// ⭐ HELPER BASE64 ROBUSTE
// ============================================================

Uint8List? _decodeBase64Robuste(String value) {
  if (value.isEmpty) return null;
  if (value.startsWith('assets/')) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return null;

  try {
    String raw = value.contains(',') ? value.split(',').last : value;

    raw = raw
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('-', '+')
        .replaceAll('_', '/');

    final mod = raw.length % 4;
    if (mod != 0) {
      raw = raw.padRight(raw.length + (4 - mod), '=');
    }

    final bytes = base64Decode(raw);
    if (bytes.isEmpty) return null;

    return bytes;
  } catch (e) {
    debugPrint('❌ Erreur décodage base64: $e');
    return null;
  }
}

// ============================================================
// NAVIGATION
// ============================================================

void _navigateToCategory(
  BuildContext context,
  String navType,
  String displayName,
  String memberId, {
  bool isVisitor = false,
  bool canDownload = false,
}) {
  Widget screen;
  switch (navType) {
    case 'Voyage':
      screen = VoyageScreen(
        memberId: memberId,
        categoryName: displayName,
        isVisitor: isVisitor,
        canDownload: canDownload,
      );
      break;
    case 'Sport':
      screen = SportScreen(
        memberId: memberId,
        categoryName: displayName,
        isVisitor: isVisitor,
        canDownload: canDownload,
      );
      break;
    case 'Amis':
      screen = AmisScreen(
        memberId: memberId,
        categoryName: displayName,
        isVisitor: isVisitor,
        canDownload: canDownload,
      );
      break;
    case 'Anniversaire':
      screen = AnniversaireScreen(
        memberId: memberId,
        categoryName: displayName,
        isVisitor: isVisitor,
        canDownload: canDownload,
      );
      break;
    case 'Mariage':
      screen = MariageScreen(
        memberId: memberId,
        categoryName: displayName,
        isVisitor: isVisitor,
        canDownload: canDownload,
      );
      break;
    case 'Famille':
      screen = FamilleScreen(
        memberId: memberId,
        categoryName: displayName,
        isVisitor: isVisitor,
        canDownload: canDownload,
      );
      break;
    default:
      screen = VoyageScreen(
        memberId: memberId,
        categoryName: displayName,
        isVisitor: isVisitor,
        canDownload: canDownload,
      );
  }
  Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
}

// ============================================================
// MES PHOTOS SCREEN
// ============================================================

class MesPhotosScreen extends StatefulWidget {
  final String? memberId;

  final bool isVisitor;
  final bool canDownload;
  final List<String> hiddenCategories;

  const MesPhotosScreen({
    super.key,
    this.memberId,
    this.isVisitor = false,
    this.canDownload = false,
    this.hiddenCategories = const [],
  });

  @override
  State<MesPhotosScreen> createState() => _MesPhotosScreenState();
}

class _MesPhotosScreenState extends State<MesPhotosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SupabaseService _storage = SupabaseService();

  String _selectedCategory = 'Toutes les Catégories';
  String _searchQuery = '';
  List<Photo> _allPhotos = [];
  bool _isLoading = true;
  bool _isImporting = false;
  String? _errorMessage;

  bool _isSelecting = false;
  Set<String> _selectedPhotoIds = {};

  String _memberName = 'Chargement...';
  String _memberPhoto = '';
  String _memberRole = '';
  String _memberId = '';
  String _memberDocId = '';
  String _memberCollection = '';

  List<Map<String, dynamic>> _customCategories = [];
  List<String> _hiddenDefaultCategories = [];

  Uint8List? _photoBytes;

  StreamSubscription<QuerySnapshot>? _photosSubscription;

  @override
  void initState() {
    super.initState();
    _memberId = widget.memberId ?? '';
    debugPrint('📌 MesPhotosScreen - memberId reçu: $_memberId');
    debugPrint('👤 isVisitor: ${widget.isVisitor}');
    debugPrint('📥 canDownload: ${widget.canDownload}');
    debugPrint('🚫 hiddenCategories (reçues): ${widget.hiddenCategories}');

    if (_memberId.isNotEmpty) {
      _initData();
    } else {
      setState(() {
        _isLoading = false;
        _memberName = 'Utilisateur';
        _memberRole = 'Membre';
      });
    }
  }

  Future<void> _initData() async {
    await _loadMemberInfo();
    _loadPhotos();
  }

  @override
  void dispose() {
    _photosSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // ⭐⭐⭐ CHARGER LES INFOS DU MEMBRE (CORRIGÉ)
  // ⭐⭐⭐ Essayer d'abord Chef de Famille par docId direct
  // ============================================================

  Future<void> _loadMemberInfo() async {
    if (_memberId.isEmpty) {
      setState(() {
        _memberName = 'Utilisateur';
        _memberRole = 'Membre';
        _photoBytes = null;
        _isLoading = false;
      });
      return;
    }

    try {
      Map<String, dynamic>? memberData;
      String? collection;
      String? docId;

      // ⭐ 1) CHEF DE FAMILLE — par doc ID DIRECT (doc ID = auth UID)
      try {
        final chefDoc = await FirebaseFirestore.instance
            .collection('Chef de Famille')
            .doc(_memberId)
            .get();

        if (chefDoc.exists) {
          memberData = chefDoc.data();
          collection = 'Chef de Famille';
          docId = chefDoc.id;
          debugPrint('✅ Chef trouvé par docId: $_memberId');
        }
      } catch (e) {
        debugPrint('⚠️ Erreur recherche chef par docId: $e');
      }

      // ⭐ 2) MEMBRES FAMILLE — par userId
      if (memberData == null) {
        try {
          final querySnapshot = await FirebaseFirestore.instance
              .collection('Membres Famille')
              .where('userId', isEqualTo: _memberId)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            memberData =
                querySnapshot.docs.first.data() as Map<String, dynamic>;
            collection = 'Membres Famille';
            docId = querySnapshot.docs.first.id;
            debugPrint('✅ Membre trouvé dans Membres Famille: $docId');
          }
        } catch (e) {
          debugPrint('⚠️ Erreur recherche membre: $e');
        }
      }

      // ⭐ 3) FALLBACK — Chef de Famille par userId
      if (memberData == null) {
        try {
          final chefQuery = await FirebaseFirestore.instance
              .collection('Chef de Famille')
              .where('userId', isEqualTo: _memberId)
              .limit(1)
              .get();

          if (chefQuery.docs.isNotEmpty) {
            memberData = chefQuery.docs.first.data() as Map<String, dynamic>;
            collection = 'Chef de Famille';
            docId = chefQuery.docs.first.id;
            debugPrint('✅ Chef trouvé par userId: $docId');
          }
        } catch (e) {
          debugPrint('⚠️ Erreur recherche chef par userId: $e');
        }
      }

      // ⭐ 4) DONNÉES TROUVÉES
      if (memberData != null && docId != null) {
        _memberCollection = collection!;
        _memberDocId = docId;

        if (memberData['categories'] != null &&
            memberData['categories'] is List) {
          _customCategories = (memberData['categories'] as List)
              .where((cat) => cat is Map)
              .map((cat) => Map<String, dynamic>.from(cat as Map))
              .toList();
        } else {
          _customCategories = [];
        }

        List<String> memberHidden = [];
        if (memberData['hiddenDefaultCategories'] != null &&
            memberData['hiddenDefaultCategories'] is List) {
          memberHidden =
              List<String>.from(memberData['hiddenDefaultCategories'])
                  .map((e) => e.toLowerCase())
                  .toList();
        }

        final Set<String> combinedHidden = {
          ...memberHidden,
          ...widget.hiddenCategories.map((e) => e.toLowerCase()),
        };
        _hiddenDefaultCategories = combinedHidden.toList();

        debugPrint('🚫 Catégories cachées finales: $_hiddenDefaultCategories');

        final String name = memberData['fullName'] ??
            memberData['name'] ??
            memberData['nom'] ??
            memberData['full_name'] ??
            'Utilisateur';

        String photo = memberData['photoUrl'] ??
            memberData['photo'] ??
            memberData['photo_url'] ??
            memberData['avatar'] ??
            memberData['profileImage'] ??
            memberData['photoBase64'] ??
            memberData['image'] ??
            '';

        final String role = memberData['relationship'] ??
            memberData['role'] ??
            memberData['lien'] ??
            memberData['relation'] ??
            'Membre';

        _photoBytes = null;
        if (photo.isNotEmpty &&
            !photo.startsWith('http') &&
            !photo.startsWith('assets/')) {
          _photoBytes = _decodeBase64Robuste(photo);
        }

        debugPrint(
            '📸 Photo URL (${photo.length > 40 ? '${photo.substring(0, 40)}...' : photo})');
        debugPrint('📸 Photo bytes: ${_photoBytes?.length ?? 0}');

        setState(() {
          _memberName = name;
          _memberPhoto = photo;
          _memberRole = role;
          _isLoading = false;
        });
        return;
      }

      debugPrint('❌ Aucun membre trouvé pour: $_memberId');
      setState(() {
        _memberName = 'Utilisateur';
        _memberRole = 'Membre';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Erreur _loadMemberInfo: $e');
      setState(() {
        _memberName = 'Utilisateur';
        _memberRole = 'Membre';
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // CHARGER LES PHOTOS
  // ============================================================

  void _loadPhotos() {
    if (_memberId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    _photosSubscription?.cancel();

    try {
      final query = FirebaseFirestore.instance
          .collection('Photos')
          .where('memberId', isEqualTo: _memberId);

      _photosSubscription = query.snapshots().listen((snapshot) {
        final List<Photo> loadedPhotos = [];
        for (var doc in snapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            loadedPhotos.add(Photo.fromFirestore(doc.id, data));
          } catch (_) {}
        }

        loadedPhotos.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

        if (mounted) {
          setState(() {
            _allPhotos = loadedPhotos;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      }, onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Erreur: $error';
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur: $e';
        });
      }
    }
  }

  // ============================================================
  // SÉLECTION / TÉLÉCHARGEMENT
  // ============================================================

  void _toggleSelectionMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      if (!_isSelecting) _selectedPhotoIds = {};
    });
  }

  void _togglePhotoSelection(String id) {
    setState(() {
      if (_selectedPhotoIds.contains(id)) {
        _selectedPhotoIds.remove(id);
      } else {
        _selectedPhotoIds.add(id);
      }
    });
  }

  Future<void> _downloadSelected() async {
    if (_selectedPhotoIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins une photo')),
      );
      return;
    }

    final selectedPhotos =
        _allPhotos.where((p) => _selectedPhotoIds.contains(p.id)).toList();

    int success = 0;
    for (final photo in selectedPhotos) {
      try {
        final uri = Uri.parse(photo.downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          success++;
          await Future.delayed(const Duration(milliseconds: 300));
        }
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $success photo(s) téléchargée(s)'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _isSelecting = false;
        _selectedPhotoIds = {};
      });
    }
  }

  // ============================================================
  // NAVIGATION VERS AJOUTER DOCUMENT - BLOQUÉ POUR VISITEUR
  // ============================================================

  Future<void> _ouvrirAjouterDocument() async {
    if (widget.isVisitor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Action non autorisée'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AjouterDocumentPScreen(
            memberId: _memberId,
            memberDocId: _memberDocId,
            memberCollection: _memberCollection,
          ),
        ),
      );

      if (result == true) {
        await _loadMemberInfo();
        _loadPhotos();

        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Catégorie ajoutée avec succès'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur ajout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // IMPORTER UNE PHOTO - BLOQUÉ POUR VISITEUR
  // ============================================================

  Future<void> _importerPhoto() async {
    if (widget.isVisitor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Import non autorisé'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isImporting) return;
    setState(() => _isImporting = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isImporting = false);
        return;
      }

      final pickedFile = result.files.single;
      final Uint8List? bytes = pickedFile.bytes;

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Fichier invalide ou vide');
      }

      final category = await _showCategoryDialog();
      if (category == null) {
        setState(() => _isImporting = false);
        return;
      }

      final safeName = _sanitizeFileName(pickedFile.name);
      final storagePath =
          '${_memberId}/${category.toLowerCase()}/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final downloadUrl = await _storage.uploadFile(
        bucket: 'media_files',
        path: storagePath,
        bytes: bytes,
        contentType: 'image/jpeg',
      );

      if (downloadUrl.isEmpty) {
        throw Exception('URL de téléchargement vide');
      }

      await FirebaseFirestore.instance.collection('Photos').add({
        'name': pickedFile.name,
        'category': category,
        'memberId': _memberId,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'sizeBytes': bytes.length,
        'type': 'photo',
      });

      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Photo importée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur import: $e');
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showCategoryDialog() async {
    final allCategories = {
      ..._defaultCategoryIcons.keys
          .where((k) => !_hiddenDefaultCategories.contains(k.toLowerCase())),
      ..._customCategories.map((cat) => cat['nom'] as String),
    }.toList();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Choisir une catégorie'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...allCategories.map((cat) {
                final isDefault = _defaultCategoryIcons.containsKey(cat);
                final icon = isDefault
                    ? _defaultCategoryIcons[cat]
                    : Icons.folder_outlined;
                final color = isDefault
                    ? _categoryColors[cat] ?? Colors.grey
                    : Colors.blue;

                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(cat),
                  onTap: () => Navigator.pop(context, cat),
                );
              }).toList(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_circle, color: purple),
                title: const Text(
                  'Ajouter une catégorie',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _ouvrirAjouterDocument();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^\w\-. ]'), '_').replaceAll(' ', '_');
  }

  Map<String, int> _getCategoryCounts() {
    final Map<String, int> counts = {};
    for (final photo in _allPhotos) {
      counts[photo.category] = (counts[photo.category] ?? 0) + 1;
    }
    return counts;
  }

  List<_CategoryInfo> _getAllCategoryInfos() {
    final List<_CategoryInfo> infos = [];

    for (final key in _defaultCategoryIcons.keys) {
      final keyLower = key.toLowerCase();
      if (!_hiddenDefaultCategories.contains(keyLower)) {
        infos.add(_CategoryInfo(title: key, navType: key, isDefault: true));
      }
    }

    for (final cat in _customCategories) {
      final title = cat['nom'] as String?;
      if (title == null || title.isEmpty) continue;

      final source = cat['source'];
      if (source == 'detail_screen') continue;
      if (source == 'videos_screen') continue;
      if (source != null && source != 'photos_screen') continue;

      if (_hiddenDefaultCategories.contains(title.toLowerCase())) continue;

      final navType = cat['originalDefaultType'] as String? ?? title;
      infos.add(_CategoryInfo(
        title: title,
        navType: navType,
        isDefault: false,
      ));
    }

    return infos;
  }

  Widget _asset(String name,
      {double size = 20, Color? color, IconData? fallback}) {
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

  Widget _buildProfilePhoto() {
    if (_photoBytes != null && _photoBytes!.isNotEmpty) {
      debugPrint('🖼️ Affichage photo base64: ${_photoBytes!.length} bytes');
      return ClipOval(
        child: Image.memory(
          _photoBytes!,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) {
            debugPrint('❌ Erreur affichage Image.memory');
            return _defaultAvatar();
          },
        ),
      );
    }

    if (_memberPhoto.isNotEmpty &&
        (_memberPhoto.startsWith('http://') ||
            _memberPhoto.startsWith('https://'))) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: _memberPhoto,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          placeholder: (_, __) => _defaultAvatar(),
          errorWidget: (_, __, ___) => _defaultAvatar(),
        ),
      );
    }

    if (_memberPhoto.startsWith('assets/')) {
      return ClipOval(
        child: Image.asset(
          _memberPhoto,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAvatar(),
        ),
      );
    }

    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return ClipOval(
      child: Image.asset(
        'assets/images/profilpat.jpg',
        width: 68,
        height: 68,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.person, size: 34, color: Colors.grey),
        ),
      ),
    );
  }

  // ============================================================
  // RENOMMER CATÉGORIE - BLOQUÉ POUR VISITEUR
  // ============================================================

  Future<void> _renommerCategorie(
      String oldCategoryName, String navType, bool isDefault) async {
    if (widget.isVisitor) return;

    final TextEditingController controller =
        TextEditingController(text: oldCategoryName);

    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Renommer la catégorie',
            style: TextStyle(color: navy, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: navy, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF0EFFF),
            hintText: 'Nouveau nom',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: grey)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty && name != oldCategoryName) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Renommer',
                style: TextStyle(color: purple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == oldCategoryName)
      return;

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Photos')
          .where('memberId', isEqualTo: _memberId)
          .where('category', isEqualTo: oldCategoryName)
          .get();

      final WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'category': newName});
      }
      await batch.commit();

      if (isDefault) {
        if (!_hiddenDefaultCategories.contains(oldCategoryName.toLowerCase())) {
          _hiddenDefaultCategories.add(oldCategoryName.toLowerCase());
        }
        _customCategories.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'nom': newName,
          'originalDefaultType': navType,
          'iconCodePoint': _defaultCategoryIcons[navType]?.codePoint ??
              Icons.folder_outlined.codePoint,
          'color': (_categoryColors[navType] ?? Colors.blue).value,
          'iconColor': (_categoryColors[navType] ?? Colors.blue).value,
          'createdAt': DateTime.now().toIso8601String(),
          'source': 'photos_screen',
        });

        if (_memberDocId.isNotEmpty && _memberCollection.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection(_memberCollection)
              .doc(_memberDocId)
              .update({
            'hiddenDefaultCategories': _hiddenDefaultCategories,
            'categories': _customCategories,
          });
        }
      } else {
        for (int i = 0; i < _customCategories.length; i++) {
          if (_customCategories[i]['nom'] == oldCategoryName) {
            _customCategories[i]['nom'] = newName;
            break;
          }
        }
        if (_memberDocId.isNotEmpty && _memberCollection.isNotEmpty) {
          await _updateCategoryInMember(oldCategoryName, newName);
        }
      }

      await _loadMemberInfo();
      _loadPhotos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Catégorie renommée en "$newName" - ${snapshot.docs.length} photos conservées'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur renommage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateCategoryInMember(String oldName, String newName) async {
    try {
      if (_memberDocId.isEmpty || _memberCollection.isEmpty) return;

      final docRef = FirebaseFirestore.instance
          .collection(_memberCollection)
          .doc(_memberDocId);
      final snapshot = await docRef.get();

      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      final List categories =
          data['categories'] is List ? data['categories'] as List : [];

      bool updated = false;
      final List updatedCategories = categories.map((cat) {
        if (cat is Map && cat['nom'] == oldName) {
          updated = true;
          return {...cat, 'nom': newName};
        }
        return cat;
      }).toList();

      if (updated) {
        await docRef.update({'categories': updatedCategories});
      }
    } catch (e) {
      debugPrint('❌ Erreur: $e');
    }
  }

  Future<void> _supprimerCategorie(String categoryName, bool isDefault) async {
    if (widget.isVisitor) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer la catégorie',
            style: TextStyle(color: navy, fontWeight: FontWeight.bold)),
        content: Text(
          'Voulez-vous supprimer la catégorie "$categoryName" ?\n\n'
          '⚠️ Toutes les photos de cette catégorie seront également supprimées.',
          style: const TextStyle(color: grey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Photos')
          .where('memberId', isEqualTo: _memberId)
          .where('category', isEqualTo: categoryName)
          .get();

      final WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (isDefault) {
        if (!_hiddenDefaultCategories.contains(categoryName.toLowerCase())) {
          _hiddenDefaultCategories.add(categoryName.toLowerCase());
        }
        if (_memberDocId.isNotEmpty && _memberCollection.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection(_memberCollection)
              .doc(_memberDocId)
              .update({'hiddenDefaultCategories': _hiddenDefaultCategories});
        }
      } else {
        _customCategories.removeWhere((cat) => cat['nom'] == categoryName);
        if (_memberDocId.isNotEmpty && _memberCollection.isNotEmpty) {
          await _removeCategoryFromMember(categoryName);
        }
      }

      await _loadMemberInfo();
      if (mounted) setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Catégorie "$categoryName" supprimée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeCategoryFromMember(String categoryName) async {
    try {
      if (_memberDocId.isEmpty || _memberCollection.isEmpty) return;

      final docRef = FirebaseFirestore.instance
          .collection(_memberCollection)
          .doc(_memberDocId);
      final snapshot = await docRef.get();

      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      final List categories =
          data['categories'] is List ? data['categories'] as List : [];

      final List updatedCategories = categories
          .where((cat) => cat is Map && cat['nom'] != categoryName)
          .toList();

      if (updatedCategories.length != categories.length) {
        await docRef.update({'categories': updatedCategories});
      }
    } catch (e) {
      debugPrint('❌ Erreur: $e');
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final categoryCounts = _getCategoryCounts();
    final categoryInfos = _getAllCategoryInfos();

    final List<PhotoCategory> categories = categoryInfos.map((info) {
      final count = categoryCounts[info.title] ?? 0;

      IconData icon;
      Color color;
      Color badgeColor;

      if (info.isDefault) {
        icon = _defaultCategoryIcons[info.navType]!;
        color = _categoryColors[info.navType] ?? Colors.grey;
        badgeColor = _badgeColors[info.navType] ?? Colors.grey.shade400;
      } else {
        Map<String, dynamic>? customCat;
        for (var cat in _customCategories) {
          if (cat['nom'] == info.title) {
            customCat = cat;
            break;
          }
        }

        if (customCat != null) {
          final int? iconCode = customCat['iconCodePoint'];
          final int? iconColorValue =
              customCat['iconColor'] ?? customCat['color'];

          icon = iconCode != null
              ? IconData(iconCode, fontFamily: 'MaterialIcons')
              : Icons.folder_outlined;
          color = iconColorValue != null
              ? Color(iconColorValue)
              : Colors.blue.shade300;
          badgeColor = iconColorValue != null
              ? Color(iconColorValue).withOpacity(0.7)
              : Colors.grey.shade400;
        } else {
          icon = _defaultCategoryIcons[info.navType] ?? Icons.folder_outlined;
          color = _categoryColors[info.navType] ?? Colors.blue.shade300;
          badgeColor = _badgeColors[info.navType] ?? Colors.grey.shade400;
        }
      }

      return PhotoCategory(
        title: info.title,
        navType: info.navType,
        count: '$count photo${count > 1 ? 's' : ''}',
        icon: icon,
        iconColor: color,
        numberColor: badgeColor,
        badge: '+$count',
        isDefault: info.isDefault,
      );
    }).toList();

    var displayedCategories = _selectedCategory == 'Toutes les Catégories'
        ? categories
        : categories.where((c) => c.title == _selectedCategory).toList();

    if (_searchQuery.isNotEmpty) {
      displayedCategories = displayedCategories
          .where(
              (c) => c.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFD),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: purple))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 10),
                        _buildProfile(),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: _buildSearchBar()),
                            const SizedBox(width: 8),
                            if (!widget.isVisitor) _buildAddButton(),
                            if (widget.canDownload &&
                                _allPhotos.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _buildDownloadButton(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildCategorySelector(categoryInfos),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: displayedCategories.isEmpty
                          ? const Center(
                              child: Text(
                                'Aucune catégorie disponible',
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            )
                          : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 9,
                                mainAxisSpacing: 9,
                                childAspectRatio: 1.18,
                              ),
                              itemCount: displayedCategories.length,
                              itemBuilder: (context, index) {
                                return _buildCategoryCard(
                                    displayedCategories[index]);
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
      ),
    );
  }

  Widget _buildDownloadButton() {
    return GestureDetector(
      onTap: _isSelecting ? _downloadSelected : _toggleSelectionMode,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _isSelecting ? selectedGreen : purple,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isSelecting
                  ? Icons.download_rounded
                  : Icons.check_circle_outline,
              color: Colors.white,
              size: 17,
            ),
            const SizedBox(width: 5),
            Text(
              _isSelecting ? '${_selectedPhotoIds.length}' : 'Télécharger',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _ElegantBackButton(
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 12),
        const Text(
          'Mes photos',
          style: TextStyle(
            color: navy,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (_isSelecting)
          GestureDetector(
            onTap: _toggleSelectionMode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ⭐⭐⭐ PROFIL AVEC BADGE À LARGEUR DYNAMIQUE ⭐⭐⭐
  Widget _buildProfile() {
    return Column(
      children: [
        // Avatar
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE9E3FF), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildProfilePhoto(),
        ),
        const SizedBox(height: 6),

        // Nom
        Text(
          _memberName,
          style: const TextStyle(
              color: navy, fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),

        // ⭐ Badge du rôle — LARGEUR DYNAMIQUE (s'adapte au texte)
        Container(
          constraints: const BoxConstraints(
            minWidth: 68,
            maxWidth: double.infinity,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF9C9CC0), Color(0xFFE58BD4)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _memberRole,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600),
          ),
        ),

        const SizedBox(height: 5),

        // Description
        Text(
          '${_allPhotos.length} photos • Gérez et organisez vos photos par catégorie',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFB7B7C5), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8E8EE), width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, size: 17, color: Color(0xFFC8C8D0)),
          const SizedBox(width: 7),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: navy, fontSize: 11),
              onChanged: (value) {
                setState(() => _searchQuery = value.trim());
              },
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Recherche des Photos...',
                hintStyle: TextStyle(color: Color(0xFFC8C8D0), fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 7),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _ouvrirAjouterDocument,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C20E8), Color(0xFFC318D9)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Colors.white, size: 17),
            SizedBox(width: 5),
            Text(
              'Ajouter',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(List<_CategoryInfo> categoryInfos) {
    return GestureDetector(
      onTap: () => _openCategoryMenu(categoryInfos),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0xFFE3E3EA), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.category_outlined, size: 21, color: navy),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _selectedCategory,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: navy, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 21, color: navy),
          ],
        ),
      ),
    );
  }

  void _openCategoryMenu(List<_CategoryInfo> categoryInfos) {
    final List<String> values = [
      'Toutes les Catégories',
      ...categoryInfos.map((c) => c.title),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3E3EA),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const Text(
                  'Choisir une catégorie',
                  style: TextStyle(
                      color: navy, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...values.map((value) {
                  final bool isSelected = value == _selectedCategory;
                  final info =
                      categoryInfos.where((c) => c.title == value).toList();
                  final navType = info.isNotEmpty ? info.first.navType : value;
                  final icon =
                      _defaultCategoryIcons[navType] ?? Icons.folder_outlined;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = value);
                      Navigator.pop(sheetContext);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFF3E9FB)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          if (value != 'Toutes les Catégories')
                            Icon(icon,
                                color: _categoryColors[navType] ?? Colors.blue,
                                size: 18),
                          if (value != 'Toutes les Catégories')
                            const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              value,
                              style: TextStyle(
                                color: navy,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                size: 18, color: purple),
                        ],
                      ),
                    ),
                  );
                }),
                if (!widget.isVisitor) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.add_circle, color: purple),
                    title: const Text(
                      'Ajouter une catégorie',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, color: navy),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _ouvrirAjouterDocument();
                    },
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(PhotoCategory category) {
    return GestureDetector(
      onTap: () => _navigateToCategory(
        context,
        category.navType,
        category.title,
        _memberId,
        isVisitor: widget.isVisitor,
        canDownload: widget.canDownload,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      color: category.iconColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(category.icon, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: navy,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          category.count,
                          style: const TextStyle(
                              color: grey,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isVisitor)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      tooltip: 'Options',
                      offset: const Offset(-5, 25),
                      elevation: 4,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      icon: const Icon(Icons.more_vert, color: navy, size: 20),
                      onSelected: (value) {
                        if (value == 'renommer') {
                          _renommerCategorie(category.title, category.navType,
                              category.isDefault);
                        } else if (value == 'supprimer') {
                          _supprimerCategorie(
                              category.title, category.isDefault);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'renommer',
                          child: Row(
                            children: [
                              Icon(Icons.drive_file_rename_outline,
                                  size: 18, color: navy),
                              SizedBox(width: 8),
                              Text('Renommer',
                                  style: TextStyle(
                                      color: navy,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'supprimer',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Supprimer',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _buildMiniPhotos(category.title)),
                  const SizedBox(width: 5),
                  Container(
                    constraints: const BoxConstraints(minWidth: 38),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                    decoration: BoxDecoration(
                      color: category.numberColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category.badge,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPhotos(String category) {
    const double size = 26;
    const double overlap = 16;

    final photos =
        _allPhotos.where((p) => p.category == category).take(3).toList();

    return SizedBox(
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(3, (i) {
          final photo = i < photos.length ? photos[i] : null;

          return Positioned(
            left: i * overlap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.5),
                color: Colors.grey.shade200,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: photo != null
                    ? CachedNetworkImage(
                        imageUrl: photo.downloadUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey.shade200),
                        errorWidget: (context, url, error) => const Icon(
                            Icons.photo,
                            size: 14,
                            color: Colors.grey),
                      )
                    : Icon(Icons.photo, size: 14, color: Colors.grey.shade400),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================
// ⭐ BOUTON RETOUR ÉLÉGANT (même design que EditPVisiteur)
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
