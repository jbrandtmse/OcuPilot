# /epic-cycle project overlay (OcuPilot)

The base kit's Step 3c and the parallel kit's Edit 5.7 re-apply these entries after every kit install, so OcuPilot's additions to the generated command and overrides survive an upgrade. Project rules that need no text inside those files live in `_bmad/custom/skill-rules.md`, under "Project-specific rules", and the base kit carries that section over itself.

The two `-off` entries leave verification-gap and intent-alignment as the implement stage's self-review; the Opus code-review stage still runs all four of its layers (`_bmad/custom/bmad-code-review.toml`). Switching edge-case-hunter off also drops the implement stage's spec-claims check, which BMAD sends to that layer alone; code review's edge-case-hunter still receives it. The two layers filed 45 to 65 findings per story that the implement stage then spent 30 to 60 minutes patching, most of them re-raised by code review. To restore either layer, delete its entry and re-run the base kit.

## runner-skeleton-slot: Runner Spawn Skeleton item 10 quotes the runner's slot block (project Rule 21)
- file: .claude/commands/epic-cycle.md
- anchor: 9. Completion contract: "Before you write it, integrate forward
- position: after

```text
10. **Slot** (OcuPilot project Rule 21 — a project addition to this skeleton, re-applied after any base-kit re-render): quote the assigned slot's block from `_bmad/custom/parallel.yaml` `slots:` verbatim — `mcp_profile`, `dev_container`, dev ports and every `throwaway` parameter — with the sentence "Every IRIS MCP call you or any stage you spawn makes carries `server: "<mcp_profile>"`; every `smoke.sh --container` and every `docker exec` against the dev instance names `<dev_container>`; every throwaway you or any stage brings up uses exactly these `--dir --project --web --super` values, `OCUPILOT_BROWSER_ORIGIN` and `--container`; every stage prompt you write repeats this block. The profile `ocupilot-iris` does not exist." Record the assignment in `dispatch.yaml` (`slot: <name>`) before the spawn.
```

## implement-blind-hunter-off: the implement stage self-reviews with two layers, so blind-hunter is off (owner decision 2026-09-20)
- file: _bmad/custom/bmad-build-auto.toml
- anchor: id = "blind-hunter"
- position: replace
- until: """

```text
id = "blind-hunter"
name = "Blind Hunter"
instruction = ""
```

## implement-edge-case-hunter-off: the implement stage self-reviews with two layers, so edge-case-hunter is off (owner decision 2026-09-20)
- file: _bmad/custom/bmad-build-auto.toml
- anchor: id = "edge-case-hunter"
- position: replace
- until: """

```text
id = "edge-case-hunter"
name = "Edge Case Hunter"
instruction = ""
```
