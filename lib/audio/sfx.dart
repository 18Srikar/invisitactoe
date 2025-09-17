import 'dart:math';
import 'package:audioplayers/audioplayers.dart';

class Sfx {
  static final _rng = Random();

  static late final List<AudioPlayer> _x;
  static late final List<AudioPlayer> _o;
  static bool _ready = false;

  /// Call once in main(): await Sfx.init();
  static Future<void> init() async {
    _x = [AudioPlayer(), AudioPlayer()];
    _o = [AudioPlayer(), AudioPlayer()];

    // Configure all players
    for (final p in [..._x, ..._o]) {
      await p.setReleaseMode(ReleaseMode.stop); // play once, stop
      await p.setVolume(1.0);
    }

    // Preload sources (no network, no file IO at play-time)
    await _x[0].setSourceAsset('audio/x_scribble_1.wav');
    await _x[1].setSourceAsset('audio/x_scribble_2.wav');
    await _o[0].setSourceAsset('audio/o_scribble_1.wav');
    await _o[1].setSourceAsset('audio/o_scribble_2.wav');

    _ready = true;
  }

  static Future<void> _replay(AudioPlayer p) async {
    // Be permissive; avoid throwing on state races
    try { await p.stop(); } catch (_) {}
    try { await p.seek(Duration.zero); } catch (_) {}
    try { await p.resume(); } catch (_) {}
  }

  /// Random X scribble
  static void x() {
    if (!_ready) return;
    _replay(_x[_rng.nextInt(_x.length)]);
  }

  /// Random O scribble
  static void o() {
    if (!_ready) return;
    _replay(_o[_rng.nextInt(_o.length)]);
  }

  /// Optional app shutdown cleanup
  static Future<void> dispose() async {
    for (final p in [..._x, ..._o]) {
      try { await p.release(); } catch (_) {}
      try { await p.dispose(); } catch (_) {}
    }
    _ready = false;
  }
}
