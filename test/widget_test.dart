import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_animes/main.dart';
import 'package:my_animes/widgets/shimmer_loading.dart';

void main() {
  testWidgets('MyAnimes app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MyAnimesApp());
    // Allow startup timers (Firebase timeout, etc.) to complete
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(MyAnimesApp), findsOneWidget);
  });

  testWidgets('ShimmerLoading.card safely renders inside unconstrained SingleChildScrollView', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                Builder(
                  builder: (context) => ShimmerLoading.card(context: context),
                ),
                Builder(
                  builder: (context) => ShimmerLoading.card(context: context, width: 130),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Pump a frame to paint
    await tester.pump();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}

