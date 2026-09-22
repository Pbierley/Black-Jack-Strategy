import 'package:flutter/material.dart';
import 'dart:math';
import 'package:playing_cards/playing_cards.dart' as pcw;

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

  /// Maps this app's Rank onto the playing_cards package's CardValue enum.
  pcw.CardValue get pkgValue {
    switch (this) {
      case Rank.two: return pcw.CardValue.two;
      case Rank.three: return pcw.CardValue.three;
      case Rank.four: return pcw.CardValue.four;
      case Rank.five: return pcw.CardValue.five;
      case Rank.six: return pcw.CardValue.six;
      case Rank.seven: return pcw.CardValue.seven;
      case Rank.eight: return pcw.CardValue.eight;
      case Rank.nine: return pcw.CardValue.nine;
      case Rank.ten: return pcw.CardValue.ten;
      case Rank.jack: return pcw.CardValue.jack;
      case Rank.queen: return pcw.CardValue.queen;
      case Rank.king: return pcw.CardValue.king;
      case Rank.ace: return pcw.CardValue.ace;
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

  /// Maps this app's Suit onto the playing_cards package's Suit enum.
  pcw.Suit get pkgSuit {
    switch (this) {
      case Suit.hearts: return pcw.Suit.hearts;
      case Suit.diamonds: return pcw.Suit.diamonds;
      case Suit.clubs: return pcw.Suit.clubs;
      case Suit.spades: return pcw.Suit.spades;
    }
  }
}

class PlayingCard {
  final Rank rank;
  final Suit suit;
  const PlayingCard(this.rank, this.suit);

  String get text => '${rank.label}${suit.symbol}';

  /// This card as the playing_cards package's own PlayingCard type, so it
  /// can be handed straight to a pcw.PlayingCardView.
  pcw.PlayingCard get pkgCard => pcw.PlayingCard(suit.pkgSuit, rank.pkgValue);

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

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: AppBar(
            title: Text("NKU Blackjack Trainer"),
            backgroundColor: Colors.blue,
          ),
        ),
        body: BlackjackTable(),
      ),
    ),
  );
}

/// betting     -> choosing a bet, waiting to press Deal
/// playerTurn  -> one of the player's hands is awaiting an action
/// dealerTurn  -> dealer is resolving (transient)
/// gameOver    -> bankroll fell below the minimum bet; must Restart
enum GamePhase { betting, playerTurn, dealerTurn, gameOver }

class BlackjackTable extends StatefulWidget {
  const BlackjackTable({super.key});

  @override
  State<BlackjackTable> createState() => _BlackjackTableState();
}

class _BlackjackTableState extends State<BlackjackTable> {
  static const int startingBankroll = 100;
  static const int minBet = 1;
  static const int maxHandsFromSplits = 4; // cap re-splitting

  Shoe shoe = Shoe(numDecks: 6);

  List<PlayerHand> playerHands = [];
  int activeHandIndex = 0;
  List<PlayingCard> dealerHand = [];

  int bankroll = startingBankroll;
  int currentBet = minBet; // adjustable while phase == betting

  GamePhase phase = GamePhase.betting;
  String message = 'Place your bet and press Deal.';

  /// The hand currently awaiting a decision, or null if none (not the
  /// player's turn, or no hands yet).
  PlayerHand? get _activeHand {
    if (phase != GamePhase.playerTurn) return null;
    if (activeHandIndex < 0 || activeHandIndex >= playerHands.length) {
      return null;
    }
    return playerHands[activeHandIndex];
  }

  // --- Betting -------------------------------------------------------

  void _increaseBet() {
    if (phase != GamePhase.betting) return;
    if (currentBet < bankroll) {
      setState(() => currentBet++);
    }
  }

  void _decreaseBet() {
    if (phase != GamePhase.betting) return;
    if (currentBet > minBet) {
      setState(() => currentBet--);
    }
  }

  // --- Round flow ------------------------------------------------------

