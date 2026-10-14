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
