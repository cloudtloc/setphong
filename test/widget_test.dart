import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diemdanh_face/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ung dung khoi tao MaterialApp', (WidgetTester tester) async {
    await dotenv.load(fileName: 'env.template');
    await tester.pumpWidget(const DiemDanhFaceApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
