import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pichat/core/theme/app_colors.dart';

/// Result returned by [showShareLocationSheet] when the user confirms.
class ShareLocationResult {
  final double latitude;
  final double longitude;
  final String? name;
  final String? address;
  const ShareLocationResult({
    required this.latitude,
    required this.longitude,
    this.name,
    this.address,
  });
}

/// WhatsApp-style "share current location" sheet. Asks for the GPS
/// permission, fetches the current fix, then shows a small confirmation
/// card with the coordinates and a single "Send your current location"
/// button. Returns `null` if dismissed.
Future<ShareLocationResult?> showShareLocationSheet(BuildContext context) {
  return showModalBottomSheet<ShareLocationResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ShareLocationSheet(),
  );
}

class _ShareLocationSheet extends StatefulWidget {
  const _ShareLocationSheet();

  @override
  State<_ShareLocationSheet> createState() => _ShareLocationSheetState();
}

class _ShareLocationSheetState extends State<_ShareLocationSheet> {
  Position? _position;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _loading = false;
          _error = 'Location services are disabled. Please enable GPS.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _loading = false;
          _error = 'Location permission denied.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = pos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not get location: $e';
        _loading = false;
      });
    }
  }

  void _send() {
    final p = _position;
    if (p == null) return;
    Navigator.of(context).pop(
      ShareLocationResult(latitude: p.latitude, longitude: p.longitude),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: PiColors.of(context).surfaceRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: PiColors.of(context).divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Color(0xFF34A853)),
                const SizedBox(width: 8),
                Text(
                  'Share location',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Geolocator.openLocationSettings(),
                          icon: const Icon(Icons.settings),
                          label: const Text('Open settings'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _fetch,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8F4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF34A853)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.my_location,
                            color: Color(0xFF34A853), size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your current location',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_position!.latitude.toStringAsFixed(5)}, '
                                '${_position!.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF34A853),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                    label: const Text('Send your current location'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
