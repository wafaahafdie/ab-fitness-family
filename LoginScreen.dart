// lib/LoginScreen.dart
// ⭐ NOUVEAU : taille des boutons et textes agrandie
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'HomeChefScreen .dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _motDePasseController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  static const Color primaryBlue = Color(0xFF1F2A6B);
  static const Color cyan = Color(0xFF22E4FA);

  @override
  void dispose() {
    _emailController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _goToSignup() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // ═══════════════════════════════════════════════════════
  // ⭐ MOT DE PASSE OUBLIÉ
  // ═══════════════════════════════════════════════════════
  Future<void> _motDePasseOublie() async {
    final email = _emailController.text.trim();
    debugPrint('════════════════════════════════════════');
    debugPrint('📧 MOT DE PASSE OUBLIÉ');
    debugPrint('   Email saisi: "$email"');

    if (email.isEmpty || !email.contains('@')) {
      debugPrint('❌ Email vide ou invalide');
      _showMessage(
        'Entrez d\'abord votre email dans le champ ci-dessus',
        isError: true,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Mot de passe oublié ?',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 19),
        ),
        content: Text(
          'Un email de réinitialisation sera envoyé à :\n\n$email\n\n'
          'Cliquez sur le lien dans l\'email pour définir un NOUVEAU mot de passe. '
          'Ensuite vous pourrez vous connecter avec ce nouveau mot de passe.',
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.grey, fontSize: 15)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Envoyer',
              style: TextStyle(
                  color: cyan, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) {
      debugPrint('ℹ️ Annulé par l\'utilisateur');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      debugPrint('✅ Email de réinitialisation ENVOYÉ à $email');

      if (mounted) {
        setState(() => _isLoading = false);
        _showDialogSuccess(email);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Erreur Firebase: ${e.code} - ${e.message}');
      if (mounted) setState(() => _isLoading = false);

      String message = 'Erreur';
      switch (e.code) {
        case 'user-not-found':
          message = '❌ Aucun compte avec cet email';
          break;
        case 'invalid-email':
          message = '❌ Email invalide';
          break;
        case 'too-many-requests':
          message = '⏱️ Trop de tentatives. Attendez 1h';
          break;
        case 'network-request-failed':
          message = '📡 Vérifiez votre connexion';
          break;
        default:
          message = '❌ ${e.message ?? e.code}';
      }
      _showMessage(message, isError: true);
    } catch (e) {
      debugPrint('❌ Erreur: $e');
      if (mounted) setState(() => _isLoading = false);
      _showMessage('❌ Erreur: $e', isError: true);
    }
  }

  void _showDialogSuccess(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read, color: Colors.green, size: 32),
            SizedBox(width: 10),
            Text('Email envoyé !',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Un email a été envoyé à :\n$email',
                style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cliquez sur le lien dans l\'email pour définir votre NOUVEAU mot de passe.',
                      style: TextStyle(fontSize: 13.5, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vérifiez aussi vos SPAMS 📮',
                      style: TextStyle(fontSize: 13.5, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK',
                style: TextStyle(
                    color: cyan, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ⭐ CONNEXION CHEF
  // ═══════════════════════════════════════════════════════
  void _seConnecter() async {
    final String email = _emailController.text.trim();
    final String password = _motDePasseController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Veuillez remplir tous les champs.', isError: true);
      return;
    }
    if (!email.contains('@')) {
      _showMessage('Format d\'email invalide', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception('Erreur de connexion');

      final chefDoc = await FirebaseFirestore.instance
          .collection('Chef de Famille')
          .doc(user.uid)
          .get();

      if (!chefDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() => _isLoading = false);
          _showMessage(
            '❌ Ce compte n\'est pas un compte CHEF DE FAMILLE.',
            isError: true,
          );
        }
        return;
      }

      try {
        await FirebaseFirestore.instance
            .collection('Chef de Famille')
            .doc(user.uid)
            .update({
          'derniereConnexion': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('✅ Connexion réussie !');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeChefScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Erreur Auth: ${e.code} - ${e.message}');
      if (mounted) setState(() => _isLoading = false);

      String message = 'Erreur de connexion';
      switch (e.code) {
        case 'user-not-found':
          message = '❌ Aucun compte avec cet email';
          break;
        case 'wrong-password':
          message =
              '❌ Mot de passe incorrect.\nSi vous venez de le changer, utilisez le NOUVEAU.';
          break;
        case 'invalid-email':
          message = '❌ Email invalide';
          break;
        case 'invalid-credential':
          message =
              '❌ Email ou mot de passe incorrect.\nSi vous venez de le changer, utilisez le NOUVEAU.';
          break;
        case 'too-many-requests':
          message = '⏱️ Trop de tentatives. Réessayez dans quelques minutes.';
          break;
        case 'network-request-failed':
          message = '📡 Vérifiez votre connexion internet';
          break;
        case 'user-disabled':
          message = '⚠️ Ce compte a été désactivé';
          break;
        default:
          message = '❌ ${e.message ?? 'Erreur de connexion'}';
      }
      _showMessage(message, isError: true);
    } catch (e) {
      debugPrint('❌ Erreur: $e');
      if (mounted) setState(() => _isLoading = false);
      _showMessage('❌ $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(fontSize: 15, color: Colors.white)),
        backgroundColor:
            isError ? const Color(0xFFE53935) : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 5 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding:
              const EdgeInsets.only(left: 22, right: 22, top: 10, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ElegantBackButton(onTap: _goBack),
              const SizedBox(height: 6),
              Center(
                child: Image.asset('assets/images/aa.png',
                    width: 76, height: 76, fit: BoxFit.contain),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Se Connecter',
                  style: TextStyle(
                      color: primaryBlue,
                      fontSize: 25,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 5),
              Center(
                child: Text(
                  'Connectez-vous à votre compte',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ),
              const SizedBox(height: 36),
              _LoginField(
                controller: _emailController,
                hintText: 'Adresse e-mail',
                iconAsset: 'assets/images/ee (4).png',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _LoginField(
                controller: _motDePasseController,
                hintText: 'Mot de passe',
                iconAsset: 'assets/images/ee (2).png',
                obscureText: _obscurePassword,
                trailing: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 22,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _isLoading ? null : _motDePasseOublie,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 8, right: 3),
                    child: Text(
                      'Mot de passe oublié ?',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cyan),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 42),
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child:
                            CircularProgressIndicator(color: Color(0xFF4439B8)),
                      ),
                    )
                  : _GradientButton(label: 'Se Connecter', onTap: _seConnecter),
              const SizedBox(height: 18),
              Center(
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: 'Vous n\'avez pas encore de compte ? ',
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: _goToSignup,
                        child: const Text(
                          'Inscrivez-vous',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: cyan),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// BOUTON RETOUR ÉLÉGANT
// ═══════════════════════════════════════════════════════

class _ElegantBackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ElegantBackButton({required this.onTap});

  @override
  State<_ElegantBackButton> createState() => _ElegantBackButtonState();
}

class _ElegantBackButtonState extends State<_ElegantBackButton> {
  bool _pressed = false;
  void _setPressed(bool v) {
    if (mounted) setState(() => _pressed = v);
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
                  offset: const Offset(0, 3))
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
                  size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// CHAMP DE SAISIE
// ═══════════════════════════════════════════════════════

class _LoginField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String iconAsset;
  final bool obscureText;
  final Widget? trailing;
  final TextInputType? keyboardType;

  const _LoginField({
    required this.controller,
    required this.hintText,
    required this.iconAsset,
    this.obscureText = false,
    this.trailing,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
            fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 15, color: Colors.grey.shade500),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Image.asset(iconAsset,
                width: 20, height: 20, fit: BoxFit.contain),
          ),
          prefixIconConstraints: const BoxConstraints(
              minWidth: 42, maxWidth: 48, minHeight: 50, maxHeight: 50),
          suffixIcon: trailing,
          suffixIconConstraints: const BoxConstraints(
              minWidth: 45, maxWidth: 52, minHeight: 50, maxHeight: 50),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// BOUTON GRADIENT
// ═══════════════════════════════════════════════════════

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: const LinearGradient(
              colors: [Color(0xFF4439B8), Color(0xFFE01BB5)]),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFF6A3FE0), blurRadius: 6, offset: Offset(0, 3))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