  void _deal() {
    if (phase != GamePhase.betting) return;
    if (bankroll < currentBet || bankroll < minBet) return;

    if (shoe.needsReshuffle()) {
      shoe.reshuffle();
    }

    setState(() {
      final wager = currentBet;
      bankroll -= wager;
      playerHands = [PlayerHand([shoe.drawCard(), shoe.drawCard()], wager)];
      activeHandIndex = 0;
      dealerHand = [shoe.drawCard(), shoe.drawCard()];
      phase = GamePhase.playerTurn;
      message = 'Your move — Hit, Stand, Double, or Split.';

      // A natural blackjack (either side) ends the round immediately,
      // without the dealer drawing further cards.
      if (playerHands[0].total == 21 || handValue(dealerHand) == 21) {
        playerHands[0].finished = true;
        _finishRound();
      }
    });
  }

  void _hit() {
    final hand = _activeHand;
    if (hand == null) return;
    setState(() {
      hand.cards.add(shoe.drawCard());
      if (hand.total >= 21) {
        hand.finished = true;
        _advanceOrGoToDealer();
      }
    });
    if (phase == GamePhase.dealerTurn) _playDealer();
  }

  void _stand() {
    final hand = _activeHand;
    if (hand == null) return;
    setState(() {
      hand.finished = true;
      _advanceOrGoToDealer();
    });
    if (phase == GamePhase.dealerTurn) _playDealer();
  }

  /// Double down: only on the initial two cards, and only if bankroll
  /// can cover matching that hand's wager. Draws exactly one card, then
  /// forces that hand to stand.
  void _double() {
    final hand = _activeHand;
    if (hand == null) return;
    if (hand.cards.length != 2 || bankroll < hand.wager) return;

    setState(() {
      bankroll -= hand.wager;
      hand.wager *= 2;
      hand.cards.add(shoe.drawCard());
      hand.finished = true;
      _advanceOrGoToDealer();
    });
    if (phase == GamePhase.dealerTurn) _playDealer();
  }

  /// Split: only on an initial pair of matching *value* (so K-Q, 10-J,
  /// etc. all qualify, not just identical ranks), only if bankroll can
  /// cover matching the wager for the new hand, and capped at
  /// [maxHandsFromSplits] hands. Splitting aces deals each hand exactly
  /// one more card and auto-stands both, per standard house rules.
  void _split() {
    final hand = _activeHand;
    if (hand == null) return;
    final canSplit = hand.cards.length == 2 &&
        hand.cards[0].rank.blackjackValue == hand.cards[1].rank.blackjackValue &&
        bankroll >= hand.wager &&
        playerHands.length < maxHandsFromSplits;
    if (!canSplit) return;

    setState(() {
      final wager = hand.wager;
      bankroll -= wager;

      final firstCard = hand.cards[0];
      final secondCard = hand.cards[1];
      final splittingAces = firstCard.rank == Rank.ace;

      hand.cards = [firstCard, shoe.drawCard()];
      final newHand = PlayerHand([secondCard, shoe.drawCard()], wager);

      if (splittingAces) {
        hand.finished = true;
        newHand.finished = true;
      } else if (hand.total >= 21) {
        hand.finished = true;
      }

      playerHands.insert(activeHandIndex + 1, newHand);

      if (hand.finished) {
        _advanceOrGoToDealer();
      } else {
        message =
        'Hand ${activeHandIndex + 1}: your move — Hit, Stand, Double, or Split.';
      }
    });
    if (phase == GamePhase.dealerTurn) _playDealer();
  }

  // --- Hint ----------------------------------------------------------

  String _actionText(String code, PlayerHand hand) {
    final canDoubleNow = hand.cards.length == 2 && bankroll >= hand.wager;
    switch (code) {
      case 'S':
        return 'Stand';
      case 'D':
        return canDoubleNow ? 'Double Down' : 'Double Down if you can — otherwise Hit';
      case 'Ds':
        return canDoubleNow ? 'Double Down' : 'Double Down if you can — otherwise Stand';
      case 'SPLIT':
        return 'Split';
      case 'SURR':
        return "Surrender if your table offers it — this game doesn't include "
            "surrender, so Hit is the next-best play";
      case 'INS':
        return 'Take insurance';
      case 'H':
      default:
        return 'Hit';
    }
  }

