import 'package:blackjack/logic/card.dart';
import 'package:blackjack/logic/shoe.dart';
import 'package:blackjack/logic/table_background.dart';
import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart' as pcw;

/// Formats a unit amount without a trailing ".0" on whole numbers.
String formatUnits(num units) => units == units.roundToDouble()
    ? units.round().toString()
    : units.toStringAsFixed(1);

class UI extends StatelessWidget {
  const UI({
    super.key,
    required this.playerHands,
    required this.activeHandIndex,
    required this.dealerHand,
    required this.bankroll,
    required this.currentBet,
    required this.message,
    required this.shoe,
    required this.isBetting,
    required this.isPlayerTurn,
    required this.isInsuranceOffer,
    required this.insuranceCost,
    required this.canInsure,
    required this.onTakeInsurance,
    required this.onDeclineInsurance,
    required this.canDeal,
    required this.canAct,
    required this.canDouble,
    required this.canSplit,
    required this.onIncreaseBet,
    required this.onDecreaseBet,
    required this.onDeal,
    required this.onHit,
    required this.onStand,
    required this.onDouble,
    required this.onSplit,
    required this.hintText,
    required this.onRestart,
  });

  final List<PlayerHand> playerHands;
  final int activeHandIndex;
  final List<PlayingCard> dealerHand;
  final double bankroll;
  final int currentBet;
  final String message;
  final Shoe shoe;
  final bool isBetting;
  final bool isPlayerTurn;
  final bool isInsuranceOffer;
  final double insuranceCost;
  final bool canInsure;
  final VoidCallback onTakeInsurance;
  final VoidCallback onDeclineInsurance;
  final bool canDeal;
  final bool canAct;
  final bool canDouble;
  final bool canSplit;
  final VoidCallback onIncreaseBet;
  final VoidCallback onDecreaseBet;
  final VoidCallback onDeal;
  final VoidCallback onHit;
  final VoidCallback onStand;
  final VoidCallback onDouble;
  final VoidCallback onSplit;
  final String Function() hintText;
  final VoidCallback onRestart;

  bool get _holeCardHidden => isPlayerTurn || isInsuranceOffer;

  void _showHint(BuildContext context) {
    final advice = hintText();
    if (advice.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Basic Strategy Hint',
          style: TextStyle(color: Colors.black),
        ),
        content: SingleChildScrollView(
          child: Text(advice, style: TextStyle(color: Colors.black)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showStrategySheet(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQpYdAyOg0fyY2PH_xrR6jvdtscpG-UUWbGcJXTxP-3yQ&s=10',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders a single card face-up using the playing_cards package.
  /// [faceDown] shows the card back instead — used for the dealer's
  /// hidden hole card while the player is still acting.
  Widget _cardImage(
    PlayingCard card, {
    required double width,
    bool faceDown = false,
  }) {
    return SizedBox(
      width: width,
      child: pcw.PlayingCardView(card: card.pkgCard, showBack: faceDown),
    );
  }

  /// Renders a whole hand as a wrapped row of card widgets. Pass
  /// [hiddenFromIndex] to face-down every card from that index onward
  /// (used for the dealer's hole card); -1 shows everything face-up.
  Widget _cardRow(
    List<PlayingCard> cards, {
    int hiddenFromIndex = -1,
    required double cardWidth,
  }) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < cards.length; i++)
          _cardImage(
            cards[i],
            width: cardWidth,
            faceDown: hiddenFromIndex >= 0 && i >= hiddenFromIndex,
          ),
      ],
    );
  }

