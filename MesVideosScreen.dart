// lib/MesVideosScreen.dart - AVEC VISITEUR + TÉLÉCHARGEMENT
// ⭐ CORRIGÉ : Filtre par catégories autorisées par le chef
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'VideoCategoryScreen.dart';
import 'AjouterDocumentVScreen.dart';

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF6046F4);
const Color pink = Color(0xFFE91E9B);
const Color grey = Color(0xFF9E9EAE);
const Color violetBtn = Color(0xFF6C20E8);
const Color selectedGreen = Color(0xFF4CAF50);

// ============================================================
// MODELE CATEGORIE
// ============================================================

class VideoCategory {
  final String title;
  final String navType;
  final int count;
  final Color iconColor;
  final Color numberColor;
  final String badge;
  final IconData icon;
  final bool isDefault;

  const VideoCategory({
    required this.title,
    required this.navType,
    required this.count,
    required this.iconColor,
    required this.numberColor,
    required this.badge,
    required this.icon,
    this.isDefault = false,
  });

  String get countLabel => '$count vidéo${count > 1 ? 's' : ''}';
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
// HELPER BASE64 ROBUSTE
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
    if (mod != 0) raw = raw.padRight(raw.length + (4 - mod), '=');
    final bytes = base64Decode(raw);
    if (bytes.isEmpty) return null;
    return bytes;
  } catch (e) {
    debugPrint('❌ Erreur décodage base64: $e');
    return null;
  }
}

// ============================================================
// MES VIDEOS SCREEN
// ============================================================

class MesVideosScreen extends StatefulWidget {
  final String? memberId;
  final bool isVisitor;
  final bool canDownload;
  final List<String> hiddenCategories;

  // ⭐⭐⭐ NOUVEAU : Catégories AUTORISÉES par le chef ⭐⭐⭐
  // Si non-vide → on affiche UNIQUEMENT ces catégories
  final List<String> authorizedCategories;

  const MesVideosScreen({
    super.key,
    this.memberId,
    this.isVisitor = false,
    this.canDownload = false,
    this.hiddenCategories = const [],
    this.authorizedCategories = const [], // ⭐ NOUVEAU
  });

  @override
  State<MesVideosScreen> createState() => _MesVideosScreenState();
}

