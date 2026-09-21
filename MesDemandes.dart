// lib/DemandeVisiteur.dart - SANS BANNIÈRE DESTINATAIRE ✅
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF6046F4);
const Color pink = Color(0xFFE91E9B);
const Color grey = Color(0xFF9E9EAE);
const Color lightPurple = Color(0xFF9C27B0);
const Color darkPurple = Color(0xFF890CC2);

class MesDemandes extends StatefulWidget {
  final String? chefId;
  final String? chefNom;
  final String? chefFamilyId;

  const MesDemandes({
    super.key,
    this.chefId,
    this.chefNom,
    this.chefFamilyId,
  });

  @override
  State<MesDemandes> createState() => _MesDemandesState();
}

class _MesDemandesState extends State<MesDemandes> {
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _motifController = TextEditingController();

  String _relation = '';
  bool _isSending = false;

  // ⭐ Stocker la photo du visiteur
  String _visiteurPhoto = '';

  final List<String> _relations = [
    'Ami de la famille',
    'Membre de la famille',
    'Voisin',
    'Collègue',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _chargerInfosVisiteur();
    _debugChefInfo();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    _motifController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // ⭐ DEBUG
  // ═══════════════════════════════════════════════════════

  void _debugChefInfo() {
    debugPrint('════════════════════════════════════════');
    debugPrint('🎯 INFOS DU CHEF REÇUES :');
    debugPrint('   chefId       = "${widget.chefId}"');
    debugPrint('   chefNom      = "${widget.chefNom}"');
    debugPrint('   chefFamilyId = "${widget.chefFamilyId}"');
    debugPrint('════════════════════════════════════════');

    if (widget.chefId == null || widget.chefId!.trim().isEmpty) {
      debugPrint('❌ ERREUR : chefId est VIDE !');
    } else {
      debugPrint('✅ chefId OK');
    }
  }

  // ═══════════════════════════════════════════════════════
  // ⭐ CHARGER LES INFOS DU VISITEUR
  // ═══════════════════════════════════════════════════════

  Future<void> _chargerInfosVisiteur() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('Visiteurs')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;

      final data = doc.data()!;

      String nomComplet = data['nomComplet']?.toString() ?? '';
      String prenom = data['prenom']?.toString() ?? '';
      String nom = data['nom']?.toString() ?? '';

      if (prenom.isEmpty && nom.isEmpty && nomComplet.isNotEmpty) {
        final parts = nomComplet.trim().split(' ');
        if (parts.length > 1) {
          prenom = parts.first;
          nom = parts.sublist(1).join(' ');
        } else {
          nom = nomComplet;
        }
      }

      String tel =
          data['téléphone']?.toString() ?? data['telephone']?.toString() ?? '';

      String photo = data['photoUrl']?.toString() ?? '';

      if (mounted) {
        setState(() {
          _nomController.text = nom;
          _prenomController.text = prenom;
          _telephoneController.text = tel;
          _visiteurPhoto = photo;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Erreur chargement visiteur: $e');
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

  void _showRelationPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _relations.map((r) {
              return ListTile(
                title: Text(
                  r,
                  style: TextStyle(
                    color: navy,
                    fontWeight:
                        r == _relation ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: r == _relation
                    ? const Icon(Icons.check, color: lightPurple)
                    : null,
                onTap: () {
                  setState(() => _relation = r);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ⭐ HEADER AVEC BOUTON RETOUR ÉLÉGANT
              Row(
                children: [
                  _ElegantBackButton(
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Demande d\'accès',
                    style: TextStyle(
                      color: navy,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ⭐ BANNIÈRE D'ERREUR si chefId vide
                      if (widget.chefId == null ||
                          widget.chefId!.trim().isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '❌ Erreur : aucun chef de famille sélectionné.\nVeuillez revenir et sélectionner une famille.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ⭐ SUPPRIMÉ : bannière "Destinataire / marwa abdou"

                      Text(
                        'Remplissez le formulaire ci-dessous pour envoyer une '
                        'demande d\'accès à cette famille',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // NOM / PRÉNOM
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildFieldBox(
                              icon: 'uu',
                              fallback: Icons.person_outline,
                              label: 'NOM ',
                              hint: 'Entrez votre nom',
                              controller: _nomController,
                              isLocked: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFieldBox(
                              icon: 'uu',
                              fallback: Icons.person_outline,
                              label: 'Prénom ',
                              hint: 'Entrez votre prénom',
                              controller: _prenomController,
                              isLocked: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // TÉLÉPHONE
                      _buildFieldBox(
                        icon: 'ttt',
                        fallback: Icons.phone,
                        label: 'Numéro de téléphone ',
                        hint: '+213   0550 45 55 99',
                        controller: _telephoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\s]')),
                        ],
                        isLocked: true,
                      ),

                      const SizedBox(height: 10),

                      // RELATION
                      GestureDetector(
                        onTap: _showRelationPicker,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _relation.isEmpty
                                  ? navy.withOpacity(0.5)
                                  : const Color(0xFFE8E5F5),
                              width: _relation.isEmpty ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              _asset(
                                'ff',
                                size: 18,
                                color: navy,
                                fallback: Icons.groups_outlined,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Relation avec la famille ',
                                      style: TextStyle(
                                        color: navy,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _relation.isEmpty
                                          ? 'Sélectionnez une relation'
                                          : _relation,
                                      style: TextStyle(
                                        color: _relation.isEmpty
                                            ? const Color(0xFFB0B0C0)
                                            : navy,
                                        fontSize: 11.5,
                                        fontStyle: _relation.isEmpty
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: navy,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // MOTIF
                      const Text(
                        'Motif ',
                        style: TextStyle(
                          color: navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: navy.withOpacity(0.5),
                            width: 1.2,
                          ),
                        ),
                        child: TextField(
                          controller: _motifController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(12),
                            hintText: 'Décrivez votre motif...',
                            hintStyle: TextStyle(
                              color: Color(0xFFB0B0C0),
                              fontSize: 12,
                            ),
                          ),
                          style: const TextStyle(
                            color: navy,
                            fontSize: 12.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // BOUTON ENVOYER
                      GestureDetector(
                        onTap:
                            _isSending ? null : () => _envoyerDemande(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _isSending ? Colors.grey : lightPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _isSending
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      'Envoyer la demande',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // BOUTON RETOUR
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: lightPurple),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _asset(
                                'rr',
                                size: 16,
                                color: lightPurple,
                                fallback: Icons.undo,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Retour',
                                style: TextStyle(
                                  color: lightPurple,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // VALIDATION + ENVOI
  // ═══════════════════════════════════════════════════════

  Future<void> _envoyerDemande(BuildContext context) async {
    if (_nomController.text.trim().isEmpty) {
      _showMessage('⚠️ Le nom est obligatoire');
      return;
    }
    if (_prenomController.text.trim().isEmpty) {
      _showMessage('⚠️ Le prénom est obligatoire');
      return;
    }
    if (_telephoneController.text.trim().isEmpty) {
      _showMessage('⚠️ Le numéro de téléphone est obligatoire');
      return;
    }
    if (_telephoneController.text.trim().length < 6) {
      _showMessage('⚠️ Numéro de téléphone invalide');
      return;
    }
    if (_relation.isEmpty) {
      _showMessage('⚠️ La relation est obligatoire');
      return;
    }
    if (_motifController.text.trim().isEmpty) {
      _showMessage('⚠️ Le motif est obligatoire');
      return;
    }
    if (_motifController.text.trim().length < 5) {
      _showMessage('⚠️ Le motif est trop court (min 5 caractères)');
      return;
    }

    // ⭐ Vérification chefId
    if (widget.chefId == null || widget.chefId!.trim().isEmpty) {
      _showMessage('❌ Erreur : aucun chef de famille sélectionné');
      return;
    }

    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Vous devez être connecté');
      }

      final email = user.email ?? '';

      String visiteurPhoto = _visiteurPhoto;
      if (visiteurPhoto.isEmpty) {
        final vDoc = await FirebaseFirestore.instance
            .collection('Visiteurs')
            .doc(user.uid)
            .get();
        if (vDoc.exists) {
          visiteurPhoto = vDoc.data()?['photoUrl']?.toString() ?? '';
        }
      }

      debugPrint('════════════════════════════════════════');
      debugPrint('📤 Envoi de la demande...');
      debugPrint('👤 Visiteur  : ${user.uid} | $email');
      debugPrint('🎯 Chef      : "${widget.chefId}" | "${widget.chefNom}"');
      debugPrint('🏠 Famille   : "${widget.chefFamilyId}"');
      debugPrint('════════════════════════════════════════');

      final docRef =
          await FirebaseFirestore.instance.collection('DemandesAcces').add({
        'visiteurId': user.uid,
        'chefId': widget.chefId!.trim(),
        'chefFamilyId': widget.chefFamilyId?.trim() ?? '',
        'chefNom': widget.chefNom ?? 'Chef de famille',
        'visiteurNom':
            '${_prenomController.text.trim()} ${_nomController.text.trim()}',
        'visiteurEmail': email,
        'visiteurTel': _telephoneController.text.trim(),
        'visiteurPhoto': visiteurPhoto,
        'relation': _relation,
        'motif': _motifController.text.trim(),
        'statut': 'en_attente',
        'dateDemande': FieldValue.serverTimestamp(),
        'dateReponse': null,
        'dureeAccesMinutes': 15,
        'dateExpiration': null,
        'permissions': {
          'voirPhotos': false,
          'voirVideos': false,
          'voirDocuments': false,
          'voirMembres': false,
          'voirCv': false,
          'voirDiplomes': false,
          'voirCertaficats': false,
        },
      });

      debugPrint('✅ Demande enregistrée: ${docRef.id}');

      if (mounted) {
        setState(() => _isSending = false);

        _showMessage('✅ Demande envoyée avec succès !', isSuccess: true);

        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERREUR: $e');
      debugPrint('StackTrace: $stackTrace');

      if (mounted) {
        setState(() => _isSending = false);
        _showMessage('❌ Erreur: ${e.toString()}');
      }
    }
  }

  void _showMessage(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
        backgroundColor: isSuccess ? Colors.green : navy,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildFieldBox({
    required String icon,
    required IconData fallback,
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool isLocked = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE8E5F5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: _asset(icon, size: 16, color: navy, fallback: fallback),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  readOnly: isLocked,
                  enableInteractiveSelection: true,
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: Color(0xFFB0B0C0),
                      fontSize: 11,
                    ),
                  ),
                  style: const TextStyle(
                    color: navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
