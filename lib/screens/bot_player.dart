import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:invisitactoe/widgets/paper_button.dart';

enum Player { human, ai }

class TicTacToePage extends StatefulWidget {
  final String title = 'Tic Tac Toe';

  @override
  _TicTacToePageState createState() => _TicTacToePageState();
}

class _TicTacToePageState extends State<TicTacToePage> {
  // Game logic and state variables
  List<String> buttonStates = List.generate(9, (index) => '');
  Player currentPlayer = Player.human;
  String gameStatus = '';
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
      gameStatus = '';

      // If the game has ended or it's not the human's turn, do nothing
      if (gameEnded || currentPlayer == Player.ai) {
        return;
      }

      // An invalid move was made (on an occupied tile)
      if (buttonStates[index] != '') {
        HapticFeedback.vibrate();
        // Since X is the human player, the 'X loses a turn' image is used.
        statusImagePath = 'assets/images/invalid_move_x_loses_a_turn.png';
        // Start the timer to fade the message
        Timer(Duration(milliseconds: textVisibleDuration), () {
          if (!mounted) return;
          setState(() {
            opacity = 0;
          });
        });
        // Change the current player and call the AI to make a move.
        currentPlayer = Player.ai;
        aiMove();
        return;
      }

      // Play X sound with new method
      _playXSound();

      // A valid human move was made
      buttonStates[index] = 'X';

      // Set the image and opacity for the tapped tile
      tileOpacities[index] = 1.0;
      tileImages[index] = xImages[_random.nextInt(xImages.length)];

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
        statusImagePath = 'assets/images/x_wins_o_loses.png';
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
        // Switch to the AI's turn
        currentPlayer = Player.ai;
        aiMove();
      }
    });
  }

  void aiMove() async {
    // A small delay to make the AI move feel more natural
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      // Play O sound with new method
      _playOSound();

      int bestMove = minimax(buttonStates, Player.ai, 0);
      buttonStates[bestMove] = 'O';

      // Set the image and opacity for the AI's move
      tileOpacities[bestMove] = 1.0;
      tileImages[bestMove] = oImages[_random.nextInt(oImages.length)];

      // NEW: fade this tile after ~0.5s
      Timer(const Duration(milliseconds: 500), () {
        if (!mounted || gameEnded) return;
        setState(() {
          tileOpacities[bestMove] = 0.0;
        });
      });

      bool isWin = checkWin();
      bool isDraw = isBoardFull(buttonStates);

      if (isWin) {
        statusImagePath = 'assets/images/o_wins_x_loses.png';
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
        // Switch back to the human's turn
        currentPlayer = Player.human;
      }
    });
  }

  // Minimax algorithm
  int minimax(List<String> board, Player player, int depth) {
    if (checkWin()) {
      return player == Player.ai ? -10 + depth : 10 - depth; // Depth helps minimize/optimize move depth
    } else if (isBoardFull(board)) {
      return 0; // Draw
    }

    int bestScore = player == Player.ai ? -9999 : 9999;
    int bestMove = -1;

    for (int i = 0; i < board.length; i++) {
      if (board[i] == '') {
        board[i] = player == Player.ai ? 'O' : 'X';
        int score = minimax(board, player == Player.ai ? Player.human : Player.ai, depth + 1);
        board[i] = ''; // Undo the move

        if (player == Player.ai) {
          if (score > bestScore) {
            bestScore = score;
            bestMove = i;
          }
        } else {
          if (score < bestScore) {
            bestScore = score;
            bestMove = i;
          }
        }
      }
    }
    return depth == 0 ? bestMove : bestScore;
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
      currentPlayer = Player.human;
      gameStatus = '';
      gameEnded = false;
      tileOpacities = List.generate(9, (index) => 0.0);
      tileImages = List.generate(9, (index) => null);
      statusImagePath = null;
      turnMessageOpacity = 1.0; // Reset the turn message opacity
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get the size of the screen to make the board responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final boardSize = screenWidth * 0.9; // Set board to 90% of screen width
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

        // Handwritten back arrow
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
              Image.asset(
                'assets/images/the_only_way_to_win.png',
                height: screenWidth * 0.2,
              ),
              SizedBox(height: screenWidth * 0.05),

              // The animated turn message
              AnimatedOpacity(
                opacity: turnMessageOpacity,
                duration: const Duration(milliseconds: 750),
                curve: Curves.easeIn,
                child: Image.asset(
                  currentPlayer == Player.human
                      ? 'assets/images/your_move.png'
                      : 'assets/images/my_move.png',
                  height: screenWidth * 0.09,
                ),
              ),
              SizedBox(height: screenWidth * 0.03),

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
                      physics: const NeverScrollableScrollPhysics(), // stop scrolling
                      primary: false, // don't try to be the primary scrollable
                      padding: EdgeInsets.zero,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                      ),
                      itemCount: 9,
                      itemBuilder: (context, index) {
                        // Transparent button on top of each grid square
                        return GestureDetector(
                          onTap: gameEnded || currentPlayer == Player.ai
                              ? null
                              : () => buttonPress(index),
                          child: Container(
                            color: Colors.transparent,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Display the X or O image if a move has been made
                                if (tileImages[index] != null)
                                  AnimatedOpacity(
                                    opacity: tileOpacities[index],
                                    duration:
                                        Duration(milliseconds: textVisibleDuration),
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

              // Reset button
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