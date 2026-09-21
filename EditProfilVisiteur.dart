// lib/EditProfilVisiteur.dart
// ⭐ CORRIGÉ : bouton retour élégant
// ⭐ CORRIGÉ : l'icône caméra ouvre la GALERIE
// ⭐ NOUVEAU : taille des boutons et textes agrandie
// ⭐ NOUVEAU : icône caméra plus petite et discrète
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

const Color navy = Color(0xFF1F2A6B);
const Color grey = Color(0xFF9E9EAE);
const Color purple = Color(0xFF8E00C8);
const Color fieldBorder = Color(0xFFD0D0D0);
const Color labelColor = Color(0xFF70708A);
const Color valueColor = Color(0xFF1E2235);

class EditProfilVisiteur extends StatefulWidget {
  const EditProfilVisiteur({Key? key}) : super(key: key);

  @override
  State<EditProfilVisiteur> createState() => _EditProfilVisiteurState();
}

class _EditProfilVisiteurState extends State<EditProfilVisiteur> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _villeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _profileImagePath;
  Uint8List? _newPhotoBytes;
  String _existingPhotoUrl = '';
  Uint8List? _existingPhotoBytes;
  bool _isLoading = true;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _chargerInfos();
  }

  Future<void> _chargerInfos() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('Visiteurs')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;

        String photo = data['photoUrl']?.toString() ?? '';
        Uint8List? photoBytes;
        if (photo.isNotEmpty &&
            !photo.startsWith('http') &&
            !photo.startsWith('assets/')) {
          try {
            String b64 = photo;
            if (b64.contains(',')) b64 = b64.split(',').last;
            b64 = b64.replaceAll('"', '').replaceAll(' ', '');
            photoBytes = base64Decode(b64);
          } catch (e) {
            debugPrint('⚠️ Erreur photo: $e');
          }
        }

        setState(() {
          _nameController.text = data['nomComplet']?.toString() ?? '';
          _villeController.text = data['Adresse']?.toString() ?? '';
          _emailController.text = data['email']?.toString() ?? '';
          _phoneController.text = data['téléphone']?.toString() ?? '';
          _existingPhotoUrl = photo;
          _existingPhotoBytes = photoBytes;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Erreur: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _villeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _asset(String name, {double size = 20, Color? color}) {
    return Image.asset(
      'assets/images/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.circle_outlined, size: size, color: color ?? navy);
      },
    );
  }

  Future<void> _changerPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        if (mounted) {
          setState(() {
            _profileImagePath = image.path;
            _newPhotoBytes = bytes;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur galerie: $e');
      if (mounted) {
        _showMessage('❌ Impossible d\'ouvrir la galerie', isError: true);
      }
    }
  }

  // ⭐⭐⭐ ICÔNE CAMÉRA PLUS PETITE ⭐⭐⭐
  Widget _buildProfileImage() {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Photo de profil
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFE5E0F1),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(child: _buildCurrentPhoto()),
          ),

          // ⭐ Bouton caméra PLUS PETIT
          Positioned(
            right: -2, // ⭐ -4 → -2
            bottom: -2, // ⭐ -4 → -2
            child: GestureDetector(
              onTap: _changerPhoto,
              child: Container(
                width: 32, // ⭐ 44 → 32
                height: 32, // ⭐ 44 → 32
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E2235),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5, // ⭐ 2 → 1.5
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 4, // ⭐ 5 → 4
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/cam.png',
                    width: 15, // ⭐ 22 → 15
                    height: 15, // ⭐ 22 → 15
                    fit: BoxFit.contain,
                    color: Colors.white,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.camera_alt,
                        size: 15, // ⭐ 22 → 15
                        color: Colors.white,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPhoto() {
    if (_newPhotoBytes != null) {
      return Image.memory(_newPhotoBytes!,
          width: 96, height: 96, fit: BoxFit.cover);
    }
    if (_existingPhotoBytes != null) {
      return Image.memory(_existingPhotoBytes!,
          width: 96, height: 96, fit: BoxFit.cover);
    }
    return Image.asset(
      'assets/images/profilpat.jpg',
      width: 96,
      height: 96,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFFF0F0F2),
          child: const Icon(
            Icons.person,
            size: 44,
            color: Color(0xFFB8B8C8),
          ),
        );
      },
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
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fieldBorder, width: 1),
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
            _asset(icon, size: 22, color: Colors.black87),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: labelColor,
                      fontSize: 11,
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
                        color: valueColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      cursorColor: purple,
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
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Modifier profil',
                  style: TextStyle(
                    color: navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: purple))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Column(
                        children: [
                          _buildProfileImage(),
                          const SizedBox(height: 26),
                          _buildTextField(
                            icon: 'user',
                            fallback: Icons.person_outline,
                            label: 'Nom Complet',
                            controller: _nameController,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            icon: 'adr',
                            fallback: Icons.location_on_outlined,
                            label: 'Ville',
                            controller: _villeController,
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
                            icon: 'tl',
                            fallback: Icons.phone_outlined,
                            label: 'Téléphone',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    child: _buildSaveButton(context),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : () => _enregistrerProfil(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSaving ? Colors.grey : purple,
          foregroundColor: Colors.white,
          elevation: 3,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
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
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Future<void> _enregistrerProfil(BuildContext context) async {
    final name = _nameController.text.trim();
    final ville = _villeController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || ville.isEmpty || email.isEmpty || phone.isEmpty) {
      _showMessage('Veuillez remplir tous les champs.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Non connecté');

      String newPhotoBase64 = _existingPhotoUrl;
      if (_newPhotoBytes != null) {
        newPhotoBase64 = base64Encode(_newPhotoBytes!);
        debugPrint('✅ Photo encodée Base64 (${newPhotoBase64.length} chars)');
      }

      await FirebaseFirestore.instance
          .collection('Visiteurs')
          .doc(user.uid)
          .update({
        'nomComplet': name,
        'Adresse': ville,
        'email': email,
        'téléphone': phone,
        if (newPhotoBase64.isNotEmpty) 'photoUrl': newPhotoBase64,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Profil mis à jour');

      if (mounted) {
        _showMessage('✅ Profil modifié avec succès !');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Erreur: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showMessage('❌ Erreur: $e', isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 15)),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
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
          width: 48,
          height: 48,
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
              width: 27,
              height: 27,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF1F2A6B),
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
