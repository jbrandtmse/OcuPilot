/// <p>Pins Story 18.15's enable of interoperability on both callers (AD-26, AD-51, AD-53): the
/// Namespaces list's <code>enable-interop</code> row action (<class>OcuPilot.Test.MappingActionFixture</class>)
/// and the agent's mint and confirm (<class>OcuPilot.Test.NamespaceConfirm</class>). The enable is
/// queued, awaited by the port's one poller and its finished result read once; an enable still running
/// at the bound is applied and continues (<class>OcuPilot.Test.NamespaceStartedPort</class>);
/// <code>%SYS</code> and <code>%ALL</code> are refused with the tool's own sentence before anything is
/// queued; a namespace deleted since the read queues nothing; and the agent's key is disabled at the
/// baseline.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates, enables and
/// deletes <code>OCUPROBE1815*</code> namespaces over a probe database and restores what the vendor's
/// enable changes instance-wide (<class>OcuPilot.Test.InteropProbe</class>). It takes a snapshot before
/// all tests, removes every probe object after each and after all, and fails when the snapshot after
/// all differs.</p>
Class OcuPilot.Test.NamespaceInterop Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG";

Parameter PROBE = "OcuPilot.Test.InteropProbe";

Parameter WRITE = "OcuPilot.Test.MappingWrite";

Parameter ACTION = "OcuPilot.Test.MappingActionFixture";

Parameter CONFIRM = "OcuPilot.Test.NamespaceConfirm";

Parameter ACCEPT = "OcuPilot.Test.MappingAcceptPort";

Parameter STARTED = "OcuPilot.Test.NamespaceStartedPort";

/// <p>The port the shipped-port refusal legs name: it records each write and sends it, so a refusal
/// that let an enable through shows as a recorded <code>INTEROP</code>.</p>
Parameter RECORDPORT = "OcuPilot.Test.MappingRecordPort";

Parameter PORT = "OcuPilot.Port.NamespacePort";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.NamespaceEnableInterop";

Parameter SEAM = "OcuPilot.Test.SeamNamespaceEnableInterop";

Parameter KEY = "osmgmt.namespaces.enableinterop";

Parameter SCREEN = "osmgmt.namespaces";

Parameter ACTIONID = "enable-interop";

Parameter CONSEQUENCE = "NAMESPACE.INTEROP";

