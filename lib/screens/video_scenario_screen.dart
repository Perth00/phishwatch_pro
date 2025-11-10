import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:lottie/lottie.dart';
import '../constants/app_theme.dart';
import 'package:provider/provider.dart';
import '../services/progress_service.dart';
import '../models/video_scenario.dart';
import '../widgets/confirm_dialog.dart';

class VideoScenarioScreen extends StatefulWidget {
  final VideoScenario scenario;
  const VideoScenarioScreen({super.key, required this.scenario});

  @override
  State<VideoScenarioScreen> createState() => _VideoScenarioScreenState();
}

class _VideoScenarioScreenState extends State<VideoScenarioScreen> {
  YoutubePlayerController? _yt;
  VideoPlayerController? _vp;
  int? _selected;
  bool _answered = false;
  bool _loadingVideo = true;
  bool _isLeaving = false; // Prevent double dialog when app bar back is used

  bool _looksLikeYoutubeId(String s) =>
      RegExp(r'^[0-9A-Za-z_-]{11}$').hasMatch(s);

  String? _extractYoutubeId(String urlRaw) {
    final String url = urlRaw
        .trim()
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .replaceAll('"', '');

    // 1) Package helper
    final String? byPkg = YoutubePlayer.convertUrlToId(url);
    if (byPkg != null && byPkg.isNotEmpty) return byPkg;

    // 2) Parse common formats
    try {
      final Uri uri = Uri.parse(url);

      // watch?v=VIDEO_ID
      final String? v = uri.queryParameters['v'];
      if (v != null && _looksLikeYoutubeId(v)) return v;

      // youtu.be/VIDEO_ID
      if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
        final String id = uri.pathSegments.first;
        if (_looksLikeYoutubeId(id)) return id;
      }

      // /embed/VIDEO_ID, /shorts/VIDEO_ID, or a raw segment that looks like an id
      final List<String> segs = uri.pathSegments;
      for (int i = 0; i < segs.length; i++) {
        final String seg = segs[i];
        if ((seg == 'embed' || seg == 'shorts') && i + 1 < segs.length) {
          final String id = segs[i + 1];
          if (_looksLikeYoutubeId(id)) return id;
        }
        if (_looksLikeYoutubeId(seg)) return seg;
      }
    } catch (_) {
      // ignore
    }

    // 3) Regex catch-all
    final RegExp exp = RegExp(
      r'(?:v=|be/|embed/|shorts/|/)([0-9A-Za-z_-]{11})(?:[?&]|$)',
    );
    final Match? m = exp.firstMatch(url);
    if (m != null && m.groupCount >= 1) return m.group(1);

    return null;
  }

  @override
  void initState() {
    super.initState();
    final String url = widget.scenario.videoUrl
        .trim()
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .replaceAll('"', '');
    final String? id = _extractYoutubeId(url);
    if (id != null) {
      _yt = YoutubePlayerController(
        initialVideoId: id,
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
      );
      _yt!.addListener(() {
        final v = _yt!.value;
        final bool buffering = v.playerState == PlayerState.buffering;
        final bool ready = v.isReady;
        final bool loading = !ready || buffering;
        if (loading != _loadingVideo && mounted) {
          setState(() => _loadingVideo = loading);
        }
      });
    } else {
      // Fallback to direct mp4/stream playback
      try {
        _vp = VideoPlayerController.networkUrl(Uri.parse(url))
          ..initialize().then((_) {
            if (!mounted) return;
            setState(() => _loadingVideo = false);
          });
      } catch (_) {
        // ignore
      }
    }
  }

  @override
  void dispose() {
    _yt?.dispose();
    _vp?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Future<bool> _confirmLeave() async {
      final bool? ok = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder:
            (_) => ConfirmDialog(
              title: 'Leave scenario?',
              message: 'Your current answer will not be saved.',
              confirmText: 'Leave',
              cancelText: 'Stay',
              onConfirm: () {},
              animationAsset: 'assets/animations/log_out.json',
            ),
      );
      return ok == true;
    }

    return WillPopScope(
      onWillPop: () async {
        if (_isLeaving) return true; // Already confirmed via app bar
        return await _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.scenario.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final ok = await _confirmLeave();
              if (ok && mounted) {
                setState(() => _isLeaving = true);
                Navigator.of(context).maybePop();
              }
            },
          ),
        ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_yt != null)
              Stack(
                fit: StackFit.passthrough,
                children: [
                  YoutubePlayer(
                    controller: _yt!,
                    showVideoProgressIndicator: true,
                  ),
                  if (_loadingVideo)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black26,
                        child: Center(
                          child: Lottie.asset(
                            'assets/animations/loading.json',
                            width: 120,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            else if (_vp != null && _vp!.value.isInitialized)
              AspectRatio(
                aspectRatio: _vp!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_vp!),
                    if (_loadingVideo || _vp!.value.isBuffering)
                      Container(
                        color: Colors.black26,
                        child: Center(
                          child: Lottie.asset(
                            'assets/animations/loading.json',
                            width: 120,
                          ),
                        ),
                      ),
                    IconButton(
                      iconSize: 56,
                      color: Colors.white,
                      onPressed: () {
                        setState(() {
                          _vp!.value.isPlaying ? _vp!.pause() : _vp!.play();
                        });
                      },
                      icon: Icon(
                        _vp!.value.isPlaying
                            ? Icons.pause_circle
                            : Icons.play_circle,
                      ),
                    ),
                  ],
                ),
              )
            else
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(
                  child: Lottie.asset(
                    'assets/animations/loading.json',
                    width: 120,
                  ),
                ),
              ),
            const SizedBox(height: AppConstants.spacingL),
            Text(widget.scenario.question, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppConstants.spacingS),
            ...List.generate(widget.scenario.options.length, (i) {
              final bool chosen = _selected == i;
              final bool correct = i == widget.scenario.correctIndex;
              final Color? color =
                  _answered && chosen
                      ? (correct
                          ? AppTheme.successColor.withOpacity(0.15)
                          : AppTheme.errorColor.withOpacity(0.15))
                      : null;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        _answered && chosen
                            ? (correct
                                ? AppTheme.successColor
                                : AppTheme.errorColor)
                            : theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: RadioListTile<int>(
                  value: i,
                  groupValue: _selected,
                  onChanged:
                      _answered ? null : (v) => setState(() => _selected = v),
                  title: Text(widget.scenario.options[i]),
                ),
              );
            }),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _selected == null || _answered
                            ? null
                            : () async {
                              final bool isCorrect =
                                  _selected == widget.scenario.correctIndex;
                              setState(() => _answered = true);
                              try {
                                await context
                                    .read<ProgressService>()
                                    .recordScenarioAttempt(
                                      scenarioId: widget.scenario.id,
                                      correct: isCorrect,
                                    );
                              } catch (_) {}
                            },
                    child: const Text('Check'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _answered
                            ? () => Navigator.of(context).maybePop()
                            : null,
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}
