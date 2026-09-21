import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1F2A6B);
const Color grey = Color(0xFF9E9EAE);
const Color lightPurple = Color(0xFF9C27B0);
const Color borderPurple = Color(0xFF890CC2);
const Color darkBlue = Color(0xFF1F2A6B);
const Color red = Color(0xFFE53E6B);
const Color green = Color(0xFF4CAF50);
const Color orange = Color(0xFFFF9800);
// ⭐ Couleur du badge "Supprimée"
const Color deletedGrey = Color(0xFF6D6D80);

// ============================================================
// MODELE NOTIFICATION VISITEUR
// ============================================================

class NotifVisiteur {
  final String id;
  final String chefNom;
  final String chefPhotoUrl;
  final String statut; // en_attente | acceptee | refusee | supprimee
  final DateTime? dateReponse;
  final DateTime? dateDemande;
  final String? motif;
  final List<String> permissionsAccordees;
  final String? nomEnfant;
  final bool lue;

  // ⭐ 'DemandesAcces' (demande normale) ou 'Notifications' (demande supprimée)
  final String collection;

  NotifVisiteur({
    required this.id,
    required this.chefNom,
    required this.chefPhotoUrl,
    required this.statut,
    this.dateReponse,
    this.dateDemande,
    this.motif,
    this.permissionsAccordees = const [],
    this.nomEnfant,
    this.lue = false,
    this.collection = 'DemandesAcces',
  });

  /// Date utilisée pour l'affichage et le tri
  DateTime get dateEvenement =>
      dateReponse ?? dateDemande ?? DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  // ----------------------------------------------------------
  // Depuis la collection DemandesAcces
  // ----------------------------------------------------------
  factory NotifVisiteur.fromFirestore(
    String docId,
    Map<String, dynamic> data,
    Map<String, dynamic>? chefData,
  ) {
    final perms = data['permissions'] as Map<String, dynamic>? ?? {};
    final listePerms = <String>[];

    if (perms['voirCv'] == true) listePerms.add('cv');
    if (perms['voirDiplomes'] == true) listePerms.add('diplomes');
    if (perms['voirCertificats'] == true) listePerms.add('certificats');
    if (perms['voirDocuments'] == true) listePerms.add('documents');
    if (perms['voirPhotos'] == true) listePerms.add('photos');
    if (perms['voirVideos'] == true) listePerms.add('videos');

    return NotifVisiteur(
      id: docId,
      chefNom: data['chefNom'] ??
          chefData?['fullName'] ??
          chefData?['nom'] ??
          chefData?['phone'] ??
          'Chef de famille',
      chefPhotoUrl: chefData?['photoUrl'] ?? '',
      statut: (data['statut'] ?? 'en_attente').toString().toLowerCase(),
      dateReponse: _parseDate(data['dateReponse']),
      dateDemande: _parseDate(data['dateDemande']),
      motif: data['motif'],
      permissionsAccordees: listePerms,
      nomEnfant: data['nomEnfant'],
      lue: data['lue'] == true,
      collection: 'DemandesAcces',
    );
  }

  // ----------------------------------------------------------
  // ⭐ Depuis la collection Notifications (type: demande_supprimee)
  // ----------------------------------------------------------
  factory NotifVisiteur.fromSuppression(
    String docId,
    Map<String, dynamic> data,
    Map<String, dynamic>? chefData,
  ) {
    final motif = data['motif']?.toString() ?? '';

    return NotifVisiteur(
      id: docId,
      chefNom: (data['chefNom']?.toString() ?? '').isNotEmpty
          ? data['chefNom'].toString()
          : (chefData?['fullName'] ??
              chefData?['nom'] ??
              chefData?['phone'] ??
              'Chef de famille'),
      chefPhotoUrl: chefData?['photoUrl'] ?? '',
      statut: 'supprimee',
      // serverTimestamp peut être null localement le temps de la synchro
      dateDemande: _parseDate(data['date']) ?? DateTime.now(),
      motif: motif.isEmpty ? null : motif,
      lue: data['lue'] == true,
      collection: 'Notifications',
    );
  }
}

