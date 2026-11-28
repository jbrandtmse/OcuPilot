/// <p>What Story 24.17 Batch 2's armed log suites share: the arming check, the probe rule log entries and business processes <class>OcuPilot.Test.InteropLogPurgeFixture</class> stores in
/// <code>USER</code> and <code>HSCUSTOM</code> and removes before and after every test and asserts gone, the per-log facts (<method>Spec</method>), the HTTP calls of the two screens
/// and the proposal route, the agent's mint, the port's calls through the shipped class or a seam, and the audit rows a purge leaves. The probes live in <code>USER</code>, which holds
/// no production; <code>HSCUSTOM</code> holds the install, so the two namespaces tell a confirm's namespace apart. <b>No production is started.</b></p>
/// <p>Every probe is back-dated 7,300 days and every purge keeps 3,650, so nothing but a probe is old enough to go: the class refuses to start while either namespace holds a row that
/// is not a probe and that a purge of that age would delete.</p>
/// <p><b>Not run itself</b>: it declares no test.</p>
Class OcuPilot.Test.InteropLogPurgeCase Extends %UnitTest.TestCase [ Abstract ]
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLogPurgeFixture";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropLogPurgeSeam";

Parameter SOURCE = "USER";

Parameter OTHER = "HSCUSTOM";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter SHARED = "OcuPilot.Test.InteropAlertCase";

Parameter MODE = "^IRIS.Temp.OcuProbe2417LogMode";

/// <p>The two logs a test visits, <code>rule</code> and <code>process</code>.</p>
Parameter KINDS = "rule,process";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, ..%ClassName(1) _ " stores probe rule log entries and business processes in USER and HSCUSTOM, purges them and creates principals on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Set tForeign = 0
    Set tWhere = ""
    For tNamespace = ..#SOURCE, ..#OTHER {
        Set tCount = $ClassMethod(..#FIXTURE, "Foreign", tNamespace)
        If tCount '= 0 {
            Set tForeign = tCount
            Set tWhere = tNamespace
            Quit
        }
    }
    If tForeign '= 0 Quit $$$ERROR($$$GeneralError, ..%ClassName(1) _ " purges rule log entries older than 3,650 days and completed business processes, and " _ tWhere _ " holds " _ tForeign _ " that are not its probes (-1 is a failed read), so nothing was run. A class that ran before it left them, or the instance holds real ones.")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "ClearLog")
    Kill ^IRIS.Temp.OcuProbe2417LogMode
    Do $ClassMethod(..#FIXTURE, "DropProbes")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "ClearLog")
    Kill ^IRIS.Temp.OcuProbe2417LogMode
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "DropProbes"), "the probe rule log entries and business processes are removed from both namespaces, and none survives")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The fact <var>pField</var> of the log <var>pKind</var> (<code>rule</code> or <code>process</code>): <code>endpoint</code>, <code>state</code> (the read type), <code>write</code> (the write type),
/// <code>screen</code>, <code>tool</code>, <code>key</code>, <code>entity</code>, <code>consequence</code>, <code>descriptor</code>, <code>criterion</code>, <code>pair</code> (the classic
/// page's resource pair) or <code>label</code>.</p>
ClassMethod Spec(pKind As %String, pField As %String) As %String
{
    Set tRule = (pKind = "rule")
    If pField = "endpoint" Quit $Select(tRule: "RuleLog", 1: "ProcessLog")
    If pField = "state" Quit $Select(tRule: "RULELOGSTATE", 1: "PROCESSLOGSTATE")
    If pField = "write" Quit $Select(tRule: "PURGERULELOG", 1: "PURGEPROCESSLOG")
    If pField = "screen" Quit $Select(tRule: "/screens/interop.rulelog", 1: "/screens/interop.processlog")
    If pField = "tool" Quit $Select(tRule: "OcuPilot.Screen.Tool.InteropRuleLogPurge", 1: "OcuPilot.Screen.Tool.InteropProcessLogPurge")
    If pField = "key" Quit $Select(tRule: "interop.rulelog.purge", 1: "interop.processlog.purge")
    If pField = "entity" Quit $Select(tRule: "interop-rule-log", 1: "interop-process-log")
    If pField = "consequence" Quit $Select(tRule: "INTEROP.RULELOG.PURGE", 1: "INTEROP.PROCESSLOG.PURGE")
    If pField = "descriptor" Quit $Select(tRule: "OcuPilot.Screen.Descriptor.InteropRuleLogList", 1: "OcuPilot.Screen.Descriptor.InteropProcessLogList")
    If pField = "criterion" Quit $Select(tRule: "errors", 1: "completed")
    If pField = "pair" Quit $Select(tRule: "%Ens_RuleLog:USE", 1: "%Ens_Jobs:READ")
    If pField = "label" Quit $Select(tRule: "rule log entry", 1: "business process")
    Quit ""
}

