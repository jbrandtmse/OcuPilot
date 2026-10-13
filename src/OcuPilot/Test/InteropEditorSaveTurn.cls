/// <p>Pins an editor save over a real turn (Story 20.16, AC7, AD-24, AD-53): a principal holding the editor screen's pairs,
/// <code>%Development:USE</code>, <code>%Ens_Code:WRITE</code> and the routines database's WRITE posts the data transformation editor
/// screen's context in <code>USER</code>, so the turn starts with that editor's read and save in its tool set, and asks, through a
/// scripted model, for the class's text and then for one replacement copied from it. The proposal it mints is confirmed over HTTP as
/// the same principal, scoped to <code>USER</code> as the client scopes it: the class holds the new text and the confirm answers the
/// compile's output. A second turn in the same conversation, after the compile, replays the first and carries no compile line, and
/// neither does any request before it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP on a throwaway, a <code>USER</code> namespace
/// that runs interoperability, and both <parameter>ARMINGVARIABLE</parameter> and <parameter>PROVIDERVARIABLE</parameter> reading
/// <code>1</code>: it creates a turn principal, the <code>OcuProbe2016</code> probe package and the <code>turnprobe</code>
/// definition, and runs two turn jobs. It snapshots the stored governance policy before the test, clears it and puts it back after it.
/// Everything is removed in <method>OnAfterAllTests</method> and after each test.</p>
Class OcuPilot.Test.InteropEditorSaveTurn Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter PROBE = "OcuPilot.Test.InteropEditorProbe";

Parameter PACKAGE = "OcuProbe2016";

Parameter TAG = "interopeditorsaveturn-probe";

Parameter NAMESPACE = "USER";

/// <p>The editor screen the turn is on, and the document it shows.</p>
Parameter ROUTE = "interoperability/transforms/document";

/// <p>The turn principal's grants beyond the fixture's own: the editor screen's pairs, the development permission and the vendor
/// editors' write resource.</p>
Parameter EDITORGRANT = "%Development:U,%Ens_Portal:U,%Ens_Code:RW";

Property PreparedTurnPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropEditorSaveTurn creates an IRIS user and runs a turn job against the turnprobe row, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must both read 1, so nothing was created.")
    }
    Set ..PreparedTurnPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#NAMESPACE, .tCode, .tGlobals, .tMapped, .tResolved)
    If 'tResolved || (tCode = "") Quit $$$ERROR($$$GeneralError, "the " _ ..#NAMESPACE _ " namespace's code database could not be resolved")
    Set tGrants = ..#EDITORGRANT _ "," _ tCode _ ":RW"
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", tUser, ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "Resources", 0), tGrants)
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
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove", ..#PACKAGE))
    If tLeft '= "" Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropEditorSaveTurn teardown left:" _ tLeft))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Set tSC = $ClassMethod(..#PROBE, "Remove", ..#PACKAGE)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Make", "transform", ..#PACKAGE)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#PACKAGE), "the probe package, its generated classes and its cache node are removed")
    Quit $$$OK
}

/// <p>The tool results of the provider request <var>pCall</var>, by tool-use id, each unwrapped from its data frame:
/// <var>pResults</var>(id) is the body, and <var>pWrapped</var>(id) whether it was framed.</p>
ClassMethod ResultsOf(pCall As %Integer, Output pResults, Output pWrapped)
{
    Kill pResults, pWrapped
    Set tMessages = ""
    Try {
        Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, pCall, "messages"))
    } Catch {
        Set tMessages = ""
    }
    If '$IsObject(tMessages) Quit
    Set tIterator = tMessages.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMessage) {
        If (tMessage.%Get("role") '= "user") || (tMessage.%GetTypeOf("content") '= "array") Continue
        Set tBlocks = tMessage.%Get("content").%GetIterator()
        While tBlocks.%GetNext(.tBlockIndex, .tBlock) {
            If tBlock.%Get("type") '= "tool_result" Continue
            Set tId = tBlock.%Get("tool_use_id")
            Set pResults(tId) = $ClassMethod(..#FIXTURE, "Unwrapped", tBlock.%Get("content"), .tFramed)
            Set pWrapped(tId) = tFramed
        }
    }
}

/// <p>The JSON object <var>pText</var> holds, or <code>""</code>.</p>
ClassMethod Parsed(pText As %String) As %DynamicAbstractObject
{
    Set tParsed = ""
    Try {
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pText)
    } Catch {
        Set tParsed = ""
    }
    Quit tParsed
}

/// <p>The names of the tools in the provider request's tool array <var>pJson</var> that are not deferred, as a <class>%List</class>:
/// the turn's starting set, the others being sent with <code>defer_loading</code> for the discovery tool to find.</p>
ClassMethod StartingTools(pJson As %String) As %List
{
    Set tNames = ""
    Set tTools = ..Parsed(pJson)
    If '$IsObject(tTools) Quit tNames
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If '$IsObject(tTool) || tTool.%Get("defer_loading") Continue
        Set tNames = tNames _ $ListBuild(tTool.%Get("name"))
    }
    Quit tNames
}

