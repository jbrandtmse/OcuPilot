/// <p>Pins the agent's class and routine creates over a real turn (Story 20.20, AC8, AD-53, AD-54, DW-2242): a
/// principal holding the development permission, WRITE on <code>USER</code>'s routines database and READ alone on
/// <code>HSCUSTOM</code>'s, asks through a scripted model for a new class in <code>USER</code>. The proposal is
/// confirmed over HTTP, scoped to <code>USER</code>: the class is held, compiled, and its confirm answers the compile's
/// output with no errors. A second turn in <code>USER</code> proposes a new routine and a save of the class, and
/// each is confirmed over HTTP scoped to <code>HSCUSTOM</code>, which the principal may not write: both are answered 200
/// and written in <code>USER</code>, where the proposal stored the namespace (DW-2242). No provider request carries a
/// compile line, though the second turn's requests carry the first turn's history.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP on a throwaway, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>PROVIDERVARIABLE</parameter> reading <code>1</code>: it creates
/// a turn principal and a <code>turnprobe</code> definition, runs two turn jobs, and creates the probe documents
/// <code>OcuProbe203</code> names in <code>USER</code>. Everything is removed in <method>OnAfterAllTests</method> and
/// after the test.</p>
Class OcuPilot.Test.ExplorerCreateTurn Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "explorercreateturn-probe";

Parameter NAMESPACE = "USER";

Parameter OTHERNAMESPACE = "HSCUSTOM";

/// <p>The probe package, in <parameter>NAMESPACE</parameter>.</p>
Parameter PACKAGE = "OcuProbe203";

Parameter PROBECLASS = "OcuProbe203.Made";

Parameter PROBEROUTINE = "OcuProbe203Made.mac";

Parameter DEVELOPMENTGRANT = "%Development:U";

Property PreparedTurnPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ExplorerCreateTurn creates an IRIS user and runs a turn job, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must both read 1, so nothing was created.")
    }
    Set ..PreparedTurnPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#NAMESPACE, .tCode, .tGlobals, .tMapped, .tResolved)
    If 'tResolved || (tCode = "") Quit $$$ERROR($$$GeneralError, "the " _ ..#NAMESPACE _ " namespace's code database could not be resolved")
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#OTHERNAMESPACE, .tOtherCode, .tOtherGlobals, .tOtherMapped, .tOtherResolved)
    If 'tOtherResolved || (tOtherCode = "") Quit $$$ERROR($$$GeneralError, "the " _ ..#OTHERNAMESPACE _ " namespace's code database could not be resolved")
    ; WRITE on the request's own namespace's code database is withheld: the confirm of a proposal stored in USER
    ; must write there, whatever namespace it is scoped to (DW-2242).
    Set tGrants = ..#DEVELOPMENTGRANT _ "," _ tCode _ ":RW," _ tOtherCode _ ":R"
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
    Set tSC = $$$ADDSC(tSC, ..RemoveProbes())
    If tLeft '= "" Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.ExplorerCreateTurn teardown left:" _ tLeft))
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
    Set tSC = ..RemoveProbes()
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Quit $$$OK
}

/// <p>Remove the probe package and routine from <parameter>NAMESPACE</parameter>, the namespace switched by explicit
/// save and restore.</p>
ClassMethod RemoveProbes() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.DeletePackage(..#PACKAGE, "-d")
        If ##class(%RoutineMgr).Exists(..#PROBEROUTINE) Do ##class(%RoutineMgr).Delete(..#PROBEROUTINE)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
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

/// <p>Confirm proposal <var>pKey</var> over HTTP as <var>pUser</var>, with the request scoped to <var>pNamespace</var>:
/// the status, and the body's text.</p>
Method Confirm(pKey As %String, pNamespace As %String, pUser As %String, Output pText As %String) As %Integer
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/proposal/" _ pKey _ "/confirm?ns=" _ pNamespace, pUser, ..PreparedTurnPassword, .tStatus, .pText, .tHeaders, "", "application/json")
    If $$$ISERR(tSC) Quit 0
    Quit tStatus
}

