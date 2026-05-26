import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// A widget that builds a gradient background from colors extracted
/// from an album art image URL.
///
/// Used in the player screen and any view that benefits from
/// album-art-aware dynamic theming.
class AlbumArtBackground extends StatefulWidget {
  final String? imageUrl;
  final Widget child;
  final double blurAmount;

  const AlbumArtBackground({
    super.key,
    this.imageUrl,
    required this.child,
    this.blurAmount = 30.0,
  });

  @override
  State<AlbumArtBackground> createState() => _AlbumArtBackgroundState();
}

class _AlbumArtBackgroundState extends State<AlbumArtBackground> {
  Color _dominantColor = Colors.black;
  Color _vibrantColor = Colors.blueGrey;
  bool _colorsExtracted = false;

  @override
  void initState() {
    super.initState();
    _extractColors();
  }

  @override
  void didUpdateWidget(covariant AlbumArtBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _colorsExtracted = false;
      _extractColors();
    }
  }

  Future<void> _extractColors() async {
    if (widget.imageUrl == null || _colorsExtracted) return;

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(widget.imageUrl!),
        maximumColorCount: 16,
      );

      if (mounted) {
        setState(() {
          _dominantColor = palette.dominantColor?.color ?? Colors.black;
          _vibrantColor = palette.vibrantColor?.color ?? Colors.blueGrey;
          _colorsExtracted = true;
        });
      }
    } catch (e) {
      // Use defaults on error
      if (mounted) {
        setState(() => _colorsExtracted = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _vibrantColor.withValues(alpha: 0.3),
            _dominantColor,
            _dominantColor,
          ],
        ),
      ),
      child: widget.child,
    );
  }
}
