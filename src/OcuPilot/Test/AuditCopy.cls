/// <p>Pins the audit database's copy (AD-8, AD-26, AD-51, AD-52, AD-53, Story 12.3): what
/// <class>OcuPilot.Screen.Tool.AuditCopy</class> declares, the vendor bodies
/// <class>OcuPilot.Port.AuditPort</class> composes, the screen route's copy into <code>USER</code>,
/// its refusals, the agent's mint and marked confirm, and a principal without
/// <code>%Admin_Operate:USE</code> refused by name on both callers while one holding exactly the
/// pair set copies as itself.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, auditing on, a
/// <code>USER</code> namespace, an account holding <code>%All</code>, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>: it creates two users and two roles
/// for every method, and it empties <code>USER</code>'s audit globals with
/// <code>%SYS.Audit.Delete</code> run in <code>USER</code> before and after each.</p>
Class OcuPilot.Test.AuditCopy Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "security.auditing.copy";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.AuditCopy";

Parameter PURGECLASS = "OcuPilot.Screen.Tool.AuditPurge";

Parameter PORT = "OcuPilot.Port.AuditPort";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.AuditingConfig";

Parameter ENDPOINT = "Security.Audit.Record";

/// <p>The pair both tools declare beyond the screen's own.</p>
Parameter OPERATEPAIR = "%Admin_Operate:USE";

Parameter ACTIONPATH = "/screens/security.auditing/action";

/// <p>The namespace every copy here targets.</p>
Parameter TARGETNS = "USER";

/// <p>The principal holding the screen's pairs and not <parameter>OPERATEPAIR</parameter>, the one
/// holding exactly the tool's pair set, their roles, and the marker <method>RemovePrincipals</method>
/// requires before it deletes one.</p>
Parameter PRINCIPAL = "OcuPilotTestAuditCopy";

Parameter PRINCIPALROLE = "OcuPilotTestAuditCopyRole";

Parameter FULLPRINCIPAL = "OcuPilotTestAuditFull";

Parameter FULLROLE = "OcuPilotTestAuditFullRole";

Parameter MARKER = "OcuPilot audit copy probe";

/// <p>The password both principals share, generated for each method.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditCopy creates users and roles and copies this instance's audit database into USER, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ..EmptyTarget()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..CreatePrincipals(.tPassword)
    Set ..PreparedPassword = $Get(tPassword)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(..RemovePrincipals(), "every probe principal and role is removed by exact name")
    Do $$$AssertStatusOK(..EmptyTarget(), "USER's audit globals are emptied")
    Quit $$$OK
}

/// <p>How many audit records <var>pNamespace</var>'s audit globals hold; <code>-1</code> when the
/// count cannot be read.</p>
ClassMethod Count(pNamespace As %String) As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM %SYS.Audit")
        If (tRS.%SQLCODE = 0) && tRS.%Next() Set tCount = +tRS.%Get("N")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Delete every record in <parameter>TARGETNS</parameter>'s own audit globals, run in that
/// namespace so the instance's own audit database is untouched.</p>
ClassMethod EmptyTarget() As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#TARGETNS
        Set tSC = ##class(%SYS.Audit).Delete(.tDeleted)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The vendor's <code>%System/%Security/AuditChange</code> rows in the instance's audit database
