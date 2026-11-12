#!/usr/bin/env node
// Story 23.12, Task 0 (b) and Task Z: the ten-question live evaluation on claude-haiku-5-5.
//
//   node eval.mjs setup    [--sheet score-before.md]  probe definition, seed, expected answers
//   node eval.mjs ask      [--sheet score-before.md]  asks the questions not yet asked; repeat
//                                                    until it reports all ten asked
//   node eval.mjs teardown [--sheet score-before.md]  always: removes everything, writes the sheet
//   node eval.mjs dry      [--sheet score-before.md]  setup then teardown, no question asked
//
// --sheet score-after.md runs the "after" phase. The phases are separate invocations so no single
// command outlives a ten-minute call; `ask` stops starting questions after ASK_BUDGET_SECONDS.
// State between invocations is eval-state-<phase>.json (figures and text only), removed by
// teardown. Spend is kept in spend.json, priced conservatively, and capped per the spec: no
// question starts once the phase is at $0.80, a turn is stopped before the phase passes $0.90, and
// Task 0 and Task Z together never pass $2.00.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { api, log, marker, markers, os, preflight, providerKey, redact, runIris, sleep, writeOutput, MODEL, CONTAINER, WEB_PORT } from './common.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);
let SHEET = 'score-before.md';
let COMMAND = '';
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--sheet') SHEET = argv[++i];
  else COMMAND = argv[i];
}
const PHASE = /after/i.test(SHEET) ? 'after' : 'before';
const STATE_FILE = path.join(HERE, `eval-state-${PHASE}.json`);
const LEDGER_FILE = path.join(HERE, 'spend.json');
const QUESTIONS = JSON.parse(fs.readFileSync(path.join(HERE, 'questions.json'), 'utf8')).questions;

const DEFINITION = { name: 'EVAL2312 probe', provider: 'anthropic', model: MODEL, credType: 'creds', credentialName: 'OcuPilotEval2312' };
const DEMO_TASK = 'OcuPilotDemo nightly purge';
const FALLBACK_TASK = 'EVAL2312 nightly check';
const SEED_TASKS = ['EVAL2312 suspended A', 'EVAL2312 suspended B', 'EVAL2312 suspended C'];
const WEEKLY_TASK = 'EVAL2312 weekly report';
const DISM_DIR = '/durable/eval2312/dism/';
const DISM_ROOT = '/durable/eval2312/';

const INPUT_PRICE = 0.625 / 1e6;
const OUTPUT_PRICE = 2.5 / 1e6;
const TEST_CALL_BOUND = { input: 5000, output: 1024 };
const PHASE_START_LIMIT = 0.8;
const PHASE_CAP = 0.9;
const TOTAL_CAP = 2.0;
const ASK_BUDGET_SECONDS = 360;
const TURN_TIMEOUT_SECONDS = 180;
const POLL_MS = 2000;
const REPLY_CHARS = 1200;

const price = (input, output) => input * INPUT_PRICE + output * OUTPUT_PRICE;
const usd = (value) => `$${value.toFixed(4)}`;
const now = () => new Date().toISOString();

// ---------------------------------------------------------------- state and spend

function loadState() {
  return fs.existsSync(STATE_FILE) ? JSON.parse(fs.readFileSync(STATE_FILE, 'utf8')) : null;
}

function saveState(state) {
  writeOutput(STATE_FILE, `${JSON.stringify(state, null, 2)}\n`);
}

function loadLedger() {
  if (fs.existsSync(LEDGER_FILE)) return JSON.parse(fs.readFileSync(LEDGER_FILE, 'utf8'));
  return {
    note: 'Live spend of Story 23.12 Task 0 and Task Z, priced conservatively: every input token at $0.625 a million, every output token at $2.50 a million. A Test connection call reports no usage and is priced at its bound.',
    caps: { phaseStart: PHASE_START_LIMIT, phase: PHASE_CAP, total: TOTAL_CAP },
    entries: [],
  };
}

function saveLedger(ledger) {
  writeOutput(LEDGER_FILE, `${JSON.stringify(ledger, null, 2)}\n`);
}

function spent(ledger, phase = null, except = null) {
  return ledger.entries.filter((e) => e !== except && (phase === null || e.phase === phase)).reduce((sum, e) => sum + e.cost, 0);
}

/** Whether another question may start: the phase below $0.80 and the total below $1.90. */
function mayStart(ledger) {
  return spent(ledger, PHASE) < PHASE_START_LIMIT && spent(ledger) < TOTAL_CAP - (PHASE_CAP - PHASE_START_LIMIT);
}

// ---------------------------------------------------------------- instance helpers

function check(output, name, expect = '1') {
  const value = marker(output, name);
  if (value !== expect) throw new Error(`${name} answered ${value}: ${output.slice(-1500)}`);
  return value;
}

async function read(tool, query = 'maxRows=1000') {
  const answer = await api('GET', `/screens/${tool}/read?${query}`);
  if (answer.status !== 200) throw new Error(`${tool} read answered ${answer.status} ${JSON.stringify(answer.body).slice(0, 400)}`);
  return answer.body;
}

async function expectStatus(promise, status, what) {
  const answer = await promise;
  if (answer.status !== status) throw new Error(`${what} answered ${answer.status} ${redact(JSON.stringify(answer.body)).slice(0, 600)}`);
  return answer.body;
}

const isFailedRun = (row) => Number(row.ErrNumber) > 0 || /ERROR #|^<[A-Z]+>/.test(String(row.Result ?? ''));

function msOf(isoLocal) {
  return Date.parse(`${String(isoLocal).replace(' ', 'T')}Z`);
}

// ---------------------------------------------------------------- seed

function dirsCheck() {
  const output = runIris([
    `Set dir=${os(DISM_DIR)},mgr=$ZConvert(##class(%File).NormalizeDirectory(##class(%File).ManagerDirectory()),"L")`,
    'Kill p Set sc=##class(Config.Databases).Get("IRISSYS",.p),sysdir=$ZConvert(##class(%File).NormalizeDirectory($Get(p("Directory"))),"L")',
    'Write "OCU-DIRS-START:",mgr,"|",sysdir,"|",($Extract(dir,1,$Length(mgr))=mgr),"|",($Extract(dir,1,$Length(sysdir))=sysdir),":OCU-DIRS-END",!',
  ], '%SYS');
  const [mgr, sysdir, inMgr, inSys] = (marker(output, 'DIRS') ?? '').split('|');
  if (!mgr || !sysdir || inMgr !== '0' || inSys !== '0') throw new Error(`${DISM_DIR} is not outside the manager (${mgr}) and IRISSYS (${sysdir}) directories: ${output.slice(-800)}`);
  return { managerDirectory: mgr, irissysDirectory: sysdir, outsideBoth: true };
}

