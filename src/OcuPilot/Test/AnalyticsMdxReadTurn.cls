/// <p>Pins the agent's MDX read inside a real turn (Story 20.35, AD-7, AD-11, AD-24, AD-36, AD-39, AD-60, AD-65): a turn as a principal holding MDX query's
/// pairs calls <code>analytics_mdxquery_read</code> for the Visits cube and for 2,000 grid members on rows, and the provider's next request
/// carries both answers as <code>tool_result</code> blocks framed as data -- the first the vendor's labels and cells, the second cut to the
/// context row cap with <code>rowsAvailable</code> 2,000 and <code>truncated</code> true; and a call whose statement names <code>%SEARCH</code> is
/// answered <code>ANALYTICS.MDX.SQL</code>, the failed step's <code>reason</code> is the published sentence, and the node its braces would define
/// stays undefined; a call that names a cell to drill into, or a typed DRILLTHROUGH, arrives as the vendor's listing, cut to the same row cap, and a malformed or
/// out-of-range drill is answered by its code (the drill legs grant the turn principal SELECT on the two tables a grid listing reads, and revoke it after each
/// test); and the person's Stop, posted to the turn's stop route while a slow read runs, ends that read and the turn and leaves nothing
/// running.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP, a <code>USER</code> namespace, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>PROVIDERVARIABLE</parameter> reading <code>1</code>: it turns analytics on for
/// <code>USER</code> and writes cubes there through <class>OcuPilot.Test.AnalyticsProbe</class>, creates a turn principal and the
/// <code>turnprobe</code> definition, and runs turn jobs. Everything is removed in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.AnalyticsMdxReadTurn Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter READ = "OcuPilot.Test.AnalyticsMdxRead";

/// <p>The class whose <code>VendorDrill</code> and <code>FlattenRows</code> read the vendor's own listing for a cell.</p>
Parameter MDX = "OcuPilot.Test.AnalyticsMdx";

/// <p>The class whose <code>DeepSeeProcesses</code> and <code>VendorStatus</code> read what the vendor has running.</p>
Parameter MDXJOB = "OcuPilot.Test.AnalyticsMdxJob";

/// <p>The class that holds the slow grid statement the Stop leg reads.</p>
Parameter SLOWHOLDER = "OcuPilot.Test.AnalyticsMdxReadJob";

Parameter TAG = "analyticsmdxreadturn-probe";

Parameter NAMESPACE = "USER";

/// <p>What the turn principal's second role grants: the developer resource MDX query names, and the cache database's WRITE.</p>
Parameter GRANT = "%Development:U,%DB_USER:RW";

/// <p>The splice node the refused <code>%SEARCH</code> statement's braces would increment.</p>
Parameter NODE = 359;

Property PreparedTurnPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedTurnPassword = ""
    Set ..PreparedDefinitionId = ""
    Set ..PreparedPrior = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxReadTurn turns analytics on in USER, creates an IRIS user and roles and runs a turn job against the turnprobe row, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must both read 1, so nothing was created.")
    }
    Set ..PreparedTurnPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $Username)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", $Parameter(..#FIXTURE, "USERA"), ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "Resources", 0), ..#GRANT)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISOK(tSC) Set ..PreparedDefinitionId = tId
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove"))
    If tLeft '= "" Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxReadTurn teardown left:" _ tLeft))
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxReadTurn left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Quit $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ..SourceSelect(0)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Quit $$$OK
}

/// <p>Script the provider to call <code>analytics_mdxquery_read</code> once for each statement of <var>pStatements</var> (a
/// <class>%DynamicArray</class>), as the calls <code>toolu_mdx_0</code>, <code>toolu_mdx_1</code>..., then to answer <code>done</code>; run the turn
/// as the principal on <code>USER</code>; and wait for it to end. The turn's final view is <var>pView</var>; the state is answered. The tool
/// results the provider's second request carries are left in <var>pByUse</var>, subscripted by call id.</p>
Method RunTurn(pStatements As %DynamicArray, Output pView, ByRef pByUse) As %String
{
    Set tInputs = []
    For tI = 0:1:pStatements.%Size() - 1 {
        Set tInput = {}
        Do tInput.%Set("statement", pStatements.%Get(tI), "string")
        Do tInputs.%Push(tInput)
    }
    Quit ..RunInputs(tInputs, .pView, .pByUse)
}

