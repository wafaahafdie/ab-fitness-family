// lib/AutorisationScreen.dart - VERSION CORRIGÉE ✅
// ⭐ CORRIGÉ : bouton retour élégant
// ⭐ CORRIGÉ : BOTTOM OVERFLOWED (contenu scrollable + bouton Valider fixe en bas)
// ⭐ CORRIGÉ : Le timer démarre à la 1ère ouverture du visiteur (pas à la validation)
// ⭐ NOUVEAU : Mise à jour en TEMPS RÉEL du lien de parenté (chef + membres)
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'MembreDetailScreen.dart';

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF6046F4);
const Color grey = Color(0xFF9E9EAE);
const Color lightPurple = Color(0xFF9C27B0);
const Color borderPurple = Color(0xFF890CC2);

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
// MODÈLE MEMBRE
// ============================================================

class MembreFamille {
  final String id;
  final String nom;
  final String photo;
  final String lienParente;
  final bool isSelected;
  final Map<String, bool> autorisations;

  const MembreFamille({
    required this.id,
    required this.nom,
    required this.photo,
    required this.lienParente,
    this.isSelected = false,
    this.autorisations = const {'profil': true, 'documents': true},
  });

  factory MembreFamille.fromFirestore(Map<String, dynamic> data, String id) {
    return MembreFamille(
      id: id,
      nom: data['fullName'] ?? data['name'] ?? 'Inconnu',
      photo: data['photoUrl'] ?? data['photo_url'] ?? '',
      lienParente: data['relationship'] ??
          data['relation'] ??
          data['lien'] ??
          data['role'] ??
          'Membre',
    );
  }

  MembreFamille copyWith({
    String? nom,
    String? photo,
    String? lienParente,
    bool? isSelected,
    Map<String, bool>? autorisations,
  }) {
    return MembreFamille(
      id: id,
      nom: nom ?? this.nom,
      photo: photo ?? this.photo,
      lienParente: lienParente ?? this.lienParente,
      isSelected: isSelected ?? this.isSelected,
      autorisations: autorisations ?? this.autorisations,
    );
  }
}

// ============================================================
// AUTORISATION SCREEN
// ============================================================

class AutorisationScreen extends StatefulWidget {
  final Map<String, dynamic> demande;

  const AutorisationScreen({super.key, required this.demande});

  @override
  State<AutorisationScreen> createState() => _AutorisationScreenState();
}

class _AutorisationScreenState extends State<AutorisationScreen> {
  List<MembreFamille> _membres = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _dureeSelectionnee = '15 min';
  final List<String> _durees = [
    '5 min',
    '10 min',
    '15 min',
    '20 min',
    '25 min',
    '30 min',
  ];

  // ⭐ NOUVEAU : streams pour la mise à jour temps réel
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _chefSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membresSub;

  // ⭐ Pour conserver l'état de sélection et les autorisations
  final Map<String, bool> _selectionMap = {};
  final Map<String, Map<String, bool>> _autorisationsMap = {};

  @override
  void initState() {
    super.initState();
    _chargerMembresTempsReel();
  }

