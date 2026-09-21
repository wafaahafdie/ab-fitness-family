// lib/AjouterDocumentPScreen.dart
// ⭐ Version PHOTOS - Catégories familiales
// ⭐ CORRIGÉ : bouton retour élégant
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _titleColor = Color(0xFF1F2A6B);
const Color _purple = Color(0xFF8E00C8);
const Color _fieldBg = Colors.white;
const Color _borderColor = Color(0xFFD0D0D0);
const Color _labelColor = Color(0xFF70708A);
const Color _valueColor = Color(0xFF1E2235);
const Color _iconInactiveBg = Color(0xFFF4F1FA);

// ============================================================
// MODELE CATEGORIE PHOTO
// ============================================================

class CategoriePhotoIcone {
  final IconData icone;
  final String nom;
  final Color couleur;
  const CategoriePhotoIcone(this.icone, this.nom, this.couleur);
}

// ============================================================
// AJOUTER DOCUMENT P SCREEN (pour MES PHOTOS)
// ============================================================

class AjouterDocumentPScreen extends StatefulWidget {
  final String? memberId;
  final String? memberDocId;
  final String? memberCollection;

  const AjouterDocumentPScreen({
    super.key,
    this.memberId,
    this.memberDocId,
    this.memberCollection,
  });

  @override
  State<AjouterDocumentPScreen> createState() => _AjouterDocumentPScreenState();
}

class _AjouterDocumentPScreenState extends State<AjouterDocumentPScreen> {
  // ==========================================================
  // CONTROLLER
  // ==========================================================

  final TextEditingController _nomController = TextEditingController();
  bool _isAdding = false;

  // ==========================================================
  // ICONES FAMILIALES POUR PHOTOS
  // ==========================================================

  final List<CategoriePhotoIcone> _icones = const [
    // 🎉 Fêtes & Événements
    CategoriePhotoIcone(Icons.cake_outlined, 'Anniversaire', Color(0xFFFF7D27)),
    CategoriePhotoIcone(Icons.celebration_outlined, 'Fête', Color(0xFFE91E9B)),
    CategoriePhotoIcone(Icons.favorite_border, 'Mariage', Color(0xFFE91E9B)),
    CategoriePhotoIcone(Icons.church_outlined, 'Baptême', Color(0xFF4777F5)),
    CategoriePhotoIcone(
        Icons.school_outlined, 'Remise diplôme', Color(0xFF8048E9)),
    CategoriePhotoIcone(
        Icons.emoji_events_outlined, 'Récompense', Color(0xFFF1C40F)),
    CategoriePhotoIcone(Icons.nightlife_outlined, 'Soirée', Color(0xFF9B59B6)),

    // ✈️ Voyages & Vacances
    CategoriePhotoIcone(Icons.flight, 'Voyage', Color(0xFF10B8AD)),
    CategoriePhotoIcone(
        Icons.beach_access_outlined, 'Plage', Color(0xFF00BCD4)),
    CategoriePhotoIcone(
        Icons.landscape_outlined, 'Montagne', Color(0xFF27AE60)),
    CategoriePhotoIcone(
        Icons.directions_car_outlined, 'Road trip', Color(0xFFE67E22)),
    CategoriePhotoIcone(Icons.hotel_outlined, 'Hôtel', Color(0xFF9B59B6)),
    CategoriePhotoIcone(
        Icons.camera_alt_outlined, 'Souvenirs', Color(0xFFE91E63)),

    // 👨‍👩‍👧‍👦 Famille & Amis
    CategoriePhotoIcone(Icons.groups_outlined, 'Famille', Color(0xFF8048E9)),
    CategoriePhotoIcone(Icons.people_outline, 'Amis', Color(0xFF4777F5)),
    CategoriePhotoIcone(
        Icons.child_care_outlined, 'Enfants', Color(0xFFFF7D27)),
    CategoriePhotoIcone(
        Icons.elderly_outlined, 'Grands-parents', Color(0xFF8E44AD)),
    CategoriePhotoIcone(
        Icons.family_restroom_outlined, 'Réunion', Color(0xFF3498DB)),
    CategoriePhotoIcone(
        Icons.pregnant_woman_outlined, 'Grossesse', Color(0xFFE91E9B)),
    CategoriePhotoIcone(
        Icons.baby_changing_station_outlined, 'Bébé', Color(0xFFFF9EC9)),

    // 🎬 Loisirs & Sports
    CategoriePhotoIcone(
        Icons.sports_soccer_outlined, 'Sport', Color(0xFF62C93D)),
    CategoriePhotoIcone(
        Icons.music_note_outlined, 'Musique', Color(0xFFE91E63)),
    CategoriePhotoIcone(
        Icons.theater_comedy_outlined, 'Spectacle', Color(0xFF9B59B6)),
    CategoriePhotoIcone(
        Icons.restaurant_outlined, 'Cuisine', Color(0xFFE74C3C)),
    CategoriePhotoIcone(Icons.pool_outlined, 'Natation', Color(0xFF00BCD4)),
    CategoriePhotoIcone(Icons.hiking_outlined, 'Randonnée', Color(0xFF27AE60)),

    // 🏠 Vie quotidienne
    CategoriePhotoIcone(Icons.home_outlined, 'Maison', Color(0xFF8E44AD)),
    CategoriePhotoIcone(Icons.pets, 'Animaux', Color(0xFFE67E22)),
    CategoriePhotoIcone(Icons.work_outline, 'Travail', Color(0xFF1F2A6B)),
    CategoriePhotoIcone(
        Icons.local_florist_outlined, 'Jardin', Color(0xFF62C93D)),

    // 🎨 Styles & Artistique
    CategoriePhotoIcone(
        Icons.photo_camera_outlined, 'Portrait', Color(0xFF9B59B6)),
    CategoriePhotoIcone(Icons.face, 'Selfie', Color(0xFFE91E63)),
    CategoriePhotoIcone(Icons.photo_album_outlined, 'Album', Color(0xFF3498DB)),
    CategoriePhotoIcone(
        Icons.filter_vintage_outlined, 'Vintage', Color(0xFFD35400)),
    CategoriePhotoIcone(Icons.landscape, 'Paysage', Color(0xFF27AE60)),

    // 📸 Autres
    CategoriePhotoIcone(
        Icons.photo_library_outlined, 'Photo', Color(0xFFE74C3C)),
    CategoriePhotoIcone(Icons.image_outlined, 'Image', Color(0xFFE91E9B)),
    CategoriePhotoIcone(Icons.star_outline, 'Favoris', Color(0xFFF1C40F)),
    CategoriePhotoIcone(Icons.collections_outlined, 'Vrac', Color(0xFF2C3E50)),
  ];

