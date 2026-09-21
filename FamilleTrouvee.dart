// lib/FamilleTrouvee.dart - CORRIGÉ ✅
import 'package:ab_fitness_family/EditPVisiteur.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'MesDemandes.dart';

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF6046F4);
const Color pink = Color(0xFFE91E9B);
const Color grey = Color(0xFF9E9EAE);
const Color lightPurple = Color(0xFF9C27B0);
const Color darkPurple = Color(0xFF890CC2);
const Color errorRed = Color(0xFFE53935);
const Color savePurple = Color(0xFF9C27B0);

class FamilleTrouvee extends StatefulWidget {
  final Map<String, dynamic>? familleData;
  final String? messageNonTrouve;

  const FamilleTrouvee({
    super.key,
    this.familleData,
    this.messageNonTrouve,
  });

  @override
  State<FamilleTrouvee> createState() => _FamilleTrouveeState();
}

class _FamilleTrouveeState extends State<FamilleTrouvee>
    with TickerProviderStateMixin {
  int _nombreMembres = 0;
  bool _isLoadingMembres = true;

  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;

  bool get _hasFamille =>
      widget.familleData != null && widget.familleData!.isNotEmpty;

  // ═══════════════════════════════════════════════════════
  // ⭐⭐⭐ EXTRACTION CORRIGÉE ⭐⭐⭐
  // ═══════════════════════════════════════════════════════

  String get _nomChef =>
      widget.familleData?['chefNom']?.toString() ??
      widget.familleData?['fullName']?.toString() ??
      'Famille inconnue';

  // ⭐ chefId (UID du chef)
  String get _chefId =>
      widget.familleData?['chefId']?.toString() ??
      widget.familleData?['userId']?.toString() ??
      widget.familleData?['user_id']?.toString() ??
      widget.familleData?['id']?.toString() ??
      '';

  // ⭐ chefFamilyId
  String get _chefFamilyId =>
      widget.familleData?['chefFamilyId']?.toString() ??
      widget.familleData?['familyId']?.toString() ??
      widget.familleData?['family_id']?.toString() ??
      '';

  String get _familyId => _chefFamilyId;

  String get _adresse => widget.familleData?['address']?.toString() ?? '';

  String get _nomFamille {
    final parts = _nomChef.trim().split(' ');
    if (parts.length > 1) {
      return 'Famille ${parts.last}';
    }
    return 'Famille $_nomChef';
  }

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _entranceController.forward();

    // ⭐ DEBUG
    debugPrint('════════════════════════════════════════');
    debugPrint('📄 FamilleTrouvee reçue :');
    debugPrint('   familleData  = ${widget.familleData}');
    debugPrint('   chefId       = "$_chefId"');
    debugPrint('   chefNom      = "$_nomChef"');
    debugPrint('   chefFamilyId = "$_chefFamilyId"');
    debugPrint('════════════════════════════════════════');

    if (_hasFamille) {
      _chargerNombreMembres();
    } else {
      _isLoadingMembres = false;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _chargerNombreMembres() async {
    if (_familyId.isEmpty) {
      if (mounted) {
        setState(() {
          _nombreMembres = 0;
          _isLoadingMembres = false;
        });
      }
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Membres Famille')
          .where('familyId', isEqualTo: _familyId)
          .get();

      if (mounted) {
        setState(() {
          _nombreMembres = snapshot.docs.length;
          _isLoadingMembres = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Erreur membres: $e');
      if (mounted) {
        setState(() {
          _nombreMembres = 0;
          _isLoadingMembres = false;
        });
      }
    }
  }

  Widget _asset(String name,
      {double size = 24, Color? color, IconData? fallback}) {
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // ⭐ BOUTON RETOUR ÉLÉGANT (même design que EditPVisiteur)
                  _ElegantBackButton(
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _hasFamille ? 'Famille trouvée' : 'Aucun résultat',
                    style: const TextStyle(
                      color: navy,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: ScaleTransition(
                            scale: _scaleAnim,
                            child: _buildCarteFamille(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ⭐⭐⭐ BOUTON DEMANDE D'ACCÈS CORRIGÉ ⭐⭐⭐
              if (_hasFamille) ...[
                GestureDetector(
                  onTap: () {
                    // ⭐ DEBUG
                    debugPrint('════════════════════════════════════════');
                    debugPrint('🎯 ENVOI À MesDemandes :');
                    debugPrint('   chefId       = "$_chefId"');
                    debugPrint('   chefNom      = "$_nomChef"');
                    debugPrint('   chefFamilyId = "$_chefFamilyId"');
                    debugPrint('════════════════════════════════════════');

                    // ⭐ Vérification
                    if (_chefId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              '❌ Erreur : impossible d\'identifier le chef'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MesDemandes(
                          chefId: _chefId, // ⭐ OBLIGATOIRE
                          chefNom: _nomChef, // ⭐
                          chefFamilyId: _chefFamilyId, // ⭐
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: lightPurple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Demande d\'accès',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // BOUTON ANNULER
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: lightPurple),
                  ),
                  child: Center(
                    child: Text(
                      _hasFamille ? 'Annuler' : 'Nouvelle recherche',
                      style: const TextStyle(
                        color: savePurple,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

  Widget _buildCarteFamille() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              _hasFamille ? const Color(0xFFE3D8F5) : errorRed.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _hasFamille
                ? Colors.black.withOpacity(0.05)
                : errorRed.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _hasFamille
              ? _asset('lg', size: 90, fallback: Icons.family_restroom)
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.85, end: 1.0),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: errorRed.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: errorRed.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.search_off_rounded,
                            color: errorRed,
                            size: 48,
                          ),
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 14),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: _hasFamille
                  ? [navy, darkPurple]
                  : [errorRed, errorRed.withOpacity(0.7)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: Text(
              _hasFamille ? _nomFamille : 'Aucune famille trouvée',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _hasFamille
                  ? _asset('fm', size: 16, fallback: Icons.people_alt_outlined)
                  : const Icon(
                      Icons.error_outline_rounded,
                      color: errorRed,
                      size: 18,
                    ),
              const SizedBox(width: 6),
              if (_hasFamille) ...[
                const Text(
                  'Chef de famille: ',
                  style: TextStyle(color: grey, fontSize: 12.5),
                ),
                Flexible(
                  child: Text(
                    _nomChef,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                Flexible(
                  child: Text(
                    widget.messageNonTrouve ?? 'Aucune famille ne correspond',
                    style: const TextStyle(
                      color: errorRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _hasFamille
                  ? _asset('ader', size: 15, fallback: Icons.location_on)
                  : Icon(
                      Icons.lightbulb_outline_rounded,
                      color: errorRed.withOpacity(0.7),
                      size: 18,
                    ),
              const SizedBox(width: 6),
              Flexible(
                child: _hasFamille
                    ? Text(
                        _adresse.isNotEmpty
                            ? _adresse
                            : 'Adresse non renseignée',
                        style: TextStyle(
                          color: _adresse.isNotEmpty ? navy : grey,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontStyle: _adresse.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        textAlign: TextAlign.center,
                      )
                    : Text(
                        'Vérifiez l\'orthographe ou essayez une autre recherche',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
            ],
          ),
          if (_hasFamille) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _asset('user', size: 15, fallback: Icons.person),
                const SizedBox(width: 6),
                _isLoadingMembres
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: navy,
                        ),
                      )
                    : Text(
                        '$_nombreMembres membre${_nombreMembres > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: navy,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ],
            ),
          ],
        ],
      ),
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
