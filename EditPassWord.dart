// lib/EditPassWord.dart
// ⭐ CORRIGÉ : bouton retour élégant
// ⭐ NOUVEAU : mise à jour RÉELLE du mot de passe dans Firebase Auth
// ⭐ NOUVEAU : taille des boutons et textes agrandie
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'DetailUserScreen.dart' show navy, purple, grey;

// ============================================================
// COULEURS
// ============================================================

const Color _fieldBg = Color(0xFFF0F0F2);
const Color _fieldText = Color(0xFF1E2235);
const Color _titleColor = Color(0xFF1F2A6B);
const Color _savePurple = Color(0xFF8E00C8);

// ============================================================
// EDIT PASSWORD SCREEN
// ============================================================

class EditPassWord extends StatefulWidget {
  const EditPassWord({super.key});

  @override
  State<EditPassWord> createState() => _EditPassWordState();
}

class _EditPassWordState extends State<EditPassWord> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
        return Icon(
          fallback ?? Icons.circle,
          size: size,
          color: color ?? navy,
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // RETOUR + TITRE
              Row(
                children: [
                  _ElegantBackButton(
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Modifier mot de passe',
                    style: TextStyle(
                      color: _titleColor,
                      fontSize: 17, // ⭐ 14 → 17
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // MOT DE PASSE COURANT
              _passwordField(
                label: 'Mot de passe courant',
                controller: _currentPasswordController,
                obscure: !_showCurrent,
                onToggle: () {
                  setState(() {
                    _showCurrent = !_showCurrent;
                  });
                },
              ),

              const SizedBox(height: 14),

              // NOUVEAU MOT DE PASSE
              _passwordField(
                label: 'Nouveau mot de passe',
                controller: _newPasswordController,
                obscure: !_showNew,
                onToggle: () {
                  setState(() {
                    _showNew = !_showNew;
                  });
                },
              ),

              const SizedBox(height: 14),

              // CONFIRMER
              _passwordField(
                label: 'Confirmer mot de passe',
                controller: _confirmPasswordController,
                obscure: !_showConfirm,
                onToggle: () {
                  setState(() {
                    _showConfirm = !_showConfirm;
                  });
                },
              ),

              const Spacer(),

              // BOUTON ENREGISTRER
              _buildSaveButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _titleColor,
              fontSize: 14, // ⭐ 12 → 14
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: 50, // ⭐ 32 → 50
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    obscureText: obscure,
                    obscuringCharacter: '•',
                    style: const TextStyle(
                      color: _titleColor,
                      fontSize: 15, // ⭐ 10.5 → 15
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                    cursorColor: _savePurple,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onToggle,
                  child: _asset(
                    'yeux',
                    size: 22, // ⭐ 14 → 22
                    fallback: obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50, // ⭐ 34 → 50
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _enregistrer(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: _savePurple,
          foregroundColor: Colors.white,
          elevation: 3,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text(
                'Enregistrer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17, // ⭐ 11.5 → 17
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ⭐ ENREGISTRER — MET À JOUR LE MOT DE PASSE DANS FIREBASE
  // ═══════════════════════════════════════════════════════

  Future<void> _enregistrer(BuildContext context) async {
    // ⭐ 1. Vérifier champs vides
    if (_currentPasswordController.text.trim().isEmpty ||
        _newPasswordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty) {
      _showMessage(context, 'Veuillez remplir tous les champs.', isError: true);
      return;
    }

    // ⭐ 2. Vérifier que les 2 nouveaux correspondent
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showMessage(context, 'Les nouveaux mots de passe ne correspondent pas.',
          isError: true);
      return;
    }

    // ⭐ 3. Vérifier longueur minimum
    if (_newPasswordController.text.length < 6) {
      _showMessage(
          context, 'Le mot de passe doit contenir au moins 6 caractères.',
          isError: true);
      return;
    }

    // ⭐ 4. Vérifier que le nouveau ≠ ancien
    if (_newPasswordController.text == _currentPasswordController.text) {
      _showMessage(
          context, 'Le nouveau mot de passe doit être différent de l\'ancien.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('Utilisateur non connecté');
      }

      // ⭐ 5. Ré-authentifier l'utilisateur (obligatoire pour Firebase)
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(cred);

      // ⭐ 6. Mettre à jour le mot de passe dans Firebase Auth
      await user.updatePassword(_newPasswordController.text);

      // ⭐ 7. Mettre à jour Firestore aussi (pour cohérence si tu l'utilises)
      try {
        await FirebaseFirestore.instance
            .collection('Chef de Famille')
            .doc(user.uid)
            .update({'motDePasse': _newPasswordController.text});
      } catch (_) {}

      debugPrint('✅ Mot de passe mis à jour pour ${user.uid}');

      if (!mounted) return;
      setState(() => _isLoading = false);

      _showMessage(
        context,
        '✅ Mot de passe mis à jour avec succès !',
        isError: false,
      );

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Erreur: ${e.code} - ${e.message}');
      if (!mounted) return;
      setState(() => _isLoading = false);

      String msg = 'Erreur';
      switch (e.code) {
        case 'wrong-password':
          msg = '❌ Mot de passe actuel incorrect';
          break;
        case 'weak-password':
          msg = '❌ Mot de passe trop faible (min 6 caractères)';
          break;
        case 'requires-recent-login':
          msg = '⚠️ Reconnectez-vous puis réessayez';
          break;
        case 'network-request-failed':
          msg = '📡 Vérifiez votre connexion';
          break;
        default:
          msg = '❌ ${e.message ?? e.code}';
      }
      _showMessage(context, msg, isError: true);
    } catch (e) {
      debugPrint('❌ Erreur: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(context, '❌ ${e.toString()}', isError: true);
    }
  }

  void _showMessage(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, color: Colors.white),
        ),
        backgroundColor:
            isError ? const Color(0xFFE53935) : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 4 : 2),
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
