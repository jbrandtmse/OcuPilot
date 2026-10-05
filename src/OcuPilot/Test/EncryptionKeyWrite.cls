/// <p>Pins Story 18.22's activations and deactivations on both callers of each tool (B2 to B5; AD-53):
/// the screen's actions (<class>OcuPilot.Test.EncryptionActionFixture</class>) and the agent's mint and
/// confirm (<class>OcuPilot.Test.DatabaseConfirm</class>), for database and data-element keys; their
/// refusals with nothing sent; the read-backs; the vendor's in-use and role refusals in OcuPilot's own
/// sentences; the passwords' absence from every log, ledger row, proposal row and answer; and the
/// script's placeholders.</p>
/// <p><b>No test activates a real key.</b> Every success leg runs through
/// <class>OcuPilot.Test.EncryptionSeamPort</class> armed <code>activation</code>, <code>inuse</code> or
/// <code>role</code>, which answers the active-key lists, the activation and the deactivation itself while
/// reading the probe key files through the vendor. The one real <code>File</code> <code>ACTIVATE</code> is
/// a wrong password, which the vendor refuses before activating anything (measured), and its leg asserts
/// the encryption facts unchanged.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates key files and
/// sets the governance policy. Every probe object is removed before all, after each and after all
/// (<class>OcuPilot.Test.EncryptionKeyProbe</class>), and after each test the instance's encryption state
/// reads as that test found it.</p>
Class OcuPilot.Test.EncryptionKeyWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ENCRYPTION_CONFIG";

Parameter PROBE = "OcuPilot.Test.EncryptionKeyProbe";

Parameter SEAM = "OcuPilot.Test.EncryptionSeamPort";

Parameter ACTION = "OcuPilot.Test.EncryptionActionFixture";

Parameter DATABASE = "security.databaseencryption";

Parameter DATAELEMENT = "security.dataelementencryption";