  /// Full hint text for the active hand: flat basic strategy, overridden
  /// by a count-based deviation when the current true count crosses that
  /// deviation's index.
  String _basicStrategyHint(PlayerHand hand, PlayingCard dealerUpcard) {
    final dealerKey =
    dealerUpcard.rank == Rank.ace ? 'A' : dealerUpcard.rank.blackjackValue.toString();
    final tc = shoe.trueCount;
    final lines = <String>[
      'True count: ${tc.toStringAsFixed(1)}',
    ];
    var handled = false;

    // --- Pairs -------------------------------------------------------
    if (hand.cards.length == 2 &&
        hand.cards[0].rank.blackjackValue == hand.cards[1].rank.blackjackValue) {
      final pairValue = hand.cards[0].rank.blackjackValue;

      // Ten-value pairs: flat basic strategy always says don't split, but
      // the count-deviation chart adds a high-count split index.
      if (pairValue == 10) {
        final dev = findDeviation('PAIR10', dealerKey);
        if (dev != null && tc >= dev.threshold) {
          final canSplitNow =
              bankroll >= hand.wager && playerHands.length < maxHandsFromSplits;
          if (canSplitNow) {
            lines.add('Split this pair.');
            lines.add('⚡ Deviation: basic strategy never splits tens, but at '
                'a true count of ${tc.toStringAsFixed(1)} (≥ ${dev.threshold}), '
                'splitting is the stronger play.');
          } else {
            lines.add("The count favors splitting this pair, but you can't "
                "right now (bankroll or split limit) — Stand instead.");
          }
          handled = true;
        }
      }

      if (!handled && basicStrategySplit(pairValue, dealerKey)) {
        final canSplitNow =
            bankroll >= hand.wager && playerHands.length < maxHandsFromSplits;
        if (canSplitNow) {
          lines.add('Split this pair.');
        } else {
          lines.add("Basic strategy says split this pair, but you can't right "
              "now (not enough bankroll, or you've hit the split limit) — "
              "playing it as a regular hand instead:");
          handled = false; // fall through to normal hand evaluation below
        }
        if (canSplitNow) handled = true;
      }
    }

    // --- Regular hand (no split, or split unavailable) ----------------
    if (!handled) {
      final total = hand.total;
      if (total > 21) {
        lines.add('This hand already busted — nothing to decide.');
      } else if (total == 21) {
        lines.add('Stand — you have 21.');
      } else if (isSoftHand(hand.cards)) {
        final other = total - 11;
        lines.add(_actionText(basicStrategySoft(other, dealerKey), hand));
      } else {
        final baseCode = basicStrategyHard(total, dealerKey);
        final dev = findDeviation(total.toString(), dealerKey);
        final deviationTriggered = dev != null &&
            (dev.atOrAbove ? tc >= dev.threshold : tc <= dev.threshold);

        if (deviationTriggered) {
          lines.add(_actionText(dev.action, hand));
          lines.add('⚡ Deviation: flat basic strategy would say '
              '${_actionText(baseCode, hand)} here, but at a true count of '
              '${tc.toStringAsFixed(1)} the correct play changes to '
              '${_actionText(dev.action, hand)}.');
        } else {
          lines.add(_actionText(baseCode, hand));
          if (basicStrategySurrenderNote(total, dealerKey)) {
            lines.add("(Basic strategy calls for Surrender here if your "
                "table offers it — this game doesn't include surrender, so "
                "Hit is the next-best play.)");
          }
          if (dev != null) {
            final needed = dev.atOrAbove
                ? 'rises to ${dev.threshold} or higher'
                : 'drops to ${dev.threshold} or lower';
            lines.add('(Watch the count: this becomes ${_actionText(dev.action, hand)} '
                'if the true count $needed — you\'re at ${tc.toStringAsFixed(1)} now.)');
          }
        }
      }
    }

    // --- Insurance note (independent of the active hand) --------------
    if (dealerKey == 'A') {
      final insDev = findDeviation('INS', 'A');
      final insTriggered = insDev != null && tc >= insDev.threshold;
      if (insTriggered) {
        lines.add('⚡ Deviation: dealer shows an Ace and the true count is '
            '${tc.toStringAsFixed(1)} (≥ ${insDev.threshold}) — basic strategy '
            'says skip insurance, but at this count taking it is profitable.');
      } else {
        lines.add("Dealer shows an Ace — basic strategy says don't take "
            "insurance or even money.");
      }
    }

    return lines.join('\n\n');
  }

