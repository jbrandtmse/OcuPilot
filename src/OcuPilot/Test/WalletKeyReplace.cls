/// <p>Pins Story 18.24's RSA and symmetric-key replace (AD-10, AD-34, AD-51, AD-53, AD-55, AD-56): the
/// agent's proposal is minted destructive with its consequence, a person's Save replaces with no proposal
/// and no governance check, a confirm after the metadata moved or against another type is refused with no
/// vendor call, a certificate-only RSA replace leaves no private key, and a symmetric replace keeps its
/// key id.</p>
/// <p><b>What it needs from the environment:</b> as <class>OcuPilot.Test.WalletKeyCreate</class>. The
/// governance policy is snapshotted before each test and restored after it, and every write reaches the
/// instance through <class>OcuPilot.Test.WalletRecordPort</class>.</p>
Class OcuPilot.Test.WalletKeyReplace Extends %UnitTest.TestCase
{

Parameter RSATOOL = "OcuPilot.Screen.Tool.WalletKeyReplaceRsa";

Parameter SYMMETRICTOOL = "OcuPilot.Screen.Tool.WalletKeyReplaceSymmetric";

Parameter SAVE = "OcuPilot.Test.WalletSaveFixture";

Parameter RECORD = "OcuPilot.Test.WalletRecordPort";

Parameter PROBE = "OcuPilot.Test.WalletKeyProbe";

Parameter MATERIAL = "OcuPilot.Test.X509Material";

Parameter RSA = "%Wallet.RSA";

Parameter SYMMETRIC = "%Wallet.SymmetricKey";

Parameter PARTS = "Rsa,Sym,Moved,Flipped,Cert";

Property MaterialDirectory As %String;

Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    Set tSC = $ClassMethod(..#MATERIAL, "Generate", .tDirectory)
    If $$$ISERR(tSC) Quit tSC
    Set ..MaterialDirectory = tDirectory
    Hang 2
    Quit $ClassMethod(..#PROBE, "EnsureCollection", .tCreated)
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove", .tRemaining)
    If $$$ISOK(tSC) && (tRemaining > 0) Set tSC = $$$ERROR($$$GeneralError, tRemaining _ " probe secret(s) survived OcuPilot.Test.WalletKeyReplace")
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#MATERIAL, "Discard", ..MaterialDirectory))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    Kill ..PreparedPolicy
    Merge ..PreparedPolicy = tRows
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Merge tRows = ..PreparedPolicy
    Do ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    For tI = 1:1:$Length(..#PARTS, ",") Do $ClassMethod(..#PROBE, "RemoveSecret", ..Name($Piece(..#PARTS, ",", tI)))
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>C4, AD-51, AD-6: the agent's RSA replace is minted destructive with its consequence code and one
/// card row, the length before and after; the schema is the name and the closed length; and the
/// symmetric replace, which only a person reaches, is declared destructive and unadvertised and asks the
/// card for its key as a masked row.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.WalletKeyReplace.DESTRUCTIVE</parameter> 0 ->
/// the destructive-mint leg goes red.</p>
Method TestTheReplaceIsMintedDestructive()
{
    Set tName = ..Name("Rsa")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddRsa", tName, 2048), "an RSA key is stored")
    Set tSchema = $ClassMethod(..#RSATOOL, "InputSchema")
    Do $$$AssertEquals(tSchema.%Get("properties").%Get("Length").%Get("enum").%ToJSON() _ " " _ tSchema.%Get("required").%ToJSON(), "[2048,3072,4096] [""Name"",""Length""]", "the schema is the name and the closed length")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#RSATOOL, tName, {"Length": 3072}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the replace is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%ToJSON(), "[{""field"":""Length"",""before"":""2048"",""after"":""3072""}]", "the card's one row is the length before and after")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals(+$Get(tValues("destructive")) _ " " _ $Get(tValues("consequence")), "1 WALLETKEY.REPLACE.RSA", "the stored proposal is destructive with the RSA consequence")
    Set tStored = ##class(%DynamicAbstractObject).%FromJSON($Get(tValues("payload")))
    Do $$$AssertEquals(tStored.%GetTypeOf("Certificate") _ " " _ tStored.%GetTypeOf("PrivateKey"), "unassigned unassigned", "the stored payload names no key member")
    Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation("WALLETKEY.REPLACE.RSA"), "", "and the consequence carries its sentence")

    Set tSym = ..Name("Sym")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddSymmetricKey", tSym), "a symmetric key is stored")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#SYMMETRICTOOL, tSym, {}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the symmetric replace is minted by the shipped mint")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%ToJSON(), "[{""field"":""Secret64"",""before"":"""",""after"":""""}]", "its one row is the key, masked and empty")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals($Get(tValues("consequence")), "WALLETKEY.REPLACE.SYMMETRIC", "with the symmetric consequence")
    Do $$$AssertEquals($ClassMethod(..#SYMMETRICTOOL, "Destructive") _ " " _ $ClassMethod(..#SYMMETRICTOOL, "Advertised"), "1 0", "the tool declares itself destructive and unadvertised")
}

/// <p>C4, AD-53: a person's Save replaces the key with no proposal and no governance check -- both
/// replace keys are disabled at the baseline -- through one <code>PUT</code> each: an RSA key by a newly
/// generated pair, a symmetric key by an imported one that keeps its key id.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.WalletSave.Update</method> stops dispatching to
/// <method>OcuPilot.Area.Security.WalletKeySave.Replace</method> -> both legs go red.</p>
Method TestTheScreenReplacesWithNoProposalAndNoGovernance()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    Set tName = ..Name("Rsa")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddRsa", tName, 2048), "an RSA key is stored")
    Set tSC = $ClassMethod(..#SAVE, "Update", tName, {"Length": 3072}, .tHttp, .tFault, .tViolations, .tReadBack, .tKey)
    Do $$$AssertStatusOK(tSC, "the screen replaces the pair")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount") _ " " _ $ClassMethod(..#RECORD, "LastWriteBody"), "1 {""Length"":3072,""Type"":""%Wallet.RSA""}", "with one PUT of the length")
    Do $$$AssertEquals(+$Get(tKey), 1, "as a key write")
    Do $$$AssertEquals($Select($IsObject($Get(tReadBack)): tReadBack.%Get("verdict"), 1: ""), "matches", "whose read-back matches (AD-58)")
    Set tMeta = $ClassMethod(..#PROBE, "Metadata", tName)
    Do $$$AssertEquals($Select($IsObject(tMeta): tMeta.%Get("Length") _ " " _ tMeta.%Get("HasPrivateKey"), 1: ""), "3072 1", "the instance holds a 3072-bit pair")

    Do $ClassMethod(..#RECORD, "Clear")
    Set tSym = ..Name("Sym")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddSymmetricKey", tSym), "a symmetric key is stored")
    Set tBefore = $ClassMethod(..#PROBE, "Metadata", tSym)
    Set tKeyBytes = $System.Encryption.GenCryptRand(32)
    Set tSC = $ClassMethod(..#SAVE, "Update", tSym, {"Secret64": ($System.Encryption.Base64Encode(tKeyBytes))}, .tHttp, .tFault, .tViolations, .tReadBack, .tKey)
    Do $$$AssertStatusOK(tSC, "the screen replaces the key")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 1, "with one PUT")
    Set tSent = ##class(%DynamicAbstractObject).%FromJSON($ClassMethod(..#RECORD, "LastWriteBody"))
    Do $$$AssertEquals(tSent.%GetTypeOf("Secret64") _ " " _ tSent.%Get("Length") _ " " _ tSent.%Get("Type"), "string 32 %Wallet.SymmetricKey", "carrying the key and the length the port computed")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "StoredKeyEquals", tSym, tKeyBytes), "the stored key is the imported one")
    Set tAfter = $ClassMethod(..#PROBE, "Metadata", tSym)
    Do $$$AssertEquals($Select($IsObject(tAfter): tAfter.%Get("KeyId") _ " " _ tAfter.%Get("Length"), 1: ""), tBefore.%Get("KeyId") _ " 32", "the key id is kept and the length reads 32")
}

/// <p>C4: a certificate-only import replaces the pair and leaves no private key; and a replace that
/// names both a length and a key is refused on <code>Length</code> with no <code>PUT</code>.</p>
Method TestACertificateOnlyReplaceLeavesNoPrivateKey()
{
    Set tName = ..Name("Cert")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddRsa", tName, 2048), "an RSA key is stored")
    Set tSC = $ClassMethod(..#SAVE, "Update", tName, {"Length": 2048, "Certificate": ($ClassMethod(..#MATERIAL, "Pem", "Certificate"))}, .tHttp, .tFault, .tViolations, .tReadBack, .tKey)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "CodeFor", .tViolations, "Length"), "WALLETKEY.SOURCE.BOTH", "a length beside a certificate is refused")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "with no PUT")
    Set tSC = $ClassMethod(..#SAVE, "Update", tName, {"Certificate": ($ClassMethod(..#MATERIAL, "Pem", "Certificate"))}, .tHttp, .tFault, .tViolations, .tReadBack, .tKey)
    Do $$$AssertStatusOK(tSC, "the certificate alone replaces the pair")
    Set tMeta = $ClassMethod(..#PROBE, "Metadata", tName)
    Do $$$AssertEquals($Select($IsObject(tMeta): tMeta.%Get("HasPrivateKey") _ " " _ tMeta.%Get("HasCertificate"), 1: ""), "0 1", "the secret holds a certificate and no private key")
}

/// <p>C4: the agent's confirm replaces the pair through one <code>PUT</code> of the length once the key
/// is enabled, and at the baseline it is refused <code>GOVERNANCE.DISABLED</code> with no
/// <code>PUT</code>.</p>
/// <p>Mutation (Rule 19): <code>security.secrets.replacersa</code> enters the baseline <code>true</code>
/// -> the refusal leg goes red.</p>
Method TestTheAgentsConfirmIsGovernedAndReplacesThePair()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    Set tName = ..Name("Rsa")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddRsa", tName, 2048), "an RSA key is stored")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#RSATOOL, tName, {"Length": 4096}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the replace is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#PROBE, "Confirm", tProposal.%Get("proposalId"), {}, .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "403 " _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "at the baseline the confirm is refused as disabled by policy")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "with no PUT")
    Kill tSettings
    Set tSettings("security.secrets.replacersa") = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is enabled")
    Set tSC = $ClassMethod(..#PROBE, "Confirm", tProposal.%Get("proposalId"), {}, .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "the confirm replaces the pair: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount") _ " " _ $ClassMethod(..#RECORD, "LastWriteBody"), "1 {""Type"":""%Wallet.RSA"",""Length"":4096}", "with one PUT of the length")
    Set tMeta = $ClassMethod(..#PROBE, "Metadata", tName)
    Do $$$AssertEquals($Select($IsObject(tMeta): tMeta.%Get("Length"), 1: ""), 4096, "the instance holds a 4096-bit pair")

    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#RSATOOL, tName, {"Length": 3072}, .tImporting, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a second replace is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#PROBE, "Confirm", tImporting.%Get("proposalId"), {"Certificate": ($ClassMethod(..#MATERIAL, "Pem", "Certificate"))}, .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "422 WALLETKEY.SOURCE.BOTH", "a confirm carrying key material beside the length is refused")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "with no PUT")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#RSATOOL, tName, {"Length": 3072}, .tImporting, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a third replace is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#PROBE, "Confirm", tImporting.%Get("proposalId"), {"Password": "x"}, .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode) _ " " _ $ClassMethod(..#RECORD, "WriteCount"), "422 WALLETKEY.SOURCE.BOTH 0", "a confirm carrying a password beside the length is refused with no PUT")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Metadata", tName).%Get("Length"), 4096, "and the pair is as it was")
}

/// <p>C4, AD-6: a confirm after the secret's metadata moved is refused as the target having changed, and
/// a confirm after the name came to hold another type likewise, each with no <code>PUT</code>; the agent's
/// mint against another type is refused, and the screen refuses another type, an unexpected member and
/// the type check on its fields.</p>
/// <p>Mutation (Rule 19): skip the type check in
/// <method>OcuPilot.Screen.Tool.WalletKeyReplace.MergeUpdate</method> -> the mint of a symmetric secret
/// is accepted and this goes red.</p>
Method TestAMovedOrFlippedTargetRefusesTheConfirmAndAnotherTypeRefusesTheSave()
{
    Kill tSettings
    Set tSettings("security.secrets.replacersa") = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is enabled")
    Set tMoved = ..Name("Moved")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddRsa", tMoved, 2048), "an RSA key is stored")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#RSATOOL, tMoved, {"Length": 3072}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "its replace is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#SAVE, "Update", tMoved, {"Certificate": ($ClassMethod(..#MATERIAL, "Pem", "Certificate"))}, .tHttp2, .tFault2, .tViolations, .tReadBack, .tKey)
    Do $$$AssertStatusOK(tSC, "and then its pair is replaced by a certificate")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#PROBE, "Confirm", tProposal.%Get("proposalId"), {}, .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "with no PUT")

    Set tFlipped = ..Name("Flipped")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddRsa", tFlipped, 2048), "a second RSA key is stored")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#RSATOOL, tFlipped, {"Length": 3072}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "its replace is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveSecret", tFlipped), "the name is deleted")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddSymmetricKey", tFlipped), "and taken by a symmetric key")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = $ClassMethod(..#PROBE, "Confirm", tProposal.%Get("proposalId"), {}, .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm of the other type is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "with no PUT")

    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#RSATOOL, tFlipped, {"Length": 3072}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "the agent's RSA replace of a symmetric key is refused at 400")
    Set tSC = $ClassMethod(..#SAVE, "Update", tFlipped, {"Type": "%Wallet.RSA", "Certificate": ($ClassMethod(..#MATERIAL, "Pem", "Certificate"))}, .tHttp, .tFault, .tViolations, .tReadBack, .tKey)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "CodeFor", .tViolations, "Type"), "WALLETKEY.TYPE.MISMATCH", "the screen refuses a body of another type")
    Set tSC = $ClassMethod(..#SAVE, "Update", tFlipped, {"Usage": 1}, .tHttp, .tFault, .tViolations, .tReadBack, .tKey)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "and a member a key replace does not take")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "with no PUT")
}

/// <p>The probe collection's full name for the secret <var>pPart</var>.</p>
ClassMethod Name(pPart As %String) As %String
{
    Quit $ClassMethod(..#PROBE, "Name", pPart)
}

}
