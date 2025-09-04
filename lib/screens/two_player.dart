import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:invisitactoe/widgets/paper_button.dart';

class TwoPlayerPage extends StatefulWidget {
  final String title = 'Two Player Mode';

  @override
  State<TwoPlayerPage> createState() => _TwoPlayerPageState();
}

class _TwoPlayerPageState extends State<TwoPlayerPage> {
  // Game logic and state variables
  List<String> buttonStates = List.generate(9, (index) => '');
  String currentPlayer = 'X';
  bool gameEnded = false;

  // UI state variables
  double opacity = 1;
  int textVisibleDuration = 500;
  double turnMessageOpacity = 1.0;
  List<double> tileOpacities = List.generate(9, (index) => 0.0);
  List<String?> tileImages = List.generate(9, (index) => null);

  final winningCombinations = const [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  // Lists of image paths for the handwritten X's and O's
  final List<String> xImages = [
    'assets/images/x1.png',
    'assets/images/x2.png',
    'assets/images/x3.png',
    'assets/images/x4.png',
    'assets/images/x5.png',
  ];
  final List<String> oImages = [
    'assets/images/o1.png',
    'assets/images/o2.png',
    'assets/images/o3.png',
    'assets/images/o4.png',
  ];

  // Lists of sound paths for the scribbling sounds
  final List<String> xSounds = [
    'audio/x_scribble_1.wav',
    'audio/x_scribble_2.wav',
  ];
  final List<String> oSounds = [
    'audio/o_scribble_1.wav',
    'audio/o_scribble_2.wav',
  ];

  // Random number generator for selecting images and sounds
  final Random _random = Random();
  
  // A variable to hold the image path for the game status message
  String? statusImagePath;
  String? statusTextMessage;

  // Method to play X sound with new AudioPlayer instance
  void _playXSound() async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource(xSounds[_random.nextInt(xSounds.length)]));
      // Dispose after a reasonable delay
      Timer(const Duration(seconds: 2), () {
        player.dispose();
      });
    } catch (e) {
      print('Error playing X sound: $e');
    }
  }

  // Method to play O sound with new AudioPlayer instance
  void _playOSound() async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource(oSounds[_random.nextInt(oSounds.length)]));
      // Dispose after a reasonable delay
      Timer(const Duration(seconds: 2), () {
        player.dispose();
      });
    } catch (e) {
      print('Error playing O sound: $e');
    }
  }

  void buttonPress(int index) {
    setState(() {
      opacity = 1;
      statusImagePath = null;
      statusTextMessage = null;
      if (gameEnded) {
        HapticFeedback.vibrate();
        return;
      }
      // If the game has ended or the tile is already taken, this is an invalid move.
      if (gameEnded || buttonStates[index] != '') {
        // An invalid move was made (on an occupied tile)
        HapticFeedback.vibrate();
        statusImagePath = currentPlayer == 'X'
            ? 'assets/images/invalid_move_x_loses_a_turn.png'
            : 'assets/images/invalid_move_o_loses_a_turn.png';
        turnMessageOpacity = 0.0;
        // Reset the opacity for the message to be visible
        opacity = 1;
        // Start the timer to fade the message
        Timer(Duration(milliseconds: textVisibleDuration), () {
          if (!mounted) return;
          setState(() {
            opacity = 0;
            // After the invalid move message fades, show the next player's turn message
            turnMessageOpacity = 1.0;
          });
        });
        
        // Switch to the next player's turn as a result of the invalid move
        currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
        return;
      }

      // Play the appropriate sound for the current player
      if (currentPlayer == 'X') {
        _playXSound();
      } else {
        _playOSound();
      }

      // A valid move was made
      buttonStates[index] = currentPlayer;
      
      // Set the image and opacity for the tapped tile
      tileOpacities[index] = 1.0;
      tileImages[index] = currentPlayer == 'X'
          ? xImages[_random.nextInt(xImages.length)]
          : oImages[_random.nextInt(oImages.length)];

      // NEW: fade this tile after ~0.5s
      Timer(const Duration(milliseconds: 500), () {
        if (!mounted || gameEnded) return;
        setState(() {
          tileOpacities[index] = 0.0;
        });
      });

      // Check for a win or a draw immediately after the move
      bool isWin = checkWin();
      bool isDraw = isBoardFull(buttonStates);
      
      if (isWin) {
        statusImagePath = currentPlayer == 'X'
            ? 'assets/images/x_wins_o_loses.png'
            : 'assets/images/o_wins_x_loses.png';
        gameEnded = true;
        turnMessageOpacity = 0.0;
        // Reveal the entire board on a win
        for (int i = 0; i < tileOpacities.length; i++) {
          tileOpacities[i] = 1.0;
        }
      } else if (isDraw) {
        statusImagePath = 'assets/images/its_a_draw.png';
        gameEnded = true;
        turnMessageOpacity = 0.0;
        // Reveal the entire board on a draw
        for (int i = 0; i < tileOpacities.length; i++) {
          tileOpacities[i] = 1.0;
        }
      } else {
        // If the game is still in progress, switch to the next player's turn
        currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
      }
    });
  }

  bool checkWin() {
    for (final combination in winningCombinations) {
      if (buttonStates[combination[0]] != '' &&
          buttonStates[combination[0]] == buttonStates[combination[1]] &&
          buttonStates[combination[1]] == buttonStates[combination[2]]) {
        return true;
      }
    }
    return false;
  }

  bool isBoardFull(List<String> board) {
    return !board.any((cell) => cell == '');
  }

  void resetGame() {
    setState(() {
      buttonStates = List.generate(9, (index) => '');
      currentPlayer = 'X';
      gameEnded = false;
      tileOpacities = List.generate(9, (index) => 0.0);
      tileImages = List.generate(9, (index) => null);
      statusImagePath = null;
      statusTextMessage = null;
      turnMessageOpacity = 1.0; // Reset the turn message opacity
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get the size of the screen to make the board responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth * 0.90; // Set board to 90% of screen width
    final tileSize = boardSize / 3;
    final safeTop = MediaQuery.of(context).padding.top;
    return Stack(
      children: <Widget>[
        // Layer 1: The full-screen background image (shared Hero)
        const Positioned.fill(
          child: Hero(
            tag: '__notebook_bg__',
            child: Image(
              image: AssetImage('assets/images/notebook_bg.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),

        Positioned(
          top: safeTop + 12,
          left: 25,
          child: PaperButton(
            onTap: () => Navigator.pop(context),
            child: Image.asset(
              'assets/images/back_arrow_handwritten.png', 
              width: 40,  // adjust size as needed
              height: 40,
            ),
          ),
        ),

        // Layer 2: The game content, centered on the screen
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(height: screenWidth * 0.04),
              // The animated turn message
              AnimatedOpacity(
                opacity: turnMessageOpacity,
                duration: const Duration(milliseconds: 750),
                curve: Curves.easeIn,
                child: Image.asset(
                  // Use specific images for X's and O's turn
                  currentPlayer == 'X'
                      ? 'assets/images/your_move_x.png'
                      : 'assets/images/your_move_o.png',
                  height: screenWidth * 0.08,
                ),
              ),
              SizedBox(height: screenWidth * 0.04),
              // The animated game status message
              AnimatedOpacity(
                opacity: opacity,
                duration: Duration(milliseconds: textVisibleDuration * 2),
                curve: Curves.ease,
                child: statusImagePath != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Image.asset(
                          statusImagePath!,
                          height: screenWidth * 0.08,
                        ),
                      )
                    : statusTextMessage != null
                        ? Text(statusTextMessage!)
                        : Container(height: screenWidth * 0.08),
              ),
              SizedBox(height: screenWidth * 0.04),
              // The main game board stack
              Stack(
                alignment: Alignment.center,
                children: [
                  // Layer 2: The square grid overlay
                  Image.asset(
                    'assets/images/grid.png',
                    width: boardSize,
                    height: boardSize,
                  ),
                  
                  // Layer 3: The 9 transparent tappable areas and the X/O images
                  SizedBox(
                    width: boardSize,
                    height: boardSize,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(), //  stop scrolling
                      primary: false,                               //  don't try to be the primary scrollable
                      padding: EdgeInsets.zero,  
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                      ),
                      itemCount: 9,
                      itemBuilder: (context, index) {
                        // Transparent button on top of each grid square
                        return GestureDetector(
                          onTap: gameEnded ? null : () => buttonPress(index),
                          // The transparent container gives the GestureDetector a solid hit area
                          child: Container(
                            color: Colors.transparent,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Display the X or O image if a move has been made
                                if (tileImages[index] != null)
                                  AnimatedOpacity(
                                    opacity: tileOpacities[index],
                                    duration: Duration(milliseconds: textVisibleDuration),
                                    child: Image.asset(
                                      tileImages[index]!,
                                      width: tileSize * 0.3, // Adjust size to fit in the box
                                      height: tileSize * 0.3,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenWidth * 0.04),
              PaperButton(
                onTap: resetGame,
                child: Image.asset(
                  'assets/images/reset.png',
                  height: screenWidth * 0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}