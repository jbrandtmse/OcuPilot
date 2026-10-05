/// <p>Pins Story 18.7's key-file writes on both callers of each tool (A2 to A4; AD-53, AD-55): the form's
/// Save (<class>OcuPilot.Test.EncryptionSaveFixture</class>), the screen's actions
/// (<class>OcuPilot.Test.EncryptionActionFixture</class>) and the agent's mint and confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>): the creates, the administrator and key adds and
/// removes, their refusals with nothing sent, the read-backs, the self-protection arm through the seam,
/// the passwords' absence from every log, ledger row, proposal row and answer, and the script's
/// placeholders.</p>
/// <p>The vendor's writes are real, on probe files under <code>&lt;ManagerDirectory&gt;ocuprobe187/</code>;
/// <class>OcuPilot.Test.EncryptionSeamPort</class> records every call the port makes and sends it, so a
/// refusal shows as a recorded write or none.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates key files and
/// sets the governance policy. The probe directory and every probe object are removed before all, after
/// each and after all (<class>OcuPilot.Test.EncryptionProbe</class>), and after each test the instance's
/// encryption state reads as that test found it: no key activated, no <code>Security.System</code>
/// property moved.</p>
Class OcuPilot.Test.EncryptionKeyFileWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ENCRYPTION_CONFIG";

Parameter PROBE = "OcuPilot.Test.EncryptionProbe";

Parameter SEAM = "OcuPilot.Test.EncryptionSeamPort";

Parameter SAVE = "OcuPilot.Test.EncryptionSaveFixture";

Parameter ACTION = "OcuPilot.Test.EncryptionActionFixture";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.EncryptionKeyFileCreate";

Parameter ADDADMINTOOL = "OcuPilot.Screen.Tool.EncryptionKeyFileAddAdmin";

Parameter REMOVEADMINTOOL = "OcuPilot.Screen.Tool.EncryptionKeyFileRemoveAdmin";

Parameter ADDKEYTOOL = "OcuPilot.Screen.Tool.EncryptionKeyFileAddKey";

Parameter REMOVEKEYTOOL = "OcuPilot.Screen.Tool.EncryptionKeyFileRemoveKey";

Parameter KEYS = "security.encryptionkeyfile";

Parameter ADMINS = "security.encryptionkeyfileadmins";

/// <p>The five governance keys, enabled over the snapshot for every test.</p>
Parameter GOVERNANCEKEYS = "security.encryptionkeyfile.create,security.encryptionkeyfile.addkey,security.encryptionkeyfile.removekey,security.encryptionkeyfileadmins.addadministrator,security.encryptionkeyfileadmins.removeadministrator";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The encryption facts before each test (<method>OcuPilot.Test.EncryptionProbe.EncryptionFacts</method>).</p>
Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EncryptionKeyFileWrite creates encryption key files on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    Kill ^||OcuPilotEncryptionProhibited
    Kill tSettings
    For tI = 1:1:$Length(..#GOVERNANCEKEYS, ",") Set tSettings($Piece(..#GOVERNANCEKEYS, ",", tI)) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "SeedDirectory", .tCreated)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort, ^||OcuPilotEncryptionProhibited
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
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

/// <p>A2: the form's Save and the agent's confirmed proposal each send one <code>File</code>
/// <code>POST</code> carrying the port-built body; the file holds one key of the chosen length and the
/// administrator; the Save answers the new key's id, marked <code>no-store</code>, and each read-back
/// reports the password written.</p>
Method TestACreateWritesOneKeyFileOnBothCallers()
{
    Set tP = ..#PROBE
    Set tBody = {"root": ($ClassMethod(tP, "Root")), "path": ($ClassMethod(tP, "RelativeName", "probe-a.key")), "AdminName": ($Parameter(tP, "ADMIN")), "AdminPassword": ($Parameter(tP, "PASSWORD")), "KeyLen": 256, "Description": "OCUPROBE187 A"}
    Set tSC = $ClassMethod(..#SAVE, "Handle", tBody, .tAnswer, .tStatus, .tCache)
    Do $$$AssertEquals(tStatus, 201, "the form's Save answers 201: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals(tCache, "no-store", "marked no-store")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "Security.Encryption.File/POST", "sending one POST")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "KeysOf", "Security.Encryption.File/POST"), "AdminName,AdminPassword,Description,File,KeyLen", "carrying the body the port builds")
    Set tContents = $ClassMethod(tP, "Contents", "probe-a.key")
    Set tAnswerObject = $ClassMethod(tP, "Parsed", tAnswer)
    Do $$$AssertEquals(tContents.%Get("keys").%Size() _ " " _ tContents.%Get("keys").%Get(0).%Get("KeyLen") _ " " _ tContents.%Get("admins").%ToJSON(), "1 256 [""OCUPROBE187ADMIN""]", "the file holds one 256-bit key and the administrator")
    Do $$$AssertEquals($Select($IsObject(tAnswerObject): tAnswerObject.%Get("keyId"), 1: ""), tContents.%Get("keys").%Get(0).%Get("Id"), "the Save answers the new key's id")
    Do $$$AssertEquals($Select($IsObject(tAnswerObject) && $IsObject(tAnswerObject.%Get("readBack")): tAnswerObject.%Get("readBack").%Get("verdict") _ " " _ tAnswerObject.%Get("readBack").%Get("written").%ToJSON(), 1: ""), "written [""AdminPassword""]", "its read-back reports the password written")
    Do $$$AssertTrue(tAnswer '[ $Parameter(tP, "PASSWORD"), "the answer carries no password")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(tP, "Mint", ..#CREATETOOL, "probe-b.key", {"AdminName": ($Parameter(tP, "ADMIN")), "KeyLen": 128, "Description": "OCUPROBE187 B"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($Select($IsObject(tProposal): ..Fields(tProposal), 1: ""), "Location,AdminName,KeyLen,Description,AdminPassword", "its card shows the location, the arguments and a password row")
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, {"AdminPassword": ($Parameter(tP, "PASSWORD"))}, .tResult), "200 ", "its confirm writes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "Security.Encryption.File/POST", "one POST")
    Set tContents = $ClassMethod(tP, "Contents", "probe-b.key")
    Do $$$AssertEquals(tContents.%Get("keys").%Size() _ " " _ tContents.%Get("keys").%Get(0).%Get("KeyLen"), "1 128", "the agent's file holds one 128-bit key")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)) && $IsObject(tResult.%Get("readBack")): tResult.%Get("readBack").%Get("verdict"), 1: ""), "written", "its read-back reports the password written")
}

