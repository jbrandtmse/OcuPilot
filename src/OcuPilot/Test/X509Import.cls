/// <p>Pins Story 8.5's X.509 import (AD-3, AD-6, AD-21, AD-27, AD-35, AD-39, AD-54, AD-55): what
/// <class>OcuPilot.Screen.Tool.X509Import</class> advertises, the one rule set both callers apply,
/// the one body the screen and the confirm send, the card's required and optional secret rows, the
/// absence of every secret from the stored proposal, the ledger, the answers and the port's log, a
/// block whose line breaks were lost, and the port's refusal of a file path.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state
/// readable. Every write goes to <class>OcuPilot.Test.ProposalFixture</class> or is refused by the
/// port, before or at the vendor's save, so nothing here imports a credential; the alias look-up and the prohibited
/// set's target read are live, so the probe alias must be one the instance does not hold. The PEM
/// material is made once for the class by <class>OcuPilot.Test.X509Material</class>, which needs the
/// image's OpenSSL and <code>$ZF(-100)</code>. No arming variable is required.</p>
Class OcuPilot.Test.X509Import Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.X509Import";

Parameter LIST = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter RULES = "OcuPilot.Area.Security.X509Rules";

Parameter MATERIAL = "OcuPilot.Test.X509Material";

/// <p>The shipped screen route with only its port replaced.</p>
Parameter SCREEN = "OcuPilot.Test.X509Fixture";

/// <p>The shipped mint and confirm with the port replaced.</p>
Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The alias the imports here propose; nothing on the instance holds it.</p>
Parameter PROBE = "OcuPilotProbeX509Import";

/// <p>The directory <class>OcuPilot.Test.X509Material</class> made the material in.</p>
Property MaterialDirectory As %String;

Method OnBeforeAllTests() As %Status
{
    Set tSC = $ClassMethod(..#MATERIAL, "Generate", .tDirectory)
    Set ..MaterialDirectory = tDirectory
    Quit tSC
}

/// <p>Delete the material's directory; a failing status when it survives.</p>
Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#MATERIAL, "Discard", ..MaterialDirectory)
}

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
    ; The port legs are refused before any save; a regression that saved one leaves the probe alias
    ; behind, which is removed here by its exact alias so the next run reads the regression again.
    Do ##class(OcuPilot.Test.X509Wire).Remove(..#PROBE)
    Quit $$$OK
}

