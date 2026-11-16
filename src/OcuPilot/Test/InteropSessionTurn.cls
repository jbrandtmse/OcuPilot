/// <p>Story 24.4's integration criterion (AD-8, AD-22, AD-29, AD-31, AD-60, AD-62): a principal holding the message viewer's pair
/// (<code>%Ens_Portal:USE</code> and <code>%Ens_MessageHeader:USE</code>), READ on the install namespace's database and not
/// <code>%Ens_MessageContent:USE</code> runs a real turn job against the armed <code>turnprobe</code> row. The turn calls
/// <code>interop_sessions_bysource</code> for a session this class plants, then <code>interop_message_body</code> for that session's
/// header: the first answers its row inside the <code>&lt;ocupilot-data&gt;</code> frame the model reads, and the second is refused
/// <code>AUTH.NOPRIVILEGE</code> naming the content pair. The turn completes.</p>
/// <p>The principal is <class>OcuPilot.Test.TurnWireFixture</class>'s, holding that fixture's
/// <method>OcuPilot.Test.TurnWireFixture.Resources</method>(0) and a second role granting the viewer's pair, read back before the test
/// runs. It needs both <parameter>ARMINGVARIABLE</parameter> and <parameter>PROVIDERVARIABLE</parameter> armed; after the method no probe
/// job, turn, slot or stub node remains, the planted headers and body are removed, and the principals, their roles and the probe
/// definition are removed in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.InteropSessionTurn Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "interopsession-probe";

Parameter PLANT = "OcuPilot.Test.InteropSessionRead";

/// <p>What the second role grants: the viewer's pair, and not the Contents pane's.</p>
Parameter VIEWERGRANT = "%Ens_Portal:U,%Ens_MessageHeader:U";

/// <p>The two tools the turn calls, as the provider names them.</p>
Parameter SEARCHTOOL = "interop_sessions_bysource";

Parameter BODYTOOL = "interop_message_body";

Property PreparedPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

/// <p>This test's marker, the planted header and the body it names.</p>
Property PreparedMarker As %String;

Property PreparedHeader As %String;

Property PreparedBodyId As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedDefinitionId = ""
    Set ..PreparedPrior = ""
    Set ..PreparedSetupOk = 0
    Set ..PreparedMarker = ""
    Set ..PreparedHeader = ""
    Set ..PreparedBodyId = ""
    Quit $$$OK
}

/// <p>Refuse unless both variables arm the instance, create the principal and the default <code>turnprobe</code> definition, and read back
/// through <method>OcuPilot.Test.InteropFloorFixture.Composed</method> that the principal holds <code>%Ens_Portal:USE</code> and
/// <code>%Ens_MessageHeader:USE</code> and neither <code>%Ens_MessageContent:USE</code>, <code>%Development:USE</code> nor an
/// administrative resource.</p>
Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropSessionTurn creates IRIS users and roles and runs turn jobs against the turnprobe row, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must both read 1, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources", 0), ..#VIEWERGRANT)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tId
    Set tSC = ##class(OcuPilot.Test.InteropFloorFixture).Composed(tUser, .tComposed)
    If $$$ISERR(tSC) Quit tSC
    Set tHolds = ##class(OcuPilot.Test.InteropFloorFixture).Holds(tComposed, "%Ens_Portal", "USE") && ##class(OcuPilot.Test.InteropFloorFixture).Holds(tComposed, "%Ens_MessageHeader", "USE")
    Set tLacks = '##class(OcuPilot.Test.InteropFloorFixture).Holds(tComposed, "%Ens_MessageContent", "USE") && '##class(OcuPilot.Test.InteropFloorFixture).Holds(tComposed, "%Development", "USE") && '##class(OcuPilot.Test.InteropFloorFixture).HoldsAdministrative(tComposed)
    Set ..PreparedSetupOk = tHolds && tLacks
    If '..PreparedSetupOk Quit $$$ERROR($$$GeneralError, "Setup could not read back that " _ tUser _ " holds the viewer's pair and not the content pair, %Development:USE or an administrative resource")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropSessionTurn teardown left:" _ tLeft)
    Quit tSC
}

