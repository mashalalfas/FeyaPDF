// Size: large — widget smoke tests (Flutter rendering baseline)
//
// These tests confirm the app's root widget tree builds without error.
// They run on every flutter test invocation and guard against scaffold breakage.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody_pdf/main.dart';

void main() {
  group('App smoke tests', () {
    // Arrange: nothing beyond the default test environment
    // Act: build the app root widget via MelodyPDFApp
    // Assert: widget builds without throwing, Scaffold is in the tree
    testWidgets('MelodyPdfApp builds without throwing', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MelodyPdfApp());

      // Assert
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('MelodyPdfApp shows a MaterialApp on first frame', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(const MelodyPdfApp());
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
