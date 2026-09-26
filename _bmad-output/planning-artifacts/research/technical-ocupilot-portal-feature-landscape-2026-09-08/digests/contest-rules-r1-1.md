# Contest rules and judging — round 1 — 2026-09-08

Sources consulted: 8

Source key (all accessed 2026-09-08):
- S1 https://openexchange.intersystems.com/contest/48 — Open Exchange contest page (Angular app; dates read from embedded JSON via curl). Publisher: InterSystems Open Exchange. Undated.
- S2 https://community.intersystems.com/post/intersystems-programming-contest-build-your-own-management-portal — official announcement, Anastasia Dyubaylo (Lead of Developer Community). Pub 2026-09-07.
- S3 https://openexchange.intersystems.com/assets/doc/contest-terms.md — InterSystems Competition Terms (legal). Undated.
- S4 https://community.intersystems.com/post/kick-webinar-intersystems-programming-contest-build-your-own-management-portal — kick-off webinar announcement, Anastasia Dyubaylo. Pub 2026-09-08 (showed "27 minutes ago" at fetch).
- S5 https://community.intersystems.com/post/technology-bonuses-results-intersystems-full-stack-programming-contest-2026 — Technology Bonuses Results, Full Stack Contest 2026, Evgeny Shvarov. Pub 2026-02-20. PRECEDENT ONLY, not this contest.
- S6 https://docs.openexchange.intersystems.com/contest/apply/ — "Applying for the contest", Open Exchange docs. Undated.
- S7 https://community.intersystems.com/intersystems-online-programming-contest-terms — community-site Contest Terms (generic legal). Undated.
- S8 https://community.intersystems.com/post/time-vote-intersystems-programming-contest-ai-agents-fhir — "Time to vote" post, AI Agents for FHIR contest, Anastasia Dyubaylo. Pub 2026-06-08. PRECEDENT ONLY for vote mechanics.

## Findings — claims

**Claim:** The task statement. Verbatim: "Create a GUI powered by InterSystems IRIS management APIs for the following Management Portal tasks: / Manage web apps and explore REST APIs / Permission management / Security and Secrets management (with wallet, x509 creds, OAuth setup, etc.) / Task management / Operating system management (processes, disks, CPU, memory, devices, etc.) / All the logs - what's being reported to the user from various sub-systems / Feel free to add any other screens or actions you frequently use!" The six areas are framed as *the* task; extra screens are explicitly optional. The post does not say whether an entry covering only some of the six is acceptable — approval is at experts' discretion (see next claim). | **Source:** S2 (verbatim); S1 carries the shorter form "Create a GUI powered by InterSystems IRIS management APIs for certain Management Portal tasks." | **Publisher:** InterSystems DC / Open Exchange | **Pub date:** 2026-09-07 / undated | **Accessed:** 2026-09-08 | **Confidence:** high (two sources) | **Class:** contest-rule

**Claim:** Entry approval is discretionary. Verbatim: "NB. Our experts will have the final say on whether the application is approved for the contest, based on the criteria of complexity and usefulness. This decision is final and not subject to appeal." and "Our team will review all applications before approving them for the contest." | **Source:** S2 | **Publisher:** InterSystems DC | **Pub date:** 2026-09-07 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** contest-rule

**Claim:** General Requirements (MUST), verbatim from S2:
1. "An application or library must be fully functional. It should not be an import or a direct interface for an already existing library in another language (except for C++, there you really need to do a lot of work to create an interface for IRIS). It should not be a copy-paste of an existing application or library."
2. "Accepted applications: new to Open Exchange apps or existing ones, but with a significant improvement."
3. "The application should work on either IRIS Community Edition or IRIS for Health Community Edition." (host versions from the Evaluation site, or containers from InterSystems Container Registry, or "intersystemsdc/iris-community:latest" / "intersystemsdc/irishealth-community:latest").
4. "The application should be Open Source and published on GitHub or GitLab."
5. "The README file for the application should be in English, include the installation steps, and include either a video demo or a description of how the application works."
6. "Only 3 submissions by a single developer/team are allowed."
S1 restates the same set (fully functional; original — "no copy-pasting or simple imports (except for C++ integrations)"; new or significantly improved; IRIS / IRIS for Health / IRIS Cloud SQL; open source on GitHub or GitLab; 3 submissions). | **Source:** S2 + S1 | **Publisher:** InterSystems | **Pub date:** 2026-09-07 / undated | **Accessed:** 2026-09-08 | **Confidence:** high (two sources) | **Class:** contest-rule

**Claim:** The Open Exchange page adds a README element the community post does not: verbatim "Include an English README with installation steps, a link to the idea, and either a video demo or a detailed app description." The phrase "a link to the idea" appears only on S1 (likely a generic OE contest-page template line inherited from Ideas-driven contests). Treat as single-source; low cost to satisfy by linking an Ideas Portal idea in the README. | **Source:** S1 | **Publisher:** InterSystems Open Exchange | **Pub date:** undated | **Accessed:** 2026-09-08 | **Confidence:** medium (single-source) | **Class:** contest-rule

