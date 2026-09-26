# Human in the loop, twice: building an AI co-pilot for IRIS with the BMAD Method

<!-- Draft of the second contest article. Before publishing: confirm the Tsvetkov attribution on the
LinkedIn post and restore his British spelling of the bracketed word in the quote (the repository's
spelling check forces the bracket here); re-count stories on the day; add the two visuals marked
below and the article 1 and Open Exchange links. -->

After InterSystems READY 2026 Asia, Aleksandr Tsvetkov of Banksia Global wrote something that has
stayed with me:

> "We'd put a human-in-the-loop approval step into our agent project almost as an afterthought. At
> the Summit that's the part every serious conversation kept coming back to - not the AI. It
> reframed the problem for me: in agentic AI the hard, interesting engineering isn't getting a
> model to call tools, it's making that safe and observable enough that a regulated
> [organization] would actually switch it on."

I agree. And I would add one thing: that kind of engineering does not happen by accident.

For the last three weeks I have been building [OcuPilot](https://ocupilot.org), an AI co-pilot for
the IRIS Management Portal, for the "Build Your Own Management Portal" contest. Its main feature is
an agent that is allowed to change an IRIS instance. In OcuPilot, the human approval step was never
an afterthought. It was written into the design on the first day, before there was any code to get
it wrong.

That is what the [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) is for. And the same
approach that made the product safe also shaped how the product was built: AI agents did the work,
and a human made the decisions. Human in the loop, twice.

## Why OcuPilot is a fair test

I have been advocating BMAD for a while. At READY 2026 in April I gave a session called *Agentic
Engineering Live on Stage*, where we built a loan application on IRIS, live, from a single product
brief ([READY-2026-LoanDemo](https://openexchange.intersystems.com/package/READY-2026-LoanDemo)).
The slide I kept coming back to said simply: **BMAD Method = Context Engineering.** I also maintain
the [IRIS MCP Server Suite](https://openexchange.intersystems.com/package/IRIS-MCP-Server-Suite-2),
which is how the agents in this story worked with IRIS directly.

A stage demo is a controlled experiment. OcuPilot was not. It had a hard deadline, a portal with six
areas to rebuild, and an agent that can change security settings - and nineteen days from the first
commit to the submission.

## Agentic engineering is not vibe coding

Vibe coding is asking a model for code and hoping it works. Agentic engineering is giving agents the
context a good engineer would have - what we are building, for whom, how it should look and how it
must be built - and holding every change to it.

BMAD describes its own goal as to *"turn an idea or change request into working software without
giving up the thinking."* The thinking is the part people skip, so that is where I started.

## Planning first

From installing BMAD to writing the first line of code took about 28 hours of clock time - and a
couple of hours of my own effort, answering the agents' questions and making the decisions only I
could make. The agents did the rest.

In that time, a one-page idea became:

- **research** into the existing portal, including a list of 538 features ranked by priority;
- **a product brief and requirements**, which showed the full scope was more than twice what the
  time allowed - so instead of cutting features, we ordered the work so that we could stop after any
  stage and still have something complete to submit;
- **a UX design**, with every screen's states and every piece of text a user will see;
- **an architecture** of binding decisions that every later change had to respect;
- **a plan** of 22 epics, broken into small stories.

The safety engineering Tsvetkov describes lives in that architecture, written down before any code
existed. Three of its decisions, word for word:

- *"Confirm is reachable only from the browser, and the write gate is on the write."* The agent can
  suggest a change. Only the person at the keyboard can approve it.
- *"Prohibited actions are absent from the tool set, not gated within it."* There are things the
  agent simply cannot ask to do.
- *"The model is assumed compromised by anything it reads."* Nothing the agent reads on a screen
  can turn into an instruction.

Add one more: every change the agent makes is recorded in the IRIS audit database, where
administrators already look.

None of that was bolted on later. Every story was checked against it.

<!-- VISUAL: the planning documents as a chain - idea, research, brief and requirements, UX,
architecture, plan - with the day each was finished. -->

## Building, one story at a time

Every story went through the same steps:

1. An agent plans the story, and the plan is checked against the architecture.
2. An agent builds it.
3. The agent proves each part works by breaking it on purpose and watching the test catch it.
4. A second agent reviews the work, looking for problems.
5. The tests run against a real, fresh IRIS instance before anything is merged.

I published the command that runs this cycle as
[bmad-epic-cycle-command](https://github.com/jbrandtmse/bmad-epic-cycle-command). It ran two
streams of work side by side, each with its own IRIS instance, so they never got in each other's
way.

The results:

- **More than 140 stories** finished for the submission, at about **three hours** each.
- About **6 stories a day** with one stream of work, and **up to 16 a day** with two.

<!-- VISUAL: stories finished per day, 9 to 25 September. -->

BMAD has since added its own version of this cycle, and I expect the two ideas to come together.

## Nothing gets lost

On most AI-assisted projects I have seen, review comments pile up and are quietly forgotten. On an
earlier project, the list of things to fix "later" grew to more than 1,500 items and never once got
shorter.

So on OcuPilot every problem a reviewer found had to go somewhere: fixed right away, assigned to a
specific later story, or turned down with a written reason. The list is reviewed at the end of every
epic.

More than 1,100 findings went through that list. Nearly half were fixed, and every one of the rest
has an owner or a reason. Only a handful are still open.

## What the agents got wrong

Agents are not careful by default; the process has to make them careful. Four things we learned the
hard way:

- **They grade their own work generously.** Early on, a separate reviewer found tests that could
  never fail, which the agent that wrote them had reported as proof. Since then, no agent's claim
  about its own work counts until something independent has checked it.
- **They treat symptoms.** One early story took 43 hours because the agents kept making a test wait
  longer instead of asking why it was slow. The real cause was a small mistake in how the test
  re-read its data. Now a story that keeps failing stops and comes back to me.
- **They write too much.** One story's spec grew to 664 KB. A longer spec is not a better one - it is
  more for a reviewer to argue with - so we keep them short on purpose.
- **Cheaper models were not cheaper.** Moving the coding work to a smaller model made nothing faster
  and meant more rework, so it moved back.

## The human in the loop, in the build

I kept the decisions that matter: priorities, scope, security, what goes to the main branch, and
what gets published. After the first week, I let the agents settle routine questions themselves and
report what they decided.

The decisions that changed the product were mine. I moved the OAuth 2.0 screens ahead of other work,
because the contest named them. I decided that an administrator should be able to grant powerful
roles, with a confirmation - *"remember this is a developer tool first."* And I made sure a new user
could try the agent's changes the first time, without extra setup.

Using the product was part of the process too. I ran the latest build with real AI provider keys,
the way an administrator would. Nine problems came out of that. Eight became stories and shipped,
some within hours. The automated tests could never have found them, which is exactly why a person
stays in the loop.

It is the same pattern as the product: the agents propose, and a human confirms.

## What I would tell a team starting with BMAD on IRIS

- **Plan before you build.** A clear architecture lets you say no to changes that do not fit.
- **Make safety a design decision, not a feature.** If it is not in the design, it will be an
  afterthought.
- **Give every review comment a home.** Fix it, schedule it, or explain why not.
- **Do not trust a test you have not seen fail.**
- **Keep documents short.** More words are not more quality.
- **Test against a real IRIS,** early and on every change.
- **Keep people on the decisions that cannot be undone:** what ships, what gets published, and
  anything that touches security.

## Try it, and read the record

- The live demo: [ocupilot.org](https://ocupilot.org), sign in as `demo` / `ocupilot-demo`.
- The code and every planning document:
  [github.com/jbrandtmse/OcuPilot](https://github.com/jbrandtmse/OcuPilot).
- The first article, on what OcuPilot does: <!-- LINK TO ARTICLE 1 -->
- Open Exchange: <!-- OPEN EXCHANGE LINK -->

I would love to hear how your teams approach this - and what you would never let an agent do on your
own instance. If OcuPilot or this way of working is useful to you, I would be grateful for your vote
in the contest.
