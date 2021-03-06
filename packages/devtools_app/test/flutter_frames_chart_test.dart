// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/timeline/flutter_frames_chart.dart';
import 'package:devtools_app/src/timeline/timeline_model.dart';
import 'package:devtools_app/src/timeline/timeline_controller.dart';
import 'package:devtools_app/src/ui/colors.dart';
import 'package:devtools_testing/support/timeline_test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

void main() {
  Future<void> pumpChart(
    WidgetTester tester, {
    @required List<TimelineFrame> frames,
  }) async {
    await tester.pumpWidget(wrapWithControllers(
      FlutterFramesChart(frames, 20, defaultRefreshRate),
      timeline: TimelineController(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterFramesChart), findsOneWidget);
  }

  group('TimelineScreen', () {
    setUp(() async {
      setGlobal(
          ServiceConnectionManager, FakeServiceManager(useFakeService: true));
    });

    testWidgets('builds with no frames', (WidgetTester tester) async {
      await pumpChart(tester, frames: []);
      expect(find.byKey(FlutterFramesChart.chartLegendKey), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsNothing);
    });

    testWidgets('builds with frames', (WidgetTester tester) async {
      await pumpChart(tester, frames: [testFrame0, testFrame1]);
      expect(find.byKey(FlutterFramesChart.chartLegendKey), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsNWidgets(2));
    });

    testWidgets('builds with janky frame', (WidgetTester tester) async {
      await pumpChart(tester, frames: [jankyFrame]);
      expect(find.byKey(FlutterFramesChart.chartLegendKey), findsOneWidget);
      expect(find.byType(FlutterFramesChartItem), findsOneWidget);
      final ui = tester.widget(find.byKey(const Key('frame jankyFrame - ui')))
          as Container;
      expect(ui.color, equals(uiJankColor));
      final raster =
          tester.widget(find.byKey(const Key('frame jankyFrame - raster')))
              as Container;
      expect(raster.color, equals(rasterJankColor));
    });
  });
}