/// <p>AD-3, AD-10, AD-21: the schema offers the alias and the two lists and nothing else -- no
/// secret and no file path -- and the settable set equals the prohibited set's reviewed create list.
/// The import is a create through the vendor's <code>POST</code>, which the port completes from
/// content.</p>
Method TestTheSchemaAdvertisesNoSecretAndNoPath()
{
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Set tProperties = tSchema.%Get("properties")
    Do $$$AssertEquals(tProperties.%GetTypeOf("Alias"), "object", "the schema names the alias")
    Do $$$AssertEquals(tProperties.%Get("OwnerList").%Get("type") _ " " _ tProperties.%Get("PeerNames").%Get("type"), "array array", "and the two lists, as arrays")
    For tField = "Certificate", "PrivateKey", "PrivateKeyPassword", "CAFile", "CertificateFile", "PrivateKeyFile", "Name" {
        Do $$$AssertEquals(tProperties.%GetTypeOf(tField), "unassigned", "the schema never offers " _ tField)
    }
    Do $$$AssertEquals(tSchema.%Get("required").%ToJSON(), "[""Alias""]", "the alias alone is required")
    Do $$$AssertEquals(tSchema.%Get("additionalProperties"), 0, "closed to everything else")
    Do $$$AssertEquals(..Sorted($ClassMethod(..#TOOL, "SettableFields")), ..Sorted($ClassMethod(..#SET, "PermittedCreateFields", "x509-credential")), "the settable set is the prohibited set's reviewed create list")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "WriteType"), "POST", "the import is the vendor's POST")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Creates") _ " " _ $ClassMethod(..#TOOL, "ChangeAction"), "1 created", "guarded as a create and publishing created (AD-54)")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).IsContentCompleted("Security.X509Credential", "POST"), 1, "and the port completes it from content (AD-27)")
    Do $$$AssertEquals($ListToString($ClassMethod(..#LIST, "SecretArguments")), "Certificate,PrivateKey,PrivateKeyPassword", "the list declares the three secrets")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).EmitSchema(tSchema, .tEmitted, .tProblem)
    Do $$$AssertEquals(tProblem, "", "and the schema is one a provider request can carry")
}

/// <p>AD-55, AD-39: every alias rule refuses on the screen route and at the agent's mint alike; the
/// certificate, key and password rules refuse on the screen, whose Save carries them, each on the
/// field it names and with nothing sent.</p>
/// <p>Mutation: drop the expiry test from <method>OcuPilot.Area.Security.X509Rules.Validate</method>
/// -> the expired case goes red. Mutation: make
/// <method>OcuPilot.Area.Security.X509Rules.KeyMatches</method> read any encrypted key's failure other
/// than the OAEP error as the password -> case 12 goes red.</p>
Method TestEveryFieldRuleRefuses()
{
    For tCase = 1:1:3 {
        If tCase = 1 Set tAlias = $Translate($Justify("", 151), " ", "a"), tCode = "X509ALIASLENGTH"
        If tCase = 2 Set tAlias = "probe/alias", tCode = "X509ALIASSHAPE"
        If tCase = 3 Set tAlias = "probe" _ $Char(9), tCode = "X509ALIASSHAPE"
        Set tExpected = $Parameter("OcuPilot.Api.Error", tCode)
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Set tSC = $ClassMethod(..#SCREEN, "Create", tAlias, ..Args(), .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(..CodeFor(.tViolations, "Alias"), tExpected, "alias case " _ tCase _ ": the screen refuses it")
        Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
        Set tSC = ..Mint(tAlias, {}, .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 400, "alias case " _ tCase _ ": the agent's mint refuses it at 400")
        Do $$$AssertTrue(..Problem(tFault) [ ##class(OcuPilot.Api.Error).ReasonForViolation(tExpected), "alias case " _ tCase _ ": with the same sentence")
    }
    Set tSC = $ClassMethod(..#SCREEN, "Create", "", ..Args(), .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(..CodeFor(.tViolations, "Alias"), ##class(OcuPilot.Api.Error).#X509ALIASREQUIRED, "an empty alias is refused")

    Set tCert = ..Pem("Certificate")
    Set tKey = ..Pem("PrivateKey")
    For tCase = 1:1:12 {
        Set tArgs = ..Args()
        If tCase = 1 Do tArgs.%Remove("Certificate") Set tField = "Certificate", tCode = "X509CERTIFICATEREQUIRED"
        If tCase = 2 Do tArgs.%Set("Certificate", $Replace(tCert, "CERTIFICATE", "PUBLIC KEY")) Set tField = "Certificate", tCode = "X509CERTIFICATESHAPE"
        If tCase = 3 Do tArgs.%Set("Certificate", tCert _ $Char(10) _ tCert) Set tField = "Certificate", tCode = "X509CERTIFICATESHAPE"
        If tCase = 4 Do tArgs.%Set("Certificate", "-----BEGIN CERTIFICATE-----" _ $Char(10) _ $Translate($Justify("", 65540), " ", "A") _ $Char(10) _ "-----END CERTIFICATE-----") Set tField = "Certificate", tCode = "X509CERTIFICATESHAPE"
        If tCase = 5 Do tArgs.%Set("Certificate", "-----BEGIN CERTIFICATE-----" _ $Char(10) _ "AAAABBBBCCCCDDDD" _ $Char(10) _ "-----END CERTIFICATE-----") Set tField = "Certificate", tCode = "X509CERTIFICATESHAPE"
        If tCase = 6 Do tArgs.%Set("Certificate", ..Pem("ExpiredCertificate")) Set tField = "Certificate", tCode = "X509CERTIFICATEEXPIRED"
        If tCase = 7 Do tArgs.%Set("PrivateKey", tCert) Set tField = "PrivateKey", tCode = "X509PRIVATEKEYSHAPE"
        If tCase = 8 Do tArgs.%Set("PrivateKey", ..Pem("OtherKey")) Set tField = "PrivateKey", tCode = "X509PRIVATEKEYMISMATCH"
        If tCase = 9 Do tArgs.%Set("PrivateKey", ..Pem("EncryptedKey")), tArgs.%Set("PrivateKeyPassword", "not the password") Set tField = "PrivateKeyPassword", tCode = "X509PRIVATEKEYPASSWORDWRONG"
        If tCase = 10 Do tArgs.%Remove("PrivateKey"), tArgs.%Set("PrivateKeyPassword", "orphan") Set tField = "PrivateKeyPassword", tCode = "X509PRIVATEKEYPASSWORDWITHOUTKEY"
        If tCase = 11 Do tArgs.%Set("PrivateKey", ..Pem("OtherEncryptedKey")) Set tField = "PrivateKey", tCode = "X509PRIVATEKEYMISMATCH"
        If tCase = 12 Do tArgs.%Set("PrivateKey", ..Pem("EcEncryptedKey")) Set tField = "PrivateKey", tCode = "X509PRIVATEKEYMISMATCH"
        Set tExpected = $Parameter("OcuPilot.Api.Error", tCode)
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Set tSC = $ClassMethod(..#SCREEN, "Create", ..#PROBE, tArgs, .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(..CodeFor(.tViolations, tField), tExpected, "secret case " _ tCase _ ": refused on " _ tField)
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "secret case " _ tCase _ ": and nothing reaches the port")
    }
    Set tArgs = ..Args()
    Do tArgs.%Set("PrivateKeyPassword", $Translate($Justify("", 129), " ", "p"))
    Set tSC = $ClassMethod(..#SCREEN, "Create", ..#PROBE, tArgs, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(..CodeFor(.tViolations, "PrivateKeyPassword"), ##class(OcuPilot.Api.Error).#X509PRIVATEKEYPASSWORDLENGTH, "a password over 128 characters is refused")
    Set tArgs = ..Args()
    Do tArgs.%Set("OwnerList", "not a list")
    Set tSC = $ClassMethod(..#SCREEN, "Create", ..#PROBE, tArgs, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(..CodeFor(.tViolations, "OwnerList"), ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE, "a list sent as text is refused on its field")
    Set tArgs = ..Args()
    Do tArgs.%Set("PrivateKey", ..Pem("EncryptedKey")), tArgs.%Set("PrivateKeyPassword", ##class(OcuPilot.Test.X509Material).#PASSWORD)
    Set tSC = $ClassMethod(..#SCREEN, "Create", ..#PROBE, tArgs, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(+$Get(tViolations), 0, "an encrypted key with its password passes every rule")
}

/// <p>AD-21, AD-55: a file path is refused on both callers. The screen's prohibited verdict refuses
/// <code>CertificateFile</code> as a field nobody reviewed, the agent's schema does not know it, and
/// the port's content completion refuses any body key outside its five before anything is saved.</p>
/// <p>Mutation: add <code>CAFile</code> to <parameter>OcuPilot.Port.AdminPort.IMPORTFIELDS</parameter>
/// -> the port saves the credential over the unread key and the port leg goes red.</p>
Method TestAFilePathIsRefusedByEveryCaller()
{
    Set tArgs = ..Args()
    Do tArgs.%Set("CertificateFile", "/etc/hosts")
    Set tSC = $ClassMethod(..#SCREEN, "Create", ..#PROBE, tArgs, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "403 " _ $Parameter(..#SET, "UNCOVEREDFIELD"), "the screen refuses a file path as an unreviewed field")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing reaches the port")
    For tField = "CAFile", "CertificateFile", "PrivateKeyFile" {
        Set tArgs = {"Alias": (..#PROBE)}
        Do tArgs.%Set(tField, "/etc/hosts")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments($ClassMethod(..#TOOL, "InputSchema"), tArgs, .tProblem)
        Do $$$AssertStatusNotOK(tSC, "the agent's call is refused " _ tField _ " as an argument its schema does not carry")
    }

    For tField = "CertificateFile", "PrivateKeyFile", "CAFile" {
        Kill tQuery
        Set tQuery("alias") = ..#PROBE
        Set tBody = {"Certificate": (..Pem("Certificate"))}
        Do tBody.%Set(tField, "/etc/hosts")
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.X509Credential", "POST", .tQuery, tBody, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 400, "the port refuses " _ tField _ " in an import body at 400")
    }
    Do $$$AssertEquals(..HeldOnInstance(..#PROBE), 0, "and no credential was saved")
}

/// <p>AD-55: the screen's Save and the agent's confirm send one body from the same arguments and
/// the same secrets: the two lists and the three secrets, at the tool's own <code>POST</code>, with
/// the alias only as the query parameter.</p>
/// <p>Mutation: compose <method>OcuPilot.Area.Security.X509Save.Create</method>'s payload over a list
/// missing <code>PeerNames</code> -> the bodies differ and this goes red.</p>
Method TestTheScreenAndTheConfirmSendOneBody()
{
    Set tSecrets = ..Secrets()
    Set tArgs = ..Args()
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set tSC = $ClassMethod(..#SCREEN, "Create", ..#PROBE, tArgs, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the screen accepts the import")
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Set tScreenBody = ##class(OcuPilot.Test.ProposalFixture).LastWriteBody()
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "POST", "at the tool's own write type")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("alias"), ..#PROBE, "naming the alias in the query parameter")

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#PROBE, ..Lists(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent mints the same import")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), tSecrets, .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and its confirm applies it: " _ $Get(tCode))
    Set tAgentBody = ##class(OcuPilot.Test.ProposalFixture).LastWriteBody()

    Do $$$AssertNotEquals(tScreenBody, "", "a body reached the port from the screen")
    Set tScreen = ##class(%DynamicAbstractObject).%FromJSON(tScreenBody)
    Set tAgent = ##class(%DynamicAbstractObject).%FromJSON(tAgentBody)
    Do $$$AssertEquals(..Keys(tScreen), "Certificate,OwnerList,PeerNames,PrivateKey,PrivateKeyPassword", "the screen sends the two lists and the three secrets")
    Do $$$AssertEquals(..Keys(tAgent), ..Keys(tScreen), "the confirm sends the same keys")
    For tField = "OwnerList", "PeerNames", "Certificate", "PrivateKey", "PrivateKeyPassword" {
        Do $$$AssertEquals(tAgent.%Get(tField, "", "json"), tScreen.%Get(tField, "", "json"), tField _ " is the same on both")
    }
}

/// <p>AC5 and the optional-secret ruling: the card's rows are one per declared secret, both sides
/// empty, the certificate required and the key and its password marked optional by the tool's own
/// per-row declaration.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Tool.X509Import.OptionalSecrets</method> answer
/// <code>""</code> -> the key and password rows lose <code>optional</code> and this goes red; make it
/// answer the certificate too -> the required row is optional and this goes red.</p>
Method TestTheCardRequiresTheCertificateAndLeavesTheKeyOptional()
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#PROBE, ..Lists(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the import is minted")
    If $$$ISERR(tSC) Quit
    Kill tRows
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tRows(tRow.%Get("field")) = tRow.%Get("before") _ "|" _ tRow.%Get("after") _ "|" _ tRow.%GetTypeOf("optional") _ "|" _ tRow.%Get("optional")
    }
    Do $$$AssertEquals($Get(tRows("Certificate")), "||unassigned|", "the certificate's row is empty and required")
    Do $$$AssertEquals($Get(tRows("PrivateKey")), "||boolean|1", "the key's row is empty and optional")
    Do $$$AssertEquals($Get(tRows("PrivateKeyPassword")), "||boolean|1", "the password's row is empty and optional")
    Do $$$AssertEquals($Data(tRows("OwnerList")) + $Data(tRows("PeerNames")), 2, "beside one row per supplied list")
}

/// <p>AC3, AD-35: the model cannot send a secret, and after an import confirmed with a key and its
/// password, no secret text is in the stored proposal's arguments, payload or diff, the minted
/// answer, the confirm's answer or the ledger row, whose fields name only the two lists.</p>
/// <p>Mutation: drop <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>'s refusal of a declared
/// secret among the arguments -> the key is minted into the stored arguments and the stored-row scan
/// goes red.</p>
Method TestNoSecretReachesTheProposalTheLedgerOrAnAnswer()
{
    Set tSecrets = ..Secrets()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tArgs = ..Lists()
    Do tArgs.%Set("PrivateKey", ..Pem("PrivateKey"))
    Set tSC = ..Mint(..#PROBE, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "a secret among the model's arguments is refused at the mint")
    If $IsObject($Get(tProposal)) {
        Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
        Do $$$AssertEquals(..Leak($Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff")), $ClassMethod(..#MATERIAL, "All")), "", "and a proposal minted from them anyway stores no secret")
    }

    Set tSC = ..Mint(..#PROBE, ..Lists(), .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the import is minted")
    If $$$ISERR(tSC) Quit
    Set tKey = tProposal.%Get("proposalId")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ..Confirm(tKey, tSecrets, .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and confirmed with its secrets")

    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tValues)
    Do $$$AssertTrue($Get(tFound), "the stored proposal is read back")
    Set tStored = $Get(tValues("arguments")) _ $Get(tValues("payload")) _ $Get(tValues("diff"))
    Do $$$AssertEquals(..Leak(tStored, tSecrets), "", "the stored proposal carries no secret")
    Do $$$AssertEquals(..Leak(tProposal.%ToJSON(), tSecrets), "", "nor does the minted answer")
    Do $$$AssertEquals(..Leak($Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: ""), tSecrets), "", "nor the confirm's answer")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row")
    Set tLedger = ""
    Set tName = ""
    For {
        Set tName = $Order(tRow(tName))
        If tName = "" Quit
        Set tLedger = tLedger _ tRow(tName) _ "|"
    }
    Do $$$AssertEquals(..Leak(tLedger, tSecrets), "", "nor the ledger row")
    Do $$$AssertEquals(..Sorted($ListFromString($Get(tRow("Fields")))), "OwnerList,PeerNames", "whose fields name the two lists and no secret")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "created", "the answer carries the created action")
}

/// <p>AC3, AD-35: a refused import writes no secret text to the port's log. Each case runs the
/// shipped port's content import, refused before or at the save, and every line the port logs is
/// scanned for the certificate, the key and the password. Case 5, a certificate and key that are not
/// RSA, is refused by the vendor's save for a code of its own, which the port maps like the rest.</p>
/// <p>Mutation: append the key text to the status
/// <method>OcuPilot.Port.AdminPort.ImportThroughClass</method> returns for a refused save -> the
/// mismatch case's log line carries it and this goes red.</p>
Method TestARefusedImportLogsNoSecret()
{
    Set tPassword = ##class(OcuPilot.Test.X509Material).#PASSWORD
    Do ##class(OcuPilot.Test.X509LogPort).Taken()
    For tCase = 1:1:5 {
        Set tBody = {"Certificate": (..Pem("Certificate"))}
        If tCase = 1 Do tBody.%Set("PrivateKey", ..Pem("OtherKey"))
        If tCase = 2 Do tBody.%Set("PrivateKey", ..Pem("EncryptedKey")), tBody.%Set("PrivateKeyPassword", tPassword _ "x")
        If tCase = 3 Do tBody.%Set("Certificate", ..Pem("ExpiredCertificate")), tBody.%Set("PrivateKey", ..Pem("PrivateKey"))
        If tCase = 4 Do tBody.%Set("PrivateKey", ..Flattened(..Pem("LegacyKey"))), tBody.%Set("PrivateKeyPassword", tPassword)
        If tCase = 5 Do tBody.%Set("Certificate", ..Pem("EcCertificate")), tBody.%Set("PrivateKey", ..Pem("EcKey"))
        Kill tQuery
        Set tQuery("alias") = ..#PROBE
        Set tSC = ##class(OcuPilot.Test.X509LogPort).Invoke("Security.X509Credential", "POST", .tQuery, tBody, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 400, "case " _ tCase _ ": the port refuses the import at 400")
        Set tLog = ##class(OcuPilot.Test.X509LogPort).Taken()
        Do $$$AssertTrue(tLog '= "", "case " _ tCase _ ": and logs the refusal")
        Set tSeen = $ClassMethod(..#MATERIAL, "All")
        Do $$$AssertEquals(..Leak(tLog, tSeen), "", "case " _ tCase _ ": with no secret text in it")
        Do $$$AssertEquals(..Leak($Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""), tSeen), "", "case " _ tCase _ ": nor in the fault")
    }
    Do $$$AssertEquals(..HeldOnInstance(..#PROBE), 0, "and no credential was saved")
}

/// <p>A block whose line breaks were lost, as a password input or the card leaves one, is re-wrapped
/// at 64 columns and passes the key check; a legacy encrypted key flattened the same way is refused,
/// because its headers can no longer be told from its body.</p>
/// <p>Mutation: make <method>OcuPilot.Port.AdminPort.PemBlock</method> keep a newline-free body on
/// one line -> the flattened key fails as a mismatch and this goes red.</p>
Method TestAFlattenedBlockIsRewrappedAndAFlattenedLegacyKeyRefused()
{
    Set tPort = "OcuPilot.Port.AdminPort"
    Do $$$AssertTrue($ClassMethod(tPort, "PemBlock", ..Pem("Certificate"), "cert", .tCanonical), "the certificate is one PEM block")
    Do $$$AssertTrue($ClassMethod(tPort, "PemBlock", ..Flattened(..Pem("Certificate")), "cert", .tFlat), "and so is its flattened form")
    Do $$$AssertEquals(tFlat, tCanonical, "which is rewritten to the same canonical block")
    Do $$$AssertEquals($Length($Piece(tFlat, $Char(10), 2)), 64, "its body wrapped at 64 columns")
    Set tArgs = {"Certificate": (..Flattened(..Pem("Certificate"))), "PrivateKey": (..Flattened(..Pem("PrivateKey")))}
    Set tSC = $ClassMethod(..#RULES, "Validate", ..#PROBE, tArgs, .tViolations, 0, 0, 1)
    Do $$$AssertEquals(+$Get(tViolations), 0, "a flattened certificate and key pass every rule, the key check included")
    Set tArgs = {"Certificate": (..Pem("Certificate")), "PrivateKey": (..Flattened(..Pem("LegacyKey"))), "PrivateKeyPassword": (##class(OcuPilot.Test.X509Material).#PASSWORD)}
    Set tSC = $ClassMethod(..#RULES, "Validate", ..#PROBE, tArgs, .tViolations, 0, 0, 1)
    Do $$$AssertEquals(..CodeFor(.tViolations, "PrivateKey"), ##class(OcuPilot.Api.Error).#X509PRIVATEKEYSHAPE, "a flattened legacy key is refused on the key's shape")
    Set tArgs = {"Certificate": (..Pem("Certificate")), "PrivateKey": (..Pem("LegacyKey")), "PrivateKeyPassword": (##class(OcuPilot.Test.X509Material).#PASSWORD)}
    Set tSC = $ClassMethod(..#RULES, "Validate", ..#PROBE, tArgs, .tViolations, 0, 0, 1)
    Do $$$AssertEquals(+$Get(tViolations), 0, "while the same key with its line breaks passes")
}

/// <p>A wrong password that decrypts an encrypted key to bytes that do not decode as a key -- about
/// one in two hundred on this build -- is still refused on the password, not as a mismatch. The test
/// searches wrong passwords for one that fails that way, then asks the rule.</p>
/// <p>Mutation: drop the encrypted-key line from
/// <method>OcuPilot.Area.Security.X509Rules.KeyMatches</method> -> that password reads as a
/// mismatch and this goes red.</p>
Method TestAWrongPasswordThatDecodesToNoKeyIsStillThePassword()
{
    Set tPort = "OcuPilot.Port.AdminPort"
    Do $ClassMethod(tPort, "PemBlock", ..Pem("Certificate"), "cert", .tCanonical)
    Set tCertificate = $ClassMethod(tPort, "PemBytes", tCanonical)
    Do $ClassMethod(tPort, "PemBlock", ..Pem("EncryptedKey"), "key", .tKey)
    Set tCipher = $System.Encryption.RSAEncrypt("InterSystems Corp.", tCertificate)
    Set tFound = ""
    For tI = 1:1:4000 {
        Set tBack = $System.Encryption.RSADecrypt(tCipher, tKey, "wrong" _ tI)
        If $System.Encryption.RSAGetLastError() [ "DECODER" Set tFound = "wrong" _ tI Quit
    }
    Do $$$AssertNotEquals(tFound, "", "a wrong password that decrypts the key to no key was found")
    If tFound = "" Quit
    Do $$$AssertEquals(##class(OcuPilot.Area.Security.X509Rules).KeyMatches(tCertificate, tKey, tFound), "wrong", "and the rule still names the password")
}

/// <p>AD-54: an alias the instance already holds refuses the agent's mint at 400, and one taken
/// between the mint and the confirm refuses the confirm at 409 with nothing sent.</p>
Method TestATakenAliasRefusesTheMintAndAConfirmTakenSince()
{
    Set tPresent = "{""OwnerList"":[],""CAFile"":"""",""PeerNames"":[]}"
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tPresent)
    Set tSC = ..Mint(..#PROBE, ..Lists(), .tProposal, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 400, "an import whose alias the instance holds is refused at the mint")

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#PROBE, ..Lists(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "an import whose alias is free is minted")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tPresent)
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), ..Secrets(), .tHttp, .tCode, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "a confirm whose alias was taken since is refused as the target having changed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is sent")
}

/// <p>AD-5, AD-39: the form is built, unlisted and at the list's own route with the editor suffix,
/// over the list's own pairs, and its context never carries a secret being typed; every
/// <code>X509.*</code> field code carries a sentence and the form read publishes exactly those; the
/// list declares Create and invites the agent.</p>
Method TestTheFormDescriptorIsBuiltUnlistedAndCarriesTheListsOwnPairs()
{
    Set tForm = "OcuPilot.Screen.Descriptor.X509Form"
    Do $$$AssertEquals($ClassMethod(tForm, "Route"), $ClassMethod(..#LIST, "Route") _ "/edit", "the form's route is the list's own with the editor suffix")
    Do $$$AssertEquals(''$ClassMethod(tForm, "IsBuilt") _ " " _ (+$ClassMethod(tForm, "SideBarPosition")), "1 0", "it is built and unlisted")
    Do $$$AssertEquals($ClassMethod(tForm, "Archetype") _ " " _ $ClassMethod(tForm, "PrimaryEntityType"), "form-page x509-credential", "a form page over the X.509 credential type")
    Do $$$AssertEquals($ClassMethod(tForm, "ToolIdentifier"), "security.x509form", "with its own tool identifier")
    Do $$$AssertEquals($IsObject($ClassMethod(tForm, "Read")), 0, "and no declared read")
    Do $$$AssertEquals($ListToString($ClassMethod(tForm, "PrivilegePairs")), $ListToString($ClassMethod(..#LIST, "PrivilegePairs")), "the form requires exactly what the list requires")
    Do $$$AssertEquals($Parameter("OcuPilot.Area.Security.X509Save", "DESCRIPTORCLASS") _ " " _ $Parameter(..#RULES, "DESCRIPTORCLASS"), tForm _ " " _ tForm, "and the routes gate on the form's declaration")
    Set tSC = $ClassMethod(tForm, "DeclarationJson", .tFormDeclaration)
    Do $$$AssertStatusOK(tSC, "the form's declaration parses")
    If $$$ISOK(tSC) Do $$$AssertEquals(tFormDeclaration.%Get("context").%Get("secretFields").%ToJSON(), "[""Certificate"",""PrivateKey"",""PrivateKeyPassword""]", "its context never carries a secret being typed")

    Set tCodes = ##class(OcuPilot.Api.Error).X509ViolationCodes()
    Do $$$AssertTrue($ListLength(tCodes) > 0, "the story publishes X.509 field codes")
    For tI = 1:1:$ListLength(tCodes) {
        Do $$$AssertNotEquals(##class(OcuPilot.Api.Error).ReasonForViolation($List(tCodes, tI)), "", $List(tCodes, tI) _ " carries a written sentence")
    }
    Do $$$AssertEquals($ClassMethod(..#RULES, "Rules").%Size(), $ListLength(tCodes), "the form read publishes one rule per code")
    Set tSC = $ClassMethod(..#LIST, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the list's declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tDeclaration.%Get("primaryAction").%Get("id"), "create", "the list declares Create as its primary action")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyNextKey"), "", "so its empty state names no next step")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyAgentKey"), "x509ListEmptyAgent", "and invites the agent instead")
}

/// <p>The two lists every import here proposes.</p>
ClassMethod Lists() As %DynamicObject
{
    Quit {"OwnerList": ["OcuPilotProbeOwner"], "PeerNames": ["probe.example"]}
}

/// <p><method>Lists</method> with the certificate, the encrypted key and its password added: what
/// the screen's Save carries.</p>
ClassMethod Args() As %DynamicObject
{
    Set tArgs = ..Lists()
    Set tSecrets = ..Secrets()
    Set tIterator = tSecrets.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Do tArgs.%Set(tKey, tValue, "string")
    }
    Quit tArgs
}

/// <p>The three secrets the card or the form supplies.</p>
ClassMethod Secrets() As %DynamicObject
{
    Quit {"Certificate": (..Pem("Certificate")), "PrivateKey": (..Pem("EncryptedKey")), "PrivateKeyPassword": (##class(OcuPilot.Test.X509Material).#PASSWORD)}
}

ClassMethod Pem(pName As %String) As %String
{
    Quit ##class(OcuPilot.Test.X509Material).Pem(pName)
}

ClassMethod Flattened(pText As %String) As %String
{
    Quit ##class(OcuPilot.Test.X509Material).Flattened(pText)
}

ClassMethod Leak(pText As %String, pSecrets As %DynamicObject) As %String
{
    Quit ##class(OcuPilot.Test.X509Material).Leak(pText, pSecrets)
}

/// <p>Whether the instance holds a credential with exactly the alias <var>pAlias</var>.</p>
ClassMethod HeldOnInstance(pAlias As %String) As %Boolean
{
    Kill tQuery
    Set tQuery("alias") = pAlias
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.X509Credential", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    Quit ($$$ISOK(tSC) && $IsObject($Get(tResult)))
}

/// <p>Mint one import of <var>pAlias</var> through the fixture mint, as
/// <method>OcuPilot.Screen.Tool.Write.View</method> would.</p>
Method Mint(pAlias As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTurnKey As %String) As %Status
{
    Set pTurnKey = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#MINT, "Mint", ..#LIST, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", pTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pAlias, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p>Confirm <var>pKey</var> through the shipped transition with <var>pSecrets</var> as the
/// body.</p>
Method Confirm(pKey As %String, pSecrets As %DynamicObject, Output pHttp As %Integer, Output pCode As %String, Output pResult As %DynamicObject) As %Status
{
    Set pResult = ""
    Quit $ClassMethod(..#CONFIRM, "Confirm", pKey, pSecrets, $Username, .pResult, .pHttp, .pCode, .tDetail)
}

/// <p>The problem a 400 <code>TOOL.ARGUMENTS</code> refusal carries, or <code>""</code>.</p>
ClassMethod Problem(pFault As %DynamicObject) As %String
{
    If '$IsObject(pFault) Quit ""
    If '$IsObject(pFault.%Get("detail")) Quit ""
    Quit pFault.%Get("detail").%Get("problem")
}

/// <p>The code <var>pViolations</var> carries for <var>pField</var>, or <code>""</code>.</p>
ClassMethod CodeFor(ByRef pViolations, pField As %String) As %String
{
    Set tCode = ""
    For tI = 1:1:+$Get(pViolations) {
        If $List(pViolations(tI), 1) = pField Set tCode = $List(pViolations(tI), 2) Quit
    }
    Quit tCode
}

/// <p><var>pObject</var>'s keys, sorted, comma-separated.</p>
ClassMethod Keys(pObject As %DynamicObject) As %String
{
    Set tKeys = ""
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $ListBuild(tKey)
    }
    Quit ..Sorted(tKeys)
}

/// <p><var>pList</var> sorted, as a comma-separated string.</p>
ClassMethod Sorted(pList As %List) As %String
{
    Kill tSeen
    For tI = 1:1:$ListLength(pList) Set tSeen($List(pList, tI)) = ""
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