/// since <var>pSince</var> whose data carries <var>pText</var>, with the last one's user in
/// <var>pUser</var>; <code>-1</code> when the read fails.</p>
ClassMethod ChangeRows(pSince As %String, pText As %String, Output pUser As %String) As %Integer
{
    Set pUser = ""
    Set tRows = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Username, EventData FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = ? AND %NOINDEX EventType = ? AND %NOINDEX Event = ?", pSince, "%System", "%Security", "AuditChange")
        If tRS.%SQLCODE = 0 {
            Set tRows = 0
            While tRS.%Next() {
                If tRS.%Get("EventData") '[ pText Continue
                Set tRows = tRows + 1
                Set pUser = tRS.%Get("Username")
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tRows = -1
    }
    Quit tRows
}

/// <p>One Auditing row action over the route as <var>pUser</var>, or as the test helper's account
/// when <var>pUser</var> is empty, answering the HTTP status and the parsed envelope.</p>
Method Act(pAction As %String, pValues As %DynamicObject, Output pStatus As %Integer, Output pBody, pUser As %String = "", pPassword As %String = "") As %Status
{
    Set pBody = ""
    Set tRequest = {"id": "SYSTEM"}
    Do tRequest.%Set("action", pAction, "string")
    If $IsObject(pValues) Do tRequest.%Set("values", pValues)
    If pUser = "" {
        Set pUser = ##class(OcuPilot.Test.Http).GetTestUsername()
        Set pPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    }
    Kill tExtra
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#ACTIONPATH, pUser, pPassword, .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json", .tExtra)
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
    Quit tSC
}

/// <p>An envelope's <code>code</code> and, where it names one, its <code>detail.problem</code> or
/// <code>detail.failedPair</code>, as <code>&lt;code&gt;|&lt;detail&gt;</code>.</p>
Method Envelope(pBody) As %String
{
    If '$IsObject(pBody) Quit ""
    Set tDetail = ""
    If pBody.%GetTypeOf("detail") = "object" Set tDetail = pBody.%Get("detail").%Get("problem") _ pBody.%Get("detail").%Get("failedPair")
    Quit pBody.%Get("code") _ "|" _ tDetail
}

/// <p>A pair list as <code>resource:permission</code> entries joined with commas.</p>
Method Pairs(pPairs As %List) As %String
{
    Set tOut = ""
    For tI = 1:1:$ListLength(pPairs) Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $ListToString($List(pPairs, tI), ":")
    Quit tOut
}

/// <p>AD-51, AD-52, AD-8, AD-26: the copy is an action-style, non-destructive write over
/// <code>Security.Audit.Record</code> <code>COPY</code> through the audit port, read at its
/// <code>DATABASE</code>, fingerprinted over its one argument, requiring the screen's pairs and
/// <parameter>OPERATEPAIR</parameter> -- as the purge does -- and both types are queued writes the
/// port composes; <method>OcuPilot.Port.AuditPort.Body</method> copies every record and deletes
/// none, and purges up to the cut-off's midnight.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Screen.Tool.AuditCopy.WRITERESOURCE</parameter>
/// from its <method>OcuPilot.Screen.Tool.AuditCopy.PrivilegePairs</method> -> the pair assertions
/// go red.</p>
Method TestTheToolsAreQueuedActionWritesOverTheScreensPairsAndOperate()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#TOOL, .tTool)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), "the registry resolves the copy by name")
    If '$IsObject($Get(tTool)) Quit
    Set tClass = ..#TOOLCLASS
    Do $$$AssertEquals(tTool.%Get("kind") _ " " _ tTool.%Get("class") _ " " _ ##class(OcuPilot.Screen.Tool.Registry).IsAdvertised(tTool), "write " _ tClass _ " 1", "an advertised write tool answered by its own class")
    Do $$$AssertEquals($ClassMethod(tClass, "PortClass") _ " " _ $ClassMethod(tClass, "Endpoint"), ..#PORT _ " " _ ..#ENDPOINT, "behind the audit port, over the audit record endpoint")
    Do $$$AssertEquals($ClassMethod(tClass, "ReadType") _ " " _ $ClassMethod(tClass, "WriteType") _ " " _ $ClassMethod(tClass, "SendsBody") _ " " _ $ClassMethod(tClass, "ChangeAction") _ " " _ $ClassMethod(tClass, "Destructive"), "DATABASE COPY 0 updated 0", "a bodyless, non-destructive copy publishing updated")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")) _ " " _ $ListToString($ClassMethod(tClass, "FingerprintSubject")) _ " " _ $ClassMethod(tClass, "PreconditionField"), "CopyNamespace CopyNamespace CopyNamespace", "admitting and fingerprinting the namespace alone")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", "which the registration guard holds adequate")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")) _ " " _ $ListToString($ClassMethod(tClass, "ScreenActionValueNames", "copy")), "copy CopyNamespace", "carrying the screen's copy action and its one value")
    Set tExpected = $ClassMethod(..#SCREEN, "PrivilegePairs") _ $ListBuild($ListFromString(..#OPERATEPAIR, ":"))
    Do $$$AssertEquals(..Pairs(##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved)), ..Pairs(tExpected), "requiring the screen's pairs and the async poll's pair")
    Do $$$AssertEquals(..Pairs($ClassMethod(..#PURGECLASS, "PrivilegePairs", "", .tResolved)), ..Pairs(tExpected), "and so does the purge")
    For tType = "COPY", "PURGE" {
        Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating(..#ENDPOINT, tType) && ##class(OcuPilot.Port.AdminPort).IsQueuedWrite(..#ENDPOINT, tType), tType _ " is a mutating pair the port lets the vendor queue")
        Do $$$AssertTrue($ListFind($ListFromString($Parameter(..#PORT, "COMPOSEDTYPES")), ..#ENDPOINT _ "/" _ tType) > 0, tType _ " is one the audit port composes")
    }
    Kill tQuery
    Set tQuery("CopyNamespace") = ..#TARGETNS
    Set tBody = $ClassMethod(..#PORT, "Body", "COPY", .tQuery)
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%ToJSON(), 1: ""), "{""AuditCopyNamespace"":""USER"",""DeleteAfterCopy"":false,""BeginDateTime"":"""",""EndDateTime"":""""}", "the copy body copies every record and deletes none")
    Kill tQuery
    Set tQuery("PurgeBefore") = "2026-09-24"
    Set tBody = $ClassMethod(..#PORT, "Body", "PURGE", .tQuery)
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%ToJSON(), 1: ""), "{""BeginDateTime"":"""",""EndDateTime"":""2026-09-24 00:00:00""}", "the purge body cuts off at that day's midnight")
    For tCase = $ListBuild("COPY", ""), $ListBuild("PURGE", ""), $ListBuild("PURGE", "24/09/2026") {
        Kill tQuery
        If $List(tCase, 2) '= "" Set tQuery("PurgeBefore") = $List(tCase, 2)
        Do $$$AssertEquals($ClassMethod(..#PORT, "Body", $List(tCase, 1), .tQuery), "", $List(tCase, 1) _ " with '" _ $List(tCase, 2) _ "' composes nothing")
    }
}

/// <p>AC1 on the screen's caller: <code>copy</code> to <code>USER</code> answers 200
/// <code>updated</code>, <code>USER</code> then holds at least every record the instance held at
/// the start, the instance keeps its own, the vendor records its <code>AuditChange</code> as the
/// caller, and the screen path emits no agent-write marker (AD-53).</p>
/// <p>Mutation (Rule 19): send <code>DeleteAfterCopy: true</code> from
/// <method>OcuPilot.Port.AuditPort.Body</method> -> the instance's own count falls and this goes
/// red.</p>
Method TestTheScreenRouteCopiesEveryRecordAndDeletesNone()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBefore = ..Count("%SYS")
    Do $$$AssertTrue(tBefore > 0, "the instance's audit database holds records to copy (" _ tBefore _ ")")
    Do $$$AssertEquals(..Count(..#TARGETNS), 0, "and USER's holds none")
    Set tStart = $ZHorolog
    Do ..Act("copy", {"CopyNamespace": (..#TARGETNS)}, .tStatus, .tBody)
    Set tSeconds = $ZHorolog - tStart
    Do $$$AssertEquals(tStatus, 200, "the copy answers 200: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: $Get(tBody)))
    Do $$$AssertEquals($Select($IsObject(tBody) && (tBody.%GetTypeOf("target") = "object"): tBody.%Get("action") _ " " _ tBody.%Get("target").%Get("type"), 1: ""), "updated auditing-configuration", "publishing updated on the auditing configuration")
    Do $$$AssertTrue(..Count(..#TARGETNS) >= tBefore, "USER holds every record the instance held at the start: " _ ..Count(..#TARGETNS) _ " against " _ tBefore)
    Do $$$AssertTrue(..Count("%SYS") >= tBefore, "and the instance keeps its own: " _ ..Count("%SYS") _ " against " _ tBefore)
    Do $$$AssertTrue(..ChangeRows(tSince, ..#TARGETNS, .tUser) > 0, "the vendor records its AuditChange for the copy")
    Do $$$AssertEquals(tUser, ##class(OcuPilot.Test.Http).GetTestUsername(), "as the caller")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, ..#TOOL, .tData), 0, "the screen path emits no agent-write marker (AD-53)")
    Do $$$LogMessage("copy of " _ tBefore _ " records answered in " _ $FNumber(tSeconds, "", 3) _ " s")
}

/// <p>The matrix's refusals: <code>%SYS</code>, a namespace this instance does not have, a path and
/// an empty value are each 400 <code>TOOL.ARGUMENTS</code>, and nothing is copied or queued.</p>
/// <p>Mutation (Rule 19): drop the <code>%SYS</code> arm of
/// <method>OcuPilot.Screen.Tool.AuditCopy.NamespaceProblem</method> -> the vendor refuses instead,
/// with another code, and this goes red.</p>
Method TestACopyIntoSysOrAnUnknownNamespaceIsRefused()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    For tCase = $ListBuild("%SYS", "%SYS"), $ListBuild("NOSUCHNS", "no namespace 'NOSUCHNS'"), $ListBuild("^^/tmp/", "not a path"), $ListBuild("", "non-empty") {
        Do ..Act("copy", {"CopyNamespace": ($List(tCase, 1))}, .tStatus, .tBody)
        Do $$$AssertEquals(tStatus _ " " _ $Piece(..Envelope(tBody), "|", 1), "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "'" _ $List(tCase, 1) _ "' is refused: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: $Get(tBody)))
        Do $$$AssertTrue($Piece(..Envelope(tBody), "|", 2) [ $List(tCase, 2), "naming the problem: " _ ..Envelope(tBody))
    }
    Do $$$AssertEquals(..Count(..#TARGETNS), 0, "nothing was copied")
    Do $$$AssertEquals(..ChangeRows(tSince, ..#TARGETNS, .tUser), 0, "and nothing was queued: the vendor recorded no copy")
}

/// <p>AC4 on the agent's caller: the proposal is non-destructive, targets the auditing
/// configuration, names <code>USER</code> in its one row, and copies nothing at the mint; its
/// confirm copies the records and the audit database carries one agent-write marker naming the
/// proposal (AD-15).</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.AuditCopy.PortQuery</method> adds nothing
/// -> the port composes no body, the confirm fails and this goes red.</p>
Method TestTheAgentsCopyIsMintedAndConfirmedMarked()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = $ClassMethod(..#TOOLCLASS, "View", "", {"Name": "SYSTEM", "CopyNamespace": "%SYS"}, 0, .tRefused, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && (tHttp = 400), "a copy into %SYS is refused at the mint")
    Set tSC = $ClassMethod(..#TOOLCLASS, "View", "", {"Name": "SYSTEM", "CopyNamespace": (..#TARGETNS)}, 0, .tProposal, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(tSC, "the copy is minted: " _ $System.Status.GetErrorText(tSC))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.%Get("target").%Get("type"), "auditing-configuration", "its target is the auditing configuration")
    Set tRows = ""
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) { Set tRows = tRows _ $ListBuild(tRow.%Get("field") _ "=" _ tRow.%Get("before") _ ">" _ tRow.%Get("after")) }
    Do $$$AssertEquals($ListToString(tRows, "|"), "CopyNamespace=>USER", "one row naming USER")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals(+$Get(tValues("destructive")), 0, "and it is not destructive")
    Do $$$AssertEquals(..Count(..#TARGETNS), 0, "nothing is copied at the mint")

    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBefore = ..Count("%SYS")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the copy is confirmed: " _ $Get(tCode))
    Do $$$AssertTrue(..Count(..#TARGETNS) >= tBefore, "the records are copied: " _ ..Count(..#TARGETNS) _ " against " _ tBefore)
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposal.%Get("proposalId") _ """", .tData), 1, "the audit database carries one agent-write marker naming this proposal")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows it wrote")
}

/// <p>AC5, AD-8: a principal holding the screen's pairs and not <parameter>OPERATEPAIR</parameter>
/// lacks exactly that pair, the shipped dispatch chain refuses the agent's copy naming it, and the
/// screen route refuses its copy and its purge 403 <code>AUTH.NOPRIVILEGE</code> naming it; nothing
/// is copied or purged.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Screen.Tool.AuditCopy.WRITERESOURCE</parameter>
/// from its <method>OcuPilot.Screen.Tool.AuditCopy.PrivilegePairs</method> -> the pair, dispatch and
/// copy-route assertions go red.</p>
Method TestAPrincipalWithoutOperateIsRefusedByName()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#TOOL, .tTool)
    If '$IsObject($Get(tTool)) Quit
    Set tMissing = ""
    Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved)
    For tI = 1:1:$ListLength(tPairs) {
        Set tPair = $List(tPairs, tI)
        If ##class(OcuPilot.Kernel.Agent.Dispatch).HoldsPair(..#PRINCIPAL, $List(tPair, 1), $List(tPair, 2)) Continue
        Set tMissing = tMissing _ $Select(tMissing = "": "", 1: ",") _ $ListToString(tPair, ":")
    }
    Do $$$AssertEquals(tMissing, ..#OPERATEPAIR, "the principal lacks the operate pair, and only it")
    Do $$$AssertEquals(..DispatchRefusal(), "1|" _ ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE _ "|" _ ..#OPERATEPAIR, "the shipped dispatch chain, with that pair not held, refuses the copy naming it")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBefore = ..Count("%SYS")
    For tCase = $ListBuild("copy", "CopyNamespace", ..#TARGETNS), $ListBuild("purge", "PurgeBefore", $ZDate(+$Horolog, 3)) {
        Set tValues = {}
        Do tValues.%Set($List(tCase, 2), $List(tCase, 3), "string")
        Do ..Act($List(tCase, 1), tValues, .tStatus, .tBody, ..#PRINCIPAL, ..PreparedPassword)
        Do $$$AssertEquals(tStatus _ " " _ ..Envelope(tBody), "403 " _ ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE _ "|" _ ..#OPERATEPAIR, $List(tCase, 1) _ ": the route refuses the principal naming the pair: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: $Get(tBody)))
    }
    Do $$$AssertEquals(..Count(..#TARGETNS), 0, "nothing is copied")
    Do $$$AssertTrue(..Count("%SYS") >= tBefore, "and nothing is purged")
    Do $$$AssertEquals(..ChangeRows(tSince, "00:00:00", .tUser) + ..ChangeRows(tSince, ..#TARGETNS, .tUser), 0, "the vendor recorded neither")
}

/// <p>AD-7, AD-26: a principal holding exactly the tool's pair set copies through the route, and the
/// vendor's queued worker records the copy as that principal.</p>
Method TestAPrincipalHoldingExactlyThePairSetCopiesAsItself()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do ..Act("copy", {"CopyNamespace": (..#TARGETNS)}, .tStatus, .tBody, ..#FULLPRINCIPAL, ..PreparedPassword)
    Do $$$AssertEquals(tStatus, 200, "the copy answers 200: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: $Get(tBody)))
    Do $$$AssertTrue(..Count(..#TARGETNS) > 0, "and copies")
    Do $$$AssertTrue(..ChangeRows(tSince, ..#TARGETNS, .tUser) > 0, "the vendor records its AuditChange")
    Do $$$AssertEquals(tUser, ..#FULLPRINCIPAL, "as the principal, so the worker ran as the caller")
}

/// <p>One agent call to the copy through the shipped dispatch chain, driven by
/// <class>OcuPilot.Test.ToolDispatchProbe</class> over the shipped registry with
/// <parameter>OPERATEPAIR</parameter> not held, as
/// <code>&lt;isError&gt;|&lt;code&gt;|&lt;failedPair&gt;</code>. The probe turn's ledger rows are
/// removed.</p>
Method DispatchRefusal() As %String
{
    Set tProbe = "OcuPilot.Test.ToolDispatchProbe"
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit "seedfailed"
    Do $ClassMethod(tProbe, "Reset")
    Do $ClassMethod(tProbe, "SetRegistryClass", "OcuPilot.Screen.Tool.Registry")
    Do $ClassMethod(tProbe, "DenyPair", $Piece(..#OPERATEPAIR, ":", 1), $Piece(..#OPERATEPAIR, ":", 2))
    Set tUse = {"type": "tool_use", "id": "toolu_copy", "input": {"Name": "SYSTEM", "CopyNamespace": "USER", "rationale": "probe", "expectedImpact": "probe"}}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(..#TOOL), "string")
    Set tSC = $ClassMethod(tProbe, "Answer", tTurnKey, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do $ClassMethod(tProbe, "Reset")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey)
    If $$$ISERR(tSC) Quit "dispatchfailed"
    If '$IsObject($Get(tResults)) || (tResults.%Size() '= 1) Quit "noresult"
    Set tResult = tResults.%Get(0)
    Set tContent = ##class(%DynamicObject).%FromJSON(tResult.%Get("content"))
    Set tPair = ""
    If tContent.%GetTypeOf("detail") = "object" Set tPair = tContent.%Get("detail").%Get("failedPair")
    Quit $Select(tResult.%Get("is_error"): 1, 1: 0) _ "|" _ tContent.%Get("code") _ "|" _ tPair
}

/// <p>Create the two principals and their roles after removing any left from an earlier run, and
/// answer their shared password. Both hold the install namespace's code read and the screen's two
/// pairs; only <parameter>FULLPRINCIPAL</parameter> holds <parameter>OPERATEPAIR</parameter>. The
/// grants are read back.</p>
ClassMethod CreatePrincipals(Output pPassword As %String) As %Status
{
    Set pPassword = ""
    Set tSC = ..RemovePrincipals()
    If $$$ISERR(tSC) Quit tSC
    Set tCode = ##class(OcuPilot.Test.TokenProbe).CodeDatabaseResource()
    If tCode = "" Quit $$$ERROR($$$GeneralError, "the install namespace's code database resource could not be resolved")
    Set tPassword = "Ocu" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18)), "+/=", "xyz") _ "9a"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Roles).Create(..#PRINCIPALROLE, ..#MARKER, tCode _ ":R,%Admin_Secure:U,%DB_IRISSYS:R", "")
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Roles).Create(..#FULLROLE, ..#MARKER, tCode _ ":R,%Admin_Secure:U,%DB_IRISSYS:R,%Admin_Operate:U", "")
        If $$$ISERR(tSC) Quit
        For tCase = $ListBuild(..#PRINCIPAL, ..#PRINCIPALROLE), $ListBuild(..#FULLPRINCIPAL, ..#FULLROLE) {
            Set tSC = ##class(Security.Users).Create($List(tCase, 1), $List(tCase, 2), tPassword, $List(tCase, 1) _ " probe", "", "", "", 0, 1, ..#MARKER)
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#PRINCIPAL, "%Admin_Secure", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#PRINCIPAL, "%Admin_Operate", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#FULLPRINCIPAL, "%Admin_Operate", "USE") '= 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the probe principals' grants did not read back as declared")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    If $$$ISERR(tSC) {
        Do ..RemovePrincipals()
        Quit tSC
    }
    Set pPassword = tPassword
    Quit $$$OK
}

/// <p>Delete the two principals and their roles by exact name, each only where it carries
/// <parameter>MARKER</parameter>. An object already gone is not an error.</p>
ClassMethod RemovePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tName = ..#PRINCIPAL, ..#FULLPRINCIPAL {
            If '##class(Security.Users).Exists(tName) Continue
            Kill tProps
            If $$$ISOK(##class(Security.Users).Get(tName, .tProps)) && ($Get(tProps("Comment")) = ..#MARKER) {
                Set tSC = $$$ADDSC(tSC, ##class(Security.Users).Delete(tName))
            } Else {
                Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the account " _ tName _ " is not this class's own, so it was left alone"))
            }
        }
        For tRole = ..#PRINCIPALROLE, ..#FULLROLE {
            If '##class(Security.Roles).Exists(tRole) Continue
            Kill tProps
            If $$$ISOK(##class(Security.Roles).Get(tRole, .tProps)) && ($Get(tProps("Description")) = ..#MARKER) {
                Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete(tRole))
            } Else {
                Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the role " _ tRole _ " is not this class's own, so it was left alone"))
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
