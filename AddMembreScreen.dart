// lib/AddMembreScreen.dart - AVEC BOUTON RETOUR ÉLÉGANT ✅ ET OBJETS AGRANDIS
// ⭐ CORRIGÉ : l'icône caméra ouvre la GALERIE (au lieu de l'appareil photo)
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF890CC2);
const Color pink = Color(0xFFE91E9B);
const Color grey = Color(0xFF9E9EAE);
const Color lightGrey = Color(0xFFF7F7FA);

// ============================================================
// ADD MEMBRE SCREEN
// ============================================================

class AddMembreScreen extends StatefulWidget {
  const AddMembreScreen({super.key});

  @override
  State<AddMembreScreen> createState() => _AddMembreScreenState();
}

// ============================================================
// STATE
// ============================================================

class _AddMembreScreenState extends State<AddMembreScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // ============================================================
  // VARIABLES
  // ============================================================

  DateTime? _selectedDate;
  String? _selectedRelation;
  String _selectedGender = 'Femme';

  // Image en base64
  String? _profileImageBase64;
  final ImagePicker _imagePicker = ImagePicker();

  // ============================================================
  // RELATIONS
  // ============================================================

  final List<String> _relations = const [
    'Fils',
    'Fille',
    'Frère',
    'Sœur',
    'Époux',
    'Épouse',
    'Père',
    'Mère',
    'Grand-père',
    'Grand-mère',
    'Oncle',
    'Tante',
    'Cousin',
    'Cousine',
    'Autre',
  ];

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ============================================================
  // ASSET
  // ============================================================

  Widget _asset(
    String name, {
    double size = 24,
    BoxFit fit = BoxFit.contain,
    Color? color,
  }) {
    return Image.asset(
      'assets/images/$name.png',
      width: size,
      height: size,
      fit: fit,
      color: color,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return Icon(
          Icons.circle_outlined,
          size: size,
          color: color ?? navy,
        );
      },
    );
  }

  // ============================================================
  // ⭐ CHOISIR UNE PHOTO DEPUIS LA GALERIE
  // ============================================================

  Future<void> _takePhotoDirectly() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 60,
      );

      if (pickedFile != null) {
        final Uint8List imageBytes = await pickedFile.readAsBytes();
        final String base64String = base64Encode(imageBytes);

        if (base64String.length > 500000) {
          _showMessage(
              'Image trop grande, veuillez en choisir une plus petite');
          return;
        }

        setState(() {
          _profileImageBase64 = base64String;
        });

        _showMessage('✅ Photo choisie avec succès!');
      }
    } catch (e) {
      _showMessage('Erreur lors du choix de la photo: $e');
    }
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = _selectedDate ?? DateTime(2000, 1, 1);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (
        BuildContext context,
        Widget? child,
      ) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: navy,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: navy,
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (!mounted) return;

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Sélectionner la date';
    }

    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // ============================================================
  // 🖼️ PHOTO PROFIL (AGRANDIE ET BIEN RONDE)
  // ============================================================

  Widget _buildProfilePhoto() {
    return SizedBox(
      width: 120, // Agrandi
      height: 120, // Agrandi
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: ClipOval(
              child: Container(
                width: 110, // Agrandi
                height: 110, // Agrandi
                color: lightGrey,
                child: _profileImageBase64 != null
                    ? Image.memory(
                        base64Decode(_profileImageBase64!),
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _asset('mem', size: 110);
                        },
                      )
                    : _asset('mem', size: 110),
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: 2,
            child: GestureDetector(
              onTap: _takePhotoDirectly,
              child: Container(
                width: 36, // Agrandi
                height: 36, // Agrandi
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: _asset(
                    'ca',
                    size: 22, // Agrandi
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHAMP NOM COMPLET (AGRANDI)
  // ============================================================

  Widget _buildFullNameField() {
    return Container(
      height: 60, // Agrandi
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD6D6D6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 5,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          _asset('us', size: 26), // Agrandi
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _fullNameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(
                fontSize: 16, // Agrandi
                color: navy,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                labelText: 'Nom Complet',
                labelStyle: TextStyle(
                  fontSize: 13, // Agrandi
                  color: navy,
                  fontWeight: FontWeight.w600,
                ),
                hintText: 'Entrez votre Nom Complet',
                hintStyle: TextStyle(
                  fontSize: 13, // Agrandi
                  color: grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }

  // ============================================================
  // DATE DE NAISSANCE (AGRANDIE)
  // ============================================================

  Widget _buildBirthDateField() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _selectDate,
      child: Container(
        height: 60, // Agrandi
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFD6D6D6),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x15000000),
              blurRadius: 5,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            _asset('cal', size: 26), // Agrandi
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date de Naissance',
                    style: TextStyle(
                      fontSize: 13, // Agrandi
                      color: navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDate(_selectedDate),
                    style: TextStyle(
                      fontSize: 13, // Agrandi
                      color: _selectedDate == null ? grey : navy,
                    ),
                  ),
                ],
              ),
            ),
            _asset('cal', size: 22), // Agrandi
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LIEN DE PARENTE (AGRANDI)
  // ============================================================

  Widget _buildRelationField() {
    return Container(
      height: 60, // Agrandi
      padding: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD6D6D6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 5,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRelation,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 22, // Agrandi
            color: navy,
          ),
          hint: Row(
            children: [
              const SizedBox(width: 14),
              _asset('aj', size: 26), // Agrandi
              const SizedBox(width: 12),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lien de parenté',
                    style: TextStyle(
                      fontSize: 13, // Agrandi
                      color: navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Choisir le lien',
                    style: TextStyle(
                      fontSize: 13, // Agrandi
                      color: grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          selectedItemBuilder: (
            BuildContext context,
          ) {
            return _relations.map(
              (String relation) {
                return Row(
                  children: [
                    const SizedBox(width: 14),
                    _asset('aj', size: 26), // Agrandi
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lien de parenté',
                          style: TextStyle(
                            fontSize: 13, // Agrandi
                            color: navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          relation,
                          style: const TextStyle(
                            fontSize: 13, // Agrandi
                            color: navy,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ).toList();
          },
          items: _relations.map(
            (String relation) {
              return DropdownMenuItem<String>(
                value: relation,
                child: Text(
                  relation,
                  style: const TextStyle(
                    fontSize: 15, // Agrandi
                    color: navy,
                  ),
                ),
              );
            },
          ).toList(),
          onChanged: (
            String? value,
          ) {
            if (value == null) return;

            setState(() {
              _selectedRelation = value;
            });
          },
        ),
      ),
    );
  }

  // ============================================================
  // TELEPHONE (AGRANDI)
  // ============================================================

  Widget _buildPhoneField() {
    return Container(
      height: 60, // Agrandi
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD6D6D6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 5,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          _asset('tl', size: 26), // Agrandi
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                fontSize: 16, // Agrandi
                color: navy,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                labelText: 'Téléphone',
                labelStyle: TextStyle(
                  fontSize: 13, // Agrandi
                  color: navy,
                  fontWeight: FontWeight.w600,
                ),
                hintText: 'Entrez votre numéro de téléphone',
                hintStyle: TextStyle(
                  fontSize: 13, // Agrandi
                  color: grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }

  // ============================================================
  // EMAIL (AGRANDI)
  // ============================================================

  Widget _buildEmailField() {
    return Container(
      height: 60, // Agrandi
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD6D6D6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 5,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          _asset('em', size: 26), // Agrandi
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(
                fontSize: 16, // Agrandi
                color: navy,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                labelText: 'Email',
                labelStyle: TextStyle(
                  fontSize: 13, // Agrandi
                  color: navy,
                  fontWeight: FontWeight.w600,
                ),
                hintText: 'Entrez votre mail',
                hintStyle: TextStyle(
                  fontSize: 13, // Agrandi
                  color: grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }

  // ============================================================
  // ADRESSE (AGRANDIE)
  // ============================================================

  Widget _buildAddressField() {
    return Container(
      height: 60, // Agrandi
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD6D6D6),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 5,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          _asset('dd', size: 26), // Agrandi
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _addressController,
              style: const TextStyle(
                fontSize: 16, // Agrandi
                color: navy,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                labelText: 'Adresse',
                labelStyle: TextStyle(
                  fontSize: 13, // Agrandi
                  color: navy,
                  fontWeight: FontWeight.w600,
                ),
                hintText: 'Entrez votre adresse',
                hintStyle: TextStyle(
                  fontSize: 13, // Agrandi
                  color: grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }

  // ============================================================
  // GENRE (AGRANDI)
  // ============================================================

  Widget _buildGenderButton({
    required String gender,
    required String assetName,
  }) {
    final bool selected = _selectedGender == gender;
    final bool isFemale = gender == 'Femme';
    final Color activeColor = isFemale ? pink : navy;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _selectedGender = gender;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 220,
        ),
        curve: Curves.easeOut,
        width: 110, // Agrandi
        height: 48, // Agrandi
        decoration: BoxDecoration(
          color: selected ? activeColor.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? activeColor : const Color(0xFF9EA3C4),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _asset(
              assetName,
              size: 22, // Agrandi
            ),
            const SizedBox(width: 8),
            Text(
              gender,
              style: TextStyle(
                color: activeColor,
                fontSize: 15, // Agrandi
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool _validateForm() {
    if (_fullNameController.text.trim().isEmpty) {
      _showMessage('Veuillez entrer le nom complet.');
      return false;
    }

    if (_selectedDate == null) {
      _showMessage('Veuillez sélectionner la date de naissance.');
      return false;
    }

    if (_selectedRelation == null) {
      _showMessage('Veuillez choisir le lien de parenté.');
      return false;
    }

    return true;
  }

  // ============================================================
  // AJOUTER MEMBRE
  // ============================================================

  void _addMember() {
    if (!_validateForm()) return;

    final Map<String, dynamic> memberData = {
      'fullName': _fullNameController.text.trim(),
      'birthDate': _formatDate(_selectedDate),
      'relation': _selectedRelation!,
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'address': _addressController.text.trim(),
      'gender': _selectedGender,
      'profileImage': _profileImageBase64 ?? '',
    };

    Navigator.pop(context, memberData);
    _showMessage('✅ Membre ajouté avec succès!');
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14, // Agrandi
          ),
        ),
        backgroundColor: navy,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            18, // Agrandi
            16, // Agrandi
            18, // Agrandi
            28, // Agrandi
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // HEADER avec bouton retour élégant
              // ==================================================

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ElegantBackButton(
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 18), // Agrandi
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ajouter un Membre',
                        style: TextStyle(
                          color: navy,
                          fontSize: 18, // Agrandi
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Inviter un nouveau Membre',
                        style: TextStyle(
                          color: Color(0xFFB1B1C5),
                          fontSize: 12, // Agrandi
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // ==================================================
              // PHOTO
              // ==================================================

              const SizedBox(height: 20), // Agrandi

              Center(
                child: _buildProfilePhoto(),
              ),

              const SizedBox(height: 24), // Agrandi

              // ==================================================
              // NOM
              // ==================================================

              _buildFullNameField(),

              const SizedBox(height: 16), // Agrandi

              // ==================================================
              // DATE
              // ==================================================

              _buildBirthDateField(),

              const SizedBox(height: 16), // Agrandi

              // ==================================================
              // RELATION
              // ==================================================

              _buildRelationField(),

              const SizedBox(height: 16), // Agrandi

              // ==================================================
              // TELEPHONE
              // ==================================================

              _buildPhoneField(),

              const SizedBox(height: 16), // Agrandi

              // ==================================================
              // EMAIL
              // ==================================================

              _buildEmailField(),

              const SizedBox(height: 16), // Agrandi

              // ==================================================
              // ADRESSE
              // ==================================================

              _buildAddressField(),

              const SizedBox(height: 20), // Agrandi

              // ==================================================
              // GENRE
              // ==================================================

              const Text(
                'Genre',
                style: TextStyle(
                  color: navy,
                  fontSize: 18, // Agrandi
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12), // Agrandi

              Row(
                children: [
                  _buildGenderButton(
                    gender: 'Femme',
                    assetName: 'fem',
                  ),
                  const SizedBox(width: 20), // Agrandi
                  _buildGenderButton(
                    gender: 'Homme',
                    assetName: 'hom',
                  ),
                ],
              ),

              // ==================================================
              // BOUTON
              // ==================================================

              const SizedBox(height: 30), // Agrandi

              GestureDetector(
                onTap: _addMember,
                child: Container(
                  width: double.infinity,
                  height: 55, // Agrandi
                  decoration: BoxDecoration(
                    color: purple,
                    borderRadius: BorderRadius.circular(12), // Agrandi
                    boxShadow: [
                      BoxShadow(
                        color: purple.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _asset('pl', size: 22), // Agrandi
                      const SizedBox(width: 10),
                      const Text(
                        'Ajouter le membre',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16, // Agrandi
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
          width: 50, // Agrandi
          height: 50, // Agrandi
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16), // Agrandi
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              'assets/images/xx.png',
              width: 28, // Agrandi
              height: 28, // Agrandi
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF1F2A6B),
                size: 24, // Agrandi
              ),
            ),
          ),
        ),
      ),
    );
  }
}