import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/entities.dart';
import 'decor.dart';
import 'game_screen.dart';
import 'sound_effects.dart';
import 'table_painter.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _playersPerSide = 1;
  int _targetScore = GameConfig.defaultTargetScore;
  bool _powerUps = true;
  bool _balance = false;
  bool _sounds = SoundEffects.instance.enabled;

  void _play() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GameScreen(
        playersPerSide: _playersPerSide,
        targetScore: _targetScore,
        powerUpsEnabled: _powerUps,
        balanceEnabled: _balance,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Le décor de la table, assombri, en fond.
          Image.asset(
            Decor.asset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const ColoredBox(color: Color(0xA6000000)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 28,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: 'JUNGLE ',
                            style: TextStyle(color: TeamColors.of(Side.left)),
                          ),
                          TextSpan(
                            text: 'HOCKEY',
                            style: TextStyle(color: TeamColors.of(Side.right)),
                          ),
                        ]),
                        style: textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                    ),
                    _Labeled(
                      label: 'Joueurs',
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 1, label: Text('1 contre 1'), icon: Icon(Icons.person)),
                          ButtonSegment(value: 2, label: Text('2 contre 2'), icon: Icon(Icons.groups)),
                        ],
                        selected: {_playersPerSide},
                        onSelectionChanged: (s) => setState(() => _playersPerSide = s.first),
                      ),
                    ),
                    _Labeled(
                      label: 'Points pour gagner',
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 5, label: Text('5')),
                          ButtonSegment(value: 7, label: Text('7')),
                          ButtonSegment(value: 10, label: Text('10')),
                        ],
                        selected: {_targetScore},
                        onSelectionChanged: (s) => setState(() => _targetScore = s.first),
                      ),
                    ),
                    SwitchListTile(
                      value: _powerUps,
                      onChanged: (v) => setState(() => _powerUps = v),
                      secondary: const Icon(Icons.auto_awesome),
                      title: const Text('Pouvoirs'),
                      subtitle: const Text('Turbo, frein adverse, tête chercheuse, maillet géant, brouillard, cages'),
                    ),
                    SwitchListTile(
                      value: _balance,
                      onChanged: (v) => setState(() => _balance = v),
                      secondary: const Icon(Icons.balance),
                      title: const Text('Équilibrage'),
                      subtitle: const Text('Plus l\'écart de score est grand, plus les tirs de l\'équipe qui mène sont ralentis et ceux de l\'autre accélérés'),
                    ),
                    SwitchListTile(
                      value: _sounds,
                      onChanged: (v) => setState(() {
                        _sounds = v;
                        SoundEffects.instance.enabled = v;
                      }),
                      secondary: Icon(_sounds ? Icons.volume_up : Icons.volume_off),
                      title: const Text('Sons'),
                    ),
                    FilledButton.icon(
                      onPressed: _play,
                      icon: const Icon(Icons.sports_hockey),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text('Jouer', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        child,
      ],
    );
  }
}
