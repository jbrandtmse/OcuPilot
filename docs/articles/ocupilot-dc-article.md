# OcuPilot: ask, review, confirm, audit - an AI co-pilot for the IRIS Management Portal

<!-- Draft for the InterSystems Developer Community, for the "Build Your Own Management Portal"
contest. Before publishing: add the screenshots marked below, the Open Exchange link, and the
contest tag. -->

The System Management Portal is where most of us administer IRIS, and it has not changed much in a
long time. When InterSystems asked the community to [build our own management
portal](https://openexchange.intersystems.com/contest/48), I wanted to answer two questions at
once: what would the portal look like if it were built today, and what would it take to let an AI
agent help run an IRIS instance without having to trust it?

The result is **OcuPilot**: a rebuilt portal for the six areas the contest names, with an agent
docked beside every screen that can explain what you are looking at and change settings for you -
but only after you have reviewed the change and pressed Confirm.

You can try it right now, without installing anything: open **[ocupilot.org](https://ocupilot.org)**
and sign in as `demo` with the password `ocupilot-demo`. The demo runs on a real IRIS for Health
instance and resets every hour.

<!-- SCREENSHOT: the portal with the agent panel open beside the Web applications list. -->

## A portal for the six areas

OcuPilot covers every area the contest asks for, with list screens, row actions and full editors
working against live instance data:

- **Web applications** - create, edit, enable, disable and delete, plus a REST API explorer and an
  OpenAPI viewer for every REST application on the instance.
- **Permissions** - users, roles, resources and services, with editors for users and roles,
  password changes and role and resource grants.
- **Security and secrets** - SSL/TLS, X.509 credentials, the wallet, LDAP, auditing and all five
  kinds of OAuth 2.0 object, with editors for each, connection tests and token revocation.
- **Tasks** - the schedule, on-demand and upcoming tasks and history, with a New Task wizard, edit,
  run, suspend, resume and delete.
- **OS management** - processes, locks, system usage, databases and devices.
- **Logs** - `alerts.log`, `messages.log`, application errors and the audit database.

The shell is shaped like VS Code: an activity rail on the left, the screen in the middle and the
agent panel on the right. There is a command palette (`Ctrl+K` or `⌘K`), favorites and recent
items, resizable columns, per-screen help, and a light and a dark theme.

## Ask about what you are looking at

The agent always knows which screen you are on. When you ask a question, OcuPilot sends it the
screen's identity, its filter and selection, and the rows in front of you, so questions like these
are answered from your own data rather than from general knowledge:

- "Which of these web applications allow unauthenticated access?"
- "Why is this task suspended, and is it safe to resume?"
- "What does this audit record mean?"

Every screen offers an **Explain this screen** prompt and a few suggested questions, and any log
line, application error or audit record can be explained in place. When the agent names rows in
its answer, they come back as citation chips: click one and the screen selects that row.

If a conversation is about a screen you are not on, the agent opens it. Ask "create a web
application for my new REST service" from Home, and it takes you to Web applications first.

## Ask, review, confirm, audit

This is the part I cared about most. An agent that can change a production instance is only
useful if you never have to wonder what it did. So in OcuPilot the agent never writes anything. It
can read, and it can propose; the write happens in a separate request that only your browser makes,
when you press Confirm.

Here is the whole path, using the web application the demo ships disabled.

**1. Ask.** On Web applications, type: *"Enable /csp/myapp and give it the %Development
resource."*

**2. Review.** A proposal card appears in the panel. The diff on it is computed by the instance
from a fresh read of `/csp/myapp` - not written by the model - and shows each field that will
change with its current and new value. The card also names the privilege the change needs and how
to reverse it.

<!-- SCREENSHOT: the proposal card with the before-and-after diff and the privilege line. -->

**3. Confirm.** When you press Confirm, OcuPilot re-checks, on the server, that you still hold the
privilege, that `/csp/myapp` has not changed since the proposal was made, and that the change is not
on the prohibited list. Then it runs the change **as you**, with your own roles, never an elevated
service account. A proposal can be confirmed once and expires after ten minutes.

**4. Audit.** The Web applications list refreshes and marks `/csp/myapp` as Changed. And the change
is recorded in the IRIS audit database as an `OcuPilot/Security/AgentWrite` event, so the answer to
"what did the agent change last week?" lives where your auditors already look, not in a log only
OcuPilot can read.

<!-- SCREENSHOT: the refreshed list with the Changed marker, and the audit database filtered to agent writes. -->

## Guardrails that live on the instance

Everything above is enforced by the server, not the browser, and a few changes are refused outright
however they are asked for. OcuPilot will not disable or delete `_SYSTEM`, the signed-in user, the
service accounts or the last holder of `%All`; it will not break its own web applications, roles,
resources or processes; and it will not touch fields outside the reviewed list for each tool. The
refusal says why - for example: *"This is the last account that holds %All. Disabling it, deleting
it or taking the role off it would leave nobody able to administer this instance."*

An administrator also has switches: a kill switch that stops the agent for everyone, an enforced
read-only mode, per-user holds, and control over how many rows of screen context may be shared.

Secrets never reach the model. Screens that hold passwords, keys or wallet secrets send only which
record you are on. When a change needs a secret - a new user's password, say - the proposal card
asks you for it, and it travels only with your Confirm.

## Bring your own model

OcuPilot works with Anthropic, OpenAI, Google Gemini, or any OpenAI-compatible endpoint. The last
one is the privacy option: point it at Ollama, vLLM or LM Studio on your own network, mark it local,
and no screen data or log text leaves your network.

Two tips from setting this up with real keys:

- **Anthropic:** create the key inside one workspace. A key that spans every workspace is refused
  unless the request names a workspace.
- **Local models:** a model that is still loading can take longer to answer its first request than
  the Web Gateway waits. Test again once it is warm, or raise the gateway's
  `Server_Response_Timeout` if your model is simply slow.

## How it is built

For the developers reading this, a short tour:

- **One install, served by IRIS.** The portal is an Angular 22 application served from `/ocupilot`,
  and the API behind it is ObjectScript REST at `/api/ocupilot`. There is no separate server.
- **The admin API, in-process.** Most screens read and write through IRIS's `/api/admin` v2
  service, called in-process rather than over HTTP, alongside `Security.*`, `%SYS.Task` and the
  log files.
- **One descriptor per screen.** Each screen is declared once, and that declaration produces both
  the screen's read and the agent's matching tool, so the agent and the screen always see the same
  data.
- **The model never writes.** An agent turn runs in a background job that can only read and
  propose. Proposals are stored on the instance with a fingerprint of their target, which is how
  Confirm knows whether the target has changed.
- **Protected state.** Agent definitions, switches, the agent ledger and transcripts live in
  OcuPilot's own database, behind a resource no ordinary role holds.
- **Tested in CI.** Every push runs 287 `%UnitTest` classes inside a fresh IRIS container, the
  client's Node and Angular tests, 92 browser specs in headless Chrome, a compile-and-smoke run on
  both IRIS Community and IRIS for Health Community, and an offline IPM install.

## How I built it: the BMAD Method

I use and advocate the [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) for building
software with AI agents, and OcuPilot was built with it from the first idea to the release - which
is a large part of how it got this far in under three weeks.

**Planning came first, and it was thorough.** Before any code:

- a research pass over the classic portal and the admin API produced a prioritized catalog of 538
  portal features;
- a product brief and a PRD set the scope, and UX design documents set every screen's states,
  strings and interactions;
- an architecture spine recorded 56 binding decisions that every story had to honor, or amend in
  the open - among them "Confirm is reachable only from the browser, and the write gate is on the
  write", "Prohibited actions are absent from the tool set, not gated within it", and "The model is
  assumed compromised by anything it reads";
- the work was cut into 22 epics of small stories, ordered so that the six contest areas and the
  ask-review-confirm-audit path landed first.

**Then every story went through the same cycle**, with Claude Code as the development agents: a
spec written and validated against the architecture, implementation, QA, an adversarial code
review, and CI against a fresh IRIS container before anything merged. An orchestrator ran two
epics at a time, each against its own IRIS instance, with its own throwaway containers for tests.
Nothing a reviewer found was allowed to quietly disappear: each finding was fixed in the story,
routed to a named later story, or declined with a written reason, and the deferred-work ledger that
tracks them holds more than 1,100 entries.

**My job was the decisions.** I set the priorities, answered the questions the agents escalated,
and used the nightly build the way an administrator would. Several things in this article started
as notes from that use - the agent not opening the screen we were talking about, columns too narrow
to read, sign-out hard to find - and each became a story and shipped within a day.

By the numbers: close to 2,000 commits, 138 validated story specs, 287 `%UnitTest` classes, and
every planning document in the repository under `_bmad-output/`, if you want to see what the method
produces.

## Install it in three minutes

With Docker, and nothing else:

```bash
git clone https://github.com/jbrandtmse/OcuPilot.git
cd OcuPilot
docker compose up -d --wait
```

Open <http://localhost:52774/ocupilot/> and sign in as `_SYSTEM` / `SYS` - the first install clears
the password expiry Community Edition ships with. OcuPilot then walks you through connecting a
model: pick a provider, paste a key, press Test connection, save and enable.

To add OcuPilot to an instance you already have, install it with IPM in the namespace you want:

```objectscript
zpm "install ocupilot"
```

One thing to know before you install it anywhere that matters: OcuPilot switches instance auditing
on if it is off, and registers its own audit events. That is deliberate - an agent write that could
not be audited would defeat the point - but it is a change to the instance's security posture, so
the README lists exactly what the installer adds.

## Community ideas

OcuPilot implements two ideas from the InterSystems Ideas portal:
[DPI-I-516](https://ideas.intersystems.com/ideas/DPI-I-516), *Integration with LLMs like GPT,
llama*, and [DPI-I-574](https://ideas.intersystems.com/ideas/DPI-I-574), *AI analysis of error
logs*. Next on the list is [DPI-I-966](https://ideas.intersystems.com/ideas/DPI-I-966), letting the
Logs area open older `messages.log` files.

## What is next

Improvements continue through the voting week: a try-it console in the REST API explorer, a
read-back line that shows the instance now holds what a change wrote, a performance row on Home,
impact lines on removals ("3 users hold this role"), and older `messages.log` files. Longer term,
the goal is parity with the classic portal - namespaces, databases, journals, a code and SQL
explorer, and Interoperability.

## Try it

- Live demo: [ocupilot.org](https://ocupilot.org) (`demo` / `ocupilot-demo`)
- Source and install guide: [github.com/jbrandtmse/OcuPilot](https://github.com/jbrandtmse/OcuPilot)
- Open Exchange: <!-- OPEN EXCHANGE LINK -->

I would love to hear what you would ask an agent like this to do on your own instances - and what
you would never let it do. If OcuPilot is useful to you, I would be grateful for your vote in the
contest.
