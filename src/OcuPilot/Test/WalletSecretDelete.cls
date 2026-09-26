/// <p>Pins Story 9.5's wallet secret delete (AD-6, AD-51, AD-52, AD-53): what
/// <class>OcuPilot.Screen.Tool.WalletSecretDelete</class> declares, the agent's marked and bodyless
/// confirm, the Secrets list's Delete reaching the same write through the screen-action route, and a
/// secret the instance does not hold refused on both.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and an account
/// holding <code>%Admin_Wallet</code>. Every secret it deletes is one it stored first in the probe
/// collection of <class>OcuPilot.Test.WalletProbe</class>, and whatever survives is removed by exact
/// name.</p>
Class OcuPilot.Test.WalletSecretDelete Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.WalletSecretDelete";

Parameter LIST = "OcuPilot.Screen.Descriptor.WalletSecretList";

Parameter CONFIRM = "OcuPilot.Test.WalletConfirm";

Parameter RECORD = "OcuPilot.Test.WalletRecordPort";

Parameter PROBE = "OcuPilot.Test.WalletProbe";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "EnsureCollection", .tCreated)
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove", .tRemaining)
    If $$$ISOK(tSC) && (tRemaining > 0) Set tSC = $$$ERROR($$$GeneralError, tRemaining _ " probe secret(s) survived OcuPilot.Test.WalletSecretDelete")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>AD-51, AD-52: an action-style write over the wallet port's read and the vendor's bodyless
/// <code>DELETE</code>, admitting no field and no secret, fingerprinted over the secret's type, and
/// carrying the list's Delete.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Screen.Tool.WalletSecretDelete.SCREENACTIONS</parameter>
/// -- the screen-action assertion here and the list's Delete in
/// <method>TestTheListsDeleteRemovesTheSecret</method> go red.</p>
Method TestTheDeleteIsAnActionWriteOverTheSecret()
{
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ReadType") _ " " _ $ClassMethod(..#TOOL, "WriteType") _ " " _ $ClassMethod(..#TOOL, "SendsBody"), "GET DELETE 0", "a bodyless delete over the wallet read")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "PortClass"), "OcuPilot.Port.WalletPort", "through the wallet port")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "SettableFields") _ $ClassMethod(..#TOOL, "SecretArguments"), "", "admitting no field and no secret")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "FingerprintSubject")), "Type", "fingerprinted over the secret's type")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Destructive") _ " " _ $ClassMethod(..#TOOL, "ChangeAction"), "1 deleted", "destructive, publishing deleted")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "ScreenActionIds")), "delete", "carrying the list's Delete")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(..#TOOL), "", "and the registry accepts its subject")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).IsBodyless("Wallet.Secret", "DELETE"), 1, "the port admits the delete bodyless")
}

/// <p>AD-6, AD-51: the agent's delete is minted destructive, its confirm sends no body and removes
/// the secret, and a secret the instance does not hold is refused at the mint.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Screen.Tool.WalletSecretDelete.DESTRUCTIVE</parameter>
/// to 0 -- the stored-destructive assertion goes red.</p>
Method TestAConfirmedDeleteRemovesTheSecretAndSendsNoBody()
{
    Set tName = ..Name("DelAgent")
    Do $ClassMethod(..#PROBE, "RemoveSecret", tName)
    Set tSC = $ClassMethod(..#PROBE, "AddKeyValue", tName, {"Secret": "OcuPilotProbe95Value", "Usage": 5, "RequireTLS": false, "AllowedHosts": ["h"]})
    Do $$$AssertStatusOK(tSC, "the probe secret is stored")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint(tName, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals(+$Get(tValues("destructive")), 1, "stored destructive")
    Do $$$AssertEquals(tProposal.%Get("changed").%Get(0).%Get("removed"), 1, "listing what would go")
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirmed: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "LastName"), "DELETE " _ tName, "at the vendor's DELETE, naming the secret")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastWriteBody"), "", "with no body")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and the secret is gone")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "deleted", "answering the deleted action")

    Set tSC = ..Mint(tName, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "a secret the instance does not hold is refused at the mint")
}

/// <p>AD-53: the Secrets list's Delete is the same write over the screen-action route -- 200 with the
/// deleted action and the secret gone -- and a second Delete of the same name is 404.</p>
Method TestTheListsDeleteRemovesTheSecret()
{
    Set tName = ..Name("DelScreen")
    Do $ClassMethod(..#PROBE, "RemoveSecret", tName)
    Set tSC = $ClassMethod(..#PROBE, "AddKeyValue", tName, {"Secret": "OcuPilotProbe95Value", "Usage": 5, "RequireTLS": false, "AllowedHosts": ["h"]})
    Do $$$AssertStatusOK(tSC, "the probe secret is stored")
    If $$$ISERR(tSC) Quit
    Set tSC = ..DeleteOnScreen(tName, .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the list's Delete is answered: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($Select($IsObject($Get(tAnswer)): tAnswer.%Get("action"), 1: ""), "deleted", "announcing a removal")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and the secret is gone")
    Set tSC = ..DeleteOnScreen(tName, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 404, "a second Delete finds nothing to delete")
}

/// <p>The probe secret <var>pPart</var>'s full name.</p>
ClassMethod Name(pPart As %String) As %String
{
    Quit $Parameter(..#PROBE, "COLLECTION") _ "." _ pPart
}

/// <p>Mint one delete of <var>pName</var> through the shipped mint, whose read goes through the
/// wallet port.</p>
Method Mint(pName As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pProposal = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tArgs = {}
    Do tArgs.%Set($ClassMethod(..#TOOL, "IdArgument"), pName, "string")
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurnKey, tArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pName, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p>One <code>POST</code> of the Secrets list's <code>delete</code> of <var>pName</var> on the
/// screen-action route, as the suite's HTTP account.</p>
ClassMethod DeleteOnScreen(pName As %String, Output pStatus As %Integer, Output pAnswer) As %Status
{
    Set tRequest = {}
    Do tRequest.%Set("action", "delete", "string")
    Do tRequest.%Set("id", pName, "string")
    Quit ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/" _ $ClassMethod(..#LIST, "ToolIdentifier") _ "/action", .pStatus, .pAnswer, tRequest.%ToJSON(), "application/json")
}

}
