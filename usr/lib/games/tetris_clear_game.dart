import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class TetrisClearGame extends StatefulWidget {
  const TetrisClearGame({super.key});

  @override
  State<TetrisClearGame> createState() => _TetrisClearGameState();
}

class _TetrisClearGameState extends State<TetrisClearGame> with TickerProviderStateMixin {
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

  // Animation Controller for clear effects
  late AnimationController _clearController;
  List<int> clearingRows = [];

  @override
  void initState() {
    super.initState();
    
    _clearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _clearController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finalizeClear();
      }
    });

    resetGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clearController.dispose();
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
        // Bonus points for clearing more lines
        int points = linesToClear.length * 100;
        if (linesToClear.length >= 4) points += 400; // Tetris bonus
        
        score += points;
        clears++;
        isClearing = true;
        clearingRows = linesToClear;
      });

      // Trigger the satisfying animation
      _clearController.forward(from: 0.0);
    } else {
      // If missed the hole or something, just reset the piece or game?
      _spawnPiece();
      if (!_canMove(pieceRow, pieceCol)) {
        // Game Over / Reset
        _resetBoardState();
      }
    }
  }

  void _finalizeClear() {
    setState(() {
      isClearing = false;
      clearingRows.clear();
      _resetBoardState();
    });
    _clearController.reset();
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
      body: AnimatedBuilder(
        animation: _clearController,
        builder: (context, child) {
          // Screen Shake Effect
          double offsetX = 0;
          double offsetY = 0;
          if (isClearing) {
            // Shake intensity decays over time
            double shakeAmount = 8.0 * (1.0 - _clearController.value); 
            // Random-ish shake using sine waves
            offsetX = sin(_clearController.value * pi * 30) * shakeAmount;
            offsetY = cos(_clearController.value * pi * 25) * shakeAmount;
          }
          
          return Transform.translate(
            offset: Offset(offsetX, offsetY),
            child: child,
          );
        },
        child: Column(
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
                  child: Stack(
                    children: [
                      // The Grid
                      Container(
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

                            // Special rendering for clearing rows
                            if (isClearing && clearingRows.contains(r)) {
                              return _buildClearingBlock(color ?? Colors.white);
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
                      
                      // "TETRIS!" Text Overlay
                      if (isClearing && clearingRows.length >= 4)
                        Center(
                          child: _buildTetrisText(),
                        ),
                    ],
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
      ),
    );
  }

  Widget _buildClearingBlock(Color color) {
    return AnimatedBuilder(
      animation: _clearController,
      builder: (context, child) {
        double t = _clearController.value;
        
        // Flash white initially
        Color displayColor;
        if (t < 0.15) {
          displayColor = Colors.white;
        } else {
          // Then fade to original or keep white-ish
          displayColor = Color.lerp(Colors.white, color, (t - 0.15) * 2) ?? color;
        }
        
        // Fade out opacity
        double opacity = (1.0 - t).clamp(0.0, 1.0);
        
        return Opacity(
          opacity: opacity,
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: displayColor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: displayColor.withOpacity(0.8),
                  blurRadius: 10 * (1 - t), // Glow shrinks
                  spreadRadius: 2 * (1 - t),
                )
              ]
            ),
          ),
        );
      }
    );
  }

  Widget _buildTetrisText() {
    return AnimatedBuilder(
      animation: _clearController,
      builder: (context, child) {
        double t = _clearController.value;
        // Scale up: 0.5 -> 1.5
        double scale = 0.5 + (t * 1.5); 
        // Fade out near the end
        double opacity = (1.0 - t * 1.2).clamp(0.0, 1.0);
        
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: const Text(
              "TETRIS!",
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 56,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 4,
                shadows: [
                  Shadow(blurRadius: 10, color: Colors.blue, offset: Offset(0,0)),
                  Shadow(blurRadius: 20, color: Colors.white, offset: Offset(0,0)),
                  Shadow(blurRadius: 30, color: Colors.purpleAccent, offset: Offset(0,0)),
                ]
              ),
            ),
          ),
        );
      }
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
