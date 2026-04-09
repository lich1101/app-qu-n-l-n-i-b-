// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:Teso_Internal_Task_Manager/app/internal_task_app.dart';

void main() {
  testWidgets('app khởi tạo MaterialApp', (WidgetTester tester) async {
    dotenv.testLoad(
      fileInput: '''
APP_NAME=Teso Internal Task Manager
API_BASE_URL=http://127.0.0.1:8000/api/v1
WEB_BASE_URL=http://127.0.0.1:8000
REQUEST_TIMEOUT_SECONDS=15
''',
    );

    await tester.pumpWidget(const InternalTaskApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
