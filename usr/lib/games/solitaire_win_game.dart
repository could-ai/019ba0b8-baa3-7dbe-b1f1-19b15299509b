import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SolitaireWinGame extends StatefulWidget {
  const SolitaireWinGame({super.key});

  @override
  State<SolitaireWinGame> createState() => _SolitaireWinGameState();
}

class _SolitaireWinGameState extends State<SolitaireWinGame> with TickerProviderStateMixin {
  // Game State
  bool isWon = false;
  bool isDragging = false;
  
  // The final card (King of Spades)
  Offset kingPosition = const Offset(100, 300); // Initial position on tableau
  final Offset targetPosition = const Offset(280, 50); // Approximate position of 4th foundation
  
  // Animation
  late Ticker _ticker;
  List<BouncingCard> bouncingCards = [];
  int cardSpawnIndex = 0; // 0 to 51 (or however many we spawn)
  double timeSinceLastSpawn = 0;
  
  // Card dimensions
  static const double cardWidth = 70;
  static const double cardHeight = 100;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!isWon) return;

    setState(() {
      // 1. Spawn new cards periodically
      // We want to spawn from the 4 foundation piles in sequence or random
      // Let's spawn one every few frames
      timeSinceLastSpawn += 1;
      if (timeSinceLastSpawn > 5 && cardSpawnIndex < 52) { // Spawn limit
        timeSinceLastSpawn = 0;
        _spawnBouncingCard();
        cardSpawnIndex++;
      }

      // 2. Update physics for all existing cards
      for (var card in bouncingCards) {
        card.update(MediaQuery.of(context).size);
      }
      
      // Remove cards that have settled or gone off screen (optional, but keeps performance up)
      // bouncingCards.removeWhere((c) => c.x > MediaQuery.of(context).size.width + 100);
    });
  }

  void _spawnBouncingCard() {
    // Cycle through the 4 foundation positions
    // Let's assume 4 piles at top right
    // We'll approximate their positions based on screen width
    double screenWidth = MediaQuery.of(context).size.width;
    double startX = screenWidth - 50 - (cardSpawnIndex % 4) * (cardWidth + 10);
    double startY = 60; // Top area

    // Random velocity
    Random rng = Random();
    double vx = (rng.nextDouble() * 10 - 5); // -5 to 5 horizontal
    if (vx.abs() < 2) vx = vx < 0 ? -3 : 3; // Ensure some horizontal movement
    
    // Initial jump
    double vy = - (rng.nextDouble() * 5 + 5); // Upward burst

    // Card Visuals
    // Cycle suits and ranks just for visuals
    int suit = cardSpawnIndex % 4; 
    int rank = 13 - (cardSpawnIndex ~/ 4); // Count down kings to aces roughly
    if (rank < 1) rank = 1;

    bouncingCards.add(BouncingCard(
      x: startX,
      y: startY,
      vx: vx,
      vy: vy,
      suit: suit,
      rank: rank,
    ));
  }

  void _checkWinCondition() {
    // Simple distance check
    double dx = kingPosition.dx - targetPosition.dx;
    double dy = kingPosition.dy - targetPosition.dy;
    double distance = sqrt(dx*dx + dy*dy);

    if (distance < 50) {
      // Snap to target
      setState(() {
        kingPosition = targetPosition;
        isWon = true;
      });
      _ticker.start();
    } else {
      // Reset to initial if dropped elsewhere
      setState(() {
        kingPosition = const Offset(100, 300);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    
    // Calculate foundation positions dynamically
    double foundationY = 60;
    double spacing = 10;
    // 4 piles on the right
    List<Offset> foundations = [];
    for(int i=0; i<4; i++) {
      foundations.add(Offset(size.width - (cardWidth + spacing) * (4-i), foundationY));
    }
    // Update target to the last one (Spades)
    // Actually let's make the last one the target
    Offset finalFoundation = foundations[3]; 
    
    return Scaffold(
      backgroundColor: const Color(0xFF006400), // Classic Green
      appBar: AppBar(
        title: const Text('Solitaire Win'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isWon = false;
                _ticker.stop();
                bouncingCards.clear();
                cardSpawnIndex = 0;
                kingPosition = const Offset(40, 300); // Reset position
              });
            },
          )
        ],
      ),
      body: Stack(
        children: [
          // 1. Foundations (Background)
          ...List.generate(3, (index) {
            return Positioned(
              left: foundations[index].dx,
              top: foundations[index].dy,
              child: _buildCardWidget(13, index, false), // Kings of Hearts, Diamonds, Clubs
            );
          }),
          // The empty/target slot (Queen of Spades underneath)
          Positioned(
            left: finalFoundation.dx,
            top: finalFoundation.dy,
            child: _buildCardWidget(12, 3, false), // Queen of Spades
          ),

          // 2. Tableau / Other piles (Decoration)
          Positioned(
            left: 40,
            top: 60,
            child: _buildEmptySlot(), // Deck pile
          ),
           Positioned(
            left: 130,
            top: 60,
            child: _buildEmptySlot(), // Discard pile
          ),

          // 3. The Bouncing Cards (Animation Layer)
          if (isWon)
            CustomPaint(
              size: Size.infinite,
              painter: BouncingCardsPainter(bouncingCards),
            ),

          // 4. The Draggable King (Interactive)
          if (!isWon)
            Positioned(
              left: kingPosition.dx,
              top: kingPosition.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    kingPosition += details.delta;
                  });
                },
                onPanEnd: (details) {
                  // Check if close to the final foundation
                  double dx = kingPosition.dx - finalFoundation.dx;
                  double dy = kingPosition.dy - finalFoundation.dy;
                  if (sqrt(dx*dx + dy*dy) < 60) {
                    setState(() {
                      kingPosition = finalFoundation;
                      isWon = true;
                    });
                    _ticker.start();
                  } else {
                    // Snap back
                     setState(() {
                      kingPosition = const Offset(40, 300);
                    });
                  }
                },
                child: _buildCardWidget(13, 3, true), // King of Spades
              ),
            ),
            
          // Instructions
          if (!isWon)
            const Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "Drag the King to finish the game!",
                  style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildCardWidget(int rank, int suit, bool shadow) {
    // Suit: 0=Hearts, 1=Diamonds, 2=Clubs, 3=Spades
    Color color = (suit == 0 || suit == 1) ? Colors.red : Colors.black;
    String suitSymbol = ['♥', '♦', '♣', '♠'][suit];
    String rankStr = _getRankString(rank);

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey),
        boxShadow: shadow ? [const BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(4,4))] : [],
      ),
      child: Stack(
        children: [
          // Top Left
          Positioned(
            left: 4,
            top: 4,
            child: Column(
              children: [
                Text(rankStr, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(suitSymbol, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ),
          // Center Big
          Center(
            child: Text(suitSymbol, style: TextStyle(color: color, fontSize: 32)),
          ),
          // Bottom Right (Rotated)
          Positioned(
            right: 4,
            bottom: 4,
            child: Transform.rotate(
              angle: pi,
              child: Column(
                children: [
                  Text(rankStr, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(suitSymbol, style: TextStyle(color: color, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white30, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(Icons.refresh, color: Colors.white10),
      ),
    );
  }

  String _getRankString(int rank) {
    switch (rank) {
      case 1: return 'A';
      case 11: return 'J';
      case 12: return 'Q';
      case 13: return 'K';
      default: return rank.toString();
    }
  }
}

class BouncingCard {
  double x;
  double y;
  double vx;
  double vy;
  int suit;
  int rank;

  BouncingCard({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.suit,
    required this.rank,
  });

  void update(Size screenSize) {
    x += vx;
    y += vy;
    vy += 0.5; // Gravity

    // Floor bounce
    if (y + 100 > screenSize.height) { // 100 is approx card height
      y = screenSize.height - 100;
      vy = -vy * 0.85; // Bounce with energy loss
    }
    
    // Optional: Wall bounce
    // if (x < 0 || x + 70 > screenSize.width) vx = -vx;
  }
}

class BouncingCardsPainter extends CustomPainter {
  final List<BouncingCard> cards;
  
  BouncingCardsPainter(this.cards);

  @override
  void paint(Canvas canvas, Size size) {
    for (var card in cards) {
      _drawCard(canvas, card);
    }
  }

  void _drawCard(Canvas canvas, BouncingCard card) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final rect = Rect.fromLTWH(card.x, card.y, 70, 100);
    
    // Draw Card Body
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);

    // Draw Content
    _drawCardContent(canvas, card.x, card.y, card.rank, card.suit);
  }

  void _drawCardContent(Canvas canvas, double x, double y, int rank, int suit) {
    Color color = (suit == 0 || suit == 1) ? Colors.red : Colors.black;
    String suitSymbol = ['♥', '♦', '♣', '♠'][suit];
    String rankStr = _getRankString(rank);

    final textStyle = TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold);
    final symbolStyle = TextStyle(color: color, fontSize: 12);
    final centerStyle = TextStyle(color: color, fontSize: 32);

    // Helper for text painting
    void drawText(String text, double dx, double dy, TextStyle style) {
      final span = TextSpan(text: text, style: style);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x + dx, y + dy));
    }

    // Top Left
    drawText(rankStr, 5, 5, textStyle);
    drawText(suitSymbol, 5, 20, symbolStyle);

    // Center
    drawText(suitSymbol, 20, 30, centerStyle); // Rough centering
  }

  String _getRankString(int rank) {
    switch (rank) {
      case 1: return 'A';
      case 11: return 'J';
      case 12: return 'Q';
      case 13: return 'K';
      default: return rank.toString();
    }
  }

  @override
  bool shouldRepaint(covariant BouncingCardsPainter oldDelegate) => true;
}
