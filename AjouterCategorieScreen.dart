// lib/AjouterCategorieScreen.dart - AVEC BOUTON RETOUR ÉLÉGANT ✅
// ✅ CORRIGÉ : plus de "BOTTOM OVERFLOWED BY 140 PIXELS"
//   → le formulaire est désormais défilable (SingleChildScrollView),
//     le bouton reste fixé en bas. Fonctionne aussi clavier ouvert.
import 'package:flutter/material.dart';

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF890CC2);
const Color pink = Color(0xFFE91E9B);
const Color grey = Color(0xFF9E9EAE);
const Color lightGrey = Color(0xFFF5F5F7);

// ============================================================
// AJOUTER / MODIFIER CATEGORIE SCREEN
// ✅ CORRIGÉ : toutes les icônes sont en NAVY sauf celle sélectionnée
// ✅ CORRIGÉ : bouton retour élégant
// ============================================================

class AjouterCategorieScreen extends StatefulWidget {
  const AjouterCategorieScreen({
    super.key,
    this.isEditing = false,
    this.initialId,
    this.initialNom,
    this.initialIconCodePoint,
    this.initialColorValue,
    this.sourceTag = 'detail_screen',
  });

  final bool isEditing;
  final String? initialId;
  final String? initialNom;
  final int? initialIconCodePoint;
  final int? initialColorValue;
  final String sourceTag;

  @override
  State<AjouterCategorieScreen> createState() => _AjouterCategorieScreenState();
}

class _AjouterCategorieScreenState extends State<AjouterCategorieScreen> {
  final TextEditingController _nomController = TextEditingController();

  IconData _selectedIcon = Icons.folder_outlined;
  int _selectedIconCodePoint = Icons.folder_outlined.codePoint;
  Color _selectedColor = navy;
  int _selectedColorValue = navy.value;

  bool _isAdding = false;

  // ✅ LISTE DES ICÔNES DISPONIBLES
  final List<IconData> _icons = [
    Icons.folder_outlined,
    Icons.folder_open_outlined,
    Icons.description_outlined,
    Icons.insert_drive_file_outlined,
    Icons.note_alt_outlined,
    Icons.credit_card_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.book_outlined,
    Icons.menu_book_outlined,
    Icons.sticky_note_2_outlined,
    Icons.flight_outlined,
    Icons.beach_access_outlined,
    Icons.location_on_outlined,
    Icons.map_outlined,
    Icons.place_outlined,
    Icons.home_outlined,
    Icons.family_restroom_outlined,
    Icons.park_outlined,
    Icons.celebration_outlined,
    Icons.shopping_bag_outlined,
    Icons.shopping_cart_outlined,
    Icons.restaurant_outlined,
    Icons.local_cafe_outlined,
    Icons.local_grocery_store_outlined,
    Icons.sports_soccer_outlined,
    Icons.fitness_center_outlined,
    Icons.music_note_outlined,
    Icons.movie_outlined,
    Icons.camera_alt_outlined,
    Icons.work_outline,
    Icons.school_outlined,
    Icons.computer_outlined,
    Icons.important_devices_outlined,
    Icons.star_outline,
    Icons.favorite_outline,
    Icons.volunteer_activism_outlined,
    Icons.health_and_safety_outlined,
    Icons.emoji_events_outlined,
  ];

