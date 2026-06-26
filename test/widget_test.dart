import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:videoframex_desktop/src/app.dart';

void main() {
  testWidgets('shows the VideoFrameX desktop shell', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    await tester.pumpWidget(const ProviderScope(child: VideoFrameXApp()));
    await tester.pump();

    expect(find.text('VideoFrameX Desktop'), findsWidgets);
    expect(find.text('Video Upload'), findsOneWidget);
    expect(find.text('Extraction Settings'), findsOneWidget);
  });
}