/// <p>The editor screen's context as the client posts it: the route, the namespace and the document.</p>
ClassMethod EditorContext() As %DynamicObject
{
    Quit {"route": (..#ROUTE), "namespace": (..#NAMESPACE), "entity": ($ClassMethod(..#PROBE, "Name", "transform", ..#PACKAGE) _ ".cls")}
}

/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Context.ScreenTools</method> ignores <parameter>SCREENLISTED</parameter> -- the
/// starting-tools leg goes red.</p>
Method TestTheEditorsSaveIsConfirmedOverHTTPFromARealTurn()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tName = $ClassMethod(..#PROBE, "Name", "transform", ..#PACKAGE) _ ".cls"
    Set tOld = $Parameter(..#PROBE, "DTLASSIGN")
    Set tNew = "<assign value='source.StringValue_""-turn""' property='target.StringValue' action='set'/>"
    Set tRead = {"id": "toolu_read", "input": {"name": (tName)}}
    Do tRead.%Set("name", "interop_transformeditor_source", "string")
    Set tSave = {"id": "toolu_save", "input": {"Names": (tName), "Edits": [{"Old": (tOld), "New": (tNew)}], "rationale": "mark the value", "expectedImpact": "the target value ends with -turn"}}
    Do tSave.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("interop.transformeditor.save"), "string")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(tRead)]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(tSave)]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("EDITORTURNREPLYONE"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("EDITORTURNREPLYTWO"))
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedTurnPassword, .tStatus, .tText)
    Do $$$AssertNotEquals(tConvId, "", "the principal starts a conversation: " _ tStatus)
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn?ns=" _ ..#NAMESPACE, tUser, ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "StartBody", "make the value end with -turn", tConvId, ..EditorContext()), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the turn starts: " _ $Extract(tText, 1, 200))
    If tStatus '= 202 Quit
    Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", ##class(%DynamicObject).%FromJSON(tText).turnId, tUser, ..PreparedTurnPassword, 90, .tView)
    Do $$$AssertEquals(tState, "completed", "the turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 3, "after three provider calls")

    Set tStarting = ..StartingTools(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "tools"))
    Do $$$AssertTrue($ListFind(tStarting, "interop_transformeditor_source") && $ListFind(tStarting, "interop_transformeditor_save"), "the first request's starting tools hold the editor's read and its save: " _ $ListToString(tStarting))
    Do $$$AssertTrue('$ListFind(tStarting, "interop_ruleeditor_save") && '$ListFind(tStarting, "interop_processeditor_save"), "and not another editor's save")

    Do ..ResultsOf(2, .tReadResults, .tReadWrapped)
    Do $$$AssertTrue($Get(tReadWrapped("toolu_read")) && ($Get(tReadResults("toolu_read")) [ "source.StringValue"), "the read's result is framed and carries the class text: " _ $Extract($Get(tReadResults("toolu_read")), 1, 300))
    Do ..ResultsOf(3, .tResults, .tWrapped)
    Set tMinted = ..Parsed($Get(tResults("toolu_save")))
    Set tRow = ""
    If $IsObject(tMinted) && (tMinted.%GetTypeOf("changed") = "array") && (tMinted.changed.%Size() = 1) Set tRow = tMinted.changed.%Get(0)
    Do $$$AssertTrue($Get(tWrapped("toolu_save")) && $IsObject(tRow) && (tRow.%Get("kind") = "lines") && (tRow.%Get("after") [ "-turn"), "the save's result is framed and carries the changed-lines hunk: " _ $Extract($Get(tResults("toolu_save")), 1, 300))

    Set tProposals = $Select($IsObject($Get(tView)) && $IsObject(tView.%Get("proposals")): tView.proposals, 1: [])
    Do $$$AssertEquals(tProposals.%Size(), 1, "the turn holds one proposal: " _ tProposals.%ToJSON())
    If tProposals.%Size() '= 1 Quit
    Set tKey = tProposals.%Get(0).%Get("proposalId")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/proposal/" _ tKey _ "/confirm?ns=" _ ..#NAMESPACE, tUser, ..PreparedTurnPassword, .tStatus, .tText, .tHeaders, "", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the confirm, scoped to the proposal's namespace, answers 200: " _ $Extract($Get(tText), 1, 300))
    Set tBody = ..Parsed($Get(tText))
    Do $$$AssertTrue($IsObject(tBody) && $IsObject(tBody.%Get("output")) && (tBody.output.%GetTypeOf("errors") = "boolean") && 'tBody.output.errors, "the confirm answers the compile's output, with no errors: " _ $Extract($Get(tText), 1, 300))
    Do $$$AssertTrue(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#NAMESPACE, tName) [ tNew, "the class holds the new text")

    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn?ns=" _ ..#NAMESPACE, tUser, ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "StartBody", "what changed?", tConvId, ..EditorContext()), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "a second turn starts after the confirm: " _ $Extract(tText, 1, 200))
    If tStatus = 202 {
        Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", ##class(%DynamicObject).%FromJSON(tText).turnId, tUser, ..PreparedTurnPassword, 90, .tView)
        Do $$$AssertEquals(tState, "completed", "the second turn completes")
        Set tAfter = ##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 4, "messages")
        Do $$$AssertTrue(tAfter [ "EDITORTURNREPLYONE", "the request made after the compile replays the first turn")
    }
    Set tCompileLine = 0
    For tCall = 1:1:##class(OcuPilot.Test.TurnProvider).Calls(..#TAG) {
        Set tSent = ##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, tCall, "messages")
        If (tSent [ "Compiling") || (tSent [ "Compilation") || (tSent [ "qualifiers") Set tCompileLine = tCall
    }
    Do $$$AssertEquals(tCompileLine, 0, "no provider request carries a compile line")
}

}
