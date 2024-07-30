import 'package:flutter/material.dart';
import 'package:invisitactoe/screens/bot_player.dart';
import 'package:invisitactoe/screens/two_player.dart';
import 'package:flutter/services.dart';
class HomePage extends StatelessWidget {
    final String title; // Add this line to declare the title parameter

  const HomePage({required this.title}); // Constructor that accepts the title
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(10.0),
              child: Text('TicTacToe with a twist! The tiles become invisible after you make your move so you\'ll have to remember the grid! If you try to make a move on an occupied tile you\'ll lose your turn, so beware!'),
            ),
            ElevatedButton(
              onPressed: (){
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (context) => TwoPlayerPage()),); // Navigate to bot mode
              },
              child: const Text('2- Player Mode'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (context) => TicTacToePage()),); // Navigate to 2-player mode
              },
              child: Text('Bot Mode'),
            ),
          ],
        ),
      ),
    );
  }
}
