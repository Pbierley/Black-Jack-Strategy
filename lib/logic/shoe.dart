import 'dart:math';
import 'card.dart';

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

/// True if the hand's total is still counting an ace as 11 (i.e. it's a
/// "soft" hand for basic-strategy purposes).
bool isSoftHand(List<PlayingCard> hand) {
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
  return aces > 0;
}

// ---------------------------------------------------------------------------
// Basic strategy lookup (from the classic Blackjack Apprenticeship chart).
// Dealer upcard key is '2'..'9', '10' (covers 10/J/Q/K), or 'A'.
// Assumes Double After Split is allowed (true in this game).
// Action codes used throughout: 'H' Hit, 'S' Stand, 'D' Double (else Hit),
// 'Ds' Double (else Stand), 'SPLIT', 'SURR' Surrender, 'INS' Insurance.
// ---------------------------------------------------------------------------

/// Pair-splitting table. pairValue is the blackjackValue of each card in
/// the pair (11 for aces, 10 for any ten-value card, else 2-9).
/// Returns true if basic strategy says to split.
bool basicStrategySplit(int pairValue, String dealerKey) {
  switch (pairValue) {
    case 11: // A,A
      return true;
    case 10: // any ten-value pair — never split under flat basic strategy
      return false;
    case 9:
      return !['7', '10', 'A'].contains(dealerKey);
    case 8:
      return true;
    case 7:
      return ['2', '3', '4', '5', '6', '7'].contains(dealerKey);
    case 6:
      return ['2', '3', '4', '5', '6'].contains(dealerKey);
    case 5:
      return false; // play as hard 10 instead
    case 4:
      return ['5', '6'].contains(dealerKey);
    case 3:
    case 2:
      return ['2', '3', '4', '5', '6', '7'].contains(dealerKey);
    default:
      return false;
  }
}

/// Soft-totals table. `other` is the value of the non-ace component
/// (2-9, representing A,2 through A,9). Returns 'H', 'S', 'D', or 'Ds'.
String basicStrategySoft(int other, String dealerKey) {
  bool in2to6(String k) => ['2', '3', '4', '5', '6'].contains(k);
  switch (other) {
    case 2:
    case 3:
      return ['5', '6'].contains(dealerKey) ? 'D' : 'H';
    case 4:
    case 5:
      return ['4', '5', '6'].contains(dealerKey) ? 'D' : 'H';
    case 6:
      return ['3', '4', '5', '6'].contains(dealerKey) ? 'D' : 'H';
    case 7:
      if (in2to6(dealerKey)) return 'Ds';
      if (dealerKey == '7' || dealerKey == '8') return 'S';
      return 'H';
    case 8:
      return dealerKey == '6' ? 'Ds' : 'S';
    default: // 9+ (soft 19 or better)
      return 'S';
  }
}

/// Hard-totals table. Returns 'H', 'S', or 'D'.
String basicStrategyHard(int total, String dealerKey) {
  bool in2to6(String k) => ['2', '3', '4', '5', '6'].contains(k);
  if (total >= 17) return 'S';
  if (total <= 8) return 'H';
  switch (total) {
    case 9:
      return ['3', '4', '5', '6'].contains(dealerKey) ? 'D' : 'H';
    case 10:
      return !['10', 'A'].contains(dealerKey) ? 'D' : 'H';
    case 11:
      return 'D';
    case 12:
      return ['4', '5', '6'].contains(dealerKey) ? 'S' : 'H';
    default: // 13-16
      return in2to6(dealerKey) ? 'S' : 'H';
  }
}

/// True for the hard totals where flat basic strategy calls for a surrender
/// (this game doesn't offer surrender as an action, so it's shown as a note).
bool basicStrategySurrenderNote(int total, String dealerKey) {
  if (total == 16) return ['9', '10', 'A'].contains(dealerKey);
  if (total == 15) return dealerKey == '10';
  return false;
}

// ---------------------------------------------------------------------------
// Count-based deviations from basic strategy (Illustrious-18-style index
// chart). Each entry names the hand it applies to, the dealer upcard, the
// action to deviate TO, the true-count threshold, and whether that
// threshold triggers at-or-above (favorable-count plays: Stand/Double/
// Split/Insurance) or at-or-below (unfavorable-count plays: Hit/Surrender).
// ---------------------------------------------------------------------------

class Deviation {
  final String handKey; // hard total as string, 'PAIR10', or 'INS'
  final String dealerKey;
  final String action; // 'H', 'S', 'D', 'SPLIT', 'SURR', 'INS'
  final double threshold;
  final bool atOrAbove; // true: TC >= threshold, false: TC <= threshold
  const Deviation(this.handKey, this.dealerKey, this.action, this.threshold,
      this.atOrAbove);
}

const List<Deviation> countDeviations = [
  Deviation('INS', 'A', 'INS', 3, true),

  Deviation('16', '8', 'SURR', 4, false),
  Deviation('16', '9', 'SURR', -1, false),
  Deviation('16', '10', 'SURR', -1, false),
  Deviation('16', 'A', 'SURR', 0, false),

  Deviation('15', '8', 'SURR', 7, false),
  Deviation('15', '9', 'SURR', 2, false),
  Deviation('15', '10', 'SURR', 0, false),
  Deviation('15', 'A', 'SURR', 2, false),

  Deviation('14', '9', 'SURR', 7, false),
  Deviation('14', '10', 'SURR', 3, false),
  Deviation('14', 'A', 'SURR', 5, false),

  Deviation('13', '2', 'H', -1, false),
  Deviation('13', '3', 'H', -2, false),
  Deviation('13', '10', 'SURR', 8, false),

  Deviation('12', '2', 'S', 3, true),
  Deviation('12', '3', 'S', 1.5, true),
  Deviation('12', '4', 'H', 0, false),
  Deviation('12', '5', 'H', -2, false),
  Deviation('12', '6', 'H', -1, false),

  Deviation('11', 'A', 'D', 2, true),

  Deviation('10', '10', 'D', 7, true),
  Deviation('10', 'A', 'D', 5, true),

  Deviation('9', '2', 'D', 1.5, true),
  Deviation('9', '7', 'D', 5, true),

  Deviation('PAIR10', '5', 'SPLIT', 6, true),
  Deviation('PAIR10', '6', 'SPLIT', 5, true),
];

/// Finds the deviation index (if any) for a given hand/dealer matchup.
Deviation? findDeviation(String handKey, String dealerKey) {
  for (final d in countDeviations) {
    if (d.handKey == handKey && d.dealerKey == dealerKey) return d;
  }
  return null;
}

/// One of the player's hands. A round starts with exactly one; splitting
/// adds more, each with its own cards and wager.
class PlayerHand {
  List<PlayingCard> cards;
  int wager;
  bool finished; // player is done acting on this hand (stood/bust/doubled/split-aces)

  PlayerHand(this.cards, this.wager) : finished = false;

  int get total => handValue(cards);
}
