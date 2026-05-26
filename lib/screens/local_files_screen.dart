import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../core/local_media_service.dart';
import '../models/track.dart';
import '../widgets/now_playing_bar.dart';

/// Browse and play audio files from the device's local storage.
class LocalFilesScreen extends ConsumerStatefulWidget {
  const LocalFilesScreen({super.key});

  @override
  ConsumerState<LocalFilesScreen> createState() => _LocalFilesScreenState();
}

class _LocalFilesScreenState extends ConsumerState<LocalFilesScreen> {
  List<Track> _localTracks = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _scanLocalFiles();
  }

  Future<void> _scanLocalFiles() async {
    setState(() => _isScanning = true);

    final service = ref.read(localMediaServiceProvider);
    final tracks = await service.scanLocalFiles(
      includeExternal: ref.read(settingsProvider).includeExternalStorage,
    );

    if (mounted) {
      setState(() {
        _localTracks = tracks;
        _isScanning = false;
      });
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg', 'opus'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    final service = ref.read(localMediaServiceProvider);
    final newTracks = <Track>[];

    for (final file in result.files) {
      if (file.path != null) {
        final track = await service.addFile(file.path!);
        if (track != null) {
          newTracks.add(track);
        }
      }
    }

    if (mounted) {
      setState(() {
        _localTracks = service.localTracks;
      });

      if (newTracks.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${newTracks.length} file(s)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _pickFiles,
            tooltip: 'Add files',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanLocalFiles,
            tooltip: 'Rescan',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: const NowPlayingBar(),
    );
  }

  Widget _buildBody() {
    if (_isScanning) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_localTracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No local audio files found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to browse and add audio files',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.add),
              label: const Text('Browse Files'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _localTracks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '${_localTracks.length} audio file(s)',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          );
        }

        final track = _localTracks[index - 1];
        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.audiotrack, color: Colors.grey[500]),
          ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          trailing: const Icon(Icons.more_vert, size: 18),
          onTap: () {
            ref.read(playerStateProvider.notifier).playTrack(track);
          },
        );
      },
    );
  }
}
