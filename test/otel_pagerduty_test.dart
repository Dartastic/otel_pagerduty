// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_pagerduty/otel_pagerduty.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_pagerduty-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('event.trigger records CLIENT span', () async {
    await tracedPagerdutyEvent<String>(
      eventAction: 'trigger',
      routingKey: 'r-1',
      severity: 'critical',
      source: 'web-1',
      invoke: () async => const PagerdutyEventResult(
        value: 'ok',
        dedupKey: 'd-1',
      ),
    );
    final a = attrsOf(spans.findSpanByName('pagerduty event.trigger')!);
    expect(a['pagerduty.event_action'], 'trigger');
    expect(a['pagerduty.routing_key'], 'r-1');
    expect(a['pagerduty.severity'], 'critical');
    expect(a['pagerduty.source'], 'web-1');
    expect(a['pagerduty.dedup_key'], 'd-1');
  });

  test('REST incidents.list records CLIENT span', () async {
    await tracedPagerdutyRest<String>(
      resource: 'incidents',
      action: 'list',
      invoke: () async => 'rows',
    );
    final a = attrsOf(spans.findSpanByName('pagerduty incidents.list')!);
    expect(a['pagerduty.operation'], 'incidents.list');
  });

  test('suppression skips spans', () async {
    await runWithoutPagerdutyInstrumentationAsync(() async {
      await tracedPagerdutyEvent<String>(
        eventAction: 'trigger',
        invoke: () async => const PagerdutyEventResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('pagerduty '), isEmpty);
  });
}
