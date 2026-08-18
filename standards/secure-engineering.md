---
name: secure-engineering
description: Security and privacy rules for design and implementation, including the non-negotiable priority ordering (security above simplicity, effort, and delivery speed), secret handling, and boundary validation. USE FOR any task that touches authentication, authorisation, secrets, credentials, tokens, cryptography, key handling, encoding, serialisation, user input handling, external API calls, personal data, file uploads, or configuration of environments. USE FOR any design decision where a convenient option and a safer option both exist. DO NOT USE FOR performance tuning or pure refactoring with no data-handling change.
globs: 
alwaysApply: false
---

# Secure engineering

## 1. Priority ordering (non-negotiable)

Security and privacy rank above simplicity, above ease of implementation, and
above delivery speed. This is an ordering, not one factor among several.

Rules:

- You must not take a shortcut that trades security or privacy for simpler code,
  less effort, or faster delivery.
- If the secure approach is harder to build, you must build the harder approach.
- When a design choice offers a more convenient option and a more secure option,
  you must default to the secure option, and you must state in your response that
  you chose it and why.
- If a genuine tradeoff is unavoidable, you must surface it to the user before
  implementing. A genuine tradeoff is a real usability or capability cost. Extra
  implementation effort is not a genuine tradeoff.
- You must never silently pick the weaker side of a tradeoff.
- This ordering applies to server code, client code, and protocol-level decisions
  (encoding, key handling, validation) equally.

### How to report a security decision

State three things, in one or two sentences each:

1. The option chosen.
2. The weaker option rejected.
3. The concrete risk the rejection avoids.

## 2. Secrets and credentials

- Secrets must live in environment variables or a user-secrets store.
- Secrets must never appear in source code, committed files, logs, error
  messages, test fixtures, or documentation examples.
- `.env` files must never be committed to git. Confirm `.gitignore` covers them
  before creating one.
- Placeholder values in examples must be obviously fake (e.g. `<api-key>`).
- If you find a committed secret, stop and report it. Say that the secret must be
  rotated, because removing it from the working tree does not remove it from git
  history.

## 3. Validation at boundaries

Validate at system boundaries. Trust internal code.

A boundary is any point where data enters the system from outside its own
process's control:

- User input, including form fields, query strings, path segments, and headers.
- Responses from external APIs and third-party services.
- Deserialised data, including JSON, XML, YAML, and binary payloads.
- File contents and file names supplied by a user.
- Message-queue payloads and webhook bodies.
- Environment and configuration values that change per deployment.

Rules:

- Validate at the boundary, once, and convert to a trusted internal type.
- Do not re-validate the same value in every internal method. Prefer a type that
  cannot hold an invalid value.
- Reject invalid input. Do not silently coerce or truncate it.
- Failure messages returned to a caller must not disclose internal structure,
  stack traces, or configuration values.

## 4. Privacy

- Do not log secrets, credentials, tokens, or personal data. See
  [[observability-standards]] for logging rules.
- Collect the minimum personal data the feature requires.
- Do not send user data to a destination the user did not ask for.

## Checklist before you report a security-relevant task complete

- [ ] No secret is present in any tracked file.
- [ ] Every new boundary has explicit validation.
- [ ] Every security-relevant choice is stated in the response with its rejected
      alternative.
- [ ] Any unavoidable tradeoff was raised with the user before implementation.