**Claim:** Judging criteria (S1 only). Verbatim: "Note: All submissions will be judged on Complexity, Clarity of Instructions, Developer Experience, Applicability, and Usability. The review team's decisions are final." S2 states only that "A specially selected jury will determine the winners" for the Experts Nomination. | **Source:** S1; S2 | **Publisher:** InterSystems | **Pub date:** undated / 2026-09-07 | **Accessed:** 2026-09-08 | **Confidence:** medium (criteria list single-source) | **Class:** contest-rule

**Claim:** Prizes, verbatim structure from S2. Prize pool "$12,000". Experts Nomination: 1st $5,000; 2nd $2,500; 3rd $1,000; 4th $500; 5th $300; 6-10th $100. Community Nomination ("The applications with the most community votes will win"): 1st $600; 2nd $400; 3rd $100. "[NEW] Freshmen Nomination": 1st $600; 2nd $400; 3rd $100. Freshmen eligibility verbatim: "You've participated in no more than 5 previous InterSystems programming contests." and "You've never placed 1st, 2nd, or 3rd in either the Experts or Community Nomination in any previous contest." Ties: "If several participants receive the same number of votes, they will all be considered winners, and the prize money will be shared among them." "Cash prizes are awarded only to participants who can verify their identity." | **Source:** S2 | **Publisher:** InterSystems DC | **Pub date:** 2026-09-07 | **Accessed:** 2026-09-08 | **Confidence:** high (S1 shows a "Prizes and Awards" heading but no amounts rendered — single-source for the amounts) | **Class:** contest-rule

**Claim:** Eligibility and teams. Verbatim: "Any Developer Community member can participate, except InterSystems employees. InterSystems contractors are welcome to join." "Teams can include 2 to 5 members." "If you participate as a team, make sure to include links to the Developer Community profiles of all team members in your application's README." | **Source:** S2 | **Publisher:** InterSystems DC | **Pub date:** 2026-09-07 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** contest-rule

**Claim:** Work may continue after the deadline. Verbatim: "You can continue improving your application throughout both the submission and voting periods." Precedent S8 confirms the practice: "contest participants are allowed to fix the bugs and make improvements to their applications during the voting week". | **Source:** S2; S8 | **Publisher:** InterSystems DC | **Pub date:** 2026-09-07; 2026-06-08 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** contest-rule

**Claim:** Submission mechanics. The app must already be a published Open Exchange listing before applying. Verbatim (S6): "There are several ways to apply for a contest, but your app must already be published on Open Exchange before the application: Visit the contest page, click the apply button, and select the app you want to apply with. / Go to your app's public page and apply via the Contest tab. / In the developer portal, navigate to all your apps, find the desired app, and apply through the dropdown menu." S3 adds: "You must submit your applications through the Contest website or the specified online judging system." and "Deliberately obfuscated source code is not allowed." S3: to enter, you must first create an Open Exchange profile. | **Source:** S6; S3 | **Publisher:** InterSystems Open Exchange | **Pub date:** undated | **Accessed:** 2026-09-08 | **Confidence:** high (two sources) | **Class:** contest-rule

**Claim:** Community vote mechanics (precedent, not yet published for this contest). Verbatim from S8: "All active members of the Developer Community with a 'trusted' status in their profile are eligible to vote in the Community nomination." "Blind vote! The number of votes for each app will be hidden from everyone. We will publish the leaderboard in the comments to this post once a day." "The order of projects on the contest page will be as follows: the earlier an application was submitted to the competition, the higher it will be on the list." "An experienced jury from InterSystems will choose the best apps to nominate for the prizes in the Experts Nomination." One vote per member, changeable ("cancel the choice and give your vote to another application"). | **Source:** S8 | **Publisher:** InterSystems DC | **Pub date:** 2026-06-08 | **Accessed:** 2026-09-08 | **Confidence:** medium (precedent from the immediately preceding contest; this contest's voting post will not exist until ~2026-09-28) | **Class:** contest-rule

**Claim:** No technology-bonuses post exists for this contest as of 2026-09-08. Searches of community.intersystems.com (WebSearch, Perplexity with 1-month recency) returned no "Technology Bonuses ... Build Your Own Management Portal" post; S2's "Related posts" lists only the kick-off webinar. The immediately preceding contest (AI Agents for FHIR) did have "Technology Bonuses for ..." and "Technology Bonus Results ..." posts (titles seen in S8's related-posts block), so a bonuses post for this contest is likely but unconfirmed. | **Source:** S2; S8 | **Publisher:** InterSystems DC | **Pub date:** 2026-09-07; 2026-06-08 | **Accessed:** 2026-09-08 | **Confidence:** high that none exists yet; low on what it will contain | **Class:** contest-rule

