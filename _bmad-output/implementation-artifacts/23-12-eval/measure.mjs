#!/usr/bin/env node
// Story 23.12, Task 0 (a) and Task Z: the token cost of a turn's first provider request.
//
//   node measure.mjs                          writes measure-before.json
//   node measure.mjs --out measure-after.json writes the "after" figures
//
// Case N is a turn with no screen open; case B a tasks/schedule turn with a one-row context. Each
// runs through the armed turnprobe stub (OcuPilot.Test.TurnProvider) on ocupilot-ci, and its first
// recorded call is rendered through each dialect's own builder (Anthropic, OpenAI and Gemini
// CallMessages). The Anthropic body is counted with count_tokens on claude-haiku-5-5. Figures only.

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomBytes } from 'node:crypto';
import { api, containerFile, countTokens, log, marker, markers, os, preflight, redact, runIris, sleep, writeOutput, MODEL, CONTAINER } from './common.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const outArg = process.argv.indexOf('--out');
const OUT = path.resolve(HERE, outArg > 0 ? process.argv[outArg + 1] : 'measure-before.json');

const MESSAGE = 'Which tasks are suspended?';
/** A fixed row, so the B context is the same text before and after. */
const CONTEXT_ROW = { Name: 'Switch Journal', Type: 'System', Namespace: '%SYS', Description: 'Switches the journal file at midnight every day', Id: 1, LastFinished: '', NextScheduled: '2026-10-24 00:00:00', Suspended: false };
const CASES = [
  { id: 'N', context: null },
  { id: 'B', context: { route: 'tasks/schedule', namespace: 'HSCUSTOM', view: { rows: [CONTEXT_ROW], rowsAvailable: 1 } } },
];
const DIR = '/tmp/eval2312m/';
const MAX_TOKENS = 32000;
const DIALECTS = ['Anthropic', 'OpenAI', 'Gemini'];
const FIXTURE = '##class(OcuPilot.Test.TurnWireFixture)';
const STUB = '##class(OcuPilot.Test.TurnProvider)';

const METHOD = {
  turn: 'POST /api/ocupilot/conversation, then POST /api/ocupilot/turn {message, conversationId[, context]} as _SYSTEM, polled on /turn/:id/progress until terminal',
  stub: 'OcuPilot.Test.TurnWireFixture.EnsureDefinition(tag) (turnprobe, default marker), OcuPilot.Test.TurnProvider.Plain(tag), first call read with OcuPilot.Test.TurnProvider.Recorded(tag, 1, "system"|"messages"|"tools")',
  render: `OcuPilot.Kernel.Provider.{Anthropic,OpenAI,Gemini}.CallMessages(%Net.HttpRequest, .values, .messages, .tools, system) on a fresh adapter (Streaming 0), values model=${MODEL} maxTokens=${MAX_TOKENS}; messages and tools rebuilt from the recorded call (role/content or blocks with the tail cache_control removed; name/description/inputSchema, start = not defer_loading, scoped when any tool is deferred). OpenAI goes through MessageAdapter.CanonicalToOpenAi and ToolDefAdapter.ToOpenAi, Gemini through MessageAdapter.CanonicalToGemini and ToolDefAdapter.ToGemini`,
  chars: 'bodyChars = $Length of the UTF-8-decoded entity body; bodyBytes = its UTF-8 bytes; toolsChars = $Length(body.tools.%ToJSON()); tools = Anthropic and OpenAI tools.%Size(), Gemini tools[0].functionDeclarations.%Size()',
  countTokens: `POST https://api.anthropic.com/v1/messages/count_tokens, anthropic-version 2023-06-01, {model: ${MODEL}, system, messages, tools} of the rendered Anthropic body (max_tokens dropped)`,
  proxies: 'listing = $ClassMethod(OcuPilot.Kernel.Agent.Loop.DispatchClass(), "Advertise", .tools); descriptionChars = sum of $Length(tools(n, "description")); prompt = $Length(OcuPilot.Kernel.Agent.Prompt.Builtin())',
};