  int _iconeSelectionnee = 0;

  // ==========================================================
  // COULEURS DISPONIBLES
  // ==========================================================

  final List<Color> _couleurs = const [
    _purple,
    _titleColor,
    Color(0xFF1FAE6B),
    Color(0xFFE0A100),
    Color(0xFFE23F3F),
    Color(0xFF10B8AD),
    Color(0xFF4777F5),
    Color(0xFFE91E9B),
    Color(0xFF8048E9),
    Color(0xFFF39C12),
    Color(0xFF2ECC71),
    Color(0xFF3498DB),
    Color(0xFF9B59B6),
    Color(0xFFE67E22),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFF8E44AD),
    Color(0xFF27AE60),
    Color(0xFFF1C40F),
    Color(0xFF2C3E50),
  ];

  int _couleurSelectionnee = 0;

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _nomController.dispose();
    super.dispose();
  }

  // ==========================================================
  // ASSET
  // ==========================================================

  Widget _asset(
    String name, {
    double size = 16,
    Color? color,
    IconData? fallback,
  }) {
    return Image.asset(
      'assets/images/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          fallback ?? Icons.circle,
          size: size,
          color: color ?? _titleColor,
        );
      },
    );
  }

  // ==========================================================
  // ⭐ CRÉER LA CATÉGORIE PHOTO + SAUVEGARDER DANS FIRESTORE
  // ==========================================================

  Future<void> _creerCategorie() async {
    if (_nomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Veuillez saisir un nom pour cette catégorie.',
            style: TextStyle(fontSize: 11),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isAdding = true);

    try {
      final iconeChoisie = _icones[_iconeSelectionnee];
      final couleurChoisie = _couleurs[_couleurSelectionnee];
      final nom = _nomController.text.trim();

      // ⭐ Nouvelle catégorie PHOTO
      final nouvelleCategorie = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'nom': nom,
        'iconCodePoint': iconeChoisie.icone.codePoint,
        'color': couleurChoisie.value,
        'iconColor': couleurChoisie.value,
        'createdAt': DateTime.now().toIso8601String(),
        'source': 'photos_screen',
      };

      // ⭐ Sauvegarder dans le doc du membre
      if (widget.memberDocId != null &&
          widget.memberDocId!.isNotEmpty &&
          widget.memberCollection != null &&
          widget.memberCollection!.isNotEmpty) {
        final memberRef = FirebaseFirestore.instance
            .collection(widget.memberCollection!)
            .doc(widget.memberDocId!);

        final doc = await memberRef.get();
        final data = doc.data() ?? {};
        final List existing = (data['categories'] as List?) ?? [];

        // Éviter les doublons
        final alreadyExists = existing.any(
          (c) => c is Map && c['nom'] == nom && c['source'] == 'photos_screen',
        );

        if (!alreadyExists) {
          existing.add(nouvelleCategorie);
          await memberRef.update({'categories': existing});
          debugPrint('✅ Catégorie photo "$nom" enregistrée dans le membre');
        } else {
          debugPrint('⚠️ Catégorie photo "$nom" existe déjà');
        }
      } else {
        debugPrint('⚠️ memberDocId ou memberCollection manquant');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Catégorie photo "$nom" créée'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Erreur création catégorie photo: $e');
      if (mounted) {
        setState(() => _isAdding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e')),
        );
      }
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ⭐ APPBAR avec bouton retour élégant
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: const BoxDecoration(color: Color(0xFFF4F1FA)),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                _ElegantBackButton(
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Nouvelle catégorie photo',
                    style: TextStyle(
                      color: _titleColor,
                      fontSize: 15,
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

      // BODY
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Column(
                  children: [
                    _buildApercuIcone(),
                    const SizedBox(height: 26),
                    _buildLabel('Nom de la catégorie'),
                    const SizedBox(height: 6),
                    _buildNomField(),
                    const SizedBox(height: 20),
                    _buildLabel('Choisir une icône'),
                    const SizedBox(height: 8),
                    _buildSelecteurIconesColores(),
                    const SizedBox(height: 20),
                    _buildLabel('Choisir une couleur'),
                    const SizedBox(height: 8),
                    _buildSelecteurCouleurs(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: _buildBoutonCreer(),
            ),
          ],
        ),
      ),
    );
  }

  // LABEL
  Widget _buildLabel(String texte) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        texte,
        style: const TextStyle(
          color: _labelColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // APERÇU ICÔNE
  Widget _buildApercuIcone() {
    final couleur = _couleurs[_couleurSelectionnee];
    final icone = _icones[_iconeSelectionnee];

    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: couleur.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: couleur.withOpacity(0.5),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: couleur.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icone.icone,
            color: couleur,
            size: 34,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _nomController.text.trim().isEmpty
              ? 'Aperçu de la catégorie'
              : _nomController.text.trim(),
          style: TextStyle(
            color: couleur,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // CHAMP NOM
  Widget _buildNomField() {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextField(
        controller: _nomController,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          color: _valueColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: 'Ex : Vacances été 2026',
          hintStyle: TextStyle(
            color: Color(0xFFB0B0C4),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // SÉLECTEUR D'ICÔNES
  Widget _buildSelecteurIconesColores() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_icones.length, (index) {
        final bool selected = index == _iconeSelectionnee;
        final icone = _icones[index];

        return GestureDetector(
          onTap: () => setState(() => _iconeSelectionnee = index),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: selected ? icone.couleur : _iconInactiveBg,
              borderRadius: BorderRadius.circular(14),
              border: selected
                  ? Border.all(color: icone.couleur, width: 3)
                  : Border.all(color: Colors.transparent, width: 1),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: icone.couleur.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    icone.icone,
                    size: 24,
                    color: selected ? Colors.white : icone.couleur,
                  ),
                ),
                if (selected)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 18,
                        color: icone.couleur,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // SÉLECTEUR DE COULEURS
  Widget _buildSelecteurCouleurs() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(_couleurs.length, (index) {
        final bool selected = index == _couleurSelectionnee;
        final couleur = _couleurs[index];

        return GestureDetector(
          onTap: () => setState(() => _couleurSelectionnee = index),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: couleur,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: couleur.withOpacity(0.5),
                        blurRadius: 12,
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? const Center(
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }

  // BOUTON CRÉER
  Widget _buildBoutonCreer() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isAdding ? null : _creerCategorie,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isAdding ? Colors.grey : _purple,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isAdding)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              const Icon(
                Icons.add_circle_outline,
                color: Colors.white,
                size: 20,
              ),
            const SizedBox(width: 10),
            Text(
              _isAdding ? 'Création en cours...' : 'Créer la catégorie',
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
