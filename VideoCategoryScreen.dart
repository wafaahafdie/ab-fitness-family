// lib/VideoCategoryScreen.dart - AVEC VISITEUR + TÉLÉCHARGEMENT
// ⭐ CORRIGÉ : Import vidéo depuis téléphone (lecture depuis path si bytes null)
// ⭐ CORRIGÉ : Compression automatique pour grosses vidéos
// ⭐ MODIFIÉ : Accepte TOUS les formats vidéo (mp4, mov, avi, mkv, 3gp, wmv, etc.)
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_compress/video_compress.dart';
import 'services/supabase_service.dart';

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF6046F4);
const Color pink = Color(0xFFE91E9B);
const Color grey = Color(0xFF9E9EAE);
const Color violetBtn = Color(0xFF6C20E8);
const Color selectedGreen = Color(0xFF4CAF50);

const int kMaxUploadSizeBytes = 50 * 1024 * 1024;

// ⭐ MODIFIÉ : Liste étendue de toutes les extensions vidéo courantes
const List<String> kVideoExtensions = [
  'mp4',
  'mov',
  'avi',
  'mkv',
  'webm',
  '3gp',
  '3g2',
  'wmv',
  'flv',
  'ts',
  'm4v',
  'mpg',
  'mpeg',
  'ogv',
  'mts',
  'm2ts',
  'hevc',
  'rm',
  'rmvb',
  'asf',
  'vob',
  'divx',
];

// ============================================================
// HELPERS DATE
// ============================================================

String _formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _formatDateShort(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString().substring(2);
  return '$day.$month.$year';
}

String _formatDateTimeShort(DateTime date) {
  return '${_formatDateShort(date)} à ${_formatTime(date)}';
}

String _formatDateForGroup(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dateOnly = DateTime(date.year, date.month, date.day);
  final diff = today.difference(dateOnly).inDays;
  final dateShort = _formatDateShort(date);

  if (diff == 0) return 'Aujourd\'hui • $dateShort';
  if (diff == 1) return 'Hier • $dateShort';
  if (diff <= 7) {
    const weekdays = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];
    return '${weekdays[date.weekday - 1]} • $dateShort';
  }
  if (diff <= 30) {
    final w = (diff / 7).floor();
    return w == 1
        ? 'Il y a 1 semaine • $dateShort'
        : 'Il y a $w semaines • $dateShort';
  }
  if (diff <= 365) {
    final m = (diff / 30).floor();
    return 'Il y a $m mois • $dateShort';
  }
  final y = (diff / 365).floor();
  return y == 1 ? 'Il y a 1 an • $dateShort' : 'Il y a $y ans • $dateShort';
}

