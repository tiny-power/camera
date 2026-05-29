import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hand_camera/generated/l10n.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage>
    with WidgetsBindingObserver {
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _microphoneStatus = PermissionStatus.denied;
  bool _isRequestInFlight = false;

  bool _isPermissionReady(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions(navigateWhenGranted: true, requestWhenMissing: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions(navigateWhenGranted: true);
    }
  }

  Future<void> _checkPermissions({
    required bool navigateWhenGranted,
    bool requestWhenMissing = false,
  }) async {
    final camera = await Permission.camera.status;
    final microphone = await Permission.microphone.status;
    if (!mounted) return;

    setState(() {
      _cameraStatus = camera;
      _microphoneStatus = microphone;
    });

    final hasAllPermissions =
        _isPermissionReady(camera) && _isPermissionReady(microphone);

    if (navigateWhenGranted && hasAllPermissions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
      return;
    }

    if (requestWhenMissing && !hasAllPermissions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestPermissions(showSettingsDialog: false);
      });
    }
  }

  Future<void> _requestPermissions({bool showSettingsDialog = true}) async {
    if (_isRequestInFlight) return;
    _isRequestInFlight = true;

    try {
      var camera = await Permission.camera.status;
      var microphone = await Permission.microphone.status;

      if (!_isPermissionReady(camera) || !_isPermissionReady(microphone)) {
        final statuses = await [
          if (!_isPermissionReady(camera)) Permission.camera,
          if (!_isPermissionReady(microphone)) Permission.microphone,
        ].request();
        camera = statuses[Permission.camera] ?? camera;
        microphone = statuses[Permission.microphone] ?? microphone;
      }

      camera = await Permission.camera.status;
      microphone = await Permission.microphone.status;

      if (!mounted) return;
      setState(() {
        _cameraStatus = camera;
        _microphoneStatus = microphone;
      });

      if (_isPermissionReady(camera) && _isPermissionReady(microphone)) {
        context.go('/home');
        return;
      }

      if (!showSettingsDialog) return;

      final shouldOpenSettings = await _showSettingsDialog();
      if (shouldOpenSettings && mounted) {
        await openAppSettings();
        await _checkPermissions(navigateWhenGranted: true);
      }
    } finally {
      _isRequestInFlight = false;
    }
  }

  Future<bool> _showSettingsDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Permissions Required'),
              content: const Text(
                'Camera and microphone access are required for hands-free photos. You can enable them in Settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Settings'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: .only(top: 16, bottom: 16, left: 18, right: 18),
      decoration: BoxDecoration(
        borderRadius: .circular(18),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      ),
      child: Row(
        spacing: 12,
        children: [
          Icon(icon, color: colorScheme.primary, size: 28),
          Expanded(
            child: Column(
              mainAxisAlignment: .center,
              crossAxisAlignment: .start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: .w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: .w400,
                  ),
                ),
              ],
            ),
          ),
          _buildPermissionStatusIcon(isGranted),
        ],
      ),
    );
  }

  Widget _buildPermissionStatusIcon(bool isGranted) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isGranted) {
      return Icon(Icons.check_circle, color: colorScheme.primary, size: 30);
    }

    return Icon(Icons.circle_outlined, color: colorScheme.outline, size: 30);
  }

  Widget _buildContinueButton({required VoidCallback onPressed}) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 64,
      child: Material(
        color: colorScheme.primary,
        borderRadius: .circular(12),
        child: InkWell(
          borderRadius: .circular(12),
          onTap: onPressed,
          child: Center(
            child: Text(
              'Continue',
              style: TextStyle(color: colorScheme.onPrimary, fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: .symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      mainAxisSize: .min,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          alignment: .center,
                          decoration: BoxDecoration(
                            shape: .circle,
                            color: colorScheme.primary.withValues(alpha: 0.3),
                          ),
                          child: Icon(
                            Icons.photo_camera,
                            color: colorScheme.primary,
                            size: 48,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Permissions Needed',
                          textAlign: .center,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 26,
                            fontWeight: .w800,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '${S.current.app_name} needs access to your\ncamera and microphone to take hands-\nfree photos.',
                          textAlign: .center,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 18,
                            fontWeight: .w400,
                            letterSpacing: 0,
                          ),
                        ),
                        SizedBox(height: 24),
                        _buildPermissionRow(
                          icon: Icons.photo_camera,
                          title: 'Camera',
                          subtitle: 'To take photos',
                          isGranted: _isPermissionReady(_cameraStatus),
                        ),
                        const SizedBox(height: 24),
                        _buildPermissionRow(
                          icon: Icons.mic,
                          title: 'Microphone',
                          subtitle: 'To detect claps',
                          isGranted: _isPermissionReady(_microphoneStatus),
                        ),
                        SizedBox(height: 24),
                        _buildContinueButton(onPressed: _requestPermissions),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
