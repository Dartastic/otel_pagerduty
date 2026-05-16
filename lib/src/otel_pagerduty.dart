// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_pagerduty_suppression.dart';

const _tracerName = 'dartastic_otel_libs_pagerduty';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedPagerdutyEvent` callback.
class PagerdutyEventResult<T> {
  const PagerdutyEventResult({required this.value, this.dedupKey});
  final T value;
  final String? dedupKey;
}

/// Wraps a PagerDuty Events API v2 enqueue (trigger / acknowledge /
/// resolve) in a CLIENT span.
Future<T> tracedPagerdutyEvent<T>({
  required String eventAction,
  required Future<PagerdutyEventResult<T>> Function() invoke,
  String? routingKey,
  String? severity,
  String? source,
}) async {
  if (pagerdutyInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'pagerduty.event_action': eventAction,
  };
  if (routingKey != null) m['pagerduty.routing_key'] = routingKey;
  if (severity != null) m['pagerduty.severity'] = severity;
  if (source != null) m['pagerduty.source'] = source;

  final span = _tracer().startSpan(
    'pagerduty event.$eventAction',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.dedupKey != null) {
      span.addAttributes(OTel.attributes([
        OTel.attributeString('pagerduty.dedup_key', r.dedupKey!),
      ]));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

/// Wraps any PagerDuty REST API call (incidents/services/users/etc.)
/// in a CLIENT span.
Future<T> tracedPagerdutyRest<T>({
  required String resource,
  required String action,
  required Future<T> Function() invoke,
  String? incidentId,
}) async {
  if (pagerdutyInstrumentationSuppressed()) {
    return invoke();
  }
  final m = <String, Object>{
    'pagerduty.resource': resource,
    'pagerduty.action': action,
    'pagerduty.operation': '$resource.$action',
  };
  if (incidentId != null) m['pagerduty.incident.id'] = incidentId;

  final span = _tracer().startSpan(
    'pagerduty $resource.$action',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
