/// <p>Pins Story 18.24's reads and its containment (AD-21, AD-27, AD-35, AD-39, AD-52, AD-53, AD-59):
/// the metadata read per key type, no answer, stored proposal, ledger row, script, tool result or log line
/// carrying key material or public halves, the refusal of a server file name before any vendor call, and
/// the codes, sentences, baseline keys and advertised rosters.</p>
/// <p><b>What it needs from the environment:</b> as <class>OcuPilot.Test.WalletKeyCreate</class>, and the
/// instance serving its API for the form and list reads. The message log is read from the byte it held
/// when the class began. One leg provokes a vendor refusal, so the class ends by clearing the monitor's
/// alert state.</p>
Class OcuPilot.Test.WalletKeyRead Extends %UnitTest.TestCase
{

Parameter CREATERSA = "OcuPilot.Screen.Tool.WalletKeyCreateRsa";

Parameter REPLACERSA = "OcuPilot.Screen.Tool.WalletKeyReplaceRsa";

Parameter REPLACESYMMETRIC = "OcuPilot.Screen.Tool.WalletKeyReplaceSymmetric";

Parameter LIST = "OcuPilot.Screen.Descriptor.WalletSecretList";

Parameter SAVE = "OcuPilot.Area.Security.WalletKeySave";

Parameter RECORD = "OcuPilot.Test.WalletRecordPort";

Parameter PROBE = "OcuPilot.Test.WalletKeyProbe";

Parameter MATERIAL = "OcuPilot.Test.X509Material";

Parameter PORT = "OcuPilot.Port.WalletPort";

Parameter RSA = "%Wallet.RSA";

Parameter SYMMETRIC = "%Wallet.SymmetricKey";

Parameter PARTS = "Meta,PubOnly,CertOnly,Sym,Leak,LeakSym,Leaked,Path,Fence,FenceSym,FenceNew";

Property MaterialDirectory As %String;

Property StartedAt As %Integer [ InitialExpression = 0 ];

Method OnBeforeAllTests() As %Status
{
    Set tSC = $ClassMethod(..#MATERIAL, "Generate", .tDirectory)
    If $$$ISERR(tSC) Quit tSC
    Set ..MaterialDirectory = tDirectory
    Set ..StartedAt = $ClassMethod(..#PROBE, "LogSize")
    Hang 2
    Quit $ClassMethod(..#PROBE, "EnsureCollection", .tCreated)
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove", .tRemaining)
    If $$$ISOK(tSC) && (tRemaining > 0) Set tSC = $$$ERROR($$$GeneralError, tRemaining _ " probe secret(s) survived OcuPilot.Test.WalletKeyRead")
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#MATERIAL, "Discard", ..MaterialDirectory))
    ; The deliberate vendor refusal raised the monitor's alert state, which only a clear resets.
    Do $SYSTEM.Monitor.Clear()
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#RECORD, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    For tI = 1:1:$Length(..#PARTS, ",") Do $ClassMethod(..#PROBE, "RemoveSecret", ..Name($Piece(..#PARTS, ",", tI)))
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>C1: an RSA key answers <code>Type</code>, <code>Length</code>, <code>HasPrivateKey</code> and
/// <code>HasCertificate</code>, a symmetric key <code>Type</code>, <code>Length</code> and
/// <code>KeyId</code>, and nothing else; a certificate-only import reads no private key, and a public-key-only
/// import reads its length as JSON null, the vendor's own; the form read carries the same metadata, the closed
/// lengths and the key rules.</p>
/// <p>Mutation (Rule 19): add <code>GetPublic(name).PublicKey</code> to the answer of
/// <method>OcuPilot.Port.WalletPort.KeySettings</method> -> the no-material leg of the next test goes red,
/// and this one fails on its exact key set.</p>
Method TestTheMetadataReadPerType()
{
    Set tMeta = ..Name("Meta")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddRsa", tMeta, 2048), "an RSA key is stored")
    Do $$$AssertEquals(..Keys($ClassMethod(..#PROBE, "Metadata", tMeta)), "HasCertificate,HasPrivateKey,Length,Type", "an RSA key answers four members")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Metadata", tMeta).%ToJSON(), "{""Type"":""%Wallet.RSA"",""Length"":2048,""HasPrivateKey"":true,""HasCertificate"":false}", "as its metadata")

    Set tSym = ..Name("Sym")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddSymmetricKey", tSym), "a symmetric key is stored")
    Do $$$AssertEquals(..Keys($ClassMethod(..#PROBE, "Metadata", tSym)), "KeyId,Length,Type", "a symmetric key answers three members")

    Set tCert = ..Name("CertOnly")
    Set tSC = $ClassMethod(..#SAVE, "Create", tCert, {"Type": (..#RSA), "Certificate": ($ClassMethod(..#MATERIAL, "Pem", "Certificate"))}, ..#RECORD, "OcuPilot.Kernel.Proposal.Prohibited", .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertStatusOK(tSC, "a certificate is imported")
    Set tRead = $ClassMethod(..#PROBE, "Metadata", tCert)
    Do $$$AssertEquals($Select($IsObject(tRead): tRead.%Get("HasPrivateKey") _ " " _ tRead.%Get("HasCertificate"), 1: ""), "0 1", "and reads no private key")

    Set tPub = ..Name("PubOnly")
    Set tSC = $ClassMethod(..#SAVE, "Create", tPub, {"Type": (..#RSA), "PublicKey": ($ClassMethod(..#MATERIAL, "Pem", "PublicKey"))}, ..#RECORD, "OcuPilot.Kernel.Proposal.Prohibited", .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertStatusOK(tSC, "a public key is imported")
    Set tRead = $ClassMethod(..#PROBE, "Metadata", tPub)
    Do $$$AssertEquals($Select($IsObject(tRead): tRead.%GetTypeOf("Length") _ " " _ tRead.%Get("HasPrivateKey") _ " " _ tRead.%Get("HasCertificate"), 1: ""), "null 0 0", "and reads its length as null")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/wallet/secret/form?name=" _ ##class(%CSP.Page).EscapeURL(tMeta), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the form read answers")
    If $IsObject($Get(tBody)) {
        Do $$$AssertEquals(tBody.%Get("secret").%ToJSON(), "{""Name"":""" _ tMeta _ """,""Collection"":""" _ $Parameter(..#PROBE, "COLLECTION") _ """,""Type"":""%Wallet.RSA"",""Length"":2048,""HasPrivateKey"":true,""HasCertificate"":false,""editable"":true}", "the form read carries the metadata and is editable")
        Do $$$AssertEquals(tBody.%Get("keyLengths").%ToJSON(), "{""rsa"":[2048,3072,4096],""symmetric"":[16,24,32]}", "the closed lengths")
        Set tCodes = ""
        Set tIterator = tBody.%Get("rules").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRule) {
            If $Extract(tRule.%Get("code"), 1, 10) = "WALLETKEY." Set tCodes = tCodes _ $ListBuild(tRule.%Get("code"))
        }
        Do $$$AssertEquals($ListLength(tCodes), $ListLength(##class(OcuPilot.Api.WalletKeyError).ViolationCodes()), "and one rule per key code")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/screens/security.secrets/read?maxRows=1000&collection=" _ $Parameter(..#PROBE, "COLLECTION"), .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the list's read answers")
    Do $$$AssertTrue($Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: "") [ "%Wallet.SymmetricKey", "and shows a symmetric key with its type")
}

/// <p>C1, AD-35: after an RSA import, a symmetric import, an agent create confirmed and a replace minted,
/// no answer, stored proposal, ledger row, tool result, script or message-log line carries the key blocks,
/// the public halves, the password or the symmetric key's base64.</p>
/// <p>Mutation (Rule 19): add the sent body to the vendor status
/// <method>OcuPilot.Port.AdminPort.Invoke</method> hands <method>OcuPilot.Port.AdminPort.Fail</method>
/// -> the log leg reddens once a refused write logs it.</p>
Method TestNoSurfaceCarriesKeyMaterial()
{
    Set tM = ..#MATERIAL
    Set tSecrets = $ClassMethod(tM, "All")
    Set tKeyBytes = $System.Encryption.GenCryptRand(32)
    Set tBase64 = $System.Encryption.Base64Encode(tKeyBytes)
    Do tSecrets.%Set("SymmetricKey", tBase64, "string")
    ; A log line cuts a long text short, so each block's first base64 line is looked for too.
    For tBlock = "Certificate", "OtherKey", "PrivateKey" {
        Do tSecrets.%Set(tBlock _ "Head", $Piece($ClassMethod(tM, "Pem", tBlock), $Char(10), 2), "string")
    }
    Set tSeen = ""
    Set tRsa = ..Name("Leak")
    Set tSC = $ClassMethod(..#SAVE, "Create", tRsa, {"Type": (..#RSA), "Certificate": ($ClassMethod(tM, "Pem", "Certificate")), "PublicKey": ($ClassMethod(tM, "Pem", "PublicKey")), "PrivateKey": ($ClassMethod(tM, "Pem", "EncryptedKey")), "Password": ($Parameter(tM, "PASSWORD"))}, ..#RECORD, "OcuPilot.Kernel.Proposal.Prohibited", .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertStatusOK(tSC, "an RSA key is imported")
    Set tSeen = tSeen _ $Select($IsObject($Get(tReadBack)): tReadBack.%ToJSON(), 1: "")
    Do $$$AssertTrue($Select($IsObject($Get(tReadBack)): tReadBack.%Get("verdict"), 1: "") '= "", "with a read-back")
    Set tSym = ..Name("LeakSym")
    Set tSC = $ClassMethod(..#SAVE, "Create", tSym, {"Type": (..#SYMMETRIC), "Secret64": (tBase64)}, ..#RECORD, "OcuPilot.Kernel.Proposal.Prohibited", .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertStatusOK(tSC, "a symmetric key is imported")
    Set tSeen = tSeen _ $Select($IsObject($Get(tReadBack)): tReadBack.%ToJSON(), 1: "")
    Set tSeen = tSeen _ $ClassMethod(..#PROBE, "Metadata", tRsa).%ToJSON() _ $ClassMethod(..#PROBE, "Metadata", tSym).%ToJSON()
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/wallet/secret/form?name=" _ ##class(%CSP.Page).EscapeURL(tRsa), .tStatus, .tBody)
    Set tSeen = tSeen _ $Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: "")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/screens/security.secrets/read?maxRows=1000&collection=" _ $Parameter(..#PROBE, "COLLECTION"), .tStatus, .tBody)
    Set tSeen = tSeen _ $Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: "")
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#LIST, {"collection": ($Parameter(..#PROBE, "COLLECTION"))}, 1000, .tView)
    Set tSeen = tSeen _ $Select($IsObject($Get(tView)): tView.%ToJSON(), 1: "")

    Set tAgent = ..Name("Leaked")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATERSA, tAgent, {"Length": 2048}, .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the agent mints an RSA create")
    If $$$ISOK(tSC) {
        Set tSeen = tSeen _ tProposal.%ToJSON()
        Set tSC = $ClassMethod(..#PROBE, "Confirm", tProposal.%Get("proposalId"), {}, .tHttp, .tCode, .tResult)
        Do $$$AssertStatusOK(tSC, "and confirms it")
        Set tSeen = tSeen _ $Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "")
        Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
        Set tSeen = tSeen _ $Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff"))
        Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one ledger row")
        Set tName = ""
        For {
            Set tName = $Order(tRow(tName))
            If tName = "" Quit
            Set tSeen = tSeen _ tRow(tName) _ "|"
        }
    }
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#REPLACERSA, tRsa, {"Length": 3072}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent mints a replace")
    If $$$ISOK(tSC) {
        Set tSeen = tSeen _ tProposal.%ToJSON()
        Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
        Set tSeen = tSeen _ $Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff"))
    }
    ; The rules refuse every pairing error first, so a deliberate vendor refusal -- a private key that is
    ; another certificate's, sent straight to the port -- is what logs a line for the scan to cover.
    Kill tQuery
    Set tQuery("name") = ..Name("Leaked")
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Wallet.Secret", "PUT", .tQuery, {"Type": (..#RSA), "Certificate": ($ClassMethod(tM, "Pem", "Certificate")), "PrivateKey": ($ClassMethod(tM, "Pem", "OtherKey"))}, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the vendor refuses the mismatched pair")
    Set tLog = $ClassMethod(..#PROBE, "LogSince", ..StartedAt)
    Do $$$AssertTrue(tLog [ "Wallet.Secret failed with HTTP 500", "and logs one line, which the scan covers")
    Do $$$AssertTrue($Length(tSeen) > 500, "the scan covered what the legs answered (" _ $Length(tSeen) _ " characters)")
    Do $$$AssertEquals($ClassMethod(tM, "Leak", tSeen, tSecrets), "", "no answer, proposal or ledger row carries key material")
    Do $$$AssertEquals($ClassMethod(tM, "Leak", tLog, tSecrets), "", "and the message log carries none")
    Set tKeyBytes = ""
}

/// <p>C6: a body naming <code>CertificateFile</code>, <code>PublicKeyFile</code> or
/// <code>PrivateKeyFile</code> is refused 400 <code>PORT.FIELD.UNEXPECTED</code> on that field before any
/// vendor call, by the admin port and by the wallet port, for each key type and for a key-value body; the
/// instance gains no secret and its message log no line.</p>
/// <p>Mutation (Rule 19): drop the refusal from <method>OcuPilot.Port.AdminPort.InvokeLocated</method> ->
/// the instance reads the named file and this goes red.</p>
Method TestAServerFileNameIsRefusedBeforeAnyVendorCall()
{
    Set tName = ..Name("Path")
    Set tLogBefore = $ClassMethod(..#PROBE, "LogSize")
    For tPort = ..#PORT, ..#RECORD, "OcuPilot.Port.AdminPort" {
        For tField = "CertificateFile", "PublicKeyFile", "PrivateKeyFile" {
            For tType = ..#RSA, ..#SYMMETRIC, "%Wallet.KeyValue" {
                Kill tQuery
                Set tQuery("name") = tName
                Set tBody = {"Type": (tType)}
                Do tBody.%Set(tField, "/etc/hostname", "string")
                Do $ClassMethod(..#RECORD, "Clear")
                Set tSC = $ClassMethod(tPort, "Invoke", "Wallet.Secret", "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
                Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ " " _ tFault.%Get("detail").%Get("violations").%Get(0).%Get("field"), 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED _ " " _ tField, tPort _ " " _ tType _ " " _ tField _ ": refused 400 on its field")
            }
        }
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "no secret was stored")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LogSize"), tLogBefore, "and no line reached the message log")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and the recording port saw no vendor call")
}

/// <p>AD-59: the scripts. A symmetric import into a new name is two steps and into a present one is one,
/// each carrying placeholders for the key and the length; an RSA replace by length is its generating
/// body whatever secret members the card names; none carries a key.</p>
/// <p>Mutation (Rule 19): the RSA branch of <method>OcuPilot.Port.WalletPort.Snippet</method> passes the
/// body it was given in place of the generating body -> the last leg goes red.</p>
Method TestTheScriptsCarryNoKeyMaterial()
{
    Set tKey = $System.Encryption.Base64Encode($System.Encryption.GenCryptRand(16))
    Kill tQuery
    Set tQuery("name") = ..Name("Sym")
    Set tBody = {"Type": (..#SYMMETRIC), "Secret64": "<Secret64>"}
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Wallet.Secret", "PUT", .tQuery, tBody, {"creates": true, "origin": "http://h", "user": "u"})
    Do $$$AssertEquals(tSteps.%Size(), 2, "a symmetric import into a new name is two steps")
    Set tText = tSteps.%ToJSON()
    Do $$$AssertTrue((tText [ "<Secret64>") && (tText [ "<Length>"), "carrying the key and the length as placeholders")
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Wallet.Secret", "PUT", .tQuery, tBody, {"creates": false, "origin": "http://h", "user": "u"})
    Do $$$AssertEquals(tSteps.%Size(), 1, "and into a present one is one step")
    Kill tQuery
    Set tQuery("name") = ..Name("Sym")
    Set tQuery("Length") = 3072
    Set tQuery("Type") = ..#RSA
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Wallet.Secret", "PUT", .tQuery, {"Certificate": (tKey), "Password": "<Password>"}, {"creates": false, "origin": "http://h", "user": "u"})
    Do $$$AssertEquals(tSteps.%Size(), 1, "an RSA replace by length is one step")
    Set tText = tSteps.%ToJSON()
    Do $$$AssertTrue((tText [ "3072") && (tText '[ "<Certificate>") && (tText '[ "Length=3072"), "its body is the generating body, with no key member and the length in the body")
    Do $$$AssertEquals(tText [ tKey, 0, "and the replace script carries none of the key the body held")
}

/// <p>AD-10, AD-54: the prohibited set judges a key write by its own type's fields: a create naming a
/// field outside the type's list, and a replace changing one, are refused <code>UNCOVEREDFIELD</code>;
/// each type's own fields pass.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.WalletKey</method> and
/// <method>WalletKeyChanged</method> answer <code>pProhibits</code> 0 whatever the fields -> the refused
/// legs go red.</p>
Method TestTheFieldFenceJudgesAKeyWriteByItsOwnType()
{
    Set tCode = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "UNCOVEREDFIELD")
    Set tFixture = "OcuPilot.Test.ProhibitedFixture"
    Set tNew = $ClassMethod(tFixture, "Reference", ..Name("FenceNew"), "wallet-secret")
    Set tCreates(1) = $ListBuild("security.secrets.creatersa", "{""Length"": 2048}", 0)
    Set tCreates(2) = $ListBuild("security.secrets.creatersa", "{""Length"": 2048, ""Secret64"": ""x""}", 1)
    Set tCreates(3) = $ListBuild("security.secrets.createsymmetric", "{""Length"": 16}", 0)
    Set tCreates(4) = $ListBuild("security.secrets.createsymmetric", "{""Length"": 16, ""Certificate"": ""x""}", 1)
    Set tCreates(5) = $ListBuild("security.secrets.createsymmetric", "{""Length"": 16, ""Usage"": 1}", 1)
    For tI = 1:1:5 {
        Set tSC = $ClassMethod("OcuPilot.Kernel.Proposal.Prohibited", "Prohibits", $List(tCreates(tI), 1), tNew, $List(tCreates(tI), 2), "[]", .tProhibits, .tAnswer)
        Do $$$AssertStatusOK(tSC, "create case " _ tI _ " is judged")
        Do $$$AssertEquals(tProhibits _ " " _ tAnswer, $Select($List(tCreates(tI), 3): "1 " _ tCode, 1: "0 "), "create case " _ tI _ " is " _ $Select($List(tCreates(tI), 3): "refused", 1: "permitted"))
    }
    Set tRsa = ..Name("Fence")
    Set tSym = ..Name("FenceSym")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddRsa", tRsa, 2048), "an RSA key is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddSymmetricKey", tSym), "a symmetric key is stored")
    Set tReplaces(1) = $ListBuild("security.secrets.replacersa", tRsa, "Length", "{""Length"": 3072}", 0)
    Set tReplaces(2) = $ListBuild("security.secrets.replacersa", tRsa, "Length,Secret64", "{""Length"": 3072, ""Secret64"": ""x""}", 1)
    Set tReplaces(3) = $ListBuild("security.secrets.replacesymmetric", tSym, "Secret64", "{""Secret64"": ""x""}", 0)
    Set tReplaces(4) = $ListBuild("security.secrets.replacesymmetric", tSym, "Usage,Secret64", "{""Usage"": 1, ""Secret64"": ""x""}", 1)
    For tI = 1:1:4 {
        Set tRef = $ClassMethod(tFixture, "Reference", $List(tReplaces(tI), 2), "wallet-secret")
        Set tSC = $ClassMethod("OcuPilot.Kernel.Proposal.Prohibited", "Prohibits", $List(tReplaces(tI), 1), tRef, $List(tReplaces(tI), 4), $ClassMethod(tFixture, "Diff", $List(tReplaces(tI), 3)), .tProhibits, .tAnswer)
        Do $$$AssertStatusOK(tSC, "replace case " _ tI _ " is judged")
        Do $$$AssertEquals(tProhibits _ " " _ tAnswer, $Select($List(tReplaces(tI), 5): "1 " _ tCode, 1: "0 "), "replace case " _ tI _ " is " _ $Select($List(tReplaces(tI), 5): "refused", 1: "permitted"))
    }
}

/// <p>C8: every <code>WALLETKEY.*</code> code carries its sentence through both resolvers; the baseline
/// reads the two create keys <code>true</code> and the two replace keys <code>false</code>; the two
/// advertised roster entries are the three tools the agent can mint, and
/// <code>security.secrets.replacesymmetric</code> is in no advertised list and does not resolve for the
/// agent.</p>
/// <p>Mutation (Rule 19): a replace key set <code>true</code> or a create key <code>false</code> in
/// <class>OcuPilot.Kernel.Governance.Baseline</code> -> this goes red; <code>ADVERTISED</code> 1 on
/// <class>OcuPilot.Screen.Tool.WalletKeyReplaceSymmetric</class> -> the roster leg goes red.</p>
Method TestCodesSentencesBaselineAndRosters()
{
    Set tCodes = ##class(OcuPilot.Api.WalletKeyError).Codes()
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Do $$$AssertNotEquals(##class(OcuPilot.Api.WalletKeyError).ReasonFor(tCode), "", tCode _ " carries a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), ##class(OcuPilot.Api.WalletKeyError).ReasonFor(tCode), tCode _ " resolves through the error class")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), ##class(OcuPilot.Api.WalletKeyError).ReasonFor(tCode), tCode _ " resolves as a tool code")
    }
    Do $$$AssertEquals($ListLength(##class(OcuPilot.Api.WalletKeyError).ViolationCodes()) _ " " _ $ListLength(tCodes), "15 18", "fifteen field codes among eighteen")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation("WALLET.TYPE.UNSUPPORTED"), "This secret is not a key-value secret.", "the key-value edit tool's refusal is reworded")
    Set tSC = ##class(OcuPilot.Kernel.Governance.Baseline).Keys(.tKeys)
    Do $$$AssertEquals(tKeys.%Get("security.secrets.creatersa") _ " " _ tKeys.%Get("security.secrets.createsymmetric") _ " " _ tKeys.%Get("security.secrets.replacersa") _ " " _ tKeys.%Get("security.secrets.replacesymmetric"), "1 1 0 0", "the create keys read true and the replace keys false")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tTools)
    Set tAdvertised = ""
    For tI = 1:1:+$Get(tTools) Set tAdvertised = tAdvertised _ $ListBuild(tTools(tI, "name"))
    For tName = "security_secrets_creatersa", "security_secrets_createsymmetric", "security_secrets_replacersa" {
        Do $$$AssertTrue($ListFind(tAdvertised, tName) > 0, tName _ " is advertised")
    }
    Do $$$AssertEquals($ListFind(tAdvertised, "security_secrets_replacesymmetric"), 0, "and replacesymmetric is not")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("security.secrets.replacesymmetric", .tAgent)
    Do $$$AssertEquals($IsObject(tAgent), 0, "it does not resolve for the agent")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("security.secrets.replacesymmetric", .tAll, 1)
    Do $$$AssertEquals($IsObject(tAll), 1, "and resolves for the Secret form's own route")
    Do $$$AssertEquals($ClassMethod(..#REPLACESYMMETRIC, "Advertised"), 0, "declared unadvertised")
}

/// <p>The probe collection's full name for the secret <var>pPart</var>.</p>
ClassMethod Name(pPart As %String) As %String
{
    Quit $ClassMethod(..#PROBE, "Name", pPart)
}

/// <p><var>pObject</var>'s keys, sorted, comma-separated.</p>
ClassMethod Keys(pObject As %DynamicObject) As %String
{
    Kill tSeen
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tSeen(tKey) = ""
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSeen(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

}
