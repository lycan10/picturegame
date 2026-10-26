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
  GameLevel('Savanna Safari', [
    MatchItem(
      id: 'zebra',
      word: 'Zebra',
      picture: '🦓',
      hint: 'This horse cousin wears black and white stripes.',
    ),
    MatchItem(
      id: 'hippo',
      word: 'Hippo',
      picture: '🦛',
      hint: 'This big animal loves soaking in rivers.',
    ),
    MatchItem(
      id: 'cheetah',
      word: 'Cheetah',
      picture: '🐆',
      hint: 'This spotted cat is the fastest land runner.',
    ),
    MatchItem(
      id: 'crocodile',
      word: 'Crocodile',
      picture: '🐊',
      hint: 'This reptile has a long snout and sharp teeth.',
    ),
  ]),
  GameLevel('Ocean Wonders', [
    MatchItem(
      id: 'whale',
      word: 'Whale',
      picture: '🐋',
      hint: 'The largest animal in the ocean.',
    ),
    MatchItem(
      id: 'shark',
      word: 'Shark',
      picture: '🦈',
      hint: 'This fish has a dorsal fin and rows of teeth.',
    ),
    MatchItem(
      id: 'octopus',
      word: 'Octopus',
      picture: '🐙',
      hint: 'This sea creature has eight arms.',
    ),
    MatchItem(
      id: 'crab',
      word: 'Crab',
      picture: '🦀',
      hint: 'This creature walks sideways with claws.',
    ),
    MatchItem(
      id: 'fish',
      word: 'Fish',
      picture: '🐟',
      hint: 'This swimmer breathes through gills.',
    ),
  ]),
  GameLevel('Jungle Challenge', [
    MatchItem(
      id: 'monkey',
      word: 'Monkey',
      picture: '🐒',
      hint: 'This animal swings from trees and loves bananas.',
    ),
    MatchItem(
      id: 'tiger',
      word: 'Tiger',
      picture: '🐯',
      hint: 'This striped big cat roars in the jungle.',
    ),
    MatchItem(
      id: 'koala',
      word: 'Koala',
      picture: '🐨',
      hint: 'This Australian animal sleeps in eucalyptus trees.',
    ),
    MatchItem(
      id: 'panda',
      word: 'Panda',
      picture: '🐼',
      hint: 'This bear is black and white and eats bamboo.',
    ),
    MatchItem(
      id: 'snake',
      word: 'Snake',
      picture: '🐍',
      hint: 'This reptile slithers without legs.',
    ),
    MatchItem(
      id: 'parrot',
      word: 'Parrot',
      picture: '🦜',
      hint: 'This colorful bird can copy human words.',
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
  GameLevel('European Tour', [
    MatchItem(
      id: 'germany',
      word: 'Germany',
      picture: '🇩🇪',
      hint: 'Its flag has black, red, and gold horizontal stripes.',
    ),
    MatchItem(
      id: 'italy',
      word: 'Italy',
      picture: '🇮🇹',
      hint: 'Its flag has green, white, and red vertical stripes.',
    ),
    MatchItem(
      id: 'spain',
      word: 'Spain',
      picture: '🇪🇸',
      hint: 'Its flag has red and yellow stripes.',
    ),
    MatchItem(
      id: 'netherlands',
      word: 'Netherlands',
      picture: '🇳🇱',
      hint: 'Its flag has red, white, and blue horizontal stripes.',
    ),
  ]),
  GameLevel('Global Tour', [
    MatchItem(
      id: 'mexico',
      word: 'Mexico',
      picture: '🇲🇽',
      hint: 'Its flag has an eagle on a cactus.',
    ),
    MatchItem(
      id: 'india',
      word: 'India',
      picture: '🇮🇳',
      hint: 'Its flag has a navy wheel in the middle.',
    ),
    MatchItem(
      id: 'china',
      word: 'China',
      picture: '🇨🇳',
      hint: 'Its flag has five yellow stars on red.',
    ),
    MatchItem(
      id: 'kenya',
      word: 'Kenya',
      picture: '🇰🇪',
      hint: 'Its flag has a shield and spears.',
    ),
  ]),
  GameLevel('Flag Champion', [
    MatchItem(
      id: 'egypt',
      word: 'Egypt',
      picture: '🇪🇬',
      hint: 'Its flag has a golden eagle in the center.',
    ),
    MatchItem(
      id: 'australia',
      word: 'Australia',
      picture: '🇦🇺',
      hint: 'Its flag has the Union Jack and southern stars.',
    ),
    MatchItem(
      id: 'argentina',
      word: 'Argentina',
      picture: '🇦🇷',
      hint: 'Its flag has a golden sun in the middle.',
    ),
    MatchItem(
      id: 'portugal',
      word: 'Portugal',
      picture: '🇵🇹',
      hint: 'Its flag has green and red with a shield.',
    ),
    MatchItem(
      id: 'sweden',
      word: 'Sweden',
      picture: '🇸🇪',
      hint: 'Its flag has a yellow cross on blue.',
    ),
    MatchItem(
      id: 'indonesia',
      word: 'Indonesia',
      picture: '🇮🇩',
      hint: 'Its flag has red and white horizontal stripes.',
    ),
  ]),
];
