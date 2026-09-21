// lib/SignupChef.dart - AVEC BOUTON RETOUR ÉLÉGANT ✅
// ⭐ NOUVEAU : taille des boutons et textes agrandie
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'LoginScreen.dart';
import 'HomeChefScreen .dart';
import 'package:flutter/services.dart';

class SignupChef extends StatefulWidget {
  const SignupChef({super.key});

  @override
  State<SignupChef> createState() => _SignupChefState();
}

class _SignupChefState extends State<SignupChef> {
  final TextEditingController _nomCompletController = TextEditingController();
  final TextEditingController _adresseController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _motDePasseController = TextEditingController();
  final TextEditingController _confirmerController = TextEditingController();

  bool _obscureMotDePasse = true;
  bool _obscureConfirmer = true;
  bool _isLoading = false;
  bool _isNavigating = false;

  static const Color titleColor = Color(0xFF1F2A6B);
  static const Color loginColor = Color(0xFF22E4FA);

  // =============================================
  // 🔍 VÉRIFICATIONS DOUBLONS
  // =============================================

  Future<bool> _emailExisteDeja(String email) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Chef de Famille')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _telephoneExisteDeja(String phone) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Chef de Famille')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _nomCompletExisteDeja(String fullName) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Chef de Famille')
          .where('fullName', isEqualTo: fullName)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // =============================================
  // 📝 VALIDATIONS DES CHAMPS
  // =============================================

  String? _validateNomComplet(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez entrer votre nom complet';
    }
    final parts = value.trim().split(' ');
    if (parts.length < 2) {
      return 'Entrez votre nom et prénom (ex: Jean Dupont)';
    }
    if (parts.any((part) => part.length < 2)) {
      return 'Nom et prénom doivent contenir au moins 2 caractères';
    }
    if (!RegExp(r'^[a-zA-ZÀ-ÿ\s\-]+$').hasMatch(value.trim())) {
      return 'Nom invalide (caractères spéciaux non autorisés)';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez entrer votre email';
    }
    final email = value.trim();
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email)) {
      return 'Format d\'email invalide (ex: nom@email.com)';
    }
    return null;
  }

  String? _validateTelephone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez entrer votre numéro de téléphone';
    }
    final phone = value.trim().replaceAll(' ', '');
    if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
      return 'Le numéro doit contenir uniquement des chiffres';
    }
    if (phone.length != 10) {
      return 'Le numéro doit contenir exactement 10 chiffres (ex: 0612345678)';
    }
    return null;
  }

  String? _validateMotDePasse(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer un mot de passe';
    }
    if (value.length < 6) {
      return 'Minimum 6 caractères';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Doit contenir une majuscule';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Doit contenir un chiffre';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez confirmer votre mot de passe';
    }
    if (value != _motDePasseController.text) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  // =============================================
  // 🚀 INSCRIPTION
  // =============================================

  void _inscrire() async {
    final nomValid = _validateNomComplet(_nomCompletController.text);
    final adresseValid = _adresseController.text.trim().isEmpty
        ? 'Veuillez entrer votre adresse'
        : null;
    final emailValid = _validateEmail(_emailController.text);
    final phoneValid = _validateTelephone(_telephoneController.text);
    final passwordValid = _validateMotDePasse(_motDePasseController.text);
    final confirmValid = _validateConfirmation(_confirmerController.text);

    final String? firstError = nomValid ??
        adresseValid ??
        emailValid ??
        phoneValid ??
        passwordValid ??
        confirmValid;

    if (firstError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(firstError, style: const TextStyle(fontSize: 15)),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fullName = _nomCompletController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final phone = _telephoneController.text.trim().replaceAll(' ', '');
      final password = _motDePasseController.text;
      final address = _adresseController.text.trim();

      final emailExiste = await _emailExisteDeja(email);
      if (emailExiste) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Cet email est déjà utilisé par un autre Chef !',
                style: TextStyle(fontSize: 15)),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final phoneExiste = await _telephoneExisteDeja(phone);
      if (phoneExiste) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Ce numéro est déjà utilisé par un autre Chef !',
                style: TextStyle(fontSize: 15)),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final nomExiste = await _nomCompletExisteDeja(fullName);
      if (nomExiste) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Le Chef "$fullName" existe déjà !',
                style: const TextStyle(fontSize: 15)),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user!.uid;
      final familyId = 'famille_${DateTime.now().millisecondsSinceEpoch}';

      await FirebaseFirestore.instance
          .collection('Chef de Famille')
          .doc(userId)
          .set({
        'fullName': fullName,
        'address': address,
        'email': email,
        'phone': phone,
        'role': 'chef_famille',
        'familyId': familyId,
        'familyMembers': [],
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await FirebaseFirestore.instance
          .collection('Membres Famille')
          .doc(userId)
          .set({
        'familyId': familyId,
        'userId': userId,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'address': address,
        'birthDate': null,
        'relationship': 'Chef de famille',
        'isHead': true,
        'photoUrl': null,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await FirebaseFirestore.instance
          .collection('Familles')
          .doc(familyId)
          .set({
        'familyId': familyId,
        'chefId': userId,
        'chefName': fullName,
        'address': address,
        'phone': phone,
        'email': email,
        'membersCount': 0,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Inscription réussie ! Bienvenue Chef !',
                style: TextStyle(fontSize: 15)),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeChefScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);

      String message = 'Erreur lors de l\'inscription';
      if (e.code == 'email-already-in-use') {
        message = 'Cet email est déjà utilisé';
      } else if (e.code == 'weak-password') {
        message = 'Mot de passe trop faible';
      } else if (e.code == 'network-request-failed') {
        message = 'Vérifiez votre connexion internet';
      } else if (e.code == 'invalid-email') {
        message = 'Format d\'email invalide';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('❌ $message', style: const TextStyle(fontSize: 15)),
            backgroundColor: Colors.red),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}',
              style: const TextStyle(fontSize: 15)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =============================================
  // 🖥️ UI
  // =============================================

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
              _ElegantBackButton(
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
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

              // CHAMP NOM COMPLET
              _ImageRoundedField(
                controller: _nomCompletController,
                hint: 'Nom Complet ',
                iconAsset: 'assets/images/ee (1).png',
              ),
              const SizedBox(height: 12),

              _ImageRoundedField(
                controller: _adresseController,
                hint: 'Adresse',
                iconAsset: 'assets/images/ee (5).png',
              ),
              const SizedBox(height: 12),

              _ImageRoundedField(
                controller: _emailController,
                hint: 'Adresse e-mail ',
                iconAsset: 'assets/images/ee (4).png',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              _ImageRoundedField(
                controller: _telephoneController,
                hint: 'Numéro de téléphone (10 chiffres) ',
                iconAsset: 'assets/images/ee (3).png',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: 12),

              _ImageRoundedField(
                controller: _motDePasseController,
                hint: 'Mot de passe ',
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
                    setState(() => _obscureMotDePasse = !_obscureMotDePasse);
                  },
                ),
              ),
              const SizedBox(height: 12),

              _ImageRoundedField(
                controller: _confirmerController,
                hint: 'Confirmer le mot de passe ',
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
                    setState(() => _obscureConfirmer = !_obscureConfirmer);
                  },
                ),
              ),
              const SizedBox(height: 26),

              // BOUTON
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

              // LIEN LOGIN
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
                          onTap: () {
                            if (!_isNavigating) {
                              setState(() => _isNavigating = true);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              ).then((_) {
                                if (mounted) {
                                  setState(() => _isNavigating = false);
                                }
                              });
                            }
                          },
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

// =============================================
// ⭐ BOUTON RETOUR ÉLÉGANT
// =============================================

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

// =============================================
// 🧩 WIDGETS RÉUTILISABLES
// =============================================

class _ImageRoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String iconAsset;
  final bool obscureText;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _ImageRoundedField({
    required this.controller,
    required this.hint,
    required this.iconAsset,
    this.obscureText = false,
    this.trailing,
    this.keyboardType,
    this.inputFormatters,
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
        inputFormatters: inputFormatters,
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
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
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
            colors: [Color(0xFF4439B8), Color(0xFFE01BB5)],
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
