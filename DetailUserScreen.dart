// lib/DetailUserScreen.dart - AVEC BOUTON RETOUR ÉLÉGANT ✅ + SÉLECTION MULTIPLE / PARTAGE (docs personnalisés)
// ⭐ CORRIGÉ : Import PDF depuis téléphone (lecture depuis path si bytes null)
// ⭐ CORRIGÉ : Les catégories VIDÉO n'apparaissent plus dans "Mes Documents"
// ⭐ AJOUTÉ : Icône téléchargement par document personnalisé (visiteur, si autorisé par le chef)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'services/supabase_service.dart';

import 'AjouterCategorieScreen.dart';
import 'Certaficat.dart';
import 'CvScreen.dart';
import 'Diplome.dart';
import 'MesPhotosScreen.dart';
import 'MesVideosScreen.dart';
import 'MonProfilScreen.dart';

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1E2235);
const Color purple = Color(0xFF890CC2);
const Color pink = Color(0xFFE91E9B);
const Color grey = Color(0xFF9E9EAE);

const Color cardBg = Color(0xFFF0EFFF);
const Color docCardBg = Color(0xFFF5F3FF);
const Color dividerColor = Color(0xFFDFDCEF);

const Color ringPinkLight = Color(0xFFE91E9B);
const Color ringPinkDeep = Color(0xFF890CC2);
const Color ringBlueLight = Color(0xFF2F7BFF);
const Color ringBlueDeep = Color(0xFF1F2A6B);

const Color selectedGreen = Color(0xFF4CAF50);

const String defaultPhoto = 'assets/images/profilpat.jpg';

const String collectionChef = 'Chef de Famille';
const String collectionMembres = 'Membres Famille';

// ============================================================
// ROUTE OBSERVER GLOBAL
// ============================================================

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// ============================================================
// WIDGET BOUTON RETOUR ÉLÉGANT
// ============================================================

class _ElegantBackButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;

  const _ElegantBackButton({required this.onTap, this.size = 42});

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
          width: widget.size,
          height: widget.size,
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
// MODELE DOCUMENT DE CATEGORIE
// ============================================================

class CategorieDocument {
  final String id;
  final String nom;
  final String taille;
  final String date;
  final String? url;
  final String? storagePath;
  final DateTime? uploadedAt;

  const CategorieDocument({
    required this.id,
    required this.nom,
    required this.taille,
    required this.date,
    this.url,
    this.storagePath,
    this.uploadedAt,
  });
}

// ============================================================
// ECRAN DOCUMENTS DE CATEGORIE (⭐ MODIFIÉ)
// ============================================================

class CategorieDocumentsScreen extends StatefulWidget {
  final String categorieNom;
  final String? categorieId;
  final List<CategorieDocument> documents;
  final String memberId;
  final bool isVisitor;
  final bool canDownload;

  const CategorieDocumentsScreen({
    super.key,
    required this.categorieNom,
    this.categorieId,
    this.documents = const [],
    required this.memberId,
    this.isVisitor = false,
    this.canDownload = false,
  });

  @override
  State<CategorieDocumentsScreen> createState() =>
      _CategorieDocumentsScreenState();
}

class _CategorieDocumentsScreenState extends State<CategorieDocumentsScreen> {
  late List<CategorieDocument> documents;
  bool _isImporting = false;
  bool _isLoading = true;

  bool _isSelecting = false;
  Set<String> _selectedIds = {};
  bool _isDownloading = false;
  bool _isShareMode = false;

  static const String _collectionName = 'UserDocuments';
  static const String _supabaseBucket = 'documents';

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
    documents = List.from(widget.documents);
    _loadData();
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadDocuments();
    _listenToFirestoreRealtime();
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  CategorieDocument _docFromFirestore(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final rawUploaded = data['uploadedAt'];
    final DateTime? uploadedAt =
        rawUploaded is Timestamp ? rawUploaded.toDate() : null;

    final int sizeBytes = data['sizeBytes'] is int
        ? data['sizeBytes'] as int
        : int.tryParse('${data['sizeBytes']}') ?? 0;

    return CategorieDocument(
      id: doc.id,
      nom: data['name'] ?? 'Document.pdf',
      taille: _formatSize(sizeBytes),
      date: uploadedAt != null
          ? uploadedAt.toString().substring(0, 10)
          : "Aujourd'hui",
      url: data['downloadUrl'] ?? '',
      storagePath: data['storagePath'],
      uploadedAt: uploadedAt,
    );
  }

  int _compareByDateDesc(CategorieDocument a, CategorieDocument b) {
    final now = DateTime.now();
    final aDate = a.uploadedAt ?? now;
    final bDate = b.uploadedAt ?? now;
    return bDate.compareTo(aDate);
  }

  void _pruneSelection() {
    final validIds = documents.map((d) => d.id).toSet();
    _selectedIds = _selectedIds.intersection(validIds);
    if (documents.isEmpty) {
      _isSelecting = false;
      _isShareMode = false;
    }
  }

