# Reconcile — load-bearing inputs vs the spine

## UX EXPERIENCE.md — the nine `[NOTE FOR ARCHITECTURE]` / `[NOTE FOR PRD]` markers

| # | Ask | Landed in | Status |
|---|---|---|---|
| 1 | Enable auditing and register OcuPilot's audit events at install | AD-17, AD-15 | ✅ |
| 2 | **Cap the rows that travel with a turn and show the count on the read tool-call card** | — | ❌ **GAP** |
| 3 | Reversible entity-id encoding; names with spaces, slashes and leading `_` round-trip in one path segment | AD-13 | ✅ |
| 4 | Where the API accepts a partial update, send only the changed fields | AD-4 | ✅ |
| 5 | Unexpire `_SYSTEM` at install so the first screen never sends the user to the classic portal | AD-17 | ✅ |
| 6 | *(NOTE FOR PRD)* Step 7 per-user turn limits need a banner and refusal sentence | n/a — PRD's, not architecture's | n/a |
| 7 | Proposal interval is a server-side constant; per-instance setting is a Switches candidate | AD-6 + Deferred | ✅ |
| 8 | **Decide whether the FR-69 demo fixture that creates `/csp/myapp` is on by default in the Compose flow** | — | ❌ **GAP** |
| 9 | Installer should make the expired-password edge disappear | AD-17 | ✅ |

### Gap 2 — screen-context row cap

The UX asks for a cap on rows travelling with a turn. This is an architecture invariant, not a story detail: it binds the context serializer that AD-5 makes every screen declare, it is a cost and latency control (NFR-1, section 7.3), and it is part of the untrusted-content surface (NFR-6) since every row carried is attacker-influenced text. Two slices could pick different caps, or none. **Needs an AD.**

### Gap 8 — demo fixture default

FR-69 and UJ-3 depend on a disabled `/csp/myapp` web application existing on a clean install. Whether the Compose flow creates it is an install-path decision that binds `Install/` and the smoke script, and it has a safety edge: a fixture that creates a web application on someone's instance is a write the operator did not ask for. **Needs a decision, at minimum in Deferred with a revisit condition — but it is on the demo critical path, so decide it.**

## PRD open questions owned by architecture

| OQ | Question | Resolution |
|---|---|---|
| 4 | Classes behind X.509, messages.log, application error log | `%SYS.X509Credentials` (confirmed twice); messages.log and alerts.log are plain files in the manager directory; application errors are `%CSP.ErrorLog`. In AD-21 for the log path; the X.509 class is a build detail, not an invariant. ✅ |
| 5 | Install at image build or container start against the durable volume | AD-17 — container start, proven from the durable/image database split. ✅ |
| 17 | Tools in-process or over HTTP with the user's token | AD-1 (in-process) + AD-7 (progress channel). ✅ |

## PRD requirement groups vs the Capability map

All of 5.1–5.12 and Stages 2–6 appear in the Capability → Architecture Map. Spot checks:

- **FR-7 auto-refresh framework** — auto-refresh state is named in AD-19's store list and its pause-under-proposal behavior is the UX's; the *shared framework* nature (one implementation, ten screens) is implied by AD-5/AD-19 but not stated. Minor.
- **FR-9 classic portal fallback links** — not mentioned in the spine. It is a per-screen link, correctly a story detail, and the descriptor (AD-5) is where it would hang. Acceptable.
- **FR-23 provider retry, timeouts, gateway prerequisite** — retry/timeout live in the harvested provider layer; the gateway prerequisite is *removed* by AD-7. Worth stating explicitly that AD-7 retires that prerequisite, which it does say.
- **NFR-12 accessibility** — entirely the UX's contract; no architecture invariant needed beyond AD-19's component model. Acceptable.
