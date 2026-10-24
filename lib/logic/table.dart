import 'package:blackjack/logic/card.dart';
import 'package:blackjack/logic/shoe.dart';
import 'package:blackjack/logic/UI.dart';
import 'package:flutter/material.dart';

/// betting     -> choosing a bet, waiting to press Deal
/// insurance   -> dealer shows an Ace; player decides on insurance before
///                the dealer peeks at the hole card
/// playerTurn  -> one of the player's hands is awaiting an action
/// dealerTurn  -> dealer is resolving (transient)
/// gameOver    -> bankroll fell below the minimum bet; must Restart
enum GamePhase { betting, insurance, playerTurn, dealerTurn, gameOver }

class BlackjackTable extends StatefulWidget {
  const BlackjackTable({super.key});

  @override
  State<BlackjackTable> createState() => _BlackjackTableState();
}

class _BlackjackTableState extends State<BlackjackTable> {
  static const double startingBankroll = 100;
  static const int minBet = 1;
  static const int maxHandsFromSplits = 4; // cap re-splitting

  Shoe shoe = Shoe(numDecks: 6);

  List<PlayerHand> playerHands = [];
  int activeHandIndex = 0;
  List<PlayingCard> dealerHand = [];

  /// Fractional so half-unit insurance and 3:2 blackjack payouts on odd
  /// bets are exact; bets themselves stay in whole units.
  double bankroll = startingBankroll;
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
    if (currentBet + 1 <= bankroll) {
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
      playerHands = [
        PlayerHand([shoe.drawCard(), shoe.drawCard()], wager),
      ];
      activeHandIndex = 0;
      dealerHand = [shoe.drawCard(), shoe.drawCard()];

      // With an Ace showing, insurance is offered before the dealer peeks,
      // so neither side's blackjack is resolved yet.
      if (dealerHand[0].rank == Rank.ace) {
        phase = GamePhase.insurance;
        message =
            'Dealer shows an Ace — take insurance for '
            '${formatUnits(_insuranceCost)}?';
        return;
      }

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

  /// Insurance matches the original wager, paying 2:1 if the dealer has
  /// blackjack.
  double get _insuranceCost =>
      playerHands.isEmpty ? 0 : playerHands[0].wager.toDouble();

  bool get _canInsure =>
      phase == GamePhase.insurance && bankroll >= _insuranceCost;

  /// Settles the insurance decision, then has the dealer peek: a dealer
  /// or player blackjack ends the round, otherwise play continues.
  void _resolveInsurance({required bool take}) {
    if (phase != GamePhase.insurance) return;
    if (take && !_canInsure) return;

    setState(() {
      final cost = _insuranceCost;
      final dealerBlackjack = handValue(dealerHand) == 21;
      String? insuranceLine;
      if (take) {
        bankroll -= cost;
        if (dealerBlackjack) {
          bankroll += cost * 3;
          insuranceLine = 'Insurance pays 2 to 1! +${formatUnits(cost * 2)}';
        } else {
          insuranceLine = 'Insurance lost. -${formatUnits(cost)}';
        }
      }

      if (dealerBlackjack || playerHands[0].total == 21) {
        playerHands[0].finished = true;
        _finishRound();
      } else {
        phase = GamePhase.playerTurn;
        message =
            'Dealer has no blackjack. Your move — Hit, Stand, Double, or Split.';
      }
      if (insuranceLine != null) message = '$insuranceLine\n$message';
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
  /// [maxHandsFromSplits] hands. Split hands, aces included, play on
  /// normally; any that reach 21 stand automatically.
  void _split() {
    final hand = _activeHand;
    if (hand == null) return;
    final canSplit =
        hand.cards.length == 2 &&
        hand.cards[0].rank.blackjackValue ==
            hand.cards[1].rank.blackjackValue &&
        bankroll >= hand.wager &&
        playerHands.length < maxHandsFromSplits;
    if (!canSplit) return;

    setState(() {
      final wager = hand.wager;
      bankroll -= wager;

      final firstCard = hand.cards[0];
      final secondCard = hand.cards[1];

      hand.cards = [firstCard, shoe.drawCard()];
      final newHand = PlayerHand([secondCard, shoe.drawCard()], wager);

      hand.finished = hand.total >= 21;
      newHand.finished = newHand.total >= 21;

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
        return canDoubleNow
            ? 'Double Down'
            : 'Double Down if you can — otherwise Hit';
      case 'Ds':
        return canDoubleNow
            ? 'Double Down'
            : 'Double Down if you can — otherwise Stand';
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
    final dealerKey = dealerUpcard.rank == Rank.ace
        ? 'A'
        : dealerUpcard.rank.blackjackValue.toString();
    final tc = shoe.trueCount;
    final lines = <String>['True count: ${tc.toStringAsFixed(1)}'];
    var handled = false;

    // --- Pairs -------------------------------------------------------
    if (hand.cards.length == 2 &&
        hand.cards[0].rank.blackjackValue ==
            hand.cards[1].rank.blackjackValue) {
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
            lines.add(
              '⚡ Deviation: basic strategy never splits tens, but at '
              'a true count of ${tc.toStringAsFixed(1)} (≥ ${dev.threshold}), '
              'splitting is the stronger play.',
            );
          } else {
            lines.add(
              "The count favors splitting this pair, but you can't "
              "right now (bankroll or split limit) — Stand instead.",
            );
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
          lines.add(
            "Basic strategy says split this pair, but you can't right "
            "now (not enough bankroll, or you've hit the split limit) — "
            "playing it as a regular hand instead:",
          );
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
        final deviationTriggered =
            dev != null &&
            (dev.atOrAbove ? tc >= dev.threshold : tc <= dev.threshold);

        if (deviationTriggered) {
          lines.add(_actionText(dev.action, hand));
          lines.add(
            '⚡ Deviation: flat basic strategy would say '
            '${_actionText(baseCode, hand)} here, but at a true count of '
            '${tc.toStringAsFixed(1)} the correct play changes to '
            '${_actionText(dev.action, hand)}.',
          );
        } else {
          lines.add(_actionText(baseCode, hand));
          if (basicStrategySurrenderNote(total, dealerKey)) {
            lines.add(
              "(Basic strategy calls for Surrender here if your "
              "table offers it — this game doesn't include surrender, so "
              "Hit is the next-best play.)",
            );
          }
          if (dev != null) {
            final needed = dev.atOrAbove
                ? 'rises to ${dev.threshold} or higher'
                : 'drops to ${dev.threshold} or lower';
            lines.add(
              '(Watch the count: this becomes ${_actionText(dev.action, hand)} '
              'if the true count $needed — you\'re at ${tc.toStringAsFixed(1)} now.)',
            );
          }
        }
      }
    }

    return lines.join('\n\n');
  }

  String _insuranceHint() {
    final tc = shoe.trueCount;
    final insDev = findDeviation('INS', 'A');
    final insTriggered = insDev != null && tc >= insDev.threshold;
    final advice = insTriggered
        ? '⚡ Deviation: dealer shows an Ace and the true count is '
              '${tc.toStringAsFixed(1)} (≥ ${insDev.threshold}) — basic strategy '
              'says skip insurance, but at this count taking it is profitable.'
        : "Dealer shows an Ace — basic strategy says don't take "
              "insurance or even money.";
    return 'True count: ${tc.toStringAsFixed(1)}\n\n$advice';
  }

  String _hintText() {
    if (phase == GamePhase.insurance) return _insuranceHint();
    final hand = _activeHand;
    if (hand == null || dealerHand.isEmpty) return '';
    return _basicStrategyHint(hand, dealerHand[0]);
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
      final isNatural =
          onlyOneHand && hand.cards.length == 2 && playerTotal == 21;
      final label = playerHands.length > 1 ? 'Hand ${i + 1}: ' : '';

      if (isNatural && dealerBlackjack) {
        bankroll += hand.wager;
        lines.add('${label}Push — both blackjack.');
      } else if (isNatural) {
        final winnings = hand.wager * 1.5; // pays 3:2
        bankroll += hand.wager + winnings;
        lines.add('${label}Blackjack! +${formatUnits(winnings)}');
      } else if (dealerBlackjack) {
        lines.add('${label}Dealer blackjack. -${hand.wager}');
      } else if (playerTotal > 21) {
        lines.add('${label}Bust. -${hand.wager}');
      } else if (dealerTotal > 21) {
        bankroll += hand.wager * 2;
        lines.add('${label}Dealer busts! +${hand.wager}');
      } else if (dealerTotal > playerTotal) {
        lines.add(
          '${label}Dealer wins $dealerTotal-$playerTotal. -${hand.wager}',
        );
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
      if (currentBet > bankroll) currentBet = bankroll.floor();
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

  @override
  Widget build(BuildContext context) {
    final hand = _activeHand;
    final canDeal = phase == GamePhase.betting && bankroll >= currentBet;
    final canDouble =
        hand != null && hand.cards.length == 2 && bankroll >= hand.wager;
    final canSplit =
        hand != null &&
        hand.cards.length == 2 &&
        hand.cards[0].rank.blackjackValue ==
            hand.cards[1].rank.blackjackValue &&
        bankroll >= hand.wager &&
        playerHands.length < maxHandsFromSplits;

    return UI(
      playerHands: playerHands,
      activeHandIndex: activeHandIndex,
      dealerHand: dealerHand,
      bankroll: bankroll,
      currentBet: currentBet,
      message: message,
      shoe: shoe,
      isBetting: phase == GamePhase.betting,
      isPlayerTurn: phase == GamePhase.playerTurn,
      isInsuranceOffer: phase == GamePhase.insurance,
      insuranceCost: _insuranceCost,
      canInsure: _canInsure,
      onTakeInsurance: () => _resolveInsurance(take: true),
      onDeclineInsurance: () => _resolveInsurance(take: false),
      canDeal: canDeal,
      canAct: hand != null,
      canDouble: canDouble,
      canSplit: canSplit,
      onIncreaseBet: _increaseBet,
      onDecreaseBet: _decreaseBet,
      onDeal: _deal,
      onHit: _hit,
      onStand: _stand,
      onDouble: _double,
      onSplit: _split,
      hintText: _hintText,
      onRestart: _restart,
    );
  }
}
