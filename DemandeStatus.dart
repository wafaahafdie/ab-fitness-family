// lib/MesDemandes.dart
// ⭐ CORRIGÉ : bouton retour élégant
import 'package:flutter/material.dart';
import 'RechercheF.dart';

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF6046F4);
const Color pink = Color(0xFFE91E9B);
const Color grey = Color(0xFF9E9EAE);
const Color lightPurple = Color(0xFF9C27B0);
const Color darkPurple = Color(0xFF890CC2);
const Color orangeStatus = Color(0xFFF39C12);
const Color greenStatus = Color(0xFF2ECC71);
const Color redStatus = Color(0xFFE74C3C);

enum DemandeStatus { attente, accepter, refuser }

class Demande {
  final String famille;
  final DemandeStatus status;
  final String date;

  Demande({
    required this.famille,
    required this.status,
    required this.date,
  });
}

class MesDemandes extends StatelessWidget {
  const MesDemandes({super.key});

  Widget _asset(String name,
      {double size = 20, Color? color, IconData? fallback}) {
    return Image.asset(
      'assets/images/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      errorBuilder: (context, error, stackTrace) {
        return Icon(fallback ?? Icons.circle, size: size, color: color ?? navy);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Demande> demandes = [
      Demande(
        famille: 'hafdi',
        status: DemandeStatus.attente,
        date: '15/07/2026',
      ),
      Demande(
        famille: 'benali',
        status: DemandeStatus.accepter,
        date: '09/11/2025',
      ),
      Demande(
        famille: 'Masli',
        status: DemandeStatus.refuser,
        date: '15/07/2024',
      ),
      Demande(
        famille: 'benali',
        status: DemandeStatus.accepter,
        date: '02/11/2025',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // HEADER : retour + titre
              // ==================================================

              Row(
                children: [
                  // ⭐ BOUTON RETOUR ÉLÉGANT
                  _ElegantBackButton(
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Mes Demandes',
                    style: TextStyle(
                      color: navy,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ==================================================
              // LISTE DES DEMANDES
              // ==================================================

              Expanded(
                child: ListView.separated(
                  itemCount: demandes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    return _buildDemandeCard(context, demandes[index]);
                  },
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // BOUTON NOUVELLE DEMANDE
              // ==================================================

              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RechercheF(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: lightPurple,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _asset(
                        'po',
                        size: 16,
                        color: Colors.white,
                        fallback: Icons.add,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Nouvelle Demande',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  // Carte d'une demande
  Widget _buildDemandeCard(BuildContext context, Demande demande) {
    late final Color borderColor;
    late final Color statusColor;
    late final String statusIcon;
    late final IconData statusFallback;
    late final String statusLabel;

    switch (demande.status) {
      case DemandeStatus.attente:
        borderColor = orangeStatus;
        statusColor = orangeStatus;
        statusIcon = 'att';
        statusFallback = Icons.schedule;
        statusLabel = 'En attente';
        break;
      case DemandeStatus.accepter:
        borderColor = greenStatus;
        statusColor = greenStatus;
        statusIcon = 'acc';
        statusFallback = Icons.check_circle;
        statusLabel = 'accepter';
        break;
      case DemandeStatus.refuser:
        borderColor = orangeStatus;
        statusColor = redStatus;
        statusIcon = 'ref';
        statusFallback = Icons.cancel;
        statusLabel = 'Refuser';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Famille ${demande.famille}',
            style: const TextStyle(
              color: navy,
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _asset(
                statusIcon,
                size: 14,
                color: statusColor,
                fallback: statusFallback,
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                demande.date,
                style: TextStyle(
                  color: grey,
                  fontSize: 11.5,
                ),
              ),
              if (demande.status == DemandeStatus.accepter)
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Consulter Famille ${demande.famille}...',
                        ),
                        duration: const Duration(milliseconds: 800),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: lightPurple,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Consulter',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.subdirectory_arrow_right,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
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
              errorBuilder: (_, __, ___) => const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF1F2A6B),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