/// <p>Store the session the turn finds: a header sourced by this test's marker, in its own session, made a minute ago, naming a stored
/// body.</p>
Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Set tSC = $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedMarker = $Parameter(..#PLANT, "PREFIX") _ "U" _ $Extract($Translate($System.Util.CreateGUID(), "-", ""), 1, 8)
    Set tBody = ##class(Ens.StringRequest).%New()
    Set tBody.StringValue = "OcuPilot session turn " _ ..PreparedMarker
    Set tSC = tBody.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedBodyId = tBody.%Id()
    Set ..PreparedHeader = $ClassMethod($Parameter(..#PLANT, "FIXTURE"), "StoreHeader", "", "Ens.StringRequest", ..PreparedBodyId, 1, 9, 60, "", "", 1, "", ..PreparedMarker _ "In", ..PreparedMarker _ "Op")
    Quit $Select(..PreparedHeader: $$$OK, 1: $$$ERROR($$$GeneralError, "the planted header could not be stored"))
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Do $$$AssertEquals($ClassMethod(..#PLANT, "Clear", ..PreparedMarker), 0, "no planted header is left")
    If ..PreparedBodyId '= "" Do ##class(Ens.StringRequest).%DeleteId(..PreparedBodyId)
    Quit $$$OK
}

/// <p>The recorded <code>messages</code> of provider call <var>pCall</var>, parsed.</p>
ClassMethod Messages(pCall As %Integer) As %DynamicArray
{
    Quit ##class(%DynamicArray).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, pCall, "messages"))
}

/// <p>The step of <var>pView</var> that is the tool <var>pName</var> (dotted), or <code>""</code>.</p>
ClassMethod StepOf(pView As %DynamicObject, pName As %String) As %DynamicObject
{
    Set tIterator = pView.steps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        If (tStep.kind = "tool") && (tStep.name = pName) Quit
        Set tStep = ""
    }
    Quit $Get(tStep)
}

/// <p>The turn's first tool call finds the planted session through <code>interop_sessions_bysource</code> and the model reads its row inside
/// the <code>&lt;ocupilot-data&gt;</code> frame; its second asks for the session's header's body and is refused
/// <code>AUTH.NOPRIVILEGE</code>, naming <code>%Ens_MessageContent:USE</code>; the turn completes, and its three
/// provider calls all ran.</p>
Method TestATurnFindsASessionAndIsRefusedItsBody()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup read back the principal's grants")
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tSearch = [{"id": "toolu_search", "input": {}}]
    Do tSearch.%Get(0).%Set("name", ..#SEARCHTOOL, "string")
    Do tSearch.%Get(0).input.%Set("source", ..PreparedMarker _ "In", "string")
    Do tSearch.%Get(0).input.%Set("hours", 2, "number")
    Set tBody = [{"id": "toolu_body", "input": {}}]
    Do tBody.%Get(0).%Set("name", ..#BODYTOOL, "string")
    Do tBody.%Get(0).input.%Set("message", ..PreparedHeader, "string")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tSearch))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tBody))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))

    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedPassword, .tStatus, .tText)
    Do $$$AssertNotEquals(tConvId, "", "the principal starts a conversation: " _ tStatus _ " " _ $Extract(tText, 1, 200))
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "StartBody", "find the session from the probe host, then read its body", tConvId), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the turn starts: " _ $Extract(tText, 1, 200))
    If tStatus '= 202 Quit
    Set tId = ##class(%DynamicObject).%FromJSON(tText).turnId
    Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", tId, tUser, ..PreparedPassword, 60, .tView)
    Set tCode = $Select($IsObject(tView) && $IsObject(tView.%Get("error")): tView.error.%Get("code"), 1: "")
    Do $$$AssertEquals(tState _ "|" _ tCode, "completed|", "the turn completes, neither abandoned nor refused: " _ tState _ "|" _ tCode)
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 3, "and the provider answered all three calls")
    If '$IsObject(tView) Quit

    Set tSearchStep = ..StepOf(tView, $Translate(..#SEARCHTOOL, "_", "."))
    Do $$$AssertTrue($IsObject(tSearchStep), "the search ran as a step")
    If $IsObject(tSearchStep) Do $$$AssertEquals(tSearchStep.status, "ok", "the search answers: " _ tSearchStep.code)
    Set tBodyStep = ..StepOf(tView, $Translate(..#BODYTOOL, "_", "."))
    Do $$$AssertTrue($IsObject(tBodyStep), "the body read ran as a step")
    If $IsObject(tBodyStep) Do $$$AssertEquals(tBodyStep.status _ "|" _ tBodyStep.code _ "|" _ tBodyStep.failedPair, "error|AUTH.NOPRIVILEGE|%Ens_MessageContent:USE", "the body read is refused by name")

    Set tResult = ..Messages(2).%Get(2).content.%Get(0)
    Do $$$AssertEquals(tResult."tool_use_id" _ "|" _ tResult."is_error", "toolu_search|0", "the model's second call carries the search's answer: " _ $Extract(tResult.content, 1, 200))
    Set tPayload = ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tResult.content, .tWrapped)
    Do $$$AssertTrue(tWrapped && (tResult.content [ "<ocupilot-data"), "the answer arrives framed as data")
    If 'tWrapped Quit
    Set tRows = ##class(%DynamicAbstractObject).%FromJSON(tPayload).rows
    Do $$$AssertEquals(tRows.%Size() _ "|" _ tRows.%Get(0).SessionId _ "|" _ tRows.%Get(0).Source, "1|" _ ..PreparedHeader _ "|" _ ..PreparedMarker _ "In", "the planted session's row is the one the model reads")
}

}
