import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../eos/eos.dart';
import '../models/public_models.dart';

Future<void> openEventGalleryViewer(
  BuildContext context, {
  required List<EventGalleryItem> items,
  required int initialIndex,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => _GalleryViewerDialog(items: items, initialIndex: initialIndex),
  );
}

class EventDetailGallerySection extends StatelessWidget {
  const EventDetailGallerySection({super.key, required this.items});

  final List<EventGalleryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return EosSection(
      title: 'Gallery',
      subtitle: 'Tap to preview',
      child: SizedBox(
        height: 132,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => SizedBox(width: context.eos.spacing.sm),
          itemBuilder: (context, index) {
            final item = items[index];
            return SizedBox(
              width: 180,
              child: EosSurfaceCard(
                onTap: () => openEventGalleryViewer(context, items: items, initialIndex: index),
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: EosRadius.input,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item.isVideo)
                        ColoredBox(
                          color: EosColors.plumDark,
                          child: Center(
                            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 42),
                          ),
                        )
                      else
                        Image.network(
                          item.url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: context.eosColors.surfaceContainerHighest,
                            child: const Center(child: Icon(Icons.broken_image_outlined)),
                          ),
                        ),
                      if (item.label != null)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          right: 8,
                          child: Text(
                            item.label!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.eosText.labelSmall?.copyWith(color: Colors.white),
                          ),
                        ),
                    ],
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

class _GalleryViewerDialog extends StatefulWidget {
  const _GalleryViewerDialog({required this.items, required this.initialIndex});
  final List<EventGalleryItem> items;
  final int initialIndex;

  @override
  State<_GalleryViewerDialog> createState() => _GalleryViewerDialogState();
}

class _GalleryViewerDialogState extends State<_GalleryViewerDialog> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    widget.items[_index].label ?? 'Media ${_index + 1}/${widget.items.length}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  if (item.isVideo) return _NetworkVideoPlayer(url: item.url);
                  return InteractiveViewer(
                    child: Center(
                      child: Image.network(
                        item.url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(Icons.broken_image, color: Colors.white, size: 48),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkVideoPlayer extends StatefulWidget {
  const _NetworkVideoPlayer({required this.url});
  final String url;

  @override
  State<_NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<_NetworkVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      }).catchError((e) {
        if (!mounted) return;
        setState(() => _error = '$e');
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)));
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio == 0 ? 16 / 9 : _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_controller),
            IconButton(
              onPressed: () {
                setState(() {
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                });
              },
              icon: Icon(
                _controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                color: Colors.white,
                size: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
