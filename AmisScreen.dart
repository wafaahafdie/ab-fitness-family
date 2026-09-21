// lib/AmisScreen.dart - AVEC VISITEUR + TÉLÉCHARGEMENT
// ⭐ CORRIGÉ : bouton retour élégant (2 endroits)
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/photos.dart';
import 'services/supabase_service.dart';

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
// FORMATER LA DATE - AVEC INDICATEUR DE TEMPS
// ============================================================

String _formatDateWithIndicator(DateTime date) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime dateOnly = DateTime(date.year, date.month, date.day);

  final int daysDiff = today.difference(dateOnly).inDays;
  final String fullDate = _formatDateFull(date);

  if (daysDiff == 0) return 'Aujourd\'hui • ${_formatTime(date)} ($fullDate)';
  if (daysDiff == 1) return 'Hier • ${_formatTime(date)} ($fullDate)';
  if (daysDiff <= 7) {
    const weekdays = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];
    return '${weekdays[date.weekday - 1]} • ${_formatTime(date)} ($fullDate)';
  }
  if (daysDiff <= 30) {
    final weeks = (daysDiff / 7).floor();
    return weeks == 1
        ? 'Il y a 1 semaine • ${_formatTime(date)} ($fullDate)'
        : 'Il y a $weeks semaines • ${_formatTime(date)} ($fullDate)';
  }
  if (daysDiff <= 60) {
    final months = (daysDiff / 30).floor();
    return months == 1
        ? 'Il y a 1 mois • $fullDate'
        : 'Il y a $months mois • $fullDate';
  }
  if (daysDiff <= 365) {
    final months = (daysDiff / 30).floor();
    return 'Il y a $months mois • $fullDate';
  }
  final years = (daysDiff / 365).floor();
  return years == 1
      ? 'Il y a 1 an • $fullDate'
      : 'Il y a $years ans • $fullDate';
}

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatDateShort(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatDateFull(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatDateForGroup(DateTime date) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime dateOnly = DateTime(date.year, date.month, date.day);

  final int daysDiff = today.difference(dateOnly).inDays;

  if (daysDiff == 0) return 'Aujourd\'hui';
  if (daysDiff == 1) return 'Hier';
  if (daysDiff <= 7) {
    const weekdays = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];
    return weekdays[date.weekday - 1];
  }
  if (daysDiff <= 30) {
    final weeks = (daysDiff / 7).floor();
    return weeks == 1 ? 'Il y a 1 semaine' : 'Il y a $weeks semaines';
  }
  if (daysDiff <= 60) {
    final months = (daysDiff / 30).floor();
    return months == 1 ? 'Il y a 1 mois' : 'Il y a $months mois';
  }
  if (daysDiff <= 365) {
    final months = (daysDiff / 30).floor();
    return 'Il y a $months mois';
  }
  final years = (daysDiff / 365).floor();
  return years == 1 ? 'Il y a 1 an' : 'Il y a $years ans';
}

// ============================================================
// AMIS SCREEN - AVEC VISITEUR + TÉLÉCHARGEMENT
// ============================================================

class AmisScreen extends StatefulWidget {
  final String memberId;
  final String categoryName;

  final bool isVisitor;
  final bool canDownload;

  const AmisScreen({
    super.key,
    required this.memberId,
    this.categoryName = 'Amis',
    this.isVisitor = false,
    this.canDownload = false,
  });

  @override
  State<AmisScreen> createState() => _AmisScreenState();
}

