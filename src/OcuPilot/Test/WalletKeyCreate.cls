/// <p>Pins Story 18.24's RSA and symmetric-key wallet secret create (AD-3, AD-6, AD-35, AD-39, AD-54,
/// AD-55, AD-56): what the two create tools advertise, generation on the screen and on the agent's
/// confirm, each import form on the screen, every refusal of the matrix with no vendor call, an imported
/// symmetric key stored as given with its length, and a name taken since the mint.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%Admin_Wallet</code>, and <code>/usr/bin/openssl</code> for the run-time key material
/// (<class>OcuPilot.Test.X509Material</class>); no key is stored in the repository. Every write reaches
/// the instance through <class>OcuPilot.Test.WalletRecordPort</class>, into the probe collection of
/// <class>OcuPilot.Test.WalletKeyProbe</class>, whose secrets are removed by exact name.</p>
Class OcuPilot.Test.WalletKeyCreate Extends %UnitTest.TestCase
{

Parameter RSATOOL = "OcuPilot.Screen.Tool.WalletKeyCreateRsa";

Parameter SYMMETRICTOOL = "OcuPilot.Screen.Tool.WalletKeyCreateSymmetric";

Parameter LIST = "OcuPilot.Screen.Descriptor.WalletSecretList";

Parameter SAVE = "OcuPilot.Area.Security.WalletKeySave";

Parameter RECORD = "OcuPilot.Test.WalletRecordPort";

Parameter PROBE = "OcuPilot.Test.WalletKeyProbe";

Parameter MATERIAL = "OcuPilot.Test.X509Material";

Parameter RSA = "%Wallet.RSA";

Parameter SYMMETRIC = "%Wallet.SymmetricKey";

Parameter PROHIBITED = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The secrets this class stores, by the part after the probe collection.</p>
Parameter PARTS = "GenRsa,GenSym,AgentRsa,AgentSym,Pkcs1,Pkcs8,Enc,Legacy,CertOnly,PubOnly,Flat,Imp16,Imp24,Imp32,Since,Taken,Refused,Both,Gone";

Property MaterialDirectory As %String;

Method OnBeforeAllTests() As %Status
{
    Set tSC = $ClassMethod(..#MATERIAL, "Generate", .tDirectory)
    If $$$ISERR(tSC) Quit tSC
    Set ..MaterialDirectory = tDirectory
    ; A certificate is valid from the second it is made, so the first import waits it out.
    Hang 2
    Quit $ClassMethod(..#PROBE, "EnsureCollection", .tCreated)
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove", .tRemaining)
    If $$$ISOK(tSC) && (tRemaining > 0) Set tSC = $$$ERROR($$$GeneralError, tRemaining _ " probe secret(s) survived OcuPilot.Test.WalletKeyCreate")
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#MATERIAL, "Discard", ..MaterialDirectory))
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

/// <p>AD-3, AD-6, AD-56: each schema is the name, the closed length and the agent's own words, with no
/// key material and no <code>Type</code>; the settable set is the length; the create is the vendor's
/// <code>PUT</code> through the wallet port, guarded as a create; every material member is a declared
/// secret of the list and a secret row of the tool's field list, and none is composed, so the card shows no key
/// row; and <code>Type</code> is the tool's derived field.</p>
Method TestTheSchemasCarryNoMaterial()
{
    For tTool = ..#RSATOOL, ..#SYMMETRICTOOL {
        Set tSchema = $ClassMethod(tTool, "InputSchema")
        Do $$$AssertEquals(..Keys(tSchema.%Get("properties")), "Length,Name,expectedImpact,rationale,reverse", tTool _ ": the name, the length and the agent's words")
        Do $$$AssertEquals(tSchema.%Get("required").%ToJSON(), "[""Name"",""Length""]", tTool _ ": the name and the length are required")
        Do $$$AssertEquals(tSchema.%Get("properties").%Get("Length").%Get("enum").%ToJSON(), $Select(tTool = ..#RSATOOL: "[2048,3072,4096]", 1: "[16,24,32]"), tTool _ ": the length is its closed set")
        Do $$$AssertEquals($ListToString($ClassMethod(tTool, "SettableFields")), "Length", tTool _ ": the length is the one settable field")
        Do $$$AssertEquals($ClassMethod(tTool, "ReadType") _ " " _ $ClassMethod(tTool, "WriteType") _ " " _ $ClassMethod(tTool, "PortClass"), "GET PUT OcuPilot.Port.WalletPort", tTool _ ": read and written through the wallet port")
        Do $$$AssertEquals($ClassMethod(tTool, "Creates") _ " " _ $ClassMethod(tTool, "ChangeAction"), "1 created", tTool _ ": guarded as a create and publishing created")
        Do $$$AssertEquals($ClassMethod(tTool, "ComposedSecrets"), "", tTool _ ": composes no secret")
        Set tSecrets = $ClassMethod(tTool, "SecretFieldNames")
        Set tMaterial = $Select(tTool = ..#RSATOOL: $ListBuild("Certificate", "PublicKey", "PrivateKey", "Password", "Secret64"), 1: $ListBuild("Secret64"))
        For tI = 1:1:$ListLength(tMaterial) {
            Set tName = $List(tMaterial, tI)
            Do $$$AssertTrue($ListFind($ClassMethod(..#LIST, "SecretArguments"), tName) > 0, tTool _ ": " _ tName _ " is a declared secret of the list")
            Do $$$AssertTrue($ListFind(tSecrets, tName) > 0, tTool _ ": and a secret row of its field list")
            Do $$$AssertEquals($ListFind($ClassMethod(tTool, "PermittedFields"), tName), 0, tTool _ ": and no permitted field")
        }
        Set tPayload = {}
        Do $ClassMethod(tTool, "DerivedFields", tPayload)
        Do $$$AssertEquals(tPayload.%ToJSON(), "{""Type"":""" _ $Parameter(tTool, "SECRETTYPE") _ """}", tTool _ ": Type is derived")
    }
}

/// <p>C2: a free name and a length of the closed set is stored by one <code>PUT {Type, Length}</code>
/// whichever caller asks, the instance reads back the key's metadata, the read-back matches, and the agent's
/// confirm sends the screen's body.</p>
Method TestGenerationOnBothCallers()
{
    Set tScreenRsa = ..Save(..Name("GenRsa"), {"Type": (..#RSA), "Length": 2048}, .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertStatusOK(tScreenRsa, "the screen generates an RSA key")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount") _ " " _ $ClassMethod(..#RECORD, "LastWriteBody"), "1 {""Length"":2048,""Type"":""%Wallet.RSA""}", "with one PUT of the type and the length")
    Do $$$AssertEquals($Select($IsObject($Get(tReadBack)): tReadBack.%Get("verdict"), 1: ""), "matches", "and the read-back matches")
    Set tMeta = $ClassMethod(..#PROBE, "Metadata", ..Name("GenRsa"))
    Do $$$AssertEquals($Select($IsObject(tMeta): tMeta.%Get("Length") _ " " _ tMeta.%Get("HasPrivateKey") _ " " _ tMeta.%Get("HasCertificate"), 1: ""), "2048 1 0", "the instance holds a 2048-bit pair with a private key and no certificate")

    Do $ClassMethod(..#RECORD, "Clear")
    Set tScreenSym = ..Save(..Name("GenSym"), {"Type": (..#SYMMETRIC), "Length": 24}, .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertStatusOK(tScreenSym, "the screen generates a symmetric key")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount") _ " " _ $ClassMethod(..#RECORD, "LastWriteBody"), "1 {""Length"":24,""Type"":""%Wallet.SymmetricKey""}", "with one PUT of the type and the length")
    Set tMeta = $ClassMethod(..#PROBE, "Metadata", ..Name("GenSym"))
    Do $$$AssertEquals($Select($IsObject(tMeta): tMeta.%Get("Length"), 1: ""), 24, "the instance holds a 24-byte key")
    Do $$$AssertTrue($Select($IsObject(tMeta): tMeta.%Get("KeyId"), 1: "") '= "", "with a key id")

    For tCase = $ListBuild(..#RSATOOL, "AgentRsa", 3072), $ListBuild(..#SYMMETRICTOOL, "AgentSym", 32) {
        Do $ClassMethod(..#RECORD, "Clear")
        Set tTool = $List(tCase, 1)
        Set tName = ..Name($List(tCase, 2))
        Set tSC = $ClassMethod(..#PROBE, "Mint", tTool, tName, {"Length": ($List(tCase, 3))}, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tTool _ ": the agent mints the create")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(tProposal.%Get("changed").%ToJSON(), "[{""field"":""Length"",""before"":"""",""after"":""" _ $List(tCase, 3) _ """}]", tTool _ ": the card's one row is the length")
        Set tSC = $ClassMethod(..#PROBE, "Confirm", tProposal.%Get("proposalId"), {}, .tHttp, .tCode, .tResult)
        Do $$$AssertStatusOK(tSC, tTool _ ": its confirm stores the key: " _ $Get(tCode))
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount") _ " " _ $ClassMethod(..#RECORD, "LastWriteBody"), "1 {""Length"":" _ $List(tCase, 3) _ ",""Type"":""" _ $Parameter(tTool, "SECRETTYPE") _ """}", tTool _ ": with the screen's body")
        Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("readBack").%Get("verdict"), 1: ""), "matches", tTool _ ": and a read-back that matches")
        Set tMeta = $ClassMethod(..#PROBE, "Metadata", tName)
        Do $$$AssertEquals($Select($IsObject(tMeta): tMeta.%Get("Length"), 1: ""), $List(tCase, 3), tTool _ ": the instance holds the length asked for")
    }
}

/// <p>C3: each import form on the screen -- PKCS#1, PKCS#8, encrypted PKCS#8 and legacy keys with their
/// password, a certificate alone, a public key alone, and a certificate with its line breaks removed -- is
/// stored by one <code>PUT</code> of canonical PEM, and the instance reads the key's metadata.</p>
/// <p>Mutation (Rule 19): skip the re-wrap in <method>OcuPilot.Port.AdminPort.PemBlock</method> -> the
/// line-breaks leg goes red.</p>
Method TestEveryImportFormOnTheScreen()
{
    Set tM = ..#MATERIAL
    Set tCases = []
    Do tCases.%Push({"part": "Pkcs1", "args": {"RsaPublicKey": "PublicKey", "Pkcs1Key": "PrivateKey"}, "meta": "2048 1 0"})
    Do tCases.%Push({"part": "Pkcs8", "args": {"PublicKey": "PublicKey", "PrivateKey": "PrivateKey"}, "meta": "2048 1 0"})
    Do tCases.%Push({"part": "Enc", "args": {"Certificate": "Certificate", "EncryptedKey": "PrivateKey"}, "pass": 1, "meta": "2048 1 1"})
    Do tCases.%Push({"part": "Legacy", "args": {"Certificate": "Certificate", "LegacyKey": "PrivateKey"}, "pass": 1, "meta": "2048 1 1"})
    Do tCases.%Push({"part": "CertOnly", "args": {"Certificate": "Certificate"}, "meta": "2048 0 1"})
    Do tCases.%Push({"part": "PubOnly", "args": {"PublicKey": "PublicKey"}, "meta": " 0 0"})
    Do tCases.%Push({"part": "Flat", "args": {"Certificate": "Certificate"}, "flat": 1, "meta": "2048 0 1"})
    Set tIterator = tCases.%GetIterator()
    While tIterator.%GetNext(.tI, .tCase) {
        Do $ClassMethod(..#RECORD, "Clear")
        Set tArgs = {"Type": (..#RSA)}
        Set tPairs = tCase.%Get("args").%GetIterator()
        While tPairs.%GetNext(.tBlock, .tField) {
            Set tPem = $ClassMethod(tM, "Pem", tBlock)
            If tCase.%Get("flat") Set tPem = $ClassMethod(tM, "Flattened", tPem)
            Do tArgs.%Set(tField, tPem, "string")
        }
        If tCase.%Get("pass") Do tArgs.%Set("Password", $Parameter(tM, "PASSWORD"), "string")
        Set tName = ..Name(tCase.%Get("part"))
        Set tSC = ..Save(tName, tArgs, .tHttp, .tFault, .tViolations, .tReadBack)
        Do $$$AssertEquals(tCase.%Get("part") _ " " _ $System.Status.IsOK(tSC) _ " " _ +$Get(tViolations), tCase.%Get("part") _ " 1 0", tCase.%Get("part") _ ": the screen stores the import with no violation")
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 1, tCase.%Get("part") _ ": with one PUT")
        Set tSent = ##class(%DynamicAbstractObject).%FromJSON($ClassMethod(..#RECORD, "LastWriteBody"))
        Do $$$AssertEquals(tSent.%Get("Length", "", "json"), "", tCase.%Get("part") _ ": carrying no length")
        If tArgs.%GetTypeOf("Certificate") = "string" Do $$$AssertTrue($Length(tSent.%Get("Certificate"), $Char(10)) > 3, tCase.%Get("part") _ ": and its certificate as canonical PEM with line breaks")
        Set tMeta = $ClassMethod(..#PROBE, "Metadata", tName)
        Do $$$AssertEquals($Select($IsObject(tMeta): $Select(tMeta.%GetTypeOf("Length") = "number": tMeta.%Get("Length"), 1: "") _ " " _ tMeta.%Get("HasPrivateKey") _ " " _ tMeta.%Get("HasCertificate"), 1: ""), tCase.%Get("meta"), tCase.%Get("part") _ ": the instance reads the key's own metadata")
    }
}

/// <p>C5: every rule of the matrix refuses its body on its field with the code the spec names, on the
/// screen, and sends nothing. The password is never a rule's sentence.</p>
/// <p>Mutation (Rule 19): drop each rule in turn from <method>OcuPilot.Area.Security.WalletKeyRules.Validate</method>
/// (length, source, public, password, mismatch, expiry, base64) -> its leg goes red with a PUT recorded.</p>
Method TestEveryRefusalSendsNothing()
{
    Set tM = ..#MATERIAL
    Set tPem = ##class(%DynamicObject).%New()
    For tName = "Certificate", "PublicKey", "PrivateKey", "EncryptedKey", "OtherKey", "ExpiredCertificate", "EcCertificate" {
        Do tPem.%Set(tName, $ClassMethod(tM, "Pem", tName), "string")
    }
    Set tPass = $Parameter(tM, "PASSWORD")
    Set tCases = []
    Do tCases.%Push({"t": (..#RSA), "args": {}, "code": "WALLETKEY.SOURCE.REQUIRED"})
    Do tCases.%Push({"t": (..#RSA), "args": {"Length": 2048, "Certificate": (tPem.Certificate)}, "code": "WALLETKEY.SOURCE.BOTH"})
    Do tCases.%Push({"t": (..#RSA), "args": {"Length": 1024}, "code": "WALLETKEY.LENGTH.RSA"})
    Do tCases.%Push({"t": (..#SYMMETRIC), "args": {"Length": 20}, "code": "WALLETKEY.LENGTH.SYMMETRIC"})
    Do tCases.%Push({"t": (..#RSA), "args": {"PrivateKey": (tPem.PrivateKey)}, "code": "WALLETKEY.PUBLIC.REQUIRED"})
    Do tCases.%Push({"t": (..#RSA), "args": {"Certificate": "not a certificate"}, "code": "WALLETKEY.CERTIFICATE.SHAPE"})
    Do tCases.%Push({"t": (..#RSA), "args": {"PublicKey": (tPem.Certificate)}, "code": "WALLETKEY.PUBLICKEY.SHAPE"})
    Do tCases.%Push({"t": (..#RSA), "args": {"Certificate": (tPem.Certificate), "PrivateKey": "not a key"}, "code": "WALLETKEY.PRIVATEKEY.SHAPE"})
    Do tCases.%Push({"t": (..#RSA), "args": {"Certificate": (tPem.ExpiredCertificate)}, "code": "WALLETKEY.CERTIFICATE.INVALID"})
    Do tCases.%Push({"t": (..#RSA), "args": {"Certificate": (tPem.Certificate), "PrivateKey": (tPem.OtherKey)}, "code": "WALLETKEY.PRIVATEKEY.MISMATCH"})
    Do tCases.%Push({"t": (..#RSA), "args": {"Certificate": (tPem.EcCertificate)}, "code": "WALLETKEY.CERTIFICATE.INVALID", "optional": 1})
    Do tCases.%Push({"t": (..#RSA), "args": {"Certificate": (tPem.Certificate), "PrivateKey": (tPem.EncryptedKey)}, "code": "WALLETKEY.PASSWORD.REQUIRED"})
    Do tCases.%Push({"t": (..#RSA), "args": {"Certificate": (tPem.Certificate), "PrivateKey": (tPem.EncryptedKey), "Password": "not the password"}, "code": "WALLETKEY.PASSWORD.WRONG"})
    Do tCases.%Push({"t": (..#RSA), "args": {"Certificate": (tPem.Certificate), "Password": (tPass)}, "code": "WALLETKEY.PASSWORD.WITHOUTKEY"})
    Do tCases.%Push({"t": (..#SYMMETRIC), "args": {"Secret64": "!!not base64!!"}, "code": "WALLETKEY.SECRET64.SHAPE"})
    Do tCases.%Push({"t": (..#SYMMETRIC), "args": {"Secret64": ($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(20)))}, "code": "WALLETKEY.SECRET64.SHAPE"})
    Do tCases.%Push({"t": (..#SYMMETRIC), "args": {"Length": 16, "Secret64": ($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(16)))}, "code": "WALLETKEY.SOURCE.BOTH"})
    Set tIterator = tCases.%GetIterator()
    While tIterator.%GetNext(.tI, .tCase) {
        If tCase.%Get("optional") Continue
        Set tArgs = {"Type": (tCase.%Get("t"))}
        Set tOver = tCase.%Get("args")
        Set tFields = tOver.%GetIterator()
        While tFields.%GetNext(.tKey, .tValue) {
            Do tArgs.%Set(tKey, tValue, tOver.%GetTypeOf(tKey))
        }
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = ..Save(..Name("Refused"), tArgs, .tHttp, .tFault, .tViolations, .tReadBack)
        Do $$$AssertEquals(..CodesFor(.tViolations), tCase.%Get("code"), "case " _ tI _ ": the screen refuses with " _ tCase.%Get("code"))
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "case " _ tI _ ": and sends nothing")
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCase.%Get("code"))
        Do $$$AssertNotEquals(tReason, "", "case " _ tI _ ": the code carries a sentence")
        Do $$$AssertEquals(tReason [ tPass, 0, "case " _ tI _ ": which quotes no password")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", ..Name("Refused")), 0, "no refused body stored a secret")
    ; The same rules refuse the agent's arguments at the mint.
    For tArgs = {"Name": "x"}, {"Length": 1024}, {"Length": "2048", "Secret64": "AAAA"} {
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#RSATOOL, ..Name("Refused"), tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 400, "the agent's mint refuses " _ tArgs.%ToJSON() _ " at 400")
    }
}

/// <p>C3: an imported symmetric key is stored as given: its AES-CBC round trip equals the imported
/// bytes', its <code>Length</code> reads the decoded byte count, and the port sent two <code>PUT</code>s,
/// the key alone and then the length alone.</p>
/// <p>Mutation (Rule 19): send <code>Length</code> beside <code>Secret64</code> on the create in
/// <method>OcuPilot.Port.WalletPort.PutSymmetricImport</method> -> the round-trip leg goes red; drop the second
/// <code>PUT</code> -> the length leg does.</p>
Method TestAnImportedSymmetricKeyIsStoredAsGiven()
{
    For tLength = 16, 24, 32 {
        Do $ClassMethod(..#RECORD, "Clear")
        Set tKey = $System.Encryption.GenCryptRand(tLength)
        Set tName = ..Name("Imp" _ tLength)
        Set tSC = ..Save(tName, {"Type": (..#SYMMETRIC), "Secret64": ($System.Encryption.Base64Encode(tKey))}, .tHttp, .tFault, .tViolations, .tReadBack)
        Do $$$AssertStatusOK(tSC, tLength _ ": the screen imports the key")
        Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 2, tLength _ ": with two PUTs")
        Set tFirst = ##class(%DynamicAbstractObject).%FromJSON($ClassMethod(..#RECORD, "WriteBodyAt", 1))
        Set tSecond = ##class(%DynamicAbstractObject).%FromJSON($ClassMethod(..#RECORD, "WriteBodyAt", 2))
        Do $$$AssertEquals(tFirst.%GetTypeOf("Length") _ " " _ tFirst.%GetTypeOf("Secret64"), "unassigned string", tLength _ ": the first sends the key and no length")
        Do $$$AssertEquals(tSecond.%ToJSON(), "{""Type"":""%Wallet.SymmetricKey"",""Length"":" _ tLength _ "}", tLength _ ": the second sends the length alone")
        Do $$$AssertTrue($ClassMethod(..#PROBE, "StoredKeyEquals", tName, tKey), tLength _ ": the stored key is the imported one")
        Set tMeta = $ClassMethod(..#PROBE, "Metadata", tName)
        Do $$$AssertEquals($Select($IsObject(tMeta): tMeta.%Get("Length"), 1: ""), tLength, tLength _ ": its length reads the byte count")
        Set tKey = ""
    }
}

/// <p>C2, AD-54: a free name stored between the mint and the confirm refuses the confirm as the target
/// having changed, with no <code>PUT</code> and the stored secret untouched; a name already taken refuses
/// the screen's Save and the agent's mint.</p>
/// <p>Mutation (Rule 19): drop the absence fingerprint from the create mint -> the confirm proceeds and
/// this goes red.</p>
Method TestANameTakenSinceTheMintRefusesTheConfirm()
{
    Set tSince = ..Name("Since")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#RSATOOL, tSince, {"Length": 2048}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a free name is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddSymmetricKey", tSince), "and then taken")
    Set tSC = $ClassMethod(..#PROBE, "Confirm", tProposal.%Get("proposalId"), {}, .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Set tMeta = $ClassMethod(..#PROBE, "Metadata", tSince)
    Do $$$AssertEquals($Select($IsObject(tMeta): tMeta.%Get("Type"), 1: ""), ..#SYMMETRIC, "and the stored secret is untouched")

    Set tTaken = ..Name("Taken")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddSymmetricKey", tTaken), "a secret holds the name")
    Set tSC = ..Save(tTaken, {"Type": (..#RSA), "Length": 2048}, .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertEquals(..CodesFor(.tViolations), "WALLET.NAME.TAKEN", "the screen refuses the taken name")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#RSATOOL, tTaken, {"Length": 2048}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "and the agent's mint refuses it")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "with nothing sent")
}

/// <p>C3, AD-53: the agent's tools generate and never import: a mint with no length is refused, one
/// naming key material is refused as a secret field, and a confirm carrying material beside the length
/// is refused <code>WALLETKEY.SOURCE.BOTH</code> by the port with no <code>PUT</code>.</p>
/// <p>Mutation (Rule 19): the <code>generate</code> mode of
/// <method>OcuPilot.Area.Security.WalletKeyRules.Validate</method> stops requiring the length -> the
/// no-length leg goes red.</p>
Method TestTheAgentImportsNothing()
{
    Set tName = ..Name("Both")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#RSATOOL, tName, {}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "a mint with no length is refused at 400")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#RSATOOL, tName, {"Length": 2048, "Certificate": "x"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "a mint naming key material is refused at 400")
    Do $$$AssertTrue($Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.%Get("detail").%Get("problem"), 1: "") [ "secret field", "as a secret field")

    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#RSATOOL, tName, {"Length": 2048}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a mint of the length is accepted")
    If $$$ISERR(tSC) Quit
    Set tPem = $ClassMethod(..#MATERIAL, "Pem", "Certificate")
    Set tSC = $ClassMethod(..#PROBE, "Confirm", tProposal.%Get("proposalId"), {"Certificate": (tPem)}, .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "422 WALLETKEY.SOURCE.BOTH", "its confirm carrying a certificate is refused for naming both")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "with no PUT")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and nothing stored")
}

/// <p>Hold the create <var>pArgs</var> of <var>pName</var> through the screen's own Save logic, the port
/// recording what is sent.</p>
ClassMethod Save(pName As %String, pArgs As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Quit $ClassMethod(..#SAVE, "Create", pName, pArgs, ..#RECORD, ..#PROHIBITED, .pHttp, .pFault, .pViolations, .pReadBack)
}

/// <p>The probe collection's full name for the secret <var>pPart</var>.</p>
ClassMethod Name(pPart As %String) As %String
{
    Quit $ClassMethod(..#PROBE, "Name", pPart)
}

/// <p>Every code <var>pViolations</var> carries, comma-separated.</p>
ClassMethod CodesFor(ByRef pViolations) As %String
{
    Quit $ClassMethod(..#PROBE, "CodesOf", .pViolations)
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
