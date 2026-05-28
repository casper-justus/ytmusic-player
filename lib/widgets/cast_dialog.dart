import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/cast_service.dart';

/// A dialog that shows available Chromecast devices and connection state.
///
/// Call via `showCastDialog(context)`.
Future<void> showCastDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (ctx) => const _CastDialog(),
  );
}

class _CastDialog extends ConsumerStatefulWidget {
  const _CastDialog();

  @override
  ConsumerState<_CastDialog> createState() => _CastDialogState();
}

class _CastDialogState extends ConsumerState<_CastDialog> {
  @override
  void initState() {
    super.initState();
    // Start discovery when dialog opens
    Future.microtask(() {
      ref.read(castServiceProvider).startDiscovery();
    });
  }

  @override
  void dispose() {
    // Stop discovery when dialog closes (saves battery)
    ref.read(castServiceProvider).stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final castService = ref.watch(castServiceProvider);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            castService.connected ? Icons.cast_connected : Icons.cast,
            color: castService.connected ? Colors.blue : null,
          ),
          const SizedBox(width: 12),
          Text(castService.connected ? 'Connected' : 'Cast to'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connected device info
            if (castService.connected) ...[
              ListTile(
                leading: const Icon(Icons.cast_connected, color: Colors.blue),
                title: Text(castService.deviceName ?? 'Unknown device'),
                subtitle: const Text('Connected'),
                trailing: TextButton(
                  onPressed: () async {
                    await castService.disconnect();
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Disconnect'),
                ),
              ),
              const Divider(),
            ],

            // Available devices
            if (!castService.connected) ...[
              Text(
                'Available devices',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 8),
              ...castService.devices.map((device) {
                return ListTile(
                  leading: const Icon(Icons.cast),
                  title: Text(device.friendlyName),
                  subtitle: device.modelName != null
                      ? Text(device.modelName!, style: TextStyle(fontSize: 12, color: Colors.grey[500]))
                      : null,
                  onTap: () async {
                    final success = await castService.connectToDevice(device);
                    if (mounted) {
                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Connected to ${device.friendlyName}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to connect')),
                        );
                      }
                    }
                  },
                );
              }),
              if (castService.devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.cast, size: 48, color: Colors.grey[500]),
                        const SizedBox(height: 12),
                        Text(
                          'No Cast devices found',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Make sure your device is on the same Wi-Fi network',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
