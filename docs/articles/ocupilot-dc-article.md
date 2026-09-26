# OcuPilot: ask, review, confirm, audit - an AI co-pilot for the IRIS Management Portal

<!-- Draft for the InterSystems Developer Community, for the "Build Your Own Management Portal"
contest. Release, IPM package, both clean installs and the demo's Epic 11 features were checked on
2026-09-26. Add the screenshots marked below and the contest tag. -->

The Management Portal is where most of us administer IRIS, and it has grown over many releases.
When InterSystems asked the community to [build our own management
portal](https://openexchange.intersystems.com/contest/48), I wanted to answer two questions at
once: what would the portal look like if we started it today, and what would it take to let an AI
agent help run an IRIS instance without having to trust it?

The result is **OcuPilot**: a rebuilt portal for the six areas the contest names, with an agent
beside every screen. It can explain what you are looking at and change settings for you - but only
after you have reviewed the change and pressed Confirm.

## Try it in two minutes

Open **[ocupilot.org](https://ocupilot.org)** and sign in as `demo` with the password
`ocupilot-demo`. It runs on a real IRIS for Health instance.

- **No model key needed.** The demo's agent runs on Claude Opus 5.5.
- **Changes take a moment.** A request that makes a change can take up to a minute.
- **It is shared.** Everyone uses the same instance, so if `/csp/myapp` is already enabled, ask the
  agent to disable it first. It resets every hour, on the hour, and is offline for a few minutes
  while it does.
- **Please do not type anything private.**

<!-- SCREENSHOT: the portal with the agent panel open beside the Web applications list. -->

## A portal for the six areas

OcuPilot covers every area the contest asks for, with lists, row actions and full editors working
against live instance data:

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

The layout will feel familiar if you use VS Code: areas on the left, the screen in the middle and
the agent on the right. There is a command palette (`Ctrl+K` or `⌘K`), favorites and recent items,
resizable columns, help on every screen, and a light and a dark theme.

## Ask about what you are looking at

The agent always knows which screen you are on. When you ask a question, it gets that screen's
filter, selection and the rows in front of you, so questions like these are answered from your own
data:

- "Which of these web applications allow unauthenticated access?"
- "Why is this task suspended, and is it safe to resume?"
- "What does this audit record mean?"

Every screen offers an **Explain this screen** prompt and a few suggested questions, and you can
ask the agent to explain any log line, application error or audit record. When it names rows in its
answer, they can come back as chips: click one and the screen selects that row.

If a conversation is about another screen, the agent opens it. Ask "create a web application for my
new REST service" from Home, and it takes you to Web applications first.

## Ask, review, confirm, audit

This is the part I cared about most. An agent that can change an instance is only useful if you
never have to wonder what it did. So in OcuPilot the agent never makes a change by itself. It can
read, and it can propose. The change happens only when you press Confirm - a request the agent
cannot make; it has to come from your own signed-in session.

Here is the whole path, using the web application the demo ships disabled.

**1. Ask.** On Web applications, type: *"Enable /csp/myapp and give it the %Development
resource."* (That resource means only users who hold `%Development` can use the application.)

**2. Review.** A proposal card appears in the panel. Its before-and-after comparison is worked out
by the instance from a fresh read of `/csp/myapp` - not written by the model. It shows each field
that will change, the privilege the change needs, and how to undo it.

<!-- SCREENSHOT: the proposal card with the before-and-after comparison and the privilege line. -->

**3. Confirm.** When you press Confirm, OcuPilot checks again, on the server, that you still hold
the privilege, that `/csp/myapp` has not changed since the proposal was made, and that the change is
allowed. Then it makes the change **as you**, with your own roles, never an elevated account. A
proposal can be confirmed once and expires after ten minutes.

**4. Audit.** The Web applications list refreshes and marks `/csp/myapp` as Changed, and the change
is recorded in the IRIS audit database as an `OcuPilot/Security/AgentWrite` event. So the answer to
"what did the agent change last week?" lives where your auditors already look. If auditing is ever
switched off, the panel says so plainly, and each change shows "audit not marked".

<!-- SCREENSHOT: the refreshed list with the Changed marker, and the audit database filtered to agent
writes. -->

## Guardrails that live on the instance

Everything above is enforced by the server, not the browser, and some changes are refused however
they are asked for. OcuPilot will not disable or delete `_SYSTEM`, the signed-in user, the accounts
the instance's own services run as, or the last holder of `%All`; and it will not break its own
applications, roles or processes. The refusal says why - for example: *"This is the last account
that holds %All. Disabling it, deleting it or taking the role off it would leave nobody able to
administer this instance."*

An administrator can also turn the agent off for everyone, hold it read-only, switch it off for
one user, and limit how many rows of a screen it may see.

The agent never sees more than your screen shows, and sometimes less. Stored passwords, keys and
wallet secrets are never sent to it; when a change needs a secret - a new user's password, say - the
proposal card asks you for it, and it travels only with your Confirm. The variables IRIS captures
with an application error stay on your screen too, because on IRIS for Health they can hold patient
data. And a **Share screen context** switch in the panel turns sharing off entirely.

## Bring your own model

OcuPilot works with Anthropic, OpenAI, Google Gemini, or any OpenAI-compatible endpoint. The last
one is the privacy option: point it at Ollama, vLLM or LM Studio on your own network, mark it local,
and no screen data or log text leaves your network. The README has a short guide to getting a key
for each provider.

## How it is built

OcuPilot is one install served by IRIS itself: an Angular application at `/ocupilot` and an
ObjectScript REST API behind it, with no separate server to run. Most screens work through IRIS's
own `/api/admin` service, called inside IRIS rather than over the network. Each screen is declared
once, and that one declaration serves both the screen and the agent's matching tool. The agent's
work runs in a background job that can only read and propose; its proposals are stored on the
instance, which is how Confirm can tell whether the target has changed since. Every code change runs
through the full test suite against a fresh IRIS container before it is merged.

<!-- DIAGRAM: the README's architecture diagram. -->

## How I built it

I built OcuPilot with the [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD), which I have
been advocating for a while, with Claude Code as the development agents. The safety you read about
above - the Confirm step, the refusals, the audit record - was written into the design before any
code existed, and every piece of work was checked against it. Every planning document is in the
repository, and I tell that story in a follow-up article.

## Install it yourself

With Docker installed:

```bash
git clone https://github.com/jbrandtmse/OcuPilot.git
cd OcuPilot
docker compose up -d --wait
```

The first start downloads IRIS for Health Community and installs OcuPilot, which takes a few
minutes. Then open <http://localhost:52774/ocupilot/> and sign in as `_SYSTEM` / `SYS` - the first
install clears the password expiry Community Edition ships with. OcuPilot then walks you through
connecting a model: pick a provider, paste a key, press Test connection, save and enable.

To add OcuPilot to an instance you already have - IRIS or IRIS for Health 2026.2 or later, with IPM
0.10.0 or later - install it in the namespace you want (not `%SYS`):

```objectscript
zpm "install ocupilot"
```

If IPM answers that no repositories are configured, run `zpm "enable -community"` once, then
install again.

One thing to know before you install it anywhere that matters: OcuPilot switches instance auditing
on if it is off, and registers its own audit events. That is deliberate - agent changes that could
not be audited would defeat the point - but it is a change to the instance's security settings, so
the README lists exactly what the installer adds.

## Community ideas

OcuPilot implements [DPI-I-516](https://ideas.intersystems.com/ideas/DPI-I-516), *Integration with
LLMs like GPT, llama*, and the on-demand part of
[DPI-I-574](https://ideas.intersystems.com/ideas/DPI-I-574), *AI analysis of error logs*: the agent
explains any error or log entry you point it at. Next is
[DPI-I-966](https://ideas.intersystems.com/ideas/DPI-I-966), opening older `messages.log` files.

## What it does not do yet

OcuPilot does not yet cover namespaces, database configuration, journals, mirroring or
Interoperability; for those, the classic portal is still there. Improvements continue through the
voting week - among them a way to send a test request from the REST API explorer, and a line on
each removal that says what depends on it ("3 users hold this role").

## Try it

- Live demo: [ocupilot.org](https://ocupilot.org) (`demo` / `ocupilot-demo`)
- Source and install guide: [github.com/jbrandtmse/OcuPilot](https://github.com/jbrandtmse/OcuPilot)
- Open Exchange: [OcuPilot](https://openexchange.intersystems.com/package/OcuPilot)

I would love to hear what you would ask an agent like this to do on your own instances - and what
you would never let it do. If OcuPilot is useful to you, I would be grateful for your vote in the
contest.