function taskLines(names, daily) {
  const list = names.map(os).join(',');
  const schedule = daily ? 'Set t.TimePeriod=0,t.DailyStartTime=10800' : 'Set t.TimePeriod=1,t.TimePeriodDay="4",t.DailyStartTime=32400';
  return `For name=${list} { Set id="",rs=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM %SYS.Task WHERE %EXACT(Name) = ?",name) While rs.%Next() { Set id=rs.%Get("ID") } If id="" { Set t=##class(%SYS.Task).%New(),t.Name=name,t.Description="EVAL2312: Story 23.12 evaluation seed on a throwaway; it does nothing",t.NameSpace="%SYS",t.TaskClass="%SYS.Task.RunLegacyTask",t.TimePeriodEvery=1,t.DailyFrequency=0 ${schedule} Set d=##class(%SYS.Task.RunLegacyTask).%New(),d.ExecuteCode="Quit",sc=t.AssignSettings(d),d="" If $System.Status.IsOK(sc) { Set sc=t.%Save() } If $System.Status.IsOK(sc) { Set id=t.%Id() } Set t="" Write "OCU-TASKNEW-START:",name,"|",$System.Status.IsOK(sc),"|",id,":OCU-TASKNEW-END",! } Set ids(name)=id }`;
}

function seed(runId) {
  const suspendList = SEED_TASKS.map(os).join(',');
  const output = runIris([
    'Kill ids',
    taskLines(SEED_TASKS, true),
    taskLines([WEEKLY_TASK], false),
    `For name=${suspendList} { Set id=$Get(ids(name)) If id'="" { Set t=##class(%SYS.Task).%OpenId(id) If $IsObject(t),+t.Suspended'=1 { Set t.Suspended=1,sc=t.%Save() } Set t="" } }`,
    `Set id=$Get(ids(${os(WEEKLY_TASK)})) If id'="" { Set t=##class(%SYS.Task).%OpenId(id) If $IsObject(t),+t.Suspended'=0 { Set t.Suspended=0,sc=t.%Save() } Set t="" }`,
    `For name=${suspendList},${os(WEEKLY_TASK)} { Set id=$Get(ids(name)),t=$Select(id'="":##class(%SYS.Task).%OpenId(id),1:"") Write "OCU-TASK-START:",name,"|",id,"|",$Select($IsObject(t):+t.Suspended,1:"missing"),"|",$Select($IsObject(t):t.TimePeriod,1:""),":OCU-TASK-END",! Set t="" }`,
    `Set dir=${os(DISM_DIR)},res="%DB_EVAL2312DISM",sc=1 If '##class(Security.Resources).Exists(res) { Set sc=##class(Security.Resources).Create(res,"EVAL2312: Story 23.12 evaluation seed on a throwaway","","") } Write "OCU-RES-START:",$System.Status.IsOK(sc),":OCU-RES-END",!`,
    'Set ok=1 If \'##class(%File).DirectoryExists(dir) { Set ok=##class(%File).CreateDirectoryChain(dir) } Write "OCU-MKDIR-START:",ok,":OCU-MKDIR-END",!',
    'Set sc=1 If \'##class(SYS.Database).%ExistsId(dir) { Set sc=##class(SYS.Database).CreateDatabase(dir,1,8192,0,res,2) } Write "OCU-DBCREATE-START:",$System.Status.IsOK(sc),"|",$Select($System.Status.IsOK(sc):"",1:$System.Status.GetErrorText(sc)),":OCU-DBCREATE-END",!',
    'Set sc=1 If \'##class(Config.Databases).Exists("EVAL2312DISM") { Kill pr Set pr("Directory")=dir,sc=##class(Config.Databases).Create("EVAL2312DISM",.pr) } Write "OCU-DBCONF-START:",$System.Status.IsOK(sc),"|",$Select($System.Status.IsOK(sc):"",1:$System.Status.GetErrorText(sc)),":OCU-DBCONF-END",!',
    'Set db=##class(SYS.Database).%OpenId(dir),m=$Select($IsObject(db):+db.Mounted,1:-1),db="",sc=1 If m=1 { Set sc=##class(SYS.Database).DismountDatabase(dir) } Write "OCU-DISMOUNT-START:",$System.Status.IsOK(sc),"|",$Select($System.Status.IsOK(sc):"",1:$System.Status.GetErrorText(sc)),":OCU-DISMOUNT-END",!',
    'Set db=##class(SYS.Database).%OpenId(dir) Write "OCU-MOUNTED-START:",$Select($IsObject(db):+db.Mounted,1:"unopened"),":OCU-MOUNTED-END",! Set db=""',
    'Set sc=1 If \'##class(Config.ECPServers).Exists("EVAL2312SRV") { Kill sv Set sv("Address")="127.0.0.1",sv("Port")=1972,sc=##class(Config.ECPServers).Create("EVAL2312SRV",.sv) } Write "OCU-ECP-START:",$System.Status.IsOK(sc),"|",$Select($System.Status.IsOK(sc):"",1:$System.Status.GetErrorText(sc)),":OCU-ECP-END",!',
    'Set sc=1 If \'##class(Config.Databases).Exists("EVAL2312REMOTE") { Kill pr Set pr("Server")="EVAL2312SRV",pr("Directory")="/eval2312remote/",sc=##class(Config.Databases).Create("EVAL2312REMOTE",.pr) } Write "OCU-REMOTE-START:",$System.Status.IsOK(sc),"|",$Select($System.Status.IsOK(sc):"",1:$System.Status.GetErrorText(sc)),":OCU-REMOTE-END",!',
    `Set text="EVAL2312 "_${os(runId)}_" journal disk check failed" Do ##class(%SYS.System).WriteToConsoleLog(text,0,2) Write "OCU-CONSOLE-START:",text,":OCU-CONSOLE-END",!`,
    'Kill logged Set $NAMESPACE="USER" Try { Set z=0,x=1/z } Catch e { Set logged=$$LOG^%ETN() } Set $NAMESPACE="%SYS" Write "OCU-ETN-START:",$ListToString($Get(logged),"|"),":OCU-ETN-END",!',
    'Write "OCU-NOW-START:",$ZDateTime($Horolog,3),"|",$ZDateTime($ZTimeStamp,3),":OCU-NOW-END",!',
  ], '%SYS');
  const result = { tasks: [], created: markers(output, 'TASKNEW') };
  for (const row of markers(output, 'TASK')) {
    const [name, id, suspended, timePeriod] = row.split('|');
    result.tasks.push({ name, id, suspended, timePeriod });
  }
  for (const task of result.tasks) {
    const want = task.name === WEEKLY_TASK ? '0' : '1';
    if (task.id === '' || task.suspended !== want) throw new Error(`seed task ${task.name} reads id ${task.id} Suspended ${task.suspended}: ${output.slice(-1500)}`);
  }
  for (const name of ['RES', 'MKDIR']) check(output, name);
  for (const name of ['DBCREATE', 'DBCONF', 'DISMOUNT', 'ECP', 'REMOTE']) {
    const value = marker(output, name) ?? '';
    if (!value.startsWith('1|')) throw new Error(`seed step ${name} answered ${value}: ${output.slice(-1500)}`);
  }
  result.database = { name: 'EVAL2312DISM', directory: DISM_DIR, resource: '%DB_EVAL2312DISM', mounted: marker(output, 'MOUNTED') };
  if (result.database.mounted !== '0') throw new Error(`EVAL2312DISM reads Mounted ${result.database.mounted}`);
  result.ecpServer = { name: 'EVAL2312SRV', address: '127.0.0.1', port: 1972 };
  result.remoteDatabase = { name: 'EVAL2312REMOTE', server: 'EVAL2312SRV', directory: '/eval2312remote/' };
  result.consoleLine = marker(output, 'CONSOLE');
  const etn = marker(output, 'ETN') ?? '';
  if (!/^\d+\|\d+$/.test(etn)) throw new Error(`LOG^%ETN answered ${etn}: ${output.slice(-1500)}`);
  result.applicationError = { namespace: 'USER', day: etn.split('|')[0], number: etn.split('|')[1], error: '<DIVIDE>' };
  const [localNow, utcNow] = (marker(output, 'NOW') ?? '').split('|');
  result.instanceNow = { local: localNow, utc: utcNow };
  return result;
}

