import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ceylontix_app/firebase_options.dart';
import 'package:ceylontix_app/main.dart';

void main() {
  testWidgets('App builds and shows events list title', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await tester.pumpWidget(const MyApp());

    // Verify events list app bar title appears.
    expect(find.text('CeylonTix - Upcoming Events'), findsOneWidget);
  });
}
