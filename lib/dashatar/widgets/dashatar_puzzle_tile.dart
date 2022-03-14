import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:very_good_slide_puzzle/audio_control/audio_control.dart';
import 'package:very_good_slide_puzzle/dashatar/dashatar.dart';
import 'package:very_good_slide_puzzle/helpers/helpers.dart';
import 'package:very_good_slide_puzzle/l10n/l10n.dart';
import 'package:very_good_slide_puzzle/layout/layout.dart';
import 'package:very_good_slide_puzzle/models/models.dart';
import 'package:very_good_slide_puzzle/puzzle/puzzle.dart';
import 'package:very_good_slide_puzzle/theme/themes/themes.dart';
import 'package:video_player/video_player.dart';

abstract class _TileSize {
  static double small = 75;
  static double medium = 100;
  static double large = 112;
}

/// {@template dashatar_puzzle_tile}
/// Displays the puzzle tile associated with [tile]
/// based on the puzzle [state].
/// {@endtemplate}
class DashatarPuzzleTile extends StatefulWidget {
  /// {@macro dashatar_puzzle_tile}
  const DashatarPuzzleTile({
    Key? key,
    required this.tile,
    required this.state,
    required this.videoController,
    AudioPlayerFactory? audioPlayer,
  })  : _audioPlayerFactory = audioPlayer ?? getAudioPlayer,
        super(key: key);

  /// The tile to be displayed.
  final Tile tile;

  /// The state of the puzzle.
  final PuzzleState state;
  final AudioPlayerFactory _audioPlayerFactory;
  final VideoPlayerController videoController;

  @override
  State<DashatarPuzzleTile> createState() =>
      DashatarPuzzleTileState(videoController);
}

/// The state of [DashatarPuzzleTile].
@visibleForTesting
class DashatarPuzzleTileState extends State<DashatarPuzzleTile>
    with SingleTickerProviderStateMixin {
  DashatarPuzzleTileState(this.videoController);

  AudioPlayer? _audioPlayer;
  late final Timer _timer;

  /// The controller that drives [_scale] animation.
  late AnimationController _controller;
  late Animation<double> _scale;
  VideoPlayerController videoController;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: PuzzleThemeAnimationDuration.puzzleTileScale,
    );

    _scale = Tween<double>(begin: 1, end: 0.94).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 1, curve: Curves.easeInOut),
      ),
    );

    // Delay the initialization of the audio player for performance reasons,
    // to avoid dropping frames when the theme is changed.
    _timer = Timer(const Duration(seconds: 1), () {
      _audioPlayer = widget._audioPlayerFactory()
        ..setAsset('assets/audio/tile_move.mp3');
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  double layoutToTileSize(ResponsiveLayoutSize layoutSize) {
    switch (layoutSize) {
      case ResponsiveLayoutSize.small:
        return _TileSize.small;

      case ResponsiveLayoutSize.medium:
        return _TileSize.medium;

      case ResponsiveLayoutSize.large:
        return _TileSize.large;

      default:
        return _TileSize.large;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.state.puzzle.getDimension();
    final theme = context.select((DashatarThemeBloc bloc) => bloc.state.theme);
    final status =
        context.select((DashatarPuzzleBloc bloc) => bloc.state.status);
    final hasStarted = status == DashatarPuzzleStatus.started;
    final puzzleIncomplete =
        context.select((PuzzleBloc bloc) => bloc.state.puzzleStatus) ==
            PuzzleStatus.incomplete;

    final movementDuration = status == DashatarPuzzleStatus.loading
        ? const Duration(milliseconds: 800)
        : const Duration(milliseconds: 370);

    final canPress = hasStarted && puzzleIncomplete;

    return AudioControlListener(
      audioPlayer: _audioPlayer,
      child: AnimatedAlign(
        alignment: FractionalOffset(
          (widget.tile.currentPosition.x - 1) / (size - 1),
          (widget.tile.currentPosition.y - 1) / (size - 1),
        ),
        duration: movementDuration,
        curve: Curves.easeInOut,
        child: ResponsiveLayoutBuilder(
          small: (_, child) => SizedBox(
            key: Key('dashatar_puzzle_tile_small_${widget.tile.value}'),
            width: _TileSize.small,
            height: _TileSize.small,
            child: child,
          ),
          medium: (_, child) => SizedBox(
            key: Key('dashatar_puzzle_tile_medium_${widget.tile.value}'),
            width: _TileSize.medium,
            height: _TileSize.medium,
            child: child,
          ),
          large: (_, child) => SizedBox(
            key: Key('dashatar_puzzle_tile_large_${widget.tile.value}'),
            width: _TileSize.large,
            height: _TileSize.large,
            child: child,
          ),
          child: (layoutSize) => Container(
            decoration: BoxDecoration(
              color: Colors.black26,
              border: Border.all(
                color: Colors.black,
                width: 1,
              ),
            ),
            child: MouseRegion(
              onEnter: (_) {
                if (canPress) {
                  _controller.forward();
                }
              },
              onExit: (_) {
                if (canPress) {
                  _controller.reverse();
                }
              },
              child: ScaleTransition(
                key: Key('dashatar_puzzle_tile_scale_${widget.tile.value}'),
                scale: _scale,
                child: videoController.value.isInitialized
                    ? InkWell(
                        onTap: canPress
                            ? () {
                                context
                                    .read<PuzzleBloc>()
                                    .add(TileTapped(widget.tile));
                                unawaited(_audioPlayer?.replay());
                              }
                            : null,
                        child: IgnorePointer(
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            fit: StackFit.expand,
                            children: [
                              Positioned(
                                top: -(widget.tile.correctPosition.y) *
                                        (layoutToTileSize(layoutSize) + 3) -
                                    layoutToTileSize(layoutSize) *
                                        0.25 *
                                        videoController.value.aspectRatio,
                                left: -(widget.tile.correctPosition.x - 1) *
                                        (layoutToTileSize(layoutSize) + 3) -
                                    layoutToTileSize(layoutSize) *
                                        0.5 *
                                        videoController.value.aspectRatio,
                                width: (layoutToTileSize(layoutSize) + 4) *
                                    4.0 *
                                    videoController.value.aspectRatio,
                                height: layoutToTileSize(layoutSize) *
                                    4.0 *
                                    videoController.value.aspectRatio,
                                child: VideoPlayer(videoController),
                              ),
                              //VideoPlayer(videoController)
                            ],
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(5),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                //child: VideoPlayer(videoController),
              ),
            ),
          ),
        ),
      ),
    );
  }
}