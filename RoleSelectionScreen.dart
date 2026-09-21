import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'SignupChef.dart';
import 'SignupVisiteur.dart';

// ============================================================
// COULEURS
// ============================================================
const Color kNavy = Color(0xFF1F2A6B);
const Color kPurple = Color(0xFF890CC2);
const Color kPurpleDark = Color(0xFF5B1E9E);
const Color kBlue = Color(0xFF3567D6);
const Color kGreen = Color(0xFF22B573);

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  // ============================================================
  // RETOUR
  // ============================================================

  void _goBack() {
    if (!mounted) return;

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // ============================================================
  // ALLER VERS SIGNUP CHEF
  // ============================================================

  void _goToSignupChef() {
    if (_isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const SignupChef(),
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

  // ============================================================
  // ALLER VERS SIGNUP VISITEUR
  // ============================================================

  void _goToSignupVisiteur() {
    if (_isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const SignupVisiteur(),
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FB),
      body: SafeArea(
        child: Stack(
          children: [
            // CERCLES ANIMÉS (formes décoratives pastel)
            AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                final double t = _floatController.value * 2 * math.pi;

                return Stack(
                  children: [
                    Positioned(
                      top: 10 + math.sin(t) * 12,
                      right: -30 + math.cos(t) * 8,
                      child: _FloatingCircle(
                        size: 130,
                        color: const Color(0xFFE85CA8).withOpacity(0.35),
                      ),
                    ),
                    Positioned(
                      top: 280 + math.cos(t) * 14,
                      left: -50 + math.sin(t) * 10,
                      child: _FloatingCircle(
                        size: 180,
                        color: const Color(0xFFF6D95A).withOpacity(0.38),
                      ),
                    ),
                    Positioned(
                      bottom: 20 + math.sin(t + 1) * 12,
                      right: -40 + math.cos(t + 1) * 8,
                      child: _FloatingCircle(
                        size: 160,
                        color: const Color(0xFF8B6FE8).withOpacity(0.30),
                      ),
                    ),
                  ],
                );
              },
            ),

            // CONTENU
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // RETOUR
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Row(
                              children: [
                                _BackButton(onTap: _goBack),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // LOGO dans un badge premium
                          Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white, Color(0xFFF3EEFF)],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: kPurple.withOpacity(0.10), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: kPurple.withOpacity(0.18),
                                  blurRadius: 30,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/images/aa.png',
                                width: 72,
                                height: 72,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // MARQUE
                          const Text(
                            'ESPACE FAMILIAL SÉCURISÉ',
                            style: TextStyle(
                              fontSize: 10.5,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w800,
                              color: kPurple,
                            ),
                          ),

                          const SizedBox(height: 22),

                          // TITRE
                          const Text(
                            'Bienvenue !',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: kNavy,
                              letterSpacing: -0.5,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Choisissez votre rôle pour continuer',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 30),

                          // ⭐ CARTES (même hauteur fixe)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: Column(
                              children: [
                                // CHEF DE FAMILLE
                                _RoleCard(
                                  iconAsset: 'assets/images/oo.png',
                                  title: 'Chef de famille',
                                  tag: 'Admin',
                                  subtitle:
                                      'Administrez votre espace familial en toute simplicité.',
                                  accent1: kPurple,
                                  accent2: kPurpleDark,
                                  iconBg: const Color(0xFFF2E9FF),
                                  onTap: _goToSignupChef,
                                ),

                                const SizedBox(height: 18),

                                // VISITEUR
                                _RoleCard(
                                  iconAsset: 'assets/images/cc.png',
                                  title: 'Visiteur',
                                  tag: 'Invité',
                                  subtitle:
                                      'Découvrez les membres de la famille avec l\'autorisation du chef.',
                                  accent1: const Color(0xFF5A9BFF),
                                  accent2: kBlue,
                                  iconBg: const Color(0xFFE7F0FF),
                                  onTap: _goToSignupVisiteur,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          // ⭐ BADGE SÉCURITÉ (placé juste en dessous des cartes)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: kGreen.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.verified_user_rounded,
                                    color: kGreen, size: 15),
                                SizedBox(width: 6),
                                Text(
                                  'Connexion sécurisée',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: kGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // TEXTE BAS
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 18),
                            child: const Text(
                              'Toute votre famille,\n'
                              'connectée et protégée\n'
                              'au même endroit',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: kNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CERCLE
// ============================================================================

class _FloatingCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _FloatingCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

// ============================================================================
// BOUTON RETOUR
// ============================================================================

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;

  const _BackButton({
    required this.onTap,
  });

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted) return;

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _setPressed(true);
      },
      onTapUp: (_) {
        _setPressed(false);
      },
      onTapCancel: () {
        _setPressed(false);
      },
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
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ⭐ CARTE ROLE — HAUTEUR FIXE + ANIMATION RENFORCÉE
// ============================================================================

class _RoleCard extends StatefulWidget {
  final String iconAsset;
  final String title;
  final String tag;
  final String subtitle;
  final Color accent1;
  final Color accent2;
  final Color iconBg;
  final VoidCallback onTap;

  const _RoleCard({
    required this.iconAsset,
    required this.title,
    required this.tag,
    required this.subtitle,
    required this.accent1,
    required this.accent2,
    required this.iconBg,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted) return;

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _setPressed(true);
      },
      onTapUp: (_) {
        _setPressed(false);
      },
      onTapCancel: () {
        _setPressed(false);
      },
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0, // ⭐ Animation plus marquée
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // ⭐ HAUTEUR FIXE pour les 2 cartes
          height: 110,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _pressed
                  ? widget.accent1.withOpacity(0.4)
                  : const Color(0xFFEFEAFB),
              width: _pressed ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _pressed
                    ? widget.accent1.withOpacity(0.30)
                    : Colors.black.withOpacity(0.07),
                blurRadius: _pressed ? 26 : 16,
                offset: Offset(0, _pressed ? 8 : 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // BARRE D'ACCENT
              Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [widget.accent1, widget.accent2],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(width: 14),

              // ICÔNE (asset PNG exact) dans un fond coloré
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.iconBg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Image.asset(
                    widget.iconAsset,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // TEXTE
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: kNavy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.iconBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.tag,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: widget.accent2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // ⭐ Sous-titre limité à 2 lignes
                    Text(
                      widget.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // FLÈCHE dans un carré arrondi
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _pressed ? widget.accent1 : widget.iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: _pressed ? Colors.white : widget.accent2,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