function check(output, name, expect = '1') {
  const value = marker(output, name);
  if (value !== expect) throw new Error(`${name} answered ${value}: ${output.slice(-1500)}`);
}

function renderLines(tag, caseId) {
  return [
    `Set tag=${os(tag)},dir=${os(DIR)},case=${os(caseId)}`,
    'Do ##class(%File).CreateDirectoryChain(dir)',
    `Set sys=${STUB}.Recorded(tag,1,"system"),mj=${STUB}.Recorded(tag,1,"messages"),tj=${STUB}.Recorded(tag,1,"tools")`,
    'Set msgs=##class(%DynamicAbstractObject).%FromJSON(mj),tools=##class(%DynamicAbstractObject).%FromJSON(tj)',
    `Kill M,T,V Set V("model")=${os(MODEL)},V("maxTokens")=${MAX_TOKENS}`,
    'Set n=msgs.%Size(),M=n For i=1:1:n { Set m=msgs.%Get(i-1),M(i,"role")=m.role If m.%GetTypeOf("content")="string" { Set M(i,"content")=m.content } Else { Set b=##class(%DynamicAbstractObject).%FromJSON(m.content.%ToJSON()) If i=n { Do b.%Get(b.%Size()-1).%Remove("cache_control") } Set M(i,"blocks")=b.%ToJSON() } }',
    'Set n=tools.%Size(),T=n,dc=0 For i=1:1:n { Set t=tools.%Get(i-1),T(i,"name")=t.name,T(i,"description")=t.description,T(i,"inputSchema")=t."input_schema".%ToJSON() If t."defer_loading" { Set dc=dc+1 } Else { Set T(i,"start")=1 } }',
    'If dc>0 Set T("scoped")=1',
    'Write "OCU-SHAPE-START:",+$Get(M),"|",+$Get(T),"|",dc,":OCU-SHAPE-END",!',
    'For cls="Anthropic","OpenAI","Gemini" { Set a=$ClassMethod("OcuPilot.Kernel.Provider."_cls,"%New"),r=##class(%Net.HttpRequest).%New(),sc=a.CallMessages(r,.V,.M,.T,sys),raw="" Do r.EntityBody.Rewind() While \'r.EntityBody.AtEnd { Set raw=raw_r.EntityBody.Read(32000) } Set body=$ZConvert(raw,"I","UTF8"),o=##class(%DynamicAbstractObject).%FromJSON(body),f=##class(%Stream.FileBinary).%New() Do f.LinkToFile(dir_case_"-"_cls_".json"),f.Write(raw),f.%Save() Set tc=0,tl=0 If $IsObject(o.tools) { Set tl=$Length(o.tools.%ToJSON()),tc=$Select(cls="Gemini":o.tools.%Get(0).functionDeclarations.%Size(),1:o.tools.%Size()) } Write "OCU-R-START:",cls,"|",$System.Status.IsOK(sc),"|",$Length(body),"|",$Length(raw),"|",tl,"|",tc,":OCU-R-END",! If cls="Anthropic" { Write "OCU-SAME-START:",(o.system=sys),"|",(o.messages.%ToJSON()=mj),"|",(o.tools.%ToJSON()=tj),":OCU-SAME-END",! } }',
  ];
}

const PROXY_LINES = [
  'Kill A Set sc=$ClassMethod(##class(OcuPilot.Kernel.Agent.Loop).DispatchClass(),"Advertise",.A),ds=0,rs=0,rc=0,sd="" For i=1:1:+$Get(A) { Set d=$Length($Get(A(i,"description"))),ds=ds+d If $Extract(A(i,"name"),*-4,*)="_read" { Set rs=rs+d,rc=rc+1 } If A(i,"name")="tasks_schedule_read" { Set sd=A(i,"description") } }',
  'Write "OCU-PROXY-START:",$System.Status.IsOK(sc),"|",+$Get(A),"|",ds,"|",rc,"|",rs,"|",$Length(##class(OcuPilot.Kernel.Agent.Prompt).Builtin()),":OCU-PROXY-END",!',
  'Write "OCU-SCHED-START:",sd,":OCU-SCHED-END",!',
];

