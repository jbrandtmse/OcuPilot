# Human in the loop, twice: building an AI co-pilot for IRIS with the BMAD Method

<!-- Draft of the second contest article. Before publishing: confirm the Tsvetkov quote and its
attribution on the LinkedIn post, ideally with his permission and a tag, and restore his British
spelling of the bracketed word; re-count stories on the day; add the two visuals marked below and
the article 1 link. -->

*How I used the BMAD Method and AI agents to build OcuPilot in nineteen days - and why a person
stayed in the loop the whole way.*

After this year's InterSystems READY event in Asia, Aleksandr Tsvetkov of Banksia Global wrote
something that has stayed with me:

> "We'd put a human-in-the-loop approval step into our agent project almost as an afterthought. At
> the Summit that's the part every serious conversation kept coming back to - not the AI. It
> reframed the problem for me: in agentic AI the hard, interesting engineering isn't getting a
> model to call tools, it's making that safe and observable enough that a regulated
> [organization] would actually switch it on."

He is right, and it matches what I found. For the last three weeks I have been building
[OcuPilot](https://ocupilot.org), an AI co-pilot for the IRIS Management Portal, for the "Build
Your Own Management Portal" contest. Its main feature is an agent that is allowed to change an IRIS
instance. In OcuPilot, the approval step came first: it was written into the design before any code
existed.

That is what the [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) is good at. And the
same approach that made the product safe also shaped how it was built: AI agents did the work, and a
person made the decisions. Human in the loop, twice.

## A real test, not a demo

At READY 2026 in April I gave a session called *Agentic Engineering Live on Stage*, where we built a
loan application on IRIS, live, from a single product brief
([READY-2026-LoanDemo](https://openexchange.intersystems.com/package/READY-2026-LoanDemo)). The
slide that summed up the talk said: **BMAD Method = Context Engineering** - give agents the right
context, and they do the right work.

A stage demo is a controlled experiment. OcuPilot was not. It had a hard deadline, a portal with six
areas to rebuild, an agent that can change security settings, and nineteen days from the first
commit to the submission. In fairness: it also reused code and lessons from four of my earlier IRIS
projects, and the agents worked day and night.

## Agentic engineering is not vibe coding

Vibe coding is asking a model for code and hoping it works. Agentic engineering is giving agents the
context a good engineer would have - what we are building, for whom, how it should look and how it
must be built - and holding every change to that.

BMAD is a free, open-source method for doing that. AI agents take the roles of analyst, product
manager, architect, UX designer and developer, and each writes a document the next one builds on. I
ran it in Claude Code. BMAD describes its own goal as to *"turn an idea or change request into
working software without giving up the thinking."* The thinking is the part people skip, so that is
where I started.

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

The safety engineering Tsvetkov describes lives in that architecture. Two of its decisions, word
for word:

- *"Confirm is reachable only from the browser, and the write gate is on the write."* The agent can
  suggest a change. Only the person at the keyboard can approve it.
- *"The model is assumed compromised by anything it reads."* We assume anything the agent reads may
  try to trick it - so a trick can never make a change on its own. Every change is still a proposal
  a person has to approve.

And the agent's changes are marked in the IRIS audit database, where administrators already look.

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
streams of work side by side, each with its own IRIS instance, so their tests never collided.

The results:

- A typical story took **about three hours**.
- About **6 stories a day** with one stream of work, about **11 a day** with two, and **16 a day**
  by the end.
- By the submission, more than 140 of the plan's 229 stories were done - and because of the way the
  plan was ordered, everything that shipped is complete.

<!-- VISUAL: stories finished per day, 9 to 25 September. -->

BMAD now has its own build loop. Mine adds the two parallel streams and the review list below. If
you are starting out, try BMAD's first.

## Nothing gets lost

An earlier version of this workflow taught me the problem: review comments pile up and are quietly
forgotten. On that project, the list of things to fix "later" grew to 1,588 items in 114 days and
never once got shorter.

So on OcuPilot every problem a reviewer found had to go somewhere: fixed right away, assigned to a
later story or a scheduled clean-up pass, or turned down with a written reason. The list is reviewed
at the end of every epic.

More than 1,100 findings went through it. Nearly half were fixed. About a third were turned down
with a written reason. About a fifth are waiting on a named later story or the clean-up pass. Only a
handful have no decision yet.

## What the agents got wrong

Agents are not careful by default; the process has to make them careful. Four things we learned the
hard way:

- **They grade their own work generously.** Early on, a separate reviewer found tests that could
  never fail, which the agent that wrote them had reported as proof. Since then, no agent's claim
  about its own work counts until something independent has checked it.
- **They treat symptoms.** One early story took nearly two days because the agents kept making a
  test wait longer instead of asking why it was slow. The real cause was a small mistake in how the
  test re-read its data. Now a story that keeps failing stops and comes back to me.
- **They write too much.** One story's spec grew to 664 KB - about the length of a novel. A longer
  spec is not a better one; it is more for a reviewer to argue with. So we keep them short on
  purpose.
- **A cheaper model was a false saving.** When we moved the coding work to a smaller model, 5 of its
  12 stories had to be redone, against 1 of 9 on the larger one. It moved back.

## The human in the loop, in the build

I kept the decisions that matter: priorities, scope, security, what goes to the main branch, and
what gets published. After the first week, I let the agents settle routine questions themselves and
report what they decided. I did not read every line of code - that is what the reviews and tests are
for. I read the plans, decided the questions that came back to me, and used the product.

The decisions that changed the product were mine. I moved the OAuth 2.0 screens ahead of other work,
because the contest named them. I decided that an administrator may grant powerful roles through
the agent, always with a confirmation - while the agent still cannot lock you out of your own
instance. And I made sure a new user could try the agent's changes the first time, without extra
setup.

Using the product was part of the process too. I ran the latest build with real AI provider keys,
the way an administrator would. Nine problems came out of that, and eight became stories and
shipped, some within hours. None of them showed up in the tests: some needed a real AI provider, and
some were things you only notice by using the screen.

It is the same pattern as the product: the agents propose, and a person confirms.

## If you are starting with BMAD on IRIS

- **Plan before you build.** A clear architecture lets you say no to changes that do not fit.
- **Make safety a design decision, not a feature.** If it is not in the design, it will be an
  afterthought.
- **Give every review comment a home.** Fix it, schedule it, or explain why not.
- **Test against a real IRIS,** early and on every change.
- **Keep people on the decisions that cannot be undone:** what ships, what gets published, and
  anything that touches security.

## Try it, and read the record

- The live demo: [ocupilot.org](https://ocupilot.org), sign in as `demo` / `ocupilot-demo`.
- The code and every planning document:
  [github.com/jbrandtmse/OcuPilot](https://github.com/jbrandtmse/OcuPilot).
- The first article, on what OcuPilot does: <!-- LINK TO ARTICLE 1 -->
- Open Exchange: [OcuPilot](https://openexchange.intersystems.com/package/OcuPilot)

If you are trying BMAD on IRIS, I would like to hear what has worked for you and what has not. And
if OcuPilot is useful to you, I would be grateful for your vote in the contest.
