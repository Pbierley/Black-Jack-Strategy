import 'package:flutter/material.dart';
import 'dart:math';

// ---------------------------------------------------------------------------
// Card model
// ---------------------------------------------------------------------------

enum Suit { hearts, diamonds, clubs, spades }

enum Rank {
  two, three, four, five, six, seven, eight, nine, ten,
  jack, queen, king, ace,
}

extension RankInfo on Rank {
  /// Standard blackjack value. Ace returns 11 — soft/hard adjustment
  /// happens in handValue(), not here.
  int get blackjackValue {
    switch (this) {
      case Rank.jack:
      case Rank.queen:
      case Rank.king:
        return 10;
      case Rank.ace:
        return 11;
      default:
        return index + 2; // two=0 -> 2, three=1 -> 3, ...
    }
  }

  /// Hi-Lo running-count value: +1 for 2-6, 0 for 7-9, -1 for 10/face/ace.
  int get hiLoValue {
    final v = blackjackValue;
    if (v >= 2 && v <= 6) return 1;
    if (v >= 7 && v <= 9) return 0;
    return -1;
  }

  String get label {
    switch (this) {
      case Rank.jack: return 'J';
      case Rank.queen: return 'Q';
      case Rank.king: return 'K';
      case Rank.ace: return 'A';
      default: return (index + 2).toString();
    }
  }
}

extension SuitInfo on Suit {
  String get symbol {
    switch (this) {
      case Suit.hearts: return '♥';
      case Suit.diamonds: return '♦';
      case Suit.clubs: return '♣';
      case Suit.spades: return '♠';
    }
  }
}

class PlayingCard {
  final Rank rank;
  final Suit suit;
  const PlayingCard(this.rank, this.suit);

  String get text => '${rank.label}${suit.symbol}';

  @override
  String toString() => text;
}

// ---------------------------------------------------------------------------
// Shoe model — tracks what's left as cards are dealt
// ---------------------------------------------------------------------------

class Shoe {
  final int numDecks;
  final Random _rng;

  final List<PlayingCard> _cards = []; // still in the shoe
  final List<PlayingCard> _dealt = []; // discard tray
  int _runningCount = 0;

  Shoe({this.numDecks = 6, Random? random}) : _rng = random ?? Random() {
    _build();
  }

  void _build() {
    _cards.clear();
    _dealt.clear();
    _runningCount = 0;
    for (var d = 0; d < numDecks; d++) {
      for (final suit in Suit.values) {
        for (final rank in Rank.values) {
          _cards.add(PlayingCard(rank, suit));
        }
      }
    }
    _cards.shuffle(_rng);
  }

  int get totalCards => numDecks * 52;
  int get cardsRemaining => _cards.length;
  int get cardsDealt => _dealt.length;
  double get decksRemaining => cardsRemaining / 52;
  int get runningCount => _runningCount;
  double get trueCount => decksRemaining <= 0 ? 0 : _runningCount / decksRemaining;

  PlayingCard drawCard() {
    if (_cards.isEmpty) {
      throw StateError('Shoe is empty — reshuffle before drawing again.');
    }
    final card = _cards.removeLast();
    _dealt.add(card);
    _runningCount += card.rank.hiLoValue;
    return card;
  }

  double get penetration => cardsDealt / totalCards;

  bool needsReshuffle({double targetPenetration = 0.75}) =>
      penetration >= targetPenetration;

  void reshuffle() => _build();
}

/// Standard blackjack hand total, treating aces as 11 unless that busts,
/// in which case they drop to 1 one at a time.
int handValue(List<PlayingCard> hand) {
  int total = 0;
  int aces = 0;
  for (final c in hand) {
    total += c.rank.blackjackValue;
    if (c.rank == Rank.ace) aces++;
  }
  while (total > 21 && aces > 0) {
    total -= 10;
    aces--;
  }
  return total;
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: AppBar(
            title: const Text("NKU Blackjack Trainer"),
            backgroundColor: Colors.blue,
          ),
        ),
        body: const BlackjackTable(),
      ),
    ),
  );
}

enum HandStatus { idle, playerTurn, dealerTurn, roundOver }