class _AmisScreenState extends State<AmisScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entrance;
  final SupabaseService _storage = SupabaseService();
  List<Photo> _photos = [];
  bool _isLoading = true;
  bool _isImporting = false;

  bool _isSelectingShare = false;
  bool _isSelectingDownload = false;
  Set<String> _selectedPhotos = {};

  String? _errorMessage;

  final List<Map<String, dynamic>> _socialApps = [
    {
      'icon': Icons.facebook,
      'color': Color(0xFF1877F2),
      'name': 'Facebook',
      'scheme': 'fb://',
      'url': 'https://www.facebook.com/sharer/sharer.php?u='
    },
    {
      'icon': Icons.camera_alt,
      'color': Color(0xFFE4405F),
      'name': 'Instagram',
      'scheme': 'instagram://',
      'url': 'https://www.instagram.com/'
    },
    {
      'icon': Icons.message,
      'color': Color(0xFF25D366),
      'name': 'WhatsApp',
      'scheme': 'whatsapp://',
      'url': 'https://wa.me/?text='
    },
    {
      'icon': Icons.send,
      'color': Color(0xFF0088CC),
      'name': 'Telegram',
      'scheme': 'tg://',
      'url': 'https://t.me/share/url?url='
    },
    {
      'icon': Icons.chat,
      'color': Color(0xFF00B2FF),
      'name': 'Messenger',
      'scheme': 'fb-messenger://',
      'url': 'https://www.messenger.com/t/'
    },
    {
      'icon': Icons.copy,
      'color': Color(0xFF6C63FF),
      'name': 'Copier',
      'scheme': '',
      'url': ''
    },
  ];

  @override
  void initState() {
    super.initState();
    debugPrint(
        '📌 AmisScreen - isVisitor: ${widget.isVisitor}, canDownload: ${widget.canDownload}');
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _loadPhotos();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _loadPhotos() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final query = FirebaseFirestore.instance
          .collection('Photos')
          .where('memberId', isEqualTo: widget.memberId)
          .where('category', isEqualTo: widget.categoryName)
          .orderBy('uploadedAt', descending: true);

      query.snapshots().listen((snapshot) {
        final List<Photo> loadedPhotos = [];
        for (var doc in snapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            loadedPhotos.add(Photo.fromFirestore(doc.id, data));
          } catch (e) {
            debugPrint('⚠️ Erreur: $e');
          }
        }

        if (mounted) {
          setState(() {
            _photos = loadedPhotos;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      }, onError: (error) {
        debugPrint('❌ Erreur Firestore: $error');
        String errorMsg = 'Erreur: $error';
        if (error.toString().contains('index')) {
          errorMsg = '⚠️ Index manquant. Cliquez sur le lien dans la console.';
        }
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = errorMsg;
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

  Map<String, List<Photo>> _groupByDate(List<Photo> photos) {
    final Map<String, List<Photo>> groups = {};
    for (final photo in photos) {
      final key = _formatDateForGroup(photo.uploadedAt);
      groups.putIfAbsent(key, () => []).add(photo);
    }

    final sortedKeys = groups.keys.toList();
    sortedKeys.sort((a, b) {
      if (a == 'Aujourd\'hui') return -1;
      if (b == 'Aujourd\'hui') return 1;
      if (a == 'Hier') return -1;
      if (b == 'Hier') return 1;
      if (a.startsWith('Il y a') && b.startsWith('Il y a')) {
        final aNum = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final bNum = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return aNum.compareTo(bNum);
      }
      return a.compareTo(b);
    });

    final sortedMap = <String, List<Photo>>{};
    for (final key in sortedKeys) {
      sortedMap[key] = groups[key]!;
    }
    return sortedMap;
  }

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

      if (bytes == null || bytes.isEmpty) throw Exception('Fichier invalide');

      final safeName = _sanitizeFileName(pickedFile.name);
      final storagePath =
          '${widget.memberId}/${widget.categoryName.toLowerCase()}/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final downloadUrl = await _storage.uploadFile(
        bucket: 'media_files',
        path: storagePath,
        bytes: bytes,
        contentType: 'image/jpeg',
      );

      if (downloadUrl.isEmpty) throw Exception('URL vide');

      await FirebaseFirestore.instance.collection('Photos').add({
        'name': pickedFile.name,
        'category': widget.categoryName,
        'memberId': widget.memberId,
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
          SnackBar(content: Text('❌ Erreur: $e')),
        );
      }
    }
  }

  Future<void> _supprimerPhoto(Photo photo) async {
    if (widget.isVisitor) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la photo'),
        content: Text('Voulez-vous supprimer "${photo.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _storage.deleteFile(bucket: 'media_files', path: photo.storagePath);
      await FirebaseFirestore.instance
          .collection('Photos')
          .doc(photo.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Photo supprimée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur suppression: $e');
    }
  }

  void _partagerPhoto(Photo photo) {
    Share.share('📸 ${photo.name}\n\n${photo.downloadUrl}');
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^\w\-. ]'), '_').replaceAll(' ', '_');
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

  Animation<double> _staggered(int order) {
    final start = (order * 0.045).clamp(0.0, 0.6);
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
  }

  void _openPhoto(Photo photo) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withAlpha(230),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, __, ___) => _PhotoViewer(
          photo: photo,
          onShare: () => _partagerPhoto(photo),
          onDelete: widget.isVisitor ? () {} : () => _supprimerPhoto(photo),
          isVisitor: widget.isVisitor,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      if (widget.isVisitor) {
        _isSelectingDownload = !_isSelectingDownload;
        if (!_isSelectingDownload) _selectedPhotos = {};
      } else {
        _isSelectingShare = !_isSelectingShare;
        if (!_isSelectingShare) _selectedPhotos = {};
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedPhotos.contains(id)) {
        _selectedPhotos.remove(id);
      } else {
        _selectedPhotos.add(id);
      }
    });
  }

  Future<void> _downloadSelected() async {
    if (_selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins une photo')),
      );
      return;
    }

    final selected =
        _photos.where((p) => _selectedPhotos.contains(p.id)).toList();

    int success = 0;
    for (final photo in selected) {
      try {
        final uri = Uri.parse(photo.downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          success++;
          await Future.delayed(const Duration(milliseconds: 300));
        }
      } catch (e) {
        debugPrint('❌ Erreur téléchargement: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $success photo(s) téléchargée(s)'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _isSelectingDownload = false;
        _selectedPhotos = {};
      });
    }
  }

  void _confirmerPartage() {
    if (_selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez au moins une photo'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() => _isSelectingShare = false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Partager sur',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: navy),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        alignment: WrapAlignment.center,
                        children: _socialApps.map((app) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              if (app['name'] == 'Copier') {
                                _copyLinks();
                              } else {
                                _shareOnSocial(app);
                              }
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: app['color'],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(app['icon'],
                                      color: Colors.white, size: 28),
                                ),
                                const SizedBox(height: 6),
                                Text(app['name'],
                                    style: const TextStyle(
                                        fontSize: 10, color: navy)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _copyLinks() async {
    final String links = _photos
        .where((p) => _selectedPhotos.contains(p.id))
        .map((p) => p.downloadUrl)
        .join('\n');

    await Clipboard.setData(ClipboardData(text: links));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Liens copiés'),
          backgroundColor: Colors.green,
        ),
      );
    }

    setState(() => _selectedPhotos = {});
  }

  void _shareOnSocial(Map<String, dynamic> app) async {
    final String message = '📸 Mes photos - ${widget.categoryName}\n\n';
    final List<String> selectedUrls = _photos
        .where((p) => _selectedPhotos.contains(p.id))
        .map((p) => p.downloadUrl)
        .toList();

    if (selectedUrls.isEmpty) return;

    final String shareText = '$message${selectedUrls.join('\n\n')}';

    try {
      await Share.share(shareText);
    } catch (e) {
      debugPrint('❌ Erreur partage: $e');
    }

    setState(() => _selectedPhotos = {});
  }

  // ============================================================
  // ⭐ APPBAR RÉUTILISABLE avec bouton retour élégant
  // ============================================================

  PreferredSizeWidget _buildAppBar({List<Widget>? actions}) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: const BoxDecoration(color: Colors.white),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              _ElegantBackButton(
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.categoryName,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actions != null) ...actions,
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final groupedPhotos = _groupByDate(_photos);
    int order = 0;

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(), // ⭐ Bouton retour élégant
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: Colors.orange.shade300),
                const SizedBox(height: 16),
                Text(_errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadPhotos,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: purple, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: FadeTransition(
          opacity: _staggered(order++),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_photos.length} photos • ${groupedPhotos.keys.length} dates',
                  style: const TextStyle(
                      color: grey, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (_isSelectingShare || _isSelectingDownload)
                  TextButton(
                    onPressed: _toggleSelectionMode,
                    child: const Text('Annuler',
                        style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
        ),
      ),
    ];

    for (var d = 0; d < groupedPhotos.keys.length; d++) {
      final date = groupedPhotos.keys.toList()[d];
      final photos = groupedPhotos[date]!;
      final isFirstDay = d == 0;

      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _DateHeaderDelegate(
            label: date,
            count: photos.length,
            animation: _staggered(order++),
          ),
        ),
      );

      final itemCount =
          photos.length + (isFirstDay && !widget.isVisitor ? 1 : 0);
      final baseOrder = order;
      order += itemCount;

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final anim = _staggered(baseOrder + index);

                if (isFirstDay && !widget.isVisitor && index == photos.length) {
                  return _AnimatedIn(
                    animation: anim,
                    child: _AddTile(onTap: _importerPhoto),
                  );
                }

                final photo = photos[index];
                final isSelected = _selectedPhotos.contains(photo.id);

                return _AnimatedIn(
                  animation: anim,
                  child: _PhotoTile(
                    photo: photo,
                    onTap: () {
                      if (_isSelectingShare || _isSelectingDownload) {
                        _toggleSelection(photo.id);
                      } else {
                        _openPhoto(photo);
                      }
                    },
                    isSelecting: _isSelectingShare || _isSelectingDownload,
                    isSelected: isSelected,
                  ),
                );
              },
              childCount: itemCount,
            ),
          ),
        ),
      );
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 12)));

    return Scaffold(
      backgroundColor: Colors.white,
      // ⭐ APPBAR avec bouton retour élégant + actions
      appBar: _buildAppBar(
        actions: [
          // ⭐ Visiteur : icône téléchargement
          if (widget.isVisitor && widget.canDownload && _photos.isNotEmpty)
            IconButton(
              icon: Icon(
                _isSelectingDownload
                    ? Icons.download_rounded
                    : Icons.check_circle_outline,
                color: _isSelectingDownload ? Colors.green : purple,
              ),
              onPressed: _isSelectingDownload
                  ? _downloadSelected
                  : _toggleSelectionMode,
              tooltip: _isSelectingDownload ? 'Télécharger' : 'Sélectionner',
            ),
          // ⭐ Propriétaire : bouton partage
          if (!widget.isVisitor && _photos.isNotEmpty && !_isSelectingShare)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded, color: purple),
              onPressed: _toggleSelectionMode,
            ),
          if (!widget.isVisitor && _isSelectingShare)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: _confirmerPartage,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: purple))
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: groupedPhotos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline,
                                    size: 60, color: grey.withOpacity(0.5)),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucune photo dans ${widget.categoryName}',
                                  style: const TextStyle(
                                      color: grey,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                                if (!widget.isVisitor) ...[
                                  const SizedBox(height: 8),
                                  const Text('Appuyez sur le + pour importer',
                                      style:
                                          TextStyle(color: grey, fontSize: 12)),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _importerPhoto,
                                    icon: const Icon(Icons.add_photo_alternate),
                                    label: const Text('Importer une photo'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: purple,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: slivers,
                          ),
                  ),
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _entrance,
                      curve:
                          const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
                    )),
                    child: FadeTransition(
                      opacity: _staggered(2),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: widget.isVisitor
                            ? const SizedBox.shrink()
                            : Row(
                                children: [
                                  _PulsingCircleButton(
                                    color: violetBtn,
                                    fallback: Icons.add,
                                    iconBuilder: (size, color) => _asset(
                                      'po',
                                      size: size,
                                      color: color,
                                      fallback: Icons.add,
                                    ),
                                    onTap: _importerPhoto,
                                  ),
                                  const SizedBox(width: 12),
                                  if (_photos.isNotEmpty)
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: _toggleSelectionMode,
                                        child: Container(
                                          height: 48,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFFF6B9D),
                                                Color(0xFFFF8A9D)
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(25),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _isSelectingShare
                                                    ? Icons.close
                                                    : Icons.share,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _isSelectingShare
                                                    ? 'Annuler'
                                                    : 'Partager',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
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

// ============================================================
// DATE HEADER DELEGATE
// ============================================================

class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DateHeaderDelegate({
    required this.label,
    required this.count,
    required this.animation,
  });

  final String label;
  final int count;
  final Animation<double> animation;

  @override
  double get minExtent => 54;

  @override
  double get maxExtent => 54;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return FadeTransition(
      opacity: animation,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration:
                  const BoxDecoration(color: purple, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: navy, fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: purple.withAlpha(26),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color: purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate oldDelegate) {
    return oldDelegate.label != label ||
        oldDelegate.count != count ||
        oldDelegate.animation != animation;
  }
}

// ============================================================
// ANIMATED IN
// ============================================================

class _AnimatedIn extends StatelessWidget {
  const _AnimatedIn({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(animation),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(animation),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================
// PRESS SCALE
// ============================================================

class _PressScale extends StatefulWidget {
  const _PressScale({
    required this.child,
    required this.onTap,
    this.pressedScale = 0.94,
  });

  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ============================================================
// PHOTO TILE
// ============================================================

class _PhotoTile extends StatelessWidget {
  final Photo photo;
  final VoidCallback onTap;
  final bool isSelecting;
  final bool isSelected;

  const _PhotoTile({
    required this.photo,
    required this.onTap,
    this.isSelecting = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final String timeLabel = _formatTime(photo.uploadedAt);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Hero(
            tag: photo.id,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: photo.downloadUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, size: 30),
                    ),
                  ),
                  if (photo.isVideo)
                    Container(
                      color: Colors.black.withAlpha(77),
                      child: const Center(
                        child: Icon(Icons.play_circle_filled,
                            color: Colors.white, size: 30),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(timeLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  if (isSelecting)
                    Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.green.withOpacity(0.3)
                            : Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? selectedGreen : Colors.white54,
                            border: Border.all(
                              color: isSelected ? selectedGreen : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 16)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ADD TILE
// ============================================================

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: violetBtn.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: violetBtn.withAlpha(90), width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: violetBtn, size: 22),
            SizedBox(height: 4),
            Text('Ajouter',
                style: TextStyle(
                    color: violetBtn,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PULSING CIRCLE BUTTON
// ============================================================

class _PulsingCircleButton extends StatefulWidget {
  const _PulsingCircleButton({
    required this.color,
    required this.fallback,
    required this.iconBuilder,
    required this.onTap,
    this.size = 48,
  });

  final Color color;
  final IconData fallback;
  final Widget Function(double size, Color color) iconBuilder;
  final VoidCallback onTap;
  final double size;

  @override
  State<_PulsingCircleButton> createState() => _PulsingCircleButtonState();
}

class _PulsingCircleButtonState extends State<_PulsingCircleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: widget.onTap,
      pressedScale: 0.9,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_pulse.value);
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withAlpha(90),
                  blurRadius: 10 + 10 * t,
                  spreadRadius: 1 * t,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Center(child: widget.iconBuilder(22, Colors.white)),
      ),
    );
  }
}

// ============================================================
// PHOTO VIEWER
// ============================================================

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({
    required this.photo,
    required this.onShare,
    required this.onDelete,
    this.isVisitor = false,
  });

  final Photo photo;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final bool isVisitor;

  @override
  Widget build(BuildContext context) {
    final String dateInfo = _formatDateWithIndicator(photo.uploadedAt);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.shrink(),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: photo.id,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: photo.downloadUrl,
                        fit: BoxFit.contain,
                        height: 300,
                        width: 300,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade800,
                          height: 300,
                          width: 300,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade800,
                          height: 300,
                          width: 300,
                          child: const Icon(Icons.broken_image,
                              color: Colors.white, size: 50),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(dateInfo,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(photo.name,
                      style: TextStyle(
                          color: Colors.white.withAlpha(200), fontSize: 13)),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: Row(
              children: [
                if (!isVisitor)
                  _PressScale(
                    onTap: onShare,
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha(64)),
                      ),
                      child: const Icon(Icons.share,
                          color: Colors.white, size: 20),
                    ),
                  ),
                if (!isVisitor)
                  _PressScale(
                    onTap: onDelete,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(60),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withAlpha(100)),
                      ),
                      child: const Icon(Icons.delete,
                          color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
