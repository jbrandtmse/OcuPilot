/// <p>Pins the agent's class save over a real turn (Story 20.21, AC7, AC8, AD-53, DW-2228): a principal holding
/// the class viewer's pairs and the routines database's WRITE asks, through a scripted model, for the class's
/// source and then for two replacements in one reply. One replacement quotes a key-shaped value the read showed
/// as <code>[redacted]</code>, so the mint refuses it; the other is a line copied from the read. The proposal the
/// second one mints is confirmed over HTTP as the same principal: the class holds the new text, the confirm answers
/// the compile's output, and no provider request carries a compile line.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP on a throwaway, a
/// <code>USER</code> namespace, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PROVIDERVARIABLE</parameter> reading <code>1</code>: it creates a turn principal, the probe class and
/// the <code>turnprobe</code> definition, and runs one turn job. Everything is removed in
/// <method>OnAfterAllTests</method> and after each test.</p>
Class OcuPilot.Test.ExplorerSaveTurn Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "explorersaveturn-probe";

Parameter NAMESPACE = "USER";

/// <p>The probe class, in <parameter>NAMESPACE</parameter>.</p>
Parameter PROBECLASS = "OcuProbe202.Keyed";

/// <p>A credential-shaped key: <code>sk-</code> and twenty-four letters and digits.</p>
Parameter SECRET = "sk-Probe202Secret0123456789";

/// <p>The turn principal's grants beyond the fixture's own: the development permission the class tools need.</p>
Parameter DEVELOPMENTGRANT = "%Development:U";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ExplorerSaveTurn creates an IRIS user and runs a turn job against the turnprobe row, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must both read 1, so nothing was created.")
    }
    Set ..PreparedTurnPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#NAMESPACE, .tCode, .tGlobals, .tMapped, .tResolved)
    If 'tResolved || (tCode = "") Quit $$$ERROR($$$GeneralError, "the " _ ..#NAMESPACE _ " namespace's code database could not be resolved")
    ; The confirm resolves its write pairs for the request's namespace (the default), not the proposal's, so the
    ; principal also holds WRITE on that namespace's routines database.
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources("HSCUSTOM", .tDefaultCode, .tDefaultGlobals, .tDefaultMapped, .tDefaultResolved)
    Set tGrants = ..#DEVELOPMENTGRANT _ "," _ tCode _ ":RW"
    If (tDefaultCode '= "") && (tDefaultCode '= tCode) Set tGrants = tGrants _ "," _ tDefaultCode _ ":RW"
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
    Set tSC = $$$ADDSC(tSC, ..RemoveKeyed())
    If tLeft '= "" Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.ExplorerSaveTurn teardown left:" _ tLeft))
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

/// <p>Save the probe class <parameter>PROBECLASS</parameter>, its doc comment carrying <parameter>SECRET</parameter>,
/// in <parameter>NAMESPACE</parameter>; its one method answers 1.</p>
ClassMethod MakeKeyed() As %Status
{
    Set tText = "Class " _ ..#PROBECLASS _ " Extends %RegisteredObject" _ $Char(10) _ "{" _ $Char(10)
    Set tText = tText _ "/// Calls the provider with " _ ..#SECRET _ " as its key." _ $Char(10)
    Set tText = tText _ "ClassMethod Probe() As %Integer" _ $Char(10) _ "{" _ $Char(10) _ "    Quit 1" _ $Char(10) _ "}" _ $Char(10) _ "}" _ $Char(10)
    Quit ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, ..#PROBECLASS _ ".cls", tText, $Char(10))
}

/// <p>Remove the probe package from <parameter>NAMESPACE</parameter>, the namespace switched by explicit save and
/// restore.</p>
ClassMethod RemoveKeyed() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.DeletePackage("OcuProbe202", "-d")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The method line of the probe class as it now stands, whatever line it sits on.</p>
ClassMethod Answer() As %String
{
    Set tText = ##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#NAMESPACE, ..#PROBECLASS _ ".cls")
    Quit "    Quit " _ $Piece($Piece(tText, "    Quit ", 2), $Char(10), 1)
}

/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.ExplorerSaveMint</class> stores <code>Compile: false</code>
/// -- the confirm's output leg goes red.</p>
Method TestTheAgentsSaveIsConfirmedOverHTTPAndCompiles()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Do $$$AssertStatusOK(..MakeKeyed(), "the probe class is saved")
    Set tRead = {"id": "toolu_read", "input": {"name": "OcuProbe202.Keyed.cls"}}
    Do tRead.%Set("name", "explorer_class_source", "string")
    Set tBad = {"id": "toolu_bad", "input": {"Names": "OcuProbe202.Keyed.cls", "Edits": [{"Old": "/// Calls the provider with [redacted] as its key.", "New": "/// Calls the provider."}], "rationale": "remove the key comment", "expectedImpact": "the comment goes"}}
    Do tBad.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.classes.save"), "string")
    Set tGood = {"id": "toolu_good", "input": {"Names": "OcuProbe202.Keyed.cls", "Edits": [{"Old": "    Quit 1", "New": "    Quit 2"}], "rationale": "change the answer", "expectedImpact": "the method answers 2"}}
    Do tGood.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.classes.save"), "string")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(tRead)]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(tBad), (tGood)]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedTurnPassword, .tStatus, .tText)
    Do $$$AssertNotEquals(tConvId, "", "the principal starts a conversation: " _ tStatus)
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn?ns=" _ ..#NAMESPACE, tUser, ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "StartBody", "change the probe class's answer to 2", tConvId), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the turn starts: " _ $Extract(tText, 1, 200))
    If tStatus '= 202 {
        Do ..RemoveKeyed()
        Quit
    }
    Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", ##class(%DynamicObject).%FromJSON(tText).turnId, tUser, ..PreparedTurnPassword, 90, .tView)
    Do $$$AssertEquals(tState, "completed", "the turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 3, "after three provider calls")

    Set tProposals = $Select($IsObject($Get(tView)) && $IsObject(tView.%Get("proposals")): tView.proposals, 1: [])
    Do $$$AssertEquals(tProposals.%Size(), 1, "the turn holds one proposal, the valid edit's: " _ tProposals.%ToJSON())
    If tProposals.%Size() '= 1 {
        Do ..RemoveKeyed()
        Quit
    }
    Set tKey = tProposals.%Get(0).%Get("proposalId")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/proposal/" _ tKey _ "/confirm", tUser, ..PreparedTurnPassword, .tStatus, .tText, .tHeaders, "", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the confirm answers 200: " _ $Extract($Get(tText), 1, 300))
    Set tBody = ""
    Try {
        Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tText)
    } Catch {
        Set tBody = ""
    }
    Do $$$AssertTrue($IsObject(tBody) && $IsObject(tBody.%Get("output")), "the confirm answers the compile's output")
    Do $$$AssertEquals(..Answer(), "    Quit 2", "the class holds the new text: " _ ##class(OcuPilot.Test.ExplorerSaveProbe).Source(..#NAMESPACE, ..#PROBECLASS _ ".cls"))
    Set tRecorded = ""
    For tCall = 1:1:3 {
        Set tRecorded = tRecorded _ ##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, tCall, "messages")
    }
    Do $$$AssertTrue((tRecorded [ "kind") && (tRecorded [ "lines"), "the provider requests carry the change's hunk")
    Do $$$AssertTrue(tRecorded [ "matched exactly", "the refused replacement tells the model its Old is matched exactly (DW-2228)")
    Do $$$AssertTrue((tRecorded '[ "Compiling") && (tRecorded '[ "Compilation"), "and no provider request carries a compile line")
    Do ..RemoveKeyed()
}

}