/// <p>The probe snapshot taken before all tests.</p>
Property PreparedSnapshot As %Library.DynamicArray;

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSnapshot = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.NamespaceInterop creates, enables and deletes namespaces and databases on this instance and restores what the enable changes instance-wide, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSnapshot = $ClassMethod(..#PROBE, "Snapshot")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotNamespaceWritePort
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $ClassMethod(..#ACCEPT, "Clear")
    Do $ClassMethod(..#STARTED, "Clear")
    Do $ClassMethod(..#RECORDPORT, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object is removed by exact name, and what the enable changed instance-wide is restored")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>Remove every probe object and restore the policy; a failing status when the snapshot differs
/// from the one taken before all tests.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Merge tRows = ..PreparedPolicy
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows))
    If $IsObject(..PreparedSnapshot) {
        Set tDiff = $ClassMethod(..#PROBE, "Diff", ..PreparedSnapshot, $ClassMethod(..#PROBE, "Snapshot"))
        If tDiff.added.%Size() || tDiff.removed.%Size() {
            Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the instance differs from its snapshot after OcuPilot.Test.NamespaceInterop: added " _ $Extract(tDiff.added.%ToJSON(), 1, 400) _ " removed " _ $Extract(tDiff.removed.%ToJSON(), 1, 400)))
        }
    }
    Quit tSC
}

/// <p>The declarations: the port admits the enable as a bodyless queued write; the tool's parameters;
/// its pairs, the list's, then <code>%All:USE</code> and <code>%Admin_Operate:USE</code>; the
/// Namespaces list's row action; the baseline's <code>false</code>; and its script, the vendor's route
/// with the namespace upper-cased and no body (AD-59).</p>
Method TestTheDeclarations()
{
    For tPredicate = "IsMutating", "IsBodyless", "IsQueuedWrite" {
        Do $$$AssertTrue($ClassMethod("OcuPilot.Port.AdminPort", tPredicate, "Namespace.Namespace", "INTEROP"), "the port's " _ tPredicate _ " answers the enable")
    }
    Set tSaid = ""
    For tName = "TOOLNAME", "PORTCLASS", "READTYPE", "WRITETYPE", "SENDSBODY", "CHANGEACTION", "DESTRUCTIVE", "SCREENACTIONS", "SCREENVALUES", "READANSWERS", "FINGERPRINTSUBJECT", "PRECONDITIONFIELD", "CLASSICPAGES", "CONSEQUENCE" {
        Set tSaid = tSaid _ tName _ "=" _ $Parameter(..#TOOLCLASS, tName) _ ";"
    }
    Do $$$AssertEquals(tSaid, "TOOLNAME=osmgmt.namespaces.enableinterop;PORTCLASS=OcuPilot.Port.NamespacePort;READTYPE=GET;WRITETYPE=INTEROP;SENDSBODY=0;CHANGEACTION=updated;DESTRUCTIVE=1;SCREENACTIONS=enable-interop;SCREENVALUES=;READANSWERS=Globals,Routines,TempGlobals,SourceNamespace;FINGERPRINTSUBJECT=Globals,Routines;PRECONDITIONFIELD=Globals;CLASSICPAGES=%CSP.UI.Portal.Namespace;CONSEQUENCE=NAMESPACE.INTEROP;", "the tool's declarations")
    Do $$$AssertEquals($Parameter(..#TOOLCLASS, "SYSTEMREASON"), "Interoperability cannot be enabled in %SYS or %ALL.", "and its refusal of %SYS and %ALL")
    Do $$$AssertEquals($ListLength($ClassMethod(..#TOOLCLASS, "SettableFields")), 0, "it takes no argument")
    Set tPairs = $ClassMethod(..#TOOLCLASS, "PrivilegePairs", "", .tResolved)
    Do $$$AssertTrue(tResolved, "its pairs resolve")
    Set tOwn = ""
    For tI = 1:1:$ListLength(tPairs) {
        Set tOwn = tOwn _ $Select(tI = 1: "", 1: ",") _ $ListToString($List(tPairs, tI), ":")
    }
    Do $$$AssertEquals($Piece(tOwn, ",", 1, 4), "%Admin_Manage:USE,%DB_IRISSYS:READ,%All:USE,%Admin_Operate:USE", "the list's pairs, then %All:USE, then the poll's pair (AD-8)")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Screen.Descriptor.NamespaceList).RowActionIds(), ..#ACTIONID), "the Namespaces list declares the row action")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed(..#KEY, .tListed) _ "|" _ tListed, "0|1", "the baseline lists the agent's key, disabled")
    Kill tQuery
    Set tQuery("name") = "ocuprobe1815a"
    Set tSteps = ##class(OcuPilot.Port.NamespacePort).Snippet("Namespace.Namespace", "INTEROP", .tQuery, "", {"origin": "https://example", "user": "u"})
    Set tText = $Select($IsObject(tSteps) && (tSteps.%Size() = 1): tSteps.%Get(0).text, 1: "")
    Do $$$AssertTrue((tText [ "/namespace/enable-interop?name=OCUPROBE1815A'") && (tText '[ " -d "), "its script is the vendor's route, the namespace upper-cased and no body (AD-59): " _ tText)
}

/// <p>AC2: the screen's enable on <code>OCUPROBE1815A</code>, the key at its baseline, answers
/// <code>updated</code> on the namespace, done or continuing; the namespace is then enabled and a
/// portal application serves it, its task read once and gone, no second read logged, and OcuPilot's
/// own objects unchanged.</p>
/// <p>Mutation (Rule 19): remove <code>Namespace.Namespace/INTEROP</code> from
/// <parameter>OcuPilot.Port.AdminPort.QUEUEDWRITES</parameter> -> the port refuses the enable before it
/// is queued and this goes red.</p>
Method TestTheScreensEnableRoundTrips()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    Set tName = $ClassMethod(..#PROBE, "Name", "A")
    Set tOwn = $ClassMethod(..#PROBE, "OwnObjects", $ClassMethod(..#PROBE, "Snapshot")).%ToJSON()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "A"), "the probe namespace is created")
    Set tReads = ##class(OcuPilot.Test.DatabaseActionProbe).SecondReads()
    Do $$$AssertTrue(tReads >= 0, "messages.log is readable, so the second-read count below compares something")
    Set tTasks = $ClassMethod(..#PROBE, "OwnTaskCount")
    Do $$$AssertTrue(tTasks >= 0, "the async task list is readable, so the counts below compare something")
    Set ^||OcuPilotNamespaceWritePort = ..#PORT
    Set tBody = ..Act(tName, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the screen's enable answers 200")
    Do $$$AssertEquals($Select($IsObject(tBody) && (tBody.%GetTypeOf("target") = "object"): tBody.%Get("action") _ " " _ tBody.%Get("target").%Get("type") _ " " _ $ZConvert(tBody.%Get("target").%Get("id"), "U"), 1: ""), "updated namespace " _ tName, "publishing updated on the namespace")
    If $IsObject(tBody) && tBody.%Get("continues") Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SettleOwnTasks", .tSettled), "an enable that continued is settled once")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "IsEnabled", tName) _ "|" _ $ClassMethod(..#PROBE, "HasPortal", tName), "1|1", "the namespace is enabled and a portal application serves it")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "OwnTaskCount"), tTasks, "its finished task was read once and removed")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActionProbe).SecondReads(), tReads, "and no second read of it was logged (ERROR #7846)")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "OwnObjects", $ClassMethod(..#PROBE, "Snapshot")).%ToJSON(), tOwn, "OcuPilot's own objects are unchanged")
}

/// <p>AC3: the agent's enable on <code>OCUPROBE1815B</code>, its key enabled for this leg, is minted
/// destructive with the enable's consequence and no row, and its confirm is applied and marked through
/// the queued write; the namespace is then enabled and no second read was logged.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.NamespaceEnableInterop.Consequence</method>
/// answers <code>""</code> -> the proposal reads <code>"1|"</code> and this goes red.</p>
Method TestTheAgentsEnableRoundTrips()
{
    Do $$$AssertStatusOK(..EnableKey(), "the agent's enable key is enabled for this leg")
    Set tName = $ClassMethod(..#PROBE, "Name", "B")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "B"), "the probe namespace is created")
    Set tReads = ##class(OcuPilot.Test.DatabaseActionProbe).SecondReads()
    Do $$$AssertTrue(tReads >= 0, "messages.log is readable, so the second-read count below compares something")
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..#TOOLCLASS, {"Name": (tName)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's enable is minted " _ tProblem)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.changed.%Size() _ " " _ tProposal.unchangedCount, "0 0", "its card shows no row and nothing unchanged: it states the consequence")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Marked", tProposal), "1|" _ ..#CONSEQUENCE, "destructive, carrying the enable's consequence")
    Set ^||OcuPilotNamespaceWritePort = ..#PORT
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm succeeds: " _ $Get(tCode))
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tResult)): tResult.%Get("state") _ " " _ tResult.%Get("auditMarked") _ " " _ tResult.%Get("action"), 1: ""), "200 confirmed 1 updated", "applied and marked (AD-15)")
    If $IsObject($Get(tResult)) && tResult.%Get("continues") Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SettleOwnTasks", .tSettled), "an enable that continued is settled once")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "IsEnabled", tName), 1, "and the namespace is enabled")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActionProbe).SecondReads(), tReads, "with no second read of its task logged (ERROR #7846)")
}

/// <p>AD-22: at the baseline the agent's call is refused <code>GOVERNANCE.DISABLED</code> at the
/// dispatch, so no proposal is minted.</p>
/// <p>Mutation (Rule 19): set the baseline's <code>osmgmt.namespaces.enableinterop</code> line to
/// <code>true</code> -> the call is answered with a proposal and this goes red, with
/// <class>OcuPilot.Test.GovernanceBaseline</class>.</p>
Method TestAtTheBaselineTheAgentsCallIsDisabled()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    Set tName = $ClassMethod(..#PROBE, "Name", "C")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "C"), "the probe namespace is created")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "running", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a running turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.MappingWriteGateProbe).Dispatch({"turnKey": (tTurnKey), "tool": (..#KEY), "input": {"Name": (tName)}}, .tHttp, .tCode, .tPair)
    Do $$$AssertStatusOK(tSC, "the call is dispatched")
    Do $$$AssertEquals(tHttp _ " " _ tCode, "400 " _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the agent's call is refused as disabled by policy")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurnKey, $Username, .tRows)
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Size(), 1: -1), 0, "no proposal is minted")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows its call wrote")
}

/// <p>AC4 through the recording seam: <code>%SYS</code> and <code>%ALL</code>, in either case, are
/// refused with the tool's sentence on the screen's route and at the agent's mint, after a fresh read
/// that answers each, with no write recorded, so nothing is queued.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.NamespaceEnableInterop.SystemProblem</method>
/// answers <code>""</code> -> the screen's leg records an <code>INTEROP</code> write and this goes
/// red.</p>
Method TestSysAndAllAreRefusedThroughTheSeam()
{
    Set tReason = $Parameter(..#TOOLCLASS, "SYSTEMREASON")
    Set ^||OcuPilotNamespaceWritePort = ..#ACCEPT
    For tName = "%SYS", "%ALL", "%sys", "%all" {
        Set tBody = ..Act(tName, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ..Problem(tBody), "400 " _ tReason, tName _ ": the screen's enable is refused with the sentence")
        Set tSC = $ClassMethod(..#WRITE, "Mint", ..#SEAM, {"Name": (tName)}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject($Get(tProposal)) && (tHttp = 400) && (tProblem = tReason), tName _ ": the agent's enable is refused at the mint with the sentence: " _ tHttp _ " " _ tProblem)
    }
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", "no enable reached the port")
}

/// <p>AC4 through the shipped port: <code>%SYS</code> is refused with the tool's sentence on both
/// callers; <code>%ALL</code> is refused with it where the instance defines that namespace, and where
/// it does not, the fresh read answers first, 404 <code>PORT.NOTFOUND</code> on the route and an
/// absent target at the mint. The route runs through <parameter>RECORDPORT</parameter>, which sends
/// what it records, and no enable is sent either way.</p>
Method TestSysAndAllAreRefusedThroughTheShippedPort()
{
    Set tReason = $Parameter(..#TOOLCLASS, "SYSTEMREASON")
    Set tAllHeld = ..AllHeld()
    Set ^||OcuPilotNamespaceWritePort = ..#RECORDPORT
    Do $ClassMethod(..#RECORDPORT, "Clear")
    For tName = "%SYS", "%ALL" {
        Set tBody = ..Act(tName, .tStatus)
        Set tSC = $ClassMethod(..#WRITE, "Mint", ..#TOOLCLASS, {"Name": (tName)}, .tProposal, .tHttp, .tProblem)
        If (tName = "%SYS") || tAllHeld {
            Do $$$AssertEquals(tStatus _ " " _ ..Problem(tBody), "400 " _ tReason, tName _ ": the screen's enable is refused with the sentence")
            Do $$$AssertTrue('$IsObject($Get(tProposal)) && (tHttp = 400) && (tProblem = tReason), tName _ ": the agent's enable is refused at the mint with the sentence: " _ tProblem)
        } Else {
            Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, tName _ ": the instance has no such namespace, so the route's fresh read answers 404")
            Do $$$AssertTrue('$IsObject($Get(tProposal)) && (tHttp = 400) && (tProblem [ "not present"), tName _ ": and the mint refuses an absent target: " _ tProblem)
        }
    }
    Do $$$AssertEquals($ClassMethod(..#RECORDPORT, "WriteCount"), 0, "no enable was sent, so nothing was queued")
}

/// <p>A namespace deleted between the mint and the confirm, or before Proceed: the confirm is refused
/// as target changed and the route is answered 404, both through <parameter>RECORDPORT</parameter>,
/// and no enable is sent.</p>
Method TestANamespaceDeletedSinceTheReadQueuesNothing()
{
    Do $$$AssertStatusOK(..EnableKey(), "the agent's enable key is enabled, so only the target stands in the way")
    Set tName = $ClassMethod(..#PROBE, "Name", "C")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "C"), "the probe namespace is created")
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..#TOOLCLASS, {"Name": (tName)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's enable is minted " _ tProblem)
    If '$IsObject($Get(tProposal)) Quit
    Kill tQuery
    Set tQuery("name") = tName
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Namespace.Namespace", "DELETE", .tQuery, "", .tResult, .tDeleteHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the namespace is deleted after the mint")
    Set ^||OcuPilotNamespaceWritePort = ..#RECORDPORT
    Do $ClassMethod(..#RECORDPORT, "Clear")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as target changed")
    Set tBody = ..Act(tName, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "the screen's enable is answered 404 by the fresh read")
    Do $$$AssertEquals($ClassMethod(..#RECORDPORT, "WriteCount"), 0, "and no enable was sent, so nothing is queued")
}

/// <p>AD-26, AD-53 on the screen's caller: an enable of <code>OCUPROBE1815A</code> still running at
/// the bound is answered <code>updated</code> with <code>continues: true</code>, and the vendor's
/// worker then finishes it, its result read once.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.NamespacePort.Invoke</method>'s <code>INTEROP</code>
/// branch returns the admin port's answer without <code>Started</code> -> the route answers 503
/// <code>PORT.TIMEOUT</code> and this goes red.</p>
Method TestTheScreenRouteAnswersThatAnEnableStillRunningContinues()
{
    Set tName = $ClassMethod(..#PROBE, "Name", "A")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "A"), "the probe namespace is created")
    Set tSC = ##class(OcuPilot.Test.NamespaceStartedAction).Enable(tName, .tAnswer, .tStatus)
    Do $$$AssertStatusOK(tSC, "the screen route runs")
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(tAnswer) } Catch { Set tBody = "" }
    Do $$$AssertEquals(tStatus, 200, "answered 200: " _ $Get(tAnswer))
    Do $$$AssertEquals($Select($IsObject(tBody) && (tBody.%GetTypeOf("target") = "object"): tBody.%Get("action") _ " " _ tBody.%Get("target").%Get("type") _ " " _ tBody.%Get("continues") _ " " _ tBody.%GetTypeOf("continues"), 1: ""), "updated namespace 1 boolean", "publishing updated, continuing on the instance, as JSON true")
    Do ..AssertTheWorkerFinishes(tName)
}

/// <p>AD-26 on the agent's caller: an enable of <code>OCUPROBE1815B</code> still running at the bound
/// is answered 200 <code>confirmed</code> with <code>continues</code>, is not read back, and the
/// vendor's worker then finishes it, its result read once.</p>
Method TestAnAgentEnableStillRunningAtTheBoundIsApplied()
{
    Do $$$AssertStatusOK(..EnableKey(), "the agent's enable key is enabled for this leg")
    Set tName = $ClassMethod(..#PROBE, "Name", "B")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "B"), "the probe namespace is created")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = $ClassMethod(..#TOOLCLASS, "View", "", {"Name": (tName)}, 0, .tProposal, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(tSC, "the enable is minted through the tool's own view")
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ##class(OcuPilot.Test.NamespaceStartedConfirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm succeeds: " _ $Get(tCode))
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tResult)): tResult.%Get("state") _ " " _ tResult.%Get("auditMarked") _ " " _ tResult.%Get("continues"), 1: ""), "200 confirmed 1 1", "answered confirmed and marked, continuing on the instance")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)) && (tResult.%GetTypeOf("readBack") = "object"): tResult.%Get("readBack").%Get("verdict") _ "/" _ tResult.%Get("readBack").%Get("reason"), 1: ""), "unchecked/running", "an enable still running is not read back (AD-58)")
    Do ..AssertTheWorkerFinishes(tName)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), "this class removes the ledger rows it wrote")
}

/// <p>The enable the vendor's worker was still running at the bound finishes, read once, and
/// <var>pName</var> is then enabled.</p>
Method AssertTheWorkerFinishes(pName As %String)
{
    Set tGuid = $ClassMethod(..#STARTED, "LastTask")
    Do $$$AssertNotEquals(tGuid, "", "the port polled a queued task")
    Do $$$AssertEquals($ClassMethod(..#STARTED, "Settle", tGuid, $Parameter(..#PROBE, "SETTLESECONDS")), "Finished", "the vendor's worker finishes the enable after the port stopped waiting")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "IsEnabled", pName), 1, pName _ ": is enabled")
}

/// <p>Enable the agent's enable key over the snapshot this class took.</p>
Method EnableKey() As %Status
{
    Kill tSettings
    Set tSettings(..#KEY) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>Send <code>enable-interop</code> for <var>pName</var> to the Namespaces list's route through
/// <class>OcuPilot.Test.MappingActionFixture</class>, answering the parsed envelope (or
/// <code>""</code>) and the status in <var>pStatus</var>.</p>
ClassMethod Act(pName As %String, Output pStatus As %Integer) As %DynamicObject
{
    Set tBody = {}
    Do tBody.%Set("action", ..#ACTIONID, "string")
    Do tBody.%Set("id", pName, "string")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .tAnswer, .pStatus)
    Set tParsed = ""
    Try { Set tParsed = ##class(%DynamicObject).%FromJSON(tAnswer) } Catch {}
    Quit tParsed
}

/// <p>The <code>detail.problem</code> of envelope <var>pBody</var>, or <code>""</code>.</p>
ClassMethod Problem(pBody As %DynamicObject) As %String
{
    If '$IsObject(pBody) || (pBody.%GetTypeOf("detail") '= "object") Quit ""
    Quit pBody.%Get("detail").%Get("problem")
}

/// <p>The <code>code</code> of envelope <var>pBody</var>, or <code>""</code>.</p>
ClassMethod Code(pBody As %DynamicObject) As %String
{
    If '$IsObject(pBody) Quit ""
    Quit pBody.%Get("code")
}

/// <p>Whether the instance's configuration defines the <code>%ALL</code> namespace.</p>
ClassMethod AllHeld() As %Boolean
{
    Set tHeld = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tHeld = ''##class(Config.Namespaces).Exists("%ALL")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tHeld = 0
    }
    Quit tHeld
}

}