class _MesVideosScreenState extends State<MesVideosScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'Toutes les Catégories';
  String _searchQuery = '';

  List<Map<String, dynamic>> _allVideos = [];
  bool _isLoading = true;
  String? _errorMessage;

  bool _isSelecting = false;
  Set<String> _selectedVideoIds = {};

  String _memberName = 'Chargement...';
  String _memberPhoto = '';
  String _memberRole = '';
  String _memberId = '';
  String _memberDocId = '';
  String _memberCollection = '';
  Uint8List? _photoBytes;

  List<Map<String, dynamic>> _customCategories = [];
  List<String> _hiddenDefaultCategories = [];

  StreamSubscription<QuerySnapshot>? _videosSubscription;

  @override
  void initState() {
    super.initState();
    _memberId = widget.memberId ?? '';
    debugPrint('📌 MesVideosScreen - memberId reçu: $_memberId');
    debugPrint('👤 isVisitor: ${widget.isVisitor}');
    debugPrint('📥 canDownload: ${widget.canDownload}');
    debugPrint('🚫 hiddenCategories: ${widget.hiddenCategories}');
    debugPrint('✅ authorizedCategories: ${widget.authorizedCategories}');

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
    _loadVideos();
  }

  @override
  void dispose() {
    _videosSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // CHARGER INFOS MEMBRE
  // ============================================================

  Future<void> _loadMemberInfo() async {
    if (_memberId.isEmpty) return;

    try {
      Map<String, dynamic>? memberData;
      String? collection;
      String? docId;

      try {
        final chefDoc = await FirebaseFirestore.instance
            .collection('Chef de Famille')
            .doc(_memberId)
            .get();
        if (chefDoc.exists) {
          memberData = chefDoc.data();
          collection = 'Chef de Famille';
          docId = chefDoc.id;
        }
      } catch (e) {
        debugPrint('⚠️ Erreur recherche chef: $e');
      }

      if (memberData == null) {
        try {
          final q1 = await FirebaseFirestore.instance
              .collection('Membres Famille')
              .where('userId', isEqualTo: _memberId)
              .limit(1)
              .get();
          if (q1.docs.isNotEmpty) {
            memberData = q1.docs.first.data();
            collection = 'Membres Famille';
            docId = q1.docs.first.id;
          }
        } catch (e) {
          debugPrint('⚠️ Erreur recherche membre: $e');
        }
      }

      if (memberData == null) {
        try {
          final q2 = await FirebaseFirestore.instance
              .collection('Chef de Famille')
              .where('userId', isEqualTo: _memberId)
              .limit(1)
              .get();
          if (q2.docs.isNotEmpty) {
            memberData = q2.docs.first.data();
            collection = 'Chef de Famille';
            docId = q2.docs.first.id;
          }
        } catch (e) {
          debugPrint('⚠️ Erreur recherche chef par userId: $e');
        }
      }

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

        if (mounted) {
          setState(() {
            _memberName = name;
            _memberPhoto = photo;
            _memberRole = role;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('❌ Erreur infos membre: $e');
    }
  }

  // ============================================================
  // CHARGER LES VIDÉOS
  // ============================================================

  void _loadVideos() {
    if (_memberId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    _videosSubscription?.cancel();

    try {
      final query = FirebaseFirestore.instance
          .collection('video')
          .where('memberId', isEqualTo: _memberId);

      _videosSubscription = query.snapshots().listen((snapshot) {
        final List<Map<String, dynamic>> loaded = [];
        for (var doc in snapshot.docs) {
          loaded.add({'id': doc.id, ...doc.data()});
        }

        loaded.sort((a, b) {
          final ta = a['uploadedAt'];
          final tb = b['uploadedAt'];
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
          return tb.toString().compareTo(ta.toString());
        });

        if (mounted) {
          setState(() {
            _allVideos = loaded;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      }, onError: (error) {
        debugPrint('❌ Erreur chargement vidéos: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Erreur de chargement.';
          });
        }
      });
    } catch (e) {
      debugPrint('❌ Exception: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      if (!_isSelecting) _selectedVideoIds = {};
    });
  }

  void _toggleVideoSelection(String id) {
    setState(() {
      if (_selectedVideoIds.contains(id)) {
        _selectedVideoIds.remove(id);
      } else {
        _selectedVideoIds.add(id);
      }
    });
  }

  Map<String, int> _getCategoryCounts() {
    final Map<String, int> counts = {};
    for (final v in _allVideos) {
      final cat = (v['category'] ?? 'Autre').toString();
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }

  // ═══════════════════════════════════════════════════════
  // ⭐⭐⭐ FILTRAGE PAR CATÉGORIES AUTORISÉES ⭐⭐⭐
  // ═══════════════════════════════════════════════════════

  List<_CategoryInfo> _getAllCategoryInfos() {
    final List<_CategoryInfo> infos = [];

    // ⭐ Si le widget reçoit une liste de catégories autorisées NON VIDE,
    //    on affiche UNIQUEMENT ces catégories
    final bool useWhitelist = widget.authorizedCategories.isNotEmpty;

    final Set<String> authorizedLower = useWhitelist
        ? widget.authorizedCategories.map((e) => e.toLowerCase()).toSet()
        : {};

    // ⭐ 1. CATÉGORIES PAR DÉFAUT
    for (final key in _defaultCategoryIcons.keys) {
      final keyLower = key.toLowerCase();

      // Si whitelist : afficher seulement si autorisé
      if (useWhitelist) {
        if (!authorizedLower.contains(keyLower)) continue;
      } else {
        // Sinon : comportement normal (cacher si dans hidden)
        if (_hiddenDefaultCategories.contains(keyLower)) continue;
      }

      infos.add(_CategoryInfo(title: key, navType: key, isDefault: true));
    }

    // ⭐ 2. CATÉGORIES PERSONNALISÉES
    for (final cat in _customCategories) {
      final title = cat['nom'] as String?;
      if (title == null || title.isEmpty) continue;

      final source = cat['source'];
      if (source == 'detail_screen') continue;
      if (source == 'photos_screen') continue;
      if (source != null && source != 'videos_screen') continue;

      final titleLower = title.toLowerCase();

      // Si whitelist : afficher seulement si autorisé
      if (useWhitelist) {
        if (!authorizedLower.contains(titleLower)) continue;
      } else {
        // Sinon : comportement normal (cacher si dans hidden)
        if (_hiddenDefaultCategories.contains(titleLower)) continue;
      }

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

  // ============================================================
  // RENOMMER - BLOQUÉ POUR VISITEUR
  // ============================================================

  Future<void> _renommerVideoCategorie(VideoCategory category) async {
    if (widget.isVisitor) return;

    final ctrl = TextEditingController(text: category.title);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Renommer la catégorie',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final n = ctrl.text.trim();
              if (n.isNotEmpty && n != category.title) {
                Navigator.pop(ctx, n);
              }
            },
            child: const Text(
              'Renommer',
              style: TextStyle(color: purple, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('video')
          .where('memberId', isEqualTo: _memberId)
          .where('category', isEqualTo: category.title)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'category': newName});
      }
      await batch.commit();

      if (_memberDocId.isNotEmpty && _memberCollection.isNotEmpty) {
        final memberRef = FirebaseFirestore.instance
            .collection(_memberCollection)
            .doc(_memberDocId);

        if (category.isDefault) {
          if (!_hiddenDefaultCategories
              .contains(category.title.toLowerCase())) {
            _hiddenDefaultCategories.add(category.title.toLowerCase());
          }

          bool exists = false;
          for (var cat in _customCategories) {
            if (cat['originalDefaultType'] == category.title) {
              cat['nom'] = newName;
              exists = true;
              break;
            }
          }

          if (!exists) {
            final style = _categoryColors[category.title] ?? Colors.blue;
            final icon =
                _defaultCategoryIcons[category.title] ?? Icons.video_library;

            _customCategories.add({
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'nom': newName,
              'originalDefaultType': category.title,
              'iconCodePoint': icon.codePoint,
              'color': style.value,
              'iconColor': style.value,
              'createdAt': DateTime.now().toIso8601String(),
              'source': 'videos_screen',
            });
          }

          await memberRef.update({
            'hiddenDefaultCategories': _hiddenDefaultCategories,
            'categories': _customCategories,
          });
        } else {
          for (int i = 0; i < _customCategories.length; i++) {
            if (_customCategories[i]['nom'] == category.title) {
              _customCategories[i]['nom'] = newName;
              break;
            }
          }
          await memberRef.update({'categories': _customCategories});
        }
      }

      await _loadMemberInfo();
      _loadVideos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Catégorie renommée en "$newName"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur renommage: $e');
    }
  }

  Future<void> _supprimerVideoCategorie(VideoCategory category) async {
    if (widget.isVisitor) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Supprimer la catégorie',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Voulez-vous supprimer "${category.title}" ?\n\n'
          '⚠️ Toutes les vidéos de cette catégorie seront supprimées.',
          style: const TextStyle(color: grey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('video')
          .where('memberId', isEqualTo: _memberId)
          .where('category', isEqualTo: category.title)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (_memberDocId.isNotEmpty && _memberCollection.isNotEmpty) {
        final memberRef = FirebaseFirestore.instance
            .collection(_memberCollection)
            .doc(_memberDocId);

        if (category.isDefault) {
          if (!_hiddenDefaultCategories
              .contains(category.title.toLowerCase())) {
            _hiddenDefaultCategories.add(category.title.toLowerCase());
          }
          await memberRef.update({
            'hiddenDefaultCategories': _hiddenDefaultCategories,
          });
        } else {
          _customCategories.removeWhere((cat) => cat['nom'] == category.title);
          await memberRef.update({'categories': _customCategories});
        }
      }

      await _loadMemberInfo();
      _loadVideos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Catégorie "${category.title}" supprimée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur suppression: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryCounts = _getCategoryCounts();
    final categoryInfos = _getAllCategoryInfos();

    final List<VideoCategory> categories = categoryInfos.map((info) {
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
              : Icons.video_library;
          color = iconColorValue != null
              ? Color(iconColorValue)
              : Colors.blue.shade300;
          badgeColor = iconColorValue != null
              ? Color(iconColorValue).withOpacity(0.7)
              : Colors.grey.shade400;
        } else {
          icon = _defaultCategoryIcons[info.navType] ?? Icons.video_library;
          color = _categoryColors[info.navType] ?? Colors.blue.shade300;
          badgeColor = _badgeColors[info.navType] ?? Colors.grey.shade400;
        }
      }

      return VideoCategory(
        title: info.title,
        navType: info.navType,
        count: count,
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
                                _allVideos.isNotEmpty) ...[
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
              _isSelecting ? '${_selectedVideoIds.length}' : 'Télécharger',
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

  Future<void> _downloadSelected() async {
    if (_selectedVideoIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins une vidéo')),
      );
      return;
    }

    final selected =
        _allVideos.where((v) => _selectedVideoIds.contains(v['id'])).toList();

    int success = 0;
    for (final video in selected) {
      try {
        final url =
            video['downloadUrl'] ?? video['videoUrl'] ?? video['url'] ?? '';
        if (url.toString().isNotEmpty) {
          debugPrint('📥 Téléchargement: $url');
          success++;
        }
      } catch (e) {
        debugPrint('❌ Erreur: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $success vidéo(s) en téléchargement'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _isSelecting = false;
        _selectedVideoIds = {};
      });
    }
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _ElegantBackButton(
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 12),
        const Text(
          'Mes Vidéos',
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

  Widget _buildProfile() {
    return Column(
      children: [
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
        Text(
          _memberName,
          style: const TextStyle(
              color: navy, fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
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
        Text(
          '${_allVideos.length} vidéos • Gérez et organisez vos vidéos par catégorie',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFB7B7C5), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildProfilePhoto() {
    if (_photoBytes != null && _photoBytes!.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          _photoBytes!,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _defaultAvatar(),
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
                hintText: 'Recherche des Vidéos...',
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
      onTap: () async {
        if (widget.isVisitor) return;

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AjouterDocumentVScreen(
              memberId: _memberId,
              memberDocId: _memberDocId,
              memberCollection: _memberCollection,
            ),
          ),
        );
        if (result == true) {
          await _loadMemberInfo();
          _loadVideos();
        }
      },
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
                  final isSelected = value == _selectedCategory;
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
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToCategory(VideoCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCategoryScreen(
          memberId: _memberId,
          categoryName: category.title,
          isVisitor: widget.isVisitor,
          canDownload: widget.canDownload,
        ),
      ),
    ).then((_) {
      _loadVideos();
    });
  }

  Widget _buildCategoryCard(VideoCategory category) {
    return GestureDetector(
      onTap: () => _navigateToCategory(category),
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
                          category.countLabel,
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
                          _renommerVideoCategorie(category);
                        } else if (value == 'supprimer') {
                          _supprimerVideoCategorie(category);
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
                              Text(
                                'Renommer',
                                style: TextStyle(
                                    color: navy,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
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
                              Text(
                                'Supprimer',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
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
                  Expanded(child: _buildMiniVideos(category.title)),
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

  Widget _buildMiniVideos(String category) {
    const double size = 26;
    const double overlap = 16;

    final videos =
        _allVideos.where((v) => v['category'] == category).take(3).toList();

    return SizedBox(
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(3, (i) {
          final v = i < videos.length ? videos[i] : null;

          final thumbUrl = v?['thumbnailUrl'] ??
              v?['thumbnail'] ??
              v?['miniature'] ??
              v?['imageUrl'];

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
                child: thumbUrl != null && thumbUrl.toString().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbUrl.toString(),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.videocam,
                            size: 14, color: Colors.grey),
                      )
                    : const Icon(Icons.videocam, size: 14, color: Colors.grey),
              ),
            ),
          );
        }),
      ),
    );
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