/// <p>The four governance keys, enabled over the snapshot for every test.</p>
Parameter GOVERNANCEKEYS = "security.databaseencryption.activate,security.databaseencryption.deactivate,security.dataelementencryption.activate,security.dataelementencryption.deactivate";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The encryption facts before each test.</p>
Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EncryptionKeyWrite creates encryption key files on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "EncryptionFacts").%ToJSON()
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Kill tSettings
    For tI = 1:1:$Length(..#GOVERNANCEKEYS, ",") Set tSettings($Piece(..#GOVERNANCEKEYS, ",", tI)) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "SeedDirectory", .tCreated)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#SEAM, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "the probe directory and every probe object are removed")
    Set tFacts = $ClassMethod(..#PROBE, "EncryptionFacts")
    Do $$$AssertTrue('tFacts.%IsDefined("error") && (..PreparedFacts '[ """error"":"), "the encryption facts were read whole before and after the test")
    Do $$$AssertEquals(tFacts.%ToJSON(), ..PreparedFacts, "no key is activated and no encryption setting moved")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>B2, B3: a database key file is activated and its key deactivated on the screen and by a confirmed
/// proposal; each sends one write with the port-built body, the activation with the resolved key file,
/// the body carrying the administrator and password the key file opens with (the seam refuses any other),
/// the key enters and leaves the active list, and the read-backs are
/// <code>written</code> and <code>notFound</code>; each card states its consequence.</p>
Method TestADatabaseKeyIsActivatedAndDeactivatedOnBothCallers()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "act-a.key", , , 256, "OCUPROBEACT A", .tKey), "a key file with one key")
    Do $ClassMethod(..#SEAM, "Arm", "activation")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATABASE, ..Activation("act-a.key"), .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the screen's activation answers 200: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "Security.Encryption.File/ACTIVATE", "sending one ACTIVATE")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "KeysOf", "Security.Encryption.File/ACTIVATE"), "Action,AdminName,AdminPassword", "carrying the port-built body")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "FileOf", "Security.Encryption.File/ACTIVATE"), $ClassMethod(tP, "FilePath", "act-a.key"), "with the key file resolved under its root")
    Set tHeld = $ClassMethod(..#SEAM, "Held", "database")
    Do $$$AssertEquals(tHeld.%Size() _ " " _ tHeld.%Get(0).%Get("Id") _ " " _ tHeld.%Get(0).%Get("KeyLen"), "1 " _ tKey _ " 256", "the key file's key is active, at the length the file holds")
    Do $$$AssertEquals(..ReadBack(tAnswer), "written [""AdminPassword""]", "its read-back reports the password written")
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATABASE, {"action": "deactivate", "id": "SYSTEM", "values": {"KeyId": (tKey)}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the screen's deactivation answers 200: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ $ClassMethod(..#SEAM, "KeysOf", "Security.Encryption.Key/DEACTIVATE"), "Security.Encryption.Key/DEACTIVATE Action,AdminName,AdminPassword", "sending one DEACTIVATE with the composed body")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Held", "database").%Size() _ " " _ ..ReadBack(tAnswer), "0 notFound", "the key leaves the list and its read-back finds it gone")
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Set tSC = $ClassMethod(tP, "KeyMint", "OcuPilot.Test.SeamDatabaseKeyActivate", "act-a.key", {"AdminName": ($Parameter(tP, "ADMIN"))}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's activation is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Fields(tProposal), "root,path,AdminName,FileKeys,AdminPassword", "its card shows the location, the administrator, the file's keys and a password row")
    Do $$$AssertEquals(..Row(tProposal, "FileKeys"), tKey, "naming the key the file holds")
    Do $$$AssertEquals(..Stored(tProposal, "consequence") _ " " _ ..Stored(tProposal, "destructive"), "ENCRYPTION.KEY.ACTIVATE 0", "with the activation's consequence, not destructive")
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, {"AdminPassword": ($Parameter(tP, "PASSWORD"))}, .tResult), "200 ", "its confirm writes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ $ClassMethod(..#SEAM, "Held", "database").%Size(), "Security.Encryption.File/ACTIVATE 1", "one ACTIVATE, and the key is active")
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Set tSC = $ClassMethod(tP, "KeyMint", "OcuPilot.Test.SeamDatabaseKeyDeactivate", "", {"KeyId": (tKey)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's deactivation is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($Select($IsObject(tProposal): tProposal.%Get("changed").%ToJSON(), 1: ""), "[{""field"":""KeyId"",""before"":""" _ tKey _ """,""after"":"""",""removed"":true}]", "its card lists the key it deactivates")
    Do $$$AssertEquals(..Stored(tProposal, "consequence") _ " " _ ..Stored(tProposal, "destructive"), "ENCRYPTION.KEY.DEACTIVATE 1", "with the deactivation's consequence, destructive")
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, "", .tResult), "200 ", "its confirm writes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ $ClassMethod(..#SEAM, "Held", "database").%Size(), "Security.Encryption.Key/DEACTIVATE 0", "one DEACTIVATE, and the list is empty")
}

/// <p>B2: a missing file, a text file, a file whose every key is active, an administrator the file does
/// not list and a password the rules refuse are each refused on both callers with nothing sent.</p>
/// <p>Mutation (Rule 19): drop the all-active check from
/// <method>OcuPilot.Port.EncryptionPort.FileKeys</method> -- an ACTIVATE is sent for the active file and
/// this goes red.</p>
Method TestAnActivationRefusedSendsNothing()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "act-a.key", , , 256, "OCUPROBEACT A", .tKey), "a key file")
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedTextFile", "act-t.txt"), "a text file")
    Do $ClassMethod(..#SEAM, "Arm", "activation")
    Do $ClassMethod(..#SEAM, "Hold", "database", [{"Id": (tKey), "KeyLen": 256, "IsDefault": true}])
    For tCase = $ListBuild("act-m.key", "", "", "400 path:PATH.NOFILE"), $ListBuild("act-t.txt", "", "", "422 path:ENCRYPTION.KEYFILE.UNREADABLE"), $ListBuild("act-a.key", "", "", "400 TOOL.ARGUMENTS " _ $Parameter("OcuPilot.Api.EncryptionError", "REASONKEYSALLACTIVE")) {
        Do $ClassMethod(..#SEAM, "ClearCalls")
        Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATABASE, ..Activation($List(tCase, 1)), .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tAnswer), $List(tCase, 4), $List(tCase, 1) _ " is refused on the screen: " _ $Extract(tAnswer, 1, 200))
        Set tSC = $ClassMethod(tP, "KeyMint", "OcuPilot.Test.SeamDatabaseKeyActivate", $List(tCase, 1), {"AdminName": ($Parameter(tP, "ADMIN"))}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals($IsObject(tProposal) _ " " _ tHttp _ " " _ tProblem, "0 " _ $Piece($List(tCase, 4), " ", 1) _ " " _ $Select($List(tCase, 4) [ "TOOL.ARGUMENTS": $Parameter("OcuPilot.Api.EncryptionError", "REASONKEYSALLACTIVE"), 1: $Piece($List(tCase, 4), " ", 2)), $List(tCase, 1) _ " is refused at the mint with the port's own answer")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", $List(tCase, 1) _ ": with nothing sent")
    }
    Do $ClassMethod(..#SEAM, "Hold", "database", [])
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATABASE, ..Activation("act-a.key", "OcuProbeActNobody"), .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tAnswer), "422 AdminName:ENCRYPTION.KEYFILE.CREDENTIALS", "an administrator the file does not list is refused on the name")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATABASE, ..Activation("act-a.key", , "ab"), .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tAnswer), "422 AdminPassword:ENCRYPTION.KEYFILE.PASSWORD", "a password the rules refuse is refused on the password")
    Set tSC = $ClassMethod(tP, "KeyMint", "OcuPilot.Test.SeamDatabaseKeyActivate", "act-a.key", {"AdminName": "OcuProbeActNobody"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject(tProposal) _ " " _ tHttp _ " " _ tProblem, "0 422 AdminName:ENCRYPTION.KEYFILE.CREDENTIALS", "the agent's activation naming an administrator the file does not list is refused at the mint, on the name")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ $ClassMethod(..#SEAM, "Held", "database").%Size(), " 0", "with nothing sent and nothing active")
}

/// <p>B2: a wrong password reaches the vendor, which refuses it before activating anything (500 #1219,
/// measured); the screen answers 422 on the password, neither the answer nor <code>messages.log</code> nor
/// <code>alerts.log</code> carries the password, and every encryption fact, key activation at startup
/// included, reads as before.</p>
Method TestAWrongPasswordIsTheVendorsRefusalAndActivatesNothing()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "act-w.key", , , 256, "OCUPROBEACT W", .tKey), "a key file")
    Set tWrong = "OcuProbeActWrong" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(9), 1), "+/=", "")
    Do $ClassMethod(..#SEAM, "ArmRefusable", tWrong)
    Set tMessages = $ClassMethod(tP, "LineCount", "messages.log")
    Set tAlerts = $ClassMethod(tP, "LineCount", "alerts.log")
    Set tBefore = $ClassMethod(tP, "EncryptionFacts")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATABASE, ..Activation("act-w.key", , tWrong), .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tAnswer), "422 AdminPassword:ENCRYPTION.KEYFILE.CREDENTIALS", "the vendor's refusal on the password: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "Security.Encryption.File/ACTIVATE", "the one ACTIVATE reached the vendor")
    Do $$$AssertTrue(tAnswer '[ tWrong, "the answer carries no password")
    Set tLines = $ClassMethod(tP, "LinesAfter", "messages.log", tMessages).%ToJSON() _ $ClassMethod(tP, "LinesAfter", "alerts.log", tAlerts).%ToJSON()
    Do $$$AssertTrue(tLines '[ tWrong, "and neither messages.log nor alerts.log carries the password the vendor refused")
    Set tAfter = $ClassMethod(tP, "EncryptionFacts")
    Do $$$AssertEquals(tAfter.%Get("DBEncStartMode") _ " " _ tAfter.%Get("activeKeys"), tBefore.%Get("DBEncStartMode") _ " ", "key activation at startup unchanged, and no key active")
    Do $$$AssertEquals(tAfter.%ToJSON(), tBefore.%ToJSON(), "every encryption fact reads as before")
}

/// <p>B3: a key not active and the default key while another is active are refused on both callers
/// before anything is sent; the vendor's in-use and role refusals are answered 409 in OcuPilot's own
/// sentence, with the key still active.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.DatabaseKeyDeactivate.StateRefusal</method>
/// admits an inactive key -- a DEACTIVATE is sent and the not-active leg goes red; drop the in-use entries
/// from <parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter> -- the in-use leg answers 500 and
/// goes red.</p>
Method TestADeactivationRefusedKeepsTheKey()
{
    Set tP = ..#PROBE
    Set tReasons = "OcuPilot.Api.EncryptionError"
    Do $ClassMethod(..#SEAM, "Arm", "activation")
    Do $ClassMethod(..#SEAM, "Hold", "database", [{"Id": "OCUPROBEACT-K1", "KeyLen": 256, "IsDefault": true}, {"Id": "OCUPROBEACT-K2", "KeyLen": 256, "IsDefault": false}])
    For tCase = $ListBuild("OCUPROBEACT-NONE", $Parameter(tReasons, "REASONKEYINACTIVE")), $ListBuild("OCUPROBEACT-K1", $Parameter(tReasons, "REASONKEYDEFAULT")) {
        Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATABASE, {"action": "deactivate", "id": "SYSTEM", "values": {"KeyId": ($List(tCase, 1))}}, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tAnswer), "400 TOOL.ARGUMENTS " _ $List(tCase, 2), $List(tCase, 1) _ " is refused on the screen")
        Set tSC = $ClassMethod(tP, "KeyMint", "OcuPilot.Test.SeamDatabaseKeyDeactivate", "", {"KeyId": ($List(tCase, 1))}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals($IsObject(tProposal) _ " " _ tProblem, "0 " _ $List(tCase, 2), $List(tCase, 1) _ " is refused at the mint")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ $ClassMethod(..#SEAM, "Held", "database").%Size(), " 2", "with nothing sent and both keys active")
    For tCase = $ListBuild("inuse", "ENCRYPTION.KEY.INUSE"), $ListBuild("role", "ENCRYPTION.KEY.ROLE") {
        Do $ClassMethod(..#SEAM, "Arm", $List(tCase, 1))
        Set tSC = $ClassMethod(tP, "KeyMint", "OcuPilot.Test.SeamDatabaseKeyDeactivate", "", {"KeyId": "OCUPROBEACT-K2"}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the agent's deactivation is minted (" _ tProblem _ ")")
        Do $ClassMethod(..#SEAM, "ClearCalls")
        Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATABASE, {"action": "deactivate", "id": "SYSTEM", "values": {"KeyId": "OCUPROBEACT-K2"}}, .tAnswer, .tStatus)
        Set tObject = $ClassMethod(tP, "Parsed", tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tObject): tObject.%Get("code") _ "|" _ tObject.%Get("reason"), 1: ""), "409 " _ $List(tCase, 2) _ "|" _ $ClassMethod(tReasons, "ReasonFor", $List(tCase, 2)), $List(tCase, 1) _ ": the screen's deactivation is the vendor's refusal in OcuPilot's sentence: " _ $Extract(tAnswer, 1, 200))
        Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, "", .tResult), "409 " _ $List(tCase, 2), $List(tCase, 1) _ ": and the confirm's")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Held", "database").%Size(), 2, $List(tCase, 1) _ ": the key stays active")
    }
}

/// <p>B3 boundary (QA): the default-key refusal holds only while another key is active. A key that is not
/// the default deactivates beside the default, and the default deactivates once it is the only key, on the
/// screen; each is one <code>DEACTIVATE</code> and the key leaves the list.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.DatabaseKeyDeactivate.StateRefusal</method> refuses a
/// default key without counting the active keys -- the sole-default leg goes red on its 400.</p>
Method TestTheDefaultKeyIsDeactivatedOnceItIsTheOnlyKeyActive()
{
    Set tP = ..#PROBE
    Set tBefore = $ClassMethod(tP, "EncryptionFacts")
    Do $ClassMethod(..#SEAM, "Arm", "activation")
    Do $ClassMethod(..#SEAM, "Hold", "database", [{"Id": "OCUPROBEACT-K1", "KeyLen": 256, "IsDefault": true}, {"Id": "OCUPROBEACT-K2", "KeyLen": 256, "IsDefault": false}])
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATABASE, {"action": "deactivate", "id": "SYSTEM", "values": {"KeyId": "OCUPROBEACT-K2"}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ..ReadBack(tAnswer), "200 notFound", "a key that is not the default deactivates beside it: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "Security.Encryption.Key/DEACTIVATE", "one DEACTIVATE left the port")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Held", "database").%Size(), 1, "the default is the only key left")
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATABASE, {"action": "deactivate", "id": "SYSTEM", "values": {"KeyId": "OCUPROBEACT-K1"}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ..ReadBack(tAnswer), "200 notFound", "the default deactivates once it is the only key active: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "Security.Encryption.Key/DEACTIVATE", "again one DEACTIVATE")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Held", "database").%Size(), 0, "no key is active")
    Do $$$AssertEquals($ClassMethod(tP, "EncryptionFacts").%ToJSON(), tBefore.%ToJSON(), "the instance's encryption facts read as before")
}

/// <p>B4: a key file holding two keys is activated for data-element encryption on the screen, both keys
/// listed and the database keys untouched, and each key deactivated, one on the screen and one by a
/// confirmed proposal; the cards state the data-element consequences.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Screen.Tool.DataElementKeyActivate.ACTION</parameter> to
/// <code>ActivateDB</code> -- the keys land in the database list and this goes red.</p>
Method TestDataElementKeysAreActivatedAndDeactivated()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "act-c.key", , , 256, "OCUPROBEACT C", .tFirst), "a key file")
    Do $$$AssertStatusOK($ClassMethod(tP, "AddKeyToFile", "act-c.key", 128, .tSecond), "with a second key")
    Do $ClassMethod(..#SEAM, "Arm", "activation")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATAELEMENT, ..Activation("act-c.key"), .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the screen's activation answers 200: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Held", "dataElement").%Size() _ " " _ $ClassMethod(..#SEAM, "Held", "database").%Size(), "2 0", "both keys are active data-element keys, and no database key")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATAELEMENT, {"action": "deactivate", "id": "SYSTEM", "values": {"KeyId": (tFirst)}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ..ReadBack(tAnswer), "200 notFound", "the screen deactivates the first")
    Set tSC = $ClassMethod(tP, "KeyMint", "OcuPilot.Test.SeamDataElementKeyDeactivate", "", {"KeyId": (tSecond)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's deactivation is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Stored(tProposal, "consequence"), "ENCRYPTION.KEY.DEACTIVATEDATAELEMENT", "with the data-element consequence")
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, "", .tResult), "200 ", "and its confirm writes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Held", "dataElement").%Size(), 0, "neither key is active")
    Set tSC = $ClassMethod(tP, "KeyMint", "OcuPilot.Test.SeamDataElementKeyActivate", "act-c.key", {"AdminName": ($Parameter(tP, "ADMIN"))}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals(..Stored(tProposal, "consequence"), "ENCRYPTION.KEY.ACTIVATEDATAELEMENT", "the agent's activation states the data-element consequence")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATAELEMENT, {"action": "deactivate", "id": "SYSTEM", "values": {"KeyId": (tFirst)}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tAnswer), "400 TOOL.ARGUMENTS " _ $Parameter("OcuPilot.Api.EncryptionError", "REASONKEYINACTIVE"), "an inactive key is refused")
}

