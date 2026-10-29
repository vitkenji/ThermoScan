import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoscan/core/storage/token_storage.dart';
import 'package:thermoscan/main.dart';

void main() {
  testWidgets('Bootstraps from Splash to Login when no session exists',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
        ],
        child: const ThermoScanApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Field Diagnostics Login'), findsOneWidget);
    expect(find.text('Corporate Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}
