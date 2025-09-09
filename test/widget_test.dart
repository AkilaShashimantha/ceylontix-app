import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ceylontix_app/firebase_options.dart';
import 'package:ceylontix_app/main.dart';

void main() {
  testWidgets('App builds and shows login prompt', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await tester.pumpWidget(const CeylonTixApp());

    // Verify login screen text appears (silent UI, no responses on sign-in attempt).
    expect(find.text('Please sign in to continue'), findsOneWidget);
  });
}
