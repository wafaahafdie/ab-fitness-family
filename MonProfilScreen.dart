// lib/MonProfilScreen.dart - VERSION COMPLÈTE CORRIGÉE ✅
// ⭐ AJOUT : mode VISITEUR (isVisitor)
// ⭐ AJOUT : paramètre canDownload (juste pour compilation, pas d'action)
// ⭐ Support de PLUSIEURS noms de champs Firestore
// ⭐ Déconnexion avec ANIMATION vers RoleSelectionScreen
// ⭐ NOUVEAU : taille des boutons et textes agrandie

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'DetailUserScreen.dart' show navy, purple, grey;
import 'EditProfilScreen.dart';
import 'EditPassWord.dart';
import 'RoleSelectionScreen.dart';
import 'dart:convert';

// ============================================================
// COULEURS
// ============================================================

const Color _titleColor = Color(0xFF1F2A6B);
const Color _textColor = Color(0xFF303044);
const Color _backCircleBg = Color(0xFFDFF6FF);
const Color _fieldBorder = Color(0xFFD69AF3);
const Color _menuBorder = Color(0xFFAEB0C7);
const Color _logoutColor = Color(0xFF9400C8);

// ============================================================
// MON PROFIL
// ============================================================

class MonProfilScreen extends StatefulWidget {
  final String userId;
  final bool isChef;
  final bool isVisitor;
  final bool canDownload;

  const MonProfilScreen({
    super.key,
    required this.userId,
    this.isChef = false,
    this.isVisitor = false,
    this.canDownload = false,
  });

  @override
  State<MonProfilScreen> createState() => _MonProfilScreenState();
}

// ============================================================
// STATE
// ============================================================