/// <p>Store a probe of the log <var>pKind</var> in <var>pNamespace</var>, <var>pDays</var> days old, and answer its id, or 0. <var>pFlag</var> is the entry's error flag for a rule log entry
/// and whether the business process is completed for a process; <var>pDebug</var> gives a rule log entry a debug row.</p>
ClassMethod Probe(pKind As %String, pNamespace As %String = {..#SOURCE}, pDays As %Integer = 7300, pFlag As %Boolean = 0, pDebug As %Boolean = 0) As %Integer
{
    If pKind = "rule" Quit $ClassMethod(..#FIXTURE, "ProbeRule", pNamespace, pDays, pFlag, pDebug)
    Quit $ClassMethod(..#FIXTURE, "ProbeProcess", pNamespace, pDays, pFlag)
}

/// <p>Whether the probe <var>pId</var> of the log <var>pKind</var> exists in <var>pNamespace</var>.</p>
ClassMethod Exists(pKind As %String, pNamespace As %String, pId As %String) As %Boolean
{
    Quit $ClassMethod(..#FIXTURE, $Select(pKind = "rule": "RuleExists", 1: "ProcessExists"), pNamespace, pId)
}

/// <p>How many rows of the log <var>pKind</var> <var>pNamespace</var> holds, probes or not.</p>
ClassMethod Rows(pKind As %String, pNamespace As %String = {..#SOURCE}) As %Integer
{
    Quit $ClassMethod(..#FIXTURE, $Select(pKind = "rule": "RuleCount", 1: "ProcessCount"), pNamespace, 0)
}

/// <p>One HTTP call as the test account, scoped to <var>pNamespace</var>: the status in <var>pStatus</var> and the parsed answer, or the raw text, in <var>pAnswer</var>.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pBody, Output pStatus As %Integer, Output pAnswer, pNamespace As %String = {..#SOURCE}) As %Status
{
    Quit $ClassMethod(..#SHARED, "Call", pMethod, pPath, pBody, .pStatus, .pAnswer, pNamespace)
}

/// <p>One person's Purge on the screen of the log <var>pKind</var> with the days <var>pDays</var>, as <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod Act(pKind As %String, pDays As %String, Output pAnswer, pNamespace As %String = {..#SOURCE}) As %String
{
    Set tValues = {}
    Do tValues.%Set("DaysToKeep", pDays, "string")
    Set tBody = {"action": "purge", "id": (pNamespace)}
    Do tBody.%Set("values", tValues)
    Do ..Call("POST", ..Spec(pKind, "screen") _ "/action", tBody, .tStatus, .pAnswer, pNamespace)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The port's call of the log <var>pKind</var> for <var>pType</var> (<code>LIST</code>, <code>state</code> or <code>write</code>, which <method>Spec</method> names) in <var>pNamespace</var>,
/// as <code>status code</code>, the rows or the row in <var>pResult</var> and the envelope in <var>pFault</var>. <var>pQuery</var> names the call's other keys.</p>
ClassMethod Verdict(pKind As %String, pType As %String, Output pResult, Output pFault, ByRef pQuery, pNamespace As %String = {..#SOURCE}, pClass As %String = {..#PORT}) As %String
{
    Set tType = $Case(pType, "state": ..Spec(pKind, "state"), "write": ..Spec(pKind, "write"), : pType)
    Quit $ClassMethod(..#SHARED, "Verdict", ..Spec(pKind, "endpoint"), tType, .pResult, .pFault, .pQuery, pNamespace, pClass)
}

/// <p>The port's purge of the log <var>pKind</var> of <var>pNamespace</var> for <var>pDays</var>, as <code>status code</code>.</p>
ClassMethod Purge(pKind As %String, pDays As %String = {$Parameter("OcuPilot.Test.InteropLogPurgeFixture", "KEEPDAYS")}, pNamespace As %String = {..#SOURCE}, pClass As %String = {..#PORT}, Output pResult, Output pFault) As %String
{
    Kill tQuery
    Set tQuery("days") = pDays
    Quit ..Verdict(pKind, "write", .pResult, .pFault, .tQuery, pNamespace, pClass)
}

/// <p>The agent's mint of the purge of the log <var>pKind</var> for <var>pDays</var>, scoped to <var>pNamespace</var>: the code of its refusal, <code>minted</code> when it was not refused; the
/// sentence in <var>pReason</var>, the proposal in <var>pProposal</var> and its turn in <var>pTurn</var>.</p>
ClassMethod Mint(pKind As %String, pDays As %String, Output pReason As %String, Output pProposal, Output pTurn, pNamespace As %String = {..#SOURCE}) As %String
{
    Set pReason = ""
    Set pProposal = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Set tArgs = {"Name": (pNamespace)}
    Do tArgs.%Set("DaysToKeep", pDays, "string")
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..Spec(pKind, "tool"), tArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .pProposal, .tHttp, .tFault, .pTurn)
    If $IsObject($Get(pProposal)) Quit "minted"
    If '$IsObject($Get(tFault)) Quit "refused"
    Set pReason = $Select($IsObject(tFault.%Get("detail")) && (tFault.detail.%Get("problem") '= ""): tFault.detail.%Get("problem"), 1: tFault.%Get("reason"))
    Quit tFault.%Get("code")
}

/// <p>Confirm proposal <var>pProposalId</var> over the wire as the test account, scoped to <var>pNamespace</var>: the status in <var>pStatus</var>, the raw body and the parsed answer.</p>
ClassMethod Confirm(pProposalId As %String, Output pStatus As %Integer, Output pRaw As %String, Output pAnswer, pNamespace As %String = {..#SOURCE}) As %Status
{
    Quit $ClassMethod(..#SHARED, "Confirm", pProposalId, .pStatus, .pRaw, .pAnswer, pNamespace)
}

/// <p>Turn on the governance keys of both purges, which ship off, for the rest of the test; <var>pPolicy</var> is what to hand back to
/// <class>OcuPilot.Test.GovernanceFixture</class>'s <code>Restore</code>.</p>
ClassMethod EnableKeys(Output pPolicy) As %Status
{
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.pPolicy)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Kill tSettings
    Set tSettings("interop.rulelog.purge") = "enabled"
    Set tSettings("interop.processlog.purge") = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>The rows of OcuPilot's own <code>ConfigChange</code> since <var>pSince</var> that name the log <var>pKind</var>'s entity type, with the last row's data in <var>pData</var>. The audit
/// database shows a row a moment after it is written, so the read is made again, for up to five seconds, until it finds <var>pExpect</var> rows.</p>
ClassMethod OwnRows(pKind As %String, pSince As %String, Output pData As %String, pExpect As %Integer = 1) As %Integer
{
    For tTry = 1:1:20 {
        Set tRows = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, "ConfigChange", ..Spec(pKind, "entity"), .pData)
        If tRows '< pExpect Quit
        Hang 0.25
    }
    Quit tRows
}

/// <p>The ids of the rows <var>pRows</var> carries under <code>ID</code>, comma-separated in the order they come.</p>
ClassMethod Ids(pRows) As %String
{
    Quit $ClassMethod(..#SHARED, "Ids", pRows)
}

/// <p>The text of every step of <var>pSteps</var>, joined by line feeds.</p>
ClassMethod StepText(pSteps As %DynamicArray) As %String
{
    Quit $ClassMethod(..#SHARED, "StepText", pSteps)
}

/// <p>How many rows <var>pRows</var> holds, or -1 when it is not an array.</p>
ClassMethod Size(pRows) As %Integer
{
    Quit $Select($IsObject($Get(pRows)): pRows.%Size(), 1: -1)
}

}