**Claim:** Precedent bonus list (Full Stack Contest 2026, S5 — NOT this contest): Vector Search 3; Embedded Python / Native SDK for Python 3; Developer Community Idea 2; Docker 2; IPM 2; Online Demo 2; Find a Bug 2; First Article on DC 2; Second Article on DC 1; Video on YouTube 3; YouTube Short 1; First Time Contribution 3; stated maximum 26. No "Angular", "REST API", "AI/LLM", "Code Quality" or "Management API" bonus appeared in that list. S5 does not state how bonus points combine with votes. | **Source:** S5 | **Publisher:** InterSystems DC | **Pub date:** 2026-02-20 | **Accessed:** 2026-09-08 | **Confidence:** high for that contest; not transferable as a rule | **Class:** contest-rule

**Claim:** Suggested starting templates (both S2 and S4): iris-fullstack-template, iris-dev-template, rest-api-contest-template (Open Exchange packages). Also linked from S2: "Build a Server-Side Application with InterSystems IRIS" course, "Learning Path for beginners", IPM videos, "How to publish an application on Open Exchange", and S6. | **Source:** S2; S4 | **Publisher:** InterSystems DC | **Pub date:** 2026-09-07; 2026-09-08 | **Accessed:** 2026-09-08 | **Confidence:** high (two sources) | **Class:** contest-rule

**Claim:** Kick-off webinar: "September 14, 2026 — 12:00 pm EDT | 6:00 pm CEST"; speakers Derek Gervais (Developer Relations Evangelist), Raj Singh (Product Manager of Developer Experience), Carmen Logue (Product Manager of Analytics and AI); registration via Meetup. The post contains no technical scoping beyond the templates. | **Source:** S4 | **Publisher:** InterSystems DC | **Pub date:** 2026-09-08 | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** contest-rule

**Claim:** No rule restricts frameworks, mandates REST, or forbids reuse of InterSystems portal code/UI assets, in any page read (S1, S2, S3, S4, S6, S7). The only originality constraints are the "fully functional / not an import / not a copy-paste" requirement (S1, S2) and the general "Deliberately obfuscated source code is not allowed" (S3). S3 grants InterSystems rights over submissions (IP section, per S7 summary) — read S3 in full before publishing proprietary code. | **Source:** S1, S2, S3, S7 | **Publisher:** InterSystems | **Pub date:** various | **Accessed:** 2026-09-08 | **Confidence:** medium (absence of evidence across six pages) | **Class:** contest-rule

**Claim:** No specific open-source license is named anywhere read; the requirement is only "Open Source and published on GitHub or GitLab" (S2) / "Must be Open Source" (S1). | **Source:** S1, S2, S3, S6, S7 | **Publisher:** InterSystems | **Pub date:** various | **Accessed:** 2026-09-08 | **Confidence:** medium | **Class:** contest-rule

**Claim:** Contest-specific Rules override the generic Terms. Verbatim (S3): "If there is a conflict between these Terms and the Rules, the Rules have priority." and "InterSystems may modify the opening and closing dates for registration by an informational notice on the applicable Contest website. You are responsible for frequently reviewing Contest details on the applicable Contest website." | **Source:** S3 | **Publisher:** InterSystems | **Pub date:** undated | **Accessed:** 2026-09-08 | **Confidence:** high | **Class:** contest-rule

## Timeline table

| event | date | days from 2026-09-08 | sources |
| --- | --- | --- | --- |
| Announcement post published | 2026-09-07 | -1 | S2 (1) |
| Kick-off webinar post published | 2026-09-08 | 0 | S4 (1) |
| Contest begins / registration opens | 2026-09-14 00:00 EST | 6 | S2 ("September 14, 2026 (00:00 EST): Contest begins."); S1 ("Registration Starts: 14 Sep, 2026, 12:00:00 AM EST"; JSON `Start":"2026-09-14 00:00:00`) (2) |
| Kick-off webinar | 2026-09-14 12:00 EDT / 18:00 CEST | 6 | S4 (1); S2 links to it |
| Submission deadline | 2026-09-27 23:59 EST | 19 | S2 ("September 27, 2026 (23:59 EST): Deadline for submissions."); S1 JSON `End":"2026-09-27 23:59:59` (2) |
| Voting begins | 2026-09-28 00:00 EST | 20 | S2; S1 JSON `Start":"2026-09-28 00:00:00` (2) |
| Voting ends | 2026-10-04 23:59 EST | 26 | S2 ("October 4, 2026 (23:59 EST): Voting ends."); S1 JSON `End":"2026-10-04 23:59:59` (2) |
| Winners announcement | not stated | — | none found in S1, S2, S4 |
| Technology-bonuses post | not yet published | — | none found |

