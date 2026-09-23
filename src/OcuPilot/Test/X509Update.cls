/// <p>Pins Story 8.5's X.509 edit (AD-3, AD-4, AD-21, AD-39, AD-55): what
/// <class>OcuPilot.Screen.Tool.X509Update</class> advertises, the merge both callers send -- the
/// vendor's whole <code>PUT</code> contract from a fresh read with only the lists the caller changed
/// -- the refusal of every other key, the absent alias and the marked confirm.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state
/// readable. Every read and write goes to <class>OcuPilot.Test.ProposalFixture</class>, so nothing
/// here changes a credential; the prohibited set's target read is live and finds the probe alias
/// absent. No arming variable is required.</p>
Class OcuPilot.Test.X509Update Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.X509Update";

Parameter LIST = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The shipped screen route with only its port replaced.</p>
Parameter SCREEN = "OcuPilot.Test.X509Fixture";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter PROBE = "OcuPilotProbeX509Update";

/// <p>What the fixture answers for the credential's fresh read: a CA file and a peer the edit does
/// not touch.</p>
Parameter FRESH = "{""OwnerList"":[""before""],""CAFile"":""/x.cer"",""PeerNames"":[""p""]}";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>AD-3, AD-4: a merge write over the vendor's single-object read and its <code>PUT</code>,
/// advertising the two lists and nothing else, over the prohibited set's reviewed change list.</p>
Method TestTheEditIsAMergeWriteOverTheTwoLists()
{
    Set tProperties = $ClassMethod(..#TOOL, "InputSchema").%Get("properties")
    Do $$$AssertEquals(tProperties.%Get("OwnerList").%Get("type") _ " " _ tProperties.%Get("PeerNames").%Get("type"), "array array", "the schema offers the two lists")
    For tField = "CAFile", "Certificate", "PrivateKey", "PrivateKeyPassword", "CertificateFile", "PrivateKeyFile" {
        Do $$$AssertEquals(tProperties.%GetTypeOf(tField), "unassigned", "and never " _ tField)
    }
    Do $$$AssertEquals(..Sorted($ClassMethod(..#TOOL, "SettableFields")), ..Sorted($ClassMethod(..#SET, "PermittedChangeFields", "x509-credential")), "the settable set is the prohibited set's reviewed change list")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ReadType") _ " " _ $ClassMethod(..#TOOL, "WriteType") _ " " _ $ClassMethod(..#TOOL, "SendsBody") _ " " _ $ClassMethod(..#TOOL, "ChangeAction"), "GET PUT 1 updated", "a merge write publishing updated")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "FingerprintSubject"), "", "fingerprinted over every field it sends")
}

/// <p>AC4, AD-4 on both callers: an edit of the authorized users alone sends the fresh read with that
/// list changed, so the peers and the CA file keep the instance's values and the body is exactly
/// <code>{OwnerList, CAFile, PeerNames}</code>.</p>
/// <p>Mutation: make <method>OcuPilot.Area.Security.X509Save.Update</method> send the caller's
/// fields without <method>OcuPilot.Kernel.Proposal.Mint.Merge</method> -> the screen body loses
/// <code>CAFile</code> and <code>PeerNames</code> and this goes red.</p>
Method TestAnEditKeepsTheFieldsTheCallerDidNotChangeOnBothCallers()
{
    Set tExpected = "{""OwnerList"":[""a""],""CAFile"":""/x.cer"",""PeerNames"":[""p""]}"
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tSC = $ClassMethod(..#SCREEN, "Update", ..#PROBE, {"OwnerList": ["a"]}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen's edit is accepted")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "PUT", "at the vendor's PUT")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("alias"), ..#PROBE, "naming the alias in the query parameter")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastWriteBody(), tExpected, "the screen sends the fresh read with the one list changed")

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tSC = ..Mint(..#PROBE, {"OwnerList": ["a"]}, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the agent mints the same edit")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 1, "with one changed row")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 2, "and the two fields it keeps")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and its confirm applies it: " _ $Get(tCode))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastWriteBody(), tExpected, "the confirm sends the identical body")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "updated", "answering the updated action")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row")
    Do $$$AssertEquals(..Sorted($ListFromString($Get(tRow("Fields")))), "CAFile,OwnerList,PeerNames", "naming the three fields the body sent and no secret")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed")
}

/// <p>AC4, AD-21: an edit carrying any key but the two lists -- the CA file, a secret, the alias --
/// is refused before anything is sent, on the screen at 400 and at the agent's mint as an argument
/// its schema does not carry or a secret it never accepts.</p>
/// <p>Mutation: add <code>CAFile</code> to
/// <parameter>OcuPilot.Area.Security.X509Save.EDITFIELDS</parameter> -> its screen case is sent and
/// this goes red.</p>
Method TestAnyOtherKeyIsRefusedOnBothCallers()
{
    For tField = "CAFile", "Certificate", "PrivateKey", "PrivateKeyPassword", "Alias", "CertificateFile" {
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
        Set tArgs = {"OwnerList": ["a"]}
        Do tArgs.%Set(tField, "/other.cer")
        Set tSC = $ClassMethod(..#SCREEN, "Update", ..#PROBE, tArgs, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, tField _ ": the screen refuses it at 400")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, tField _ ": and nothing is sent")
        If tField = "Alias" Continue
        Do tArgs.%Set("Alias", ..#PROBE)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments($ClassMethod(..#TOOL, "InputSchema"), tArgs, .tProblem)
        Do $$$AssertStatusNotOK(tSC, tField _ ": the agent's call is refused by the tool's closed schema")
    }
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tSC = $ClassMethod(..#SCREEN, "Update", ..#PROBE, {"PeerNames": "not a list"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(##class(OcuPilot.Test.X509Import).CodeFor(.tViolations, "PeerNames"), ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE, "a list sent as text is refused on its field")
    Set tSC = ..Mint(..#PROBE, {"PeerNames": [1]}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "and a list holding a number is refused at the mint by the edit's own rules")
}

/// <p>An edit, or an update mint, of an alias the instance does not hold is refused and sends
/// nothing: the screen at 404, the mint at 400.</p>
Method TestAnAbsentAliasIsRefused()
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = $ClassMethod(..#SCREEN, "Update", ..#PROBE, {"OwnerList": ["a"]}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp, 404, "the screen's edit of an absent alias is 404")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is sent")
    Set tSC = ..Mint(..#PROBE, {"OwnerList": ["a"]}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "the agent's update mint of an absent alias is refused")
}

/// <p>Mint one edit of <var>pAlias</var> through the fixture mint.</p>
Method Mint(pAlias As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTurnKey As %String) As %Status
{
    Set pTurnKey = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#MINT, "Mint", ..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", pTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pAlias, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p>Confirm <var>pKey</var> through the shipped transition.</p>
Method Confirm(pKey As %String, Output pHttp As %Integer, Output pCode As %String, Output pResult As %DynamicObject) As %Status
{
    Set pResult = ""
    Quit $ClassMethod(..#CONFIRM, "Confirm", pKey, "", $Username, .pResult, .pHttp, .pCode, .tDetail)
}

ClassMethod Sorted(pList As %List) As %String
{
    Quit ##class(OcuPilot.Test.X509Import).Sorted(pList)
}

}
