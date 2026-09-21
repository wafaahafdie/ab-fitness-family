// lib/DemandeAccesScreen.dart - EMAIL DANS LES 2 ONGLETS ✅
// ⭐ CORRIGÉ : bouton retour élégant
// ⭐ AJOUTÉ : icône supprimer sur chaque demande + fenêtre de confirmation
// ⭐ FIX : filtre chefId → chaque chef ne voit QUE ses propres demandes
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'AutorisationScreen.dart';

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1E2235);
const Color purple = Color(0xFF6046F4);
const Color pink = Color(0xFFE91E9B);
const Color grey = Color(0xFF9E9EAE);
const Color lightPurple = Color(0xFF9C27B0);
const Color borderPurple = Color(0xFF890CC2);
const Color green = Color(0xFF4CAF50);
const Color red = Color(0xFFE53935);

const Color borderGradientStart = Color(0xFFD9A8E8);
const Color borderGradientEnd = Color(0xFFF3CDE4);

const Color greenBorderLight = Color(0xFFB5E6BA);
const Color redBorderLight = Color(0xFFF5BCBC);

// ============================================================
// HELPER BASE64
// ============================================================

Uint8List? _decodeBase64Image(String? photoUrl) {
  if (photoUrl == null || photoUrl.isEmpty) return null;
  if (photoUrl.startsWith('assets/') ||
      photoUrl.startsWith('http://') ||
      photoUrl.startsWith('https://')) {
    return null;
  }
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
    debugPrint('❌ Base64: $e');
    return null;
  }
}

Widget _buildAvatar(String? photoUrl, {double radius = 24}) {
  final size = radius * 2;
  const bg = Color(0xFFF0F0F2);

  if (photoUrl == null || photoUrl.isEmpty) return _defaultAvatar(size, radius);

  if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
    return _wrap(
      bg,
      size,
      Image.network(photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAvatarChild(radius)),
    );
  }
  if (photoUrl.startsWith('assets/')) {
    return _wrap(
      bg,
      size,
      Image.asset(photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAvatarChild(radius)),
    );
  }
  final bytes = _decodeBase64Image(photoUrl);
  if (bytes != null && bytes.isNotEmpty) {
    return _wrap(
      bg,
      size,
      Image.memory(bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _defaultAvatarChild(radius)),
    );
  }
  return _defaultAvatar(size, radius);
}

Widget _wrap(Color bg, double size, Widget child) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: ClipOval(child: child),
    );

Widget _defaultAvatar(double size, double radius) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFF0F0F2),
        shape: BoxShape.circle,
      ),
      child: _defaultAvatarChild(radius),
    );

Widget _defaultAvatarChild(double radius) =>
    Icon(Icons.person, color: grey, size: radius * 1.1);

// ============================================================
// DEMANDE ACCES SCREEN
// ============================================================

class DemandeAccesScreen extends StatefulWidget {
  const DemandeAccesScreen({super.key});

  @override
  State<DemandeAccesScreen> createState() => _DemandeAccesScreenState();
}

class _DemandeAccesScreenState extends State<DemandeAccesScreen> {
  String _selectedTab = 'En attente';

  String? _chefId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _demandes = [];
  StreamSubscription<QuerySnapshot>? _demandesSub;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _audioInitialized = false;

  int _lastKnownCount = 0;
  bool _isFirstLoad = true;

  Timer? _refreshTimer;