/// <p>B5, AD-35: activations carrying a marker password, applied and refused, leave no trace of it in
/// <code>messages.log</code>, <code>alerts.log</code>, the ledger, the proposal row or any answer. The key
/// file opens with the marker, and the seam applies an activation only with that password.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.EncryptionPort.Activate</method> logs its body -- the
/// log leg goes red.</p>
Method TestPasswordsReachNoLogLedgerProposalOrAnswer()
{
    Set tP = ..#PROBE
    Set tMarker = "OcuProbeActMk" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(9), 1), "+/=", "")
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "act-p.key", , tMarker, 256, "OCUPROBEACT P", .tKey), "a key file opened by the marker")
    Set tMessages = $ClassMethod(tP, "LineCount", "messages.log")
    Set tAlerts = $ClassMethod(tP, "LineCount", "alerts.log")
    Do $ClassMethod(..#SEAM, "Arm", "activation")
    Do $ClassMethod(..#SEAM, "ArmCredentials", $Parameter(tP, "ADMIN"), tMarker)
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATABASE, ..Activation("act-p.key", "OcuProbeActNobody", tMarker _ "B"), .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 422, "an unlisted administrator is refused")
    Set tAnswers = tAnswer
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#DATABASE, ..Activation("act-p.key", , tMarker), .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the screen activates")
    Set tAnswers = tAnswers _ tAnswer
    Set tSC = $ClassMethod(tP, "KeyMint", "OcuPilot.Test.SeamDataElementKeyActivate", "act-p.key", {"AdminName": ($Parameter(tP, "ADMIN"))}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's activation is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, {"AdminPassword": (tMarker)}, .tResult), "200 ", "and confirmed with the marker")
    Set tAnswers = tAnswers _ $Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "")
    Do $$$AssertTrue(tAnswers '[ tMarker, "no answer carries the marker")
    Set tLines = $ClassMethod(tP, "LinesAfter", "messages.log", tMessages).%ToJSON() _ $ClassMethod(tP, "LinesAfter", "alerts.log", tAlerts).%ToJSON()
    Do $$$AssertTrue(tLines '[ tMarker, "messages.log and alerts.log carry no marker")
    Set tStored = ##class(OcuPilot.Test.EncryptionKeyFileWrite).StoredText(tProposal.%Get("proposalId"))
    Do $$$AssertTrue(tStored '= "", "the proposal row and its ledger rows are read")
    Do $$$AssertTrue(tStored '[ tMarker, "and neither carries the marker")
}

/// <p>AD-59: the script of a minted activation renders one <code>rest</code> step to
/// <code>File</code> <code>ACTIVATE</code>'s route with the resolved key file and the password's
/// placeholder, and a deactivation's one to <code>Key</code> <code>DEACTIVATE</code>'s with the key; an
/// activation whose key file has gone renders one <code>comment</code> carrying the refusal.</p>
/// <p>Mutation (Rule 19): drop <code>AdminPassword</code> from
/// <method>OcuPilot.Port.EncryptionPort.KeySnippet</method>'s activation body -- the placeholder leg goes
/// red.</p>
Method TestTheScriptRendersTheResolvedFileAndThePlaceholder()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "act-x.key", , , 256, "OCUPROBEACT X", .tKey), "a key file")
    Do $ClassMethod(..#SEAM, "Arm", "activation")
    Do $ClassMethod(..#SEAM, "Hold", "database", [{"Id": "OCUPROBEACT-K9", "KeyLen": 256, "IsDefault": true}])
    Set tEncoded = $ZConvert($ClassMethod(tP, "FilePath", "act-x.key"), "O", "URL")
    For tCase = $ListBuild("OcuPilot.Test.SeamDatabaseKeyActivate", "act-x.key", {"AdminName": ($Parameter(tP, "ADMIN"))}.%ToJSON(), "/security/encryption/file/activate", tEncoded, "<AdminPassword>"), $ListBuild("OcuPilot.Test.SeamDatabaseKeyDeactivate", "", {"KeyId": "OCUPROBEACT-K9"}.%ToJSON(), "/security/encryption/key/deactivate", "OCUPROBEACT-K9", "DeactivateDB") {
        Set tSC = $ClassMethod(tP, "KeyMint", $List(tCase, 1), $List(tCase, 2), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": minted (" _ tProblem _ ")")
        Set tText = ..Draft(tProposal, .tSteps)
        Do $$$AssertEquals(tSteps.%Size() _ " " _ $Select(tSteps.%Size() > 0: tSteps.%Get(0).%Get("kind"), 1: ""), "1 rest", $List(tCase, 1) _ ": one rest step: " _ $Extract(tText, 1, 300))
        Do $$$AssertTrue(tText [ $List(tCase, 4), $List(tCase, 1) _ ": addressed to the vendor's route")
        Do $$$AssertTrue(tText [ $List(tCase, 5), $List(tCase, 1) _ ": naming its key file or key")
        Do $$$AssertTrue(tText [ $List(tCase, 6), $List(tCase, 1) _ ": and " _ $List(tCase, 6))
        Do $$$AssertTrue(tText '[ $Parameter(tP, "PASSWORD"), $List(tCase, 1) _ ": and no password")
    }
    Set tSC = $ClassMethod(tP, "KeyMint", "OcuPilot.Test.SeamDatabaseKeyActivate", "act-x.key", {"AdminName": ($Parameter(tP, "ADMIN"))}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a second activation is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK(##class(%File).Delete($ClassMethod(tP, "FilePath", "act-x.key")), "and its key file removed")
    Set tText = ..Draft(tProposal, .tSteps)
    Do $$$AssertEquals(tSteps.%Size() _ " " _ $Select(tSteps.%Size() > 0: tSteps.%Get(0).%Get("kind") _ " " _ tSteps.%Get(0).%Get("text"), 1: ""), "1 comment " _ ##class(OcuPilot.Api.Error).#REASONPATHNOFILE, "its script is the refusal's sentence: " _ $Extract(tText, 1, 300))
}

/// <p>A screen activation's body for probe file <var>pName</var>, as <var>pAdmin</var> with
/// <var>pPassword</var>.</p>
ClassMethod Activation(pName As %String, pAdmin As %String = {##class(OcuPilot.Test.EncryptionKeyProbe).#ADMIN}, pPassword As %String = {##class(OcuPilot.Test.EncryptionKeyProbe).#PASSWORD}) As %DynamicObject
{
    Set tP = "OcuPilot.Test.EncryptionKeyProbe"
    Quit {"action": "activate", "id": "SYSTEM", "values": {"root": ($ClassMethod(tP, "Root")), "path": ($ClassMethod(tP, "RelativeName", pName)), "AdminName": (pAdmin), "AdminPassword": (pPassword)}}
}

/// <p>The read-back an action's answer carries, as <code>verdict</code> or <code>verdict written</code>.</p>
ClassMethod ReadBack(pAnswer As %String) As %String
{
    Set tObject = ##class(OcuPilot.Test.EncryptionProbe).Parsed(pAnswer)
    If '$IsObject(tObject) || (tObject.%GetTypeOf("readBack") '= "object") Quit ""
    Set tReadBack = tObject.%Get("readBack")
    If tReadBack.%GetTypeOf("written") = "array" && (tReadBack.%Get("written").%Size() > 0) Quit tReadBack.%Get("verdict") _ " " _ tReadBack.%Get("written").%ToJSON()
    Quit tReadBack.%Get("verdict")
}

/// <p>The proposal's diff field names, comma-joined.</p>
ClassMethod Fields(pProposal As %DynamicObject) As %String
{
    If '$IsObject(pProposal) Quit ""
    Quit ##class(OcuPilot.Test.EncryptionKeyFileWrite).Fields(pProposal)
}

/// <p>The <code>after</code> of the proposal's diff row <var>pField</var>.</p>
ClassMethod Row(pProposal As %DynamicObject, pField As %String) As %String
{
    If '$IsObject(pProposal) Quit ""
    Set tAfter = ""
    Set tIterator = pProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("field") = pField Set tAfter = tRow.%Get("after") Quit
    }
    Quit tAfter
}

/// <p>The stored value <var>pName</var> of the proposal <var>pProposal</var>.</p>
ClassMethod Stored(pProposal As %DynamicObject, pName As %String) As %String
{
    If '$IsObject(pProposal) Quit ""
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposal.%Get("proposalId"), .tFound, .tValues)
    Quit $Get(tValues(pName))
}

/// <p>The script of the proposal <var>pProposal</var> as JSON text, with its steps in <var>pSteps</var>.</p>
ClassMethod Draft(pProposal As %DynamicObject, Output pSteps As %DynamicArray) As %String
{
    Set pSteps = []
    Kill tDraft
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take($Select($IsObject($Get(pProposal)): pProposal.%Get("proposalId"), 1: ""), $Username, "https://probe.example", .tDraft, .tHttp, .tCode)
    If '$IsObject($Get(tDraft)) Quit $Get(tCode)
    If (tDraft.%GetTypeOf("draft") = "object") && (tDraft.%Get("draft").%GetTypeOf("steps") = "array") Set pSteps = tDraft.%Get("draft").%Get("steps")
    Quit tDraft.%ToJSON()
}

}
