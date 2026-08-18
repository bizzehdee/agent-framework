---
name: observability-standards
description: Logging, diagnostics, and health-check standards - structured logging, which events to log, prohibition on logging secrets or personal data, health endpoints for services, and using existing diagnostics before writing custom debug code. USE FOR adding or reviewing logging, choosing log levels, instrumenting a feature, adding metrics or traces, adding a health check, or when tempted to add print statements or temporary debug output. DO NOT USE FOR interpreting existing telemetry during a bug hunt - see elimination-debugging.
globs: 
alwaysApply: false
---

# Observability standards

## Structured logging

- Use structured logging. Pass values as named parameters, not as interpolated
  strings.
- Write `logger.LogInformation("Order {OrderId} created for {CustomerId}", orderId, customerId)`.
- Do not write `logger.LogInformation($"Order {orderId} created")`. String
  interpolation destroys the queryable fields.
- Keep the message template constant for a given event. Do not vary the wording
  between call sites for the same event.
- Include a correlation identifier on every log entry that belongs to a request or
  a message-handling operation.

## What to log

Log:

- Business events, such as an order placed, a payment captured, or a user
  deactivated. Log the identifiers needed to trace the entity.
- Failures, including handled exceptions, validation rejections at boundaries, and
  failed calls to external services.
- The start and outcome of long-running or scheduled operations.

Do not log:

- Success of every internal method call. That is tracing, not logging.
- The same failure at more than one level of the call stack. Log it where it is
  handled.

### Level selection

- `Error`: the operation failed and a person may need to act.
- `Warning`: the operation continued but a degraded path was taken.
- `Information`: a business event completed.
- `Debug` and `Trace`: developer detail, disabled in production by default.

## Prohibited content

- Never log secrets, credentials, tokens, connection strings, or API keys.
- Never log personal data. This includes names, email addresses, phone numbers,
  postal addresses, payment details, and government identifiers.
- Log an identifier instead of the personal data it refers to.
- Check exception messages and request-body dumps before logging them. Both
  commonly carry both categories.
- See [[secure-engineering]] for the wider privacy rules.

## Health checks

- Expose health check endpoints for services.
- Provide a liveness check that reports whether the process is running.
- Provide a readiness check that reports whether dependencies are reachable.
- A health check response must not disclose connection strings, internal
  hostnames, or version detail beyond what is needed.

## Diagnose with existing diagnostics first

- Emit or read useful diagnostics before adding custom debugging code.
- Before adding a print statement or a temporary logger call, check whether an
  existing log, metric, trace, or structured error already answers the question.
- If temporary instrumentation is required, say so, and remove it before reporting
  the task complete. Temporary debug output must not be committed.

## Review checklist

- [ ] Every new log call uses a constant message template with named parameters.
- [ ] No log call can emit a secret or personal data.
- [ ] Failures are logged once, where handled.
- [ ] No temporary debug output remains.
