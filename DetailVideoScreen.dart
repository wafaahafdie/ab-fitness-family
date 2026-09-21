// lib/DetailVideoScreen.dart
// ⭐ CORRIGÉ : bouton retour élégant (blanc) + bouton retour sombre pour le lecteur
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

// ============================================================
// COULEURS
// ============================================================

const Color navy = Color(0xFF1F2A6B);
const Color purple = Color(0xFF6046F4);
const Color grey = Color(0xFF9E9EAE);

// ============================================================
// DETAIL VIDEO SCREEN
// ============================================================

class DetailVideoScreen extends StatefulWidget {
  final String title;
  final String count;
  final String? memberId;

  const DetailVideoScreen({
    super.key,
    required this.title,
    required this.count,
    this.memberId,
  });

  @override
  State<DetailVideoScreen> createState() => _DetailVideoScreenState();
}

class _DetailVideoScreenState extends State<DetailVideoScreen> {
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('video')
          .where('category', isEqualTo: widget.title);

      if (widget.memberId != null && widget.memberId!.isNotEmpty) {
        query = query.where('memberId', isEqualTo: widget.memberId);
      }

      final snapshot = await query.get();

      if (!mounted) return;
      setState(() {
        _videos = snapshot.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement vidéos: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFD),
      // ⭐ APPBAR avec bouton retour élégant
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: const BoxDecoration(color: Colors.white),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                _ElegantBackButton(
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.count,
                        style: const TextStyle(
                          color: grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: purple))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 50, color: Colors.redAccent),
                      const SizedBox(height: 10),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: grey, fontSize: 12)),
                    ],
                  ),
                )
              : _videos.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library_outlined,
                              size: 60, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Aucune vidéo',
                              style: TextStyle(color: grey, fontSize: 14)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(14),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _videos.length,
                      itemBuilder: (_, i) => _videoTile(_videos[i]),
                    ),
    );
  }

  Widget _videoTile(Map<String, dynamic> video) {
    return GestureDetector(
      onTap: () {
        final url = video['downloadUrl'] ?? '';
        if (url.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
              url: url,
              title: video['name'] ?? 'Vidéo',
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: video['thumbnailUrl'] != null &&
                          (video['thumbnailUrl'] as String).isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: video['thumbnailUrl'],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: Colors.black87),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.black87,
                            child: const Center(
                              child: Icon(Icons.videocam,
                                  color: Colors.white, size: 40),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.black87,
                          child: const Center(
                            child: Icon(Icons.videocam,
                                color: Colors.white, size: 40),
                          ),
                        ),
                ),
                const Center(
                  child: Icon(Icons.play_circle_fill,
                      color: Colors.white, size: 45),
                ),
                if (video['duration'] != null)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(video['duration']),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            video['name'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: navy,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(dynamic duration) {
    int? secs;
    if (duration is int) secs = duration;
    if (duration is String) secs = int.tryParse(duration);
    if (secs == null) return '';
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ============================================================
// ⭐ BOUTON RETOUR ÉLÉGANT (design RoleSelectionScreen - fond blanc)
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

// ============================================================
// ⭐ BOUTON RETOUR SOMBRE (pour lecteur vidéo plein écran)
// ============================================================

class _DarkElegantBackButton extends StatefulWidget {
  final VoidCallback onTap;

  const _DarkElegantBackButton({required this.onTap});

  @override
  State<_DarkElegantBackButton> createState() => _DarkElegantBackButtonState();
}

class _DarkElegantBackButtonState extends State<_DarkElegantBackButton> {
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
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LECTEUR VIDÉO PLEIN ÉCRAN
// ============================================================

class VideoPlayerScreen extends StatefulWidget {
  final String url;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      }).catchError((e) {
        debugPrint('❌ Erreur init vidéo: $e');
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // ⭐ APPBAR avec bouton retour élégant sombre
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: const BoxDecoration(color: Colors.black),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                _DarkElegantBackButton(
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      floatingActionButton: _controller.value.isInitialized
          ? FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
              ),
            )
          : null,
    );
  }
}
