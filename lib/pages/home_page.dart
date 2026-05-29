import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:hand_camera/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:path_provider/path_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with RouteAware, WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  StreamSubscription<dynamic>? _clapSubscription;
  Timer? _countdownTimer;
  String? _cameraError;
  String? _activeSettingsPanel;
  bool _isInitializing = false;
  bool _isListening = false;
  bool _isCountingDown = false;
  bool _isTakingPicture = false;
  FlashMode _flashMode = FlashMode.always;
  bool _resumeListeningAfterCapture = false;
  int _countdown = 3;
  int _countdownSeconds = 3;
  int _captureCount = 1;
  String _aspectRatioLabel = '4:3';
  double _ambientDecibel = 0;
  DateTime? _lastTriggerAt;

  static const List<int> _countdownOptions = [3, 5, 10, 15, 20, 30];
  static const Map<String, int> _captureModeOptions = {
    'Single': 1,
    'Burst 5': 5,
    'Burst 10': 10,
    'Burst 15': 15,
    'Burst 20': 20,
  };
  static const Map<String, double> _aspectRatioOptions = {
    '4:3': 4 / 3,
    '16:9': 16 / 9,
    '1:1': 1,
  };
  static const double _absoluteTriggerDecibel = 82;
  static const double _relativeTriggerDecibel = 18;
  static const Duration _triggerCooldown = Duration(seconds: 4);
  static const EventChannel _clapEventChannel = EventChannel(
    'hand_camera/clap_events',
  );
  static const MethodChannel _countdownSoundChannel = MethodChannel(
    'hand_camera/countdown_sound',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _startSoundDetection();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _stopSoundDetection();
    _countdownTimer?.cancel();
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    _initializeCamera();
    if (_resumeListeningAfterCapture) {
      _resumeListeningAfterCapture = false;
      _startSoundDetection();
    }
  }

  @override
  void didPushNext() {
    _disposeCamera();
    _stopSoundDetection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeCamera();
      _stopSoundDetection();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
      _startSoundDetection();
    }
  }

  Future<void> _initializeCamera({bool useSelectedCamera = false}) async {
    if (_isInitializing || (_cameraController?.value.isInitialized ?? false)) {
      return;
    }

    setState(() {
      _isInitializing = true;
      _cameraError = null;
    });

    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera found on this device.');
      }

      if (_selectedCameraIndex >= _cameras.length) {
        _selectedCameraIndex = 0;
      }
      final camera = useSelectedCamera
          ? _cameras[_selectedCameraIndex]
          : _cameraController == null
          ? _cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.back,
              orElse: () => _cameras[_selectedCameraIndex],
            )
          : _cameras[_selectedCameraIndex];
      _selectedCameraIndex = _cameras.indexOf(camera);
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      await _applyFlashMode(controller);
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isInitializing = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = error.description ?? error.code;
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = error.toString();
        _isInitializing = false;
      });
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    await controller?.dispose();
  }

  Future<void> _applyFlashMode(CameraController controller) async {
    try {
      await controller.setFlashMode(_flashMode);
    } catch (_) {
      _flashMode = FlashMode.off;
      await controller.setFlashMode(FlashMode.off).catchError((_) {});
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 ||
        _isInitializing ||
        _isCountingDown ||
        _isTakingPicture) {
      return;
    }

    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });
    await _disposeCamera();
    await _initializeCamera(useSelectedCamera: true);
  }

  String get _cameraDirectionLabel {
    if (_cameras.isEmpty || _selectedCameraIndex >= _cameras.length) {
      return 'Back';
    }

    return switch (_cameras[_selectedCameraIndex].lensDirection) {
      CameraLensDirection.front => 'Front',
      CameraLensDirection.back => 'Back',
      _ => 'Camera',
    };
  }

  FlashMode get _nextFlashMode {
    return switch (_flashMode) {
      FlashMode.always => FlashMode.auto,
      FlashMode.auto => FlashMode.off,
      _ => FlashMode.always,
    };
  }

  IconData get _flashIcon {
    return switch (_flashMode) {
      FlashMode.always => Icons.flash_on,
      FlashMode.auto => Icons.flash_auto,
      _ => Icons.flash_off,
    };
  }

  Color _flashIconColor(ColorScheme colorScheme) {
    return switch (_flashMode) {
      FlashMode.always || FlashMode.auto => colorScheme.primary,
      _ => colorScheme.onInverseSurface,
    };
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isInitializing ||
        _isTakingPicture) {
      return;
    }

    final nextFlashMode = _nextFlashMode;
    try {
      await controller.setFlashMode(nextFlashMode);
      if (!mounted) return;
      setState(() {
        _flashMode = nextFlashMode;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _flashMode = FlashMode.off;
        _cameraError = error.description ?? error.code;
      });
    }
  }

  void _showCountdownSettings() {
    if (_isCountingDown || _isTakingPicture) return;

    setState(() {
      _activeSettingsPanel = _activeSettingsPanel == 'countdown'
          ? null
          : 'countdown';
    });
  }

  void _showCaptureModeSettings() {
    if (_isCountingDown || _isTakingPicture) return;

    setState(() {
      _activeSettingsPanel = _activeSettingsPanel == 'capture'
          ? null
          : 'capture';
    });
  }

  void _toggleAspectRatio() {
    if (_isCountingDown || _isTakingPicture) return;

    final labels = _aspectRatioOptions.keys.toList();
    final currentIndex = labels.indexOf(_aspectRatioLabel);
    final nextIndex = currentIndex == -1
        ? 0
        : (currentIndex + 1) % labels.length;

    setState(() {
      _aspectRatioLabel = labels[nextIndex];
      _activeSettingsPanel = null;
    });
  }

  void _selectCountdownSeconds(int seconds) {
    setState(() {
      _countdownSeconds = seconds;
      _countdown = seconds;
      _activeSettingsPanel = null;
    });
  }

  void _selectCaptureCount(int count) {
    setState(() {
      _captureCount = count;
      _activeSettingsPanel = null;
    });
  }

  Future<void> _startSoundDetection() async {
    if (_isListening) return;

    try {
      if (Platform.isIOS) {
        await _startIosClapDetection();
      } else {
        _noiseMeter ??= NoiseMeter();
        await _noiseSubscription?.cancel();
        _noiseSubscription = _noiseMeter!.noise.listen(
          _handleNoiseReading,
          onError: _handleNoiseError,
          cancelOnError: false,
        );
      }
      if (!mounted) return;
      setState(() {
        _isListening = true;
        _cameraError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _cameraError = error.toString();
      });
    }
  }

  Future<void> _stopSoundDetection() async {
    await _noiseSubscription?.cancel();
    await _clapSubscription?.cancel();
    _noiseSubscription = null;
    _clapSubscription = null;
    if (!mounted) {
      _isListening = false;
      return;
    }
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _startIosClapDetection() async {
    await _clapSubscription?.cancel();
    _clapSubscription = _clapEventChannel.receiveBroadcastStream().listen(
      _handleIosClapEvent,
      onError: _handleNoiseError,
      cancelOnError: false,
    );
  }

  void _handleIosClapEvent(dynamic event) {
    if (!mounted) return;
    _startCountdown();
  }

  void _handleNoiseReading(NoiseReading reading) {
    final decibel = reading.maxDecibel;
    final ambient = _ambientDecibel == 0
        ? reading.meanDecibel
        : (_ambientDecibel * 0.92) + (reading.meanDecibel * 0.08);
    final isSharpSound =
        decibel >= _absoluteTriggerDecibel &&
        decibel - ambient >= _relativeTriggerDecibel;

    if (!mounted) return;
    setState(() {
      _ambientDecibel = ambient;
    });

    if (isSharpSound) {
      _startCountdown();
    }
  }

  void _handleNoiseError(Object error) {
    if (!mounted) return;
    setState(() {
      _cameraError = error.toString();
      _isListening = false;
    });
  }

  Future<void> _startCountdown() async {
    if (_isCountingDown || _isTakingPicture) return;

    final now = DateTime.now();
    final lastTriggerAt = _lastTriggerAt;
    if (lastTriggerAt != null &&
        now.difference(lastTriggerAt) < _triggerCooldown) {
      return;
    }

    _lastTriggerAt = now;
    _countdownTimer?.cancel();
    _resumeListeningAfterCapture = _isListening;
    if (_isListening) {
      await _stopSoundDetection();
    }
    if (!mounted) return;

    setState(() {
      _countdown = _countdownSeconds;
      _isCountingDown = true;
      _activeSettingsPanel = null;
    });
    _playCountdownSound(isFinal: false);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdown <= 1) {
        timer.cancel();
        _playCountdownSound(isFinal: true);
        setState(() {
          _isCountingDown = false;
        });
        _takePicture();
        return;
      }

      setState(() {
        _countdown -= 1;
      });
      _playCountdownSound(isFinal: false);
    });
  }

  Future<void> _playCountdownSound({required bool isFinal}) async {
    if (Platform.isIOS) {
      try {
        await _countdownSoundChannel.invokeMethod<void>('play', {
          'isFinal': isFinal,
        });
        return;
      } catch (_) {}
    }

    await SystemSound.play(
      isFinal ? SystemSoundType.alert : SystemSoundType.click,
    );
  }

  Future<void> _takePicture() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    setState(() {
      _isTakingPicture = true;
      _cameraError = null;
    });

    try {
      final imagePaths = <String>[];
      for (var index = 0; index < _captureCount; index += 1) {
        final image = await controller.takePicture();
        final croppedPath = await _cropImageToAspectRatio(image.path);
        imagePaths.add(croppedPath);
        if (index < _captureCount - 1) {
          await Future.delayed(const Duration(milliseconds: 280));
        }
      }
      if (!mounted) return;

      setState(() {
        _isTakingPicture = false;
      });
      context.push('/photo-captured', extra: imagePaths);
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = error.description ?? error.code;
        _isTakingPicture = false;
      });
      if (_resumeListeningAfterCapture) {
        _resumeListeningAfterCapture = false;
        _startSoundDetection();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = error.toString();
        _isTakingPicture = false;
      });
      if (_resumeListeningAfterCapture) {
        _resumeListeningAfterCapture = false;
        _startSoundDetection();
      }
    }
  }

  Future<String> _cropImageToAspectRatio(String imagePath) async {
    final imageFile = File(imagePath);
    final bytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final sourceImage = frame.image;

    try {
      final sourceWidth = sourceImage.width.toDouble();
      final sourceHeight = sourceImage.height.toDouble();
      final selectedAspectRatio =
          _aspectRatioOptions[_aspectRatioLabel] ??
          _aspectRatioOptions.values.first;
      final targetAspectRatio = sourceWidth >= sourceHeight
          ? selectedAspectRatio
          : 1 / selectedAspectRatio;
      final sourceAspectRatio = sourceWidth / sourceHeight;

      late final Rect sourceRect;
      if (sourceAspectRatio > targetAspectRatio) {
        final cropWidth = sourceHeight * targetAspectRatio;
        sourceRect = Rect.fromLTWH(
          (sourceWidth - cropWidth) / 2,
          0,
          cropWidth,
          sourceHeight,
        );
      } else {
        final cropHeight = sourceWidth / targetAspectRatio;
        sourceRect = Rect.fromLTWH(
          0,
          (sourceHeight - cropHeight) / 2,
          sourceWidth,
          cropHeight,
        );
      }

      final outputWidth = sourceRect.width.round();
      final outputHeight = sourceRect.height.round();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        sourceImage,
        sourceRect,
        Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
        Paint(),
      );

      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(outputWidth, outputHeight);
      final croppedBytes = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      croppedImage.dispose();
      picture.dispose();

      if (croppedBytes == null) {
        return imagePath;
      }

      final temporaryDirectory = await getTemporaryDirectory();
      final croppedFile = File(
        '${temporaryDirectory.path}/aspect_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await croppedFile.writeAsBytes(croppedBytes.buffer.asUint8List());
      try {
        await imageFile.delete();
      } catch (_) {}
      return croppedFile.path;
    } finally {
      sourceImage.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonBackground = colorScheme.onTertiaryFixed;
    final buttonForeground = colorScheme.onInverseSurface;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildCameraView()),
          Positioned(
            left: 16,
            right: 16,
            top: 60,
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                GestureDetector(
                  onTap: _isInitializing || _isCountingDown || _isTakingPicture
                      ? null
                      : _toggleFlash,
                  child: Container(
                    padding: .only(top: 8, bottom: 8, left: 12, right: 12),
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: .circular(40),
                      color: buttonBackground,
                    ),
                    child: Icon(
                      _flashIcon,
                      color: _flashIconColor(colorScheme),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _isCountingDown || _isTakingPicture
                      ? null
                      : _showCountdownSettings,
                  child: Container(
                    padding: .only(top: 8, bottom: 8, left: 12, right: 12),
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: .circular(40),
                      color: buttonBackground,
                    ),
                    child: Row(
                      spacing: 4,
                      children: [
                        Icon(Icons.timer, size: 18, color: colorScheme.primary),
                        Text(
                          '${_countdownSeconds}s',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _isCountingDown || _isTakingPicture
                      ? null
                      : _toggleAspectRatio,
                  child: Container(
                    padding: .only(top: 8, bottom: 8, left: 12, right: 12),
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: .circular(40),
                      color: buttonBackground,
                    ),
                    child: Row(
                      spacing: 4,
                      children: [
                        Icon(
                          Icons.aspect_ratio,
                          size: 18,
                          color: buttonForeground,
                        ),
                        Text(
                          _aspectRatioLabel,
                          style: TextStyle(
                            color: buttonForeground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // GestureDetector(
                //   onTap: () => {},
                //   child: Container(
                //     padding: .only(top: 8, bottom: 8, left: 12, right: 12),
                //     height: 40,
                //     decoration: BoxDecoration(
                //       borderRadius: .circular(40),
                //       color: buttonBackground,
                //     ),
                //     child: Icon(Icons.settings, color: buttonForeground),
                //   ),
                // ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 60,
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                GestureDetector(
                  onTap: _isListening
                      ? _stopSoundDetection
                      : _startSoundDetection,
                  child: Container(
                    padding: .only(top: 8, bottom: 8, left: 12, right: 12),
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: .circular(40),
                      color: buttonBackground,
                    ),
                    child: Row(
                      spacing: 4,
                      children: [
                        Icon(
                          _isListening
                              ? Icons.mic_none_outlined
                              : Icons.mic_off_outlined,
                          color: _isListening
                              ? colorScheme.primary
                              : buttonForeground,
                        ),
                        Text(
                          _isListening ? 'Listening...' : 'Clap Mode',
                          style: TextStyle(
                            color: _isListening
                                ? colorScheme.primary
                                : buttonForeground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _isCountingDown || _isTakingPicture
                      ? null
                      : _showCaptureModeSettings,
                  child: Container(
                    padding: .only(top: 8, bottom: 8, left: 12, right: 12),
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: .circular(40),
                      color: buttonBackground,
                    ),
                    child: Row(
                      spacing: 4,
                      children: [
                        Icon(
                          Icons.photo_camera_outlined,
                          size: 18,
                          color: buttonForeground,
                        ),
                        Text(
                          _captureCount == 1
                              ? 'Single'
                              : 'Burst $_captureCount',
                          style: TextStyle(
                            color: buttonForeground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap:
                      _cameras.length < 2 ||
                          _isInitializing ||
                          _isCountingDown ||
                          _isTakingPicture
                      ? null
                      : _switchCamera,
                  child: Container(
                    padding: .only(top: 8, bottom: 8, left: 12, right: 12),
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: .circular(40),
                      color: buttonBackground,
                    ),
                    child: Row(
                      spacing: 4,
                      children: [
                        Icon(
                          Icons.cameraswitch_outlined,
                          size: 18,
                          color: buttonForeground,
                        ),
                        Text(
                          _cameraDirectionLabel,
                          style: TextStyle(
                            color: buttonForeground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 146,
            child: Center(child: _buildCaptureButton()),
          ),
          if (_isListening && !_isCountingDown && !_isTakingPicture)
            Positioned(
              left: 16,
              right: 16,
              bottom: 232,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: buttonBackground,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.scrim.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Text(
                      '👏 Clap to take photo',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_isCountingDown)
            Positioned.fill(
              child: ColoredBox(
                color: colorScheme.scrim.withValues(alpha: 0.45),
                child: Center(
                  child: Text(
                    '$_countdown',
                    style: TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontSize: 96,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          if (_isTakingPicture)
            Positioned.fill(
              child: ColoredBox(
                color: colorScheme.scrim.withValues(alpha: 0.26),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_activeSettingsPanel != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  setState(() {
                    _activeSettingsPanel = null;
                  });
                },
              ),
            ),
          if (_activeSettingsPanel != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildSettingsPanel(),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    final isCountdownPanel = _activeSettingsPanel == 'countdown';
    final title = isCountdownPanel ? 'Countdown' : 'Capture mode';
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: isCountdownPanel
                    ? [
                        for (final seconds in _countdownOptions)
                          ChoiceChip(
                            selected: seconds == _countdownSeconds,
                            label: Text('${seconds}s'),
                            onSelected: (_) => _selectCountdownSeconds(seconds),
                          ),
                      ]
                    : [
                        for (final option in _captureModeOptions.entries)
                          ChoiceChip(
                            selected: option.value == _captureCount,
                            label: Text(option.key),
                            onSelected: (_) =>
                                _selectCaptureCount(option.value),
                          ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    final controller = _cameraController;
    final colorScheme = Theme.of(context).colorScheme;
    final canCapture =
        controller != null &&
        controller.value.isInitialized &&
        !_isInitializing &&
        !_isCountingDown &&
        !_isTakingPicture;

    return SizedBox(
      width: 72,
      height: 72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.surfaceContainerHighest,
            width: 5,
          ),
          color: colorScheme.scrim.withValues(alpha: 0.18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: FilledButton(
            onPressed: canCapture ? _startCountdown : null,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: colorScheme.surfaceContainerHighest,
              disabledBackgroundColor: colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.38),
            ),
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    final controller = _cameraController;
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _cameraError!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final selectedAspectRatio =
            _aspectRatioOptions[_aspectRatioLabel] ??
            _aspectRatioOptions.values.first;
        final frameAspectRatio = constraints.maxWidth <= constraints.maxHeight
            ? 1 / selectedAspectRatio
            : selectedAspectRatio;

        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: AspectRatio(
              aspectRatio: frameAspectRatio,
              child: _buildCameraPreview(controller),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCameraPreview(CameraController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize;
        if (previewSize == null) {
          return CameraPreview(controller);
        }

        final previewAspectRatio = previewSize.height / previewSize.width;
        final screenAspectRatio = constraints.maxWidth / constraints.maxHeight;
        final scale = previewAspectRatio / screenAspectRatio;

        return ClipRect(
          child: Transform.scale(
            scale: scale < 1 ? 1 / scale : scale,
            child: Center(child: CameraPreview(controller)),
          ),
        );
      },
    );
  }
}
