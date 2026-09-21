// lib/RechercheF.dart - CORRIGÉ ✅
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'FamilleTrouvee.dart';

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF6046F4);
const Color pink = Color(0xFFE91E9B);
const Color grey = Color(0xFF9E9EAE);
const Color lightPurple = Color(0xFF9C27B0);
const Color lavenderBg = Color(0xFFE9E7F7);
const Color darkPurple = Color(0xFF890CC2);

class RechercheF extends StatefulWidget {
  const RechercheF({super.key});

  @override
  State<RechercheF> createState() => _RechercheFState();
}

class _RechercheFState extends State<RechercheF> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isPhoneTab = true;
  bool _isSearching = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
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

  // ═══════════════════════════════════════════════════════
  // ⭐ RECHERCHE
  // ═══════════════════════════════════════════════════════

  Future<void> _rechercher() async {
    final query = _isPhoneTab
        ? _phoneController.text.trim()
        : _nameController.text.trim();

    if (query.isEmpty) {
      _showSnack('Veuillez entrer une recherche.', isError: true);
      return;
    }

    setState(() => _isSearching = true);

    try {
      debugPrint('════════════════════════════════════════');
      debugPrint(
          '🔍 Recherche: "$query" (${_isPhoneTab ? "téléphone" : "nom"})');
      debugPrint('════════════════════════════════════════');

      final user = FirebaseAuth.instance.currentUser;
      debugPrint('👤 Utilisateur: ${user?.uid ?? "AUCUN"}');

      List<Map<String, dynamic>> resultats = [];

      QuerySnapshot allChefsSnapshot;
      try {
        allChefsSnapshot = await FirebaseFirestore.instance
            .collection('Chef de Famille')
            .get()
            .timeout(const Duration(seconds: 10));
      } on FirebaseException catch (e) {
        debugPrint('❌ FirebaseException: ${e.code} - ${e.message}');
        throw Exception('Erreur Firestore: ${e.message}');
      } catch (e) {
        debugPrint('❌ Erreur: $e');
        throw Exception('Impossible de charger les familles: $e');
      }

      debugPrint('📊 ${allChefsSnapshot.docs.length} chefs trouvés');

      if (allChefsSnapshot.docs.isEmpty) {
        if (mounted) setState(() => _isSearching = false);
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FamilleTrouvee(
              familleData: null,
              messageNonTrouve: _isPhoneTab
                  ? 'Aucune famille trouvée avec ce numéro de téléphone'
                  : 'Aucune famille trouvée avec ce nom de famille',
            ),
          ),
        );
        return;
      }

      final queryLower = query.toLowerCase();
      final cleanedQuery = query.replaceAll(' ', '').replaceAll('+', '');

      for (var doc in allChefsSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;

          final String chefId = data['userId']?.toString() ??
              data['user_id']?.toString() ??
              doc.id;

          final String chefNom = data['fullName']?.toString() ??
              data['full_name']?.toString() ??
              'Chef de famille';

          final String chefFamilyId = data['familyId']?.toString() ??
              data['family_id']?.toString() ??
              '';

          if (_isPhoneTab) {
            final phone = (data['phone'] ?? '').toString();
            final phoneClean = phone.replaceAll(' ', '').replaceAll('+', '');

            if (phoneClean == cleanedQuery ||
                phoneClean.contains(cleanedQuery) ||
                phone.contains(query)) {
              resultats.add({
                'id': doc.id,
                'chefId': chefId,
                'userId': chefId,
                'chefNom': chefNom,
                'fullName': chefNom,
                'chefFamilyId': chefFamilyId,
                'familyId': chefFamilyId,
                ...data,
              });
              debugPrint('✅ Match téléphone: $phone');
            }
          } else {
            final fullName = (data['fullName'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final address = (data['address'] ?? '').toString().toLowerCase();

            if (fullName.contains(queryLower) ||
                email.contains(queryLower) ||
                address.contains(queryLower)) {
              resultats.add({
                'id': doc.id,
                'chefId': chefId,
                'userId': chefId,
                'chefNom': chefNom,
                'fullName': chefNom,
                'chefFamilyId': chefFamilyId,
                'familyId': chefFamilyId,
                ...data,
              });
              debugPrint('✅ Match nom: $fullName');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur doc: $e');
        }
      }

      debugPrint('📊 ${resultats.length} résultat(s)');

      if (mounted) setState(() => _isSearching = false);
      if (!mounted) return;

      if (resultats.isEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FamilleTrouvee(
              familleData: null,
              messageNonTrouve: _isPhoneTab
                  ? 'Aucune famille trouvée avec ce numéro de téléphone'
                  : 'Aucune famille trouvée avec ce nom de famille',
            ),
          ),
        );
      } else if (resultats.length == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FamilleTrouvee(
              familleData: resultats.first,
            ),
          ),
        );
      } else {
        _showResultatsDialog(resultats);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERREUR: $e');
      debugPrint('StackTrace: $stackTrace');

      if (mounted) {
        setState(() => _isSearching = false);
        _showSnack('Erreur: $e', isError: true);
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // DIALOG RÉSULTATS MULTIPLES
  // ═══════════════════════════════════════════════════════

  void _showResultatsDialog(List<Map<String, dynamic>> resultats) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3E3EA),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Text(
                  '${resultats.length} famille(s) trouvée(s)',
                  style: const TextStyle(
                    color: navy,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: resultats.length,
                    itemBuilder: (ctx2, index) {
                      final f = resultats[index];
                      final nom = f['chefNom'] ?? f['fullName'] ?? 'Famille';
                      final phone = f['phone'] ?? '';
                      final address = f['address'] ?? '';

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FamilleTrouvee(
                                familleData: f,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F1FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: navy,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.family_restroom,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nom,
                                      style: const TextStyle(
                                        color: navy,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (phone.isNotEmpty)
                                      Text(
                                        phone,
                                        style: const TextStyle(
                                          color: grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    if (address.isNotEmpty)
                                      Text(
                                        address,
                                        style: const TextStyle(
                                          color: grey,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: grey, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SNACKBAR
  // ═══════════════════════════════════════════════════════

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

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
              // HEADER
              // ⭐ BOUTON RETOUR ÉLÉGANT (même design que EditPVisiteur)
              _ElegantBackButton(
                onTap: () => Navigator.maybePop(context),
              ),

              const SizedBox(height: 14),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/aa.png',
                              width: 64,
                              height: 64,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 64,
                                  height: 64,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.diversity_3,
                                    color: purple,
                                    size: 40,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Recherche une famille',
                              style: TextStyle(
                                color: navy,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Trouvez une famille et envoyez une demande d\'accès.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildTabButton(
                                icon: 'tlb',
                                fallback: Icons.phone,
                                title: 'Numéro de téléphone',
                                subtitle: 'Recherche par num',
                                isActive: _isPhoneTab,
                                onTap: () => setState(() => _isPhoneTab = true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTabButton(
                                icon: 'fb',
                                fallback: Icons.home_outlined,
                                title: 'Nom de famille',
                                subtitle: 'Recherche par nom',
                                isActive: !_isPhoneTab,
                                onTap: () =>
                                    setState(() => _isPhoneTab = false),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ═══════════════════════════════════════════════
                      // ⭐ ONGLET TÉLÉPHONE → CHIFFRES UNIQUEMENT
                      // ═══════════════════════════════════════════════
                      if (_isPhoneTab) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0EFF5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 14),
                              _asset('alg', size: 24, fallback: Icons.flag),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  // ⭐ CHIFFRES + + ET ESPACES UNIQUEMENT
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9+\s]')),
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: '0550 16 77 03',
                                    hintStyle: TextStyle(
                                      color: Color.fromARGB(255, 138, 139, 142),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 14,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: navy,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoBox(
                          'Entrez le numéro de téléphone du chef de famille. '
                          'Si ce numéro est associé à une famille, vous pourrez '
                          'lui envoyer une demande d\'accès.',
                        ),
                      ]

                      // ═══════════════════════════════════════════════
                      // ⭐ ONGLET NOM → LETTRES UNIQUEMENT
                      // ═══════════════════════════════════════════════
                      else ...[
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0EFF5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              _asset('rec',
                                  size: 20,
                                  color: grey,
                                  fallback: Icons.search),
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  keyboardType: TextInputType.name,
                                  // ⭐ LETTRES + ESPACES + TIRETS + APOSTROPHES UNIQUEMENT
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r"[a-zA-ZÀ-ÿ\s'\-]"),
                                    ),
                                  ],
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Recherche par Nom de famille......',
                                    hintStyle: TextStyle(
                                      color: Color(0xFFB0B0C0),
                                      fontSize: 13,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: navy,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoBox(
                          'Entrez le nom de famille (lettres uniquement). '
                          'Si une famille correspond à ce nom, vous pourrez '
                          'lui envoyer une demande d\'accès.',
                        ),
                      ],
                      const SizedBox(height: 24),
                      Center(
                        child: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: purple,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Recherche en cours...',
                                      style: TextStyle(
                                        color: grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _buildSearchButton(onTap: _rechercher),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String icon,
    required IconData fallback,
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [navy, darkPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? Colors.transparent : const Color(0xFFE8E5F5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _asset(
              icon,
              size: 24,
              color: isActive ? Colors.white : purple,
              fallback: fallback,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isActive ? Colors.white : navy,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isActive ? Colors.white.withOpacity(0.85) : purple,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lavenderBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: navy,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: _asset(
                'qste',
                size: 14,
                color: Colors.white,
                fallback: Icons.question_mark,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: navy,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [navy, darkPurple, pink],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Recherche',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