  void _showHint() {
    final hand = _activeHand;
    if (hand == null || dealerHand.isEmpty) return;
    final advice = _basicStrategyHint(hand, dealerHand[0]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Basic Strategy Hint'),
        content: SingleChildScrollView(child: Text(advice)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Moves to the next unfinished player hand, or to the dealer's turn
  /// if every hand is done. Must be called from inside setState().
  void _advanceOrGoToDealer() {
    var i = activeHandIndex + 1;
    while (i < playerHands.length && playerHands[i].finished) {
      i++;
    }
    if (i < playerHands.length) {
      activeHandIndex = i;
      message = 'Hand ${i + 1}: your move — Hit, Stand, Double, or Split.';
    } else {
      phase = GamePhase.dealerTurn;
    }
  }

  void _playDealer() {
    // Only draw further cards if at least one player hand is still live —
    // matches real table play, and avoids needlessly burning shoe cards
    // (and skewing the count) when every hand has already busted.
    final anyLive = playerHands.any((h) => h.total <= 21);
    if (anyLive) {
      while (handValue(dealerHand) < 17) {
        dealerHand.add(shoe.drawCard());
      }
    }
    setState(() {
      _finishRound();
    });
  }

  /// Settles every hand's bet against bankroll and figures out the next
  /// phase. Must be called from inside setState().
  void _finishRound() {
    final dealerTotal = handValue(dealerHand);
    final dealerBlackjack = dealerHand.length == 2 && dealerTotal == 21;
    final onlyOneHand = playerHands.length == 1;
    final lines = <String>[];

    for (var i = 0; i < playerHands.length; i++) {
      final hand = playerHands[i];
      final playerTotal = hand.total;
      // A 21 only counts as a paying "blackjack" on the original two cards
      // when the hand was never split.
      final isNatural = onlyOneHand && hand.cards.length == 2 && playerTotal == 21;
      final label = playerHands.length > 1 ? 'Hand ${i + 1}: ' : '';

      if (isNatural && dealerBlackjack) {
        bankroll += hand.wager;
        lines.add('${label}Push — both blackjack.');
      } else if (isNatural) {
        final winnings = hand.wager + (hand.wager * 3) ~/ 2; // pays 3:2
        bankroll += winnings;
        lines.add('${label}Blackjack! +${winnings - hand.wager}');
      } else if (dealerBlackjack) {
        lines.add('${label}Dealer blackjack. -${hand.wager}');
      } else if (playerTotal > 21) {
        lines.add('${label}Bust. -${hand.wager}');
      } else if (dealerTotal > 21) {
        bankroll += hand.wager * 2;
        lines.add('${label}Dealer busts! +${hand.wager}');
      } else if (dealerTotal > playerTotal) {
        lines.add('${label}Dealer wins $dealerTotal-$playerTotal. -${hand.wager}');
      } else if (playerTotal > dealerTotal) {
        bankroll += hand.wager * 2;
        lines.add('${label}You win $playerTotal-$dealerTotal! +${hand.wager}');
      } else {
        bankroll += hand.wager;
        lines.add('${label}Push at $playerTotal.');
      }
    }

    message = lines.join('\n');

    if (bankroll < minBet) {
      phase = GamePhase.gameOver;
      message += '\nOut of bankroll! Press Restart to play again.';
    } else {
      phase = GamePhase.betting;
      if (currentBet > bankroll) currentBet = bankroll;
    }
  }

  void _restart() {
    setState(() {
      shoe.reshuffle();
      playerHands = [];
      activeHandIndex = 0;
      dealerHand = [];
      bankroll = startingBankroll;
      currentBet = minBet;
      phase = GamePhase.betting;
      message = 'Place your bet and press Deal.';
    });
  }

  // --- UI ----------------------------------------------------------------

  /// Renders a single card face-up using the playing_cards package.
  /// [faceDown] shows the card back instead — used for the dealer's
  /// hidden hole card while the player is still acting.
  Widget _cardImage(PlayingCard card, {double width = 112, bool faceDown = false}) {
    return SizedBox(
      width: width,
      child: pcw.PlayingCardView(
        card: card.pkgCard,
        showBack: faceDown,
      ),
    );
  }

  /// Renders a whole hand as a wrapped row of card widgets. Pass
  /// [hiddenFromIndex] to face-down every card from that index onward
  /// (used for the dealer's hole card); -1 shows everything face-up.
  Widget _cardRow(List<PlayingCard> cards, {int hiddenFromIndex = -1}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < cards.length; i++)
          _cardImage(
            cards[i],
            faceDown: hiddenFromIndex >= 0 && i >= hiddenFromIndex,
          ),
      ],
    );
  }

