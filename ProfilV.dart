// lib/ProfilV.dart
// ⭐ NOUVEAU : taille des boutons et textes agrandie
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'EditProfilVisiteur.dart';
import 'EditPVisiteur.dart';
import 'RoleSelectionScreen.dart';

const Color navy = Color(0xFF1F2A6B);
const Color grey = Color(0xFF9E9EAE);
const Color purple = Color(0xFF890CC2);
const Color fieldBorder = Color(0xFFD69AF3);
const Color menuBorder = Color(0xFFAEB0C7);
const Color logoutColor = Color(0xFF9400C8);
const Color backCircleBg = Color(0xFFDFF6FF);

class ProfilV extends StatefulWidget {
  const ProfilV({Key? key}) : super(key: key);

  @override
  State<ProfilV> createState() => _ProfilVState();
}

class _ProfilVState extends State<ProfilV> {
  String _nomComplet = 'Chargement...';
  String _adresse = '';
  String _email = '';
  String _telephone = '';
  String _typeVisiteur = '';
  String _photoUrl = '';
  Uint8List? _photoBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerProfil();
  }

  Future<void> _chargerProfil() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      debugPrint('🔍 Chargement profil: ${user.uid}');

      final doc = await FirebaseFirestore.instance
          .collection('Visiteurs')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        debugPrint('⚠️ Visiteur introuvable');
        if (mounted) {
          setState(() {
            _nomComplet = 'Utilisateur';
            _email = user.email ?? '';
            _isLoading = false;
          });
        }
        return;
      }

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
          debugPrint('⚠️ Erreur décodage Base64: $e');
        }
      }

      if (mounted) {
        setState(() {
          _nomComplet = data['nomComplet']?.toString() ?? 'Utilisateur';
          _adresse = data['Adresse']?.toString() ?? '';
          _email = data['email']?.toString() ?? user.email ?? '';
          _telephone = data['téléphone']?.toString() ?? '';
          _typeVisiteur = data['typeVisiteur']?.toString() ?? '';
          _photoUrl = photo;
          _photoBytes = photoBytes;
          _isLoading = false;
        });
      }

      debugPrint('✅ Profil chargé: $_nomComplet');
    } catch (e) {
      debugPrint('❌ Erreur profil: $e');
      if (mounted) {
        setState(() {
          _nomComplet = 'Utilisateur';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: purple))
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _ElegantBackButton(
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Mon profil',
                            style: TextStyle(
                              color: navy,
                              fontSize: 17, // ⭐ 14 → 17
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 23),

                      // PHOTO
                      Center(
                        child: Container(
                          width: 86, // ⭐ 72 → 86
                          height: 86, // ⭐ 72 → 86
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE4DDF2),
                              width: 1.2,
                            ),
                          ),
                          child: ClipOval(child: _buildPhoto()),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // BADGE TYPE VISITEUR
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18, // ⭐ 16 → 18
                            vertical: 8, // ⭐ 6 → 8
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFC69BD5),
                                Color(0xFFE68BCF),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            _typeVisiteur.isNotEmpty
                                ? _typeVisiteur
                                : 'Visiteur',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14, // ⭐ 12 → 14
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // CHAMPS
                      _readOnlyField(
                          _nomComplet.isEmpty ? 'Non renseigné' : _nomComplet),
                      const SizedBox(height: 13),

                      _readOnlyField(
                          _adresse.isEmpty ? 'Non renseigné' : _adresse),
                      const SizedBox(height: 13),

                      _readOnlyField(_email.isEmpty ? 'Non renseigné' : _email),
                      const SizedBox(height: 13),

                      _readOnlyField(
                          _telephone.isEmpty ? 'Non renseigné' : _telephone),

                      const SizedBox(height: 26),

                      // MODIFIER PROFIL
                      _menuButton(
                        label: 'Modifier profil',
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfilVisiteur(),
                            ),
                          );
                          if (result == true) _chargerProfil();
                        },
                      ),

                      const SizedBox(height: 14),

                      // MODIFIER MOT DE PASSE
                      _menuButton(
                        label: 'Modifier mot de passe',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditPVisiteur(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 28),

                      // DECONNECTER
                      _buildLogoutButton(context),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPhoto() {
    if (_photoBytes != null && _photoBytes!.isNotEmpty) {
      return Image.memory(
        _photoBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultPhoto(),
      );
    }
    if (_photoUrl.isNotEmpty && _photoUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: _photoUrl,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _defaultPhoto(),
      );
    }
    return _defaultPhoto();
  }

  Widget _defaultPhoto() {
    return Image.asset(
      'assets/images/profilpat.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFFF0F0F2),
          child: const Icon(
            Icons.person,
            size: 42, // ⭐ 35 → 42
            color: Color(0xFFB8B8C8),
          ),
        );
      },
    );
  }

  Widget _readOnlyField(String value) {
    return Center(
      child: Container(
        width: double.infinity,
        height: 48, // ⭐ 40 → 48
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: fieldBorder, width: 1),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF303044),
            fontSize: 15, // ⭐ 13 → 15
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _menuButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 62, // ⭐ 54 → 62
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: menuBorder, width: 0.9),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: navy,
                  fontSize: 15.5, // ⭐ 13 → 15.5
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: navy, size: 20), // ⭐ 17 → 20
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => _confirmerDeconnexion(context),
        child: Container(
          width: double.infinity,
          height: 46, // ⭐ 35 → 46
          decoration: BoxDecoration(
            color: logoutColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Déconnecter',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14, // ⭐ 11 → 14
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmerDeconnexion(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Déconnexion',
            style: TextStyle(
              color: navy,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          content: const Text(
            'Voulez-vous vraiment vous déconnecter ?',
            style: TextStyle(color: grey, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Annuler',
                style: TextStyle(color: grey, fontSize: 14),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                await FirebaseAuth.instance.signOut();

                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const RoleSelectionScreen(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        final fadeAnim = Tween<double>(
                          begin: 0.0,
                          end: 1.0,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: const Interval(
                              0.0,
                              0.6,
                              curve: Curves.easeOut,
                            ),
                          ),
                        );

                        final slideAnim = Tween<Offset>(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: const Interval(
                              0.0,
                              0.7,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                        );

                        final scaleAnim = Tween<double>(
                          begin: 0.9,
                          end: 1.0,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: const Interval(
                              0.0,
                              0.8,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                        );

                        return FadeTransition(
                          opacity: fadeAnim,
                          child: SlideTransition(
                            position: slideAnim,
                            child: ScaleTransition(
                              scale: scaleAnim,
                              child: child,
                            ),
                          ),
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 700),
                    ),
                    (route) => false,
                  );
                }
              },
              child: const Text(
                'Déconnecter',
                style: TextStyle(
                  color: purple,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// BOUTON RETOUR ÉLÉGANT
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
                color: navy,
                size: 22, // ⭐ 20 → 22
              ),
            ),
          ),
        ),
      ),
    );
  }
}
