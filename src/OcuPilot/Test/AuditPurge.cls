/// <p>Pins the audit database's purge (AD-51, AD-52, AD-53, AD-22, Stories 12.3 and 14.2): what
/// <class>OcuPilot.Screen.Tool.AuditPurge</class> declares, that it is in every roster the agent
/// sees and refused by the default policy, that with its key enabled the agent's purge is confirmed
/// with its marker, the screen route's purge at the instance's own today, and the refusal of a
/// malformed or future cut-off. Every test starts from no stored policy and puts back the one it
/// found.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, auditing on, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>: it removes every record in this
/// instance's audit database dated before today.</p>
Class OcuPilot.Test.AuditPurge Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_AUDIT_PURGE";

Parameter TOOL = "security.auditing.purge";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.AuditPurge";

Parameter COPYTOOL = "security.auditing.copy";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.AuditingConfig";

Parameter ACTIONPATH = "/screens/security.auditing/action";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditPurge removes every record in this instance's audit database dated before today, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was removed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Do $$$AssertStatusOK(tSC, "the policy found before the test is put back")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).Matches(.tRows), "and reads back as it was")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The instance's own today, <code>YYYY-MM-DD</code> (Conventions, Dates).</p>
ClassMethod Today() As %String
{
    Quit $ZDate(+$Horolog, 3)
}

/// <p>The UTC timestamp of today's local midnight, as the audit table stores its times.</p>
ClassMethod TodayStartUTC() As %String
{
    Quit $ZDateTime($ZDateTimeH($ZDateTimeH(..Today() _ " 00:00:00", 3), -3), 3, , 3)
}

/// <p>How many records the instance's audit database holds with a UTC time before
/// <var>pBefore</var> (<code>&lt;</code>) or, with <var>pOnOrAfter</var>, at or after it;
/// <code>-1</code> when the count cannot be read.</p>
ClassMethod Count(pBefore As %String, pOnOrAfter As %Boolean = 0) As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM %SYS.Audit WHERE " _ $Select(pOnOrAfter: "UTCTimeStamp >= ?", 1: "UTCTimeStamp < ?"), pBefore)
        If (tRS.%SQLCODE = 0) && tRS.%Next() Set tCount = +tRS.%Get("N")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>One purge over the route as the test helper's account, answering the HTTP status and the
/// parsed envelope.</p>
Method Act(pCutoff As %String, Output pStatus As %Integer, Output pBody) As %Status
{
    Set pBody = ""
    Set tRequest = {"action": "purge", "id": "SYSTEM", "values": {}}
    Do tRequest.%Get("values").%Set("PurgeBefore", pCutoff, "string")
    Kill tExtra
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#ACTIONPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json", .tExtra)
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
    Quit tSC
}

/// <p>The vendor's <code>AuditChange</code> rows since <var>pSince</var> whose data carries
/// <var>pText</var>.</p>
ClassMethod ChangeRows(pSince As %String, pText As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditCopy).ChangeRows(pSince, pText, .tUser)
}

/// <p>How many stored proposals name <var>pToolName</var>.</p>
ClassMethod ProposalRows(pToolName As %String) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ToolName) = ?", pToolName)
    If (tRS.%SQLCODE '= 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%Get("N")
}

/// <p>AD-51, AD-52, AD-8: the purge is an advertised, destructive, action-style write over
/// <code>Security.Audit.Record</code> <code>PURGE</code> through the audit port, fingerprinted
/// over its one argument, carrying the screen's <code>purge</code> action and its value, and the
/// consequence <code>AUDIT.PURGEMARKERS</code> whatever the cut-off.</p>
/// <p>Mutation (Rule 19): remove <method>OcuPilot.Screen.Tool.AuditPurge.Consequence</method> ->
/// the consequence leg goes red.</p>
Method TestThePurgeIsAnAdvertisedDestructiveActionWrite()
{
    Set tClass = ..#TOOLCLASS
    Do $$$AssertEquals($ClassMethod(tClass, "Advertised"), 1, "declared advertised")
    Do $$$AssertEquals($ClassMethod(tClass, "PortClass") _ " " _ $ClassMethod(tClass, "Endpoint"), "OcuPilot.Port.AuditPort Security.Audit.Record", "behind the audit port")
    Do $$$AssertEquals($ClassMethod(tClass, "ReadType") _ " " _ $ClassMethod(tClass, "WriteType") _ " " _ $ClassMethod(tClass, "SendsBody") _ " " _ $ClassMethod(tClass, "ChangeAction") _ " " _ $ClassMethod(tClass, "Destructive"), "DATABASE PURGE 0 updated 1", "a bodyless, destructive purge publishing updated")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")) _ " " _ $ListToString($ClassMethod(tClass, "FingerprintSubject")) _ " " _ $ClassMethod(tClass, "PreconditionField"), "PurgeBefore PurgeBefore PurgeBefore", "admitting and fingerprinting the cut-off alone")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", "which the registration guard holds adequate")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")) _ " " _ $ListToString($ClassMethod(tClass, "ScreenActionValueNames", "purge")), "purge PurgeBefore", "carrying the screen's purge action and its one value")
    Do $$$AssertEquals($ClassMethod(tClass, "CutoffProblem", ..Today()), "", "today is a cut-off")
    Do $$$AssertEquals(##class(%Dictionary.CompiledMethod).%ExistsId(tClass _ "||Consequence"), 1, "it declares a consequence")
    If ##class(%Dictionary.CompiledMethod).%ExistsId(tClass _ "||Consequence") Do $$$AssertEquals($ClassMethod(tClass, "Consequence", {"PurgeBefore": (..Today())}, 0, ""), "AUDIT.PURGEMARKERS", "and it is the purge's own")
}

