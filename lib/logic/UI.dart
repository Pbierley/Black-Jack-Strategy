
import 'package:blackjack/logic/card.dart';
import 'package:blackjack/logic/shoe.dart';
import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart' as pcw;

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
  final int bankroll;
  final int currentBet;
  final String message;
  final Shoe shoe;
  final bool isBetting;
  final bool isPlayerTurn;
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

  void _showHint(BuildContext context) {
    final advice = hintText();
    if (advice.isEmpty) return;
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
      final isActive = isPlayerTurn && i == activeHandIndex;
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
    final dealerTotalText = isPlayerTurn
        ? '${dealerHand.isNotEmpty ? dealerHand[0].rank.blackjackValue : 0} + ?'
        : '${handValue(dealerHand)}';

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
                      onPressed: isBetting ? onDecreaseBet : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: isBetting ? onIncreaseBet : null,
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
                hiddenFromIndex: isPlayerTurn ? 1 : -1,
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
                  onPressed: canAct ? () => _showHint(context) : null,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Hint'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showStrategySheet(context),
                  icon: const Icon(Icons.grid_on),
                  label: const Text('Strategy Sheet'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Center(
              child: TextButton(
                onPressed: onRestart,
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

          ],
        ),
      ),
    );
  }
}