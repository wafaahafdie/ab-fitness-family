// lib/CvScreen.dart - SÉLECTION MULTIPLE + TOUT SÉLECTIONNER + PARTAGE SOCIAL
// ⭐ CORRIGÉ : Import PDF depuis le téléphone (lecture depuis path si bytes null)
// ⭐ AJOUTÉ : Icône téléchargement par document (visiteur, si autorisé par le chef)
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/supabase_service.dart';

import 'DetailUserScreen.dart'
    show navy, purple, pink, grey, cardBg, docCardBg, dividerColor;

const Color selectedGreen = Color(0xFF4CAF50);

// ============================================================
// MODELE FICHIER CV
// ============================================================

class CvFile {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime date;
  final Uint8List? bytes;
  final String memberId;
  final String? firestoreId;
  final String? storagePath;
  final String? downloadUrl;

  CvFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.date,
    this.bytes,
    required this.memberId,
    this.firestoreId,
    this.storagePath,
    this.downloadUrl,
  });

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes o';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} Ko';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  String get dateLabel {
    const mois = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${mois[date.month - 1]} ${date.year}';
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'sizeBytes': sizeBytes,
      'date': date.toIso8601String(),
      'memberId': memberId,
      'path': path,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'uploadedAt': FieldValue.serverTimestamp(),
      'type': 'cv',
    };
  }

  factory CvFile.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime parsedDate;
    try {
      parsedDate = data['date'] != null
          ? DateTime.parse(data['date'].toString())
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return CvFile(
      firestoreId: id,
      path: data['path'] ?? '',
      name: data['name'] ?? '',
      sizeBytes: (data['sizeBytes'] ?? 0) is int
          ? data['sizeBytes'] ?? 0
          : int.tryParse(data['sizeBytes'].toString()) ?? 0,
      date: parsedDate,
      memberId: data['memberId'] ?? '',
      storagePath: data['storagePath'],
      downloadUrl: data['downloadUrl'],
    );
  }
}

// ============================================================
// CV SCREEN
// ============================================================

class CvScreen extends StatefulWidget {
  final String ownerName;
  final String memberId;
  final List<CvFile>? initialFiles;
  final bool isVisitor;
  final bool canDownload;

  const CvScreen({
    super.key,
    required this.memberId,
    this.ownerName = 'Hafdi Mohamed',
    this.initialFiles,
    this.isVisitor = false,
    this.canDownload = false,
  });

  @override
  State<CvScreen> createState() => _CvScreenState();
}

class _CvScreenState extends State<CvScreen> {
  late List<CvFile> files;

  bool _isImporting = false;
  bool _isLoading = true;

  bool _isSelecting = false;
  Set<String> _selectedIds = {};
  bool _isDownloading = false;
  bool _isShareMode = false;

  static const String _firestoreCollection = 'CvFiles';
  static const String _supabaseBucket = 'cv_files';

  final SupabaseService _storage = SupabaseService();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _firestoreSubscription;

  final List<Map<String, dynamic>> _socialApps = [
    {
      'icon': Icons.facebook,
      'color': const Color(0xFF1877F2),
      'name': 'Facebook'
    },
    {
      'icon': Icons.camera_alt,
      'color': const Color(0xFFE4405F),
      'name': 'Instagram'
    },
    {
      'icon': Icons.message,
      'color': const Color(0xFF25D366),
      'name': 'WhatsApp'
    },
    {'icon': Icons.send, 'color': const Color(0xFF0088CC), 'name': 'Telegram'},
    {'icon': Icons.chat, 'color': const Color(0xFF00B2FF), 'name': 'Messenger'},
    {'icon': Icons.copy, 'color': const Color(0xFF6C63FF), 'name': 'Copier'},
  ];

  @override
  void initState() {
    super.initState();
    files = widget.initialFiles ?? [];
    _loadData();
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadFromFirestore();
    _listenToFirestoreRealtime();
    if (mounted) setState(() => _isLoading = false);
  }

  void _pruneSelection() {
    final validIds = files
        .where((f) => f.firestoreId != null)
        .map((f) => f.firestoreId!)
        .toSet();
    _selectedIds = _selectedIds.intersection(validIds);
    if (files.isEmpty) {
      _isSelecting = false;
      _isShareMode = false;
    }
  }

  Future<void> _loadFromFirestore() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection(_firestoreCollection)
          .where('memberId', isEqualTo: widget.memberId)
          .get();