async function awaitTurn(turnId, seconds = 180) {
  const deadline = Date.now() + seconds * 1000;
  while (Date.now() < deadline) {
    const progress = await api('GET', `/turn/${encodeURIComponent(turnId)}/progress`);
    if (progress.status !== 200) throw new Error(`progress answered ${progress.status} ${JSON.stringify(progress.body)}`);
    if (['completed', 'stopped', 'abandoned', 'failed'].includes(progress.body.state)) return progress.body;
    await sleep(1000);
  }
  throw new Error(`turn ${turnId} did not end within ${seconds} s`);
}

async function measureCase(tag, spec) {
  const reset = runIris([
    `Do ${STUB}.Forget(${os(tag)}) Set sc=${STUB}.Plain(${os(tag)}) Write "OCU-PLAIN-START:"_$System.Status.IsOK(sc)_":OCU-PLAIN-END",!`,
  ]);
  check(reset, 'PLAIN');
  const conversation = await api('POST', '/conversation');
  if (conversation.status !== 201) throw new Error(`conversation answered ${conversation.status} ${JSON.stringify(conversation.body)}`);
  const body = { message: MESSAGE, conversationId: conversation.body.conversationId };
  if (spec.context) body.context = spec.context;
  const start = await api('POST', '/turn', body);
  if (start.status !== 202) throw new Error(`turn answered ${start.status} ${JSON.stringify(start.body)}`);
  const view = await awaitTurn(start.body.turnId);
  if (view.state !== 'completed') throw new Error(`case ${spec.id}: the stub turn ended ${view.state} ${JSON.stringify(view.error)}`);

  const output = runIris(renderLines(tag, spec.id));
  const shape = marker(output, 'SHAPE');
  if (!shape) throw new Error(`case ${spec.id}: the recorded call was not rebuilt: ${output.slice(-2000)}`);
  const [messages, tools, deferred] = shape.split('|').map(Number);
  const result = { turnState: view.state, recordedCall: 1, messages, tools, deferredTools: deferred, startingSetTools: tools - deferred, dialects: {} };
  for (const row of markers(output, 'R')) {
    const [dialect, ok, bodyChars, bodyBytes, toolsChars, toolCount] = row.split('|');
    if (ok !== '1') throw new Error(`case ${spec.id}: ${dialect}.CallMessages failed: ${output.slice(-2000)}`);
    result.dialects[dialect.toLowerCase()] = { bodyChars: Number(bodyChars), bodyBytes: Number(bodyBytes), toolsChars: Number(toolsChars), tools: Number(toolCount) };
  }
  if (Object.keys(result.dialects).length !== DIALECTS.length) throw new Error(`case ${spec.id}: not every dialect rendered: ${output.slice(-2000)}`);
  const [sameSystem, sameMessages, sameTools] = (marker(output, 'SAME') ?? '').split('|');
  result.anthropicRenderEqualsRecorded = { system: sameSystem === '1', messages: sameMessages === '1', tools: sameTools === '1' };
  const anthropicBody = JSON.parse(containerFile(`${DIR}${spec.id}-Anthropic.json`));
  result.countTokens = await countTokens(anthropicBody);
  return result;
}