/** Create the fallback task that fails on every run, and ask for one run. Used only without the demo task. */
function seedFallback() {
  const output = runIris([
    `Set name=${os(FALLBACK_TASK)},id="",rs=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM %SYS.Task WHERE %EXACT(Name) = ?",name) While rs.%Next() { Set id=rs.%Get("ID") }`,
    'If id="" { Set t=##class(%SYS.Task).%New(),t.Name=name,t.Description="EVAL2312: Story 23.12 evaluation seed on a throwaway; fails on every run by design",t.NameSpace="%SYS",t.TaskClass="%SYS.Task.RunLegacyTask",t.TimePeriod=0,t.TimePeriodEvery=1,t.DailyFrequency=0,t.DailyStartTime=10800,t.SuspendOnError=1,d=##class(%SYS.Task.RunLegacyTask).%New(),d.ExecuteCode="Set Status=$System.Status.Error(5001,""EVAL2312 evaluation task: fails on every run by design"")",sc=t.AssignSettings(d),d="" If $System.Status.IsOK(sc) { Set sc=t.%Save() } If $System.Status.IsOK(sc) { Set id=t.%Id() } Set t="" }',
    'Set sc=$Select(id\'="":##class(%SYS.Task).RunNow(id),1:0) Write "OCU-FALLBACK-START:",id,"|",$System.Status.IsOK(sc),":OCU-FALLBACK-END",!',
  ], '%SYS');
  const [id, ok] = (marker(output, 'FALLBACK') ?? '').split('|');
  if (!id || ok !== '1') throw new Error(`the fallback task could not be run: ${output.slice(-1500)}`);
  return id;
}

/** Whether `name` reads Suspended in the schedule and has a failed run in the history. */
async function failedAndSuspended(name) {
  const schedule = await read('tasks.schedule');
  const history = await read('tasks.history');
  const row = schedule.rows.find((r) => r.Name === name);
  return Boolean(row && row.Suspended === true && history.rows.some((r) => r.Name === name && isFailedRun(r)));
}

async function awaitFailing(name, seconds = 180) {
  const deadline = Date.now() + seconds * 1000;
  for (;;) {
    if (await failedAndSuspended(name)) return true;
    if (Date.now() > deadline) return false;
    await sleep(10000);
  }
}

// ---------------------------------------------------------------- expected answers