// ============================================================
// NOTIFICATION VISITEUR SCREEN
// ============================================================

class NotifV extends StatefulWidget {
  const NotifV({Key? key}) : super(key: key);

  @override
  State<NotifV> createState() => _NotifVState();
}

class _NotifVState extends State<NotifV> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache des infos chef (évite de relire le même document)
  final Map<String, Map<String, dynamic>?> _chefCache = {};

  // ⭐ Stream créé une seule fois (et non à chaque build)
  late final Stream<List<NotifVisiteur>> _notifStream;

  @override
  void initState() {
    super.initState();
    _notifStream = _buildMergedStream();
    _playNotificationSound();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(
        AssetSource('sounds/notification.mp3'),
        volume: 0.8,
      );
    } catch (e) {
      debugPrint('🔊 Erreur audio: $e');
    }
  }

  // ==========================================================
  // MARQUER COMME LUE
  // ==========================================================
  Future<void> _markAsRead(NotifVisiteur n) async {
    if (n.lue) return;

    try {
      await _firestore
          .collection(n.collection) // ⭐ DemandesAcces ou Notifications
          .doc(n.id)
          .update({'lue': true});
      debugPrint('✅ Notification ${n.id} marquée comme lue');
    } catch (e) {
      debugPrint('❌ Erreur markAsRead: $e');
    }
  }

  // ==========================================================
  // FORMAT DATE RELATIF
  // ==========================================================
  String _formatRelativeTime(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60)
      return 'Il y a ${diff.inSeconds < 0 ? 0 : diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 30) return 'Il y a ${diff.inDays} j';
    return 'Il y a ${(diff.inDays / 30).floor()} mois';
  }

  // ==========================================================
  // COULEUR DU BADGE
  // ==========================================================
  Color _badgeColor(String statut) {
    switch (statut) {
      case 'acceptee':
      case 'acceptée':
        return green;
      case 'refusee':
      case 'refusée':
        return red;
      case 'supprimee': // ⭐
        return deletedGrey;
      default:
        return orange;
    }
  }

  String _badgeLabel(String statut) {
    switch (statut) {
      case 'acceptee':
      case 'acceptée':
        return 'Acceptée';
      case 'refusee':
      case 'refusée':
        return 'Refusée';
      case 'supprimee': // ⭐
        return 'Supprimée';
      default:
        return 'En attente';
    }
  }

  // ==========================================================
  // LISTE DES PERMISSIONS
  // ==========================================================
  String _buildPermissionsList(List<String> perms) {
    if (perms.isEmpty) return '';

    final Map<String, String> labels = {
      'cv': 'les CV',
      'diplomes': 'les diplômes',
      'certificats': 'les certificats',
      'documents': 'les documents',
      'photos': 'les photos',
      'videos': 'les vidéos',
    };

    final libelles = perms
        .where((p) => labels.containsKey(p))
        .map((p) => labels[p]!)
        .toList();

    if (libelles.isEmpty) return '';
    if (libelles.length == 1) return libelles.first;
    if (libelles.length == 2) return '${libelles[0]} et ${libelles[1]}';

    final tousSaufDernier = libelles.sublist(0, libelles.length - 1).join(', ');
    return '$tousSaufDernier et ${libelles.last}';
  }

  // ==========================================================
  // TEXTES SELON STATUT
  // ==========================================================
  Map<String, String> _buildTexts(NotifVisiteur n) {
    final enfant = (n.nomEnfant != null && n.nomEnfant!.isNotEmpty)
        ? ' de sa fille ${n.nomEnfant}'
        : '';

    final motifTxt = (n.motif != null && n.motif!.isNotEmpty)
        ? ' Votre demande était : "${n.motif}".'
        : '';

    switch (n.statut) {
      case 'acceptee':
      case 'acceptée':
        final liste = _buildPermissionsList(n.permissionsAccordees);

        if (liste.isEmpty) {
          return {
            'title': 'Le chef de famille, ',
            'action':
                'a accepté votre demande. Vous pouvez consulter ses informations$enfant.$motifTxt',
          };
        }

        return {
          'title': 'Le chef de famille, ',
          'action': 'a accepté de vous laisser voir $liste$enfant.$motifTxt',
        };

      case 'refusee':
      case 'refusée':
        return {
          'title': 'Le chef de famille, ',
          'action': 'a refusé votre demande d\'accès à sa famille.$motifTxt',
        };

      // ⭐ MODIFIÉ : le chef a supprimé la demande → on affiche le motif
      case 'supprimee':
        final motifSuppr = (n.motif ?? '').trim();
        if (motifSuppr.isNotEmpty) {
          return {
            'title': 'Le chef de famille, ',
            'action': 'a supprimé votre demande de $motifSuppr.',
          };
        }
        return {
          'title': 'Le chef de famille, ',
          'action': 'a supprimé votre demande d\'accès à sa famille.',
        };

      default:
        return {
          'title': 'Le chef de famille, ',
          'action': 'n\'a pas encore répondu à votre demande.$motifTxt',
        };
    }
  }

  // ==========================================================
  // INFOS CHEF (avec cache)
  // ==========================================================
  Future<Map<String, dynamic>?> _getChefData(dynamic chefId) async {
    final id = chefId?.toString() ?? '';
    if (id.isEmpty) return null;
    if (_chefCache.containsKey(id)) return _chefCache[id];

    try {
      final chefDoc =
          await _firestore.collection('Chef de Famille').doc(id).get();
      final data = chefDoc.data();
      _chefCache[id] = data;
      return data;
    } catch (e) {
      debugPrint('❌ Erreur chef: $e');
      return null;
    }
  }

  // ==========================================================
  // STREAM 1 : DEMANDES D'ACCÈS DU VISITEUR
  // ==========================================================
  Stream<List<NotifVisiteur>> _streamDemandes(String uid) {
    return _firestore
        .collection('DemandesAcces')
        .where('visiteurId', isEqualTo: uid)
        .orderBy('dateDemande', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<NotifVisiteur> result = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final chefData = await _getChefData(data['chefId']);
        result.add(NotifVisiteur.fromFirestore(doc.id, data, chefData));
      }

      return result;
    });
  }

  // ==========================================================
  // ⭐ STREAM 2 : DEMANDES SUPPRIMÉES PAR LE CHEF
  // ==========================================================
  Stream<List<NotifVisiteur>> _streamSuppressions(String uid) {
    return _firestore
        .collection('Notifications')
        .where('userId', isEqualTo: uid)
        .where('type', isEqualTo: 'demande_supprimee')
        .snapshots()
        .asyncMap((snapshot) async {
      final List<NotifVisiteur> result = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final chefData = await _getChefData(data['chefId']);
        result.add(NotifVisiteur.fromSuppression(doc.id, data, chefData));
      }

      return result;
    });
  }

  // ==========================================================
  // ⭐ FUSION DES 2 STREAMS (triés du plus récent au plus ancien)
  // ==========================================================
  Stream<List<NotifVisiteur>> _buildMergedStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(<NotifVisiteur>[]);

    late final StreamController<List<NotifVisiteur>> controller;
    StreamSubscription<List<NotifVisiteur>>? subDemandes;
    StreamSubscription<List<NotifVisiteur>>? subSuppressions;

    List<NotifVisiteur> demandes = [];
    List<NotifVisiteur> suppressions = [];
    bool demandesReady = false;
    bool suppressionsReady = false;

    void emit() {
      if (!demandesReady || !suppressionsReady || controller.isClosed) return;
      final all = <NotifVisiteur>[...demandes, ...suppressions];
      all.sort((a, b) => b.dateEvenement.compareTo(a.dateEvenement));
      controller.add(all);
    }

    controller = StreamController<List<NotifVisiteur>>(
      onListen: () {
        subDemandes = _streamDemandes(uid).listen(
          (list) {
            demandes = list;
            demandesReady = true;
            emit();
          },
          onError: (Object e, StackTrace st) {
            if (!controller.isClosed) controller.addError(e, st);
          },
        );

        subSuppressions = _streamSuppressions(uid).listen(
          (list) {
            suppressions = list;
            suppressionsReady = true;
            emit();
          },
          // Une erreur ici ne doit pas casser tout l'écran
          onError: (Object e, StackTrace st) {
            debugPrint('❌ Erreur suppressions: $e');
            suppressions = [];
            suppressionsReady = true;
            emit();
          },
        );
      },
      onCancel: () async {
        await subDemandes?.cancel();
        await subSuppressions?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ═══════════════════════════════════════════════
            // HEADER
            // ═══════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 18, 12),
              child: Row(
                children: [
                  _ElegantBackButton(
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      color: navy,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // ═══════════════════════════════════════════════
            // LISTE DYNAMIQUE
            // ═══════════════════════════════════════════════
            Expanded(
              child: StreamBuilder<List<NotifVisiteur>>(
                stream: _notifStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: navy),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Erreur: ${snapshot.error}',
                          style: const TextStyle(color: red, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final notifs = snapshot.data ?? [];

                  if (notifs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aucune notification',
                        style: TextStyle(color: grey, fontSize: 13),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
                    itemCount: notifs.length,
                    itemBuilder: (context, index) {
                      final n = notifs[index];
                      final texts = _buildTexts(n);

                      return NotificationCardV(
                        title: texts['title']!,
                        boldText: n.chefNom,
                        action: texts['action']!,
                        time: _formatRelativeTime(
                          n.dateReponse ?? n.dateDemande,
                        ),
                        statutBadge: _badgeLabel(n.statut),
                        badgeColor: _badgeColor(n.statut),
                        photoUrl: n.chefPhotoUrl,
                        lue: n.lue,
                        onTap: () => _markAsRead(n),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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

// ============================================================
// WIDGET : NOTIFICATION CARD VISITEUR
// ============================================================

class NotificationCardV extends StatelessWidget {
  final String title;
  final String boldText;
  final String action;
  final String time;
  final String statutBadge;
  final Color badgeColor;
  final String? photoUrl;
  final bool lue;
  final VoidCallback? onTap;

  const NotificationCardV({
    Key? key,
    required this.title,
    required this.boldText,
    required this.action,
    required this.time,
    required this.statutBadge,
    required this.badgeColor,
    this.photoUrl,
    this.lue = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: lue ? const Color(0xFFF9F9FB) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: badgeColor.withOpacity(lue ? 0.25 : 0.55),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PHOTO DE PROFIL
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: badgeColor.withOpacity(lue ? 0.4 : 1.0),
                  width: 1.6,
                ),
              ),
              child: ClipOval(child: _buildAvatar()),
            ),
            const SizedBox(width: 12),

            // CONTENU TEXTE
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12.5,
                        // ⭐ Corps du texte : grisé si lu, navy si non lu
                        color: lue ? darkBlue.withOpacity(0.6) : darkBlue,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: title,
                          style: const TextStyle(fontWeight: FontWeight.w400),
                        ),
                        // ⭐⭐⭐ NOM DU CHEF : TOUJOURS NAVY FONCÉ ⭐⭐⭐
                        TextSpan(
                          text: boldText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: darkBlue, // ← Toujours la même intensité
                          ),
                        ),
                        TextSpan(
                          text: ' $action',
                          style: const TextStyle(fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Heure + Badge statut
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            color: Colors.grey.shade400,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      // ⭐ Badge : TOUJOURS la même intensité de couleur
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statutBadge,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // AVATAR
  Widget _buildAvatar() {
    if (photoUrl == null || photoUrl!.isEmpty) {
      return _defaultAvatar();
    }

    final url = photoUrl!;

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFF0F0F2),
            child: const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _defaultAvatar(),
      );
    }

    try {
      final base64Str = url.contains(',') ? url.split(',').last : url;
      final bytes = base64Decode(base64Str);
      return Image.memory(
        bytes,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _defaultAvatar(),
      );
    } catch (e) {
      debugPrint('❌ Erreur décodage Base64: $e');
      return _defaultAvatar();
    }
  }

  Widget _defaultAvatar() {
    return Container(
      color: const Color(0xFFF0F0F2),
      child: Icon(
        Icons.person,
        size: 18,
        color: badgeColor,
      ),
    );
  }
}
