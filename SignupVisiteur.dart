// lib/SignupVisiteur.dart
// ⭐ NOUVEAU : taille des boutons et textes agrandie
import 'package:ab_fitness_family/LoginVisiteur.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'HomeVisiteur.dart';

class SignupVisiteur extends StatefulWidget {
  const SignupVisiteur({super.key});

  @override
  State<SignupVisiteur> createState() => _SignupVisiteurState();
}

class _SignupVisiteurState extends State<SignupVisiteur> {
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _adresseController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _motDePasseController = TextEditingController();
  final TextEditingController _confirmerController = TextEditingController();

  bool _obscureMotDePasse = true;
  bool _obscureConfirmer = true;
  bool _isLoading = false;

  static const Color titleColor = Color(0xFF1F2A6B);
  static const Color loginColor = Color(0xFF22E4FA);

  bool _isNavigating = false;

  @override
  void dispose() {
    _nomController.dispose();
    _adresseController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _motDePasseController.dispose();
    _confirmerController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _goToLogin() {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
    });
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const LoginVisiteur(),
      ),
    )
        .then((_) {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    });
  }

  // ⭐ INSCRIPTION
  Future<void> _inscrire() async {
    if (_nomController.text.trim().isEmpty ||
        _adresseController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _telephoneController.text.trim().isEmpty ||
        _motDePasseController.text.isEmpty ||
        _confirmerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs.',
              style: TextStyle(fontSize: 15)),
        ),
      );
      return;
    }

    if (_motDePasseController.text != _confirmerController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les mots de passe ne correspondent pas.',
              style: TextStyle(fontSize: 15)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _motDePasseController.text,
      );

      final user = credential.user;
      if (user == null) throw Exception('Erreur création compte');

      await FirebaseFirestore.instance
          .collection('Visiteurs')
          .doc(user.uid)
          .set({
        'userId': user.uid,
        'email': _emailController.text.trim(),
        'nomComplet': _nomController.text.trim(),
        'téléphone': _telephoneController.text.trim(),
        'Adresse': _adresseController.text.trim(),
        'role': 'visiteur',
        'typeCompte': 'visiteur',
        'statut': false,
        'actif': true,
        'dateInscription': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Visiteur créé: ${user.uid}');

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte créé avec succès !',
                style: TextStyle(fontSize: 15)),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeVisiteur()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _isLoading = false);
      String msg = 'Erreur d\'inscription';
      if (e.code == 'email-already-in-use') msg = 'Cet email est déjà utilisé';
      if (e.code == 'invalid-email') msg = 'Email invalide';
      if (e.code == 'weak-password') msg = 'Mot de passe trop faible';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg, style: const TextStyle(fontSize: 15)),
            backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur: $e', style: const TextStyle(fontSize: 15)),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(
            left: 22,
            right: 22,
            top: 10,
            bottom: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ElegantBackButton(
                onTap: _goBack,
              ),

              const SizedBox(height: 6),

              // LOGO
              Center(
                child: Image.asset(
                  'assets/images/aa.png',
                  width: 76, // ⭐ 62 → 76
                  height: 76, // ⭐ 62 → 76
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 6),

              // TITRE
              const Center(
                child: Text(
                  'Créer Un Compte',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 25, // ⭐ 20 → 25
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(height: 5),

              // SOUS TITRE
              Center(
                child: Text(
                  'Rejoignez votre espace familial',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14, // ⭐ 11.5 → 14
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // CHAMP NOM
              _ImageRoundedField(
                controller: _nomController,
                hint: 'Nom Complet',
                iconAsset: 'assets/images/us.png',
              ),

              const SizedBox(height: 12),

              // CHAMP ADRESSE
              _ImageRoundedField(
                controller: _adresseController,
                hint: 'Adresse',
                iconAsset: 'assets/images/ee (5).png',
              ),

              const SizedBox(height: 12),

              // CHAMP EMAIL
              _ImageRoundedField(
                controller: _emailController,
                hint: 'Adresse e-mail',
                iconAsset: 'assets/images/ee (4).png',
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 12),

              // CHAMP TÉLÉPHONE
              _ImageRoundedField(
                controller: _telephoneController,
                hint: 'Numéro de téléphone',
                iconAsset: 'assets/images/ee (3).png',
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 12),

              // CHAMP MOT DE PASSE
              _ImageRoundedField(
                controller: _motDePasseController,
                hint: 'Mot de passe',
                iconAsset: 'assets/images/ee (2).png',
                obscureText: _obscureMotDePasse,
                trailing: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    _obscureMotDePasse
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 22, // ⭐ 18 → 22
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureMotDePasse = !_obscureMotDePasse;
                    });
                  },
                ),
              ),

              const SizedBox(height: 12),

              // CHAMP CONFIRMER
              _ImageRoundedField(
                controller: _confirmerController,
                hint: 'Confirmer le mot de passe',
                iconAsset: 'assets/images/ee (2).png',
                obscureText: _obscureConfirmer,
                trailing: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    _obscureConfirmer
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 22, // ⭐ 18 → 22
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmer = !_obscureConfirmer;
                    });
                  },
                ),
              ),

              const SizedBox(height: 26),

              // BOUTON S'INSCRIRE
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          color: Color(0xFF4439B8),
                        ),
                      ),
                    )
                  : _GradientButton(
                      label: "S'inscrire",
                      onTap: _inscrire,
                    ),

              const SizedBox(height: 18),

              // LIEN VERS CONNEXION
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Déjà un compte ? ',
                        style: TextStyle(
                          fontSize: 14, // ⭐ 11.5 → 14
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: _goToLogin,
                          child: const Text(
                            'Se connecter',
                            style: TextStyle(
                              color: loginColor,
                              fontSize: 14, // ⭐ 11.5 → 14
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
    );
  }
}

// ============================================================================
// ⭐ BOUTON RETOUR ÉLÉGANT
// ============================================================================

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

// ============================================================================
// CHAMP
// ============================================================================

class _ImageRoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String iconAsset;
  final bool obscureText;
  final Widget? trailing;
  final TextInputType? keyboardType;

  const _ImageRoundedField({
    required this.controller,
    required this.hint,
    required this.iconAsset,
    this.obscureText = false,
    this.trailing,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50, // ⭐ 36 → 50
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
          fontSize: 15, // ⭐ 13 → 15
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 15, // ⭐ 13 → 15
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 4,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(
              left: 14,
              right: 8,
            ),
            child: Image.asset(
              iconAsset,
              width: 20, // ⭐ 15 → 20
              height: 20, // ⭐ 15 → 20
              fit: BoxFit.contain,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 42,
            maxWidth: 48,
            minHeight: 50,
            maxHeight: 50,
          ),
          suffixIcon: trailing,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 45,
            maxWidth: 52,
            minHeight: 50,
            maxHeight: 50,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// BOUTON GRADIENT
// ============================================================================

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50, // ⭐ 36 → 50
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF4439B8),
              Color(0xFFE01BB5),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF6A3FE0),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
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
                  fontSize: 17, // ⭐ 13 → 17
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