String _formatDuration(int? seconds) {
  if (seconds == null) return '';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ============================================================
// MODELE VIDEO
// ============================================================

class VideoItem {
  final String id;
  final String name;
  final String downloadUrl;
  final String? thumbnailUrl;
  final String category;
  final String memberId;
  final int sizeBytes;
  final int? duration;
  final DateTime uploadedAt;

  VideoItem({
    required this.id,
    required this.name,
    required this.downloadUrl,
    this.thumbnailUrl,
    required this.category,
    required this.memberId,
    required this.sizeBytes,
    this.duration,
    required this.uploadedAt,
  });

  factory VideoItem.fromDoc(String id, Map<String, dynamic> data) {
    return VideoItem(
      id: id,
      name: data['name'] ?? '',
      downloadUrl: data['downloadUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      category: data['category'] ?? '',
      memberId: data['memberId'] ?? '',
      sizeBytes: _toInt(data['sizeBytes']),
      duration: _toIntOrNull(data['duration']),
      uploadedAt: _toDate(data['uploadedAt']),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime _toDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v.runtimeType.toString() == 'Timestamp') return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}

// ============================================================
// VIDEO CATEGORY SCREEN - AVEC VISITEUR + TÉLÉCHARGEMENT
// ============================================================

class VideoCategoryScreen extends StatefulWidget {
  final String memberId;
  final String categoryName;

  final bool isVisitor;
  final bool canDownload;

  const VideoCategoryScreen({
    super.key,
    required this.memberId,
    required this.categoryName,
    this.isVisitor = false,
    this.canDownload = false,
  });

  @override
  State<VideoCategoryScreen> createState() => _VideoCategoryScreenState();
}

class _VideoCategoryScreenState extends State<VideoCategoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entrance;
  final SupabaseService _storage = SupabaseService();
  List<VideoItem> _videos = [];
  bool _isLoading = true;
  bool _isImporting = false;

  bool _isSelectingShare = false;
  bool _isSelectingDownload = false;
  Set<String> _selected = {};

  String? _errorMessage;

  StreamSubscription<QuerySnapshot>? _videosSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '📌 VideoCategoryScreen - isVisitor: ${widget.isVisitor}, canDownload: ${widget.canDownload}');
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _loadVideos();
  }

  @override
  void dispose() {
    _videosSubscription?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  // ============================================================
  // CHARGER VIDÉOS
  // ============================================================

  void _loadVideos() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _videosSubscription?.cancel();

    try {
      final query = FirebaseFirestore.instance
          .collection('video')
          .where('memberId', isEqualTo: widget.memberId);

      _videosSubscription = query.snapshots().listen((snapshot) {
        final List<VideoItem> loaded = [];
        for (var doc in snapshot.docs) {
          try {
            final v = VideoItem.fromDoc(doc.id, doc.data());
            final catFirestore = v.category.toLowerCase().trim();
            final catWidget = widget.categoryName.toLowerCase().trim();
            if (catFirestore == catWidget) {
              loaded.add(v);
            }
          } catch (e) {
            debugPrint('⚠️ Erreur doc: $e');
          }
        }

        loaded.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

        if (mounted) {
          setState(() {
            _videos = loaded;
            _isLoading = false;
          });
        }
      }, onError: (e) {
        debugPrint('❌ Erreur load videos: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Erreur: $e';
          });
        }
      });
    } catch (e) {
      debugPrint('❌ Exception load videos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur: $e';
        });
      }
    }
  }

  Map<String, List<VideoItem>> _groupByDate() {
    final Map<String, List<VideoItem>> groups = {};
    for (final v in _videos) {
      final key = _formatDateForGroup(v.uploadedAt);
      groups.putIfAbsent(key, () => []).add(v);
    }

    final sorted = groups.keys.toList()
      ..sort((a, b) {
        if (a.contains('Aujourd\'hui')) return -1;
        if (b.contains('Aujourd\'hui')) return 1;
        if (a.contains('Hier')) return -1;
        if (b.contains('Hier')) return 1;
        return a.compareTo(b);
      });

    return {for (final k in sorted) k: groups[k]!};
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ============================================================
  // ⭐⭐⭐ IMPORT VIDÉO - TOUS FORMATS ACCEPTÉS ⭐⭐⭐
  // ============================================================

  Future<void> _importerVideo() async {
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
      // ⭐ MODIFIÉ : FileType.video = TOUTES les vidéos du téléphone
      // (mp4, mov, avi, mkv, 3gp, wmv, flv, m4v, mts, etc.)
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.video, // ✅ tous les formats vidéo natifs
          allowMultiple: false,
          withData: kIsWeb, // ⭐ Data uniquement sur Web
        );
      } catch (e) {
        debugPrint('⚠️ FileType.video échoué, fallback FileType.any: $e');
        // ⭐ Fallback : si le sélecteur vidéo plante, on accepte TOUT
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
          withData: kIsWeb,
        );
      }

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      final pickedFile = result.files.single;
      final filePath = pickedFile.path;
      Uint8List? bytes = pickedFile.bytes;

      // ⭐ Vérification extension (tolérante)
      final ext = (pickedFile.extension ?? '').toLowerCase();
      if (ext.isNotEmpty && !kVideoExtensions.contains(ext)) {
        debugPrint('⚠️ Extension "$ext" inhabituelle, on continue quand même');
      }

      // ⭐ Sur mobile : lire depuis le chemin
      if (bytes == null && filePath != null && filePath.isNotEmpty) {
        debugPrint('📂 Lecture vidéo depuis: $filePath');
        try {
          final f = File(filePath);
          bytes = await f.readAsBytes();
          debugPrint('✅ Vidéo lue: ${bytes.length} octets');
        } catch (e) {
          debugPrint('❌ Impossible de lire le path: $e');
          throw Exception('Impossible de lire la vidéo sélectionnée.');
        }
      }

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Fichier vidéo vide ou invalide');
      }

      final originalSize = bytes.length;
      debugPrint(
          '📹 Taille originale: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} Mo');

      // ⭐ Compression si nécessaire (> 50 Mo)
      final needCompression = originalSize > kMaxUploadSizeBytes;

      if (needCompression && !kIsWeb && filePath != null) {
        debugPrint('🗜️ Compression nécessaire (> 50 Mo)...');
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 10),
                  Text('Compression de la vidéo en cours...'),
                ],
              ),
              duration: Duration(minutes: 5),
              backgroundColor: Colors.orange,
            ),
          );
        }

        try {
          final compressedInfo = await VideoCompress.compressVideo(
            filePath,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
            includeAudio: true,
          );

          if (compressedInfo == null || compressedInfo.file == null) {
            throw Exception('Échec de la compression');
          }

          bytes = await compressedInfo.file!.readAsBytes();
          debugPrint(
              '✅ Vidéo compressée: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} Mo');
        } catch (compErr) {
          debugPrint('❌ Erreur compression: $compErr');
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
          throw Exception('Compression impossible: $compErr');
        }
      } else if (needCompression && kIsWeb) {
        throw Exception(
          'Vidéo trop grosse (${(originalSize / 1024 / 1024).toStringAsFixed(1)} Mo). '
          'Limite : 50 Mo sur Web.',
        );
      }

      if (bytes.length > kMaxUploadSizeBytes) {
        throw Exception(
          'Vidéo toujours trop grosse '
          '(${(bytes.length / 1024 / 1024).toStringAsFixed(1)} Mo). Limite : 50 Mo.',
        );
      }

      // ⭐ Upload avec indicateur
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 10),
                Text('Upload en cours...'),
              ],
            ),
            duration: Duration(minutes: 10),
            backgroundColor: Colors.blue,
          ),
        );
      }

      final safeName = _sanitizeFileName(pickedFile.name);

      // ⭐ MODIFIÉ : contentType dynamique selon l'extension
      String contentType = 'video/mp4';
      switch (ext) {
        case 'mov':
          contentType = 'video/quicktime';
          break;
        case 'avi':
          contentType = 'video/x-msvideo';
          break;
        case 'mkv':
          contentType = 'video/x-matroska';
          break;
        case 'webm':
          contentType = 'video/webm';
          break;
        case '3gp':
          contentType = 'video/3gpp';
          break;
        case 'wmv':
          contentType = 'video/x-ms-wmv';
          break;
        case 'flv':
          contentType = 'video/x-flv';
          break;
        case 'm4v':
          contentType = 'video/x-m4v';
          break;
        case 'mpg':
        case 'mpeg':
          contentType = 'video/mpeg';
          break;
        case 'ts':
          contentType = 'video/mp2t';
          break;
        default:
          contentType = 'video/mp4';
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final storagePath =
          '${widget.memberId}/${widget.categoryName.toLowerCase()}/${ts}_$safeName';

      final downloadUrl = await _storage.uploadFile(
        bucket: 'media_files',
        path: 'videos/$storagePath',
        bytes: bytes,
        contentType: contentType, // ⭐ dynamique
      );

      if (downloadUrl.isEmpty) throw Exception('URL de téléchargement vide');

      // ⭐ Miniature + durée
      String? thumbUrl;
      int? duration;

      if (!kIsWeb && filePath != null) {
        try {
          final ctrl = VideoPlayerController.file(File(filePath));
          await ctrl.initialize();
          duration = ctrl.value.duration.inSeconds;
          await ctrl.dispose();

          final thumbBytes = await VideoThumbnail.thumbnailData(
            video: filePath,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 400,
            quality: 70,
          );

          if (thumbBytes != null) {
            final thumbPath = 'thumbnails/$storagePath.jpg';
            thumbUrl = await _storage.uploadFile(
              bucket: 'media_files',
              path: thumbPath,
              bytes: thumbBytes,
              contentType: 'image/jpeg',
            );
          }
        } catch (e) {
          debugPrint('⚠️ Miniature ignorée: $e');
        }
      }

      // ⭐ Sauvegarde Firestore
      await FirebaseFirestore.instance.collection('video').add({
        'name': pickedFile.name,
        'category': widget.categoryName,
        'memberId': widget.memberId,
        'storagePath': 'videos/$storagePath',
        'downloadUrl': downloadUrl,
        if (thumbUrl != null) 'thumbnailUrl': thumbUrl,
        if (duration != null) 'duration': duration,
        'uploadedAt': FieldValue.serverTimestamp(),
        'sizeBytes': bytes.length,
        'originalSizeBytes': originalSize,
        'wasCompressed': needCompression,
        'extension': ext, // ⭐ NOUVEAU : trace l'extension
        'type': 'video',
      });

      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Vidéo importée avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur import: $e');
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ============================================================
  // SUPPRIMER - BLOQUÉ POUR VISITEUR
  // ============================================================

  Future<void> _supprimerVideo(VideoItem video) async {
    if (widget.isVisitor) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la vidéo'),
        content: Text('Voulez-vous supprimer "${video.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _storage.deleteFile(
        bucket: 'media_files',
        path: video.downloadUrl.isNotEmpty
            ? Uri.parse(video.downloadUrl).path.split('/media_files/').last
            : '',
      );
      if (video.thumbnailUrl != null) {
        try {
          await _storage.deleteFile(
            bucket: 'media_files',
            path:
                Uri.parse(video.thumbnailUrl!).path.split('/media_files/').last,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('⚠️ Erreur suppression storage: $e');
    }

    try {
      await FirebaseFirestore.instance
          .collection('video')
          .doc(video.id)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Vidéo supprimée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur suppression firestore: $e');
    }
  }

  // ============================================================
  // RENOMMER - BLOQUÉ POUR VISITEUR
  // ============================================================

  Future<void> _renommerVideo(VideoItem video) async {
    if (widget.isVisitor) return;

    final ctrl = TextEditingController(text: video.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Renommer la vidéo'),
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
              if (n.isNotEmpty && n != video.name) Navigator.pop(ctx, n);
            },
            child: const Text('Renommer',
                style: TextStyle(color: purple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('video')
          .doc(video.id)
          .update({'name': newName});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Vidéo renommée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur renommage: $e');
    }
  }

  void _partagerVideo(VideoItem v) {
    Share.share('🎬 ${v.name}\n\n${v.downloadUrl}');
  }

  void _ouvrirVideo(VideoItem v) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          url: v.downloadUrl,
          title: v.name,
        ),
      ),
    );
  }

  // ============================================================
  // ⭐ TÉLÉCHARGER (visiteur)
  // ============================================================

  Future<void> _downloadSelected() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins une vidéo')),
      );
      return;
    }

    final selectedVideos =
        _videos.where((v) => _selected.contains(v.id)).toList();
    int success = 0;

    for (final v in selectedVideos) {
      try {
        final uri = Uri.parse(v.downloadUrl);
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
          content: Text('✅ $success vidéo(s) téléchargée(s)'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _isSelectingDownload = false;
        _selected = {};
      });
    }
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
      errorBuilder: (_, __, ___) =>
          Icon(fallback ?? Icons.circle, size: size, color: color ?? navy),
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate();
    int order = 0;

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
                  '${_videos.length} vidéo${_videos.length > 1 ? 's' : ''} • ${grouped.keys.length} dates',
                  style: const TextStyle(
                    color: grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_isSelectingShare || _isSelectingDownload)
                  TextButton(
                    onPressed: () => setState(() {
                      _isSelectingShare = false;
                      _isSelectingDownload = false;
                      _selected = {};
                    }),
                    child: const Text('Annuler',
                        style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
        ),
      ),
    ];

    for (var d = 0; d < grouped.keys.length; d++) {
      final date = grouped.keys.toList()[d];
      final videos = grouped[date]!;
      final isFirstDay = d == 0;

      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _DateHeaderDelegate(
            label: date,
            count: videos.length,
            animation: _staggered(order++),
          ),
        ),
      );

      final itemCount =
          videos.length + (isFirstDay && !widget.isVisitor ? 1 : 0);
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

                if (isFirstDay && !widget.isVisitor && index == videos.length) {
                  return _AnimatedIn(
                    animation: anim,
                    child: _AddTile(onTap: _importerVideo),
                  );
                }

                final v = videos[index];
                final isSelected = _selected.contains(v.id);

                return _AnimatedIn(
                  animation: anim,
                  child: _VideoTile(
                    video: v,
                    onTap: () {
                      if (_isSelectingShare || _isSelectingDownload) {
                        setState(() {
                          if (isSelected) {
                            _selected.remove(v.id);
                          } else {
                            _selected.add(v.id);
                          }
                        });
                      } else {
                        _ouvrirVideo(v);
                      }
                    },
                    onLongPress:
                        widget.isVisitor ? null : () => _showVideoMenu(v),
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: _ElegantBackButton(
              onTap: () => Navigator.maybePop(context),
            ),
          ),
        ),
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            color: navy,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (widget.isVisitor && widget.canDownload && _videos.isNotEmpty)
            IconButton(
              icon: Icon(
                _isSelectingDownload
                    ? Icons.download_rounded
                    : Icons.check_circle_outline,
                color: _isSelectingDownload ? Colors.green : purple,
              ),
              onPressed: _isSelectingDownload
                  ? _downloadSelected
                  : () => setState(() => _isSelectingDownload = true),
              tooltip: _isSelectingDownload ? 'Télécharger' : 'Sélectionner',
            ),
          if (!widget.isVisitor && _videos.isNotEmpty && !_isSelectingShare)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded, color: purple),
              onPressed: () => setState(() => _isSelectingShare = true),
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
                    child: grouped.isEmpty
                        ? _buildEmptyState()
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
                                    onTap: _importerVideo,
                                  ),
                                  const SizedBox(width: 12),
                                  if (_videos.isNotEmpty)
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(
                                            () => _isSelectingShare = true),
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
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFFF6B9D)
                                                    .withOpacity(0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.share,
                                                  color: Colors.white,
                                                  size: 22),
                                              SizedBox(width: 8),
                                              Text(
                                                'Partager',
                                                style: TextStyle(
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined,
              size: 60, color: grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Aucune vidéo dans ${widget.categoryName}',
            style: const TextStyle(
                color: grey, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (!widget.isVisitor) ...[
            const SizedBox(height: 8),
            const Text('Appuyez sur le + pour importer',
                style: TextStyle(color: grey, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _importerVideo,
              icon: const Icon(Icons.video_call),
              label: const Text('Importer une vidéo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showVideoMenu(VideoItem v) {
    if (widget.isVisitor) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE3E3EA),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.play_arrow, color: purple),
              title: const Text('Lire la vidéo'),
              onTap: () {
                Navigator.pop(ctx);
                _ouvrirVideo(v);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline, color: navy),
              title: const Text('Renommer'),
              onTap: () {
                Navigator.pop(ctx);
                _renommerVideo(v);
              },
            ),
            if (!widget.isVisitor)
              ListTile(
                leading: const Icon(Icons.share, color: purple),
                title: const Text('Partager'),
                onTap: () {
                  Navigator.pop(ctx);
                  _partagerVideo(v);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _supprimerVideo(v);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmerPartage() {
    if (_selected.isEmpty) return;
    final links = _videos
        .where((v) => _selected.contains(v.id))
        .map((v) => v.downloadUrl)
        .join('\n');
    Share.share('🎬 Mes vidéos - ${widget.categoryName}\n\n$links');
    setState(() {
      _isSelectingShare = false;
      _selected = {};
    });
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

// ============================================================
// DATE HEADER
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
  Widget build(BuildContext ctx, double _, bool __) {
    return FadeTransition(
      opacity: animation,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: navy, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
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
  bool shouldRebuild(covariant _DateHeaderDelegate old) =>
      old.label != label || old.count != count;
}

// ============================================================
// ANIMATED IN
// ============================================================

class _AnimatedIn extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _AnimatedIn({required this.animation, required this.child});

  @override
  Widget build(BuildContext ctx) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
            .animate(animation),
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
  final Widget child;
  final VoidCallback onTap;
  const _PressScale({required this.child, required this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext ctx) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

// ============================================================
// TUILE VIDÉO
// ============================================================

class _VideoTile extends StatelessWidget {
  final VideoItem video;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelecting;
  final bool isSelected;

  const _VideoTile({
    required this.video,
    required this.onTap,
    this.onLongPress,
    this.isSelecting = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext ctx) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (video.thumbnailUrl != null &&
                    video.thumbnailUrl!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: video.thumbnailUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.black87),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.black87,
                      child: const Icon(Icons.videocam,
                          color: Colors.white, size: 30),
                    ),
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6046F4), Color(0xFF8E00C8)],
                      ),
                    ),
                    child: const Center(
                      child:
                          Icon(Icons.videocam, color: Colors.white, size: 30),
                    ),
                  ),
                Container(
                  color: Colors.black.withAlpha(50),
                  child: const Center(
                    child: Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 34),
                  ),
                ),
                if (video.duration != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        _formatDuration(video.duration),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDateTimeShort(video.uploadedAt),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600),
                    ),
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
                              width: 2),
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
        ],
      ),
    );
  }
}

