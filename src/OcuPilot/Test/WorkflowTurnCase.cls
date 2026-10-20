/// <p>What <class>OcuPilot.Test.WorkflowTurn</class> and <class>OcuPilot.Test.WorkflowGates</class> share
/// (Story 20.12): the armed harness for a scripted guided-workflow turn over HTTP -- a turn principal holding
/// the class tools' pairs, the <code>turnprobe</code> definition, a probe class in <parameter>NAMESPACE</parameter>,
/// the governance policy and the switches put back after each test -- with the helpers that start a turn, wait
/// for it, read what the model was sent and confirm a proposal as the principal. It declares no test of its
/// own, and no arming variable: a subclass names both in <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PROVIDERVARIABLE</parameter>, which is what <code>scripts/ci-throwaway.sh</code>'s rosters hold equal
/// to the classes that arm.</p>
/// <p><b>What a subclass needs from the environment:</b> OcuPilot installed and serving over HTTP on a throwaway,
/// a <code>USER</code> namespace, and both variables reading <code>1</code>. It creates the definition once, the
/// turn principal afresh before each test so that no test meets another's leftover account, and the probe class
/// inside the tests that need it; it removes the probe class, the policy and the switches after each test, and the
/// principal and the definition in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.WorkflowTurnCase Extends %UnitTest.TestCase [ Abstract ]
{

/// <p>The variable that arms the principal's creation; a subclass names it.</p>
Parameter ARMINGVARIABLE;

/// <p>The variable that arms the scripted provider; a subclass names it.</p>
Parameter PROVIDERVARIABLE;

/// <p>The script tag of the <code>turnprobe</code> definition; a subclass names its own.</p>
Parameter TAG;

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter NAMESPACE = "USER";

/// <p>The probe package, removed whole.</p>
Parameter PROBEPACKAGE = "OcuProbe2012";

/// <p>The probe class, in <parameter>NAMESPACE</parameter>; its one method answers 1 until a save changes it.</p>
Parameter PROBECLASS = "OcuProbe2012.Flow";

Property PreparedTurnPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

/// <p>The turn principal's grants beyond the fixture's own (<method>Grants</method>), resolved once.</p>
Property PreparedGrants As %String;

/// <p>The policy found before the test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedTurnPassword = ""
    Set ..PreparedDefinitionId = ""
    Set ..PreparedPrior = ""
    Set ..PreparedGrants = ""
    Quit $$$OK
}

/// <p>Whether both arming variables read 1.</p>
Method Armed() As %Boolean
{
    Quit ($System.Util.GetEnviron(..#ARMINGVARIABLE) = 1) && ($System.Util.GetEnviron(..#PROVIDERVARIABLE) = 1)
}

/// <p>The grants the turn principal holds beyond the fixture's own, given the resource that guards
/// <parameter>NAMESPACE</parameter>'s code database: the development permission the class tools need and
/// that database's read and write. A subclass that needs more adds to it.</p>
Method Grants(pCodeResource As %String) As %String
{
    Quit "%Development:U," _ pCodeResource _ ":RW"
}

Method OnBeforeAllTests() As %Status
{
    If '..Armed() {
        Quit $$$ERROR($$$GeneralError, $ClassName() _ " creates an IRIS user and runs a turn job against the turnprobe row, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must both read 1, so nothing was run.")
    }
    Set ..PreparedTurnPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#NAMESPACE, .tCode, .tGlobals, .tMapped, .tResolved)
    If 'tResolved || (tCode = "") Quit $$$ERROR($$$GeneralError, "the " _ ..#NAMESPACE _ " namespace's code database could not be resolved")
    Set ..PreparedGrants = ..Grants(tCode)
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISOK(tSC) Set ..PreparedDefinitionId = tId
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    If '..Armed() Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    Set tSC = $$$ADDSC(tSC, ..RemoveProbe())
    If tLeft '= "" Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, $ClassName() _ " teardown left:" _ tLeft))
    Quit tSC
}

/// <p>Create the turn principal with <method>Grants</method>, replacing any account of that name.</p>
Method EnsureTurnPrincipal() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "EnsurePrincipal", $Parameter(..#FIXTURE, "USERA"), ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "Resources", 0), ..PreparedGrants)
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tSC = ..EnsureTurnPrincipal()
    If $$$ISERR(tSC) Quit tSC
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds)
    If $$$ISERR(tSC) Quit tSC
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Quit $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).Reset(.tHolds), "the switches are put back")
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Do $$$AssertStatusOK(..RemoveProbe(), "the probe package is removed")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
    Quit $$$OK
}

