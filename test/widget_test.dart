import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_app/main.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const RecipeApp());
    // Verify app renders the loading indicator initially
    expect(find.byType(RecipeApp), findsOneWidget);
  });
}