// ============================================================
// ADD TILE
// ============================================================

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext ctx) {
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
  final Color color;
  final VoidCallback onTap;
  final double size;
  const _PulsingCircleButton({
    required this.color,
    required this.onTap,
    this.size = 48,
  });

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
  Widget build(BuildContext ctx) {
    return _PressScale(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
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
        child: const Icon(Icons.add, color: Colors.white, size: 22),
      ),
    );
  }
}

// ============================================================
// LECTEUR VIDÉO COMPLET
// ============================================================

class VideoPlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  const VideoPlayerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  double _volume = 1.0;
  bool _isMuted = false;
  bool _isLooping = false;
  String? _errorMessage;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..setLooping(_isLooping)
        ..setVolume(_volume);

      await _controller.initialize();
      _controller.addListener(_onVideoUpdate);

      if (mounted) {
        setState(() => _isInitialized = true);
        _controller.play();
        _startHideTimer();
      }
    } catch (e) {
      debugPrint('❌ Erreur init vidéo: $e');
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  void _onVideoUpdate() {
    if (mounted) setState(() {});
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller.removeListener(_onVideoUpdate);
    _controller.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _seekRelative(int seconds) {
    final pos = _controller.value.position + Duration(seconds: seconds);
    final clamped = pos < Duration.zero
        ? Duration.zero
        : (pos > _controller.value.duration ? _controller.value.duration : pos);
    _controller.seekTo(clamped);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isLooping ? Icons.repeat_on : Icons.repeat,
              color: _isLooping ? purple : Colors.white,
            ),
            tooltip: _isLooping ? 'Répétition activée' : 'Répéter',
            onPressed: () {
              setState(() => _isLooping = !_isLooping);
              _controller.setLooping(_isLooping);
            },
          ),
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur de lecture\n$_errorMessage',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : !_isInitialized
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : GestureDetector(
                  onTap: _toggleControls,
                  child: Stack(
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: _showControls ? 1 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          color: Colors.black.withOpacity(0.4),
                          child: Column(
                            children: [
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _circleBtn(
                                      Icons.replay_10, () => _seekRelative(-10),
                                      size: 40),
                                  const SizedBox(width: 20),
                                  _circleBtn(
                                    _controller.value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    () {
                                      setState(() {
                                        _controller.value.isPlaying
                                            ? _controller.pause()
                                            : _controller.play();
                                      });
                                      _startHideTimer();
                                    },
                                    size: 56,
                                  ),
                                  const SizedBox(width: 20),
                                  _circleBtn(
                                      Icons.forward_10, () => _seekRelative(10),
                                      size: 40),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _fmt(_controller.value.position),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12),
                                        ),
                                        Text(
                                          _fmt(_controller.value.duration),
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    SliderTheme(
                                      data: SliderTheme.of(ctx).copyWith(
                                        activeTrackColor: purple,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: Colors.white,
                                        overlayColor: purple.withOpacity(0.3),
                                        trackHeight: 3,
                                      ),
                                      child: Slider(
                                        value: _controller.value.duration
                                                    .inMilliseconds ==
                                                0
                                            ? 0
                                            : _controller
                                                .value.position.inMilliseconds
                                                .toDouble()
                                                .clamp(
                                                    0,
                                                    _controller.value.duration
                                                        .inMilliseconds
                                                        .toDouble()),
                                        min: 0,
                                        max: _controller.value.duration
                                                    .inMilliseconds ==
                                                0
                                            ? 1
                                            : _controller
                                                .value.duration.inMilliseconds
                                                .toDouble(),
                                        onChanged: (value) {
                                          _controller.seekTo(
                                            Duration(
                                                milliseconds: value.toInt()),
                                          );
                                        },
                                        onChangeStart: (_) {
                                          _hideControlsTimer?.cancel();
                                        },
                                        onChangeEnd: (_) {
                                          _startHideTimer();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _isMuted || _volume == 0
                                            ? Icons.volume_off
                                            : _volume < 0.5
                                                ? Icons.volume_down
                                                : Icons.volume_up,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isMuted = !_isMuted;
                                          _controller.setVolume(
                                              _isMuted ? 0 : _volume);
                                        });
                                        _startHideTimer();
                                      },
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(ctx).copyWith(
                                          activeTrackColor: Colors.white,
                                          inactiveTrackColor: Colors.white24,
                                          thumbColor: Colors.white,
                                          trackHeight: 2,
                                        ),
                                        child: Slider(
                                          value: _isMuted ? 0 : _volume,
                                          min: 0,
                                          max: 1,
                                          onChanged: (v) {
                                            setState(() {
                                              _volume = v;
                                              _isMuted = v == 0;
                                              _controller.setVolume(v);
                                            });
                                          },
                                          onChangeEnd: (_) {
                                            _startHideTimer();
                                          },
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.replay,
                                          color: Colors.white),
                                      tooltip: 'Rejouer depuis le début',
                                      onPressed: () {
                                        _controller.seekTo(Duration.zero);
                                        _controller.play();
                                        _startHideTimer();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {double size = 48}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }
}
