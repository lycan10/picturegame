import 'package:flutter_test/flutter_test.dart';

import 'package:picture_match/main.dart';

void main() {
  testWidgets('Home screen renders worlds and navigation', (tester) async {
    await tester.pumpWidget(const PictureMatchApp());
    await tester.pump();

    expect(find.text('Choose your world'), findsOneWidget);
    expect(find.text('Animal Kingdom'), findsOneWidget);

    // Bottom navigation tabs exist.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Battle'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
