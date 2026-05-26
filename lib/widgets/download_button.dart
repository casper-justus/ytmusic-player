import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/download_service.dart';
import '../models/track.dart';

/// A download button for a track that shows download/delete state
/// with progress feedback.
///
/// States:
/// - Not downloaded: shows download icon
/// - Downloading: shows circular progress
/// - Downloaded: shows check icon, can tap to delete
class DownloadButton extends ConsumerStatefulWidget {
  final Track track;
  final double iconSize;

  const DownloadButton({
    super.key,
    required this.track,
    this.iconSize = 24,
  });

  @override
  ConsumerState<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends ConsumerState<DownloadButton> {
  bool _isDownloading = false;
  double _progress = 0.0;

  Future<void> _handleDownload() async {
    final service = ref.read(downloadServiceProvider);

    if (service.isDownloaded(widget.track)) {
      // Already downloaded — offer to delete
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Download'),
          content: Text('Remove "${widget.track.title}" from offline storage?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await service.deleteDownload(widget.track);
        if (mounted) setState(() {});
      }
      return;
    }

    // Start download
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
    });

    try {
      await for (final progress in service.downloadTrack(widget.track)) {
        if (mounted) {
          setState(() => _progress = progress);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(downloadServiceProvider);
    final isDownloaded = service.isDownloaded(widget.track);

    if (_isDownloading) {
      return SizedBox(
        width: widget.iconSize,
        height: widget.iconSize,
        child: CircularProgressIndicator(
          value: _progress > 0 ? _progress : null,
          strokeWidth: 2,
        ),
      );
    }

    return IconButton(
      icon: Icon(
        isDownloaded ? Icons.check_circle : Icons.download_outlined,
        size: widget.iconSize,
        color: isDownloaded ? Colors.green : null,
      ),
      onPressed: _handleDownload,
      tooltip: isDownloaded ? 'Downloaded (tap to delete)' : 'Download',
    );
  }
}