  List<Widget> _buildPlayerHandWidgets() {
    if (playerHands.isEmpty) {
      return const [Text('—', style: TextStyle(fontSize: 22))];
    }
    return List.generate(playerHands.length, (i) {
      final hand = playerHands[i];
      final isActive = phase == GamePhase.playerTurn && i == activeHandIndex;
      final label = playerHands.length > 1 ? 'Hand ${i + 1}' : 'Your Hand';
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive ? Colors.blue : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label${isActive ? '  (active)' : ''} — Bet: ${hand.wager}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _cardRow(hand.cards),
            ),
            Text('Total: ${hand.total}'),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hideDealerHole = phase == GamePhase.playerTurn;
    final dealerTotalText = hideDealerHole
        ? '${dealerHand.isNotEmpty ? dealerHand[0].rank.blackjackValue : 0} + ?'
        : '${handValue(dealerHand)}';

    final hand = _activeHand;
    final canDeal = phase == GamePhase.betting && bankroll >= currentBet;
    final canBet = phase == GamePhase.betting;
    final canAct = hand != null;
    final canDouble = hand != null && hand.cards.length == 2 && bankroll >= hand.wager;
    final canSplit = hand != null &&
        hand.cards.length == 2 &&
        hand.cards[0].rank.blackjackValue == hand.cards[1].rank.blackjackValue &&
        bankroll >= hand.wager &&
        playerHands.length < maxHandsFromSplits;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bankroll / bet controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bankroll: $bankroll units',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Row(
                  children: [
                    Text('Bet: $currentBet',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: canBet ? _decreaseBet : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: canBet ? _increaseBet : null,
                    ),
                  ],
                ),
              ],
            ),

            const Divider(height: 24),

            // Dealer
            Text('Dealer', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            dealerHand.isEmpty
                ? const Text('—', style: TextStyle(fontSize: 22))
                : Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _cardRow(
                dealerHand,
                hiddenFromIndex: hideDealerHole ? 1 : -1,
              ),
            ),
            Text('Total: $dealerTotalText'),

            const Divider(height: 32),

            // Player hand(s)
            Text('Your Hand${playerHands.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            ..._buildPlayerHandWidgets(),

            const Divider(height: 8),

            // Status / message
            Text(message,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

            const SizedBox(height: 16),

            // Controls
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: canDeal ? _deal : null,
                  child: const Text('Deal'),
                ),
                ElevatedButton(
                  onPressed: canAct ? _hit : null,
                  child: const Text('Hit'),
                ),
                ElevatedButton(
                  onPressed: canAct ? _stand : null,
                  child: const Text('Stand'),
                ),
                ElevatedButton(
                  onPressed: canDouble ? _double : null,
                  child: const Text('Double'),
                ),
                ElevatedButton(
                  onPressed: canSplit ? _split : null,
                  child: const Text('Split'),
                ),
                OutlinedButton.icon(
                  onPressed: canAct ? _showHint : null,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Hint'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Center(
              child: TextButton(
                onPressed: _restart,
                child: const Text('Restart Game'),
              ),
            ),

            const SizedBox(height: 12),

            // Shoe info — handy while you're testing the counting logic
            Text(
              'Cards remaining in shoe: ${shoe.cardsRemaining} / ${shoe.totalCards}',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              'Running count: ${shoe.runningCount}   True count: ${shoe.trueCount.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 24),

            Image.network(
              'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQpYdAyOg0fyY2PH_xrR6jvdtscpG-UUWbGcJXTxP-3yQ&s=10',
            ),
          ],
        ),
      ),
    );
  }
}