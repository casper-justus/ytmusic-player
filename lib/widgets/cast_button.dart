import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import '../core/cast_service.dart';

/// A floating Cast button that opens a device picker when tapped.
///
/// Shows an active indicator when connected to a Cast device.
/// Place this in the app bar or player screen.
class CastButton extends ConsumerWidget {
  final double iconSize;
  final Color? activeColor;

  const CastButton({
    super.key,
    this.iconSize = 24,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castService = ref.watch(castServiceProvider);
    final isConnected = castService.connected;
    final deviceName = castService.deviceName;

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            Icons.cast,
            size: iconSize,
            color: isConnected
                ? (activeColor ?? Theme.of(context).colorScheme.primary)
                : null,
          ),
          onPressed: () => _showCastDialog(context, ref, castService),
          tooltip: isConnected ? 'Connected to $deviceName' : 'Cast',
        ),
        if (isConnected)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showCastDialog(BuildContext context, WidgetRef ref, CastService service) {
    if (service.connected) {
      // Show connected state with disconnect option
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.cast, color: Colors.green),
                title: Text('Connected to ${service.deviceName ?? "Cast Device"}'),
                subtitle: const Text('Tap to disconnect'),
                onTap: () {
                  service.disconnect();
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.volume_up),
                title: const Text('Volume'),
                subtitle: Slider(
                  value: service.volume,
                  onChanged: (v) => service.setVolume(v),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Show available devices
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Cast to',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              FutureBuilder<List<GoogleCastDevice>>(
                future: service.getAvailableDevices(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    );
                  }

                  final devices = snapshot.data ?? [];

                  if (devices.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.cast_connected, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No devices found',
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Make sure your device is on the same Wi-Fi network',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: devices.map((device) {
                      return ListTile(
                        leading: const Icon(Icons.tv),
                        title: Text(device.friendlyName),
                        subtitle: device.modelName != null ? Text(device.modelName!) : null,
                        onTap: () async {
                          await service.connectToDevice(device);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }
  }
}