  Future<void> _loadDocuments() async {
    if (widget.categorieId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection(_collectionName)
          .where('memberId', isEqualTo: widget.memberId)
          .where('categoryId', isEqualTo: widget.categorieId)
          .get();

      final loaded = querySnapshot.docs.map(_docFromFirestore).toList();
      loaded.sort(_compareByDateDesc);

      if (!mounted) return;
      setState(() {
        documents = loaded;
        _pruneSelection();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur chargement: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenToFirestoreRealtime() {
    _firestoreSubscription?.cancel();

    if (widget.categorieId == null) return;

    _firestoreSubscription = FirebaseFirestore.instance
        .collection(_collectionName)
        .where('memberId', isEqualTo: widget.memberId)
        .where('categoryId', isEqualTo: widget.categorieId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final loaded = snapshot.docs.map(_docFromFirestore).toList();
      loaded.sort(_compareByDateDesc);

      setState(() {
        documents = loaded;
        _pruneSelection();
        _isLoading = false;
      });
    }, onError: (error) {
      debugPrint('Erreur ecoute Firestore: $error');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^\w\-. ]'), '_').replaceAll(' ', '_');
  }

  // ═══════════════════════════════════════════════════════
  // ⭐⭐⭐ NOUVEAU : TÉLÉCHARGER UN SEUL DOCUMENT (visiteur) ⭐⭐⭐
  // ═══════════════════════════════════════════════════════

  Future<void> _telechargerFichier(CategorieDocument doc) async {
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

    final url = doc.url ?? '';
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
            content: Text('✅ ${doc.nom} téléchargé'),
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

  void _enterSelectionMode() {
    setState(() {
      _isSelecting = true;
      _isShareMode = false;
      _selectedIds = {};
    });
  }

  void _enterShareSelectionMode({bool selectAll = false}) {
    if (documents.isEmpty) return;
    setState(() {
      _isSelecting = true;
      _isShareMode = true;
      _selectedIds = selectAll ? documents.map((d) => d.id).toSet() : {};
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
    final allIds = documents.map((d) => d.id).toSet();

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
        documents.where((d) => _selectedIds.contains(d.id)).toList();

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
        documents.where((d) => _selectedIds.contains(d.id)).toList();

    int success = 0;
    int failed = 0;

    for (final file in selectedFiles) {
      try {
        if (file.url != null && file.url!.isNotEmpty) {
          final uri = Uri.parse(file.url!);
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

  Future<void> _importerDocument() async {
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
        if (mounted) {
          setState(() => _isImporting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fichier vide ou invalide')),
          );
        }
        return;
      }

      final safeFileName = _sanitizeFileName(fileName);
      final storagePath =
          '${widget.memberId}/${widget.categorieId}/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

      final downloadUrl = await _storage.uploadFile(
        bucket: _supabaseBucket,
        path: storagePath,
        bytes: bytes,
        contentType: 'application/pdf',
      );

      final docRef =
          FirebaseFirestore.instance.collection(_collectionName).doc();

      await docRef.set({
        'name': fileName,
        'sizeBytes': bytes.length,
        'categoryId': widget.categorieId,
        'memberId': widget.memberId,
        'storagePath': storagePath,
        'downloadUrl': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'type': 'document',
      });

      await _loadDocuments();

      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Document importé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur import: $e');
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _ouvrirDocument(CategorieDocument doc) async {
    try {
      if (doc.url != null && doc.url!.isNotEmpty) {
        final uri = Uri.parse(doc.url!);
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!opened) {
          throw Exception("Impossible d'ouvrir le PDF");
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ce document n\'a pas d\'URL valide.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur ouverture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible d'ouvrir le document : $e")),
        );
      }
    }
  }

  void _renommerDocument(CategorieDocument doc) {
    if (widget.isVisitor) return;

    final controller = TextEditingController(text: doc.nom);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Renommer',
            style: TextStyle(color: navy, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(fontSize: 13, color: navy),
            decoration: InputDecoration(
              filled: true,
              fillColor: cardBg,
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
              onPressed: () async {
                final newName = controller.text.trim();
                Navigator.pop(context);
                if (newName.isEmpty) return;

                try {
                  await FirebaseFirestore.instance
                      .collection(_collectionName)
                      .doc(doc.id)
                      .update({'name': newName});

                  await _loadDocuments();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Document renommé'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Erreur renommage: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Erreur: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Enregistrer',
                style: TextStyle(color: purple, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmSupprimer(CategorieDocument doc) async {
    if (widget.isVisitor) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer',
            style: TextStyle(color: navy, fontWeight: FontWeight.bold)),
        content: Text(
          'Voulez-vous vraiment supprimer "${doc.nom}" ?',
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
      if (doc.storagePath != null && doc.storagePath!.isNotEmpty) {
        await _storage.deleteFile(
          bucket: _supabaseBucket,
          path: doc.storagePath!,
        );
      }

      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(doc.id)
          .delete();

      if (mounted) {
        setState(() {
          documents.removeWhere((d) => d.id == doc.id);
          _pruneSelection();
        });
      }
    } catch (e) {
      debugPrint('Erreur suppression: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _partagerDocument(CategorieDocument doc) {
    if (widget.isVisitor) return;
    _showShareSheet([doc]);
  }

  void _partagerTout() {
    if (widget.isVisitor || documents.isEmpty) return;
    _enterShareSelectionMode(selectAll: true);
  }

  void _showShareSheet(List<CategorieDocument> fichiers) {
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

  Future<void> _copyLinks(List<CategorieDocument> fichiers) async {
    final String links = fichiers
        .where((f) => f.url != null && f.url!.isNotEmpty)
        .map((f) => '${f.nom}\n${f.url}')
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
      Map<String, dynamic> app, List<CategorieDocument> fichiers) async {
    final validFiles =
        fichiers.where((f) => f.url != null && f.url!.isNotEmpty).toList();

    if (validFiles.isEmpty) return;

    final String message = validFiles.length == 1
        ? '📄 ${validFiles.first.nom}\n\n${validFiles.first.url}'
        : '📄 ${widget.categorieNom} (${validFiles.length})\n\n${validFiles.map((f) => '• ${f.nom}\n${f.url}').join('\n\n')}';

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
                    widget.categorieNom,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: purple))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.folder_outlined,
                            color: purple,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.categorieNom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: navy,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              '${documents.length} fichier${documents.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderActions(),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: documents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_open_outlined,
                                  size: 60,
                                  color: grey.withOpacity(0.5),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Aucun document',
                                  style: TextStyle(
                                    color: grey,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.isVisitor
                                      ? 'Aucun document à consulter'
                                      : 'Ajoutez des documents à cette catégorie',
                                  style: const TextStyle(
                                    color: grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: documents.length,
                            itemBuilder: (context, index) {
                              final doc = documents[index];
                              return _documentTile(doc);
                            },
                          ),
                  ),
                  if (!widget.isVisitor && !_isSelecting) ...[
                    const SizedBox(height: 8),
                    _buildImportButton(),
                  ],
                ],
              ),
            ),
      // ⭐ Barre de sélection : chef uniquement
      bottomNavigationBar:
          _isSelecting && !widget.isVisitor ? _buildSelectionBar() : null,
    );
  }

  // ⭐ TopBar : plus de bouton "Télécharger" pour le visiteur
  Widget _buildHeaderActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ⭐ CÔTÉ CHEF uniquement : bouton "Partager tout"
        if (!widget.isVisitor)
          GestureDetector(
            onTap: documents.isEmpty
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectionBar() {
    final int total = documents.length;
    final int selected = _selectedIds.length;
    final bool allSelected = total > 0 && selected == total;
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

  Widget _buildImportButton() {
    return GestureDetector(
      onTap: _isImporting ? null : _importerDocument,
      child: Container(
        width: double.infinity,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [purple, pink],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: purple.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              const Icon(
                Icons.upload_file_rounded,
                color: Colors.white,
                size: 18,
              ),
            const SizedBox(width: 8),
            Text(
              _isImporting ? 'Import en cours...' : 'Importer un document',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⭐⭐⭐ DOCUMENT TILE : icône ⬇️ par document (visiteur) ⭐⭐⭐
  Widget _documentTile(CategorieDocument doc) {
    final isSelected = _selectedIds.contains(doc.id);

    return GestureDetector(
      onTap: () {
        // ⭐ VISITEUR : clic simple = ouvrir
        if (widget.isVisitor) {
          _ouvrirDocument(doc);
          return;
        }
        // CHEF : comportement normal
        if (_isSelecting) {
          _toggleFileSelection(doc.id);
        } else {
          _ouvrirDocument(doc);
        }
      },
      onLongPress: () {
        // ⭐ VISITEUR : pas de sélection multiple
        if (widget.isVisitor) return;

        if (_isSelecting) return;
        _enterShareSelectionMode();
        _toggleFileSelection(doc.id);
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
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: purple,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${doc.taille} • ${doc.date}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // ⭐⭐⭐ ICÔNE ⬇️ PAR DOCUMENT (VISITEUR SEULEMENT) ⭐⭐⭐
            if (widget.isVisitor && widget.canDownload)
              GestureDetector(
                onTap: () => _telechargerFichier(doc),
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
                icon: const Icon(
                  Icons.ios_share_rounded,
                  color: purple,
                  size: 18,
                ),
                onPressed: () => _partagerDocument(doc),
                tooltip: 'Partager',
              ),
              _buildFileMenu(doc),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileMenu(CategorieDocument doc) {
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
        if (value == 'renommer') _renommerDocument(doc);
        if (value == 'supprimer') _confirmSupprimer(doc);
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'renommer',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.drive_file_rename_outline, size: 15, color: navy),
              SizedBox(width: 8),
              Text(
                'Renommer',
                style: TextStyle(
                  color: navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'supprimer',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 15, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Supprimer',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ⭐ ICÔNE PARTAGE ANIMÉE
// ============================================================

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

// ============================================================
// MODELE DOCUMENT UTILISATEUR
// ============================================================

class UserDocument {
  final String label;
  final String subtitle;
  final String assetIcon;
  final String? id;
  final IconData? icon;
  final Color? color;
  final String? originalType;

  const UserDocument({
    required this.label,
    required this.subtitle,
    required this.assetIcon,
    this.id,
    this.icon,
    this.color,
    this.originalType,
  });
}

class _MemberRef {
  final String collection;
  final String id;

  const _MemberRef(this.collection, this.id);
}

// ============================================================
// DETAIL USER SCREEN
// ⭐ AJOUTÉ : isVisitor + canDownload (transmis aux écrans enfants)
// ============================================================

class DetailUserScreen extends StatefulWidget {
  final String userId;
  final bool isChef;

  // ⭐ NOUVEAU : pour transmettre les droits au visiteur
  final bool isVisitor;
  final bool canDownload;

  const DetailUserScreen({
    super.key,
    required this.userId,
    this.isChef = false,
    this.isVisitor = false,
    this.canDownload = false,
  });

  @override
  State<DetailUserScreen> createState() => _DetailUserScreenState();
}

class _DetailUserScreenState extends State<DetailUserScreen> with RouteAware {
  List<UserDocument> documents = [];

  String _name = '';
  String _role = '';
  String _photoUrl = '';
  String _gender = '';
  String _fullName = '';
  String _phone = '';
  String _email = '';
  String _address = '';
  String _memberId = '';

  Uint8List? _photoBytes;

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  int _refreshKey = 0;

  int _cvCount = 0;
  int _diplomeCount = 0;
  int _certificatCount = 0;
  int _photoCount = 0;
  int _videoCount = 0;

  Map<String, int> _customCounts = {};

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  _MemberRef? _ref;
  Timer? _indicatorTimer;
  bool _premiereDonnee = true;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cvSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _diplomeSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _certificatSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _photoSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _videoSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _customDocsSubscription;

  @override
  void initState() {
    super.initState();
    _memberId = widget.userId;
    _ecouterMembre();
    _chargerCompteursTempsReel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    _sub?.cancel();
    _cvSubscription?.cancel();
    _diplomeSubscription?.cancel();
    _certificatSubscription?.cancel();
    _photoSubscription?.cancel();
    _videoSubscription?.cancel();
    _customDocsSubscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (_sub == null) {
      _ecouterMembre();
    }
  }

  void _chargerCompteursTempsReel() {
    _cvSubscription = FirebaseFirestore.instance
        .collection('CvFiles')
        .where('memberId', isEqualTo: _memberId)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _cvCount = snapshot.docs.length;
        _mettreAJourSousTitres();
      });
    });

    _diplomeSubscription = FirebaseFirestore.instance
        .collection('DiplomeFiles')
        .where('memberId', isEqualTo: _memberId)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _diplomeCount = snapshot.docs.length;
        _mettreAJourSousTitres();
      });
    });

    _certificatSubscription = FirebaseFirestore.instance
        .collection('CertificatFiles')
        .where('memberId', isEqualTo: _memberId)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _certificatCount = snapshot.docs.length;
        _mettreAJourSousTitres();
      });
    });

    _photoSubscription = FirebaseFirestore.instance
        .collection('Photos')
        .where('memberId', isEqualTo: _memberId)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _photoCount = snapshot.docs.length;
        _mettreAJourSousTitres();
      });
    });

    _videoSubscription = FirebaseFirestore.instance
        .collection('video')
        .where('memberId', isEqualTo: _memberId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _videoCount = snapshot.docs.length;
        _mettreAJourSousTitres();
      });
    });

    _ecouterDocumentsPersonnalises();
  }

  void _ecouterDocumentsPersonnalises() {
    _customDocsSubscription?.cancel();

    _customDocsSubscription = FirebaseFirestore.instance
        .collection('UserDocuments')
        .where('memberId', isEqualTo: _memberId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final Map<String, int> counts = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();

        final String type =
            (data['type'] ?? 'document').toString().toLowerCase();
        if (type == 'video' || type == 'videos') continue;

        final categoryId = data['categoryId'] as String? ?? '';
        if (categoryId.isNotEmpty) {
          counts[categoryId] = (counts[categoryId] ?? 0) + 1;
        }
      }

      setState(() {
        _customCounts = counts;
      });
      _mettreAJourSousTitres();
    }, onError: (error) {
      debugPrint('Erreur ecoute UserDocuments: $error');
    });
  }

  void _mettreAJourSousTitres() {
    final updatedDocs = documents.map((doc) {
      final String effectiveLabel =
          doc.originalType?.toLowerCase() ?? doc.label.toLowerCase();
      int count = 0;
      String suffix = '';

      if (effectiveLabel == 'cv') {
        count = _cvCount;
        suffix = 'fichier';
      } else if (effectiveLabel == 'diplomes') {
        count = _diplomeCount;
        suffix = 'fichier';
      } else if (effectiveLabel == 'certificats') {
        count = _certificatCount;
        suffix = 'fichier';
      } else if (effectiveLabel == 'photos') {
        count = _photoCount;
        suffix = 'photo';
      } else if (effectiveLabel == 'videos') {
        count = _videoCount;
        suffix = 'vidéo';
      } else {
        if (doc.id != null && _customCounts.containsKey(doc.id)) {
          count = _customCounts[doc.id!]!;
        }
        suffix = 'element';
      }

      final subtitle =
          count > 0 ? '$count $suffix${count > 1 ? 's' : ''}' : '0 $suffix';

      return UserDocument(
        id: doc.id,
        label: doc.label,
        subtitle: subtitle,
        assetIcon: doc.assetIcon,
        icon: doc.icon,
        color: doc.color,
        originalType: doc.originalType,
      );
    }).toList();

    setState(() {
      documents = updatedDocs;
    });
  }

  Future<_MemberRef?> _trouverMembre() async {
    final List<String> collections = widget.isChef
        ? <String>[collectionChef, collectionMembres]
        : <String>[collectionMembres, collectionChef];

    final String id = widget.userId.trim();
    if (id.isEmpty) return null;

    for (final String c in collections) {
      try {
        final snap =
            await FirebaseFirestore.instance.collection(c).doc(id).get();
        if (snap.exists) {
          return _MemberRef(c, snap.id);
        }
      } catch (e) {
        debugPrint('Recherche dans $c : $e');
      }
    }

    for (final String c in collections) {
      try {
        final query = await FirebaseFirestore.instance
            .collection(c)
            .where('userId', isEqualTo: id)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          return _MemberRef(c, query.docs.first.id);
        }
      } catch (e) {
        debugPrint('Recherche par userId dans $c : $e');
      }
    }

    return null;
  }

  Future<void> _ecouterMembre() async {
    await _sub?.cancel();
    _sub = null;

    if (mounted) {
      setState(() {
        _error = null;
      });
    }

    final _MemberRef? ref = await _trouverMembre();
    if (!mounted) return;

    if (ref == null) {
      setState(() {
        _error = 'Utilisateur introuvable';
        _isLoading = false;
      });
      return;
    }

    _ref = ref;
    _memberId = ref.id;
    debugPrint('Ecoute de ${ref.collection} / ${ref.id}');

    _ecouterDocumentsPersonnalises();

    _sub = FirebaseFirestore.instance
        .collection(ref.collection)
        .doc(ref.id)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;

        if (!snapshot.exists) {
          setState(() {
            _error = 'Utilisateur introuvable';
            _isLoading = false;
          });
          return;
        }

        _appliquer(snapshot.data() ?? <String, dynamic>{});
      },
      onError: (Object e) {
        if (!mounted) return;
        debugPrint("Erreur d'ecoute : $e");
        setState(() {
          _error = 'Erreur de chargement: $e';
          _isLoading = false;
        });
      },
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'cv':
        return Icons.badge_outlined;
      case 'diplomes':
        return Icons.school_outlined;
      case 'certificats':
        return Icons.verified_outlined;
      case 'videos':
        return Icons.video_library_outlined;
      case 'photos':
        return Icons.photo_library_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'cv':
        return Colors.blue.shade700;
      case 'diplomes':
        return Colors.green.shade700;
      case 'certificats':
        return Colors.purple.shade700;
      case 'videos':
        return Colors.orange.shade700;
      case 'photos':
        return Colors.pink.shade700;
      default:
        return navy;
    }
  }

