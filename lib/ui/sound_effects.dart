import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Effets sonores (assets/sounds/, synthétisés par tool/generate_sounds.py).
///
/// Lecteurs en mode basse latence (SoundPool sur Android), chargés une fois
/// au démarrage : un son part sans délai de chargement. Les contacts
/// maillet/palet tournent sur plusieurs lecteurs (trois hauteurs de
/// « tock » de noix de coco), pour que des coups rapprochés ne se coupent
/// pas. Les sons se mêlent à la musique éventuelle sans l'interrompre.
///
/// Si un son ne se charge pas, il est simplement muet.
class SoundEffects {
  SoundEffects._();

  static final SoundEffects instance = SoundEffects._();

  /// Coupé par l'interrupteur « Sons » du menu.
  bool enabled = true;

  /// Écart minimal entre deux sons de contact : un maillet qui pousse le
  /// palet le touche à chaque image, ce qui ferait un crépitement.
  static const int _hitMinGapMs = 45;

  final List<AudioPlayer> _hits = [];
  int _nextHit = 0;
  final Stopwatch _sinceHit = Stopwatch()..start();
  final Map<String, AudioPlayer> _cues = {};
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
      for (var i = 0; i < 6; i++) {
        _hits.add(await _player('sounds/hit_${i % 3 + 1}.wav'));
      }
      for (final name in const ['power', 'goal', 'victory']) {
        _cues[name] = await _player('sounds/$name.wav');
      }
    } catch (e) {
      debugPrint('SoundEffects: cannot load the sounds ($e)');
    }
  }

  Future<AudioPlayer> _player(String asset) async {
    final player = AudioPlayer();
    await player.setPlayerMode(PlayerMode.lowLatency);
    // stop (et non release) : le son reste chargé, prêt à rejouer.
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSource(AssetSource(asset));
    return player;
  }

  /// Contact maillet/palet ; [intensity] de 0 à 1 (vitesse de l'impact).
  void hit(double intensity) {
    if (!enabled || _hits.isEmpty || intensity < 0.02) return;
    if (_sinceHit.elapsedMilliseconds < _hitMinGapMs) return;
    _sinceHit.reset();
    final player = _hits[_nextHit];
    _nextHit = (_nextHit + 1) % _hits.length;
    _play(player, 0.3 + 0.7 * math.sqrt(intensity.clamp(0.0, 1.0)));
  }

  /// Un pouvoir commence.
  void power() => _cue('power');

  void goal() => _cue('goal');

  void victory() => _cue('victory');

  void _cue(String name) {
    final player = _cues[name];
    if (!enabled || player == null) return;
    _play(player, 1);
  }

  void _play(AudioPlayer player, double volume) {
    unawaited(() async {
      try {
        // En basse latence, il faut arrêter avant de rejouer depuis le début.
        await player.stop();
        await player.setVolume(volume);
        await player.resume();
      } catch (e) {
        debugPrint('SoundEffects: $e');
      }
    }());
  }
}