/// <p>Mutation (Rule 19): <class>OcuPilot.Port.AtelierPort</class>'s <code>CREATE</code> skips the compile -- the
/// first confirm's compiled and output legs go red. <method>OcuPilot.Screen.Tool.ExplorerSave.CodeWritePairs</method>
/// reads the request's namespace rather than the stored one -- the second turn's confirms go red.</p>
Method TestTheAgentsCreatesAreConfirmedOverHTTPAndCompile()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tClassText = $ClassMethod("OcuPilot.Test.ExplorerCreateProbe", "NewClassText", ..#PROBECLASS)
    Set tCreate = {"id": "toolu_class", "input": {"Names": (..#PROBECLASS _ ".cls"), "Text": (tClassText), "rationale": "a probe class", "expectedImpact": "the probe class is held"}}
    Do tCreate.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.classes.create"), "string")
    Set tRoutineText = $ClassMethod("OcuPilot.Test.ExplorerCreateProbe", "NewRoutineText", ..#PROBEROUTINE)
    Set tRoutine = {"id": "toolu_routine", "input": {"Names": (..#PROBEROUTINE), "Text": (tRoutineText), "rationale": "a probe routine", "expectedImpact": "the routine is held"}}
    Do tRoutine.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.routines.create"), "string")
    Set tSave = {"id": "toolu_save", "input": {"Names": (..#PROBECLASS _ ".cls"), "Edits": [{"Old": "    Quit 1", "New": "    Quit 2"}], "rationale": "change the answer", "expectedImpact": "the method answers 2"}}
    Do tSave.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.classes.save"), "string")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(tCreate)]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("CREATETURNREPLYONE"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(tRoutine), (tSave)]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("CREATETURNREPLYTWO"))
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedTurnPassword, .tStatus, .tText)
    Do $$$AssertNotEquals(tConvId, "", "the principal starts a conversation: " _ tStatus)
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn?ns=" _ ..#NAMESPACE, tUser, ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "StartBody", "create the probe class", tConvId), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the first turn starts: " _ $Extract(tText, 1, 200))
    If tStatus '= 202 {
        Do ..RemoveProbes()
        Quit
    }
    Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", ##class(%DynamicObject).%FromJSON(tText).turnId, tUser, ..PreparedTurnPassword, 90, .tView)
    Do $$$AssertEquals(tState, "completed", "the first turn completes")
    Set tProposals = $Select($IsObject($Get(tView)) && $IsObject(tView.%Get("proposals")): tView.proposals, 1: [])
    Do $$$AssertEquals(tProposals.%Size(), 1, "the first turn holds the class create's proposal: " _ tProposals.%ToJSON())
    If tProposals.%Size() '= 1 {
        Do ..RemoveProbes()
        Quit
    }
    Set tStatus = ..Confirm(tProposals.%Get(0).%Get("proposalId"), ..#NAMESPACE, tUser, .tConfirmText)
    Do $$$AssertEquals(tStatus, 200, "the class confirm, scoped to USER, answers 200: " _ $Extract($Get(tConfirmText), 1, 300))
    Set tBody = ..Parsed($Get(tConfirmText))
    Do $$$AssertTrue($IsObject(tBody) && $IsObject(tBody.%Get("output")) && (tBody.output.%GetTypeOf("errors") = "boolean") && 'tBody.output.errors, "the confirm answers the compile's output, with no errors")
    Do $$$AssertTrue($IsObject(tBody) && $IsObject(tBody.%Get("output")) && (tBody.output.%GetTypeOf("lines") = "array") && (tBody.output.lines.%ToJSON() [ ("Compiling class " _ ..#PROBECLASS)), "and the compile's lines, which the model must never see")
    Do $$$AssertEquals($ZStrip(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#NAMESPACE, ..#PROBECLASS _ ".cls"), "<>WC"), $ZStrip(tClassText, "<>WC"), "the class holds the new text")
    Do $$$AssertTrue($ClassMethod("OcuPilot.Test.ExplorerCreateProbe", "Compiled", ..#NAMESPACE, ..#PROBECLASS), "and is compiled")

    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn?ns=" _ ..#NAMESPACE, tUser, ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "StartBody", "now the routine and the answer", tConvId), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "a second turn starts: " _ $Extract($Get(tText), 1, 200))
    If tStatus = 202 {
        Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", ##class(%DynamicObject).%FromJSON(tText).turnId, tUser, ..PreparedTurnPassword, 90, .tView)
        Do $$$AssertEquals(tState, "completed", "the second turn completes")
        Set tProposals = $Select($IsObject($Get(tView)) && $IsObject(tView.%Get("proposals")): tView.proposals, 1: [])
        Do $$$AssertEquals(tProposals.%Size(), 2, "the second turn holds the routine create and the save: " _ tProposals.%ToJSON())
        For tI = 0:1:tProposals.%Size() - 1 {
            Set tStatus = ..Confirm(tProposals.%Get(tI).%Get("proposalId"), ..#OTHERNAMESPACE, tUser, .tConfirmText)
            Do $$$AssertEquals(tStatus, 200, "proposal " _ tI _ ", scoped to " _ ..#OTHERNAMESPACE _ " where the principal may not write, answers 200: " _ $Extract($Get(tConfirmText), 1, 300))
        }
        Do $$$AssertTrue($ClassMethod("OcuPilot.Test.ExplorerCreateProbe", "Exists", ..#NAMESPACE, ..#PROBEROUTINE), "the routine is written in USER")
        Do $$$AssertEquals($Piece(##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#NAMESPACE, ..#PROBECLASS _ ".cls"), $Char(10), 6), "    Quit 2", "and the class holds the saved answer")
        Do $$$AssertTrue(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 3, "messages") [ "CREATETURNREPLYONE", "the second turn's first request carries the first turn's history, where a compile line would have leaked")
        For tCall = 1:1:4 {
            Set tRecorded = ##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, tCall, "messages")
            Do $$$AssertTrue(tRecorded '= "", "call " _ tCall _ " is recorded")
            Do $$$AssertTrue((tRecorded '[ "Compiling") && (tRecorded '[ "Compilation"), "provider request " _ tCall _ " carries no compile line")
        }
    }
    Do ..RemoveProbes()
}

}
