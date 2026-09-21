// lib/EditProfilScreen.dart
// ⭐ CORRIGÉ : bouton retour élégant
// ⭐ CORRIGÉ : l'icône caméra ouvre la GALERIE
// ⭐ NOUVEAU : taille des boutons et textes agrandie
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ============================================================
// COULEURS
// ============================================================

const Color _titleColor = Color(0xFF1F2A6B);
const Color _purple = Color(0xFF8E00C8);
const Color _fieldBg = Colors.white;
const Color _borderColor = Color(0xFFD0D0D0);
const Color _labelColor = Color(0xFF70708A);
const Color _valueColor = Color(0xFF1E2235);

const String _defaultPhoto = 'assets/images/profilpat.jpg';
const int _maxPhotoBase64Length = 700000;

// ============================================================
// EDIT PROFIL SCREEN
// ============================================================

class EditProfilScreen extends StatefulWidget {
  final String userId;
  final bool isChef;

  const EditProfilScreen({
    super.key,
    required this.userId,
    this.isChef = false,
  });

  @override
  State<EditProfilScreen> createState() => _EditProfilScreenState();
}

class _EditProfilScreenState extends State<EditProfilScreen> {
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _dateNaissanceController =
      TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _adresseController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  String _selectedRelationship = 'Membre';
  final List<String> _relationships = [
    'Père',
    'Mère',
    'Fils',
    'Fille',
    'Époux',
    'Épouse',
    'Frère',
    'Sœur',
    'Grand-père',
    'Grand-mère',
    'Membre',
  ];

  String _selectedGender = 'Homme';
  final List<String> _genders = ['Homme', 'Femme', 'Autre'];

  bool _loading = true;
  bool _saving = false;
  bool _pickingPhoto = false;
  String? _error;
  String _collectionName = '';

  String _photoUrl = _defaultPhoto;
  Uint8List? _pickedBytes;
  String? _imageBase64;
  Uint8List? _existingPhotoBytes;
  bool _photoRemoved = false;

  @override
  void initState() {
    super.initState();
    _collectionName = widget.isChef ? 'Chef de Famille' : 'Membres Famille';
    _loadData();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _dateNaissanceController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  void _snack(String message, {Color? background}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 15)), // ⭐
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(widget.userId)
          .get();

      if (!mounted) return;

      if (!snap.exists) {
        setState(() {
          _error = 'Document introuvable.';
          _loading = false;
        });
        return;
      }

      final data = snap.data() ?? <String, dynamic>{};

      _nomController.text = (data['fullName'] ?? '').toString();
      _telephoneController.text = (data['phone'] ?? '').toString();
      _emailController.text = (data['email'] ?? '').toString();
      _adresseController.text = (data['address'] ?? '').toString();
      _dateNaissanceController.text = (data['birthDate'] ?? '').toString();

      final String stored = (data['photoUrl'] ?? '').toString();
      _photoUrl = stored.trim().isEmpty ? _defaultPhoto : stored;
      _existingPhotoBytes = _tryDecodeBase64(_photoUrl);

      if (!widget.isChef) {
        final relationship = (data['relationship'] ?? 'Membre').toString();
        _selectedRelationship = _relationships.contains(relationship)
            ? relationship
            : _relationships.last;
      }

