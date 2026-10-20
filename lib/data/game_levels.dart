import '../models/game_level.dart';
import '../models/match_item.dart';

const animalLevels = <GameLevel>[
  GameLevel('Meet the Animals', [
    MatchItem(
      id: 'lion',
      word: 'Lion',
      picture: '🦁',
      hint: 'This big cat has a mane.',
    ),
    MatchItem(
      id: 'elephant',
      word: 'Elephant',
      picture: '🐘',
      hint: 'This animal has a long trunk.',
    ),
    MatchItem(
      id: 'giraffe',
      word: 'Giraffe',
      picture: '🦒',
      hint: 'This animal has a very long neck.',
    ),
  ]),
  GameLevel('Animal Friends', [
    MatchItem(
      id: 'cat',
      word: 'Cat',
      picture: '🐱',
      hint: 'This pet purrs and has whiskers.',
    ),
    MatchItem(
      id: 'dog',
      word: 'Dog',
      picture: '🐶',
      hint: 'This pet is known as man’s best friend.',
    ),
    MatchItem(
      id: 'rabbit',
      word: 'Rabbit',
      picture: '🐰',
      hint: 'This animal has long ears and hops.',
    ),
  ]),
  GameLevel('Wildlife Explorer', [
    MatchItem(
      id: 'penguin',
      word: 'Penguin',
      picture: '🐧',
      hint: 'This bird cannot fly and loves the cold.',
    ),
    MatchItem(
      id: 'turtle',
      word: 'Turtle',
      picture: '🐢',
      hint: 'This animal carries a protective shell.',
    ),
    MatchItem(
      id: 'dolphin',
      word: 'Dolphin',
      picture: '🐬',
      hint: 'This intelligent marine mammal swims in the sea.',
    ),
  ]),
];

const countryLevels = <GameLevel>[
  GameLevel('Around the World', [
    MatchItem(
      id: 'canada',
      word: 'Canada',
      picture: '🇨🇦',
      hint: 'Its flag has a red maple leaf.',
    ),
    MatchItem(
      id: 'japan',
      word: 'Japan',
      picture: '🇯🇵',
      hint: 'Its flag has a red circle on white.',
    ),
    MatchItem(
      id: 'brazil',
      word: 'Brazil',
      picture: '🇧🇷',
      hint: 'Its flag has a yellow diamond and blue globe.',
    ),
  ]),
  GameLevel('Flag Explorer', [
    MatchItem(
      id: 'nigeria',
      word: 'Nigeria',
      picture: '🇳🇬',
      hint: 'Its flag has green, white, and green vertical stripes.',
    ),
    MatchItem(
      id: 'france',
      word: 'France',
      picture: '🇫🇷',
      hint: 'Its flag has blue, white, and red vertical stripes.',
    ),
    MatchItem(
      id: 'ghana',
      word: 'Ghana',
      picture: '🇬🇭',
      hint: 'Its flag has a black star.',
    ),
  ]),
  GameLevel('Flag Master', [
    MatchItem(
      id: 'usa',
      word: 'United States',
      picture: '🇺🇸',
      hint: 'Its flag has stars and stripes.',
    ),
    MatchItem(
      id: 'uk',
      word: 'United Kingdom',
      picture: '🇬🇧',
      hint: 'Its flag features overlapping red, white, and blue crosses.',
    ),
    MatchItem(
      id: 'south_africa',
      word: 'South Africa',
      picture: '🇿🇦',
      hint: 'Its colorful flag features a green Y-shaped band.',
    ),
  ]),
];