      final loadedFiles = querySnapshot.docs.map((doc) {
        return CvFile.fromFirestore(doc.id, doc.data());
      }).toList();

      loadedFiles.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          files = loadedFiles;
          _pruneSelection();
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement: $e');
    }
  }

  void _listenToFirestoreRealtime() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = FirebaseFirestore.instance
        .collection(_firestoreCollection)
        .where('memberId', isEqualTo: widget.memberId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final loadedFiles = snapshot.docs.map((doc) {
        return CvFile.fromFirestore(doc.id, doc.data());
      }).toList();
      loadedFiles.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        files = loadedFiles;
        _pruneSelection();
        _isLoading = false;
      });
    }, onError: (error) {
      debugPrint('❌ Erreur écoute: $error');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  // ═══════════════════════════════════════════════════════
  // ⭐⭐⭐ NOUVEAU : TÉLÉCHARGER UN SEUL CV ⭐⭐⭐
  // Appelé par l'icône ⬇️ sur chaque CV (visiteur)
  // ═══════════════════════════════════════════════════════

  Future<void> _telechargerFichier(CvFile file) async {
    // ⭐ Sécurité : chef doit avoir autorisé
    if (!widget.canDownload) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Téléchargement non autorisé'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final url = file.downloadUrl ?? '';
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Fichier introuvable'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${file.name} téléchargé'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Impossible d\'ouvrir le fichier');
      }
    } catch (e) {
      debugPrint('❌ Erreur téléchargement: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════
  // SÉLECTION MULTIPLE (chef uniquement)
  // ═══════════════════════════════════════════════════════

  void _enterSelectionMode() {
    setState(() {
      _isSelecting = true;
      _isShareMode = false;
      _selectedIds = {};
    });
  }

  void _enterShareSelectionMode({bool selectAll = false}) {
    if (files.isEmpty) return;
    setState(() {
      _isSelecting = true;
      _isShareMode = true;
      _selectedIds = selectAll
          ? files
              .where((f) => f.firestoreId != null)
              .map((f) => f.firestoreId!)
              .toSet()
          : {};
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelecting = false;
      _isShareMode = false;
      _selectedIds = {};
    });
  }

  void _toggleFileSelection(String id) {
    if (id.isEmpty) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    final allIds = files
        .where((f) => f.firestoreId != null)
        .map((f) => f.firestoreId!)
        .toSet();

    setState(() {
      if (_selectedIds.length == allIds.length) {
        _selectedIds = {};
      } else {
        _selectedIds = allIds;
      }
    });
  }

  void _shareSelected() {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez au moins un fichier'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedFiles =
        files.where((f) => _selectedIds.contains(f.firestoreId)).toList();

    _showShareSheet(selectedFiles);
  }

  Future<void> _downloadSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez au moins un fichier'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isDownloading = true);

    final selectedFiles =
        files.where((f) => _selectedIds.contains(f.firestoreId)).toList();

    int success = 0;
    int failed = 0;

    for (final file in selectedFiles) {
      try {
        if (file.downloadUrl != null && file.downloadUrl!.isNotEmpty) {
          final uri = Uri.parse(file.downloadUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            success++;
            await Future.delayed(const Duration(milliseconds: 400));
          } else {
            failed++;
          }
        } else {
          failed++;
        }
      } catch (e) {
        debugPrint('❌ Erreur téléchargement: $e');
        failed++;
      }
    }

    if (!mounted) return;

    setState(() {
      _isDownloading = false;
      _isSelecting = false;
      _isShareMode = false;
      _selectedIds = {};
    });

    String message = '✅ $success fichier(s) téléchargé(s)';
    if (failed > 0) message += ' • $failed échec(s)';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: failed > 0 ? Colors.orange : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // IMPORT CV
  // ═══════════════════════════════════════════════════════

  Future<void> _importerCv() async {
    if (widget.isVisitor) return;
    if (_isImporting) return;
    setState(() => _isImporting = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      final pickedFile = result.files.single;
      final String fileName = pickedFile.name;

      Uint8List? bytes = pickedFile.bytes;

      if ((bytes == null || bytes.isEmpty) && pickedFile.path != null) {
        debugPrint('⚠️ Bytes null, lecture depuis path: ${pickedFile.path}');
        try {
          final file = File(pickedFile.path!);
          bytes = await file.readAsBytes();
          debugPrint('✅ Bytes lus depuis path: ${bytes.length} octets');
        } catch (e) {
          debugPrint('❌ Impossible de lire le path: $e');
        }
      }

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Impossible de lire le fichier PDF.');
      }

      final int size = bytes.length;
      final DateTime now = DateTime.now();

      final docRef =
          FirebaseFirestore.instance.collection(_firestoreCollection).doc();

      final safeFileName = _sanitizeFileName(fileName);
      final storagePath = '${widget.memberId}/${docRef.id}_$safeFileName';

      final downloadUrl = await _storage.uploadFile(
        bucket: _supabaseBucket,
        path: storagePath,
        bytes: bytes,
        contentType: 'application/pdf',
      );

      await docRef.set({
        'name': fileName,
        'sizeBytes': size,
        'date': now.toIso8601String(),
        'memberId': widget.memberId,
        'path': fileName,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'type': 'cv',
      });

      await _loadFromFirestore();

      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ CV importé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur import: $e');
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erreur lors de l'import : $e")),
        );
      }
    }
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^\w\-. ]'), '_').replaceAll(' ', '_');
  }

  Future<void> _ouvrirFichier(CvFile file) async {
    try {
      if (file.downloadUrl != null && file.downloadUrl!.isNotEmpty) {
        final uri = Uri.parse(file.downloadUrl!);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('❌ Erreur ouverture: $e');
    }
  }

  Future<void> _confirmSupprimer(CvFile file) async {
    if (widget.isVisitor) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer',
            style: TextStyle(color: navy, fontWeight: FontWeight.bold)),
        content: Text(
          'Voulez-vous vraiment supprimer "${file.name}" ?',
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
      if (file.storagePath != null && file.storagePath!.isNotEmpty) {
        await _storage.deleteFile(
            bucket: _supabaseBucket, path: file.storagePath!);
      }
      if (file.firestoreId != null) {
        await FirebaseFirestore.instance
            .collection(_firestoreCollection)
            .doc(file.firestoreId)
            .delete();
      }
      if (mounted) {
        setState(() {
          files.removeWhere((f) => f.firestoreId == file.firestoreId);
          _pruneSelection();
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur suppression: $e');
    }
  }

  Future<void> _renommerFichier(CvFile file) async {
    if (widget.isVisitor) return;

    const extension = '.pdf';
    final controller = TextEditingController(
      text: file.name.endsWith('.pdf')
          ? file.name.substring(0, file.name.length - 4)
          : file.name,
    );

    final newBaseName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Renommer',
            style: TextStyle(color: navy, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 13, color: navy),
          decoration: InputDecoration(
            filled: true,
            fillColor: cardBg,
            suffixText: extension,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Enregistrer',
                style: TextStyle(color: purple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    controller.dispose();
    if (newBaseName == null || newBaseName.trim().isEmpty) return;

    try {
      final newName = '$newBaseName$extension';
      if (file.storagePath == null || file.storagePath!.isEmpty) return;

      final data = await _storage.downloadFile(
        bucket: _supabaseBucket,
        path: file.storagePath!,
      );
      if (data == null || data.isEmpty) return;

      final safeName = _sanitizeFileName(newName);
      final newStoragePath = '${widget.memberId}/${file.firestoreId}_$safeName';

      final newDownloadUrl = await _storage.renameFile(
        bucket: _supabaseBucket,
        oldPath: file.storagePath!,
        newPath: newStoragePath,
        bytes: data,
      );

      if (file.firestoreId != null) {
        await FirebaseFirestore.instance
            .collection(_firestoreCollection)
            .doc(file.firestoreId)
            .update({
          'name': newName,
          'path': newName,
          'storagePath': newStoragePath,
          'downloadUrl': newDownloadUrl,
        });
      }

      await _loadFromFirestore();
    } catch (e) {
      debugPrint('❌ Erreur renommage: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // PARTAGE SOCIAL
  // ═══════════════════════════════════════════════════════

  void _partagerFichier(CvFile file) {
    if (widget.isVisitor) return;
    _showShareSheet([file]);
  }

  void _partagerTout() {
    if (widget.isVisitor || files.isEmpty) return;
    _enterShareSelectionMode(selectAll: true);
  }

  void _showShareSheet(List<CvFile> fichiers) {
    if (fichiers.isEmpty) return;

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
                      Text(
                        fichiers.length == 1
                            ? 'Partager le fichier'
                            : 'Partager ${fichiers.length} fichiers',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: navy,
                        ),
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
                                _copyLinks(fichiers);
                              } else {
                                _shareOnSocial(app, fichiers);
                              }
                            },
                            child: _AnimatedShareIcon(
                              icon: app['icon'],
                              color: app['color'],
                              label: app['name'],
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

  Future<void> _copyLinks(List<CvFile> fichiers) async {
    final String links = fichiers
        .where((f) => f.downloadUrl != null && f.downloadUrl!.isNotEmpty)
        .map((f) => '${f.name}\n${f.downloadUrl}')
        .join('\n\n');

    await Clipboard.setData(ClipboardData(text: links));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Liens copiés'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _shareOnSocial(
      Map<String, dynamic> app, List<CvFile> fichiers) async {
    final validFiles = fichiers
        .where((f) => f.downloadUrl != null && f.downloadUrl!.isNotEmpty)
        .toList();

    if (validFiles.isEmpty) return;

    final String message = validFiles.length == 1
        ? '📄 ${validFiles.first.name}\n\n${validFiles.first.downloadUrl}'
        : '📄 Mes CV (${validFiles.length})\n\n${validFiles.map((f) => '• ${f.name}\n${f.downloadUrl}').join('\n\n')}';

    try {
      await Share.share(message);
    } catch (e) {
      debugPrint('❌ Erreur partage: $e');
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: purple))
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(context),
                          const SizedBox(height: 18),
                          _buildHeader(),
                          const SizedBox(height: 18),
                          if (files.isEmpty)
                            _buildEmptyState()
                          else
                            _buildFilesList(),
                          const SizedBox(height: 20),
                          _buildBottomButtons(),
                        ],
                      ),
                    ),
                  ),
                  // ⭐ Barre de sélection : chef uniquement
                  if (_isSelecting && !widget.isVisitor) _buildSelectionBar(),
                ],
              ),
      ),
    );
  }

  // ⭐ TopBar : plus de bouton "Télécharger" pour le visiteur
  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ElegantBackButton(onTap: () => Navigator.of(context).pop()),

        // ⭐ CÔTÉ CHEF uniquement : bouton "Partager tout"
        if (!widget.isVisitor)
          GestureDetector(
            onTap: files.isEmpty
                ? null
                : (_isSelecting ? _exitSelectionMode : _partagerTout),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _isSelecting ? Colors.red : null,
                gradient: _isSelecting
                    ? null
                    : const LinearGradient(colors: [purple, pink]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color:
                        (_isSelecting ? Colors.red : purple).withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isSelecting
                        ? Icons.close_rounded
                        : Icons.ios_share_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isSelecting ? 'Annuler' : 'Partager tout',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectionBar() {
    final int total = files.length;
    final int selected = _selectedIds.length;
    final int validTotal = files.where((f) => f.firestoreId != null).length;
    final bool allSelected = validTotal > 0 && selected == validTotal;
    final bool canAct = selected > 0 && !_isDownloading;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: _toggleSelectAll,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: allSelected
                      ? selectedGreen.withOpacity(0.15)
                      : const Color(0xFFF0F0F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: allSelected ? selectedGreen : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      allSelected
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: allSelected ? selectedGreen : navy,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      allSelected ? 'Tout désélectionner' : 'Tout sélectionner',
                      style: TextStyle(
                        color: allSelected ? selectedGreen : navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$selected / $total',
                style: const TextStyle(
                  color: purple,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: canAct
                  ? (_isShareMode ? _shareSelected : _downloadSelected)
                  : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected > 0
                      ? const LinearGradient(colors: [purple, pink])
                      : null,
                  color: selected > 0 ? null : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected > 0
                      ? [
                          BoxShadow(
                            color: purple.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isDownloading && !_isShareMode)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    else
                      Icon(
                        _isShareMode
                            ? Icons.ios_share_rounded
                            : Icons.download_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _isShareMode
                          ? 'Partager ($selected)'
                          : (_isDownloading
                              ? 'Téléchargement...'
                              : 'Télécharger'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: cardBg, borderRadius: BorderRadius.circular(14)),
          child: Center(
              child: _asset('cv',
                  size: 26, color: purple, fallback: Icons.badge_outlined)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CV',
                style: TextStyle(
                    color: navy, fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 2),
            Text(
                '${files.length} fichier${files.length > 1 ? 's' : ''} • ${widget.ownerName}',
                style: const TextStyle(
                    color: grey, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildFilesList() {
    return Column(children: files.map((file) => _fileTile(file)).toList());
  }

  // ⭐⭐⭐ FILE TILE : icône ⬇️ par CV (visiteur) ⭐⭐⭐
  Widget _fileTile(CvFile file) {
    final id = file.firestoreId ?? '';
    final isSelected = _selectedIds.contains(id);

    return GestureDetector(
      onTap: () {
        // ⭐ VISITEUR : clic simple = ouvrir
        if (widget.isVisitor) {
          _ouvrirFichier(file);
          return;
        }
        // CHEF : comportement normal
        if (_isSelecting) {
          _toggleFileSelection(id);
        } else {
          _ouvrirFichier(file);
        }
      },
      onLongPress: () {
        // ⭐ VISITEUR : pas de sélection multiple
        if (widget.isVisitor) return;

        if (_isSelecting) return;
        _enterShareSelectionMode();
        _toggleFileSelection(id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.withOpacity(0.12) : docCardBg,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: selectedGreen, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? selectedGreen.withOpacity(0.25)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 10 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Checkbox : chef uniquement
            if (_isSelecting && !widget.isVisitor)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? selectedGreen : Colors.white,
                    border: Border.all(
                      color: isSelected ? selectedGreen : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ),

            // Icône PDF
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: const Center(
                  child: Icon(Icons.picture_as_pdf_rounded,
                      color: purple, size: 22)),
            ),
            const SizedBox(width: 12),

            // Nom + infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: navy)),
                  const SizedBox(height: 2),
                  Text('${file.sizeLabel} • ${file.dateLabel}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: grey,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),

            // ⭐⭐⭐ ICÔNE ⬇️ PAR CV (VISITEUR SEULEMENT) ⭐⭐⭐
            if (widget.isVisitor && widget.canDownload)
              GestureDetector(
                onTap: () => _telechargerFichier(file),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [purple, Color(0xFF8E00C8)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: purple.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/telechargement.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),

            // Actions du chef
            if (!_isSelecting && !widget.isVisitor) ...[
              IconButton(
                icon: const Icon(Icons.ios_share_rounded,
                    color: purple, size: 18),
                onPressed: () => _partagerFichier(file),
                tooltip: 'Partager',
              ),
              _buildFileMenu(file),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileMenu(CvFile file) {
    if (widget.isVisitor) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30),
      tooltip: '',
      offset: const Offset(-5, 30),
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: const Icon(Icons.more_vert, color: grey, size: 20),
      onSelected: (value) {
        if (value == 'renommer') _renommerFichier(file);
        if (value == 'supprimer') _confirmSupprimer(file);
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
            value: 'renommer',
            height: 38,
            child: Row(children: [
              Icon(Icons.drive_file_rename_outline, size: 15, color: navy),
              SizedBox(width: 8),
              Text('Renommer',
                  style: TextStyle(
                      color: navy, fontSize: 12, fontWeight: FontWeight.w600))
            ])),
        PopupMenuItem(
            value: 'supprimer',
            height: 38,
            child: Row(children: [
              Icon(Icons.delete_outline, size: 15, color: Colors.red),
              SizedBox(width: 8),
              Text('Supprimer',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600))
            ])),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration:
          BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _asset('cv', size: 40, color: purple, fallback: Icons.badge_outlined),
          const SizedBox(height: 10),
          const Text('Aucun CV pour le moment',
              style: TextStyle(
                  color: navy, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            widget.isVisitor
                ? 'Aucun CV à consulter'
                : 'Importe un fichier pour commencer',
            style: const TextStyle(color: grey, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    if (widget.isVisitor) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _isImporting ? null : _importerCv,
      child: Container(
        width: double.infinity,
        height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [purple, pink]),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
                color: purple.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isImporting)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white)))
            else
              const Icon(Icons.upload_file_rounded,
                  color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(_isImporting ? 'Upload en cours...' : 'Importer un CV',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _AnimatedShareIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _AnimatedShareIcon({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  State<_AnimatedShareIcon> createState() => _AnimatedShareIconState();
}

class _AnimatedShareIconState extends State<_AnimatedShareIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(widget.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          Text(widget.label, style: const TextStyle(fontSize: 10, color: navy)),
        ],
      ),
    );
  }
}

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