/// <p>As <method>RunTurn</method>, for calls whose whole argument objects are <var>pInputs</var> (a <class>%DynamicArray</class> of objects), so a call can
/// carry <code>drill</code> beside its statement.</p>
Method RunInputs(pInputs As %DynamicArray, Output pView, ByRef pByUse) As %String
{
    Kill pByUse
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tCalls = []
    For tI = 0:1:pInputs.%Size() - 1 {
        Set tCall = {}
        Do tCall.%Set("id", "toolu_mdx_" _ tI, "string")
        Do tCall.%Set("name", "analytics_mdxquery_read", "string")
        Do tCall.%Set("input", pInputs.%Get(tI))
        Do tCalls.%Push(tCall)
    }
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tCalls))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedTurnPassword, .tStatus, .tText)
    Do $$$AssertNotEquals(tConvId, "", "the principal starts a conversation: " _ tStatus)
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn?ns=" _ ..#NAMESPACE, tUser, ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "StartBody", "read the probe cubes", tConvId), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the turn starts: " _ $Extract(tText, 1, 200))
    If tStatus '= 202 Quit ""
    Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", ##class(%DynamicObject).%FromJSON(tText).turnId, tUser, ..PreparedTurnPassword, 90, .pView)
    Do $$$AssertEquals(tState, "completed", "the turn completes: " _ $Select($IsObject(pView): $Extract(pView.%ToJSON(), 1, 600), 1: "no view"))
    If tState '= "completed" Quit tState
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 2, "after two provider calls")
    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    Set tIterator = tMessages.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMessage) {
        If (tMessage.%Get("role") '= "user") || (tMessage.%GetTypeOf("content") '= "array") Continue
        Set tBlocks = tMessage.%Get("content").%GetIterator()
        While tBlocks.%GetNext(.tBlockIndex, .tBlock) {
            If tBlock.%Get("type") = "tool_result" Set pByUse(tBlock.%Get("tool_use_id")) = tBlock.%Get("content")
        }
    }
    Quit tState
}

