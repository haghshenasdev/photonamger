import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoPreview extends StatefulWidget {
  final String path;

  const VideoPreview({super.key, required this.path});

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late VideoPlayerController _controller;

  Timer? _hideControlsTimer;

  bool _showControls = true;
  bool _isMuted = false;
  bool _isFullscreen = false;

  double _volume = 1.0;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.file(File(widget.path));

    _controller.addListener(_videoListener);

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();

      await _controller.setVolume(1.0);

      if (!mounted) return;

      setState(() {});

      _startHideTimer();
    } catch (_) {
      if (!mounted) return;
      setState(() {});
    }
  }

  void _videoListener() {
    if (!mounted) return;

    if (_controller.value.isCompleted) {
      setState(() {
        _showControls = true;
      });

      _hideControlsTimer?.cancel();
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller.removeListener(_videoListener);
    _controller.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Controls visibility
  // ---------------------------------------------------------------------------

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _startHideTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();

    if (!_controller.value.isPlaying) {
      return;
    }

    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      setState(() {
        _showControls = false;
      });
    });
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });

    _startHideTimer();
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  Future<void> _togglePlay() async {
    if (!_controller.value.isInitialized) return;

    if (_controller.value.isCompleted) {
      await _controller.seekTo(Duration.zero);
      await _controller.play();
    } else if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }

    if (!mounted) return;

    setState(() {});

    _startHideTimer();
  }

  Future<void> _seekRelative(int seconds) async {
    if (!_controller.value.isInitialized) return;

    final current = _controller.value.position;
    final duration = _controller.value.duration;

    var target = current + Duration(seconds: seconds);

    if (target < Duration.zero) {
      target = Duration.zero;
    }

    if (target > duration) {
      target = duration;
    }

    await _controller.seekTo(target);

    _showControlsTemporarily();
  }

  Future<void> _restart() async {
    await _controller.seekTo(Duration.zero);
    await _controller.play();

    _showControlsTemporarily();
  }

  // ---------------------------------------------------------------------------
  // Volume
  // ---------------------------------------------------------------------------

  Future<void> _toggleMute() async {
    if (_isMuted) {
      await _controller.setVolume(_volume);

      setState(() {
        _isMuted = false;
      });
    } else {
      await _controller.setVolume(0);

      setState(() {
        _isMuted = true;
      });
    }

    _showControlsTemporarily();
  }

  Future<void> _setVolume(double value) async {
    _volume = value;

    await _controller.setVolume(_isMuted ? 0 : value);

    setState(() {});

    _showControlsTemporarily();
  }

  // ---------------------------------------------------------------------------
  // Speed
  // ---------------------------------------------------------------------------

  Future<void> _setPlaybackSpeed(double speed) async {
    await _controller.setPlaybackSpeed(speed);

    setState(() {
      _playbackSpeed = speed;
    });

    _showControlsTemporarily();
  }

  // ---------------------------------------------------------------------------
  // Keyboard
  // ---------------------------------------------------------------------------

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      _togglePlay();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      _seekRelative(-5);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      _seekRelative(5);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      _setVolume((_volume + 0.1).clamp(0.0, 1.0));
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _setVolume((_volume - 0.1).clamp(0.0, 1.0));
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: _buildPlayer(),
    );
  }

  Widget _buildPlayer() {
    if (!_controller.value.isInitialized) {
      if (_controller.value.hasError) {
        return _buildError();
      }

      return const Center(child: ProgressRing());
    }

    return MouseRegion(
      cursor: _showControls
          ? SystemMouseCursors.basic
          : SystemMouseCursors.none,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        onDoubleTap: _toggleFullscreen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideo(),

            if (_showControls) _buildControls(),

            if (_showControls && !_controller.value.isPlaying)
              _buildCenterPlayButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    final aspectRatio = _controller.value.aspectRatio;

    if (aspectRatio <= 0) {
      return const Center(child: Icon(FluentIcons.video, size: 64));
    }

    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Center play button
  // ---------------------------------------------------------------------------

  Widget _buildCenterPlayButton() {
    return Center(
      child: GestureDetector(
        onTap: _togglePlay,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            shape: BoxShape.circle,
          ),
          child: const Icon(FluentIcons.play, size: 32, color: Colors.white),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom controls
  // ---------------------------------------------------------------------------

  Widget _buildControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProgress(),

            const SizedBox(height: 2),

            Row(
              children: [
                // Play / Pause
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying
                        ? FluentIcons.pause
                        : FluentIcons.play,
                    color: Colors.white,
                  ),
                  onPressed: _togglePlay,
                ),

                // Back 5
                IconButton(
                  icon: const Icon(FluentIcons.rewind, color: Colors.white),
                  onPressed: () => _seekRelative(-5),
                ),

                // Forward 5
                IconButton(
                  icon: const Icon(
                    FluentIcons.fast_forward,
                    color: Colors.white,
                  ),
                  onPressed: () => _seekRelative(5),
                ),

                const SizedBox(width: 8),

                Text(
                  _formatDuration(_controller.value.position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),

                const Text(' / ', style: TextStyle(color: Colors.white)),

                Text(
                  _formatDuration(_controller.value.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),

                const Spacer(),

                // Speed
                _buildSpeedButton(),

                const SizedBox(width: 4),

                // Volume
                _buildVolumeButton(),

                const SizedBox(width: 4),

                // Fullscreen
                IconButton(
                  icon: Icon(
                    _isFullscreen
                        ? FluentIcons.back_to_window
                        : FluentIcons.full_screen,
                    color: Colors.white,
                  ),
                  onPressed: _toggleFullscreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Progress
  // ---------------------------------------------------------------------------

  Widget _buildProgress() {
    return VideoProgressIndicator(
      _controller,
      allowScrubbing: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  // ---------------------------------------------------------------------------
  // Speed menu
  // ---------------------------------------------------------------------------

  Widget _buildSpeedButton() {
    return FlyoutTarget(
      controller: _speedFlyoutController,
      child: IconButton(
        icon: Text(
          '${_playbackSpeed}x',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: () {
          _speedFlyoutController.showFlyout(
            barrierDismissible: true,
            builder: (context) {
              return MenuFlyout(
                items: [
                  _speedItem(0.5),
                  _speedItem(0.75),
                  _speedItem(1.0),
                  _speedItem(1.25),
                  _speedItem(1.5),
                  _speedItem(2.0),
                ],
              );
            },
          );
        },
      ),
    );
  }

  final FlyoutController _speedFlyoutController = FlyoutController();

  MenuFlyoutItem _speedItem(double speed) {
    return MenuFlyoutItem(
      text: Text('${speed}x'),
      trailing: speed == _playbackSpeed
          ? const Icon(FluentIcons.check_mark)
          : null,
      onPressed: () {
        _setPlaybackSpeed(speed);
        _speedFlyoutController.close();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Volume
  // ---------------------------------------------------------------------------

  Widget _buildVolumeButton() {
    return FlyoutTarget(
      controller: _volumeFlyoutController,
      child: IconButton(
        icon: Icon(
          _isMuted || _volume == 0
              ? FluentIcons.volume0
              : _volume < 0.5
              ? FluentIcons.volume1
              : FluentIcons.volume3,
          color: Colors.white,
        ),
        onPressed: () {
          _volumeFlyoutController.showFlyout(
            barrierDismissible: true,
            builder: (context) {
              return FlyoutContent(
                child: SizedBox(
                  width: 220,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(FluentIcons.volume0),
                        onPressed: _toggleMute,
                      ),
                      Expanded(
                        child: Slider(
                          min: 0,
                          max: 1,
                          value: _volume,
                          onChanged: _setVolume,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  final FlyoutController _volumeFlyoutController = FlyoutController();

  // ---------------------------------------------------------------------------
  // Fullscreen
  // ---------------------------------------------------------------------------

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    // فعلاً وضعیت Fullscreen را داخلی نگه می‌داریم.
    //
    // اگر ImagePreviewDialog تو امکان تغییر اندازه / Window fullscreen
    // داشته باشد، اینجا باید آن را به Dialog متصل کنیم.
    //
    // در غیر این صورت Double Click همچنان کنترل‌ها را فعال/غیرفعال می‌کند.
    _showControlsTemporarily();
  }

  // ---------------------------------------------------------------------------
  // Error
  // ---------------------------------------------------------------------------

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(FluentIcons.error, size: 48),
          const SizedBox(height: 12),
          Text(
            _controller.value.errorDescription ?? 'خطا در پخش ویدئو',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Button(
            child: const Text('تلاش مجدد'),
            onPressed: () async {
              await _controller.dispose();

              _controller = VideoPlayerController.file(File(widget.path));

              _controller.addListener(_videoListener);

              setState(() {});

              await _initialize();
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return '00:00';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