async function expectedAnswers(state) {
  const schedule = await read('tasks.schedule');
  const history = await read('tasks.history');
  const databases = await read('osmgmt.databases');
  const remote = await read('osmgmt.remotedatabases');
  const messages = await read('logs.messages');
  const background = await read('tasks.background');
  const auditing = await read('security.auditing');
  const events = await read('security.auditsystemevents');
  const hub = await read('logs.hub');
  const dates = await api('GET', '/logs/errors/dates?namespace=USER');
  let errorList = null;
  let errorDate = null;
  if (dates.status === 200 && dates.body.rows?.length) {
    errorDate = dates.body.rows[0].date;
    const list = await api('GET', `/logs/errors/list?namespace=USER&date=${encodeURIComponent(errorDate)}`);
    errorList = list.status === 200 ? list.body : { status: list.status, body: list.body };
  }
  const nowMs = msOf(state.seed.instanceNow.local);
  const failedRows = history.rows.filter((r) => isFailedRun(r) && nowMs - msOf(r.LogDatetime) <= 24 * 3600 * 1000);
  const failingRuns = history.rows.filter((r) => r.Name === state.failingTask).sort((a, b) => String(b.LogDatetime).localeCompare(String(a.LogDatetime)));
  const loginFailure = events.rows.find((r) => r.EventName === '%System/%Login/LoginFailure');
  const weekly = schedule.rows.find((r) => r.Name === WEEKLY_TASK);
  return {
    readAt: now(),
    suspendedTasks: { read: 'tasks.schedule', names: schedule.rows.filter((r) => r.Suspended === true).map((r) => r.Name), rowsRead: schedule.rows.length, truncated: schedule.truncated },
    failedRuns: { read: 'tasks.history', criteria: history.criteria, windowFrom: state.seed.instanceNow.local, names: [...new Set(failedRows.map((r) => r.Name))], rows: failedRows.map((r) => ({ Name: r.Name, LogDatetime: r.LogDatetime, Status: r.Status, ErrNumber: r.ErrNumber, Result: r.Result })) },
    dismountedDatabases: { read: 'osmgmt.databases', rows: databases.rows.filter((r) => r.Status === 'Dismounted'), rowsRead: databases.rows.length, truncated: databases.truncated },
    remoteDatabases: { read: 'osmgmt.remotedatabases', rows: remote.rows },
    consoleLine: { read: 'logs.messages', rows: messages.rows.filter((r) => String(r.text).includes(state.seed.consoleLine)) },
    applicationError: { read: '/logs/errors/dates and /logs/errors/list (logs.applicationerrors), and logs.hub', namespace: 'USER', date: errorDate, list: errorList, hubRows: hub.rows.filter((r) => r.source === 'logs/errors' && String(r.text).startsWith('[USER]')) },
    backgroundJobs: { read: 'tasks.background', rows: background.rows },
    weeklyNext: { read: 'tasks.schedule', name: WEEKLY_TASK, nextScheduled: weekly?.NextScheduled ?? null, suspended: weekly?.Suspended ?? null },
    failingTaskLastRun: { read: 'tasks.history', name: state.failingTask, rows: failingRuns.slice(0, 3).map((r) => ({ LogDatetime: r.LogDatetime, LastStart: r.LastStart, Completed: r.Completed, Status: r.Status, ErrNumber: r.ErrNumber, Result: r.Result })) },
    auditing: { read: 'security.auditing, security.auditsystemevents', auditingEnabled: auditing.rows[0]?.Enabled ?? null, loginFailure: loginFailure ?? null },
  };
}

/**
 * A hint for the scorer, never the score: which expected values the reply names. Each wanted value
 * is a list of spellings, any one of which counts.
 */
function autoCheck(kind, expected, reply) {
  const text = String(reply ?? '').toLowerCase();
  const has = (value) => text.includes(String(value).toLowerCase());
  let wanted = [];
  switch (kind) {
    case 'suspendedTasks': wanted = expected.suspendedTasks.names.map((name) => [name]); break;
    case 'failedRuns': wanted = expected.failedRuns.names.map((name) => [name]); break;
    case 'dismountedDatabases': wanted = expected.dismountedDatabases.rows.map((r) => (r.Directory === DISM_DIR ? [r.Directory, 'EVAL2312DISM'] : [r.Directory])); break;
    case 'remoteDatabases': wanted = [['EVAL2312REMOTE'], ['EVAL2312SRV']]; break;
    case 'consoleLine': wanted = [['messages.log'], ['journal disk check failed']]; break;
    case 'applicationError': wanted = [['DIVIDE'], ['USER']]; break;
    case 'backgroundJobs': wanted = expected.backgroundJobs.rows.length ? expected.backgroundJobs.rows.map((r) => [String(r.Task)]) : [['background']]; break;
    case 'weeklyNext': wanted = expected.weeklyNext.nextScheduled ? [[String(expected.weeklyNext.nextScheduled).slice(0, 10)]] : []; break;
    case 'failingTaskLastRun': wanted = [['fail'], ['5001', 'always fails by design', 'fails on every run by design']]; break;
    case 'auditing': wanted = [['LoginFailure', 'login failure'], ['enabled']]; break;
    default: wanted = [];
  }
  const missing = wanted.filter((spellings) => !spellings.some(has)).map((spellings) => spellings.join(' | '));
  return { wanted: wanted.map((spellings) => spellings.join(' | ')), missing, allNamed: wanted.length > 0 && missing.length === 0 };
}

// ---------------------------------------------------------------- the probe definition

async function createDefinition(state, ledger) {
  const life = { name: DEFINITION.name, requested: DEFINITION, createdAt: now() };
  state.definition = life;
  saveState(state);
  const created = await expectStatus(api('POST', '/agent/definitions', DEFINITION), 201, 'definition create');
  life.id = String(created.id);
  life.createdEnabled = created.enabled;
  saveState(state);
  const stored = await expectStatus(api('POST', `/agent/definitions/${life.id}/credential`, { apiKey: providerKey() }), 200, 'credential store');
  life.credentialStored = stored.stored === true;
  const entry = { phase: PHASE, label: `${state.runId} test connection (bound)`, at: now(), input: TEST_CALL_BOUND.input, output: TEST_CALL_BOUND.output, cost: price(TEST_CALL_BOUND.input, TEST_CALL_BOUND.output), estimated: true };
  ledger.entries.push(entry);
  saveLedger(ledger);
  const tested = await expectStatus(api('POST', `/agent/definitions/${life.id}/test`, {}), 200, 'Test connection');
  life.test = { connected: tested.connected, connectionVerified: tested.connectionVerified, testedAsStored: tested.testedAsStored, latencyMs: tested.latencyMs };
  if (!tested.connectionVerified) throw new Error(`Test connection did not verify: ${JSON.stringify(life.test)}`);
  const enabled = await expectStatus(api('PUT', `/agent/definitions/${life.id}`, { enabled: true }), 200, 'enable');
  life.enabled = enabled.enabled;
  await expectStatus(api('POST', '/account/preferences', { kind: 'shell', action: 'set', name: 'agentDefinition', value: life.id }), 200, 'agentDefinition pick');
  life.pickedForSystem = true;
  saveState(state);
}

// ---------------------------------------------------------------- phases

