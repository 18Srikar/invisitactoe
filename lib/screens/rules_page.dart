import 'package:flutter/material.dart';
import 'package:invisitactoe/widgets/background_manager.dart';
import 'package:invisitactoe/widgets/paper_button.dart';
class RulesPage extends StatelessWidget {
  const RulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Persistent-feeling notebook background (shared Hero tag)
          Positioned.fill(
            child: Hero(
              tag: '__notebook_bg__',
              child: Image.asset(BackgroundManager.current,
                  fit: BoxFit.cover)
            ),
          ),

          // Rules image in the center
          Center(
            child: Image.asset(
              'assets/images/rules_overlay.png',
              width: screenWidth * 0.9,
              fit: BoxFit.contain,
            ),
          ),

          // Custom handwritten back arrow PNG
          Positioned(
            top: 25,
            left: 25,
            child: PaperButton(
              onTap: () => Navigator.pop(context),
              child: Image.asset(
                'assets/images/back_arrow_handwritten.png',
                width: 35,
                height: 35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
