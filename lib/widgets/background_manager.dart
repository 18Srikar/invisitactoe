import 'dart:math';

class BackgroundManager {
  static const List<String> _bgPaths = [
    'assets/images/notebook_bg_1.jpg',
    'assets/images/notebook_bg_2.jpg',
    'assets/images/notebook_bg_4.jpg',
    'assets/images/notebook_bg_5.jpg',
    'assets/images/notebook_bg_6.jpg',


  ];

  static late final String current = _pick();

  static String _pick() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rng = Random(now);
    return _bgPaths[rng.nextInt(_bgPaths.length)];
  }
}
