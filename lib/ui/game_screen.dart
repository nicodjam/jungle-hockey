import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/air_hockey_game.dart';
import 'sound_effects.dart';
import 'table_layout.dart';
import 'table_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.playersPerSide,
    required this.targetScore,
    this.powerUpsEnabled = true,
    this.balanceEnabled = false,
  });

  final int playersPerSide;
  final int targetScore;
  final bool powerUpsEnabled;
  final bool balanceEnabled;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final AirHockeyGame _game;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  GamePhase _shownPhase = GamePhase.playing;
  TableLayout? _layout;
  final Stopwatch _sinceHaptic = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _game = AirHockeyGame(
      playersPerSide: widget.playersPerSide,
      targetScore: widget.targetScore,
      powerUpsEnabled: widget.powerUpsEnabled,
      balanceEnabled: widget.balanceEnabled,
      onEvent: _onGameEvent,
    )..addListener(_onGameChanged);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _game
      ..removeListener(_onGameChanged)
      ..dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    _game.update(dt);
  }

  /// Ne reconstruit l'interface (boutons) qu'au changement de phase ;
  /// le plateau, lui, est redessiné à chaque image par le painter.
  void _onGameChanged() {
    if (_game.phase != _shownPhase) {
      setState(() => _shownPhase = _game.phase);
    }
  }

  void _onGameEvent(GameEvent event, double intensity) {
    final sounds = SoundEffects.instance;
    switch (event) {
      case GameEvent.malletHit:
        sounds.hit(intensity);
        if (intensity > 0.1 && _sinceHaptic.elapsedMilliseconds > 60) {
          _sinceHaptic.reset();
          HapticFeedback.lightImpact();
        }
      case GameEvent.wallHit:
        break;
      case GameEvent.powerUp:
        sounds.power();
        HapticFeedback.mediumImpact();
      case GameEvent.goal:
        // Le but de la victoire a son propre son (événement suivant).
        final scorer = _game.lastScorer;
        if (scorer == null || _game.scoreOf(scorer) < _game.targetScore) {
          sounds.goal();
        }
        HapticFeedback.heavyImpact();
      case GameEvent.victory:
        sounds.victory();
        HapticFeedback.heavyImpact();
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    final layout = _layout;
    if (layout == null) return;
    _game.pointerDown(e.pointer, layout.toTable(e.localPosition));
  }

  void _onPointerMove(PointerMoveEvent e) {
    final layout = _layout;
    if (layout == null) return;
    _game.pointerMove(e.pointer, layout.toTable(e.localPosition));
  }

  void _onPointerUp(PointerEvent e) => _game.pointerUp(e.pointer);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _shownPhase != GamePhase.playing && _shownPhase != GamePhase.goal,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _game.pause();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            _layout = TableLayout.fit(constraints.biggest);
            return Stack(
              fit: StackFit.expand,
              children: [
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerUp,
                  child: CustomPaint(painter: TablePainter(_game)),
                ),
                Center(child: _buildCenterControls()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    switch (_shownPhase) {
      case GamePhase.playing:
      case GamePhase.goal:
        return IconButton.filledTonal(
          tooltip: 'Pause',
          iconSize: 28,
          onPressed: _game.pause,
          icon: const Icon(Icons.pause),
        );
      case GamePhase.paused:
        return _MenuPanel(children: [
          FilledButton.icon(
            onPressed: _game.resume,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Reprendre'),
          ),
          OutlinedButton.icon(
            onPressed: _game.restart,
            icon: const Icon(Icons.replay),
            label: const Text('Recommencer'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Menu'),
          ),
        ]);
      case GamePhase.finished:
        return _MenuPanel(children: [
          FilledButton.icon(
            onPressed: _game.restart,
            icon: const Icon(Icons.replay),
            label: const Text('Rejouer'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Menu'),
          ),
        ]);
    }
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withValues(alpha: 0.75),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: children,
        ),
      ),
    );
  }
}
