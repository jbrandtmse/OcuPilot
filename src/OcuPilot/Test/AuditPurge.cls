/// <p>Pins the audit database's purge (AD-51, AD-52, AD-53, Story 12.3): what
/// <class>OcuPilot.Screen.Tool.AuditPurge</class> declares, that it is absent from every roster the
/// agent sees while its screen's route still resolves it, the screen route's purge at the
/// instance's own today, and the refusal of a malformed or future cut-off.</p>
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

/// <p>AD-51, AD-52, AD-8: the purge is an unadvertised, destructive, action-style write over
/// <code>Security.Audit.Record</code> <code>PURGE</code> through the audit port, fingerprinted
/// over its one argument, carrying the screen's <code>purge</code> action and its value.</p>
Method TestThePurgeIsAnUnadvertisedDestructiveActionWrite()
{
    Set tClass = ..#TOOLCLASS
    Do $$$AssertEquals($ClassMethod(tClass, "Advertised"), 0, "declared unadvertised")
    Do $$$AssertEquals($ClassMethod(tClass, "PortClass") _ " " _ $ClassMethod(tClass, "Endpoint"), "OcuPilot.Port.AuditPort Security.Audit.Record", "behind the audit port")
    Do $$$AssertEquals($ClassMethod(tClass, "ReadType") _ " " _ $ClassMethod(tClass, "WriteType") _ " " _ $ClassMethod(tClass, "SendsBody") _ " " _ $ClassMethod(tClass, "ChangeAction") _ " " _ $ClassMethod(tClass, "Destructive"), "DATABASE PURGE 0 updated 1", "a bodyless, destructive purge publishing updated")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")) _ " " _ $ListToString($ClassMethod(tClass, "FingerprintSubject")) _ " " _ $ClassMethod(tClass, "PreconditionField"), "PurgeBefore PurgeBefore PurgeBefore", "admitting and fingerprinting the cut-off alone")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", "which the registration guard holds adequate")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")) _ " " _ $ListToString($ClassMethod(tClass, "ScreenActionValueNames", "purge")), "purge PurgeBefore", "carrying the screen's purge action and its one value")
    Do $$$AssertEquals($ClassMethod(tClass, "CutoffProblem", ..Today()), "", "today is a cut-off")
}

/// <p>AC3, AD-53: the purge is absent from the provider tool list, the dispatch lookup and the
/// Auditing screen's context <code>tools</code>, where the copy is present; the registry still lists
/// it and the prohibited set's resolve and the screen route reach it; and a model's call to
/// <code>security_auditing_purge</code> is refused as an unknown tool with no proposal written.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.Registry.ProviderTools</method> ignores
/// <code>advertised</code> -> the provider-list assertion goes red.</p>
Method TestThePurgeIsAbsentFromEveryRosterTheAgentSees()
{
    Set tRegistry = "OcuPilot.Screen.Tool.Registry"
    Set tWire = $ClassMethod(tRegistry, "WireName", ..#TOOL)
    Set tCopyWire = $ClassMethod(tRegistry, "WireName", ..#COPYTOOL)
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ProviderTools", .tProvider), "the provider tool list builds")
    Set tNames = ""
    For tI = 1:1:+$Get(tProvider) Set tNames = tNames _ $ListBuild(tProvider(tI, "name"))
    Do $$$AssertEquals($ListFind(tNames, tWire), 0, "the provider tool list leaves the purge out")
    Do $$$AssertTrue($ListFind(tNames, tCopyWire) > 0, "and carries the copy")
    Do $ClassMethod(tRegistry, "ResolveWire", tWire, .tByWire)
    Do $ClassMethod(tRegistry, "ResolveWire", tCopyWire, .tCopyByWire)
    Do $$$AssertTrue('$IsObject($Get(tByWire)) && $IsObject($Get(tCopyByWire)), "the dispatch lookup finds the copy and not the purge")
    Do $ClassMethod(tRegistry, "Resolve", ..#TOOL, .tByName)
    Do $$$AssertTrue('$IsObject($Get(tByName)), "and neither does a proposal-path resolve by name")
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Context).ScreenTools(..#SCREEN, .tTools), "the Auditing screen's context tools build")
    Do $$$AssertTrue(($Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: "") '[ tWire) && ($Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: "") [ tCopyWire), "they carry the copy and not the purge: " _ $Select($IsObject($Get(tTools)): tTools.%ToJSON(), 1: ""))
    Do $$$AssertStatusOK($ClassMethod(tRegistry, "ListTools", .tAll), "the registry lists")
    Set tListed = 0
    Set tIterator = tAll.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) { If tEntry.%Get("name") = ..#TOOL Set tListed = 1 }
    Do $$$AssertEquals(tListed, 1, "the registry still lists the purge, so the screen route resolves it")
    Do $ClassMethod(tRegistry, "Resolve", ..#TOOL, .tForRoute, 1)
    Do $$$AssertTrue($IsObject($Get(tForRoute)), "and the prohibited set's resolve reaches it")

    Set tProbe = "OcuPilot.Test.ToolDispatchProbe"
    Set tBefore = ..ProposalRows(..#TOOL)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed probe turn is seeded")
    Do $ClassMethod(tProbe, "Reset")
    Do $ClassMethod(tProbe, "SetRegistryClass", tRegistry)
    Set tUse = {"type": "tool_use", "id": "toolu_purge", "input": {"Name": "SYSTEM", "rationale": "probe", "expectedImpact": "probe"}}
    Do tUse.%Get("input").%Set("PurgeBefore", ..Today(), "string")
    Do tUse.%Set("name", tWire, "string")
    Set tSC = $ClassMethod(tProbe, "Answer", tTurnKey, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do $ClassMethod(tProbe, "Reset")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the dispatch answers")
    Set tCode = ""
    If $IsObject($Get(tResults)) && (tResults.%Size() = 1) Set tCode = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content")).%Get("code")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Api.Error).#TOOLUNKNOWN, "a model's purge is refused as an unknown tool")
    Do $$$AssertEquals(..ProposalRows(..#TOOL), tBefore, "and no proposal is written")
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
