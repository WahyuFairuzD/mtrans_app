import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtrans_wash/widgets/dashboard_scaffold.dart';

void main() {
  Future<double> greetingFontSize(WidgetTester tester, String text) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 320, child: GreetingText(text: text)),
          ),
        ),
      ),
    );
    return tester.widget<Text>(find.byType(Text)).style!.fontSize!;
  }

  testWidgets('nama pendek memakai ukuran penuh', (tester) async {
    expect(
      await greetingFontSize(tester, 'Halo, Budi'),
      GreetingText.maxFontSize,
    );
  });

  testWidgets('nama panjang dikecilkan agar muat satu baris', (tester) async {
    final size = await greetingFontSize(tester, 'Halo, PengawasOperational');
    expect(size, lessThan(GreetingText.maxFontSize));
    expect(size, greaterThanOrEqualTo(GreetingText.minFontSize));
  });

  testWidgets('nama sangat panjang tidak overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: GreetingText(text: 'Halo, ${'PengawasOperational' * 4}'),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Text>(find.byType(Text)).style!.fontSize,
      GreetingText.minFontSize,
    );
  });
}