      final gender = (data['gender'] ?? 'Homme').toString();
      _selectedGender = _genders.contains(gender) ? gender : _genders.first;

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur de chargement : $e';
        _loading = false;
      });
    }
  }

  Uint8List? _tryDecodeBase64(String value) {
    if (value.isEmpty) return null;
    if (value.startsWith('assets/')) return null;
    if (value.startsWith('http://') || value.startsWith('https://'))
      return null;

    try {
      final String raw = value.contains(',') ? value.split(',').last : value;
      return base64Decode(raw);
    } catch (e) {
      debugPrint('Photo de profil illisible : $e');
      return null;
    }
  }

  Future<void> _takePhotoDirectly() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 70,
      );

      if (!mounted) return;

      if (image == null) {
        setState(() => _pickingPhoto = false);
        return;
      }

      final Uint8List bytes = await image.readAsBytes();
      if (!mounted) return;

      final String encoded = base64Encode(bytes);

      if (encoded.length > _maxPhotoBase64Length) {
        setState(() => _pickingPhoto = false);
        _snack(
          'Cette photo est trop lourde. Choisissez-en une plus petite.',
          background: Colors.red,
        );
        return;
      }

      setState(() {
        _pickedBytes = bytes;
        _imageBase64 = encoded;
        _photoRemoved = false;
        _pickingPhoto = false;
      });

      _snack(
        'Photo choisie. Touchez Enregistrer pour la conserver.',
        background: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _pickingPhoto = false);
      _snack(
        "Impossible d'ouvrir la galerie. Vérifiez les autorisations.",
        background: Colors.red,
      );
      debugPrint('Erreur choix photo : $e');
    }
  }

  Widget _buildAvatar({double radius = 48}) {
    ImageProvider provider;
    Key key;

    if (_pickedBytes != null) {
      provider = MemoryImage(_pickedBytes!);
      key = const ValueKey('picked');
    } else if (_existingPhotoBytes != null) {
      provider = MemoryImage(_existingPhotoBytes!);
      key = const ValueKey('stored-bytes');
    } else if (_photoUrl.startsWith('http://') ||
        _photoUrl.startsWith('https://')) {
      provider = NetworkImage(_photoUrl);
      key = ValueKey(_photoUrl);
    } else if (_photoUrl.startsWith('assets/')) {
      provider = AssetImage(_photoUrl);
      key = ValueKey(_photoUrl);
    } else {
      provider = const AssetImage(_defaultPhoto);
      key = const ValueKey('default');
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: CircleAvatar(
        key: key,
        radius: radius,
        backgroundColor: const Color(0xFFF0F0F2),
        backgroundImage: provider,
        onBackgroundImageError: (error, stack) {
          debugPrint('Photo de profil non affichable : $error');
        },
      ),
    );
  }

  Widget _asset(
    String name, {
    double size = 20,
    Color? color,
    IconData? fallback,
  }) {
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
          color: color ?? _titleColor,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(66),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          color: const Color(0xFFF4F1FA),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                _ElegantBackButton(
                  onTap: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Modifier Profil',
                  style: TextStyle(
                    color: _titleColor,
                    fontSize: 17, // ⭐ 14 → 17
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 15),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Column(
                      children: [
                        _buildProfileImage(),
                        const SizedBox(height: 26),
                        _buildTextField(
                          icon: 'user',
                          fallback: Icons.person_outline,
                          label: 'Nom Complet',
                          controller: _nomController,
                        ),
                        const SizedBox(height: 14),
                        _buildDateField(),
                        const SizedBox(height: 14),
                        _buildGenderDropdown(),
                        const SizedBox(height: 14),
                        if (!widget.isChef) _buildRelationshipDropdown(),
                        if (!widget.isChef) const SizedBox(height: 14),
                        _buildTextField(
                          icon: 'tl',
                          fallback: Icons.phone_outlined,
                          label: 'Téléphone',
                          controller: _telephoneController,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          icon: 'mail',
                          fallback: Icons.email_outlined,
                          label: 'Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          icon: 'adr',
                          fallback: Icons.location_on_outlined,
                          label: 'Adresse',
                          controller: _adresseController,
                        ),
                        const SizedBox(height: 28),
                        _buildSaveButton(context),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildAvatar(radius: 48), // ⭐ 41 → 48
          if (_pickingPhoto)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withAlpha(70),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: -2,
            bottom: -1,
            child: Semantics(
              button: true,
              label: 'Choisir une photo depuis la galerie',
              child: GestureDetector(
                onTap: _pickingPhoto ? null : _takePhotoDirectly,
                child: Container(
                  width: 34, // ⭐ 28 → 34
                  height: 34, // ⭐ 28 → 34
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2235),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: _asset(
                      'cam',
                      size: 18, // ⭐ 14 → 18
                      color: Colors.white,
                      fallback: Icons.photo_library,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String icon,
    required IconData fallback,
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 64, // ⭐ 54 → 64
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _asset(icon,
                size: 22,
                color: Colors.black87,
                fallback: fallback), // ⭐ 17 → 22
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: _labelColor,
                      fontSize: 11, // ⭐ 8.5 → 11
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 22,
                    child: TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      style: const TextStyle(
                        color: _valueColor,
                        fontSize: 14, // ⭐ 10.5 → 14
                        fontWeight: FontWeight.w600,
                      ),
                      cursorColor: _purple,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        height: 64, // ⭐ 54 → 64
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              _asset(
                'cal',
                size: 22, // ⭐ 17 → 22
                color: Colors.black87,
                fallback: Icons.calendar_today,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date de Naissance',
                      style: TextStyle(
                        color: _labelColor,
                        fontSize: 11, // ⭐ 8.5 → 11
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _dateNaissanceController.text.isEmpty
                          ? 'Non renseignée'
                          : _dateNaissanceController.text,
                      style: const TextStyle(
                        color: _valueColor,
                        fontSize: 14, // ⭐ 10.5 → 14
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _asset(
                'cal',
                size: 22, // ⭐ 17 → 22
                color: Colors.black87,
                fallback: Icons.calendar_today,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Container(
      height: 64, // ⭐ 54 → 64
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            _asset(
              'gre',
              size: 22, // ⭐ 17 → 22
              color: Colors.black87,
              fallback: Icons.transgender,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Genre',
                    style: TextStyle(
                      color: _labelColor,
                      fontSize: 11, // ⭐ 8.5 → 11
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGender,
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: _labelColor,
                        size: 24,
                      ),
                      style: const TextStyle(
                        color: _valueColor,
                        fontSize: 14, // ⭐ 10.5 → 14
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() => _selectedGender = value);
                        }
                      },
                      items: _genders.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: _valueColor,
                              fontSize: 14, // ⭐ 10.5 → 14
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationshipDropdown() {
    return Container(
      height: 64, // ⭐ 54 → 64
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            _asset(
              'aj',
              size: 22, // ⭐ 17 → 22
              color: Colors.black87,
              fallback: Icons.family_restroom,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lien de parenté',
                    style: TextStyle(
                      color: _labelColor,
                      fontSize: 11, // ⭐ 8.5 → 11
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRelationship,
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: _labelColor,
                        size: 24,
                      ),
                      style: const TextStyle(
                        color: _valueColor,
                        fontSize: 14, // ⭐ 10.5 → 14
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() => _selectedRelationship = value);
                        }
                      },
                      items: _relationships.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: _valueColor,
                              fontSize: 14, // ⭐ 10.5 → 14
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime first = DateTime(1900);
    final DateTime last = DateTime.now();
    DateTime initialDate = DateTime(2000, 1, 1);

    try {
      final parts = _dateNaissanceController.text.split('/');
      if (parts.length == 3) {
        initialDate = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (_) {}

    if (initialDate.isBefore(first)) initialDate = first;
    if (initialDate.isAfter(last)) initialDate = last;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _purple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _titleColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted || picked == null) return;

    setState(() {
      _dateNaissanceController.text =
          '${picked.day.toString().padLeft(2, '0')}/'
          '${picked.month.toString().padLeft(2, '0')}/'
          '${picked.year}';
    });
  }

  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56, // ⭐ 48 → 56
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          elevation: 3,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _saving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Enregistrer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17, // ⭐ 13 → 17
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nomController.text.trim().isEmpty) {
      _snack('Le nom ne peut pas être vide.', background: Colors.red);
      return;
    }

    setState(() => _saving = true);

    try {
      final Map<String, dynamic> data = <String, dynamic>{
        'fullName': _nomController.text.trim(),
        'phone': _telephoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _adresseController.text.trim(),
        'birthDate': _dateNaissanceController.text.trim(),
        'gender': _selectedGender,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_imageBase64 != null && _imageBase64!.isNotEmpty) {
        data['photoUrl'] = _imageBase64;
      } else if (_photoRemoved) {
        data['photoUrl'] = _defaultPhoto;
      }

      if (!widget.isChef) {
        data['relationship'] = _selectedRelationship;
      }

      await FirebaseFirestore.instance
          .collection(_collectionName)
          .doc(widget.userId)
          .update(data);

      if (!mounted) return;

      _snack('Profil modifié avec succès.', background: Colors.green);

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Erreur : $e', background: Colors.red);
      debugPrint('Erreur enregistrement profil : $e');
    }
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
          width: 48, // ⭐ 42 → 48
          height: 48, // ⭐ 42 → 48
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
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
              width: 27, // ⭐ 24 → 27
              height: 27, // ⭐ 24 → 27
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF1F2A6B),
                size: 22, // ⭐ 20 → 22
              ),
            ),
          ),
        ),
      ),
    );
  }
}