async function main() {
  const startedAt = new Date().toISOString();
  const pre = await preflight();
  log(`preflight: ${CONTAINER} on ${pre.port}, readiness ${pre.readiness}`);
  const prefs = await api('GET', '/account/preferences');
  if ((prefs.body.shell ?? []).some((row) => row.name === 'agentDefinition')) throw new Error('_SYSTEM has an agentDefinition pick, which would take the turn away from the stub definition; clear it first');

  const tag = `EVAL2312M${randomBytes(3).toString('hex')}`;
  let mark = null;
  let prior = '';
  const record = { story: '23.12', file: path.basename(OUT), startedAt, container: CONTAINER, model: MODEL, message: MESSAGE, contextRow: CONTEXT_ROW, method: METHOD, cases: {}, proxies: null };
  try {
    const arm = runIris([
      `Set sc=${FIXTURE}.RemoveDefinition("") Write "OCU-RM0-START:"_$System.Status.IsOK(sc)_":OCU-RM0-END",!`,
      `Write "OCU-PRIOR-START:"_${FIXTURE}.MarkedDefault()_":OCU-PRIOR-END",!`,
      `Write "OCU-MARK-START:"_${FIXTURE}.StateMark()_":OCU-MARK-END",!`,
      `Set sc=${FIXTURE}.EnsureDefinition(${os(tag)},.id) Write "OCU-DEF-START:"_$System.Status.IsOK(sc)_"|"_id_":OCU-DEF-END",!`,
    ]);
    check(arm, 'RM0');
    prior = marker(arm, 'PRIOR') ?? '';
    mark = Number(marker(arm, 'MARK'));
    if (!Number.isInteger(mark)) throw new Error(`StateMark answered: ${arm.slice(-1500)}`);
    if (!(marker(arm, 'DEF') ?? '').startsWith('1|')) throw new Error(`EnsureDefinition answered: ${arm.slice(-1500)}`);

    for (const spec of CASES) {
      record.cases[spec.id] = await measureCase(tag, spec);
      log(`case ${spec.id}: ${JSON.stringify(record.cases[spec.id])}`);
    }

    const proxy = runIris(PROXY_LINES);
    const values = (marker(proxy, 'PROXY') ?? '').split('|');
    if (values[0] !== '1') throw new Error(`the listing was not advertised: ${proxy.slice(-1500)}`);
    record.proxies = {
      advertisedTools: Number(values[1]),
      descriptionChars: Number(values[2]),
      readTools: Number(values[3]),
      readToolDescriptionChars: Number(values[4]),
      promptChars: Number(values[5]),
      tasksScheduleReadDescription: marker(proxy, 'SCHED'),
    };
    log(`proxies: ${JSON.stringify(record.proxies)}`);
  } finally {
    const lines = [];
    if (Number.isInteger(mark)) lines.push(`Write "OCU-SWEEP-START:"_${FIXTURE}.SweepSince(${mark},"_SYSTEM")_":OCU-SWEEP-END",!`);
    lines.push(`Set sc=${FIXTURE}.RemoveDefinition(${os(prior)}) Write "OCU-RM-START:"_$System.Status.IsOK(sc)_":OCU-RM-END",!`);
    lines.push(`Do ${STUB}.Forget(${os(tag)}) Write "OCU-LEFT-START:"_${STUB}.Remains(${os(tag)})_":OCU-LEFT-END",!`);
    lines.push(`Do ##class(%File).RemoveDirectoryTree(${os(DIR)}) Write "OCU-DIR-START:"_##class(%File).DirectoryExists(${os(DIR)})_":OCU-DIR-END",!`);
    const teardown = runIris(lines);
    record.teardown = { sweepLeft: marker(teardown, 'SWEEP'), definitionRemoved: marker(teardown, 'RM') === '1', stubNodesLeft: marker(teardown, 'LEFT'), renderDirLeft: marker(teardown, 'DIR') };
    log(`teardown: ${JSON.stringify(record.teardown)}`);
  }
  record.endedAt = new Date().toISOString();
  writeOutput(OUT, `${JSON.stringify(record, null, 2)}\n`);
  log(`wrote ${OUT}`);
}

main().catch((error) => {
  console.error(redact(error));
  process.exitCode = 1;
});