class BlackjackTable extends StatefulWidget {
  const BlackjackTable({super.key});

  @override
  State<BlackjackTable> createState() => _BlackjackTableState();
}

class _BlackjackTableState extends State<BlackjackTable> {
  final Shoe shoe = Shoe(numDecks: 6);

  List<PlayingCard> playerHand = [];
  List<PlayingCard> dealerHand = [];
  HandStatus status = HandStatus.idle;
  String message = 'Press Deal to start a hand.';

  void _deal() {
    if (shoe.needsReshuffle()) {
      shoe.reshuffle();
    }
    setState(() {
      playerHand = [shoe.drawCard(), shoe.drawCard()];
      dealerHand = [shoe.drawCard(), shoe.drawCard()];
      status = HandStatus.playerTurn;
      message = 'Your move — Hit or Stand.';

      if (handValue(playerHand) == 21) {
        _finishRound(blackjack: true);
      }
    });
  }

  void _hit() {
    if (status != HandStatus.playerTurn) return;
    setState(() {
      playerHand.add(shoe.drawCard());
      if (handValue(playerHand) > 21) {
        message = 'Bust! You went over 21.';
        status = HandStatus.roundOver;
      }
    });
  }

  void _stand() {
    if (status != HandStatus.playerTurn) return;
    setState(() {
      status = HandStatus.dealerTurn;
    });
    _playDealer();
  }

  void _playDealer() {
    // Dealer hits until 17 or higher (stands on soft 17).
    while (handValue(dealerHand) < 17) {
      dealerHand.add(shoe.drawCard());
    }
    setState(() {
      _finishRound();
    });
  }

  void _finishRound({bool blackjack = false}) {
    status = HandStatus.roundOver;
    final playerTotal = handValue(playerHand);
    final dealerTotal = handValue(dealerHand);

    if (blackjack) {
      message = 'Blackjack! You win.';
    } else if (playerTotal > 21) {
      message = 'Bust! You went over 21. Dealer wins.';
    } else if (dealerTotal > 21) {
      message = 'Dealer busts! You win.';
    } else if (dealerTotal > playerTotal) {
      message = 'Dealer wins, $dealerTotal to $playerTotal.';
    } else if (playerTotal > dealerTotal) {
      message = 'You win, $playerTotal to $dealerTotal.';
    } else {
      message = 'Push — both have $playerTotal.';
    }
  }

  String _cardListText(List<PlayingCard> hand) =>
      hand.map((c) => c.text).join('  ');

  @override
  Widget build(BuildContext context) {
    final showDealerHole = status == HandStatus.playerTurn;
    final dealerText = showDealerHole
        ? '${dealerHand.isNotEmpty ? dealerHand[0].text : ''}  ??'
        : _cardListText(dealerHand);
    final dealerTotalText =
    showDealerHole ? '${dealerHand.isNotEmpty ? dealerHand[0].rank.blackjackValue : 0} + ?' : '${handValue(dealerHand)}';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dealer
          Text('Dealer', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(dealerHand.isEmpty ? '—' : dealerText,
              style: const TextStyle(fontSize: 22)),
          Text('Total: $dealerTotalText'),

          const Divider(height: 32),

          // Player
          Text('Your Hand', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(playerHand.isEmpty ? '—' : _cardListText(playerHand),
              style: const TextStyle(fontSize: 22)),
          Text('Total: ${playerHand.isEmpty ? 0 : handValue(playerHand)}'),

          const Divider(height: 32),

          // Status / message
          Text(message,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

          const SizedBox(height: 16),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: status == HandStatus.playerTurn ? null : _deal,
                child: const Text('Deal'),
              ),
              ElevatedButton(
                onPressed: status == HandStatus.playerTurn ? _hit : null,
                child: const Text('Hit'),
              ),
              ElevatedButton(
                onPressed: status == HandStatus.playerTurn ? _stand : null,
                child: const Text('Stand'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Shoe info — handy while you're testing the counting logic
          Text(
            'Cards remaining in shoe: ${shoe.cardsRemaining} / ${shoe.totalCards}',
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            'Running count: ${shoe.runningCount}   True count: ${shoe.trueCount.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}