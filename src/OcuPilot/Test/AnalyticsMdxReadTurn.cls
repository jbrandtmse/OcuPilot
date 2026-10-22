/// <p>Pins the agent's MDX read inside a real turn (Story 20.35, AD-7, AD-11, AD-24, AD-36, AD-39, AD-60, AD-65): a turn as a principal holding MDX query's
/// pairs calls <code>analytics_mdxquery_read</code> for the Visits cube and for 2,000 grid members on rows, and the provider's next request
/// carries both answers as <code>tool_result</code> blocks framed as data -- the first the vendor's labels and cells, the second cut to the
/// context row cap with <code>rowsAvailable</code> 2,000 and <code>truncated</code> true; and a call whose statement names <code>%SEARCH</code> is
/// answered <code>ANALYTICS.MDX.SQL</code>, the failed step's <code>reason</code> is the published sentence, and the node its braces would define
/// stays undefined.</p>
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
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Quit $$$OK
}

/// <p>Script the provider to call <code>analytics_mdxquery_read</code> once for each statement of <var>pStatements</var> (a
/// <class>%DynamicArray</class>), as the calls <code>toolu_mdx_0</code>, <code>toolu_mdx_1</code>..., then to answer <code>done</code>; run the turn
/// as the principal on <code>USER</code>; and wait for it to end. The turn's final view is <var>pView</var>; the state is answered. The tool
/// results the provider's second request carries are left in <var>pByUse</var>, subscripted by call id.</p>
Method RunTurn(pStatements As %DynamicArray, Output pView, ByRef pByUse) As %String
{
    Kill pByUse
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tCalls = []
    For tI = 0:1:pStatements.%Size() - 1 {
        Set tCall = {"input": {}}
        Do tCall.%Set("id", "toolu_mdx_" _ tI, "string")
        Do tCall.%Set("name", "analytics_mdxquery_read", "string")
        Do tCall.input.%Set("statement", pStatements.%Get(tI), "string")
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

}