async function setup({ dry = false } = {}) {
  if (loadState()) throw new Error(`${path.basename(STATE_FILE)} exists: run teardown for this phase first`);
  const ledger = loadLedger();
  if (!mayStart(ledger)) throw new Error(`no budget: phase ${PHASE} has spent ${usd(spent(ledger, PHASE))}, all phases ${usd(spent(ledger))}`);
  const pre = await preflight();
  const runId = `${PHASE}${new Date().toISOString().replace(/[-:]/g, '').slice(4, 13)}`;
  const state = { story: '23.12', phase: PHASE, sheet: SHEET, runId, dry, startedAt: now(), container: CONTAINER, port: WEB_PORT, readiness: pre.readiness, model: MODEL, results: [] };
  saveState(state);
  try {
    // Leftovers of an earlier run that did not tear down.
    const listed = await expectStatus(api('GET', '/agent/definitions'), 200, 'definition list');
    state.leftovers = [];
    for (const row of listed.definitions ?? []) {
      if (row.name !== DEFINITION.name) continue;
      await api('DELETE', `/agent/definitions/${row.id}`);
      state.leftovers.push(`definition ${row.id}`);
    }
    const credentialLeft = runIris([`Write "OCU-CRED-START:"_##class(OcuPilot.Test.CredentialFixture).Exists(${os(DEFINITION.credentialName)})_":OCU-CRED-END",!`]);
    if (marker(credentialLeft, 'CRED') === '1') {
      runIris([`Do ##class(OcuPilot.Test.CredentialFixture).Remove(${os(DEFINITION.credentialName)})`]);
      state.leftovers.push(`credential ${DEFINITION.credentialName}`);
    }
    const prefs = await expectStatus(api('GET', '/account/preferences'), 200, 'preferences read');
    state.priorPick = (prefs.shell ?? []).find((row) => row.name === 'agentDefinition')?.value ?? '';
    const markOut = runIris(['Write "OCU-MARK-START:"_##class(OcuPilot.Test.TurnWireFixture).StateMark()_":OCU-MARK-END",!']);
    state.mark = Number(marker(markOut, 'MARK'));
    if (!Number.isInteger(state.mark)) throw new Error(`StateMark answered ${markOut.slice(-800)}`);
    saveState(state);

    await createDefinition(state, ledger);
    log(`definition ${state.definition.id} created, verified and picked for _SYSTEM`);

    state.directories = dirsCheck();
    state.seed = seed(runId);
    saveState(state);
    log(`seeded: ${JSON.stringify(state.seed)}`);

    const demoReady = await awaitFailing(DEMO_TASK);
    state.failingTask = DEMO_TASK;
    state.failingTaskDecision = demoReady ? `the install's demo task "${DEMO_TASK}" had failed and suspended itself` : null;
    if (!demoReady) {
      state.seed.fallbackTaskId = seedFallback();
      state.failingTask = FALLBACK_TASK;
      saveState(state);
      if (!(await awaitFailing(FALLBACK_TASK))) throw new Error(`neither ${DEMO_TASK} nor ${FALLBACK_TASK} failed and suspended within the wait`);
      state.failingTaskDecision = `"${DEMO_TASK}" had not failed and suspended within 180 s, so the seed added "${FALLBACK_TASK}", which fails on every run, ran it once, and questions 1, 2 and 9 name it`;
    }
    state.expected = await expectedAnswers(state);
    saveState(state);
    log(`expected answers read: ${JSON.stringify(state.expected).slice(0, 3000)}`);
  } catch (error) {
    log(`setup failed, tearing down: ${redact(error).split('\n')[0]}`);
    await teardown({ writeSheet: false });
    throw error;
  }
  if (dry) await teardown({ writeSheet: false });
}

async function startTurn(message) {
  const conversation = await expectStatus(api('POST', '/conversation'), 201, 'conversation');
  const deadline = Date.now() + 300 * 1000;
  for (;;) {
    const start = await api('POST', '/turn', { message, conversationId: conversation.conversationId });
    if (start.status === 202) return { conversationId: conversation.conversationId, turnId: start.body.turnId };
    if (Date.now() > deadline) throw new Error(`turn start kept answering ${start.status} ${JSON.stringify(start.body)}`);
    if (start.status === 409 && start.body.code === 'TURN.BUSY') {
      await sleep(POLL_MS);
      continue;
    }
    if (start.status === 403 && start.body.code === 'TURN.LIMITHOUR') {
      const wait = Math.max(Date.parse(start.body.detail?.retryAt ?? '') - Date.now(), POLL_MS);
      if (Date.now() + wait > deadline) throw new Error(`turn limit until ${start.body.detail?.retryAt}`);
      await sleep(wait);
      continue;
    }
    throw new Error(`turn start answered ${start.status} ${JSON.stringify(start.body)}`);
  }
}

function toolsOf(view) {
  return (view.steps ?? []).filter((s) => s.kind === 'tool').map((s) => ({ name: s.name, status: s.status, arguments: String(s.arguments ?? '').slice(0, 160) }));
}

async function awaitStopped(turnId, seconds = 30) {
  const deadline = Date.now() + seconds * 1000;
  let view = null;
  while (Date.now() < deadline) {
    const progress = await api('GET', `/turn/${encodeURIComponent(turnId)}/progress`);
    if (progress.status === 200) {
      view = progress.body;
      if (['completed', 'stopped', 'abandoned', 'failed'].includes(view.state)) return view;
    }
    await sleep(POLL_MS);
  }
  return view;
}