/// <p>Save the probe class <parameter>PROBECLASS</parameter> in <parameter>NAMESPACE</parameter>; its one method
/// answers 1.</p>
ClassMethod MakeProbe() As %Status
{
    Quit ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, ..#PROBECLASS _ ".cls", ##class(OcuPilot.Test.ExplorerSaveProbe).ClassText(..#PROBECLASS, 1), $Char(10))
}

/// <p>Remove the probe package from <parameter>NAMESPACE</parameter>, the namespace switched by explicit save and
/// restore.</p>
ClassMethod RemoveProbe() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.DeletePackage(..#PROBEPACKAGE, "-d")
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

/// <p>A scripted <code>tool_use</code> block (<code>{id, name, input}</code>) calling the class save with id
/// <var>pId</var>, replacing the probe method's line <var>pOld</var> by <var>pNew</var>.</p>
ClassMethod SaveCall(pId As %String, pOld As %String, pNew As %String) As %DynamicObject
{
    Set tCall = {"id": (pId), "input": {"Names": (..#PROBECLASS _ ".cls"), "Edits": [{"Old": (pOld), "New": (pNew)}], "rationale": "change the answer", "expectedImpact": "the method answers differently"}}
    Do tCall.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.classes.save"), "string")
    Quit tCall
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

/// <p>The tool results of the provider request <var>pCall</var>, by tool-use id, each unwrapped from its data
/// frame: <var>pResults</var>(id) is the body, and <var>pWrapped</var>(id) whether it was framed.</p>
ClassMethod ResultsOf(pCall As %Integer, Output pResults, Output pWrapped)
{
    Do ..ResultsFor(..#TAG, pCall, .pResults, .pWrapped)
}

/// <p><method>ResultsOf</method> for the script tag <var>pTag</var>, which is how a browser spec reads what its
/// own scripted turns sent.</p>
ClassMethod ResultsFor(pTag As %String, pCall As %Integer, Output pResults, Output pWrapped)
{
    Kill pResults, pWrapped
    Set tMessages = ..Parsed(##class(OcuPilot.Test.TurnProvider).Recorded(pTag, pCall, "messages"))
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

/// <p>The <code>previous</code> array of the workflow result in provider request <var>pCall</var> of
/// <parameter>TAG</parameter>'s script, as JSON text, or <code>none</code> when the request holds no workflow
/// result.</p>
Method PreviousAt(pCall As %Integer) As %String
{
    Do ..ResultsOf(pCall, .tResults, .tWrapped)
    Set tResult = ..Parsed($Get(tResults("ocupilot_workflow")))
    If '$IsObject(tResult) || (tResult.%GetTypeOf("previous") '= "array") Quit "none"
    Quit tResult.previous.%ToJSON()
}

/// <p>A one-line summary of the workflow result in provider request <var>pCall</var> of script tag <var>pTag</var>,
/// for a browser spec: <code>&lt;workflow&gt;|&lt;1 when its steps name the class save&gt;|&lt;proposals reported by
/// previous&gt;|&lt;previous' first tool&gt;|&lt;its state&gt;</code>, or <code>none</code> when the request holds
/// no workflow result.</p>
ClassMethod WorkflowSummary(pTag As %String, pCall As %Integer) As %String
{
    Do ..ResultsFor(pTag, pCall, .tResults, .tWrapped)
    Set tResult = ..Parsed($Get(tResults("ocupilot_workflow")))
    If '$IsObject(tResult) Quit "none"
    Set tFirst = $Select($IsObject(tResult.%Get("previous")) && (tResult.previous.%Size() > 0): tResult.previous.%Get(0), 1: "")
    Quit tResult.%Get("workflow") _ "|" _ (tResult.%ToJSON() [ "explorer.classes.save") _ "|" _ $Select($IsObject(tResult.%Get("previous")): tResult.previous.%Size(), 1: 0) _ "|" _ $Select($IsObject(tFirst): tFirst.%Get("tool") _ "|" _ tFirst.%Get("state"), 1: "|")
}

/// <p>Start a turn of conversation <var>pConvId</var> as the principal, saying <var>pMessage</var> and naming
/// workflow <var>pWorkflow</var> when it is not empty, scoped to <parameter>NAMESPACE</parameter> as the client
/// scopes it. <var>pTurnId</var> is the new turn's id when the start answered 202; the HTTP status is the answer.</p>
Method StartTurn(pConvId As %String, pMessage As %String, pWorkflow As %String, Output pTurnId As %String, Output pText As %String) As %Integer
{
    Set pTurnId = ""
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn?ns=" _ ..#NAMESPACE, $Parameter(..#FIXTURE, "USERA"), ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "StartBody", pMessage, pConvId, "", pWorkflow), .tStatus, .pText, .tHeaders)
    If tStatus = 202 Set pTurnId = ##class(%DynamicObject).%FromJSON(pText).turnId
    Quit tStatus
}

/// <p>Start a turn (<method>StartTurn</method>) and wait up to ninety seconds for it to end; answer its state, with
/// the last progress view in <var>pView</var>.</p>
Method RunTurn(pConvId As %String, pMessage As %String, pWorkflow As %String, Output pView) As %String
{
    Set tStatus = ..StartTurn(pConvId, pMessage, pWorkflow, .tTurnId, .tText)
    Do $$$AssertEquals(tStatus, 202, "the turn starts: " _ $Extract(tText, 1, 200))
    If tStatus '= 202 Quit ""
    Quit $ClassMethod(..#FIXTURE, "AwaitEnd", tTurnId, $Parameter(..#FIXTURE, "USERA"), ..PreparedTurnPassword, 90, .pView)
}

/// <p>A new conversation of the principal's.</p>
Method NewConversation() As %String
{
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", $Parameter(..#FIXTURE, "USERA"), ..PreparedTurnPassword, .tStatus, .tText)
    Do $$$AssertNotEquals(tConvId, "", "the principal starts a conversation: " _ tStatus)
    Quit tConvId
}

/// <p>Confirm proposal <var>pKey</var> over HTTP as the principal, scoped to <parameter>NAMESPACE</parameter>;
/// the status is <var>pStatus</var> and the body, parsed, <var>pBody</var> (<code>""</code> when none parsed).</p>
Method Confirm(pKey As %String, Output pStatus As %Integer, Output pBody)
{
    Do ..Decide(pKey, "confirm", .pStatus, .pBody)
}

/// <p>Cancel proposal <var>pKey</var> over HTTP as the principal, answering as <method>Confirm</method> does.</p>
Method Cancel(pKey As %String, Output pStatus As %Integer, Output pBody)
{
    Do ..Decide(pKey, "cancel", .pStatus, .pBody)
}

/// <p>Post <var>pVerb</var> (<code>confirm</code> or <code>cancel</code>) for proposal <var>pKey</var> as the principal,
/// scoped to <parameter>NAMESPACE</parameter>.</p>
Method Decide(pKey As %String, pVerb As %String, Output pStatus As %Integer, Output pBody) [ Private ]
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", "/api/ocupilot/proposal/" _ pKey _ "/" _ pVerb _ "?ns=" _ ..#NAMESPACE, $Parameter(..#FIXTURE, "USERA"), ..PreparedTurnPassword, .pStatus, .tText, .tHeaders, "", "application/json")
    Set pBody = ..Parsed($Get(tText))
}

/// <p>The id of the first proposal of progress view <var>pView</var>, or <code>""</code>.</p>
ClassMethod FirstProposal(pView) As %String
{
    If '$IsObject(pView) || '$IsObject(pView.%Get("proposals")) || (pView.proposals.%Size() = 0) Quit ""
    Quit pView.proposals.%Get(0).%Get("proposalId")
}

}
