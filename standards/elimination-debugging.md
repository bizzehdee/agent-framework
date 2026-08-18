---
name: elimination-debugging
description: Structured elimination method for diagnosing a defect, failure, or unexplained behaviour, with a required candidate-enumeration and elimination-table report format. USE FOR debugging a bug, a failing test, a crash, a performance regression, flaky behaviour, an incorrect output, a build failure, or any question of the form "why does X happen". USE FOR root-cause analysis and incident investigation. DO NOT USE FOR implementing a new feature, writing tests for working code, or answering a question that needs no diagnosis.
globs: 
alwaysApply: false
---

# Elimination debugging

Diagnose by elimination. You must not test one hypothesis at a time until one
happens to fit.

## Procedure

Follow these steps in order.

1. **Enumerate first.** Before running any test, list every cause the current
   evidence allows. Write the list into your response. Do not start from the most
   likely cause. Do not rank the list.

2. **Check the list for completeness.** Ask: what cause would fall outside this
   list? If you cannot show completeness, add a candidate named
   `not yet enumerated` and keep it in the list until you can.

3. **Do not assume a single cause.** State whether the candidates are mutually
   exclusive. If they are not, continue eliminating after the first cause is
   confirmed.

4. **Prefer tests that split the list.** Choose the test that can remove the most
   candidates. You must not run a test that can only confirm one candidate when a
   splitting test is available.

5. **Eliminate only with evidence.** For each elimination, record the candidate,
   the test performed, the observed result, and why that result rules the
   candidate out. Low plausibility is not evidence. "Unlikely" is not
   "eliminated". An elimination without a recorded observation is invalid.

6. **Track state explicitly.** Keep one row per candidate with a status of
   `eliminated`, `surviving`, or `untested`. Update the table after every test.
   Include the table in every progress report, not only the final one.

7. **Stop rule.** Stop when exactly one candidate survives *and* direct positive
   evidence supports it. If several survive, report all of them. Do not choose
   between survivors by preference, elegance, or familiarity.

8. **An empty set means the enumeration was wrong.** If every candidate is
   eliminated, either the list was incomplete or a test was invalid. Return to
   step 1. Do not resume guessing.

9. **No fix-first debugging.** You must not change code to see what happens.
   Change code only to test a named candidate, and name the candidate in your
   response before making the change.

## Required report format

Every investigation report must contain these five parts, under these headings:

### Candidates
The full list, with a one-line note on why it is or is not complete.

### Elimination table

| Candidate | Test | Observed result | Verdict |
|---|---|---|---|
| ... | ... | ... | eliminated / surviving / untested |

### Surviving candidate(s)
One or more. Never zero. If zero, go back to step 1 instead of reporting.

### Direct positive evidence
The observation that positively demonstrates the survivor causes the behaviour.
Absence of other causes is not positive evidence.

### Reopening assumptions
Assumptions that, if false, would reopen an eliminated candidate.

## Notes

- A test may be a code read, a log inspection, a query, an instrumented run, or a
  minimal reproduction. It does not have to be an automated test.
- If a candidate is untestable with available access, record it as `untested` and
  say what access would be needed. Do not silently drop it.
- Once the cause is confirmed, a regression test is required. See
  [[testing-standards]].