async function askOne(state, ledger, question) {
  const message = question.question.replace('{failingTask}', state.failingTask);
  const entry = { phase: PHASE, label: `${state.runId} q${question.n}`, at: now(), input: 0, output: 0, cost: 0 };
  ledger.entries.push(entry);
  const result = { n: question.n, question: message, startedAt: now(), navigationSettled: [] };
  const started = await startTurn(message);
  Object.assign(result, started);
  state.inFlight = { n: question.n, turnId: started.turnId };
  saveState(state);
  const begun = Date.now();
  let view = null;
  let largestCall = 0;
  let lastInput = 0;
  for (;;) {
    const progress = await api('GET', `/turn/${encodeURIComponent(started.turnId)}/progress`);
    if (progress.status !== 200) throw new Error(`progress answered ${progress.status} ${JSON.stringify(progress.body)}`);
    view = progress.body;
    const input = Number(view.tokens?.input ?? 0);
    const output = Number(view.tokens?.output ?? 0);
    if (input > lastInput) largestCall = Math.max(largestCall, input - lastInput);
    lastInput = input;
    Object.assign(entry, { input, output, cost: price(input, output) });
    saveLedger(ledger);
    if (['completed', 'stopped', 'abandoned', 'failed'].includes(view.state)) break;
    const nav = view.navigation;
    if (nav && !result.navigationSettled.includes(nav.seq)) {
      const settle = await api('POST', `/turn/${encodeURIComponent(started.turnId)}/navigation`, { seq: nav.seq, outcome: 'opened', code: null });
      result.navigationSettled.push(nav.seq);
      result.navigationRoutes = [...(result.navigationRoutes ?? []), `${nav.route} (${settle.status})`];
    }
    const nextCall = price(Math.max(largestCall * 1.25, 20000), 4000);
    const phaseWithout = spent(ledger, PHASE, entry);
    const totalWithout = spent(ledger, null, entry);
    const overCap = phaseWithout + entry.cost + nextCall > PHASE_CAP || totalWithout + entry.cost + nextCall > TOTAL_CAP;
    const overTime = Date.now() - begun > TURN_TIMEOUT_SECONDS * 1000;
    if ((overCap || overTime) && !result.stopRequested) {
      await api('POST', `/turn/${encodeURIComponent(started.turnId)}/stop`);
      result.stopRequested = overCap ? 'cost cap' : `over ${TURN_TIMEOUT_SECONDS} s`;
      log(`question ${question.n}: stop requested (${result.stopRequested})`);
    }
    await sleep(POLL_MS);
  }
  result.endedAt = now();
  result.seconds = Math.round((Date.now() - begun) / 1000);
  result.state = view.state;
  result.error = view.error;
  result.iterations = view.iterations;
  result.tokens = { input: entry.input, output: entry.output };
  result.cost = entry.cost;
  result.reply = view.reply ?? '';
  result.tools = toolsOf(view);
  result.check = autoCheck(question.expect, state.expected, result.reply);
  state.results.push(result);
  delete state.inFlight;
  saveState(state);
  saveLedger(ledger);
  return result;
}

async function settleInFlight(state, ledger) {
  if (!state.inFlight) return;
  const { n, turnId } = state.inFlight;
  await api('POST', `/turn/${encodeURIComponent(turnId)}/stop`);
  const view = await awaitStopped(turnId);
  const label = `${state.runId} q${n}`;
  let entry = ledger.entries.find((e) => e.label === label);
  if (!entry) {
    entry = { phase: PHASE, label, at: now(), input: 0, output: 0, cost: 0 };
    ledger.entries.push(entry);
  }
  if (view) Object.assign(entry, { input: Number(view.tokens?.input ?? 0), output: Number(view.tokens?.output ?? 0) });
  entry.cost = price(entry.input, entry.output);
  saveLedger(ledger);
  if (!state.results.some((r) => r.n === n)) {
    state.results.push({ n, turnId, interrupted: true, state: view?.state ?? 'unknown', reply: view?.reply ?? '', tools: view ? toolsOf(view) : [], tokens: { input: entry.input, output: entry.output }, cost: entry.cost, check: { wanted: [], missing: [], allNamed: false } });
  }
  delete state.inFlight;
  saveState(state);
}

async function ask() {
  const state = loadState();
  if (!state || !state.expected) throw new Error(`no completed setup for phase ${PHASE}: run setup first`);
  await preflight();
  const ledger = loadLedger();
  const began = Date.now();
  try {
    await settleInFlight(state, ledger);
    for (const question of QUESTIONS) {
      if (state.results.some((r) => r.n === question.n)) continue;
      if (Date.now() - began > ASK_BUDGET_SECONDS * 1000) {
        log('time budget for this invocation used; run ask again');
        break;
      }
      if (!mayStart(ledger)) {
        log(`no question starts: phase ${PHASE} at ${usd(spent(ledger, PHASE))}, all phases ${usd(spent(ledger))}`);
        state.budgetStop = `question ${question.n} and later not started: phase at ${usd(spent(ledger, PHASE))}`;
        saveState(state);
        break;
      }
      const result = await askOne(state, ledger, question);
      log(`question ${result.n}: ${result.state}, ${result.tokens.input}+${result.tokens.output} tokens, ${usd(result.cost)}, tools ${result.tools.map((t) => t.name).join(' > ') || '(none)'}; phase spend ${usd(spent(ledger, PHASE))}`);
    }
  } finally {
    await settleInFlight(state, ledger);
  }
  const asked = state.results.length;
  log(`${asked} of ${QUESTIONS.length} asked${asked === QUESTIONS.length ? '; run teardown' : ''}`);
}

