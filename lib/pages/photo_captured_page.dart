import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:hand_camera/providers/rewarder_model.dart';
import 'package:provider/provider.dart';

class PhotoCapturedPage extends StatefulWidget {
  const PhotoCapturedPage({super.key, required this.imagePaths});

  final List<String> imagePaths;

  @override
  State<PhotoCapturedPage> createState() => _PhotoCapturedPageState();
}

class _PhotoCapturedPageState extends State<PhotoCapturedPage> {
  bool _isSaving = false;
  bool _isSaved = false;
  String? _savedMessage;

  static const _backgroundColor = Color(0xFF18182A);
  static const _orangeColor = Color(0xFFF78433);
  static const _outlineColor = Color(0xFF5D5C72);

  Future<void> _retake() async {
    if (!_isSaved) {
      for (final imagePath in widget.imagePaths) {
        try {
          await File(imagePath).delete();
        } catch (_) {}
      }
    }
    if (!mounted) return;
    context.pop();
  }

  Future<void> _savePhoto() async {
    if (_isSaving || _isSaved) return;

    setState(() {
      _isSaving = true;
    });

    try {
      for (final imagePath in widget.imagePaths) {
        await Gal.putImage(imagePath);
      }
      if (!mounted) return;

      Provider.of<RewarderModel>(context, listen: false).insert();
      setState(() {
        _isSaving = false;
        _isSaved = true;
        _savedMessage = widget.imagePaths.length == 1
            ? 'Saved to Photos'
            : 'Saved ${widget.imagePaths.length} photos to Photos';
      });
    } on GalException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: ${error.type.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _backgroundColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 30),
                Text(
                  widget.imagePaths.length == 1
                      ? 'Photo Captured'
                      : '${widget.imagePaths.length} Photos Captured',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final buttonAreaHeight = 138.0;
                      final frameHeight =
                          constraints.maxHeight - buttonAreaHeight;

                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: frameHeight.clamp(280.0, 620.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ColoredBox(
                                color: Colors.black,
                                child: PageView.builder(
                                  itemCount: widget.imagePaths.length,
                                  itemBuilder: (context, index) {
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.file(
                                          File(widget.imagePaths[index]),
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return const Center(
                                                  child: Text(
                                                    'Photo unavailable',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                );
                                              },
                                        ),
                                        if (widget.imagePaths.length > 1)
                                          Positioned(
                                            right: 12,
                                            bottom: 12,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.58,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 5,
                                                    ),
                                                child: Text(
                                                  '${index + 1}/${widget.imagePaths.length}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          _buildActions(),
                          if (_savedMessage != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _savedMessage!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 62,
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : _retake,
              icon: const Icon(Icons.delete_outline, size: 25),
              label: const Text('Retake'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
                side: const BorderSide(color: _outlineColor, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 62,
            child: FilledButton.icon(
              onPressed: _isSaving || _isSaved ? null : _savePhoto,
              icon: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_download_outlined, size: 25),
              label: Text(_isSaved ? 'Saved' : 'Save'),
              style: FilledButton.styleFrom(
                backgroundColor: _orangeColor,
                disabledBackgroundColor: _orangeColor.withValues(alpha: 0.72),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
