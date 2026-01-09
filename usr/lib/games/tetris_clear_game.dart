import 'dart:async';
import 'package:flutter/material.dart';

class TetrisClearGame extends StatefulWidget {
  const TetrisClearGame({super.key});

  @override
  State<TetrisClearGame> createState() => _TetrisClearGameState();
}

class _TetrisClearGameState extends State<TetrisClearGame> {
  static const int rows = 20;
  static const int cols = 10;
  
  // Board state: null = empty, Color = filled
  List<List<Color?>> board = List.generate(rows, (_) => List.filled(cols, null));
  
  // Current Piece (I-piece vertical)
  // Relative coordinates: (0,0), (1,0), (2,0), (3,0) -> (row, col)
  final List<Offset> iPiece = [
    const Offset(0, 0),
    const Offset(1, 0),
    const Offset(2, 0),
    const Offset(3, 0),
  ];
  
  Color currentPieceColor = Colors.cyanAccent;
  int pieceRow = 0;
  int pieceCol = 0;
  
  Timer? _timer;
  int score = 0;
  int clears = 0;
  bool isClearing = false;

  @override
  void initState() {
    super.initState();
    resetGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void resetGame() {
    setState(() {
      score = 0;
      clears = 0;
      _resetBoardState();
      _startTimer();
    });
  }

  void _resetBoardState() {
    // Clear board
    board = List.generate(rows, (_) => List.filled(cols, null));
    
    // Fill bottom 4 rows, columns 0-8 (leave col 9 empty)
    for (int r = rows - 4; r < rows; r++) {
      for (int c = 0; c < cols - 1; c++) {
        board[r][c] = Colors.indigo[800];
      }
    }
    
    // Spawn piece
    _spawnPiece();
  }

  void _spawnPiece() {
    pieceRow = -4; // Start just above
    pieceCol = 9; // Aligned with the gap
    isClearing = false;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (isClearing) return;
      _moveDown();
    });
  }

  void _moveDown() {
    setState(() {
      if (_canMove(pieceRow + 1, pieceCol)) {
        pieceRow++;
      } else {
        _lockPiece();
      }
    });
  }

  bool _canMove(int newRow, int newCol) {
    for (var point in iPiece) {
      int r = newRow + point.dx.toInt();
      int c = newCol + point.dy.toInt();

      // Wall collision
      if (c < 0 || c >= cols) return false;
      // Floor collision
      if (r >= rows) return false;
      
      // Board collision
      if (r >= 0 && board[r][c] != null) return false;
    }
    return true;
  }

  void _lockPiece() {
    // Add piece to board
    for (var point in iPiece) {
      int r = pieceRow + point.dx.toInt();
      int c = pieceCol + point.dy.toInt();
      if (r >= 0 && r < rows && c >= 0 && c < cols) {
        board[r][c] = currentPieceColor;
      }
    }

    _checkLines();
  }

  void _checkLines() {
    List<int> linesToClear = [];
    for (int r = 0; r < rows; r++) {
      bool full = true;
      for (int c = 0; c < cols; c++) {
        if (board[r][c] == null) {
          full = false;
          break;
        }
      }
      if (full) linesToClear.add(r);
    }

    if (linesToClear.isNotEmpty) {
      setState(() {
        score += linesToClear.length * 100;
        clears++;
        isClearing = true;
      });

      // Delay to show the full lines, then reset
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() {
          // Flash effect or just clear
          // For this game, we reset the scenario
          _resetBoardState();
        });
      });
    } else {
      // If missed the hole or something, just reset the piece or game?
      // Let's just spawn a new piece. If it stacks up, it stacks up.
      // But eventually we want to reset if they fail too much.
      _spawnPiece();
      if (!_canMove(pieceRow, pieceCol)) {
        // Game Over / Reset
        _resetBoardState();
      }
    }
  }

  void _hardDrop() {
    if (isClearing) return;
    setState(() {
      while (_canMove(pieceRow + 1, pieceCol)) {
        pieceRow++;
      }
      _lockPiece();
    });
  }

  void _moveLeft() {
    if (isClearing) return;
    setState(() {
      if (_canMove(pieceRow, pieceCol - 1)) {
        pieceCol--;
      }
    });
  }

  void _moveRight() {
    if (isClearing) return;
    setState(() {
      if (_canMove(pieceRow, pieceCol + 1)) {
        pieceCol++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Tetris Clear'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Score / Stats
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('SCORE', '$score'),
                _buildStat('CLEARS', '$clears'),
              ],
            ),
          ),
          
          // Game Board
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: cols / rows,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    color: Colors.black87,
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows * cols,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                    ),
                    itemBuilder: (context, index) {
                      int r = index ~/ cols;
                      int c = index % cols;
                      
                      Color? color = board[r][c];
                      
                      // Draw active piece
                      if (!isClearing) {
                        for (var point in iPiece) {
                          int pr = pieceRow + point.dx.toInt();
                          int pc = pieceCol + point.dy.toInt();
                          if (pr == r && pc == c) {
                            color = currentPieceColor;
                          }
                        }
                      }

                      if (color == null) {
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white10, width: 0.5),
                          ),
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: 2,
                              spreadRadius: 0,
                            )
                          ]
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          
          // Controls
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(Icons.arrow_back, _moveLeft),
                _buildControlButton(Icons.arrow_downward, _hardDrop, size: 72, color: Colors.cyanAccent),
                _buildControlButton(Icons.arrow_forward, _moveRight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed, {double size = 56, Color color = Colors.white}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}