async function teardown({ writeSheet = true } = {}) {
  const state = loadState() ?? { phase: PHASE, runId: `${PHASE}-unknown`, results: [], priorPick: null };
  const ledger = loadLedger();
  const done = { at: now() };
  try {
    await settleInFlight(state, ledger);
  } catch (error) {
    done.inFlight = `could not stop: ${redact(error).split('\n')[0]}`;
  }
  // The definition: by id, and any other by name.
  const listed = await api('GET', '/agent/definitions');
  const ids = new Set(state.definition?.id ? [state.definition.id] : []);
  for (const row of listed.body?.definitions ?? []) if (row.name === DEFINITION.name) ids.add(String(row.id));
  done.definitionsDeleted = [];
  for (const id of ids) {
    const deleted = await api('DELETE', `/agent/definitions/${id}`);
    done.definitionsDeleted.push(`${id}: ${deleted.status}`);
  }
  const after = await api('GET', '/agent/definitions');
  done.definitionsLeft = (after.body?.definitions ?? []).filter((row) => row.name === DEFINITION.name).length;
  // The pick, restored.
  if (state.priorPick === null) {
    done.pick = 'prior unknown (no state); left as found';
  } else if (state.priorPick === '') {
    const out = runIris(['Set sc=##class(OcuPilot.Kernel.State.Pref).GuardedRemove("_SYSTEM","shell","agentDefinition") Write "OCU-PICK-START:"_$System.Status.IsOK(sc)_":OCU-PICK-END",!']);
    done.pick = `removed (no prior pick): ${marker(out, 'PICK')}`;
  } else {
    const set = await api('POST', '/account/preferences', { kind: 'shell', action: 'set', name: 'agentDefinition', value: state.priorPick });
    done.pick = `restored to ${state.priorPick}: ${set.status}`;
  }
  const prefs = await api('GET', '/account/preferences');
  done.pickAfter = (prefs.body?.shell ?? []).find((row) => row.name === 'agentDefinition')?.value ?? '';
  // The credential entry, if the delete left it.
  const cred = runIris([`Set e=##class(OcuPilot.Test.CredentialFixture).Exists(${os(DEFINITION.credentialName)}) Do:e ##class(OcuPilot.Test.CredentialFixture).Remove(${os(DEFINITION.credentialName)}) Write "OCU-CRED-START:"_e_"|"_##class(OcuPilot.Test.CredentialFixture).Exists(${os(DEFINITION.credentialName)})_":OCU-CRED-END",!`]);
  const [credBefore, credAfter] = (marker(cred, 'CRED') ?? '?|?').split('|');
  done.credential = credBefore === '0' ? 'removed with the definition' : `left by the delete, removed here (now ${credAfter})`;
  // The seed.
  const seedOut = runIris([
    'Set n=0,rs=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM %SYS.Task WHERE %EXACT(Name) %STARTSWITH ?","EVAL2312") While rs.%Next() { Set sc=##class(%SYS.Task).%DeleteId(rs.%Get("ID")) Set:$System.Status.IsOK(sc) n=n+1 } Write "OCU-TASKS-START:",n,":OCU-TASKS-END",!',
    'Set sc=1 If ##class(Config.Databases).Exists("EVAL2312REMOTE") { Set sc=##class(Config.Databases).Delete("EVAL2312REMOTE") } Write "OCU-RREMOTE-START:",$System.Status.IsOK(sc),":OCU-RREMOTE-END",!',
    'Set sc=1 If ##class(Config.ECPServers).Exists("EVAL2312SRV") { Set sc=##class(Config.ECPServers).Delete("EVAL2312SRV") } Write "OCU-RECP-START:",$System.Status.IsOK(sc),":OCU-RECP-END",!',
    `Set dir=${os(DISM_DIR)},sc=1 If ##class(Config.Databases).Exists("EVAL2312DISM") { Set sc=##class(Config.Databases).Delete("EVAL2312DISM") } Write "OCU-RDBCONF-START:",$System.Status.IsOK(sc),":OCU-RDBCONF-END",!`,
    'Set sc=1 If ##class(SYS.Database).%ExistsId(dir) { Set sc=##class(SYS.Database).DeleteDatabase(dir) } Write "OCU-RDB-START:",$System.Status.IsOK(sc),"|",$Select($System.Status.IsOK(sc):"",1:$System.Status.GetErrorText(sc)),":OCU-RDB-END",!',
    `Set ok=1 If ##class(%File).DirectoryExists(${os(DISM_ROOT)}) { Set ok=##class(%File).RemoveDirectoryTree(${os(DISM_ROOT)}) } Write "OCU-RDIR-START:",ok,":OCU-RDIR-END",!`,
    'Set sc=1 If ##class(Security.Resources).Exists("%DB_EVAL2312DISM") { Set sc=##class(Security.Resources).Delete("%DB_EVAL2312DISM") } Write "OCU-RRES-START:",$System.Status.IsOK(sc),":OCU-RRES-END",!',
    `Set left="",rs=##class(%SQL.Statement).%ExecDirect(,"SELECT Name FROM %SYS.Task WHERE %EXACT(Name) %STARTSWITH ?","EVAL2312") While rs.%Next() { Set left=left_" task "_rs.%Get("Name") } Set:##class(Config.Databases).Exists("EVAL2312REMOTE") left=left_" EVAL2312REMOTE" Set:##class(Config.ECPServers).Exists("EVAL2312SRV") left=left_" EVAL2312SRV" Set:##class(Config.Databases).Exists("EVAL2312DISM") left=left_" EVAL2312DISM" Set:##class(SYS.Database).%ExistsId(${os(DISM_DIR)}) left=left_" database ${DISM_DIR}" Set:##class(%File).DirectoryExists(${os(DISM_ROOT)}) left=left_" directory ${DISM_ROOT}" Set:##class(Security.Resources).Exists("%DB_EVAL2312DISM") left=left_" %DB_EVAL2312DISM" Write "OCU-LEFT-START:",left,":OCU-LEFT-END",!`,
  ], '%SYS');
  done.seed = {
    tasksDeleted: Number(marker(seedOut, 'TASKS')),
    remoteDatabase: marker(seedOut, 'RREMOTE'),
    ecpServer: marker(seedOut, 'RECP'),
    dismountedConfig: marker(seedOut, 'RDBCONF'),
    dismountedDatabase: marker(seedOut, 'RDB'),
    directory: marker(seedOut, 'RDIR'),
    resource: marker(seedOut, 'RRES'),
    left: (marker(seedOut, 'LEFT') ?? 'unread').trim(),
  };
  // This run's conversations, turns and ledger rows.
  if (Number.isInteger(state.mark)) {
    const sweep = runIris([`Write "OCU-SWEEP-START:"_##class(OcuPilot.Test.TurnWireFixture).SweepSince(${state.mark},"_SYSTEM")_":OCU-SWEEP-END",!`]);
    done.sweepLeft = (marker(sweep, 'SWEEP') ?? 'unread').trim();
  }
  state.teardown = done;
  state.endedAt = now();
  log(`teardown: ${JSON.stringify(done)}`);
  if (writeSheet && state.results.length) {
    const sheetPath = path.join(HERE, SHEET);
    writeOutput(sheetPath, sheet(state, ledger));
    log(`wrote ${sheetPath}`);
  }
  if (state.dry || writeSheet || !state.expected) {
    if (fs.existsSync(STATE_FILE)) fs.unlinkSync(STATE_FILE);
  } else {
    saveState(state);
  }
  saveLedger(ledger);
  return done;
}

// ---------------------------------------------------------------- the sheet

