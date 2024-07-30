import 'package:flutter/material.dart';
import 'dart:async';


enum Player { human, ai }

class TicTacToePage extends StatefulWidget {
  final String title = 'Tic Tac Toe';

  @override
  _TicTacToePageState createState() => _TicTacToePageState();
}

class _TicTacToePageState extends State<TicTacToePage> {
  List<String> buttonStates = List.generate(9, (index) => '');
  Player currentPlayer = Player.human;
  String gameStatus = '';
  bool gameEnded = false;

  double opacity = 1;
  int textVisibleDuration = 500;

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

  void buttonPress(int index) {

    setState(() {
      opacity = 1;
      gameStatus = '';
      if (buttonStates[index] == '' && !gameEnded) {
        buttonStates[index] = currentPlayer == Player.human ? 'X' : 'O';

        if (checkWin()) {
          gameStatus = '${currentPlayer == Player.human ? 'You' : 'I'} win!';
          gameEnded = true;
        } else if (buttonStates.every((element) => element != '')) {
          gameStatus = 'It\'s a draw, so you win.';
          gameEnded = true;
        } else {
          currentPlayer = currentPlayer == Player.human ? Player.ai : Player.human;
          if (!gameEnded) {
            aiMove();
          }
        }
      } else {
        gameStatus = 'Invalid move!😹😹';
      }
    });
    Timer(Duration(milliseconds: textVisibleDuration), () {
      setState(() {

        opacity = 0;
      });
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

  void resetGame() {
    setState(() {
      buttonStates = List.generate(9, (index) => '');
      currentPlayer = Player.human;
      gameStatus = '';
      gameEnded = false;
    });
  }

void aiMove() async {
  int bestMove = minimax(buttonStates, Player.ai, 0);
  
  await Future.delayed(const Duration(milliseconds: 00));

  setState(() {
    buttonStates[bestMove] = 'O';
    if (checkWin()) {
      gameStatus = 'I win!😹😹';
      gameEnded = true;
    } else if (buttonStates.every((element) => element != '')) {
      gameStatus = 'It\'s a draw, so you win.';
      gameEnded = true;
    } else {
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




  bool isBoardFull(List<String> board) {
    return !board.any((cell) => cell == '');
  }

  List<int> getEmptyCells(List<String> board) {
    return board.asMap().entries.where((entry) => entry.value == '').map((entry) => entry.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('InvisiTacToe')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text('I am Minimax Bot. I play the game optimally, so the best you can get is a draw. Draw the game and I shall count it as your win.'),
          ),
          Text('${currentPlayer == Player.human ? 'Your' : 'My'} move ...'),
          Text(gameStatus),
          const Padding(padding: EdgeInsets.all(30)),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              children: List.generate(9, (index) {
                return ElevatedButton(
                  onPressed: gameEnded ? null : () => buttonPress(index),
                  style: ElevatedButton.styleFrom(shape: const BeveledRectangleBorder(borderRadius: BorderRadius.zero)),
                  child: AnimatedOpacity(
                    opacity: opacity,
                    duration: Duration(milliseconds: textVisibleDuration),
                    curve: Curves.ease,
                    child: Text(buttonStates[index]),
                  ),
                );
              }),
            ),
          ),
          ElevatedButton(onPressed: resetGame, child: const Text('Reset'))
        ],
      ),
    );
  }
}
