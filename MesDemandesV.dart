// lib/MesDemandesScreen.dart - BOUTON DYNAMIQUE SELON EXPIRATION
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'VoirFamilleScreen.dart';

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF8E00C8);
const Color grey = Color(0xFF9E9EAE);
const Color labelGrey = Color(0xFF70708A);
const Color orange = Color(0xFFFF9800);
const Color green = Color(0xFF2FAE60);
const Color red = Color(0xFFE53E6B);
const Color greyDisabled = Color(0xFFBDBDBD);

// ============================================================
// MES DEMANDES SCREEN
// ============================================================

class MesDemandesV extends StatefulWidget {
  const MesDemandesV({super.key});

  @override
  State<MesDemandesV> createState() => _MesDemandesVState();
}

class _MesDemandesVState extends State<MesDemandesV> {
  Timer? _refreshTimer;
  final Map<String, String> _chefsNomsCache = {};

  @override
  void initState() {
    super.initState();
    // ⭐ Rafraîchir toutes les 30 secondes pour mettre à jour l'expiration
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ⭐ Format temps relatif
  String _formatRelativeTime(dynamic date) {
    if (date == null) return '';
    try {
      DateTime dt;
      if (date is Timestamp) {
        dt = date.toDate();
      } else if (date is String) {
        dt = DateTime.parse(date);
      } else {
        return '';
      }

      final diff = DateTime.now().difference(dt);

      if (diff.inSeconds < 60) {
        return 'il y a ${diff.inSeconds} sec';
      } else if (diff.inMinutes < 60) {
        return 'il y a ${diff.inMinutes} min';
      } else if (diff.inHours < 24) {
        return 'il y a ${diff.inHours} h';
      } else if (diff.inDays < 7) {
        return 'il y a ${diff.inDays} j';
      } else if (diff.inDays < 30) {
        return 'il y a ${(diff.inDays / 7).floor()} sem';
      } else if (diff.inDays < 365) {
        return 'il y a ${(diff.inDays / 30).floor()} mois';
      } else {
        final years = (diff.inDays / 365).floor();
        return 'il y a $years an${years > 1 ? 's' : ''}';
      }
    } catch (e) {
      return '';
    }
  }

  // ⭐ Format date classique
  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt =
          date is Timestamp ? date.toDate() : DateTime.parse(date.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (e) {
      return '';
    }
  }

  // ⭐ Prendre le premier mot du nom
  String _premierMot(String nom) {
    final trimmed = nom.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.first;
  }

  // ⭐⭐⭐ CALCULER SI L'ACCÈS EST EXPIRÉ ⭐⭐⭐
  bool _estExpire(
      dynamic dateReponse, dynamic dateExpiration, int dureeMinutes) {
    DateTime? expiration;

    // 1️⃣ Si dateExpiration existe → l'utiliser
    if (dateExpiration is Timestamp) {
      expiration = dateExpiration.toDate();
    }
    // 2️⃣ Sinon calculer depuis dateReponse + durée
    else if (dateReponse is Timestamp) {
      expiration = dateReponse
          .toDate()
          .add(Duration(minutes: dureeMinutes > 0 ? dureeMinutes : 15));
    }

    if (expiration == null) return false;

    return DateTime.now().isAfter(expiration);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                // ⭐ BOUTON RETOUR ÉLÉGANT (même design que EditPVisiteur)
                _ElegantBackButton(
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Mes Demandes',
                  style: TextStyle(
                    color: navy,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: uid == null
            ? const Center(child: Text('Non connecté'))
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('DemandesAcces')
                    .where('visiteurId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: purple),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return _buildEmpty();
                  }

                  final list = docs.toList()
                    ..sort((a, b) {
                      final da = (a.data() as Map)['dateDemande'];
                      final db = (b.data() as Map)['dateDemande'];
                      if (da is Timestamp && db is Timestamp) {
                        return db.compareTo(da);
                      }
                      return 0;
                    });

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final data = list[i].data() as Map<String, dynamic>;
                      final id = list[i].id;
                      final chefId = data['chefId']?.toString() ?? '';

                      // ⭐ Calculer expiration
                      final duree =
                          (data['dureeAccesMinutes'] as num?)?.toInt() ?? 15;
                      final estExpire = _estExpire(
                        data['dateReponse'],
                        data['dateExpiration'],
                        duree,
                      );

                      return FutureBuilder<String>(
                        future: _chargerNomChef(chefId),
                        builder: (context, chefSnap) {
                          final nomComplet = chefSnap.data ??
                              data['chefNom']?.toString() ??
                              '';

                          final premierMot = _premierMot(nomComplet);

                          final famille = premierMot.isEmpty
                              ? 'Famille'
                              : 'Famille $premierMot';

                          return _DemandeCard(
                            demandeId: id,
                            famille: famille,
                            dateDemande: _formatDate(data['dateDemande']),
                            dateReponse: _formatRelativeTime(
                              data['dateReponse'] ?? data['dateDemande'],
                            ),
                            statut: (data['statut'] ?? 'en_attente').toString(),
                            estExpire: estExpire, // ⭐
                          );
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Future<String> _chargerNomChef(String chefId) async {
    if (chefId.isEmpty) return '';

    if (_chefsNomsCache.containsKey(chefId)) {
      return _chefsNomsCache[chefId]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Chef de Famille')
          .doc(chefId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final nom = data['fullName']?.toString().trim() ??
            data['full_name']?.toString().trim() ??
            data['name']?.toString().trim() ??
            data['nom']?.toString().trim() ??
            '';

        if (nom.isNotEmpty) {
          _chefsNomsCache[chefId] = nom;
          return nom;
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur chef: $e');
    }

    _chefsNomsCache[chefId] = '';
    return '';
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: purple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_outlined, color: purple, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune demande',
            style: TextStyle(
              color: navy,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vos demandes s\'afficheront ici',
            style: TextStyle(color: grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static Widget _asset(
    String name, {
    double size = 16,
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
        return Icon(fallback ?? Icons.circle, size: size, color: color ?? navy);
      },
    );
  }
}

// ============================================================
// ⭐ BOUTON RETOUR ÉLÉGANT (même design que EditPVisiteur)
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
                color: navy,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// WIDGET : CARTE DEMANDE
// ============================================================

class _DemandeCard extends StatelessWidget {
  final String demandeId;
  final String famille;
  final String dateDemande;
  final String dateReponse;
  final String statut;
  final bool estExpire; // ⭐ NOUVEAU

  const _DemandeCard({
    required this.demandeId,
    required this.famille,
    required this.dateDemande,
    required this.dateReponse,
    required this.statut,
    this.estExpire = false,
  });

  bool get _isAcceptee => statut == 'acceptee';
  bool get _isRefusee => statut == 'refusee';
  bool get _isEnAttente => !_isAcceptee && !_isRefusee;
  bool get _peutVoir => _isAcceptee && !estExpire; // ⭐

  Color get _couleur {
    if (_isAcceptee) {
      return estExpire ? greyDisabled : green;
    }
    if (_isRefusee) return red;
    return orange;
  }

  String get _texte {
    if (_isAcceptee) {
      return estExpire ? 'Expirée' : 'Acceptée';
    }
    if (_isRefusee) return 'Refusée';
    return 'En attente';
  }

  IconData get _icon {
    if (_isAcceptee) {
      return estExpire ? Icons.lock_clock : Icons.check_circle;
    }
    if (_isRefusee) return Icons.cancel;
    return Icons.hourglass_top_rounded;
  }

  void _ouvrirAvecAnimation(BuildContext context) {
    // ⭐ Bloquer si expiré
    if (estExpire) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⏰ Cet accès a expiré. Envoyez une nouvelle demande au chef de famille.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            VoirFamilleScreen(demandeId: demandeId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          );

          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeIn),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(scale: scaleAnimation, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        // ⭐ Fond gris très clair si expiré
        color: estExpire ? const Color(0xFFF8F8FA) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _couleur.withOpacity(0.6),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  famille,
                  style: TextStyle(
                    color: estExpire ? grey : navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(_icon, size: 14, color: _couleur),
                    const SizedBox(width: 5),
                    Text(
                      _texte,
                      style: TextStyle(
                        color: _couleur,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!_isEnAttente) ...[
                      const SizedBox(width: 6),
                      Text(
                        '• $dateReponse',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 11,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isEnAttente
                          ? 'Demandé le : $dateDemande'
                          : 'Répondu le : $dateDemande',
                      style: TextStyle(
                        color: estExpire ? grey.withOpacity(0.7) : grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isAcceptee)
            // ⭐⭐ BOUTON "VOIR" DYNAMIQUE ⭐⭐
            _BoutonVoir(
              estExpire: estExpire,
              onTap: _peutVoir ? () => _ouvrirAvecAnimation(context) : null,
            ),
        ],
      ),
    );
  }
}

// ============================================================
// ⭐ BOUTON "VOIR" AVEC ANIMATION ⭐
// ============================================================

class _BoutonVoir extends StatefulWidget {
  final bool estExpire;
  final VoidCallback? onTap;

  const _BoutonVoir({required this.estExpire, this.onTap});

  @override
  State<_BoutonVoir> createState() => _BoutonVoirState();
}

class _BoutonVoirState extends State<_BoutonVoir>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ⭐ Démarrer la pulsation si le bouton est actif
    if (!widget.estExpire) {
      _demarrerPulse();
    }
  }

  @override
  void didUpdateWidget(covariant _BoutonVoir oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ⭐ Nouvelle autorisation → pulsation
    if (oldWidget.estExpire == true && widget.estExpire == false) {
      _demarrerPulse();
    }
    // ⭐ Expiré → arrêter pulsation
    else if (widget.estExpire == true) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _demarrerPulse() {
    // ⭐ Pulse 3 fois puis s'arrête
    _pulseController.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 3600), () {
      if (mounted) {
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool actif = !widget.estExpire;

    // ⭐ Couleur selon état
    final Color bgColor = actif ? purple : greyDisabled;
    final Color textColor = actif ? Colors.white : Colors.white;

    // ⭐ Bouton statique
    Widget bouton = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: actif
            ? [
                BoxShadow(
                  color: purple.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            actif ? 'Voir' : 'Expiré',
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          Image.asset(
            actif ? 'assets/images/voir.png' : 'assets/images/lock.png',
            width: 13,
            height: 13,
            color: Colors.white,
            errorBuilder: (_, __, ___) => Icon(
              actif ? Icons.arrow_forward_rounded : Icons.lock_outline,
              color: Colors.white,
              size: 13,
            ),
          ),
        ],
      ),
    );

    // ⭐ Envelopper avec animation si actif
    if (actif) {
      return GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: bouton,
        ),
      );
    }

    // ⭐ Bouton gris non cliquable
    return GestureDetector(
      onTap: null,
      child: bouton,
    );
  }
}