/// <p>The parsed body of the framed tool result <var>pContent</var>, or <code>""</code> when it is not framed as data or does not parse.</p>
Method Body(pContent As %String) As %DynamicObject
{
    Set tBody = $ClassMethod(..#FIXTURE, "Unwrapped", pContent, .tWrapped)
    Do $$$AssertTrue(tWrapped, "the result reaches the model framed as data (AD-60)")
    Set tParsed = ""
    Try { Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(tBody) } Catch {}
    Do $$$AssertTrue($IsObject(tParsed), "and parses")
    Quit tParsed
}

/// <p>AC1, AD-24, AD-60: a turn reads the Visits cube's cells, which reach the model as the vendor's own labels and values, and 2,000 grid members on
/// rows, which reach it cut to the context row cap read now, with <code>rowsAvailable</code> 2,000 and <code>truncated</code> true.</p>
/// <p>Mutation (Rule 19): drop the label column from <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.Projected</method> -- the first read no longer equals
/// the vendor's and this goes red.</p>
Method TestATurnReadsCellsFramedAsDataAndTheRowCapCutsThem()
{
    Set tVisits = $Parameter(..#READ, "VISITS")
    Set tGrid = "SELECT {[Measures].[Amount]} ON 0, [Sub].[H1].[Sub].Members ON 1 FROM [OcuPilotProbeGrid]"
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).Resolve(.tSwitch), "the switches resolve")
    Set tCap = tSwitch("contextRowCap")
    Do $$$AssertTrue((tCap >= 1) && (tCap < 1000), "the context row cap is below the port's 1,000 rows: " _ tCap)
    Set tState = ..RunTurn([(tVisits), (tGrid)], .tView, .tByUse)
    If tState '= "completed" Quit
    Set tCells = ..Body($Get(tByUse("toolu_mdx_0")))
    If $IsObject(tCells) {
        Do $$$AssertEquals(tCells.outcome _ " " _ tCells.namespace, "cells USER", "the first read is a cells answer in USER")
        Do $$$AssertEquals($ClassMethod(..#READ, "FlattenCells", tCells), $ClassMethod("OcuPilot.Test.AnalyticsMdx", "VendorCells", tVisits), "and is the vendor's labels and cells")
    }
    Set tBig = ..Body($Get(tByUse("toolu_mdx_1")))
    If $IsObject(tBig) {
        Do $$$AssertEquals(tBig.rowsSent _ " " _ tBig.rowsAvailable _ " " _ tBig.truncated _ " " _ tBig.rows.%Size(), tCap _ " 2000 1 " _ tCap, "the grid read carries the context row cap's rows of 2,000 and says it was cut")
    }
}

/// <p>AC3, AD-39, AD-60: a call whose statement names <code>%SEARCH</code> is answered <code>ANALYTICS.MDX.SQL</code> as an error result framed as
/// data; the failed tool step carries the published sentence as its <code>reason</code>; the node the statement's braces would increment stays
/// undefined; and the turn completes.</p>
/// <p>Mutation (Rule 19): drop the <code>ANALYTICS.</code> branch from <method>OcuPilot.Api.Error.ReasonForToolCode</method> -- the step's reason
/// leg goes red.</p>
Method TestATurnIsRefusedACodeBearingStatementAndTheCardGetsTheSentence()
{
    Set tNode = ..#NODE
    Kill ^|"USER"|OcuPilotProbeMdxSplice(tNode)
    Set tStatement = "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeVisits] WHERE %SEARCH.&[ID > {$Increment(^OcuPilotProbeMdxSplice(" _ tNode _ "))}]"
    Set tState = ..RunTurn([(tStatement)], .tView, .tByUse)
    If tState '= "completed" Quit
    Set tBody = ..Body($Get(tByUse("toolu_mdx_0")))
    If $IsObject(tBody) Do $$$AssertEquals(tBody.code, "ANALYTICS.MDX.SQL", "the model receives the refusal's code")
    Set tFailed = ""
    For tI = 0:1:tView.steps.%Size() - 1 {
        Set tStep = tView.steps.%Get(tI)
        If (tStep.kind = "tool") && (tStep.name = "analytics.mdxquery.read") Set tFailed = tStep
    }
    Do $$$AssertTrue($IsObject(tFailed), "the turn recorded the tool step")
    If $IsObject(tFailed) Do $$$AssertEquals(tFailed.status _ " " _ tFailed.code _ " " _ tFailed.reason, "error ANALYTICS.MDX.SQL " _ ##class(OcuPilot.Api.AnalyticsError).#REASONMDXSQL, "and it failed with the code and the published sentence")
    Do $$$AssertEquals($Data(^|"USER"|OcuPilotProbeMdxSplice(tNode)), 0, "the node the statement's braces would define is undefined")
}

/// <p>Grant (<var>pGrant</var> 1) or revoke (0) SELECT on the two tables a grid listing reads, the cube's source table and its listing table, to the turn principal in
/// <code>USER</code>, and answer whether both statements ran: a cell's listing, and a typed DRILLTHROUGH's, read them as the signed-in user. A revoke of a grant that was
/// never made answers 0 and changes nothing.</p>
ClassMethod SourceSelect(pGrant As %Boolean) As %Boolean
{
    Set tSource = $Parameter(..#PROBE, "GRIDSOURCE")
    Set tTables = $ListBuild($Translate($Piece(tSource, ".", 1, *-1), ".", "_") _ "." _ $Piece(tSource, ".", *), $Translate($Parameter(..#PROBE, "GRIDCLASS"), ".", "_") _ ".Listing")
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tOrigNS = $NAMESPACE
    Set tRan = 1
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tI = 1:1:$ListLength(tTables) {
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, $Select(pGrant: "GRANT SELECT ON " _ $List(tTables, tI) _ " TO " _ tUser, 1: "REVOKE SELECT ON " _ $List(tTables, tI) _ " FROM " _ tUser))
            If tResult.%SQLCODE '= 0 Set tRan = 0
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tRan = 0
    }
    Quit tRan
}

/// <p>AC2, AC5, AD-24, AD-60: a turn names a cell to drill into, and the listing for that cell reaches the model as the vendor's own, framed as data; a drill past
/// the answer's axes is answered <code>ANALYTICS.MDX.INPUT</code> and one whose row is 0 <code>TOOL.ARGUMENTS</code>; and a typed DRILLTHROUGH of the grid's 50,000
/// rows reaches the model cut to the context row cap read now, with <code>rowsAvailable</code> the port's 1,000 and <code>truncated</code> true.</p>
/// <p>Mutation (Rule 19): ignore <code>drill</code> in <method>OcuPilot.Port.AnalyticsPort.MdxRun</method> (pass an empty row) -- the first call comes back as cells
/// and this goes red.</p>
Method TestATurnDrillsIntoACellAndAListingIsCutToTheContextRowCap()
{
    Set tCrossjoin = $Parameter(..#READ, "CROSSJOIN")
    Set tGridListing = "DRILLTHROUGH SELECT FROM [OcuPilotProbeGrid]"
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Switch).Resolve(.tSwitch), "the switches resolve")
    Set tCap = tSwitch("contextRowCap")
    Do $$$AssertTrue((tCap >= 4) && (tCap < 1000), "the context row cap holds the four-row cell listing and is below the port's 1,000 rows: " _ tCap)
    Set tInputs = []
    Do tInputs.%Push({"statement": (tCrossjoin), "drill": {"row": 2, "column": 1}})
    Do tInputs.%Push({"statement": (tCrossjoin), "drill": {"row": 3, "column": 1}})
    Do tInputs.%Push({"statement": (tCrossjoin), "drill": {"row": 0, "column": 1}})
    Do tInputs.%Push({"statement": (tGridListing)})
    Do $$$AssertTrue(..SourceSelect(1), "the turn principal is granted SELECT on the grid's source table")
    Set tState = ..RunInputs(tInputs, .tView, .tByUse)
    If tState '= "completed" Quit
    Set tCell = ..Body($Get(tByUse("toolu_mdx_0")))
    If $IsObject(tCell) {
        Do $$$AssertEquals(tCell.outcome _ " " _ tCell.namespace, "rows USER", "the drill's answer is a listing in USER: " _ $Extract(tCell.%ToJSON(), 1, 400))
        Set tExpected = $ClassMethod(..#MDX, "VendorDrill", tCrossjoin, 2, 1, .tText)
        Do $$$AssertEquals($ClassMethod(..#MDX, "FlattenRows", tCell), tExpected, "and is the vendor's listing for cell (2, 1): " _ tText)
        Do $$$AssertEquals($ClassMethod(..#MDX, "FlattenRows", tCell), "2,0,2;2,0,2;2,0,2;2,0,2", "the four facts of Sub 2 and Sub2 0")
    }
    Set tPast = ..Body($Get(tByUse("toolu_mdx_1")))
    If $IsObject(tPast) Do $$$AssertEquals(tPast.code, "ANALYTICS.MDX.INPUT", "a drill past the answer's axes is answered by its code")
    Set tBad = ..Body($Get(tByUse("toolu_mdx_2")))
    If $IsObject(tBad) Do $$$AssertEquals(tBad.code, "TOOL.ARGUMENTS", "and a drill whose row is 0 is refused as a bad argument")
    Set tListing = ..Body($Get(tByUse("toolu_mdx_3")))
    If $IsObject(tListing) {
        Do $$$AssertEquals(tListing.outcome _ " " _ tListing.rowsSent _ " " _ tListing.rowsAvailable _ " " _ tListing.truncated _ " " _ tListing.rows.%Size(), "rows " _ tCap _ " 1000 1 " _ tCap, "the typed listing carries the context row cap's rows of the port's 1,000 and says it was cut")
    }
}

/// <p>That the vendor has nothing of the statement <var>pStatement</var> running: its status reads 100 and no process in <code>USER</code> runs <code>%DeepSee</code>
/// code, each polled for up to five seconds because a worker exits just after the vendor reports the cancel.</p>
Method AssertNothingRuns(pStatement As %String)
{
    Set tDeadline = $ZHorolog + 5
    For {
        Set tProcesses = $ClassMethod(..#MDXJOB, "DeepSeeProcesses")
        If (tProcesses = "") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Do $$$AssertEquals($ClassMethod(..#MDXJOB, "VendorStatus", pStatement), 100, "the vendor reports its query finished")
    Do $$$AssertEquals($ClassMethod(..#MDXJOB, "DeepSeeProcesses"), "", "and no process in USER runs %DeepSee code")
}

/// <p>Cancel the vendor's run of the statement <var>pStatement</var> in <code>USER</code>, so a stop that did not reach the read leaves no orphaned work in the
/// vendor's queue for the tests that follow.</p>
ClassMethod CancelRun(pStatement As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%DeepSee.ResultSet).%New()
        If $$$ISOK(tRS.%PrepareMDX(pStatement)) Do ##class(%DeepSee.ResultSet).%CancelQuery(tRS.%GetCubeName(), tRS.%GetQueryKey())
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>AC4, AD-7, AD-31, AD-33: the person's Stop, posted to the turn's stop route while a turn's read of the slow grid query is running, ends that read and the turn
/// well inside the two minutes the read is otherwise bound to: the turn ends <code>stopped</code> within the port's settle time of the post, and the vendor reports the
/// query finished with no process in <code>USER</code> running <code>%DeepSee</code> code. The turn is the real loop's, so the key the read polls is the one the loop
/// stashed, and each status poll of the test renews the lease, so the stop signal alone ends the read.</p>
/// <p>Mutation (Rule 19): answer 0 from <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.MdxStopRequested</method> -- the read runs on to its two-minute bound, the turn is
/// still running when the wait ends and this goes red.</p>
Method TestThePersonsStopEndsAReadInATurnAndLeavesNothingRunning()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tSlow = $Parameter(..#SLOWHOLDER, "SLOWSTOP")
    Set tQuiet = $ZHorolog + 5
    While ($ClassMethod(..#MDXJOB, "DeepSeeProcesses") '= "") && ($ZHorolog < tQuiet) {
        Hang 0.25
    }
    Do $$$AssertEquals($ClassMethod(..#MDXJOB, "DeepSeeProcesses"), "", "no process in USER runs %DeepSee code before the turn starts")
    Set tCall = {}
    Do tCall.%Set("id", "toolu_mdx_stop", "string")
    Do tCall.%Set("name", "analytics_mdxquery_read", "string")
    Do tCall.%Set("input", {"statement": (tSlow)})
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(tCall)]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedTurnPassword, .tStatus, .tText)
    Do $$$AssertNotEquals(tConvId, "", "the principal starts a conversation: " _ tStatus)
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn?ns=" _ ..#NAMESPACE, tUser, ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "StartBody", "read the slow grid", tConvId), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the turn starts: " _ $Extract(tText, 1, 200))
    If tStatus '= 202 Quit
    Set tTurnId = ##class(%DynamicObject).%FromJSON(tText).turnId
    Set tDeadline = $ZHorolog + 30
    For {
        Set tVendor = +$ClassMethod(..#MDXJOB, "VendorStatus", tSlow)
        If ((tVendor >= 10) && (tVendor < 100)) || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Do $$$AssertTrue((tVendor >= 10) && (tVendor < 100), "the read is running: the vendor reports its query started and not finished (" _ tVendor _ ")")
    Set tPosted = $ZHorolog
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn/" _ tTurnId _ "/stop", tUser, ..PreparedTurnPassword, "", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ##class(%DynamicObject).%FromJSON(tText).stopRequested, "200 1", "the stop is requested: " _ tText)
    Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", tTurnId, tUser, ..PreparedTurnPassword, 40, .tView)
    Set tTook = $ZHorolog - tPosted
    Do $$$AssertEquals(tState, "stopped", "the turn ends stopped, not still running or completed: " _ $Select($IsObject(tView): $Extract(tView.%ToJSON(), 1, 600), 1: "no view"))
    Do $$$AssertTrue(tTook < ($Parameter("OcuPilot.Port.AnalyticsPort", "MDXSETTLESECONDS") + 5), "within the settle time of the stop, not at the two-minute bound: " _ $FNumber(tTook, "", 2) _ " s")
    If tState '= "stopped" Do ..CancelRun(tSlow)
    Do ..AssertNothingRuns(tSlow)
}

}