  @override
  void dispose() {
    _chefSub?.cancel();
    _membresSub?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // ⭐ CHARGER LES MEMBRES EN TEMPS RÉEL
  //   → Si le lien de parenté change dans Firestore,
  //     l'écran se met à jour automatiquement.
  // ═══════════════════════════════════════════════════════

  Future<void> _chargerMembresTempsReel() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Utilisateur non connecté';
        });
        return;
      }

      // ⭐ 1. Écouter le chef en temps réel
      _chefSub = FirebaseFirestore.instance
          .collection('Chef de Famille')
          .doc(user.uid)
          .snapshots()
          .listen((chefSnapshot) {
        if (!mounted) return;

        if (!chefSnapshot.exists) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Profil chef introuvable';
          });
          return;
        }

        _traiterChefEtMembres(chefSnapshot.data()!);
      }, onError: (e) {
        debugPrint('❌ Erreur écoute chef: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Erreur: $e';
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  // ⭐ Traiter le chef + écouter les membres
  void _traiterChefEtMembres(Map<String, dynamic> chefData) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ⭐ Chef de famille lui-même
    final chefMembre = MembreFamille(
      id: user.uid,
      nom: chefData['fullName'] ?? chefData['name'] ?? 'Chef de famille',
      photo: chefData['photoUrl'] ?? chefData['photo_url'] ?? '',
      lienParente: chefData['role'] ??
          chefData['relationship'] ??
          chefData['relation'] ??
          'Chef de famille',
    );

    // ⭐ Liste des IDs des membres (familyMembers ou family_members)
    List<dynamic> membersUids = [];
    if (chefData['familyMembers'] is List) {
      membersUids = chefData['familyMembers'] as List;
    } else if (chefData['family_members'] is List) {
      membersUids = chefData['family_members'] as List;
    }

    // ⭐ Si aucun membre, on affiche juste le chef
    if (membersUids.isEmpty) {
      if (!mounted) return;
      setState(() {
        _membres = [_appliquerEtatSauvegarde(chefMembre)];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    // ⭐ Annuler l'écoute précédente des membres
    _membresSub?.cancel();

    // ⭐ 2. Écouter la collection "Membres Famille" en temps réel
    //    (limit 10 pour whereIn)
    final idsLimited = membersUids.take(30).toList();

    _membresSub = FirebaseFirestore.instance
        .collection('Membres Famille')
        .where(FieldPath.documentId, whereIn: idsLimited)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      final List<MembreFamille> liste = [];

      // ⭐ Ajouter le chef en premier
      liste.add(_appliquerEtatSauvegarde(chefMembre));

      // ⭐ Ajouter les membres (avec lien de parenté à jour)
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final membre = MembreFamille.fromFirestore(data, doc.id);
        liste.add(_appliquerEtatSauvegarde(membre));
      }

      // ⭐ Trier : chef en premier, puis ordre alphabétique
      liste.sort((a, b) {
        if (a.id == user.uid) return -1;
        if (b.id == user.uid) return 1;
        return a.nom.compareTo(b.nom);
      });

      setState(() {
        _membres = liste;
        _isLoading = false;
        _errorMessage = null;
      });

      debugPrint('🔄 Liste membres mise à jour : ${liste.length} membres');
    }, onError: (e) {
      debugPrint('❌ Erreur écoute membres: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur: $e';
        });
      }
    });
  }

  // ⭐ Conserver l'état de sélection + autorisations lors d'un refresh
  MembreFamille _appliquerEtatSauvegarde(MembreFamille membre) {
    final bool isSelected = _selectionMap[membre.id] ?? membre.isSelected;
    final Map<String, bool> aut =
        _autorisationsMap[membre.id] ?? membre.autorisations;

    return membre.copyWith(
      isSelected: isSelected,
      autorisations: aut,
    );
  }

  // ═══════════════════════════════════════════════════════
  // AVATAR
  // ═══════════════════════════════════════════════════════

  Widget _buildAvatar(String photo, {double size = 52}) {
    if (photo.isEmpty) return _avatarFallback(size);

    final bytes = _decodeBase64Image(photo);
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _avatarFallback(size));
    }
    if (photo.startsWith('http')) {
      return Image.network(photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback(size));
    }
    return Image.asset('assets/images/$photo',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarFallback(size));
  }

  Widget _avatarFallback(double size) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFF0F0F2),
      child: const Icon(Icons.person, color: Color(0xFFB8B8C8)),
    );
  }

  Widget _asset(String name,
      {double size = 20, Color? color, IconData? fallback}) {
    return Image.asset('assets/images/$name.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: color, errorBuilder: (context, error, stackTrace) {
      return Icon(fallback ?? Icons.arrow_back,
          size: size, color: color ?? navy);
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      final membre = _membres[index];
      final newVal = !membre.isSelected;
      _membres[index] = membre.copyWith(isSelected: newVal);
      _selectionMap[membre.id] = newVal; // ⭐ sauvegarde
    });
  }

  Future<void> _ouvrirDetailMembre(int index) async {
    final membre = _membres[index];

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MembreDetailScreen(
          membreId: membre.id,
          membreNom: membre.nom,
          membrePhoto: membre.photo,
          lienParente: membre.lienParente,
          initialAut: membre.autorisations,
        ),
      ),
    );

    if (result != null && result is Map<String, bool> && mounted) {
      setState(() {
        _membres[index] = _membres[index].copyWith(
          autorisations: result,
          isSelected: true,
        );
        _autorisationsMap[membre.id] = result; // ⭐ sauvegarde
        _selectionMap[membre.id] = true;
      });
      debugPrint('✅ Autorisations ${membre.nom}: $result');
    }
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final String nomVisiteur =
        widget.demande['visiteurNom']?.toString() ?? 'Visiteur';

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
                    'Autorisation pour $nomVisiteur',
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sélectionnez les membres et configurez leurs accès.',
                      style: TextStyle(color: grey, fontSize: 11.5),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 128,
                      child: _isLoading
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: borderPurple),
                              ),
                            )
                          : _errorMessage != null
                              ? Center(
                                  child: Text(_errorMessage!,
                                      style: const TextStyle(
                                          color: Colors.red, fontSize: 11)))
                              : _membres.isEmpty
                                  ? const Center(
                                      child: Text('Aucun membre trouvé',
                                          style: TextStyle(
                                              color: grey, fontSize: 11)))
                                  : ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _membres.length,
                                      itemBuilder: (context, index) {
                                        return _buildMembreCard(
                                            _membres[index], index);
                                      },
                                    ),
                    ),
                    const SizedBox(height: 14),
                    if (_membres.any((m) => m.isSelected)) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: borderPurple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: borderPurple.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: borderPurple, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_membres.where((m) => m.isSelected).length} membre(s) sélectionné(s)',
                                style: const TextStyle(
                                    color: borderPurple,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const Text('Droit d\'accès',
                        style: TextStyle(
                            color: navy,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: borderPurple.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              color: borderPurple, size: 20),
                          const SizedBox(width: 10),
                          const Text('Durée d\'accès :',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: navy,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _dureeSelectionnee,
                              isExpanded: true,
                              underline: Container(),
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  color: borderPurple, size: 20),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: borderPurple,
                                  fontWeight: FontWeight.w600),
                              items: _durees.map((String duree) {
                                return DropdownMenuItem<String>(
                                  value: duree,
                                  child: Text(duree,
                                      style: const TextStyle(
                                          fontSize: 13, color: navy)),
                                );
                              }).toList(),
                              onChanged: (String? nouvelleDuree) {
                                if (nouvelleDuree != null) {
                                  setState(
                                      () => _dureeSelectionnee = nouvelleDuree);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF0EDFF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.touch_app_outlined,
                              color: borderPurple,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Cliquez sur un membre',
                            style: TextStyle(
                                color: navy,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 30),
                            child: Text(
                              'Appui court = ouvrir ses documents\nAppui long = cocher/décocher',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: grey, fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: GestureDetector(
                onTap: _onValider,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [purple, lightPurple]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: purple.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: const Center(
                    child: Text('Valider',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembreCard(MembreFamille membre, int index) {
    final bool selected = membre.isSelected;

    return GestureDetector(
      onTap: () => _ouvrirDetailMembre(index),
      onLongPress: () => _toggleSelection(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        width: 92,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? borderPurple : const Color(0xFFE9E3FF),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? borderPurple.withOpacity(0.25)
                  : Colors.black.withOpacity(0.04),
              blurRadius: selected ? 10 : 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  width: selected ? 58 : 52,
                  height: selected ? 58 : 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? borderPurple : const Color(0xFFE9E3FF),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: _buildAvatar(membre.photo, size: selected ? 54 : 48),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: borderPurple,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.check,
                          size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              membre.nom,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? borderPurple : navy,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            // ⭐ Ce texte se met à jour automatiquement quand le lien change
            Text(
              membre.lienParente,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: grey, fontSize: 9.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _onValider() {
    final membresSelectionnes = _membres.where((m) => m.isSelected).toList();

    if (membresSelectionnes.isEmpty) {
      _showMessage('⚠️ Sélectionnez au moins un membre');
      return;
    }

    final String nomVisiteur =
        widget.demande['visiteurNom']?.toString() ?? 'Visiteur';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('✅ Autorisations validées',
            style: TextStyle(
                color: navy, fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('👤 $nomVisiteur',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: navy)),
              const SizedBox(height: 8),
              Text('⏱️ Durée : $_dureeSelectionnee',
                  style: const TextStyle(
                      fontSize: 13,
                      color: borderPurple,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('👥 Membres sélectionnés :',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: navy)),
              const SizedBox(height: 4),
              ...membresSelectionnes.map((m) {
                final droits = m.autorisations.entries
                    .where((e) => e.value)
                    .map((e) => e.key)
                    .toList();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ${m.nom} (${m.lienParente})',
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: borderPurple)),
                      if (droits.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 2),
                          child: Text(
                            droits.map((d) {
                              if (d == 'profil') return '👤 Voir profil';
                              if (d == 'documents') {
                                return '📥 Télécharger';
                              }
                              return d
                                  .replaceAll('doc_', '')
                                  .replaceAll('photo_', '📷 ')
                                  .replaceAll('video_', '🎬 ');
                            }).join(' • '),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.green),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler',
                style: TextStyle(color: grey, fontSize: 12)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _enregistrerAutorisations(membresSelectionnes);
            },
            child: const Text('Confirmer',
                style: TextStyle(
                    color: borderPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _enregistrerAutorisations(List<MembreFamille> membres) async {
    try {
      final dureeMinutes =
          int.tryParse(_dureeSelectionnee.replaceAll(' min', '')) ?? 15;

      final autorisationsParMembre = <String, Map<String, bool>>{};
      for (var m in membres) {
        autorisationsParMembre[m.id] = m.autorisations;
      }

      final docId = widget.demande['id'];
      if (docId != null) {
        await FirebaseFirestore.instance
            .collection('DemandesAcces')
            .doc(docId)
            .update({
          'statut': 'acceptee',
          'dateReponse': FieldValue.serverTimestamp(),
          'dureeAccesMinutes': dureeMinutes,
          // ⭐ dateExpiration = null → sera définie à la 1ère ouverture
          'dateExpiration': null,
          'membresAutorises': membres.map((m) => m.id).toList(),
          'autorisationsParMembre': autorisationsParMembre,
        });
        debugPrint('✅ Demande acceptée avec durée : $dureeMinutes min');
      }

      final visiteurId = widget.demande['visiteurId']?.toString() ?? '';
      if (visiteurId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('Notifications').add({
          'userId': visiteurId,
          'titre': 'Demande acceptée ✅',
          'message': 'Votre demande a été acceptée pour $_dureeSelectionnee.',
          'type': 'demande_acceptee',
          'lue': false,
          'date': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        _showMessage('✅ Autorisations validées !', success: true);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showMessage('❌ Erreur: $e');
    }
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(fontSize: 12, color: Colors.white)),
        backgroundColor: success ? Colors.green : navy,
        duration: const Duration(seconds: 2),
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