class _MonProfilScreenState extends State<MonProfilScreen> {
  bool _loading = true;
  bool _isRefreshing = false;
  String? _error;
  Map<String, dynamic> _data = {};
  String _collectionName = '';
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _collectionName = widget.isChef ? 'Chef de Famille' : 'Membres Famille';
    _loadProfil();
  }

  Future<void> _loadProfil() async {
    if (!mounted) return;

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
          _error = 'Profil introuvable.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _data = snap.data() ?? {};
        _loading = false;
        _refreshKey++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur de chargement : $e';
        _loading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    await _loadProfil();

    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  String _read(List<String> keys, {String fallback = '—'}) {
    for (final k in keys) {
      final v = _data[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString();
      }
    }
    return fallback;
  }

  String get _fullName => _read(
        ['fullName', 'nomComplet', 'name', 'nom'],
        fallback: '—',
      );

  String get _role {
    if (widget.isChef) return 'Chef de famille';
    return _read(
      ['relationship', 'relation', 'lien', 'role'],
      fallback: 'Membre',
    );
  }

  String get _address => _read(['address', 'adresse'], fallback: '—');
  String get _email => _read(['email', 'mail'], fallback: '—');
  String get _phone => _read(
        ['phone', 'téléphone', 'telephone', 'tel', 'numero'],
        fallback: '—',
      );
  String get _birthDate => _read(
        ['birthDate', 'dateNaissance', 'date_naissance'],
        fallback: '—',
      );
  String get _gender => _read(
        ['gender', 'genre', 'sexe'],
        fallback: '—',
      );
  String get _photoUrl => _read(
        ['photoUrl', 'photo_url', 'photo'],
        fallback: 'assets/images/profilpat.jpg',
      );

  Widget _buildAvatar({double radius = 44}) {
    String photoUrl = _photoUrl;

    if (photoUrl.startsWith('assets/')) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: AssetImage(photoUrl),
        backgroundColor: const Color(0xFFF0F0F2),
      );
    } else if (photoUrl.startsWith('http://') ||
        photoUrl.startsWith('https://')) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl),
        backgroundColor: const Color(0xFFF0F0F2),
      );
    } else {
      try {
        String base64String = photoUrl;
        if (photoUrl.contains(',')) {
          base64String = photoUrl.split(',').last;
        }
        base64String = base64String.replaceAll(RegExp(r'\s'), '');
        final mod = base64String.length % 4;
        if (mod != 0) {
          base64String =
              base64String.padRight(base64String.length + (4 - mod), '=');
        }
        final decodedBytes = base64Decode(base64String);
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(decodedBytes),
          backgroundColor: const Color(0xFFF0F0F2),
        );
      } catch (e) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: const AssetImage('assets/images/profilpat.jpg'),
          backgroundColor: const Color(0xFFF0F0F2),
        );
      }
    }
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
      errorBuilder: (context, error, stackTrace) {
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
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: purple))
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  )
                : SingleChildScrollView(
                    key: ValueKey(_refreshKey),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _ElegantBackButton(
                                onTap: () {
                                  Navigator.pop(
                                      context, widget.isVisitor ? false : true);
                                },
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.isVisitor
                                    ? 'Profil du membre'
                                    : 'Mon profil',
                                style: const TextStyle(
                                  color: _titleColor,
                                  fontSize: 17, // ⭐ 14 → 17
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_isRefreshing)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: purple,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 23),

                          Center(child: _buildAvatar(radius: 44)), // ⭐ 36 → 44

                          const SizedBox(height: 10),

                          Center(
                            child: Text(
                              _fullName,
                              style: const TextStyle(
                                color: _titleColor,
                                fontSize: 18, // ⭐ 15 → 18
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 5), // ⭐ +grand
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Color(0xFFC69BD5),
                                    Color(0xFFE68BCF)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _role,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11, // ⭐ 9 → 11
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          _readOnlyField('Nom Complet', _fullName),
                          const SizedBox(height: 13),
                          _readOnlyField('Date de naissance', _birthDate),
                          const SizedBox(height: 13),
                          _readOnlyField('Genre', _gender),
                          const SizedBox(height: 13),
                          _readOnlyField('Adresse', _address),
                          const SizedBox(height: 13),
                          _readOnlyField('Email', _email),
                          const SizedBox(height: 13),
                          _readOnlyField('Téléphone', _phone),

                          const SizedBox(height: 26),

                          if (!widget.isVisitor) ...[
                            _menuButton(
                              label: 'Modifier profil',
                              onTap: _modifierProfil,
                            ),
                            if (widget.isChef) ...[
                              const SizedBox(height: 14),
                              _menuButton(
                                label: 'Modifier mot de passe',
                                onTap: _modifierMotDePasse,
                              ),
                            ],
                            const SizedBox(height: 28),
                            _buildLogoutButton(context),
                          ] else ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0EDFF),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: purple.withOpacity(0.25)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.visibility_outlined,
                                      color: purple, size: 19),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Mode lecture seule — profil consulté via une autorisation.',
                                      style: TextStyle(
                                        color: purple,
                                        fontSize: 12.5, // ⭐ 11 → 12.5
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _textColor,
            fontSize: 13, // ⭐ 11 → 13
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: 48, // ⭐ 40 → 48
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _fieldBorder, width: 1),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textColor,
              fontSize: 15, // ⭐ 13 → 15
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
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
            border: Border.all(color: _menuBorder, width: 0.9),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 5,
                  offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _titleColor,
                  fontSize: 15.5, // ⭐ 13 → 15.5
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: _titleColor, size: 20), // ⭐ 17 → 20
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
            color: _logoutColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x30000000),
                  blurRadius: 5,
                  offset: Offset(0, 3)),
            ],
          ),
          child: const Center(
            child: Text(
              'Déconnecter',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14, // ⭐ 11 → 14
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _modifierProfil() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilScreen(
          userId: widget.userId,
          isChef: widget.isChef,
        ),
      ),
    );

    if (result == true) {
      await _refreshData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  '✅ Profil mis à jour !',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _modifierMotDePasse() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditPassWord()),
    );
  }

  void _confirmerDeconnexion(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            'Déconnexion',
            style: TextStyle(
                color: navy, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: const Text(
            'Voulez-vous vraiment vous déconnecter ?',
            style: TextStyle(color: grey, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler',
                  style: TextStyle(color: grey, fontSize: 14)),
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
                    color: purple, fontWeight: FontWeight.bold, fontSize: 14),
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
                color: _titleColor,
                size: 22, // ⭐ 20 → 22
              ),
            ),
          ),
        ),
      ),
    );
  }
}
