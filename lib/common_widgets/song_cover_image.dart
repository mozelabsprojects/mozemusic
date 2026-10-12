import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/song.dart';

/// A robust, adaptive song cover image widget that guarantees a working cover.
/// Cascades:
/// 1. Primary URL (auto-converts i.ytimg.com to img.youtube.com & maxres to hqdefault)
/// 2. YouTube img.youtube.com hqdefault.jpg
/// 3. YouTube img.youtube.com mqdefault.jpg
/// 4. YouTube i.ytimg.com hqdefault.jpg
/// 5. YouTube img.youtube.com default.jpg
/// 6. Dark glass gradient tile with music note
class SongCoverImage extends StatefulWidget {
  final String? imageUrl;
  final String? videoId;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const SongCoverImage({
    super.key,
    this.imageUrl,
    this.videoId,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  factory SongCoverImage.fromSong({
    Key? key,
    required Song song,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    BoxFit fit = BoxFit.cover,
  }) {
    return SongCoverImage(
      key: key,
      imageUrl: song.thumbnailUrl,
      videoId: song.videoId,
      width: width,
      height: height,
      borderRadius: borderRadius,
      fit: fit,
    );
  }

  @override
  State<SongCoverImage> createState() => _SongCoverImageState();
}

class _SongCoverImageState extends State<SongCoverImage> {
  int _attemptIndex = 0;
  late List<String> _candidateUrls;

  @override
  void initState() {
    super.initState();
    _candidateUrls = _buildCandidates();
  }

  @override
  void didUpdateWidget(SongCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl || oldWidget.videoId != widget.videoId) {
      _attemptIndex = 0;
      _candidateUrls = _buildCandidates();
    }
  }

  List<String> _buildCandidates() {
    final list = <String>[];

    // Extract videoId if possible
    String? vid = widget.videoId;
    if ((vid == null || vid.isEmpty) && widget.imageUrl != null) {
      final match = RegExp(r'vi/([^/?#]+)').firstMatch(widget.imageUrl!);
      if (match != null) {
        vid = match.group(1);
      }
    }

    // 1. Primary URL sanitized
    if (widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty) {
      var primary = widget.imageUrl!.trim();
      if (primary.contains('i.ytimg.com')) {
        primary = primary.replaceAll('i.ytimg.com', 'img.youtube.com');
      }
      if (primary.contains('maxresdefault.jpg') && vid != null && vid.isNotEmpty) {
        primary = 'https://img.youtube.com/vi/$vid/hqdefault.jpg';
      }
      list.add(primary);
    }

    if (vid != null && vid.isNotEmpty) {
      final hqYoutube = 'https://img.youtube.com/vi/$vid/hqdefault.jpg';
      final mqYoutube = 'https://img.youtube.com/vi/$vid/mqdefault.jpg';
      final hqYtimg = 'https://i.ytimg.com/vi/$vid/hqdefault.jpg';
      final defYoutube = 'https://img.youtube.com/vi/$vid/default.jpg';

      if (!list.contains(hqYoutube)) list.add(hqYoutube);
      if (!list.contains(mqYoutube)) list.add(mqYoutube);
      if (!list.contains(hqYtimg)) list.add(hqYtimg);
      if (!list.contains(defYoutube)) list.add(defYoutube);
    }

    return list;
  }

  void _onImageError() {
    if (_attemptIndex + 1 < _candidateUrls.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _attemptIndex++;
          });
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _attemptIndex != _candidateUrls.length) {
          setState(() {
            _attemptIndex = _candidateUrls.length; // points to fallback tile
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = widget.borderRadius ?? BorderRadius.circular(8);

    Widget placeholder() => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: effectiveBorderRadius,
          ),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.redAccent),
            ),
          ),
        );

    Widget fallbackTile() => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: effectiveBorderRadius,
            gradient: const LinearGradient(
              colors: [Color(0xFF2A2A2A), Color(0xFF141414)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.music_note_rounded,
              color: Colors.white38,
              size: (widget.width != null && widget.height != null && !widget.width!.isInfinite && !widget.height!.isInfinite)
                  ? (widget.width! * 0.4).clamp(16.0, 48.0)
                  : 24,
            ),
          ),
        );

    if (_candidateUrls.isEmpty || _attemptIndex >= _candidateUrls.length) {
      return fallbackTile();
    }

    final currentUrl = _candidateUrls[_attemptIndex];

    return ClipRRect(
      borderRadius: effectiveBorderRadius,
      child: Image.network(
        currentUrl,
        key: ValueKey(currentUrl),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: (widget.width != null && !widget.width!.isInfinite) ? (widget.width! * 2).toInt() : 400,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder();
        },
        errorBuilder: (context, error, stackTrace) {
          _onImageError();
          return placeholder();
        },
      ),
    );
  }
}
