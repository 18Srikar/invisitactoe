import 'package:flutter/material.dart';
import 'dart:async';
class TwoPlayerPage extends StatefulWidget {
    final String title='2 Player Mode';
  @override
  State<TwoPlayerPage> createState() => _TwoPlayerPageState();
}

class _TwoPlayerPageState extends State<TwoPlayerPage> {
List<String> buttonStates = List.generate(9, (index) => '');
String currentPlayer = 'X';
String gameStatus = ''; 
bool currentPlayerTurn = true; 
bool gameEnded = false;

double opacity = 1;
int textVisibleDuration = 500;

void buttonpress(int index) {
  setState(() {
    opacity=1;
    gameStatus = '';
    if (buttonStates[index] == '') {
      buttonStates[index] = currentPlayer;
      currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
      if (checkWin()) {
        gameStatus = '$currentPlayer loses! 😹😹 ';
        gameEnded=true;
      } else if (buttonStates.every((element) => element != '')) {
        gameStatus = 'It\'s a draw!';
        gameEnded=true;
      }
    } 
    else{
      currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
      gameStatus= 'Haha! Missed a turn 😹😹';
    }
  });
Timer(Duration(milliseconds: textVisibleDuration), () {
    setState(() {
      opacity = 0;
    });
  });
}


  bool checkWin() {
    final winningCombinations = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];

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
      currentPlayer = 'X';
      gameStatus = '';
      gameEnded=false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:const Text('InvisiTacToe')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text('Your move, $currentPlayer ...'),
          Text(gameStatus),
          const Padding(padding: EdgeInsets.all(30)),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              children: List.generate(9, (index) {
                return ElevatedButton(
                  onPressed: gameEnded ? null :() => buttonpress(index),
                  style: ElevatedButton.styleFrom(shape: const BeveledRectangleBorder(borderRadius: BorderRadius.zero)),
                  child: AnimatedOpacity(opacity: opacity, duration: Duration(milliseconds: textVisibleDuration),curve: Curves.ease,child: Text(buttonStates[index]),),
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