/// <p>AD-53, AD-22: the purge is in the provider tool list, the dispatch lookup and the Auditing
/// screen's context <code>tools</code> beside the copy, and a model's call to
/// <code>security_auditing_purge</code> under the default policy is refused
/// <code>GOVERNANCE.DISABLED</code> with no proposal written.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Governance.Gate.Decide</method> answers allowed
/// -> the refusal leg goes red.</p>
Method TestThePurgeIsInEveryRosterAndDisabledByDefault()
{
    Set tRegistry = "OcuPilot.Screen.Tool.Registry"
    Set tWire = $ClassMethod(tRegistry, "WireName", ..#TOOL)
    Set tCopyWire = $ClassMethod(tRegistry, "WireName", ..#COPYTOOL)
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ProviderTools", .tProvider), "the provider tool list builds")
    Set tNames = ""
    For tI = 1:1:+$Get(tProvider) Set tNames = tNames _ $ListBuild(tProvider(tI, "name"))
    Do $$$AssertTrue(($ListFind(tNames, tWire) > 0) && ($ListFind(tNames, tCopyWire) > 0), "the provider tool list carries the purge and the copy")
    Do $ClassMethod(tRegistry, "ResolveWire", tWire, .tByWire)
    Do $$$AssertTrue($IsObject($Get(tByWire)), "the dispatch lookup finds the purge")
    Do $ClassMethod(tRegistry, "Resolve", ..#TOOL, .tByName)
    Do $$$AssertTrue($IsObject($Get(tByName)), "and so does a proposal-path resolve by name")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(..#SCREEN, .tTools), "the Auditing screen's context tools build")
    Set tJson = $Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: "")
    Do $$$AssertTrue((tJson [ tWire) && (tJson [ tCopyWire), "they carry the purge and the copy: " _ tJson)

    Set tBefore = ..ProposalRows(..#TOOL)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed probe turn is seeded")
    Set tSC = ..Dispatch(tTurnKey, .tResults)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    Do $$$AssertStatusOK(tSC, "the dispatch answers")
    Set tCode = ""
    If $IsObject($Get(tResults)) && (tResults.%Size() = 1) Set tCode = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content")).%Get("code")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "a model's purge is refused as disabled by policy")
    Do $$$AssertEquals(..ProposalRows(..#TOOL), tBefore, "and no proposal is written")
}

/// <p>AC10 (routed from Story 12.3): with the purge's key enabled, the agent's purge is minted
/// destructive carrying <code>AUDIT.PURGEMARKERS</code>, and its confirm purges the records dated
/// before today with the agent's own marker written for the write.</p>
/// <p>Mutation (Rule 19): remove <method>OcuPilot.Screen.Tool.AuditPurge.Consequence</method> ->
/// the consequence leg goes red.</p>
Method TestWithItsKeyEnabledTheAgentsPurgeIsConfirmedMarked()
{
    Kill tSettings
    Set tSettings(..#TOOL) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the purge's key is enabled")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed probe turn is seeded")
    Set tSC = ..Dispatch(tTurnKey, .tResults)
    Do $$$AssertStatusOK(tSC, "the dispatch answers")
    Set tProposal = ""
    If $IsObject($Get(tResults)) && (tResults.%Size() = 1) && 'tResults.%Get(0).%Get("is_error") Set tProposal = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content"))
    Do $$$AssertTrue($IsObject(tProposal) && (tProposal.%Get("proposalId") '= ""), "the purge is minted: " _ $Select($IsObject($Get(tResults)) && (tResults.%Size() = 1): tResults.%Get(0).%Get("content"), 1: ""))
    If '$IsObject(tProposal) Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals(+$Get(tValues("destructive")) _ "|" _ $Get(tValues("consequence")), "1|AUDIT.PURGEMARKERS", "destructive, carrying the purge's consequence")

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the purge is confirmed: " _ $Get(tCode))
    Do $$$AssertEquals(..Count(..TodayStartUTC()), 0, "no record dated before today remains")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposal.%Get("proposalId") _ """", .tData), 1, "and the audit database carries the agent's marker for it")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows it wrote")
}

/// <p>One model call to <code>security_auditing_purge</code> cutting off at today, through the
/// shipped registry and the shipped gate, answering the dispatch's results.</p>
Method Dispatch(pTurnKey As %String, Output pResults As %DynamicArray) As %Status
{
    Set tProbe = "OcuPilot.Test.ToolDispatchProbe"
    Do $ClassMethod(tProbe, "Reset")
    Do $ClassMethod(tProbe, "SetRegistryClass", "OcuPilot.Screen.Tool.Registry")
    Set tUse = {"type": "tool_use", "id": "toolu_purge", "input": {"Name": "SYSTEM", "rationale": "probe", "expectedImpact": "probe"}}
    Do tUse.%Get("input").%Set("PurgeBefore", ..Today(), "string")
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(..#TOOL), "string")
    ; The turn marker a real turn carries, so a proposal minted here names its turn (AD-40); cleared
    ; before anything confirms.
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(pTurnKey)
    Set tSC = $ClassMethod(tProbe, "Answer", pTurnKey, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .pResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $ClassMethod(tProbe, "Reset")
    Quit tSC
}

/// <p>AC2 on the screen's caller: a purge cutting off at the instance's own today answers 200
/// <code>updated</code>, leaves no record dated before today and every record dated today, and the
/// vendor records its own <code>AuditChange</code> for it, while the screen path emits no agent
/// marker.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.AuditPort.Body</method> sends an empty
/// <code>EndDateTime</code> -> today's records are removed too and this goes red.</p>
Method TestTheScreenRoutePurgesBeforeTodayAndKeepsToday()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tMidnight = ..TodayStartUTC()
    Set tToday = ..Count(tMidnight, 1)
    Do $$$AssertTrue(tToday > 0, "the audit database holds records dated today (" _ tToday _ ")")
    Do $$$LogMessage("records dated before today at the start: " _ ..Count(tMidnight))
    Do ..Act(..Today(), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the purge answers 200: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: $Get(tBody)))
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%Get("action"), 1: ""), "updated", "publishing updated")
    Do $$$AssertEquals(..Count(tMidnight), 0, "no record dated before today remains")
    Do $$$AssertTrue(..Count(tMidnight, 1) >= tToday, "every record dated today remains: " _ ..Count(tMidnight, 1) _ " against " _ tToday)
    Do $$$AssertTrue(..ChangeRows(tSince, ..Today() _ " 00:00:00") > 0, "and the vendor records its own AuditChange for the purge")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, ..#TOOL, .tData), 0, "the screen path emits no agent-write marker (AD-53)")
}

/// <p>The matrix's refusals: a cut-off that is not a date, one that is not written
/// <code>YYYY-MM-DD</code>, and tomorrow are each 400 <code>TOOL.ARGUMENTS</code>, and no record is
/// removed.</p>
/// <p>Mutation (Rule 19): drop the future arm of
/// <method>OcuPilot.Screen.Tool.AuditPurge.CutoffProblem</method> -> tomorrow is purged and this
/// goes red.</p>
Method TestAMalformedOrFutureCutoffIsRefused()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tHeld = ..Count(tSince)
    Do $$$AssertTrue(tHeld > 0, "the audit database holds records to lose (" _ tHeld _ ")")
    For tCutoff = "2026-13-01", "24/09/2026", $ZDate(+$Horolog + 1, 3) {
        Do ..Act(tCutoff, .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.%Get("code"), 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "'" _ tCutoff _ "' is refused: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: $Get(tBody)))
    }
    Do $$$AssertEquals(..Count(tSince), tHeld, "no record is removed")
    Do $$$AssertEquals(..ChangeRows(tSince, "00:00:00"), 0, "and the vendor recorded no purge")
}

}