  String _getAssetIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'cv':
        return 'cv';
      case 'diplomes':
        return 'dip';
      case 'certificats':
        return 'cetr';
      case 'videos':
        return 'vid';
      case 'photos':
        return 'imag';
      default:
        return 'doc';
    }
  }

  void _appliquer(Map<String, dynamic> data) {
    final String photo = _lire(
      data,
      const ['photoUrl', 'photo', 'photoBase64', 'image', 'avatar'],
      '',
    );

    if (photo != _photoUrl) {
      _oublierImage(_photoUrl);
      _photoBytes = _decodeBase64(photo);
      _refreshKey++;
      debugPrint('Nouvelle photo recue : ${photo.length} caracteres');
    }

    final bool chef = data['isHead'] == true || widget.isChef;
    final String nom = _lire(data, const ['fullName', 'name', 'nom'], '');

    List<UserDocument> loadedDocs = [];
    final Set<String> existingIds = {};

    final Set<String> renamedDefaultTypes = {};

    if (data.containsKey('categories') && data['categories'] is List) {
      final List categoriesData = data['categories'] as List;
      for (var cat in categoriesData) {
        if (cat is Map<String, dynamic>) {
          final String? catId = cat['id']?.toString();

          final String? source = cat['source'] as String?;

          if (source == 'photos_screen' ||
              source == 'photos' ||
              source == 'videos_screen' ||
              source == 'videos') {
            debugPrint('Categorie ignoree (source: $source): ${cat['nom']}');
            continue;
          }

          final String? originalType = cat['originalDefaultType'] as String?;
          if (originalType != null && originalType.trim().isNotEmpty) {
            renamedDefaultTypes.add(originalType.trim().toLowerCase());
          }

          if (catId != null && !existingIds.contains(catId)) {
            existingIds.add(catId);

            final int? iconCodePoint = cat['iconCodePoint'] as int?;
            final int? iconOld = cat['icon'] as int?;
            final int finalIconCode =
                iconCodePoint ?? iconOld ?? Icons.folder_outlined.codePoint;
            final IconData icon =
                IconData(finalIconCode, fontFamily: 'MaterialIcons');

            final int? colorValue = cat['colorValue'] as int?;
            final int? colorOld = cat['color'] as int?;
            final int finalColorValue = colorValue ?? colorOld ?? navy.value;
            final Color color = Color(finalColorValue);

            final String assetIcon = cat['assetIcon'] as String? ??
                (originalType != null
                    ? _getAssetIconForType(originalType)
                    : 'doc');

            loadedDocs.add(UserDocument(
              id: catId,
              label: cat['nom'] ?? 'Categorie',
              subtitle: '0 elements',
              assetIcon: assetIcon,
              icon: icon,
              color: color,
              originalType: originalType,
            ));
          }
        }
      }
    }

    _chargerCompteurs(loadedDocs);

    setState(() {
      _photoUrl = photo;
      _gender = _lire(data, const ['gender', 'genre', 'sexe'], '');
      _name = nom;
      _fullName = nom;
      _role = chef
          ? 'Chef de famille'
          : _lire(data, const ['relationship', 'relation', 'role', 'lien'], '');
      _phone =
          _lire(data, const ['phone', 'telephone', 'tel', 'phoneNumber'], '');
      _email = _lire(data, const ['email', 'mail'], '');
      _address = _lire(data,
          const ['address', 'adresse', 'ville', 'city', 'localisation'], '');

      final defaultDocs = _getDefaultDocuments();

      final filteredDefaultDocs = defaultDocs.where((d) {
        return !renamedDefaultTypes.contains(d.label.toLowerCase());
      }).toList();

      final Set<String> allIds = {};
      final List<UserDocument> mergedDocs = [];

      for (var doc in filteredDefaultDocs) {
        final String key = doc.id ?? doc.label;
        if (!allIds.contains(key)) {
          allIds.add(key);
          mergedDocs.add(doc);
        }
      }

      for (var doc in loadedDocs) {
        if (doc.id != null && !allIds.contains(doc.id)) {
          allIds.add(doc.id!);
          mergedDocs.add(doc);
        }
      }

      documents = mergedDocs;
      _isLoading = false;
      _error = null;
    });

    _mettreAJourSousTitres();

    if (!_premiereDonnee) {
      _montrerIndicateur();
    }
    _premiereDonnee = false;

    debugPrint(
      'Mise a jour recue : $_fullName | genre $_gender | '
      '${documents.length} documents',
    );
  }

  Future<void> _chargerCompteurs(List<UserDocument> docs) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('UserDocuments')
          .where('memberId', isEqualTo: _memberId)
          .get();

      final Map<String, int> counts = {};
      for (var doc in query.docs) {
        final data = doc.data();

        final String type =
            (data['type'] ?? 'document').toString().toLowerCase();
        if (type == 'video' || type == 'videos') continue;

        final categoryId = data['categoryId'] ?? 'default';
        counts[categoryId] = (counts[categoryId] ?? 0) + 1;
      }

      for (int i = 0; i < docs.length; i++) {
        final id = docs[i].id;
        if (id != null && counts.containsKey(id)) {
          final count = counts[id]!;
          docs[i] = UserDocument(
            id: docs[i].id,
            label: docs[i].label,
            subtitle: '$count element${count > 1 ? 's' : ''}',
            assetIcon: docs[i].assetIcon,
            icon: docs[i].icon,
            color: docs[i].color,
            originalType: docs[i].originalType,
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement compteurs: $e');
    }
  }

  List<UserDocument> _getDefaultDocuments() {
    return [
      UserDocument(
        label: 'CV',
        subtitle: '0 fichiers',
        assetIcon: 'cv',
        icon: Icons.badge_outlined,
        color: Colors.blue.shade700,
      ),
      UserDocument(
        label: 'Diplomes',
        subtitle: '0 fichiers',
        assetIcon: 'dip',
        icon: Icons.school_outlined,
        color: Colors.green.shade700,
      ),
      UserDocument(
        label: 'Videos',
        subtitle: '0 vidéos',
        assetIcon: 'vid',
        icon: Icons.video_library_outlined,
        color: Colors.orange.shade700,
      ),
      UserDocument(
        label: 'Certificats',
        subtitle: '0 fichiers',
        assetIcon: 'cetr',
        icon: Icons.verified_outlined,
        color: Colors.purple.shade700,
      ),
      UserDocument(
        label: 'Photos',
        subtitle: '0 photos',
        assetIcon: 'imag',
        icon: Icons.photo_library_outlined,
        color: Colors.pink.shade700,
      ),
    ];
  }

  void _voirTousLesDocuments() {
    if (documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun document disponible'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.folder_open_outlined, color: purple, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Tous les documents',
                style: TextStyle(
                  color: navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: docCardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE8E5F5),
                    width: 0.7,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE8E5F5),
                          width: 0.7,
                        ),
                      ),
                      child: Center(
                        child: doc.icon != null
                            ? Icon(
                                doc.icon,
                                color: doc.color ?? navy,
                                size: 18,
                              )
                            : _asset(
                                doc.assetIcon,
                                size: 18,
                                color: navy,
                                fallback: Icons.insert_drive_file,
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        doc.label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: navy,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [purple, pink],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Fermer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _lire(Map<String, dynamic> data, List<String> cles, String secours) {
    for (final String cle in cles) {
      if (!data.containsKey(cle)) continue;
      final String texte = (data[cle] ?? '').toString().trim();
      if (texte.isNotEmpty && texte != 'null') {
        return texte;
      }
    }
    return secours.trim();
  }

  Uint8List? _decodeBase64(String value) {
    if (value.isEmpty) return null;
    if (value.startsWith('assets/')) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return null;
    }

    try {
      String raw = value.contains(',') ? value.split(',').last : value;
      raw = raw.replaceAll(RegExp(r'\s'), '');
      final int reste = raw.length % 4;
      if (reste != 0) {
        raw = raw.padRight(raw.length + (4 - reste), '=');
      }
      final decoded = base64Decode(raw);
      if (decoded.isEmpty) return null;
      return decoded;
    } catch (e) {
      debugPrint('Photo illisible : $e');
      return null;
    }
  }

  void _oublierImage(String value) {
    if (value.isEmpty) return;
    try {
      if (value.startsWith('http://') || value.startsWith('https://')) {
        NetworkImage(value).evict();
        debugPrint('Image URL supprimee du cache');
      } else if (value.startsWith('assets/')) {
        AssetImage(value).evict();
        debugPrint('Image asset supprimee du cache');
      } else {
        debugPrint('Base64 image : force refresh avec nouveau key');
      }
    } catch (e) {
      debugPrint('Nettoyage image : $e');
    }
  }

  void _montrerIndicateur() {
    _indicatorTimer?.cancel();
    setState(() {
      _isRefreshing = true;
    });
    _indicatorTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
      });
    });
  }

  Future<void> _refreshData() async {
    _premiereDonnee = false;
    await _ecouterMembre();
  }

  bool get _estFemme {
    final String g = _gender.toLowerCase();
    return g.startsWith('f') || g.startsWith('w') || g == 'female';
  }

  bool get _estHomme {
    final String g = _gender.toLowerCase();
    return g.startsWith('h') || g.startsWith('m') || g == 'male';
  }

  List<Color> get _ringColors {
    if (_estFemme) return const [ringPinkLight, ringPinkDeep];
    if (_estHomme) return const [ringBlueLight, ringBlueDeep];
    return const [grey, grey];
  }

  Widget _buildAvatar({double radius = 50}) {
    final double diametre = radius * 2;
    String photoUrl = _photoUrl;

    if (photoUrl.isEmpty || photoUrl == 'null') {
      photoUrl = defaultPhoto;
    }

    ImageProvider provider;

    if (_photoBytes != null && _photoBytes!.isNotEmpty) {
      provider = MemoryImage(_photoBytes!);
    } else if (photoUrl.startsWith('http://') ||
        photoUrl.startsWith('https://')) {
      provider = NetworkImage(photoUrl);
    } else if (photoUrl.startsWith('assets/')) {
      provider = AssetImage(photoUrl);
    } else {
      final bytes = _decodeBase64(photoUrl);
      if (bytes != null && bytes.isNotEmpty) {
        provider = MemoryImage(bytes);
        _photoBytes = bytes;
      } else {
        provider = const AssetImage(defaultPhoto);
      }
    }

    final String imageKey =
        'avatar_${_refreshKey}_${photoUrl.hashCode}_${_photoBytes?.length ?? 0}';

    return ClipOval(
      child: Image(
        key: ValueKey(imageKey),
        image: provider,
        width: diametre,
        height: diametre,
        fit: BoxFit.cover,
        gaplessPlayback: false,
        errorBuilder: (context, error, stack) {
          debugPrint('Erreur chargement photo: $error');
          return _initiale(diametre);
        },
      ),
    );
  }

  Widget _initiale(double diametre) {
    final String texte = _name.trim();
    final String lettre =
        texte.isEmpty ? '?' : texte.substring(0, 1).toUpperCase();

    return Container(
      width: diametre,
      height: diametre,
      alignment: Alignment.center,
      color: _ringColors.first.withAlpha(38),
      child: Text(
        lettre,
        style: TextStyle(
          color: _ringColors.last,
          fontSize: diametre * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _asset(String name,
      {double size = 20, Color? color, IconData? fallback}) {
    return Image.asset(
      'assets/images/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          fallback ?? Icons.circle,
          size: size,
          color: color ?? navy,
        );
      },
    );
  }

  Future<void> _ajouterCategorie() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AjouterCategorieScreen(),
      ),
    );

    if (result != null && mounted) {
      final String id =
          result['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      final String nom = result['nom'] ?? 'Nouvelle categorie';

      final int iconCodePoint =
          result['iconCodePoint'] ?? Icons.folder_outlined.codePoint;
      final IconData icon =
          IconData(iconCodePoint, fontFamily: 'MaterialIcons');

      final int colorValue = result['colorValue'] ?? navy.value;
      final Color color = Color(colorValue);

      await _sauvegarderCategorieDansFirestore(
        id: id,
        nom: nom,
        icon: icon,
        color: color,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Categorie "$nom" ajoutee avec succes'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _sauvegarderCategorieDansFirestore({
    required String id,
    required String nom,
    required IconData icon,
    required Color color,
  }) async {
    try {
      if (_ref == null) return;

      final Map<String, dynamic> newCategory = {
        'id': id,
        'nom': nom,
        'iconCodePoint': icon.codePoint,
        'colorValue': color.value,
        'iconColor': color.value,
        'createdBy': _ref!.id,
        'createdAt': DateTime.now().toIso8601String(),
        'source': 'detail_screen',
      };

      await FirebaseFirestore.instance
          .collection(_ref!.collection)
          .doc(_ref!.id)
          .update({
        'categories': FieldValue.arrayUnion([newCategory]),
      });

      debugPrint('Categorie sauvegardee dans ${_ref!.collection}/${_ref!.id}');
    } catch (e) {
      debugPrint('Erreur sauvegarde: $e');
      try {
        await FirebaseFirestore.instance
            .collection(_ref!.collection)
            .doc(_ref!.id)
            .set({
          'categories': [
            {
              'id': id,
              'nom': nom,
              'iconCodePoint': icon.codePoint,
              'colorValue': color.value,
              'iconColor': color.value,
              'createdBy': _ref!.id,
              'createdAt': DateTime.now().toIso8601String(),
              'source': 'detail_screen',
            }
          ]
        }, SetOptions(merge: true));
      } catch (e2) {
        debugPrint('Erreur creation champ: $e2');
      }
    }
  }

  void _modifierDocument(UserDocument doc) {
    final List<String> protectedCategories = ['photos', 'videos'];
    if (protectedCategories.contains(doc.label.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cette categorie ne peut pas etre renommee'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final TextEditingController controller =
        TextEditingController(text: doc.label);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Renommer',
            style: TextStyle(color: navy, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(fontSize: 13, color: navy),
            decoration: InputDecoration(
              filled: true,
              fillColor: cardBg,
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
              onPressed: () async {
                final newName = controller.text.trim();
                Navigator.pop(context);
                if (newName.isEmpty || newName == doc.label) return;

                try {
                  final IconData existingIcon =
                      doc.icon ?? _getIconForType(doc.label);
                  final Color existingColor =
                      doc.color ?? _getColorForType(doc.label);

                  if (_ref != null) {
                    final snapshot = await FirebaseFirestore.instance
                        .collection(_ref!.collection)
                        .doc(_ref!.id)
                        .get();

                    if (snapshot.exists) {
                      final data = snapshot.data() ?? {};
                      final List rawCategories = data['categories'] is List
                          ? data['categories'] as List
                          : [];
                      final List<Map<String, dynamic>> categories =
                          rawCategories
                              .whereType<Map<String, dynamic>>()
                              .toList();

                      List<Map<String, dynamic>>? updatedCategories;

                      if (doc.id != null) {
                        updatedCategories = categories.map((cat) {
                          if (cat['id'] == doc.id) {
                            return {
                              ...cat,
                              'nom': newName,
                              'iconCodePoint': cat['iconCodePoint'] ??
                                  existingIcon.codePoint,
                              'colorValue':
                                  cat['colorValue'] ?? existingColor.value,
                              'iconColor':
                                  cat['iconColor'] ?? existingColor.value,
                              'icon': cat['icon'] ?? existingIcon.codePoint,
                              'color': cat['color'] ?? existingColor.value,
                            };
                          }
                          return cat;
                        }).toList();
                      } else {
                        final List<String> defaultCategories = [
                          'cv',
                          'diplomes',
                          'certificats'
                        ];
                        if (defaultCategories
                            .contains(doc.label.toLowerCase())) {
                          int existingIndex = -1;
                          for (int i = 0; i < categories.length; i++) {
                            final cat = categories[i];
                            if (cat['originalDefaultType'] == doc.label) {
                              existingIndex = i;
                              break;
                            }
                          }

                          final String newId = existingIndex != -1 &&
                                  categories[existingIndex]['id'] != null
                              ? categories[existingIndex]['id'].toString()
                              : DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString();

                          final Map<String, dynamic> newCatMap = {
                            'id': newId,
                            'nom': newName,
                            'iconCodePoint': existingIcon.codePoint,
                            'colorValue': existingColor.value,
                            'iconColor': existingColor.value,
                            'icon': existingIcon.codePoint,
                            'color': existingColor.value,
                            'assetIcon': doc.assetIcon,
                            'originalDefaultType': doc.label,
                            'createdAt': DateTime.now().toIso8601String(),
                            'source': 'detail_screen',
                          };

                          if (existingIndex != -1) {
                            updatedCategories =
                                List<Map<String, dynamic>>.from(categories);
                            updatedCategories[existingIndex] = newCatMap;
                          } else {
                            updatedCategories = categories
                                .where((cat) =>
                                    cat['nom'] != doc.label ||
                                    cat['id'] != null)
                                .toList();
                            updatedCategories.add(newCatMap);
                          }
                        }
                      }

                      if (updatedCategories != null) {
                        await FirebaseFirestore.instance
                            .collection(_ref!.collection)
                            .doc(_ref!.id)
                            .update({'categories': updatedCategories});
                      }
                    }
                  }

                  setState(() {
                    final index = documents.indexWhere(
                        (d) => d.label == doc.label && d.id == doc.id);
                    if (index != -1) {
                      documents[index] = UserDocument(
                        id: doc.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        label: newName,
                        subtitle: doc.subtitle,
                        assetIcon: doc.assetIcon,
                        icon: existingIcon,
                        color: existingColor,
                        originalType: doc.originalType ?? doc.label,
                      );
                    }
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Categorie renommee avec succes'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Erreur renommage: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Enregistrer',
                style: TextStyle(color: purple, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _supprimerDocument(UserDocument doc) {
    final List<String> protectedCategories = ['photos', 'videos'];
    if (protectedCategories.contains(doc.label.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cette categorie ne peut pas etre supprimee'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Supprimer',
            style: TextStyle(
              color: navy,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          content: Text(
            'Voulez-vous supprimer "${doc.label}" ?',
            style: const TextStyle(
              color: grey,
              fontSize: 11,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Annuler',
                style: TextStyle(
                  color: grey,
                  fontSize: 11,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (_ref != null) {
                  try {
                    final snapshot = await FirebaseFirestore.instance
                        .collection(_ref!.collection)
                        .doc(_ref!.id)
                        .get();

                    if (snapshot.exists) {
                      final data = snapshot.data() ?? {};
                      final List categories = data['categories'] is List
                          ? data['categories'] as List
                          : [];

                      final filtered = categories.where((cat) {
                        if (cat is Map<String, dynamic>) {
                          if (doc.id != null && cat['id'] == doc.id) {
                            return false;
                          }
                          if (doc.id == null &&
                              cat['nom'] == doc.label &&
                              cat['id'] == null) {
                            return false;
                          }
                        }
                        return true;
                      }).toList();

                      await FirebaseFirestore.instance
                          .collection(_ref!.collection)
                          .doc(_ref!.id)
                          .update({'categories': filtered});
                    }

                    setState(() {
                      documents.removeWhere((d) =>
                          d.label == doc.label ||
                          (doc.id != null && d.id == doc.id));
                    });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Categorie supprimee avec succes'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint('Erreur suppression: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Supprimer',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: purple,
                ),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 50,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _refreshData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: purple,
                          ),
                          child: const Text('Reessayer'),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBackButton(context),
                        const SizedBox(height: 6),
                        if (_isRefreshing)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: purple,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Mise a jour...',
                                  style: TextStyle(
                                    color: purple,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _buildHeaderProfile(),
                        const SizedBox(height: 18),
                        _buildInfoCard(context),
                        const SizedBox(height: 20),
                        _buildDocumentsHeader(context),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _buildDocumentsScrollable(),
                        ),
                        const SizedBox(height: 8),
                        _buildAddDocumentButton(context),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return _ElegantBackButton(
      onTap: () {
        Navigator.pop(context, true);
      },
    );
  }

  Widget _buildHeaderProfile() {
    return Center(
      key: ValueKey('profile_$_refreshKey'),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _ringColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: _ringColors.last.withAlpha(56),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: _buildAvatar(radius: 45),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _name.isEmpty ? '-' : _name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: navy,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          if (_role.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    purple,
                    pink,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                _role,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _asset(
                'user',
                size: 16,
                fallback: Icons.person_outline,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Information personnel',
                  style: TextStyle(
                    color: navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Modifier le profil',
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MonProfilScreen(
                          userId: _ref?.id ?? widget.userId,
                          isChef: _ref?.collection == collectionChef ||
                              widget.isChef,
                        ),
                      ),
                    );

                    if (!mounted) return;
                    if (_sub == null) {
                      await _refreshData();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E9FB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _asset(
                          'modif',
                          size: 12,
                          fallback: Icons.edit,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Modifier',
                          style: TextStyle(
                            color: purple,
                            fontSize: 10,
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
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _infoField(
                  icon: 'user',
                  fallback: Icons.person_outline,
                  label: 'Nom Complet',
                  value: _fullName,
                ),
              ),
              _buildDivider(),
              Expanded(
                child: _infoField(
                  icon: 'tt',
                  fallback: Icons.phone_outlined,
                  label: 'Telephone',
                  value: _phone,
                ),
              ),
              _buildDivider(),
              Expanded(
                child: _infoField(
                  icon: 'mail',
                  fallback: Icons.email_outlined,
                  label: 'Email',
                  value: _email,
                ),
              ),
              _buildDivider(),
              Expanded(
                child: _infoField(
                  icon: 'adr',
                  fallback: Icons.location_on_outlined,
                  label: 'Adresse',
                  value: _address,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: dividerColor,
    );
  }

  Widget _infoField({
    required String icon,
    required IconData fallback,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: Center(
            child: _asset(
              icon,
              size: 16,
              fallback: fallback,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            color: grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.trim().isEmpty ? '-' : value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _asset(
              'doc',
              size: 22,
              color: navy,
              fallback: Icons.description_outlined,
            ),
            const SizedBox(width: 6),
            const Text(
              'Mes Documents',
              style: TextStyle(
                color: navy,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: _voirTousLesDocuments,
          child: const Row(
            children: [
              Text(
                'Voir tous',
                style: TextStyle(
                  color: purple,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 15,
                color: purple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsScrollable() {
    if (documents.isEmpty) {
      return const Center(
        child: Text(
          'Aucun document',
          style: TextStyle(
            color: grey,
            fontSize: 11,
          ),
        ),
      );
    }

    return ClipRect(
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: 0,
          right: 2,
          bottom: 4,
        ),
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        itemCount: documents.length,
        itemBuilder: (context, index) {
          final doc = documents[index];
          return _documentTile(doc);
        },
      ),
    );
  }

  Widget _documentTile(UserDocument doc) {
    final List<String> protectedCategories = ['photos', 'videos'];

    final bool isProtected =
        protectedCategories.contains(doc.label.toLowerCase());

    final List<String> defaultCategories = ['cv', 'diplomes', 'certificats'];
    final bool isDefaultCategory =
        defaultCategories.contains(doc.label.toLowerCase());

    final bool isRenamedDefault = doc.originalType != null;

    final bool isCustomCategory =
        doc.id != null && doc.icon != null && !isRenamedDefault;

    final bool hasMenu = !isProtected &&
        (isCustomCategory || isDefaultCategory || isRenamedDefault);

    return GestureDetector(
      onTap: () {
        // ⭐ NOUVEAU : on transmet isVisitor + canDownload aux écrans enfants
        final bool isV = widget.isVisitor;
        final bool canD = widget.canDownload;

        if (isRenamedDefault) {
          switch (doc.originalType!.toLowerCase()) {
            case 'cv':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CvScreen(
                    ownerName: _fullName,
                    memberId: _memberId,
                    isVisitor: isV,
                    canDownload: canD,
                  ),
                ),
              );
              break;
            case 'diplomes':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DiplomeScreen(
                    ownerName: _fullName,
                    memberId: _memberId,
                    isVisitor: isV,
                    canDownload: canD,
                  ),
                ),
              );
              break;
            case 'certificats':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Certaficat(
                    ownerName: _fullName,
                    memberId: _memberId,
                    isVisitor: isV,
                    canDownload: canD,
                  ),
                ),
              );
              break;
            case 'videos':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MesVideosScreen(
                    memberId: _memberId,
                    isVisitor: isV,
                    canDownload: canD,
                  ),
                ),
              );
              break;
            case 'photos':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MesPhotosScreen(
                    memberId: _memberId,
                    isVisitor: isV,
                    canDownload: canD,
                  ),
                ),
              );
              break;
          }
          return;
        }

        if (isCustomCategory) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategorieDocumentsScreen(
                categorieNom: doc.label,
                categorieId: doc.id,
                documents: const [],
                memberId: _memberId,
                isVisitor: isV,
                canDownload: canD,
              ),
            ),
          );
          return;
        }

        switch (doc.label.toLowerCase()) {
          case 'videos':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MesVideosScreen(
                  memberId: _memberId,
                  isVisitor: isV,
                  canDownload: canD,
                ),
              ),
            );
            break;
          case 'photos':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MesPhotosScreen(
                  memberId: _memberId,
                  isVisitor: isV,
                  canDownload: canD,
                ),
              ),
            );
            break;
          case 'cv':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CvScreen(
                  ownerName: _fullName,
                  memberId: _memberId,
                  isVisitor: isV,
                  canDownload: canD,
                ),
              ),
            );
            break;
          case 'diplomes':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DiplomeScreen(
                  ownerName: _fullName,
                  memberId: _memberId,
                  isVisitor: isV,
                  canDownload: canD,
                ),
              ),
            );
            break;
          case 'certificats':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Certaficat(
                  ownerName: _fullName,
                  memberId: _memberId,
                  isVisitor: isV,
                  canDownload: canD,
                ),
              ),
            );
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ouverture de ${doc.label}...'),
              ),
            );
        }
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: docCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFE8E5F5),
            width: 0.7,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFE8E5F5),
                  width: 0.7,
                ),
              ),
              child: Center(
                child: doc.icon != null
                    ? Icon(
                        doc.icon,
                        color: doc.color ?? navy,
                        size: 18,
                      )
                    : _asset(
                        doc.assetIcon,
                        size: 18,
                        color: navy,
                        fallback: Icons.insert_drive_file,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    doc.subtitle,
                    style: const TextStyle(
                      fontSize: 9,
                      color: grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (hasMenu) _buildDocumentMenu(doc) else const SizedBox(width: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentMenu(UserDocument doc) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: '',
      offset: const Offset(-5, 22),
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      icon: const Icon(
        Icons.more_horiz,
        color: navy,
        size: 17,
      ),
      onSelected: (value) {
        if (value == 'modifier') {
          _modifierDocument(doc);
        }

        if (value == 'supprimer') {
          _supprimerDocument(doc);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'modifier',
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 14,
                color: navy,
              ),
              const SizedBox(width: 6),
              Text(
                'Modifier',
                style: TextStyle(
                  color: navy,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'supprimer',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 14,
                color: Colors.red,
              ),
              SizedBox(width: 6),
              Text(
                'Supprimer',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddDocumentButton(BuildContext context) {
    return GestureDetector(
      onTap: _ajouterCategorie,
      child: Container(
        width: double.infinity,
        height: 40,
        decoration: BoxDecoration(
          color: purple,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: purple.withAlpha(77),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              'Ajouter une categorie',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
