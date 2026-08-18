---
name: performance-discipline
description: Rules for when and how to optimise - correctness before performance, measure before optimising, and the specific defects worth avoiding by default (N+1 queries, loading unnecessary data, buffering large payloads, poor algorithmic complexity on collections). USE FOR responding to a slowness report, reviewing code for efficiency, writing a database query or a loop over a large collection, handling file or streamed payloads, or when asked to make something faster. DO NOT USE FOR diagnosing a specific measured regression - use elimination-debugging to find the cause first.
globs: 
alwaysApply: false
---

# Performance discipline

## Order of work

1. Make it correct.
2. Measure it.
3. Optimise the measured bottleneck.

Rules:

- Do not optimise too early. Prefer correctness over performance initially, and
  optimise later.
- You must measure before optimising. State the measurement in your response: what
  was measured, the tool or method used, and the number observed.
- You must not accept "this will be faster" as a justification without a
  measurement. If you cannot measure, say so and label the change as unverified.
- After optimising, measure again and report the before and after values.
- Do not trade readability for a performance gain you have not measured.

## Defects to avoid by default

These are not premature optimisations. They are defects. Avoid them when first
writing the code.

### N+1 database queries

- Do not issue a query inside a loop over results from another query.
- Load related data in one query, or batch the loads.
- When reviewing data access, count the queries a single request issues.

### Loading unnecessary data

- Select only the columns the caller uses.
- Filter and paginate in the database, not in application memory.
- Do not materialise a full collection to compute a count or check existence.

### Buffering large payloads

- Prefer streaming for large payloads.
- Do not read an entire file or HTTP response into memory when it can be processed
  incrementally.
- Set an explicit size limit on any upload or inbound payload. An unbounded read
  is also a security issue. See [[secure-engineering]].

### Algorithmic complexity

- Consider algorithmic complexity when processing collections.
- Do not write a nested loop over two collections that both grow with data volume.
  Use a lookup structure.
- State the complexity when it is not obvious from the code, as a comment
  explaining a non-obvious why. See [[code-quality]].

## Reporting a performance change

Report all four:

1. The measurement before the change.
2. The change made.
3. The measurement after the change.
4. The measurement method, so the result can be reproduced.
