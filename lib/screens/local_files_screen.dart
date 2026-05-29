import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/player_provider.dart';
import '../core/local_media_service.dart';
import '../widgets/now_playing_bar.dart';

class LocalFilesScreen extends ConsumerStatefulWidget {
  const LocalFilesScreen({super.key});

  @override
  ConsumerState<LocalFilesScreen> createState() => _LocalFilesScreenState();
}

class _LocalFilesScreenState extends ConsumerState<LocalFilesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoScan());
  }

  Future<void> _autoScan() async {
    final service = ref.read(localMediaServiceProvider);
    if (service.scanned && service.localTracks.isNotEmpty) return;

    final audioGranted = await Permission.audio.isGranted;
    final storageGranted = await Permission.storage.isGranted;

    if (!audioGranted && !storageGranted) {
      await Permission.audio.request();
    }

    await service.scanLocalFiles(includeExternal: true);
    if (mounted) setState(() {});
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg', 'opus', 'wma', 'webm'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final service = ref.read(localMediaServiceProvider);
    var count = 0;
    for (final file in result.files) {
      if (file.path != null) {
        final track = await service.addFile(file.path!);
        if (track != null) count++;
      }
    }
    if (mounted) {
      setState(() {});
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $count file(s)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(localMediaServiceProvider);
    final tracks = service.localTracks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _autoScan,
            tooltip: 'Rescan',
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickFiles,
            tooltip: 'Pick files',
          ),
        ],
      ),
      body: tracks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_music_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No local audio files found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Files are scanned automatically on supported devices.\nYou can also pick files manually.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.add),
                    label: const Text('Browse Files'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
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
                  title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  trailing: const Icon(Icons.more_vert, size: 18),
                  onTap: () => ref.read(playerStateProvider.notifier).playTrack(track),
                );
              },
            ),
      bottomNavigationBar: const NowPlayingBar(),
    );
  }
}
