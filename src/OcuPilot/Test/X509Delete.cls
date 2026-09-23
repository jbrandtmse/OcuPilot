/// <p>Pins Story 8.5's agent-only X.509 delete (AD-6, AD-10, AD-51): what
/// <class>OcuPilot.Screen.Tool.X509Delete</class> declares, the removal rows read from the certificate
/// read, the fingerprint over the certificate the user reviewed -- so one replaced under the same
/// alias refuses the confirm -- and the marked, bodyless confirm.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state
/// readable. Every read and write goes to <class>OcuPilot.Test.ProposalFixture</class>, so nothing
/// here deletes a credential. No arming variable is required.</p>
Class OcuPilot.Test.X509Delete Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.X509Delete";

Parameter LIST = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter PROBE = "OcuPilotProbeX509Delete";

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

/// <p>AD-51: an action-style write over the vendor's certificate read and its bodyless
/// <code>DELETE</code>, admitting no field, fingerprinted over the serial number and the issuer, and
/// accepted by the registration guard.</p>
Method TestTheDeleteIsAnActionWriteOverTheCertificate()
{
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ReadType") _ " " _ $ClassMethod(..#TOOL, "WriteType") _ " " _ $ClassMethod(..#TOOL, "SendsBody"), "CERTINFO DELETE 0", "a bodyless delete over the certificate read")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "SettableFields"), "", "admitting no field")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "FingerprintSubject")), "SerialNumber,IssuerDN", "fingerprinted over the certificate the user reviewed")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Destructive") _ " " _ $ClassMethod(..#TOOL, "ChangeAction"), "1 deleted", "destructive, publishing deleted")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(..#TOOL), "", "and the registry accepts its subject")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).IsBodyless("Security.X509Credential", "DELETE"), 1, "the port admits the delete bodyless")
    Set tProperties = $ClassMethod(..#TOOL, "InputSchema").%Get("properties")
    Do $$$AssertEquals(tProperties.%GetTypeOf("Alias"), "object", "the schema names the alias")
}

/// <p>AC5, AD-51: the card lists the certificate as removals read from the fresh certificate read,
/// and a confirm is refused when the certificate under the alias was replaced -- another serial
/// number or another issuer -- since the mint.</p>
/// <p>Mutation: set <parameter>OcuPilot.Screen.Tool.X509Delete.FINGERPRINTSUBJECT</parameter> to
/// <code>IssuerDN</code> -> the moved-serial case confirms and this goes red.</p>
Method TestTheRemovalRowsAndAReplacedCertificateRefusesTheConfirm()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Info("11", "CN=Issuer"))
    Set tSC = ..Mint(..#PROBE, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the delete is minted")
    If $$$ISERR(tSC) Quit
    Set tRows = tProposal.%Get("changed")
    Do $$$AssertEquals(tRows.%Size(), 6, "one removal row per certificate field")
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $$$AssertEquals(tRow.%Get("removed") _ "|" _ tRow.%Get("after"), "1|", tRow.%Get("field") _ " is removed with no after-state")
    }
    Do $$$AssertEquals(tRows.%Get(0).%Get("field") _ "=" _ tRows.%Get(0).%Get("before"), "SubjectDN=CN=Probe", "the subject first, as the certificate read answers it")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "and nothing sent unchanged")

    For tCase = 1:1:2 {
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Info("11", "CN=Issuer"))
        Set tSC = ..Mint(..#PROBE, .tProposal, .tHttp, .tFault)
        If $$$ISERR(tSC) Continue
        Do ##class(OcuPilot.Test.ProposalFixture).Arm($Select(tCase = 1: ..Info("22", "CN=Issuer"), 1: ..Info("11", "CN=Other")))
        Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
        Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "case " _ tCase _ ": a certificate replaced since the mint refuses the confirm")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "case " _ tCase _ ": and nothing is deleted")
    }
}

/// <p>AD-15, AD-51: a confirmed delete sends no body, is marked, names no field in the ledger and
/// answers the deleted action; an alias the instance does not hold is refused at the mint.</p>
/// <p>Mutation: set <parameter>OcuPilot.Screen.Tool.X509Delete.CHANGEACTION</parameter> to
/// <code>updated</code> -> the action assertion goes red.</p>
Method TestAConfirmedDeleteIsMarkedAndSendsNoBody()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..Info("11", "CN=Issuer"))
    Set tSC = ..Mint(..#PROBE, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the delete is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and confirmed: " _ $Get(tCode))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "DELETE", "at the vendor's DELETE")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastWriteBody(), "", "with no body")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("alias"), ..#PROBE, "naming the alias")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "deleted", "answering the deleted action")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row")
    Do $$$AssertEquals($Get(tRow("Fields")), "", "naming no field")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed")

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#PROBE, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "an alias the instance does not hold is refused at the mint")
}

/// <p>A certificate read as <code>CERTINFO</code> answers it, with serial number <var>pSerial</var>
/// and issuer <var>pIssuer</var>.</p>
ClassMethod Info(pSerial As %String, pIssuer As %String) As %String
{
    Set tInfo = {"HasPrivateKey": true, "SerialNumber": (pSerial), "IssuerDN": (pIssuer), "SubjectDN": "CN=Probe", "ValidityNotBefore": "2026-01-01 00:00:00", "ValidityNotAfter": "2126-01-01 00:00:00"}
    Quit tInfo.%ToJSON()
}

/// <p>Mint one delete of <var>pAlias</var> through the fixture mint.</p>
Method Mint(pAlias As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTurnKey As %String) As %Status
{
    Set pTurnKey = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#MINT, "Mint", ..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", pTurnKey, {"Alias": (pAlias)}, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pAlias, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p>Confirm <var>pKey</var> through the shipped transition.</p>
Method Confirm(pKey As %String, Output pHttp As %Integer, Output pCode As %String, Output pResult As %DynamicObject) As %Status
{
    Set pResult = ""
    Quit $ClassMethod(..#CONFIRM, "Confirm", pKey, "", $Username, .pResult, .pHttp, .pCode, .tDetail)
}

}