Working window: 19 calendar days to the deadline, of which the first 6 are before the contest formally opens (the app can be built now, but the Open Exchange listing must exist and be applied through the contest page once registration opens — S6, S1).

## Bonus/points table

No bonus list has been published for contest 48 as of 2026-09-08. Precedent from the most recent bonus post read (Full Stack Contest 2026, S5, 2026-02-20) — NOT binding for this contest:

| bonus | points | source |
| --- | --- | --- |
| Vector Search | 3 | S5 |
| Native SDK for Python / Embedded Python | 3 | S5 |
| Developer Community Idea | 2 | S5 |
| Docker | 2 | S5 |
| IPM | 2 | S5 |
| Online Demo | 2 | S5 |
| Find a Bug | 2 | S5 |
| First Article on DC | 2 | S5 |
| Second Article on DC | 1 | S5 |
| Video on YouTube | 3 | S5 |
| YouTube Short | 1 | S5 |
| First Time Contribution | 3 | S5 |
| (stated maximum) | 26 | S5 |

Items the brief asked about that did NOT appear in S5's list: Angular, AI/LLM, Code Quality, REST API, Online Demo was present. A prior AI-themed contest (AI Agents for FHIR) had its own bonuses post (title only seen in S8) — its list was not read this run.

## Leads

- **Bonuses post watch.** The Technology Bonuses post for this contest will most likely appear around 2026-09-14 (kick-off) — precedent: the AI Agents for FHIR contest had "Technology Bonuses for ..." and "Technology Bonus Results ..." posts (S8 related-posts block). Re-run this dimension on or after 2026-09-14; search community.intersystems.com for "Technology Bonuses" + "Management Portal". Until then, the safe assumption from S5 precedent is that Docker, IPM, Online Demo, DC article(s), YouTube video, and Embedded Python each carry 1–3 points.
- **Kick-off webinar recording (2026-09-14)** — speakers include Raj Singh (Developer Experience PM) and Carmen Logue (Analytics and AI PM); the AI PM's presence is a weak signal that AI features may be discussed/bonused. Watch/record and mine for any scoping of the six functional areas and which "management APIs" InterSystems expects (e.g. /api/mgmnt, /api/monitor, %SYS Config/Security classes) — no page read this run named any specific API.
- **"Link to the idea" README line (S1 only).** Cheap to satisfy: post or reference an Ideas Portal idea and link it. Also in S5 precedent, "Developer Community Idea" is a 2-point bonus, so this probably doubles as a bonus.
- **Contradiction to track:** S1 lists "IRIS Cloud SQL" as an allowed platform; S2 lists only IRIS Community / IRIS for Health Community. S2 is more recent and specific; build against the Community containers named in S2.
- **Winners announcement date** — not stated anywhere; historically follows voting close. Open question.
- **Judging criteria** ("Complexity, Clarity of Instructions, Developer Experience, Applicability, and Usability") appear only on S1 and read like the standard OE contest template; confirm whether the experts publish rubric weights.
- **Comment on S2** (Anton Yartsev, 2026-09-07/08): asked whether Community Bounty Program participation counts toward Freshmen eligibility — unanswered at fetch time. Relevant only if the team wants the Freshmen nomination.
- **IP grant in S3/S7** — S7 summary mentions "intellectual property rights grants" and Massachusetts governing law; read S3's IP section before publishing under a permissive license.

## Gaps

- **No technology-bonuses post for this contest** — searched twice (WebSearch on community.intersystems.com; Perplexity with 1-month recency on community + openexchange domains). Not yet published.
- **No FAQ page** specific to this contest was found; S2 directs questions to the Discord contest channel or post comments.
- **No definition of "management APIs"** — none of S1, S2, S4 names /api/mgmnt, /api/monitor, /api/atelier, %SYS classes or any other API. The choice of API surface is left to the entrant.
- **All six functional areas are required** - stated at the 2026-09-14 kick-off webinar (owner's report, recorded 2026-09-16); the pages read on 2026-09-08 carried only the discretionary "complexity and usefulness" approval standard (S2).
- **Prize amounts are single-source (S2)** — S1 shows a "Prizes and Awards" heading but the amounts did not render through curl or WebFetch.
- **Vote counting for this contest** — only precedent (S8); this contest's "Time to vote" post is expected ~2026-09-28.
- **Winners announcement date** — not found.
- **Open Exchange contest page dates are only in embedded JSON** (`Start/End` pairs), not rendered text; the visible page shows only "Registration Starts: 14 Sep, 2026". Treated as a valid second source because the JSON is served by the same InterSystems page.
- The AI Agents for FHIR technology-bonuses list (the most AI-relevant precedent) was not read — budget exhausted.