  // ⭐ Demandes en cours de suppression (évite les doubles clics)
  final Set<String> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _initAudio();
    _init();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      _audioInitialized = true;
      debugPrint('✅ Audio initialisé');
    } catch (e) {
      debugPrint('⚠️ Erreur audio: $e');
    }
  }

  Future<void> _init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _chefId = user.uid;
    _listenDemandes();
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ FIX : écoute filtrée sur chefId = uid du chef connecté
  // ═══════════════════════════════════════════════════════════
  void _listenDemandes() {
    _demandesSub?.cancel();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _chefId = user.uid;

    // ⭐ On ne récupère QUE les demandes destinées à ce chef
    _demandesSub = FirebaseFirestore.instance
        .collection('DemandesAcces')
        .where('chefId', isEqualTo: _chefId) // ⭐ FILTRE CRUCIAL
        .snapshots()
        .listen((snapshot) async {
      if (!mounted) return;

      final List<Map<String, dynamic>> list = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        // ⭐ Double sécurité côté client (au cas où d'anciens docs
        // n'auraient pas de champ chefId → on les ignore aussi)
        final String docChefId = data['chefId']?.toString() ?? '';
        if (docChefId.isNotEmpty && docChefId != _chefId) continue;

        final visiteurId = data['visiteurId']?.toString() ?? '';
        if (visiteurId.isNotEmpty) {
          try {
            final visiteurDoc = await FirebaseFirestore.instance
                .collection('Visiteurs')
                .doc(visiteurId)
                .get();

            if (visiteurDoc.exists) {
              final vData = visiteurDoc.data()!;

              final photoFromVisiteur = vData['photoUrl']?.toString() ?? '';
              if (photoFromVisiteur.isNotEmpty &&
                  (data['visiteurPhoto']?.toString() ?? '').isEmpty) {
                data['visiteurPhoto'] = photoFromVisiteur;
              }

              final emailFromVisiteur = vData['email']?.toString() ?? '';
              if (emailFromVisiteur.isNotEmpty &&
                  (data['visiteurEmail']?.toString() ?? '').isEmpty) {
                data['visiteurEmail'] = emailFromVisiteur;
              }

              if ((data['visiteurNom']?.toString() ?? '').isEmpty) {
                final fullName = vData['nomComplet']?.toString() ?? '';
                if (fullName.isNotEmpty) {
                  data['visiteurNom'] = fullName;
                }
              }

              if ((data['visiteurTel']?.toString() ?? '').isEmpty) {
                final tel = vData['téléphone']?.toString() ??
                    vData['telephone']?.toString() ??
                    '';
                if (tel.isNotEmpty) {
                  data['visiteurTel'] = tel;
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ Erreur récup visiteur: $e');
          }
        }

        list.add(data);
      }

      list.sort((a, b) {
        final da = a['dateDemande'];
        final db = b['dateDemande'];
        if (da is Timestamp && db is Timestamp) return db.compareTo(da);
        return 0;
      });

      final enAttenteCount =
          list.where((d) => d['statut']?.toString() == 'en_attente').length;

      if (!_isFirstLoad && enAttenteCount > _lastKnownCount) {
        _playNotificationSound();
        _showNewDemandeSnackBar();
      }

      _isFirstLoad = false;
      _lastKnownCount = enAttenteCount;

      if (mounted) {
        setState(() {
          _demandes = list;
          _isLoading = false;
        });
      }
    }, onError: (e) {
      debugPrint('❌ Erreur stream: $e');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _playNotificationSound() async {
    try {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);

      if (_audioInitialized) {
        try {
          await _audioPlayer.stop();
          await _audioPlayer.play(
            AssetSource('sounds/notification.mp3'),
            volume: 1.0,
          );
        } catch (e) {
          debugPrint('⚠️ MP3 manquant: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Sonnerie: $e');
    }
  }

  void _showNewDemandeSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '🔔 Nouvelle demande reçue !',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: borderPurple,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _demandesSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredDemandes {
    return _demandes.where((d) {
      final statut = d['statut']?.toString() ?? 'en_attente';
      if (_selectedTab == 'En attente') {
        return statut == 'en_attente';
      } else {
        return statut != 'en_attente';
      }
    }).toList();
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Date inconnue';
    try {
      DateTime dt;
      if (date is Timestamp) {
        dt = date.toDate();
      } else if (date is String) {
        dt = DateTime.parse(date);
      } else {
        return 'Date inconnue';
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (e) {
      return 'Date inconnue';
    }
  }

  String _formatRelativeTime(dynamic date) {
    if (date == null) return '';
    try {
      DateTime dt;
      if (date is Timestamp) {
        dt = date.toDate();
      } else if (date is String) {
        dt = DateTime.parse(date);
      } else {
        return '';
      }

      final diff = DateTime.now().difference(dt);

      if (diff.inSeconds < 60) {
        return 'il y a ${diff.inSeconds} sec';
      } else if (diff.inMinutes < 60) {
        return 'il y a ${diff.inMinutes} min';
      } else if (diff.inHours < 24) {
        return 'il y a ${diff.inHours} h';
      } else if (diff.inDays < 7) {
        return 'il y a ${diff.inDays} j';
      } else if (diff.inDays < 30) {
        final weeks = (diff.inDays / 7).floor();
        return 'il y a $weeks sem';
      } else if (diff.inDays < 365) {
        final months = (diff.inDays / 30).floor();
        return 'il y a $months mois';
      } else {
        final years = (diff.inDays / 365).floor();
        return 'il y a $years an${years > 1 ? 's' : ''}';
      }
    } catch (e) {
      return '';
    }
  }

  Future<void> _accepterDemande(Map<String, dynamic> demande) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AutorisationScreen(demande: demande),
      ),
    );
    if (result == true) {
      await _updateStatut(demande['id'], 'acceptee');
      _notifyVisiteur(demande, accepted: true);
    }
  }

  Future<void> _refuserDemande(Map<String, dynamic> demande) async {
    await _updateStatut(demande['id'], 'refusee');
    _notifyVisiteur(demande, accepted: false);
  }

  Future<void> _updateStatut(String docId, String statut) async {
    try {
      await FirebaseFirestore.instance
          .collection('DemandesAcces')
          .doc(docId)
          .update({
        'statut': statut,
        'dateReponse': FieldValue.serverTimestamp(),
        'lue': false,
      });
    } catch (e) {
      debugPrint('❌ Statut: $e');
    }
  }

  Future<void> _notifyVisiteur(Map<String, dynamic> demande,
      {required bool accepted}) async {
    try {
      final visiteurId = demande['visiteurId']?.toString() ?? '';
      if (visiteurId.isEmpty) return;

      await FirebaseFirestore.instance.collection('Notifications').add({
        'userId': visiteurId,
        'titre': accepted ? 'Demande acceptée' : 'Demande refusée',
        'message': accepted
            ? '✅ Votre demande a été acceptée.'
            : '❌ Votre demande a été refusée.',
        'type': accepted ? 'demande_acceptee' : 'demande_refusee',
        'lue': false,
        'date': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Notif: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ⭐ SUPPRESSION D'UNE DEMANDE
  // ═══════════════════════════════════════════════════════

  /// Affiche la fenêtre de confirmation, puis supprime si confirmé.
  Future<void> _confirmerSuppression(Map<String, dynamic> demande) async {
    final String docId = demande['id']?.toString() ?? '';
    if (docId.isEmpty || _deletingIds.contains(docId)) return;

    final String nom = (demande['visiteurNom']?.toString() ?? '').isNotEmpty
        ? demande['visiteurNom'].toString()
        : 'Visiteur';

    HapticFeedback.lightImpact();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: red.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: red,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Supprimer la demande',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: navy,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    color: grey,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(
                      text:
                          'Voulez-vous vraiment supprimer cette demande du visiteur ',
                    ),
                    TextSpan(
                      text: nom,
                      style: const TextStyle(
                        color: navy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' ?'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cette action est irréversible.',
                textAlign: TextAlign.center,
                style: TextStyle(color: grey, fontSize: 11),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(false),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE0E0E8),
                            width: 1.2,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Annuler',
                            style: TextStyle(
                              color: navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(true),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'Supprimer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _supprimerDemande(demande, nom);
    }
  }

  /// Supprime réellement le document dans Firestore.
  /// Le stream `_listenDemandes` met la liste à jour automatiquement.
  Future<void> _supprimerDemande(
      Map<String, dynamic> demande, String nom) async {
    final String docId = demande['id']?.toString() ?? '';
    if (docId.isEmpty || _deletingIds.contains(docId)) return;
    _deletingIds.add(docId);

    try {
      final db = FirebaseFirestore.instance;

      final String visiteurId = demande['visiteurId']?.toString() ?? '';
      final String chefId = (demande['chefId']?.toString() ?? '').isNotEmpty
          ? demande['chefId'].toString()
          : (_chefId ?? '');

      // ⭐ Nom du chef (affiché au visiteur dans sa notification)
      String chefNom = demande['chefNom']?.toString() ?? '';
      if (chefNom.isEmpty && chefId.isNotEmpty) {
        try {
          final chefDoc =
              await db.collection('Chef de Famille').doc(chefId).get();
          final c = chefDoc.data();
          chefNom = c?['fullName']?.toString() ??
              c?['nom']?.toString() ??
              c?['phone']?.toString() ??
              '';
        } catch (e) {
          debugPrint('⚠️ Nom chef: $e');
        }
      }
      if (chefNom.isEmpty) chefNom = 'Chef de famille';

      // ⭐ Batch atomique : suppression de la demande + notification au visiteur
      final batch = db.batch();
      batch.delete(db.collection('DemandesAcces').doc(docId));

      if (visiteurId.isNotEmpty) {
        final notifRef = db.collection('Notifications').doc();
        batch.set(notifRef, {
          'userId': visiteurId,
          'chefId': chefId,
          'chefNom': chefNom,
          'titre': 'Demande supprimée',
          'message': '🗑️ Le chef de famille a supprimé votre demande.',
          'type': 'demande_supprimee',
          'motif': demande['motif']?.toString() ?? '',
          'statutAvant': demande['statut']?.toString() ?? 'en_attente',
          'lue': false,
          'date': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Retrait local immédiat (le stream confirmera ensuite)
      if (mounted) {
        setState(() {
          _demandes.removeWhere((d) => d['id'] == docId);
        });
      }

      _showSnack('Demande de $nom supprimée');
    } catch (e) {
      debugPrint('❌ Suppression: $e');
      _showSnack('Erreur lors de la suppression', isError: true);
    } finally {
      _deletingIds.remove(docId);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? red : green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
      errorBuilder: (context, error, stackTrace) {
        return Icon(fallback ?? Icons.circle, size: size, color: color ?? navy);
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDemandes;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 13, 18, 16),
              color: Colors.white,
              child: Row(
                children: [
                  // ⭐ BOUTON RETOUR ÉLÉGANT
                  _ElegantBackButton(
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Demande D\'accès',
                    style: TextStyle(
                      color: navy,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFF0F0F5)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTab('En attente'),
                  const SizedBox(width: 20),
                  _buildTab('Traitées'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: borderPurple))
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) =>
                              _buildDemandeCard(filtered[index]),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFF0EDFF),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.inbox_outlined, color: borderPurple, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedTab == 'En attente'
                ? 'Aucune demande en attente'
                : 'Aucune demande traitée',
            style: const TextStyle(
              color: navy,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedTab == 'En attente'
                ? 'Les nouvelles demandes s\'afficheront ici'
                : 'Vos décisions s\'afficheront ici',
            style: const TextStyle(color: grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title) {
    final isSelected = _selectedTab == title;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = title),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? navy : grey,
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 30,
            height: 3,
            decoration: BoxDecoration(
              color: isSelected ? borderPurple : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  // ⭐ Petite icône poubelle (utilisée dans chaque carte)
  Widget _buildDeleteButton(Map<String, dynamic> demande) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _confirmerSuppression(demande),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: red,
          size: 17,
        ),
      ),
    );
  }

  Widget _buildDemandeCard(Map<String, dynamic> demande) {
    final String statut = demande['statut']?.toString() ?? 'en_attente';
    final bool isTraitee = statut != 'en_attente';
    final bool isAcceptee = statut == 'acceptee' || statut == 'accepte';

    final String nom = demande['visiteurNom']?.toString() ?? 'Visiteur';
    final String email = demande['visiteurEmail']?.toString() ?? '';
    final String phone = demande['visiteurTel']?.toString() ?? '';
    final String motif = demande['motif']?.toString() ?? '';
    final String relation = demande['relation']?.toString() ?? '';
    final String photo = demande['visiteurPhoto']?.toString() ?? '';

    final String dateDemande = _formatDate(demande['dateDemande']);

    final String tempsRelatifDemande =
        _formatRelativeTime(demande['dateDemande']);
    final String tempsRelatifReponse =
        _formatRelativeTime(demande['dateReponse'] ?? demande['dateDemande']);

    Gradient? borderGradient;
    Color? borderSolidColor;
    Color shadowColor;

    if (!isTraitee) {
      borderGradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [borderGradientStart, borderGradientEnd],
      );
      shadowColor = borderPurple.withOpacity(0.05);
    } else if (isAcceptee) {
      borderSolidColor = greenBorderLight;
      shadowColor = green.withOpacity(0.08);
    } else {
      borderSolidColor = redBorderLight;
      shadowColor = red.withOpacity(0.08);
    }

    final Widget cardContent = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(photo.isNotEmpty ? photo : null, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          nom,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (isTraitee)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAcceptee ? green : red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isAcceptee ? 'Acceptée' : 'Refusée',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 11,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tempsRelatifReponse,
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    // ⭐ ICÔNE SUPPRIMER (en attente + traitées)
                    const SizedBox(width: 8),
                    _buildDeleteButton(demande),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (email.isNotEmpty) ...[
            Row(
              children: [
                _asset('em', size: 14, fallback: Icons.email_outlined),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: grey, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              _asset('tl', size: 14, fallback: Icons.phone_outlined),
              const SizedBox(width: 6),
              Text(
                phone,
                style: const TextStyle(color: grey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (relation.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.people_outline, size: 14, color: grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    relation,
                    style: const TextStyle(color: grey, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (!isTraitee)
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Demandé le :$dateDemande',
                    style: const TextStyle(
                      color: grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          if (!isTraitee && motif.isNotEmpty) ...[
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12),
                children: [
                  const TextSpan(
                    text: 'Motif : ',
                    style: TextStyle(color: navy, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: motif,
                    style: const TextStyle(
                        color: navy, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
          if (!isTraitee) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'Accepter',
                    color: green,
                    onTap: () => _accepterDemande(demande),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionButton(
                    label: 'Refuser',
                    color: red,
                    onTap: () => _refuserDemande(demande),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Reçue $tempsRelatifDemande',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: borderGradient,
        color: borderSolidColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.2),
      child: cardContent,
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
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