/// <p>A2: an existing name, a missing folder, a name directly in the manager directory, a key length of
/// 100, an empty and a 51-character administrator name, and an empty and a 2-character password are
/// each refused on their field by the Save with nothing sent, and the agent's
/// mint refuses the location and argument cases.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.EncryptionPort.CheckCreate</method> resolves with
/// overwrite 1 and skips its folder check -- the existing-name and missing-folder legs go red.</p>
Method TestACreateIsRefusedOnItsFieldWithNothingSent()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-e.key"), "a key file at the name")
    Set tPassword = $Parameter(tP, "PASSWORD")
    For tCase = $ListBuild("probe-e.key", "path:PATH.EXISTS", 256, "OcuProbe187Admin", tPassword), $ListBuild("missing/probe-m.key", "path:ENCRYPTION.KEYFILE.DIRECTORY", 256, "OcuProbe187Admin", tPassword), $ListBuild("", "path:PATH.MANAGER", 256, "OcuProbe187Admin", tPassword), $ListBuild("probe-k.key", "KeyLen:ENCRYPTION.KEYFILE.KEYLEN", 100, "OcuProbe187Admin", tPassword), $ListBuild("probe-n.key", "AdminName:ENCRYPTION.KEYFILE.ADMINNAME", 256, "", tPassword), $ListBuild("probe-p.key", "AdminPassword:ENCRYPTION.KEYFILE.PASSWORD", 256, "OcuProbe187Admin", ""), $ListBuild("probe-l.key", "AdminName:ENCRYPTION.KEYFILE.ADMINNAME", 256, "OcuProbe187" _ $Translate($Justify("", 40), " ", "L"), tPassword), $ListBuild("probe-q.key", "AdminPassword:ENCRYPTION.KEYFILE.PASSWORD", 256, "OcuProbe187Admin", "ab") {
        Set tPath = $Select($List(tCase, 1) = "": "ocuprobe187-direct.key", 1: $ClassMethod(tP, "RelativeName", $List(tCase, 1)))
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = $ClassMethod(..#SAVE, "Handle", {"root": ($ClassMethod(tP, "Root")), "path": (tPath), "AdminName": ($List(tCase, 4)), "AdminPassword": ($List(tCase, 5)), "KeyLen": ($List(tCase, 3)), "Description": "OCUPROBE187"}, .tAnswer, .tStatus, .tCache)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tAnswer), "422 " _ $List(tCase, 2), tPath _ " is refused on its field: " _ $Extract(tAnswer, 1, 200))
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with nothing sent")
        Set tAnswerObject = {}.%FromJSON(tAnswer)
        Set tReasons = 1
        Set tRowIterator = tAnswerObject.detail.violations.%GetIterator()
        While tRowIterator.%GetNext(.tRowIndex, .tRow) {
            If tRow.reason = "" Set tReasons = 0
        }
        Do $$$AssertTrue(tReasons, tPath _ ": every violation carries its sentence, so the form has text to show (QA)")
    }
    Do $$$AssertEquals(##class(%File).DirectoryExists($ClassMethod(tP, "Directory") _ "missing"), 0, "no folder was created")
    Do $$$AssertEquals($ClassMethod(tP, "Contents", "probe-e.key").%Get("keys").%Size(), 1, "and the existing file is unchanged")
    For tCase = $ListBuild("probe-e.key", "path:PATH.EXISTS", 256), $ListBuild("missing/probe-m.key", "path:ENCRYPTION.KEYFILE.DIRECTORY", 256), $ListBuild("probe-k.key", "KeyLen", 100) {
        Set tSC = $ClassMethod(tP, "Mint", ..#CREATETOOL, $List(tCase, 1), {"AdminName": "OcuProbe187Admin", "KeyLen": ($List(tCase, 3))}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ $List(tCase, 2)), "the agent's create of " _ $List(tCase, 1) _ " is refused naming " _ $List(tCase, 2) _ ": " _ tProblem)
    }
}

/// <p>A3: an administrator is added with the right existing credentials and removed again, on the
/// screen and by a confirmed proposal; each sends one write, the list shows the change, and the
/// read-backs are <code>written</code> and <code>notFound</code>.</p>
Method TestAnAdministratorIsAddedAndRemovedOnBothCallers()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-d.key"), "a key file")
    Set tId = $ClassMethod(tP, "KeyFileId", "probe-d.key")
    Set tRequest = {"action": "addadministrator", "id": (tId), "values": {"OldAdminName": ($Parameter(tP, "ADMIN")), "NewAdminName": "OcuProbe187Admin2", "OldAdminPassword": ($Parameter(tP, "PASSWORD")), "NewAdminPassword": "OcuProbe187-Pass2"}}
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#ADMINS, tRequest, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the screen's add answers 200: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "Security.Encryption.AdminInFile/POST", "sending one POST")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "KeysOf", "Security.Encryption.AdminInFile/POST"), "NewAdminName,NewAdminPassword,OldAdminName,OldAdminPassword", "carrying the port-built body")
    Do $$$AssertEquals($ClassMethod(tP, "Contents", "probe-d.key").%Get("admins").%ToJSON(), "[""OCUPROBE187ADMIN"",""OCUPROBE187ADMIN2""]", "the new name is listed")
    Do $$$AssertEquals(..Verdict(tAnswer), "written", "its read-back is written")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#ADMINS, {"action": "removeadministrator", "id": (tId), "values": {"Admin": "OCUPROBE187ADMIN2"}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the screen's remove answers 200: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "Security.Encryption.AdminInFile/DELETE", "sending one DELETE")
    Do $$$AssertEquals(..Verdict(tAnswer), "notFound", "its read-back finds the name gone")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(tP, "Mint", ..#ADDADMINTOOL, "probe-d.key", {"OldAdminName": ($Parameter(tP, "ADMIN")), "NewAdminName": "OcuProbe187Admin3"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's add is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($Select($IsObject(tProposal): ..Fields(tProposal), 1: ""), "OldAdminName,NewAdminName,OldAdminPassword,NewAdminPassword", "its card shows the names and asks for both passwords")
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, {"OldAdminPassword": ($Parameter(tP, "PASSWORD")), "NewAdminPassword": "OcuProbe187-Pass3"}, .tResult), "200 ", "and its confirm writes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "Security.Encryption.AdminInFile/POST", "one POST")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(tP, "Mint", ..#REMOVEADMINTOOL, "probe-d.key", {"Admin": "ocuprobe187admin3"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's remove is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($Select($IsObject(tProposal): tProposal.%Get("changed").%Get(0).%ToJSON(), 1: ""), "{""field"":""Admin"",""before"":""ocuprobe187admin3"",""after"":"""",""removed"":true}", "its card lists the name it removes")
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, "", .tResult), "200 ", "and its confirm writes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "Security.Encryption.AdminInFile/DELETE", "one DELETE")
    Do $$$AssertEquals($ClassMethod(tP, "Contents", "probe-d.key").%Get("admins").%ToJSON(), "[""OCUPROBE187ADMIN""]", "the file keeps its first administrator alone")
}

/// <p>A3: a name already listed, the last administrator and a name not listed are refused before
/// anything is sent, on both callers; a wrong existing password is the vendor's refusal, 422 on the
/// password, with the file unchanged; and a name removed since the mint closes the proposal.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.EncryptionKeyFileAddAdmin.StateRefusal</method>
/// answers <code>""</code> -- a POST is sent for the taken name and this goes red; and
/// <method>OcuPilot.Screen.Tool.EncryptionKeyFileRemoveAdmin.StateRefusal</method> skips the last-name
/// check -- a DELETE is sent and this goes red.</p>
Method TestAdministratorRefusalsSendNothingOrLeaveTheFileUnchanged()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-r.key"), "a key file")
    Set tId = $ClassMethod(tP, "KeyFileId", "probe-r.key")
    Set tAdd = {"action": "addadministrator", "id": (tId), "values": {"OldAdminName": ($Parameter(tP, "ADMIN")), "NewAdminName": "ocuprobe187admin", "OldAdminPassword": ($Parameter(tP, "PASSWORD")), "NewAdminPassword": "OcuProbe187-Pass9"}}
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#ADMINS, tAdd, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tAnswer), "400 TOOL.ARGUMENTS " _ $Parameter(..#ADDADMINTOOL, "REASONADMINTAKEN"), "a taken name is refused on the screen")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#ADMINS, {"action": "removeadministrator", "id": (tId), "values": {"Admin": "OCUPROBE187ADMIN"}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tAnswer), "400 TOOL.ARGUMENTS " _ $Parameter(..#REMOVEADMINTOOL, "REASONADMINLAST"), "the last administrator is refused on the screen")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#ADMINS, {"action": "removeadministrator", "id": (tId), "values": {"Admin": "OcuProbe187Nobody"}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tAnswer), "400 TOOL.ARGUMENTS " _ $Parameter(..#REMOVEADMINTOOL, "REASONADMINABSENT"), "a name not listed is refused on the screen")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with nothing sent")
    Set tSC = $ClassMethod(tP, "Mint", ..#ADDADMINTOOL, "probe-r.key", {"OldAdminName": ($Parameter(tP, "ADMIN")), "NewAdminName": "OCUPROBE187ADMIN"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject(tProposal) _ " " _ tProblem, "0 " _ $Parameter(..#ADDADMINTOOL, "REASONADMINTAKEN"), "the agent's taken name is refused at the mint")
    Set tSC = $ClassMethod(tP, "Mint", ..#REMOVEADMINTOOL, "probe-r.key", {"Admin": "OCUPROBE187ADMIN"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject(tProposal) _ " " _ tProblem, "0 " _ $Parameter(..#REMOVEADMINTOOL, "REASONADMINLAST"), "and the agent's last administrator")
    Set tWrong = {"action": "addadministrator", "id": (tId), "values": {"OldAdminName": ($Parameter(tP, "ADMIN")), "NewAdminName": "OcuProbe187Admin4", "OldAdminPassword": "OcuProbe187-Wrong", "NewAdminPassword": "OcuProbe187-Pass4"}}
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#ADMINS, tWrong, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tAnswer), "422 OldAdminPassword:ENCRYPTION.KEYFILE.CREDENTIALS", "a wrong password is the vendor's refusal on the password: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(tP, "Contents", "probe-r.key").%Get("admins").%ToJSON(), "[""OCUPROBE187ADMIN""]", "with the file unchanged")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tMessages = $ClassMethod(tP, "LineCount", "messages.log")
    Set tUnlisted = {"action": "addadministrator", "id": (tId), "values": {"OldAdminName": "OcuProbe187Nobody", "NewAdminName": "OcuProbe187Admin7", "OldAdminPassword": ($Parameter(tP, "PASSWORD")), "NewAdminPassword": "OcuProbe187-Pass7"}}
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#ADMINS, tUnlisted, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tAnswer), "422 OldAdminName:ENCRYPTION.KEYFILE.CREDENTIALS", "an existing name the file does not list is refused on the screen: " _ $Extract(tAnswer, 1, 200))
    Set tSC = $ClassMethod(tP, "Mint", ..#ADDADMINTOOL, "probe-r.key", {"OldAdminName": "OcuProbe187Nobody", "NewAdminName": "OcuProbe187Admin7"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's add naming it is minted (" _ tProblem _ ")")
    Set tConfirmed = $ClassMethod(tP, "Confirm", tProposal, {"OldAdminPassword": ($Parameter(tP, "PASSWORD")), "NewAdminPassword": "OcuProbe187-Pass7"}, .tResult)
    Do $$$AssertEquals(tConfirmed, "422 ENCRYPTION.KEYFILE.CREDENTIALS", "and at the confirm: " _ tConfirmed)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "each before any vendor write")
    Do $$$AssertEquals($ClassMethod(tP, "LinesAfter", "messages.log", tMessages).%Size(), 0, "logging no line")
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-s.key"), "a second key file")
    Do $$$AssertStatusOK(..AddAdminDirect("probe-s.key", "OcuProbe187Gone"), "with a second administrator")
    Set tSC = $ClassMethod(tP, "Mint", ..#REMOVEADMINTOOL, "probe-s.key", {"Admin": "OcuProbe187Gone"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's remove is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(tP, "RemoveFromFile", "probe-s.key", "", "OcuProbe187Gone"), "and the name is removed by another writer")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($Piece($ClassMethod(tP, "Confirm", tProposal, "", .tResult), " ", 1), 409, "the confirm closes the proposal as target-changed")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with nothing sent")
}

/// <p>The port's own answers to a write the state refuses, as any caller past the tools meets them: the
/// vendor's 409 for a taken name and for the last administrator is <code>TOOL.ARGUMENTS</code> with the
/// tools' sentence, logging no line, and its 404 for an absent administrator or key
/// <code>PORT.NOTFOUND</code>; the file is left unchanged.</p>
Method TestThePortMapsTheVendorsStateAnswers()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-v.key"), "a key file")
    Set tBefore = $ClassMethod(tP, "Contents", "probe-v.key").%ToJSON()
    Set tKeyFile = $ClassMethod(tP, "KeyFileId", "probe-v.key")
    Set tMessages = $ClassMethod(tP, "LineCount", "messages.log")
    Set tTaken = $ClassMethod(tP, "Run", "Security.Encryption.AdminInFile", "POST", {"keyfile": (tKeyFile), "OldAdminName": ($Parameter(tP, "ADMIN")), "NewAdminName": "ocuprobe187admin"}, {"OldAdminPassword": ($Parameter(tP, "PASSWORD")), "NewAdminPassword": "OcuProbe187-Pass8"}, "OcuPilot.Port.EncryptionPort")
    Do $$$AssertEquals(..Answer(tTaken), "400 TOOL.ARGUMENTS " _ $Parameter(..#ADDADMINTOOL, "REASONADMINTAKEN"), "a taken name")
    Set tLast = $ClassMethod(tP, "Run", "Security.Encryption.AdminInFile", "DELETE", {"keyfile": (tKeyFile), "Admin": "OCUPROBE187ADMIN"}, "", "OcuPilot.Port.EncryptionPort")
    Do $$$AssertEquals(..Answer(tLast), "400 TOOL.ARGUMENTS " _ $Parameter(..#REMOVEADMINTOOL, "REASONADMINLAST"), "the last administrator")
    Do $$$AssertEquals($ClassMethod(tP, "LinesAfter", "messages.log", tMessages).%Size(), 0, "with no line logged")
    Set tAbsent = $ClassMethod(tP, "Run", "Security.Encryption.AdminInFile", "DELETE", {"keyfile": (tKeyFile), "Admin": "OcuProbe187Nobody"}, "", "OcuPilot.Port.EncryptionPort")
    Do $$$AssertEquals(..Answer(tAbsent), "404 PORT.NOTFOUND", "an absent administrator")
    Set tNoKey = $ClassMethod(tP, "Run", "Security.Encryption.KeyInFile", "DELETE", {"keyfile": (tKeyFile), "KeyId": "OCUPROBE187-NO-SUCH-KEY"}, "", "OcuPilot.Port.EncryptionPort")
    Do $$$AssertEquals(..Answer(tNoKey), "404 PORT.NOTFOUND", "an absent key")
    Do $$$AssertEquals($ClassMethod(tP, "Contents", "probe-v.key").%ToJSON(), tBefore, "and the file unchanged")
}

/// <p>A <method>OcuPilot.Test.EncryptionProbe.Run</method> answer as <code>http code</code>, then
/// <code>detail.problem</code> when there is one.</p>
ClassMethod Answer(pRun As %DynamicObject) As %String
{
    If '$IsObject(pRun) Quit ""
    Set tFault = pRun.%Get("fault")
    If '$IsObject(tFault) Quit pRun.%Get("http")
    Set tText = pRun.%Get("http") _ " " _ tFault.%Get("code")
    If $IsObject(tFault.%Get("detail")) && (tFault.%Get("detail").%Get("problem") '= "") Set tText = tText _ " " _ tFault.%Get("detail").%Get("problem")
    Quit tText
}

/// <p>A4: a key is added and removed on the screen and by a confirmed proposal; each sends one write
/// with its consequence on the card, and a wrong password is refused on the password with the file
/// unchanged.</p>
Method TestAKeyIsAddedAndRemovedOnBothCallers()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-k.key", , , 256, "OCUPROBE187 K", .tFirst), "a key file")
    Set tId = $ClassMethod(tP, "KeyFileId", "probe-k.key")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#KEYS, {"action": "addkey", "id": (tId), "values": {"AdminName": ($Parameter(tP, "ADMIN")), "KeyLen": "128", "Description": "OCUPROBE187 ADDED", "AdminPassword": ($Parameter(tP, "PASSWORD"))}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the screen's add answers 200: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "Security.Encryption.KeyInFile/POST", "sending one POST")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "KeysOf", "Security.Encryption.KeyInFile/POST"), "AdminName,AdminPassword,Description,KeyLen", "carrying the port-built body")
    Set tKeys = $ClassMethod(tP, "Contents", "probe-k.key").%Get("keys")
    Do $$$AssertEquals(tKeys.%Size(), 2, "the file holds one more key")
    Set tAdded = ""
    Set tIterator = tKeys.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Description") = "OCUPROBE187 ADDED" Set tAdded = tRow.%Get("Id")
    }
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#KEYS, {"action": "removekey", "id": (tId), "values": {"KeyId": (tAdded)}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the screen's remove answers 200: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "Security.Encryption.KeyInFile/DELETE", "sending one DELETE")
    Do $$$AssertEquals(..Verdict(tAnswer), "notFound", "its read-back finds the key gone")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#KEYS, {"action": "addkey", "id": (tId), "values": {"AdminName": ($Parameter(tP, "ADMIN")), "KeyLen": "128", "Description": "OCUPROBE187 WRONG", "AdminPassword": "OcuProbe187-Wrong"}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tAnswer), "422 AdminPassword:ENCRYPTION.KEYFILE.CREDENTIALS", "a wrong password is refused on the password: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(tP, "Contents", "probe-k.key").%Get("keys").%Size(), 1, "with the file unchanged")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(tP, "Mint", ..#ADDKEYTOOL, "probe-k.key", {"AdminName": ($Parameter(tP, "ADMIN")), "KeyLen": 192, "Description": "OCUPROBE187 AGENT"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's add is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($Select($IsObject(tProposal): ..Fields(tProposal), 1: ""), "AdminName,KeyLen,Description,AdminPassword", "its card shows the arguments and asks for the password")
    Do $$$AssertEquals(..Consequence(tProposal), "ENCRYPTION.KEYFILE.NEWKEY", "with the new-key consequence")
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, {"AdminPassword": ($Parameter(tP, "PASSWORD"))}, .tResult), "200 ", "and its confirm writes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "Security.Encryption.KeyInFile/POST", "one POST")
    Set tSC = $ClassMethod(tP, "Mint", ..#REMOVEKEYTOOL, "probe-k.key", {"KeyId": (tFirst)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's remove is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Consequence(tProposal), "ENCRYPTION.KEYFILE.REMOVEKEY", "with the loss consequence")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, "", .tResult), "200 ", "and its confirm writes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "Security.Encryption.KeyInFile/DELETE", "one DELETE")
    Set tKeys = $ClassMethod(tP, "Contents", "probe-k.key").%Get("keys")
    Do $$$AssertEquals(tKeys.%Size() _ " " _ tKeys.%Get(0).%Get("KeyLen"), "1 192", "the agent's key alone remains")
    Set tSC = $ClassMethod(tP, "Mint", ..#REMOVEKEYTOOL, "probe-k.key", {"KeyId": (tFirst)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($IsObject(tProposal) _ " " _ tProblem, "0 " _ $Parameter(..#REMOVEKEYTOOL, "REASONKEYABSENT"), "a key not listed is refused at the mint")
}

/// <p>A4: a key removed by another writer since the mint closes the agent's removal as target-changed,
/// with nothing sent and the file's other key kept.</p>
/// <p>Mutation (Rule 19): drop <code>Keys</code> from
/// <parameter>OcuPilot.Screen.Tool.EncryptionKeyFileRemoveKey.FINGERPRINTSUBJECT</parameter> -- the confirm
/// no longer sees the change and this goes red.</p>
Method TestAKeyRemovedSinceTheMintClosesTheProposal()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-t.key", , , 256, "OCUPROBE187 T", .tKey), "a key file")
    Set tSecond = $ClassMethod(tP, "Run", "Security.Encryption.KeyInFile", "POST", {"keyfile": ($ClassMethod(tP, "KeyFileId", "probe-t.key")), "AdminName": ($Parameter(tP, "ADMIN")), "KeyLen": "128", "Description": "OCUPROBE187 T2"}, {"AdminPassword": ($Parameter(tP, "PASSWORD"))}, "OcuPilot.Port.EncryptionPort")
    Do $$$AssertEquals($ClassMethod(tP, "Contents", "probe-t.key").%Get("keys").%Size(), 2, "with a second key (" _ tSecond.%Get("http") _ ")")
    Set tSC = $ClassMethod(tP, "Mint", ..#REMOVEKEYTOOL, "probe-t.key", {"KeyId": (tKey)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's removal is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(tP, "RemoveFromFile", "probe-t.key", tKey), "and the key is removed by another writer")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($Piece($ClassMethod(tP, "Confirm", tProposal, "", .tResult), " ", 1), 409, "the confirm closes the proposal as target-changed")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with nothing sent")
    Do $$$AssertEquals($ClassMethod(tP, "Contents", "probe-t.key").%Get("keys").%Size(), 1, "and the other key kept")
}

/// <p>A4, AD-10: removing a key the instance depends on is refused <code>PROHIBITED.OCUPILOTKEY</code> on the
/// screen and at the confirm, with nothing sent, for each kind the seam can arm: OcuPilot's own database
/// encrypted with it, IRISSYS (one of the seven protected databases), the install namespace's globals
/// database, OcuPilot's own database encrypted with a key id that cannot be read, the journal's key, a
/// journal file the instance still needs for recovery (DW-2066), and each of the five reads that fails,
/// the journal's use of the key among them.</p>
/// <p>Mutation (Rule 19): drop the <code>KeyFile</code> arm from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -- every leg sends a DELETE and goes red;
/// drop <method>OcuPilot.Kernel.Proposal.Prohibited.DependsOnKey</method>'s journal comparison, compare a
/// row's key id alone in place of <code>RowNeedsKey</code>, or answer 0 on one of its failed reads -- that
/// mode's legs go red.</p>
Method TestAKeyTheInstanceDependsOnIsNotRemovedOnEitherCaller()
{
    Set tP = ..#PROBE
    Set ^||OcuPilotEncryptionProhibited = "OcuPilot.Test.EncryptionProhibited"
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.EncryptionProhibited")
    For tMode = "protected", "system", "namespace", "unreadable", "journal", "readfails", "namesfail", "dirsfail", "settingsfail", "journalfiles", "journalfails" {
        Set tFile = "probe-o-" _ tMode _ ".key"
        Do $ClassMethod(..#SEAM, "Clear")
        Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", tFile, , , 256, "OCUPROBE187 O", .tKey), tMode _ ": a key file")
        Do $ClassMethod(..#SEAM, "Arm", tMode, tKey)
        Set tSC = $ClassMethod(..#ACTION, "Act", ..#KEYS, {"action": "removekey", "id": ($ClassMethod(tP, "KeyFileId", tFile)), "values": {"KeyId": (tKey)}}, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tAnswer), "403 PROHIBITED.OCUPILOTKEY", tMode _ ": the screen's remove is refused: " _ $Extract(tAnswer, 1, 200))
        Set tSC = $ClassMethod(tP, "Mint", ..#REMOVEKEYTOOL, tFile, {"KeyId": (tKey)}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, tMode _ ": the agent's remove is minted (" _ tProblem _ ")")
        Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, "", .tResult), "403 PROHIBITED.OCUPILOTKEY", tMode _ ": and its confirm is refused")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", tMode _ ": with nothing sent")
        Do $$$AssertEquals($ClassMethod(tP, "Contents", tFile).%Get("keys").%Size(), 1, tMode _ ": and the key stays in the file")
    }
}

/// <p>A4, AD-10: a key that encrypts only a database that is none of OcuPilot's or the instance's own is
/// removed on the screen and at the confirm; the arm refuses only what the instance depends on.</p>
/// <p>Mutation (Rule 19): drop the own-database test from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.DependsOnKey</method> -- both removals are refused and this
/// goes red.</p>
Method TestAKeyAnotherDatabaseUsesIsRemoved()
{
    Set tP = ..#PROBE
    Set ^||OcuPilotEncryptionProhibited = "OcuPilot.Test.EncryptionProhibited"
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.EncryptionProhibited")
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-u.key", , , 256, "OCUPROBE187 U", .tFirst), "a key file")
    Set tId = $ClassMethod(tP, "KeyFileId", "probe-u.key")
    ; Two more keys, one for each caller to remove, so the file never reads as holding none (the
    ; vendor's list then fails and logs).
    For tDescription = "OCUPROBE187 U2", "OCUPROBE187 U3" {
        Do $ClassMethod(tP, "Run", "Security.Encryption.KeyInFile", "POST", {"keyfile": (tId), "AdminName": ($Parameter(tP, "ADMIN")), "KeyLen": "128", "Description": (tDescription)}, {"AdminPassword": ($Parameter(tP, "PASSWORD"))}, "OcuPilot.Port.EncryptionPort")
    }
    Kill tAdded
    Set tIterator = $ClassMethod(tP, "Contents", "probe-u.key").%Get("keys").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Description") '= "OCUPROBE187 U" Set tAdded($Select(tRow.%Get("Description") = "OCUPROBE187 U2": "screen", 1: "confirm")) = tRow.%Get("Id")
    }
    Do $$$AssertTrue(($Get(tAdded("screen")) '= "") && ($Get(tAdded("confirm")) '= ""), "with two more keys")
    For tLeg = "screen", "confirm" {
        Set tKey = $Get(tAdded(tLeg))
        Do $ClassMethod(..#SEAM, "Clear")
        Do $ClassMethod(..#SEAM, "Arm", "other", tKey)
        If tLeg = "screen" {
            Set tSC = $ClassMethod(..#ACTION, "Act", ..#KEYS, {"action": "removekey", "id": (tId), "values": {"KeyId": (tKey)}}, .tAnswer, .tStatus)
            Set tOutcome = tStatus
        } Else {
            Set tSC = $ClassMethod(tP, "Mint", ..#REMOVEKEYTOOL, "probe-u.key", {"KeyId": (tKey)}, .tProposal, .tHttp, .tProblem)
            Set tOutcome = $ClassMethod(tP, "Confirm", tProposal, "", .tResult)
        }
        Do $$$AssertNotEquals($ClassMethod(..#SEAM, "Armed"), "", tLeg _ ": the seam read another database as encrypted with the key")
        Do $$$AssertEquals($ZStrip(tOutcome, ">W") _ " " _ $ClassMethod(..#SEAM, "Writes"), "200 Security.Encryption.KeyInFile/DELETE", tLeg _ ": the removal is sent")
    }
    Do $$$AssertEquals($ClassMethod(tP, "Contents", "probe-u.key").%Get("keys").%Size(), 1, "and both keys left the file, its first kept")
}

/// <p>AD-35: writes carrying a marker in each password leave no trace of it in
/// <code>messages.log</code>, <code>alerts.log</code>, the ledger, the proposal row or any answer, a
/// refused one included.</p>
Method TestPasswordsReachNoLogLedgerProposalOrAnswer()
{
    Set tP = ..#PROBE
    Set tMarker = "OcuProbe187Mk" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(9), 1), "+/=", "")
    Set tMessages = $ClassMethod(tP, "LineCount", "messages.log")
    Set tAlerts = $ClassMethod(tP, "LineCount", "alerts.log")
    Set tAnswers = ""
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"root": ($ClassMethod(tP, "Root")), "path": ($ClassMethod(tP, "RelativeName", "probe-m.key")), "AdminName": ($Parameter(tP, "ADMIN")), "AdminPassword": (tMarker _ "A"), "KeyLen": 256, "Description": "OCUPROBE187 M"}, .tAnswer, .tStatus, .tCache)
    Do $$$AssertEquals(tStatus, 201, "the Save creates the file")
    Set tAnswers = tAnswers _ tAnswer
    Set tId = $ClassMethod(tP, "KeyFileId", "probe-m.key")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#ADMINS, {"action": "addadministrator", "id": (tId), "values": {"OldAdminName": ($Parameter(tP, "ADMIN")), "NewAdminName": "OcuProbe187Admin5", "OldAdminPassword": (tMarker _ "A"), "NewAdminPassword": (tMarker _ "B")}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the screen adds an administrator")
    Set tAnswers = tAnswers _ tAnswer
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#KEYS, {"action": "addkey", "id": (tId), "values": {"AdminName": ($Parameter(tP, "ADMIN")), "KeyLen": "128", "Description": "OCUPROBE187 MK", "AdminPassword": (tMarker _ "Z")}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 422, "a wrong password is refused")
    Set tAnswers = tAnswers _ tAnswer
    Set tSC = $ClassMethod(tP, "Mint", ..#ADDKEYTOOL, "probe-m.key", {"AdminName": ($Parameter(tP, "ADMIN")), "KeyLen": 128, "Description": "OCUPROBE187 MA"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's add is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, {"AdminPassword": (tMarker _ "A")}, .tResult), "200 ", "and confirmed with the marker")
    Set tAnswers = tAnswers _ $Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "")
    Do $$$AssertTrue(tAnswers '[ tMarker, "no answer carries the marker")
    Set tLines = $ClassMethod(tP, "LinesAfter", "messages.log", tMessages).%ToJSON() _ $ClassMethod(tP, "LinesAfter", "alerts.log", tAlerts).%ToJSON()
    Do $$$AssertTrue(tLines '[ tMarker, "messages.log and alerts.log carry no marker")
    Set tStored = ..StoredText(tProposal.%Get("proposalId"))
    Do $$$AssertTrue(tStored '= "", "the proposal row and its ledger rows are read")
    Do $$$AssertTrue(tStored '[ tMarker, "and neither carries the marker")
}

/// <p>AD-59: the script of a minted create, administrator add and removal, key add and key removal each
/// renders one <code>rest</code> step to the vendor's route, with the resolved key file and each password
/// as its placeholder, and no password; the removal names its administrator under the vendor's
/// <code>admin</code> query key.</p>
/// <p>Mutation (Rule 19): drop <code>AdminPassword</code> from
/// <method>OcuPilot.Port.EncryptionPort.Snippet</method>'s <code>File</code> <code>POST</code> body -- the
/// create's leg goes red.</p>
Method TestTheScriptRendersTheResolvedFileAndPasswordPlaceholders()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-x.key", , , 256, "OCUPROBE187 X", .tKey), "a key file")
    Do $$$AssertStatusOK(..AddAdminDirect("probe-x.key", "OcuProbe187Gone"), "with a second administrator")
    Set tEncoded = $ZConvert($ClassMethod(tP, "FilePath", "probe-x.key"), "O", "URL")
    ; Each case's arguments travel as JSON text: a $List does not keep an object.
    For tCase = $ListBuild(..#CREATETOOL, "probe-xn.key", {"AdminName": ($Parameter(tP, "ADMIN")), "KeyLen": 256, "Description": "OCUPROBE187 XN"}.%ToJSON(), "/security/encryption/file", $ClassMethod(tP, "FilePath", "probe-xn.key"), "<AdminPassword>"), $ListBuild(..#ADDADMINTOOL, "probe-x.key", {"OldAdminName": ($Parameter(tP, "ADMIN")), "NewAdminName": "OcuProbe187Admin6"}.%ToJSON(), "/security/encryption/file/admin", tEncoded, "<OldAdminPassword>,<NewAdminPassword>"), $ListBuild(..#ADDKEYTOOL, "probe-x.key", {"AdminName": ($Parameter(tP, "ADMIN")), "KeyLen": 128, "Description": "OCUPROBE187 XK"}.%ToJSON(), "/security/encryption/file/key", tEncoded, "<AdminPassword>"), $ListBuild(..#REMOVEKEYTOOL, "probe-x.key", {"KeyId": (tKey)}.%ToJSON(), "/security/encryption/file/key", tEncoded, ""), $ListBuild(..#REMOVEADMINTOOL, "probe-x.key", {"Admin": "OcuProbe187Gone"}.%ToJSON(), "/security/encryption/file/admin?admin=OcuProbe187Gone&", tEncoded, "") {
        Set tTool = $Piece($List(tCase, 1), ".", $Length($List(tCase, 1), "."))
        Set tSC = $ClassMethod(tP, "Mint", $List(tCase, 1), $List(tCase, 2), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, tTool _ ": minted (" _ tProblem _ ")")
        Kill tDraft
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Draft).Take($Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: ""), $Username, "https://probe.example", .tDraft, .tHttp, .tCode)
        Do $$$AssertStatusOK(tSC, tTool _ ": the script is taken (" _ $Get(tCode) _ ")")
        Set tText = $Select($IsObject($Get(tDraft)): tDraft.%ToJSON(), 1: "")
        Set tSteps = []
        If $IsObject($Get(tDraft)) && (tDraft.%GetTypeOf("draft") = "object") && (tDraft.%Get("draft").%GetTypeOf("steps") = "array") Set tSteps = tDraft.%Get("draft").%Get("steps")
        Do $$$AssertEquals(tSteps.%Size() _ " " _ $Select(tSteps.%Size() > 0: tSteps.%Get(0).%Get("kind"), 1: ""), "1 rest", tTool _ ": one rest step: " _ $Extract(tText, 1, 300))
        Do $$$AssertTrue(tText [ $List(tCase, 4), tTool _ ": addressed to the vendor's route")
        Do $$$AssertTrue(tText [ $List(tCase, 5), tTool _ ": with the resolved key file")
        For tI = 1:1:$Length($List(tCase, 6), ",") {
            Set tPlaceholder = $Piece($List(tCase, 6), ",", tI)
            If tPlaceholder '= "" Do $$$AssertTrue(tText [ tPlaceholder, tTool _ ": and " _ tPlaceholder _ " as its placeholder")
        }
        Do $$$AssertTrue(tText '[ $Parameter(tP, "PASSWORD"), tTool _ ": and no password")
    }
}

/// <p>Add administrator <var>pName</var> to probe file <var>pFile</var> through the vendor's own routine
/// in <code>%SYS</code> (test-only seeding).</p>
ClassMethod AddAdminDirect(pFile As %String, pName As %String) As %Status
{
    Set tSC = $$$OK
    Set tPath = ##class(OcuPilot.Test.EncryptionProbe).FilePath(pFile)
    Set tAdmin = ##class(OcuPilot.Test.EncryptionProbe).#ADMIN
    Set tPassword = ##class(OcuPilot.Test.EncryptionProbe).#PASSWORD
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $$AdminAdd^EncryptionKey(tPath, tAdmin, tPassword, pName, "OcuProbe187-Other")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The proposal's diff field names, comma-joined.</p>
ClassMethod Fields(pProposal As %DynamicObject) As %String
{
    Set tOut = ""
    Set tIterator = pProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tRow.%Get("field")
    }
    Quit tOut
}

/// <p>The read-back verdict an action's answer carries.</p>
ClassMethod Verdict(pAnswer As %String) As %String
{
    Set tObject = ##class(OcuPilot.Test.EncryptionProbe).Parsed(pAnswer)
    If '$IsObject(tObject) Quit ""
    If tObject.%GetTypeOf("readBack") = "object" Quit tObject.%Get("readBack").%Get("verdict")
    If (tObject.%GetTypeOf("result") = "object") && (tObject.%Get("result").%GetTypeOf("readBack") = "object") Quit tObject.%Get("result").%Get("readBack").%Get("verdict")
    Quit ""
}

/// <p>The stored consequence of the proposal <var>pProposal</var>.</p>
ClassMethod Consequence(pProposal As %DynamicObject) As %String
{
    If '$IsObject(pProposal) Quit ""
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposal.%Get("proposalId"), .tFound, .tValues)
    Quit $Get(tValues("consequence"))
}

/// <p>Every value of the stored proposal row and its turn's ledger rows' target, arguments and field
/// names, as one string.</p>
ClassMethod StoredText(pProposalId As %String) As %String
{
    Set tOut = ""
    Try {
        Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposalId, .tFound, .tValues)
        If '$Get(tFound) Quit
        Set tNode = ""
        For {
            Set tNode = $Order(tValues(tNode), 1, tValue)
            If tNode = "" Quit
            Set tOut = tOut _ "|" _ tValue
        }
        Set tLedger = ##class(%SQL.Statement).%ExecDirect(, "SELECT Target, Arguments, Fields FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", $Get(tValues("turnKey")))
        While tLedger.%Next() {
            Set tOut = tOut _ "|" _ tLedger.%Get("Target") _ "|" _ tLedger.%Get("Arguments") _ "|" _ tLedger.%Get("Fields")
        }
    } Catch ex {
        Set tOut = ""
    }
    Quit tOut
}

}