  // ✅ LISTE DES COULEURS DISPONIBLES
  final List<Color> _colors = const [
    navy,
    purple,
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

  int _selectedColorIndex = 0;

  @override
  void initState() {
    super.initState();

    if (widget.initialNom != null && widget.initialNom!.trim().isNotEmpty) {
      _nomController.text = widget.initialNom!;
    }

    if (widget.initialIconCodePoint != null) {
      _selectedIcon = IconData(
        widget.initialIconCodePoint!,
        fontFamily: 'MaterialIcons',
      );
      _selectedIconCodePoint = widget.initialIconCodePoint!;
    }

    if (widget.initialColorValue != null) {
      _selectedColorValue = widget.initialColorValue!;
      _selectedColor = Color(widget.initialColorValue!);

      final int foundIndex =
          _colors.indexWhere((c) => c.value == widget.initialColorValue);
      if (foundIndex != -1) {
        _selectedColorIndex = foundIndex;
      }
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
  void dispose() {
    _nomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color currentColor = _selectedColor;

    return Scaffold(
      backgroundColor: Colors.white,
      // ⭐ APPBAR avec bouton retour élégant
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
                    widget.isEditing
                        ? 'Modifier la catégorie'
                        : 'Ajouter une catégorie',
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
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Zone défilable : plus d'overflow (clavier ou petit écran)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==================================================
                      // APERÇU DE L'ICÔNE
                      // ==================================================

                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: currentColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: currentColor.withOpacity(0.5),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: currentColor.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _selectedIcon,
                                color: currentColor,
                                size: 34,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _nomController.text.trim().isEmpty
                                  ? 'Aperçu de la catégorie'
                                  : _nomController.text.trim(),
                              style: TextStyle(
                                color: currentColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ==================================================
                      // NOM DE LA CATEGORIE
                      // ==================================================

                      const Text(
                        'Nom de la catégorie',
                        style: TextStyle(
                          color: navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: lightGrey,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE8E5F5),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _nomController,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            fontSize: 14,
                            color: navy,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 16),
                            hintText: 'Ex: Fêtes, École...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFB0B0C0),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // CHOISIR UNE ICÔNE
                      // ==================================================

                      const Text(
                        'Choisir une icône',
                        style: TextStyle(
                          color: navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 70,
                        decoration: BoxDecoration(
                          color: lightGrey,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE8E5F5),
                            width: 1,
                          ),
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _icons.length,
                          itemBuilder: (context, index) {
                            final icon = _icons[index];
                            final isSelected =
                                _selectedIcon.codePoint == icon.codePoint;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedIcon = icon;
                                  _selectedIconCodePoint = icon.codePoint;
                                });
                              },
                              child: Container(
                                width: 50,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 8),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? currentColor
                                              : const Color(0xFFE8E5F5),
                                          width: isSelected ? 2.4 : 1.5,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: currentColor
                                                      .withOpacity(0.3),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Icon(
                                        icon,
                                        color: isSelected ? currentColor : navy,
                                        size: 22,
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: -5,
                                        right: -5,
                                        child: Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: currentColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // CHOISIR UNE COULEUR
                      // ==================================================

                      const Text(
                        'Choisir une couleur',
                        style: TextStyle(
                          color: navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: List.generate(_colors.length, (index) {
                          final Color color = _colors[index];
                          final bool selected =
                              color.value == _selectedColorValue;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedColorIndex = index;
                                _selectedColor = color;
                                _selectedColorValue = color.value;
                              });
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: color.withOpacity(0.5),
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
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // BOUTON CREER / MODIFIER LA CATEGORIE
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _isAdding ? null : _validerCategorie,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAdding ? Colors.grey : purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isAdding)
                        const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      else
                        Icon(
                          widget.isEditing
                              ? Icons.check_circle_outline
                              : Icons.add_circle_outline,
                          color: Colors.white,
                          size: 17,
                        ),
                      const SizedBox(width: 7),
                      Text(
                        _isAdding
                            ? (widget.isEditing
                                ? 'Modification en cours...'
                                : 'Ajout en cours...')
                            : (widget.isEditing
                                ? 'Modifier la catégorie'
                                : 'Créer une catégorie'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  // ============================================================
  // ✅ CRÉER OU MODIFIER LA CATÉGORIE
  // ============================================================

  void _validerCategorie() {
    if (_nomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un nom de catégorie'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }

    setState(() => _isAdding = true);

    Navigator.pop(context, {
      'id':
          widget.initialId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'nom': _nomController.text.trim(),
      'iconCodePoint': _selectedIconCodePoint,
      'colorValue': _selectedColorValue,
      'iconColor': _selectedColorValue,
      'source': widget.sourceTag,
      'isEditing': widget.isEditing,
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isAdding = false);
    });
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