  List<Widget> _buildPlayerHandWidgets({
    required double cardWidth,
    required double handWidth,
  }) {
    if (playerHands.isEmpty) {
      return const [Text('—', style: TextStyle(fontSize: 22))];
    }
    return List.generate(playerHands.length, (i) {
      final hand = playerHands[i];
      final isActive = isPlayerTurn && i == activeHandIndex;
      final label = playerHands.length > 1 ? 'Hand ${i + 1}' : 'Your Hand';
      return Container(
        width: handWidth,
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$label${isActive ? '  (active)' : ''} — Bet: ${hand.wager}',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _cardRow(hand.cards, cardWidth: cardWidth),
            ),
            Text('Total: ${hand.total}', textAlign: TextAlign.center),
          ],
        ),
      );
    });
  }

  Widget _buildDealerSection(
    TextTheme textTheme,
    String totalText,
    double cardWidth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        dealerHand.isEmpty
            ? const Text('—', style: TextStyle(fontSize: 22))
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _cardRow(
                  dealerHand,
                  hiddenFromIndex: _holeCardHidden ? 1 : -1,
                  cardWidth: cardWidth,
                ),
              ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Dealer', style: textTheme.titleLarge),
            const SizedBox(width: 20),

            Text('Total: $totalText', textAlign: TextAlign.center),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerHandsSection(
    TextTheme textTheme, {
    required double cardWidth,
    required double handWidth,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Text(
        //   'Your Hand${playerHands.length > 1 ? 's' : ''}',
        //   style: textTheme.titleLarge,
        //   textAlign: TextAlign.center,
        // ),
        // const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: _buildPlayerHandWidgets(
            cardWidth: cardWidth,
            handWidth: handWidth,
          ),
        ),
      ],
    );
  }

  Widget _buildBankrollControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Bankroll: ${formatUnits(bankroll)} units',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bet: $currentBet',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: isBetting ? onDecreaseBet : null,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: isBetting ? onIncreaseBet : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShoeInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Cards: ${shoe.cardsRemaining} / ${shoe.totalCards}',
          textAlign: TextAlign.left,
          style: const TextStyle(color: Colors.white70),
        ),
        Text(
          'Running: ${shoe.runningCount}  True: ${shoe.trueCount.toStringAsFixed(2)}',
          textAlign: TextAlign.left,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildStatusAndBankroll(double maxWidth) {
    // status widget
    final status = Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );

    // place bankroll to the right if space allows
    if (maxWidth >= 650) {
      return SizedBox(
        height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 230),
                  child: status,
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildShoeInfo(),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: _buildBankrollControls(),
              ),
            ),
          ],
        ),
      );
    }

    // otherwise place verically
    return Column(
      children: [
        Center(child: status),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: _buildShoeInfo()),
            const SizedBox(width: 8),
            _buildBankrollControls(),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (isInsuranceOffer) ...[
          ElevatedButton(
            onPressed: canInsure ? onTakeInsurance : null,
            child: Text('Insurance (${formatUnits(insuranceCost)})'),
          ),
          ElevatedButton(
            onPressed: onDeclineInsurance,
            child: const Text('No Insurance'),
          ),
        ],
        ElevatedButton(
          onPressed: canDeal ? onDeal : null,
          child: const Text('Deal'),
        ),
        ElevatedButton(
          onPressed: canAct ? onHit : null,
          child: const Text('Hit'),
        ),
        ElevatedButton(
          onPressed: canAct ? onStand : null,
          child: const Text('Stand'),
        ),
        ElevatedButton(
          onPressed: canDouble ? onDouble : null,
          child: const Text('Double'),
        ),
        ElevatedButton(
          onPressed: canSplit ? onSplit : null,
          child: const Text('Split'),
        ),
        OutlinedButton.icon(
          onPressed: canAct || isInsuranceOffer
              ? () => _showHint(context)
              : null,
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text('Hint'),
        ),
        OutlinedButton.icon(
          onPressed: () => _showStrategySheet(context),
          icon: const Icon(Icons.grid_on),
          label: const Text('Strategy Sheet'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dealerTotalText = _holeCardHidden
        ? '${dealerHand.isNotEmpty ? dealerHand[0].rank.blackjackValue : 0} + ?'
        : '${handValue(dealerHand)}';
    final theme = Theme.of(context);
    final textTheme = theme.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        const TableBackground(),
        Theme(
          data: theme.copyWith(
            textTheme: textTheme,
            iconTheme: const IconThemeData(color: Colors.white),
            dividerColor: Colors.white54,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
              ),
            ),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth - 32;
                final isWide = constraints.maxWidth >= 700;
                final handCount = playerHands.isEmpty ? 1 : playerHands.length;
                final handsPerRow = isWide ? handCount : 1;
                final handWidth = availableWidth / handsPerRow;
                final maxCardsInHand = playerHands.fold<int>(
                  2,
                  (maxCards, hand) => hand.cards.length > maxCards
                      ? hand.cards.length
                      : maxCards,
                );
                final maxDealerCards = dealerHand.length.clamp(1, 5);
                final maxPlayerCardsPerRow = maxCardsInHand.clamp(1, 4);
                final estimatedRows = 1 + (isWide ? 1 : handCount);
                final markingsHeight = TableMarkings.heightFor(availableWidth);
                final heightBasedCardWidth =
                    ((constraints.maxHeight - markingsHeight) /
                            (4.4 + estimatedRows * 1.45))
                        .clamp(36.0, 112.0)
                        .toDouble();
                final dealerRowWidth =
                    availableWidth - (maxDealerCards - 1) * 6;
                final dealerCardWidth =
                    heightBasedCardWidth < dealerRowWidth / maxDealerCards
                    ? heightBasedCardWidth
                    : dealerRowWidth / maxDealerCards;
                final widthBasedPlayerCard =
                    (handWidth - 32 - (maxPlayerCardsPerRow - 1) * 6) /
                    maxPlayerCardsPerRow;
                final playerCardWidth =
                    heightBasedCardWidth < widthBasedPlayerCard
                    ? heightBasedCardWidth
                    : widthBasedPlayerCard;

                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Dealer
                          _buildDealerSection(
                            textTheme,
                            dealerTotalText,
                            dealerCardWidth,
                          ),
                          const SizedBox(height: 12),

                          // Keep status centered and place bankroll/shoe details at the right.
                          _buildStatusAndBankroll(constraints.maxWidth),
                          TableMarkings(width: availableWidth),
                          const SizedBox(height: 8),

                          // Player hands share a row on wide screens and stack on narrow ones.
                          _buildPlayerHandsSection(
                            textTheme,
                            cardWidth: playerCardWidth,
                            handWidth: handWidth,
                          ),

                          // Action buttons
                          const SizedBox(height: 8),
                          _buildActionButtons(context),
                          const SizedBox(height: 4),

                          // Restart Button
                          Center(
                            child: TextButton(
                              onPressed: onRestart,
                              child: const Text('Restart Game'),
                            ),
                          ),
                          const SizedBox(height: 12),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
