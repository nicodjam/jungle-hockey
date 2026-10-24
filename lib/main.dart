import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/decor.dart';
import 'ui/menu_screen.dart';
import 'ui/sound_effects.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Tablette posée à plat, joueurs aux deux petits côtés : un seul sens de
  // paysage. Autoriser les deux ferait pivoter l'écran (et le plateau) au
  // moindre mouvement de la tablette pendant la partie.
  // (Doublé par android:screenOrientation="landscape" dans le manifeste,
  // pour que l'appli démarre déjà dans ce sens.)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await Decor.load();
  unawaited(SoundEffects.instance.load()); // en fond : le menu n'attend pas
  runApp(const JungleHockeyApp());
}

class JungleHockeyApp extends StatelessWidget {
  const JungleHockeyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jungle Hockey',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E9BFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF070B14),
      ),
      home: const MenuScreen(),
    );
  }
}