function fence(value) {
  const text = String(value ?? '');
  const cut = text.length > REPLY_CHARS ? `${text.slice(0, REPLY_CHARS)}\n[cut: first ${REPLY_CHARS} of ${text.length} characters]` : text;
  return ['```text', cut.replace(/```/g, "'''"), '```'].join('\n');
}

function json(value) {
  return ['```json', JSON.stringify(value, null, 2), '```'].join('\n');
}

function sheet(state, ledger) {
  const totalIn = state.results.reduce((sum, r) => sum + (r.tokens?.input ?? 0), 0);
  const totalOut = state.results.reduce((sum, r) => sum + (r.tokens?.output ?? 0), 0);
  const turnCost = state.results.reduce((sum, r) => sum + (r.cost ?? 0), 0);
  const phaseCost = spent(ledger, PHASE);
  const lines = [
    `# Story 23.12 live evaluation, ${PHASE}`,
    '',
    `- Run \`${state.runId}\`, ${state.startedAt} to ${state.endedAt} (UTC), on \`${state.container}\` (web ${state.port}).`,
    `- Model \`${state.model}\`, through the definition "${DEFINITION.name}" (provider \`anthropic\`, credType \`creds\`, credential \`${DEFINITION.credentialName}\`, every other field at its default), picked as \`_SYSTEM\`'s agent definition.`,
    `- ${QUESTIONS.length} questions, each in a new conversation with no screen context; ${state.results.length} asked. A navigation the agent announced was answered \`opened\`, as a browser that follows it would.`,
    `- Tokens: input ${totalIn}, output ${totalOut}; priced ${usd(turnCost)} at $0.625 a million input and $2.50 a million output (conservative).`,
    `- Spend: this phase ${usd(phaseCost)} including the Test connection call at its bound; Task 0 and Task Z together ${usd(spent(ledger))} of $2.00 (\`spend.json\`). Cap for this phase $0.90; ${usd(Math.max(0, PHASE_CAP - phaseCost))} left.`,
    `- Provisional scores: the lead confirms or corrects each.`,
    '',
    '## Seeded state',
    '',
    `- Failing task: ${state.failingTaskDecision}.`,
    `- Tasks: ${(state.seed?.tasks ?? []).map((t) => `"${t.name}" (id ${t.id}, Suspended ${t.suspended})`).join(', ')}. Each is \`%SYS.Task.RunLegacyTask\` with \`ExecuteCode\` \`Quit\`.`,
    `- Database EVAL2312DISM at \`${DISM_DIR}\` (resource \`%DB_EVAL2312DISM\`), dismounted (Mounted ${state.seed?.database?.mounted}); outside the manager directory \`${state.directories?.managerDirectory}\` and IRISSYS's \`${state.directories?.irissysDirectory}\`.`,
    '- ECP data server EVAL2312SRV at 127.0.0.1:1972, and remote database EVAL2312REMOTE on it (directory `/eval2312remote/`).',
    `- messages.log line at severity 2: "${state.seed?.consoleLine}".`,
    `- A \`<DIVIDE>\` logged with \`LOG^%ETN\` in USER (day ${state.seed?.applicationError?.day}, entry ${state.seed?.applicationError?.number}).`,
    `- Instance time at seeding: ${state.seed?.instanceNow?.local} local, ${state.seed?.instanceNow?.utc} UTC.`,
    '',
    '## Probe definition',
    '',
    `- Created ${state.definition?.createdAt}, id ${state.definition?.id}; key stored: ${state.definition?.credentialStored}; Test connection: ${JSON.stringify(state.definition?.test)}; enabled: ${state.definition?.enabled}; picked for \`_SYSTEM\`: ${state.definition?.pickedForSystem}.`,
    `- Used by the ${state.results.length} turns below.`,
    `- Deleted: ${(state.teardown?.definitionsDeleted ?? []).join(', ')}; left by name: ${state.teardown?.definitionsLeft}; credential: ${state.teardown?.credential}; pick: ${state.teardown?.pick}, now \`${state.teardown?.pickAfter || '(none)'}\`.`,
    '',
    '## Teardown',
    '',
    json(state.teardown),
    '',
    '## Questions',
    '',
  ];
  for (const question of QUESTIONS) {
    const result = state.results.find((r) => r.n === question.n);
    const expected = state.expected?.[question.expect];
    lines.push(`### ${question.n}. ${result?.question ?? question.question.replace('{failingTask}', state.failingTask)}`, '');
    lines.push(`- Holds the answer: \`${question.holds}\`.`, `- Right when: ${question.rightWhen}`);
    if (!result) {
      lines.push('- Not asked.', '');
      continue;
    }
    const tools = result.tools.map((t) => `\`${t.name}\`${t.status === 'ok' ? '' : ` (${t.status})`}`).join(', ') || '(none)';
    lines.push(
      `- Tools called, in order: ${tools}.`,
      `- Tokens: input ${result.tokens.input}, output ${result.tokens.output}; priced ${usd(result.cost)}.`,
      `- Turn: ${result.state}${result.error ? ` (${JSON.stringify(result.error)})` : ''}, ${result.iterations ?? '?'} model calls, ${result.seconds ?? '?'} s${result.navigationRoutes ? `; navigation answered opened: ${result.navigationRoutes.join(', ')}` : ''}${result.stopRequested ? `; stop requested: ${result.stopRequested}` : ''}${result.interrupted ? '; interrupted' : ''}.`,
      `- Automatic check (a hint, not the score): ${result.check.allNamed ? 'names every expected value' : `misses ${JSON.stringify(result.check.missing)}`} of ${JSON.stringify(result.check.wanted)}.`,
      `- **Provisional score: ${result.check.allNamed ? 'RIGHT' : 'WRONG'}.** Reason: automatic check only.`,
      '',
      'Expected, as the reads showed it:',
      '',
      json(expected),
      '',
      'Reply:',
      '',
      fence(result.reply),
      '',
    );
  }
  return `${lines.join('\n').replace(/\n{3,}/g, '\n\n').trimEnd()}\n`;
}

// ---------------------------------------------------------------- main

const COMMANDS = { setup: () => setup(), ask, teardown: () => teardown(), dry: () => setup({ dry: true }) };

if (!COMMANDS[COMMAND]) {
  console.error('usage: node eval.mjs setup|ask|teardown|dry [--sheet score-before.md|score-after.md]');
  process.exitCode = 2;
} else {
  COMMANDS[COMMAND]().catch((error) => {
    console.error(redact(error));
    process.exitCode = 1;
  });
}
