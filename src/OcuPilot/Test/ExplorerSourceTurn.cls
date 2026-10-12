/// <p>Pins the agent's class source read over a real turn (Story 20.19, AC5, AD-60): a principal holding
/// the class viewer's pairs asks, through a scripted model, for <code>explorer_class_source</code> on a
/// probe class in <code>USER</code> whose doc comment carries a credential-shaped key; the next provider
/// request carries the class's lines framed as data in a <code>tool_result</code>, with the key reading
/// <code>[redacted]</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP, a
/// <code>USER</code> namespace, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PROVIDERVARIABLE</parameter> reading <code>1</code>: it creates a turn principal, the
/// probe class and the <code>turnprobe</code> definition, and runs one turn job. Everything is removed
/// in <method>OnAfterAllTests</method> and after each test.</p>
Class OcuPilot.Test.ExplorerSourceTurn Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "explorersourceturn-probe";

Parameter NAMESPACE = "USER";

/// <p>The probe class, in <parameter>NAMESPACE</parameter>, and the package it sits in.</p>
Parameter PROBECLASS = "OcuProbe201.Keyed";

/// <p>A credential-shaped key: <code>sk-</code> and twenty-four letters and digits.</p>
Parameter SECRET = "sk-Probe201Secret0123456789";

/// <p>What the turn principal's second role grants beyond the fixture's own resources, beside READ
/// on <parameter>NAMESPACE</parameter>'s code database.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ExplorerSourceTurn creates an IRIS user and runs a turn job against the turnprobe row, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must both read 1, so nothing was created.")
    }
    Set ..PreparedTurnPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(..#NAMESPACE, .tCode, .tGlobals, .tMapped, .tResolved)
    If 'tResolved || (tCode = "") Quit $$$ERROR($$$GeneralError, "the " _ ..#NAMESPACE _ " namespace's code database could not be resolved")
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", tUser, ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "Resources", 0), ..#DEVELOPMENTGRANT _ "," _ tCode _ ":R")
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
    If tLeft '= "" Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.ExplorerSourceTurn teardown left:" _ tLeft))
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

/// <p>Save the probe class <parameter>PROBECLASS</parameter>, its doc comment carrying
/// <parameter>SECRET</parameter>, in <parameter>NAMESPACE</parameter>.</p>
ClassMethod MakeKeyed() As %Status
{
    Set tText = "Class " _ ..#PROBECLASS _ " Extends %RegisteredObject" _ $Char(13, 10) _ "{" _ $Char(13, 10)
    Set tText = tText _ "/// Calls the provider with " _ ..#SECRET _ " as its key." _ $Char(13, 10)
    Set tText = tText _ "ClassMethod Probe() As %Integer" _ $Char(13, 10) _ "{" _ $Char(13, 10) _ "    Quit 1" _ $Char(13, 10) _ "}" _ $Char(13, 10) _ "}" _ $Char(13, 10)
    Quit ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, ..#PROBECLASS _ ".cls", tText)
}

/// <p>Remove the probe package from <parameter>NAMESPACE</parameter>, the namespace switched by
/// explicit save and restore.</p>
ClassMethod RemoveKeyed() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.DeletePackage("OcuProbe201", "-d")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Mutation (Rule 19): have <class>OcuPilot.Kernel.Agent.Loop</class> skip
/// <method>OcuPilot.Kernel.Agent.Sanitize.Results</method> -- the wrapper and the masked key go red.</p>
Method TestTheClassSourceReachesTheModelFramedAndMasked()
{
    Do $$$AssertStatusOK(..MakeKeyed(), "the probe class is saved")
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tCall = {"id": "toolu_src", "input": {"name": "OcuProbe201.Keyed.cls"}}
    Do tCall.%Set("name", "explorer_class_source", "string")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(tCall)]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tConvId = $ClassMethod(..#FIXTURE, "StartConversation", tUser, ..PreparedTurnPassword, .tStatus, .tText)
    Do $$$AssertNotEquals(tConvId, "", "the principal starts a conversation: " _ tStatus)
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn?ns=" _ ..#NAMESPACE, tUser, ..PreparedTurnPassword, $ClassMethod(..#FIXTURE, "StartBody", "read the probe class's source", tConvId), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "the turn starts: " _ $Extract(tText, 1, 200))
    If tStatus '= 202 {
        Do $$$AssertStatusOK(..RemoveKeyed(), "the probe package is removed")
        Quit
    }
    Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", ##class(%DynamicObject).%FromJSON(tText).turnId, tUser, ..PreparedTurnPassword, 60, .tView)
    Do $$$AssertEquals(tState, "completed", "the turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 2, "after two provider calls")
    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    Kill tByUse
    Set tIterator = tMessages.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMessage) {
        If (tMessage.%Get("role") '= "user") || (tMessage.%GetTypeOf("content") '= "array") Continue
        Set tBlocks = tMessage.%Get("content").%GetIterator()
        While tBlocks.%GetNext(.tBlockIndex, .tBlock) {
            If tBlock.%Get("type") = "tool_result" Set tByUse(tBlock.%Get("tool_use_id")) = tBlock.%Get("content")
        }
    }
    Set tSource = $Get(tByUse("toolu_src"))
    Set tBody = $ClassMethod(..#FIXTURE, "Unwrapped", tSource, .tWrapped)
    Do $$$AssertTrue(tWrapped, "the class source reaches the model framed as data (AD-60)")
    Set tParsed = ""
    Try { Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(tBody) } Catch {}
    Do $$$AssertTrue($IsObject(tParsed), "and parses")
    If $IsObject(tParsed) {
        Do $$$AssertTrue(tParsed.%Get("text") [ ("Class " _ ..#PROBECLASS), "the class's lines reach the model")
        Do $$$AssertTrue(tParsed.%Get("text") [ "[redacted]", "the key reads [redacted]")
        Do $$$AssertTrue('(tParsed.%Get("text") [ ..#SECRET), "and the key itself does not reach the model")
        Do $$$AssertEquals(tParsed.%Get("truncated"), 0, "the class is read whole")
    }
    Do $$$AssertStatusOK(..RemoveKeyed(), "the probe package is removed")
}

}
