# Human in the loop, twice: building an AI co-pilot for IRIS with the BMAD Method

<!-- Draft of the second contest article. Before publishing: confirm the Tsvetkov attribution on the
LinkedIn post and restore his British spelling of the bracketed word in the quote (the repository's
spelling check forces the bracket here); re-count stories and commits on the day; add the visuals marked below and
the Open Exchange link. -->

Coming back from InterSystems READY 2026 Asia, Aleksandr Tsvetkov of Banksia Global wrote something
that has stayed with me:

> "We'd put a human-in-the-loop approval step into our agent project almost as an afterthought. At
> the Summit that's the part every serious conversation kept coming back to - not the AI. It
> reframed the problem for me: in agentic AI the hard, interesting engineering isn't getting a
> model to call tools, it's making that safe and observable enough that a regulated
> [organization] would actually switch it on."

I agree with every word, and I want to add one thing: that engineering does not happen by accident.
For the last three weeks I have been building [OcuPilot](https://ocupilot.org), an AI co-pilot for
the IRIS Management Portal, for the "Build Your Own Management Portal" contest. Its central feature
is an agent that is allowed to change an IRIS instance - and in OcuPilot, the human-in-the-loop step
was never an afterthought. It was decided in the architecture on the first day, before any code
existed to get it wrong.

That is what the [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) is for. And the
approach that made the product's agent safe is the same one that governed how the product itself was
built: AI agents doing the work, under a spec, a review and a human who decides. Human in the loop,
twice.

## Why OcuPilot is a fair test

I have been advocating BMAD for a while. At READY 2026 in April I gave a session called *Agentic
Engineering Live on Stage*, where we built a loan broker application on IRIS from a single product
brief, live, in 45 minutes
([READY-2026-LoanDemo](https://openexchange.intersystems.com/package/READY-2026-LoanDemo)). The
slide I kept coming back to said simply: **BMAD Method = Context Engineering.** I also maintain the
[IRIS MCP Server Suite](https://openexchange.intersystems.com/package/IRIS-MCP-Server-Suite-2),
which is how the agents in this story compiled, tested and inspected IRIS.

A stage demo is a controlled experiment. OcuPilot was not. It had a contest deadline, a portal with
six areas to rebuild, five OAuth 2.0 editors, an agent that proposes changes to security settings -
and nineteen days from first commit to submission.

## Agentic engineering is not vibe coding

Vibe coding asks a model for code and hopes. Agentic engineering gives agents durable context - a
brief, requirements, a UX contract, an architecture - and holds every change to it. BMAD, the
Breakthrough Method for Agile AI-Driven Development, describes its own aim as to *"turn an idea or
change request into working software without giving up the thinking."* The thinking is the part
people skip, so that is where I will start.

## Planning in 28 hours

From installing BMAD (v6.12.0) to the first line of code took about 28 hours of clock time - and a
couple of hours of my own effort, answering the agents' questions and making the decisions only I
could make. The agents did the rest. In those 28 hours:

- **Analysis.** A 500-word idea became a research report of 17,000 words across 46 sources, and a
  catalog of **538 portal features in five priority bands**. Nothing is ever deleted from that
  catalog; features we will not build move to the long tail, with the reason. A time-boxed spike of
  about two hours settled how authentication would work before anyone designed a screen.
- **Planning.** A product brief with eight decisions marked "not reopened here", then a PRD with 80
  functional and 14 non-functional requirements. The PRD's feasibility review put the scope at
  **about 45 developer-days, against 19 calendar days**. I kept the scope and made the build order
  the cut line: the epics were ordered so that *"the boundary between two epics is exactly a point
  at which the project could stop and still submit."*
- **UX.** A design system - 128 color roles across light and dark, 42 components - and an experience
  contract with every screen's states and one canonical table of every string a user sees.
- **Solutioning.** An architecture spine of 47 binding decisions. It opens with a warning I wish
  every architecture document carried: *"An AD skimmed is an AD violated."*
- **Epics and stories.** 22 epics and 206 stories, ordered so that the six contest areas and the
  path from question to audit record landed first.

The safety engineering Tsvetkov describes lives in that spine, as decisions with numbers:

- AD-40: *"Confirm is reachable only from the browser, and the write gate is on the write."*
- AD-10: *"Prohibited actions are absent from the tool set, not gated within it."*
- AD-11: *"The model is assumed compromised by anything it reads. The defense is these five
  checkable rules, not a posture."*
- And every write an agent makes is marked in the IRIS audit database, where an administrator
  already looks.

None of that was retrofitted. Every story was checked against it, and when a story needed to change
a decision, it amended the spine in the open. The spine holds 56 decisions today; the nine added
since went in the same way.

<!-- VISUAL: the planning artifacts as a chain - idea, research and catalog, brief, PRD, UX,
architecture spine, epics - with the day each was finished. -->

## Implementation as a loop, not a chat

Every story went through the same cycle, run by a Claude Code command I published as
[bmad-epic-cycle-command](https://github.com/jbrandtmse/bmad-epic-cycle-command):

1. **Plan** the story into a spec, and validate the spec against the architecture.
2. **Implement** it, with Claude Code as the developer.
3. **Prove** each acceptance criterion with a mutation - break the code on purpose and watch the
   test turn red.
4. **QA**, then an **adversarial code review** by a separate agent.
5. **Adjudicate** every review finding (more on that below), run a smoke test against a live IRIS,
   then **CI** against a fresh IRIS container.

At the end of each epic: a burn-down gate, a decision sheet for me, and a merge gate.

An orchestrator ran two epics at a time, each against its own IRIS instance with its own throwaway
containers for tests, following a dependency graph I approved. My standing instruction when the
orchestrator's analysis and mine disagreed: *"take the more conservative graph."*

The results, counted from the logs:

- **More than 140 stories** done for the submission build, at a median of **3.0 hours** from plan to
  commit.
- About **6 stories a day** with one runner, about **10.7 a day** with two, and **16 a day** over the
  last three days.
- **1,956 commits**, two thirds of them bookkeeping - the process recording itself as it went.

<!-- VISUAL: stories completed per day, 9 to 25 September, with the switch from one runner to two
marked. -->

BMAD has since grown its own version of this loop - v6.11 made "Build" the official implementation
phase, and a new BMad Loop module runs a whole epic unattended. `/epic-cycle` is one practitioner's
take on the same idea, with a parallel orchestrator and a ledger; I would expect the two to
converge.

## Nothing a reviewer finds is allowed to disappear

Code review on this project reported about 63 high, 680 medium and 1,460 low findings across 131
stories. What happens to them is the part most AI-assisted projects get wrong.

The epic-cycle kit carries a field report from an earlier project whose deferred-work list went from
*"0 → 1,588 entries in 114 days, never once shrinking."* So in OcuPilot every finding is born with an
owner, and the rule that governs it says: *"The drain is a stage, not a sentence."* Each finding is
fixed in the story, routed to a named later story, or declined with a written reason, and every epic
ends with a burn-down gate.

The ledger holds 1,136 entries today. 47% are resolved, 22% were declined with a reason, 21% are
routed to a named story, and the rest are by design, theoretical or dropped. Three are open.

<!-- VISUAL: one real ledger entry, showing its owner, its evidence line and its status history. -->

Two other rules did most of the quality work:

- **A test whose red has not been observed is not evidence.** QA recorded 322 demonstrated
  mutations.
- **Review findings per story went down as the rules went up:** the mean number of high and medium
  findings per review fell from 9.1 in the first epic to 3.9 in the parallel run. I read that as the
  rules accumulating, not as the agents getting smarter, but that is my inference.

About one story in five still needed a rework after its first pass; CI caused most of those.

## What went wrong, and what each taught

**Gates that could not fail.** In the first three stories, review found a test gate in each that
could never go red: a claimed fix re-applied as a mutation left all 27 tests green; a check for
external URLs split every line at the `//` inside `https://`; tests ran as `_SYSTEM`, whose `%All`
role bypassed the very resource being tested. The lesson: an agent's report of its own verification
is not verification.

**The 43-hour story.** Story 1.4 took nine implementation attempts and five review rounds, all
treating a Task Manager "latency" with longer waits. The real cause was `%OpenId` handing back an
object the polling loop still held in memory - it never re-read anything. Its spec reached 664 KB.
That story gave the loop an exit, gave the project a rule about stale object references, and gave
CLAUDE.md a section on prose discipline: *"Every sentence a reviewer can file a finding against is
surface area; keep the surface small."*

**Eighteen test runs at once.** One agent launched 18 test classes against the same instance in a
single message. Two of them raced on the same probe database and left it mounted with no file
behind it, and seven test classes could not run until the instance was restarted. Rule: one test
run at a time, at any depth.

**Green suites over broken paths.** Our test suite runs as a privileged user, which is convenient
and dangerous. A commit message from that week records the common cause of four defects that had
passed every test: *"a suite that runs as %All cannot see a privilege-shaped defect."* Another test
searched a random token for a three-character value, and passed or failed by chance: *"A needle as
short as `432` turns up inside random material often enough to redden an otherwise green run."*

**Models and money.** 92.8% of our spend was on the top model tier, so we moved implementation to a
cheaper model. Stories got no faster, and reworks and CI failures went up. Implementation moved
back.

## The human in the loop, in the build

What I kept: priorities, scope, security posture, merges to `main`, and publishing. What I delegated
after the first week: routine clarifications, which the orchestrator answered under a standing grant
and logged for me to read.

The decisions that changed the product were mine:

- ranking the OAuth 2.0 editors ahead of the agent refinements, because the contest named OAuth
  setup explicitly;
- lifting the ban on granting privileged roles four minutes after deciding to keep it - *"remember
  this is a developer tool first"* - so the portal can do what an administrator needs, behind a
  confirmation;
- making new agent definitions able to propose changes by default, so a judge succeeds the first
  time.

And using the product was part of the loop. I ran the nightly build on a spare instance with real
model keys. Nine findings came out of that; eight became stories and shipped. Two provider defects
went from my report to a merged fix in about seven hours, and a dropped-connection fix in under six.
CI could never have found them - it stubs the model providers - which is exactly why a human stays
in the loop.

It is the same pattern as the product: the agents propose, a human confirms.

## What I would tell a team starting with BMAD on IRIS

- **Plan until the architecture can say no.** Make it a contract, not a backlog.
- **Make safety an architecture decision, not a feature.** If it is not in the spine, it will be an
  afterthought.
- **Give every review finding an owner** and a stage that drains the list.
- **Demand observed reds.** Distrust any green that no deliberate break has tested.
- **Keep specs and comments small.** Narration becomes review surface.
- **Put a real IRIS in the loop:** throwaway containers, CI against a fresh instance, and MCP tools
  so the agents can compile and test for themselves.
- **Keep humans on what cannot be undone:** merges to production, publishing, security posture.

## Try it, and read the record

- The live demo: [ocupilot.org](https://ocupilot.org), sign in as `demo` / `ocupilot-demo`.
- The code and every planning document, under `_bmad-output/`:
  [github.com/jbrandtmse/OcuPilot](https://github.com/jbrandtmse/OcuPilot).
- The first article, on what OcuPilot does: <!-- LINK TO ARTICLE 1 -->
- Open Exchange: <!-- OPEN EXCHANGE LINK -->
- The BMAD Method, the epic-cycle kits, READY-2026-LoanDemo and the IRIS MCP Server Suite, linked
  above.

I would love to hear how your teams are approaching this - and what you would never let an agent do
on your instance. If OcuPilot or this approach is useful to you, I would be grateful for your vote in
the contest.
