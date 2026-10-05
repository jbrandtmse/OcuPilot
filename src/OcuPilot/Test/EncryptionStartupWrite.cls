/// <p>Pins Story 18.23's write on both callers (C3 to C7; AD-4, AD-10, AD-26, AD-53, AD-55): the form's Save
/// (<class>OcuPilot.Test.EncryptionStartupSaveFixture</class>) and the agent's mint and confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>). Each change sends one <code>Settings</code>
/// <code>PUT</code> with the body the vendor requires; <code>AuditEncrypt</code> is read at the write unless
/// the change sets it, and a change that sets it is destructive and refused once the value it reviewed
/// moves; every rule, the Interactive arm in both orders and while a database is still encrypted on disk,
/// and the version gate refuse with no <code>PUT</code>; the vendor's refusals arrive in OcuPilot's
/// sentences; and the password reaches no record.</p>
/// <p><b>No test changes a real startup setting.</b> Every value change runs through
/// <class>OcuPilot.Test.EncryptionSeamPort</class> armed <code>startup</code>, <code>startupfails</code>,
/// <code>kmip</code> or <code>settingsv1</code>, which never sends a settings <code>PUT</code>, and AD-10's
/// set reads the seam's settings (<class>OcuPilot.Test.EncryptionStartupProhibited</class>). The one real
/// <code>PUT</code> sends the instance's own settings unchanged, and the facts are read again after it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates key files and sets
/// the governance policy. Every probe object is removed after each test, and after each test the
/// instance's encryption state and the audit database's identity read as that test found them.</p>
Class OcuPilot.Test.EncryptionStartupWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ENCRYPTION_CONFIG";

Parameter PROBE = "OcuPilot.Test.EncryptionStartupProbe";

Parameter SEAM = "OcuPilot.Test.EncryptionSeamPort";

Parameter SAVE = "OcuPilot.Test.EncryptionStartupSaveFixture";

Parameter SEAMTOOL = "OcuPilot.Test.SeamEncryptionStartupUpdate";

Parameter PUT = "Security.Encryption.Settings/PUT";

Parameter GOVERNANCEKEY = "security.encryptionstartup.update";

/// <p>The two seam-active keys.</p>
Parameter KEYONE = "0CC1C7E0-C0D0-11F1-8A00-0242AC110001";

Parameter KEYTWO = "0CC1C7E0-C0D0-11F1-8A00-0242AC110002";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The encryption facts and the audit database's identity before each test.</p>
Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EncryptionStartupWrite creates encryption key files on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = ..Facts()
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.EncryptionStartupProhibited")
    Kill tSettings
    Set tSettings(..#GOVERNANCEKEY) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "SeedDirectory", .tCreated)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Do $ClassMethod(..#SEAM, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "the probe directory and every probe object are removed")
    Set tFacts = ..Facts()
    Do $$$AssertTrue((tFacts '[ """error"":") && (..PreparedFacts '[ """error"":"), "the facts were read whole before and after the test")
    Do $$$AssertEquals(tFacts, ..PreparedFacts, "no encryption setting moved and the audit database is the one the test found")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>C3, C2: Interactive, Unattended with a new key file, and KMIP with a configured server, each by the
/// Save and by a confirmed proposal, send one <code>PUT</code> each with the seven settings the vendor
/// requires and <code>AuditEncrypt</code> as held; only the new key file's legs carry the administrator and
/// password; each read-back matches and each card names its mode's consequence.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.EncryptionPort.StartupBody</method> sends the credentials for
/// every Unattended write -- the stored-file leg goes red.</p>
Method TestAStartModeChangeIsOnePutOnBothCallers()
{
    Set tP = ..#PROBE
    Set tPassword = $ClassMethod(tP, "NewPassword")
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "start-w.key", $Parameter(tP, "ADMIN"), tPassword, 256, "OCUPROBESTART W", .tKey), "a probe key file")
    Set tSeven = "AuditEncrypt,DBEncIRISSecurity,DBEncIRISTemp,DBEncJournal,DBEncStartKMIPServer,DBEncStartKeyFile,DBEncStartMode"
    Do $ClassMethod(..#SEAM, "Arm", "kmip")
    Do $ClassMethod(..#SEAM, "ArmKmip", "OCUPROBESTARTKMS")
    Set tFile = $ClassMethod(tP, "FilePath", "start-w.key")
    Set tNewFile = {"root": ($ClassMethod(tP, "Root")), "path": ($ClassMethod(tP, "RelativeName", "start-w.key")), "AdminName": ($Parameter(tP, "ADMIN"))}
    For tCaller = "save", "agent" {
        For tCase = $ListBuild("Interactive", "{}", tSeven, "", "ENCRYPTION.STARTUP.INTERACTIVE"), $ListBuild("Unattended", tNewFile.%ToJSON(), "AdminName,AdminPassword," _ tSeven, tFile, "ENCRYPTION.STARTUP.UNATTENDED"), $ListBuild("KMIP", {"DBEncStartKMIPServer": "OCUPROBESTARTKMS"}.%ToJSON(), tSeven, "", "ENCRYPTION.STARTUP.KMIP") {
            Set tMode = $List(tCase, 1)
            Do ..Hold({"DBEncStartMode": "None", "AuditEncrypt": false})
            Do $ClassMethod(..#SEAM, "ClearCalls")
            Set tArgs = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
            Do tArgs.%Set("DBEncStartMode", tMode, "string")
            If tCaller = "save" {
                If tMode = "Unattended" Do tArgs.%Set("AdminPassword", tPassword, "string")
                Set tOutcome = ..Save(tArgs, .tAnswer)
                Do $$$AssertEquals(tOutcome, "200 ", tMode _ " by the Save writes: " _ $Extract(tAnswer, 1, 200))
                Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyWrite).ReadBack(tAnswer), $Select(tMode = "Unattended": "matches [""AdminName"",""AdminPassword""]", 1: "matches"), tMode _ ": its read-back matches")
                Do $$$AssertEquals(..Parsed(tAnswer, "consequence"), $List(tCase, 5), tMode _ ": the Save answers the mode's consequence")
            } Else {
                Set tOutcome = ..Propose(tArgs, .tProposal)
                Do $$$AssertEquals(tOutcome, "", tMode _ " is minted")
                Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyWrite).Stored(tProposal, "consequence") _ " " _ ##class(OcuPilot.Test.EncryptionKeyWrite).Stored(tProposal, "destructive"), $List(tCase, 5) _ " 0", tMode _ ": the card names the mode's consequence, not destructive")
                Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyWrite).Stored(tProposal, "payload") [ """AdminPassword"":""""", (tMode = "Unattended"), tMode _ ": the card asks for a password only for a new key file")
                Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, $Select(tMode = "Unattended": {"AdminPassword": (tPassword)}, 1: ""), .tResult), "200 ", tMode _ " is confirmed")
                Do $$$AssertEquals($Select($IsObject($Get(tResult)) && $IsObject(tResult.%Get("readBack")): tResult.%Get("readBack").%Get("verdict"), 1: ""), "matches", tMode _ ": its read-back matches")
            }
            Do $$$AssertEquals(..Puts(), 1, tCaller _ " " _ tMode _ ": one PUT")
            Do $$$AssertEquals($ClassMethod(..#SEAM, "KeysOf", ..#PUT), $List(tCase, 3), tCaller _ " " _ tMode _ ": the vendor's seven settings" _ $Select(tMode = "Unattended": " and the new file's credentials", 1: ""))
            Do $$$AssertEquals($ClassMethod(..#SEAM, "SentOf", "DBEncStartMode") _ " " _ $ClassMethod(..#SEAM, "SentOf", "AuditEncrypt") _ " " _ $ClassMethod(..#SEAM, "SentOf", "DBEncStartKeyFile"), tMode _ " false " _ $List(tCase, 4), tCaller _ " " _ tMode _ ": the mode, AuditEncrypt as held, and the key file the port composed")
        }
    }
    Do ..Hold({"DBEncStartMode": "Unattended", "DBEncStartKeyFile": (tFile)})
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Do $$$AssertEquals(..Save({"DBEncJournalKeyID": "", "DBEncStartMode": "Unattended"}, .tAnswer), "200 ", "a Save restating the settings answers")
    Do $$$AssertEquals(..Puts(), 0, "and sends nothing")
    Do $$$AssertEquals(..Save({"DBEncStartKMIPServer": "OCUPROBESTARTKMS"}, .tAnswer), "200 ", "a change under the stored key file writes")
    Do $$$AssertEquals(..Puts() _ " " _ $ClassMethod(..#SEAM, "KeysOf", ..#PUT) _ " " _ $ClassMethod(..#SEAM, "SentOf", "DBEncStartKeyFile"), "1 " _ tSeven _ " " _ tFile, "one PUT keeping the stored key file, with no credential")
}

/// <p>Matrix rows 3 and 4: IRISSECURITY and IRISTEMP turned on under Unattended and journal encryption under
/// Interactive (Decision 8 leaves Interactive open to the journal alone), each with a seam-active key, and the
/// default and journal key moved between two seam-active keys, each send one <code>PUT</code>, a key id only
/// when it changed, and name their consequence.</p>
/// <p>Mutation (Rule 19): keep an unchanged key id in both
/// <method>OcuPilot.Screen.Tool.EncryptionStartupUpdate.MergeUpdate</method> and
/// <method>OcuPilot.Port.EncryptionPort.StartupBody</method> -- the key id legs go red; either alone is
/// caught by the other.</p>
Method TestFlagsAndKeyIdsChangeOnBothCallers()
{
    Do $ClassMethod(..#SEAM, "Arm", "startup")
    Do $ClassMethod(..#SEAM, "Hold", "database", [{"Id": (..#KEYONE), "KeyLen": 256, "IsDefault": true}, {"Id": (..#KEYTWO), "KeyLen": 256, "IsDefault": false}])
    Set tHeld = {"DBEncStartMode": "Unattended", "DBEncStartKeyFile": "/ocuprobestart/held.key", "DBEncDefaultKeyID": (..#KEYONE), "DBEncJournalKeyID": (..#KEYONE)}
    For tCase = $ListBuild("save", "DBEncIRISSecurity", "ENCRYPTION.STARTUP.RESTART"), $ListBuild("agent", "DBEncIRISTemp", "ENCRYPTION.STARTUP.RESTART"), $ListBuild("save", "DBEncJournal", "ENCRYPTION.STARTUP.JOURNAL"), $ListBuild("agent", "DBEncJournal", "ENCRYPTION.STARTUP.JOURNAL") {
        Set tField = $List(tCase, 2)
        Set tHeldNow = ##class(%DynamicObject).%FromJSON(tHeld.%ToJSON())
        If tField = "DBEncJournal" Do tHeldNow.%Set("DBEncStartMode", "Interactive", "string"), tHeldNow.%Set("DBEncStartKeyFile", "", "string")
        Do ..Hold(tHeldNow)
        Do $ClassMethod(..#SEAM, "ClearCalls")
        Set tArgs = {}
        Do tArgs.%Set(tField, 1, "boolean")
        Do $$$AssertEquals(..Change($List(tCase, 1), tArgs, .tConsequence), "200 ", $List(tCase, 1) _ " turns " _ tField _ " on")
        Do $$$AssertEquals(..Puts() _ " " _ $ClassMethod(..#SEAM, "SentOf", tField) _ " " _ tConsequence, "1 true " _ $List(tCase, 3), $List(tCase, 1) _ " " _ tField _ ": one PUT carrying it, and its consequence")
    }
    For tCase = $ListBuild("save", "DBEncDefaultKeyID", "DBEncJournalKeyID"), $ListBuild("agent", "DBEncJournalKeyID", "DBEncDefaultKeyID") {
        Do ..Hold(tHeld)
        Do $ClassMethod(..#SEAM, "ClearCalls")
        Set tArgs = {}
        Do tArgs.%Set($List(tCase, 2), ..#KEYTWO, "string")
        Do $$$AssertEquals(..Change($List(tCase, 1), tArgs, .tConsequence), "200 ", $List(tCase, 1) _ " moves " _ $List(tCase, 2))
        Set tKeys = $ClassMethod(..#SEAM, "KeysOf", ..#PUT)
        Do $$$AssertEquals(..Puts() _ " " _ $ClassMethod(..#SEAM, "SentOf", $List(tCase, 2)) _ " " _ (tKeys [ $List(tCase, 3)), "1 " _ ..#KEYTWO _ " 0", $List(tCase, 1) _ ": one PUT carrying the changed id and not the other")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "HeldSettings").%Get($List(tCase, 2)), ..#KEYTWO, $List(tCase, 1) _ ": the seam holds the new id")
    }
}

/// <p>C4: a change to the audit log's encryption is minted destructive with the audit consequence and
/// confirmed with one <code>PUT</code> carrying it; a second proposal's confirm, once another writer has moved
/// the value it reviewed, is refused target-changed with no <code>PUT</code>; and the Save changes it with the
/// tool's key disabled, because the Save is not governed.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method>'s
/// <code>AUDIT.ENCRYPTIONCHANGE</code> branch -- the destructive legs go red.</p>
Method TestAuditEncryptionIsDestructiveAndConfirmsTheReviewedValue()
{
    Set tP = ..#PROBE
    Do $ClassMethod(..#SEAM, "Arm", "startup")
    Do $ClassMethod(..#SEAM, "Hold", "database", [{"Id": (..#KEYONE), "KeyLen": 256, "IsDefault": true}])
    Do ..Hold({"DBEncStartMode": "Unattended", "DBEncStartKeyFile": "/ocuprobestart/held.key", "AuditEncrypt": false})
    Do $$$AssertEquals(..Propose({"AuditEncrypt": true}, .tProposal), "", "the audit change is minted")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyWrite).Stored(tProposal, "consequence") _ " " _ ##class(OcuPilot.Test.EncryptionKeyWrite).Stored(tProposal, "destructive"), "AUDIT.ENCRYPTIONCHANGE 1", "destructive, with the audit consequence")
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, "", .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals(..Puts() _ " " _ $ClassMethod(..#SEAM, "SentOf", "AuditEncrypt"), "1 true", "with one PUT carrying the change")
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Do $$$AssertEquals(..Propose({"AuditEncrypt": false}, .tProposal), "", "turning it off is minted")
    Do $ClassMethod(..#SEAM, "SetHeld", "AuditEncrypt", 0)
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, "", .tResult), "409 " _ $Parameter("OcuPilot.Kernel.Proposal.Write", "TARGETCHANGED"), "once another writer moved the reviewed value, the confirm is refused")
    Do $$$AssertEquals(..Puts(), 0, "with no PUT")
    Kill tSettings
    Set tSettings(..#GOVERNANCEKEY) = "disabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the tool's key is disabled")
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Do $$$AssertEquals(..Save({"AuditEncrypt": true}, .tAnswer), "200 ", "the Save changes the audit log's encryption all the same: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals(..Puts() _ " " _ $ClassMethod(..#SEAM, "SentOf", "AuditEncrypt") _ " " _ ..Parsed(tAnswer, "consequence"), "1 true AUDIT.ENCRYPTIONCHANGE", "one PUT, naming the audit consequence")
}

/// <p>C3, Decision 1: a start-mode proposal's payload carries no <code>AuditEncrypt</code>, so its confirm
/// sends the value another writer set after the mint.</p>
/// <p>Mutation (Rule 19): keep the fresh read's <code>AuditEncrypt</code> in
/// <method>OcuPilot.Screen.Tool.EncryptionStartupUpdate.MergeUpdate</method> -- the confirm is refused
/// target-changed and this goes red.</p>
Method TestTheWriteReadsAuditEncryptionAtTheWrite()
{
    Set tP = ..#PROBE
    Do $ClassMethod(..#SEAM, "Arm", "kmip")
    Do $ClassMethod(..#SEAM, "ArmKmip", "OCUPROBESTARTKMS")
    Do $ClassMethod(..#SEAM, "Hold", "database", [{"Id": (..#KEYONE), "KeyLen": 256, "IsDefault": true}])
    Do ..Hold({"DBEncStartMode": "Unattended", "DBEncStartKeyFile": "/ocuprobestart/held.key", "AuditEncrypt": false})
    Do $$$AssertEquals(..Propose({"DBEncStartMode": "KMIP", "DBEncStartKMIPServer": "OCUPROBESTARTKMS"}, .tProposal), "", "a mode change is minted")
    Do $$$AssertTrue(##class(OcuPilot.Test.EncryptionKeyWrite).Stored(tProposal, "payload") '[ "AuditEncrypt", "its payload carries no AuditEncrypt")
    Do $ClassMethod(..#SEAM, "SetHeld", "AuditEncrypt", 1)
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, "", .tResult), "200 ", "another writer's change does not move the reviewed payload")
    Do $$$AssertEquals(..Puts() _ " " _ $ClassMethod(..#SEAM, "SentOf", "AuditEncrypt") _ " " _ $ClassMethod(..#SEAM, "SentOf", "DBEncStartMode"), "1 true KMIP", "the PUT sends AuditEncrypt as read at the write")
}

/// <p>C5: every rule refuses on its field with no <code>PUT</code>, on the Save and at the mint.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Port.EncryptionPort.StartupProblems</method>'s active-key check
/// -- the no-key legs send a PUT and go red.</p>
Method TestARefusedChangeSendsNothing()
{
    Set tP = ..#PROBE
    Set tPassword = $ClassMethod(tP, "NewPassword")
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "start-r.key", $Parameter(tP, "ADMIN"), tPassword, 256, "OCUPROBESTART R", .tKey), "a probe key file")
    Do $ClassMethod(..#SEAM, "Arm", "startup")
    Set tRoot = $ClassMethod(tP, "Root")
    Set tPath = $ClassMethod(tP, "RelativeName", "start-r.key")
    Set tNone = {"DBEncStartMode": "None"}.%ToJSON()
    Set tStored = {"DBEncStartMode": "Unattended", "DBEncStartKeyFile": "/ocuprobestart/held.key"}.%ToJSON()
    For tCase = $ListBuild(tNone, {"DBEncStartMode": "KMIP", "DBEncStartKMIPServer": "nowhere"}.%ToJSON(), "DBEncStartKMIPServer:ENCRYPTION.STARTUP.KMIPSERVER", 1), $ListBuild(tNone, {"DBEncStartMode": "Unattended"}.%ToJSON(), "path:ENCRYPTION.STARTUP.KEYFILE", 1), $ListBuild(tNone, {"DBEncStartMode": "Unattended", "root": (tRoot), "path": (tPath), "AdminName": ($Parameter(tP, "ADMIN"))}.%ToJSON(), "AdminPassword:ENCRYPTION.KEYFILE.PASSWORD", 0), $ListBuild(tNone, {"DBEncStartMode": "Unattended", "root": (tRoot), "path": (tPath), "AdminName": "OcuProbeStartNobody", "AdminPassword": (tPassword)}.%ToJSON(), "AdminName:ENCRYPTION.KEYFILE.CREDENTIALS", 1), $ListBuild(tNone, {"DBEncJournal": true}.%ToJSON(), "DBEncJournal:ENCRYPTION.STARTUP.NEEDSSTART", 1), $ListBuild(tStored, {"DBEncIRISTemp": true}.%ToJSON(), "DBEncIRISTemp:ENCRYPTION.STARTUP.NOKEY", 1), $ListBuild(tStored, {"AuditEncrypt": true}.%ToJSON(), "AuditEncrypt:ENCRYPTION.STARTUP.NOKEY", 1), $ListBuild(tStored, {"DBEncDefaultKeyID": "OCUPROBESTART-NOKEY"}.%ToJSON(), "DBEncDefaultKeyID:ENCRYPTION.STARTUP.KEYINACTIVE", 1) {
        Do ..Hold(##class(%DynamicObject).%FromJSON($List(tCase, 1)))
        Do $ClassMethod(..#SEAM, "ClearCalls")
        Set tBody = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Do $$$AssertEquals(..Save(tBody, .tAnswer), "422 " _ $List(tCase, 3), tBody.%ToJSON() _ " is refused on the Save")
        If $List(tCase, 4) {
            Set tArgs = ##class(%DynamicObject).%FromJSON(tBody.%ToJSON())
            Do tArgs.%Remove("AdminPassword")
            Do $$$AssertEquals(..Propose(tArgs, .tProposal), "422 " _ $List(tCase, 3), tBody.%ToJSON() _ " is refused at the mint")
        }
        Do $$$AssertEquals(..Puts(), 0, tBody.%ToJSON() _ ": no PUT")
    }
}

/// <p>C5, AD-10, Decision 8: Interactive is refused while the audit log, IRISSECURITY or IRISTEMP is
/// encrypted, also by a write that turns it off as it chooses Interactive, and each is refused while the mode
/// is Interactive, on the Save and at the confirm, each with the refusal's sentence and no <code>PUT</code>.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Kernel.Proposal.Prohibited.EncryptionStartup</method>'s
/// Interactive check -- every leg goes red; judge it only when the mode changes -- the "under Interactive"
/// legs alone; only when it does not -- the "Interactive while" legs alone; drop the target's flags from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.LeavesInteractiveRequired</method> -- the "same write" legs
/// alone; let the Save ignore the verdict -- the Save legs alone; let the confirm ignore it -- the confirm
/// legs alone.</p>
Method TestInteractiveIsRefusedInBothOrdersOnBothCallers()
{
    Set tP = ..#PROBE
    Do $ClassMethod(..#SEAM, "Arm", "startup")
    Do $ClassMethod(..#SEAM, "Hold", "database", [{"Id": (..#KEYONE), "KeyLen": 256, "IsDefault": true}])
    Set tCode = "PROHIBITED.STARTUPINTERACTIVE"
    For tFlag = "AuditEncrypt", "DBEncIRISSecurity", "DBEncIRISTemp" {
        Set tEncrypted = {"DBEncStartMode": "Unattended", "DBEncStartKeyFile": "/ocuprobestart/held.key"}
        Do tEncrypted.%Set(tFlag, 1, "boolean")
        Set tFlagOn = {}
        Do tFlagOn.%Set(tFlag, 1, "boolean")
        Set tTogether = {"DBEncStartMode": "Interactive"}
        Do tTogether.%Set(tFlag, 0, "boolean")
        For tOrder = $ListBuild(tEncrypted.%ToJSON(), "{""DBEncStartMode"":""Interactive""}", "Interactive while " _ tFlag _ " is encrypted"), $ListBuild("{""DBEncStartMode"":""Interactive""}", tFlagOn.%ToJSON(), tFlag _ " under Interactive"), $ListBuild(tEncrypted.%ToJSON(), tTogether.%ToJSON(), "Interactive with " _ tFlag _ " turned off in the same write") {
            Do ..Hold(##class(%DynamicObject).%FromJSON($List(tOrder, 1)))
            Do $ClassMethod(..#SEAM, "ClearCalls")
            Set tChange = ##class(%DynamicObject).%FromJSON($List(tOrder, 2))
            Set tOutcome = ..Save(tChange, .tAnswer)
            Do $$$AssertEquals(tOutcome, "403 " _ tCode, $List(tOrder, 3) _ " is refused on the Save")
            Do $$$AssertEquals(..Parsed(tAnswer, "reason"), $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "STARTUPINTERACTIVEREASON"), "with its sentence")
            Do $$$AssertEquals(..Puts(), 0, $List(tOrder, 3) _ ": no PUT from the Save")
            Do ..Hold(##class(%DynamicObject).%FromJSON($List(tOrder, 1)))
            Do $ClassMethod(..#SEAM, "ClearCalls")
            Do $$$AssertEquals(..Propose(tChange, .tProposal), "", $List(tOrder, 3) _ " is minted")
            Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, "", .tResult), "403 " _ tCode, $List(tOrder, 3) _ " is refused at the confirm")
            Do $$$AssertEquals(..Puts(), 0, $List(tOrder, 3) _ ": no PUT from the confirm")
        }
    }
}

/// <p>C5, AD-10, AD-27: with every flag off, Interactive is refused while the audit log's, IRISSECURITY's or
/// IRISTEMP's database is still encrypted on disk, and while that read fails, on the Save and at the
/// confirm, with no <code>PUT</code>; under Interactive a write that keeps it is refused too, on both
/// callers, while leaving it is not; with nothing encrypted on disk Interactive is written.</p>
/// <p>Mutation (Rule 19): answer 0 for the on-disk read in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.EncryptionStartup</method> -- every refused leg goes red; let
/// <method>OcuPilot.Kernel.Proposal.Prohibited.StartupDatabasesEncrypted</method> answer a failed read as
/// nothing encrypted -- the failed-read legs alone.</p>
Method TestInteractiveIsRefusedWhileADatabaseIsStillEncryptedOnDisk()
{
    Set tP = ..#PROBE
    Set tCode = "PROHIBITED.STARTUPINTERACTIVE"
    Do $ClassMethod(..#SEAM, "Hold", "database", [{"Id": (..#KEYONE), "KeyLen": 256, "IsDefault": true}])
    Set tHeld = {"DBEncStartMode": "Unattended", "DBEncStartKeyFile": "/ocuprobestart/held.key"}
    For tCase = $ListBuild("startup", "IRISAUDIT", "while IRISAUDIT is still encrypted on disk"), $ListBuild("startup", "IRISSECURITY", "while IRISSECURITY is still encrypted on disk"), $ListBuild("startup", "IRISTEMP", "while IRISTEMP is still encrypted on disk"), $ListBuild("ondiskfails", "", "while the on-disk read fails") {
        Do $ClassMethod(..#SEAM, "Arm", $List(tCase, 1))
        Do $ClassMethod(..#SEAM, "ArmOnDisk", $List(tCase, 2))
        Do ..Hold(tHeld)
        Do $ClassMethod(..#SEAM, "ClearCalls")
        Do $$$AssertEquals(..Save({"DBEncStartMode": "Interactive"}, .tAnswer), "403 " _ tCode, "Interactive " _ $List(tCase, 3) _ " is refused on the Save")
        Do $$$AssertEquals(..Parsed(tAnswer, "reason"), $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "STARTUPINTERACTIVEREASON"), "with its sentence")
        Do $$$AssertEquals(..Puts(), 0, $List(tCase, 3) _ ": no PUT from the Save")
        Do ..Hold(tHeld)
        Do $$$AssertEquals(..Propose({"DBEncStartMode": "Interactive"}, .tProposal), "", "Interactive " _ $List(tCase, 3) _ " is minted")
        Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, "", .tResult), "403 " _ tCode, "Interactive " _ $List(tCase, 3) _ " is refused at the confirm")
        Do $$$AssertEquals(..Puts(), 0, $List(tCase, 3) _ ": no PUT from the confirm")
    }
    Do $ClassMethod(..#SEAM, "Arm", "startup")
    Do $ClassMethod(..#SEAM, "ArmOnDisk", "IRISAUDIT")
    Set tUnder = {"DBEncStartMode": "Interactive", "DBEncStartKeyFile": "/ocuprobestart/held.key"}
    Do ..Hold(tUnder)
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Do $$$AssertEquals(..Save({"DBEncJournal": true}, .tAnswer) _ " " _ ..Puts(), "403 " _ tCode _ " 0", "under Interactive, a write that keeps it while IRISAUDIT is still encrypted on disk is refused with no PUT")
    Do ..Hold(tUnder)
    Do $$$AssertEquals(..Propose({"DBEncJournal": true}, .tProposal), "", "under Interactive, a write that keeps it while IRISAUDIT is still encrypted on disk is minted")
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, "", .tResult) _ " " _ ..Puts(), "403 " _ tCode _ " 0", "and refused at the confirm with no PUT")
    Do ..Hold(tUnder)
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Do $$$AssertEquals(..Save({"DBEncStartMode": "Unattended"}, .tAnswer) _ " " _ ..Puts(), "200  1", "leaving Interactive for Unattended is written: " _ $Extract(tAnswer, 1, 200))
    Do $ClassMethod(..#SEAM, "ArmOnDisk", "")
    Do ..Hold(tHeld)
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Do $$$AssertEquals(..Save({"DBEncStartMode": "Interactive"}, .tAnswer) _ " " _ ..Puts(), "200  1", "with nothing encrypted on disk, Interactive is written: " _ $Extract(tAnswer, 1, 200))
}

/// <p>C6, AD-26: with a settings template that carries no administrator and password, the Save, the mint and
/// the confirm of a proposal minted before are refused 501 <code>PORT.NOTIMPLEMENTED</code> with no
/// <code>PUT</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.EncryptionPort.SettingsGate</method> always answers OK --
/// each leg records a PUT and goes red.</p>
Method TestTheVersionGateRefusesEveryCaller()
{
    Set tP = ..#PROBE
    Do $ClassMethod(..#SEAM, "Arm", "startup")
    Do ..Hold({"DBEncStartMode": "None"})
    Do $$$AssertEquals(..Propose({"DBEncStartMode": "Interactive"}, .tEarlier), "", "a proposal is minted while the template carries the credentials")
    Do $ClassMethod(..#SEAM, "Arm", "settingsv1")
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Do $$$AssertEquals(..Save({"DBEncStartMode": "Interactive"}, .tAnswer), "501 PORT.NOTIMPLEMENTED", "the Save is refused")
    Do $$$AssertEquals(..Parsed(tAnswer, "reason"), $Parameter("OcuPilot.Api.EncryptionError", "REASONSETTINGSVERSION"), "naming the classic page")
    Do $$$AssertEquals(..Propose({"DBEncStartMode": "Interactive"}, .tProposal), "501 PORT.NOTIMPLEMENTED", "the mint is refused")
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tEarlier, "", .tResult), "501 PORT.NOTIMPLEMENTED", "and the earlier proposal's confirm")
    Do $$$AssertEquals(..Puts(), 0, "with no PUT")
}

/// <p>Matrix row 8: the vendor's measured refusals arrive as OcuPilot's: turning startup activation off while
/// something depends on it (#1217) is 409 with its sentence; a new key file's wrong password (#5001) is 422 on
/// the password; the same #5001 with no credentials sent is the generic 500.</p>
/// <p>Mutation (Rule 19): drop the credentials branch from
/// <method>OcuPilot.Port.EncryptionPort.StartupMapped</method> -- the password leg answers 500 and goes red.</p>
Method TestAVendorRefusalArrivesAsOcuPilotsSentence()
{
    Set tP = ..#PROBE
    Set tPassword = $ClassMethod(tP, "NewPassword")
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "start-v.key", $Parameter(tP, "ADMIN"), tPassword, 256, "OCUPROBESTART V", .tKey), "a probe key file")
    Do $ClassMethod(..#SEAM, "Arm", "startupfails")
    Do ..Hold({"DBEncStartMode": "Unattended", "DBEncStartKeyFile": "/ocuprobestart/held.key"})
    Do $ClassMethod(..#SEAM, "ArmFailure", 1217)
    Do $$$AssertEquals(..Save({"DBEncStartMode": "None"}, .tAnswer), "409 ENCRYPTION.STARTUP.REQUIRED", "#1217 is the startup-required refusal")
    Do $$$AssertEquals(..Parsed(tAnswer, "reason"), $Parameter("OcuPilot.Api.EncryptionError", "REASONSTARTUPREQUIRED"), "in OcuPilot's sentence")
    Do $ClassMethod(..#SEAM, "ArmFailure", 5001)
    Do $$$AssertEquals(..Save({"DBEncStartMode": "Unattended", "root": ($ClassMethod(tP, "Root")), "path": ($ClassMethod(tP, "RelativeName", "start-v.key")), "AdminName": ($Parameter(tP, "ADMIN")), "AdminPassword": (tPassword)}, .tAnswer), "422 AdminPassword:ENCRYPTION.KEYFILE.CREDENTIALS", "#5001 on a write carrying credentials is the password's refusal")
    Do $$$AssertEquals(..Save({"DBEncStartMode": "None"}, .tAnswer), "500 INTERNAL", "#5001 on a write carrying none is the generic fault")
    Do $$$AssertTrue(tAnswer '[ "5001", "and no vendor text is sent")
}

/// <p>C7, AD-35: a marker password, sent by the Save and supplied at the confirm, reaches no answer, no line of
/// <code>messages.log</code> or <code>alerts.log</code>, no proposal or ledger row, and no record of the seam;
/// the card asks for it as a masked row, and the script renders its placeholder.</p>
/// <p>A control line written to <code>messages.log</code> after the writes must be found by the same scan, so
/// a scan that reads nothing cannot pass for one that found no marker.</p>
/// <p>Mutation (Rule 19): the Save answers the body it sent as its read-back -- the marker leg goes red.</p>
Method TestThePasswordReachesNoRecord()
{
    Set tP = ..#PROBE
    Set tMarker = $ClassMethod(tP, "NewPassword")
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "start-p.key", $Parameter(tP, "ADMIN"), tMarker, 256, "OCUPROBESTART P", .tKey), "a probe key file opened by the marker")
    Set tMessages = $ClassMethod(tP, "LineCount", "messages.log")
    Set tAlerts = $ClassMethod(tP, "LineCount", "alerts.log")
    Do $ClassMethod(..#SEAM, "Arm", "startup")
    Do ..Hold({"DBEncStartMode": "None"})
    Set tNewFile = {"DBEncStartMode": "Unattended", "root": ($ClassMethod(tP, "Root")), "path": ($ClassMethod(tP, "RelativeName", "start-p.key")), "AdminName": ($Parameter(tP, "ADMIN"))}
    Set tBody = ##class(%DynamicObject).%FromJSON(tNewFile.%ToJSON())
    Do tBody.%Set("AdminPassword", tMarker, "string")
    Do $$$AssertEquals(..Save(tBody, .tAnswers), "200 ", "the Save writes with the marker")
    Do ..Hold({"DBEncStartMode": "None"})
    Do $$$AssertEquals(..Propose(tNewFile, .tProposal), "", "the agent's change is minted")
    Do $$$AssertTrue(##class(OcuPilot.Test.EncryptionKeyWrite).Stored(tProposal, "payload") [ """AdminPassword"":""""", "its card asks for the password as a masked row")
    Set tDraft = ##class(OcuPilot.Test.EncryptionKeyWrite).Draft(tProposal, .tSteps)
    Do $$$AssertTrue((tDraft [ "<AdminPassword>") && (tDraft [ "start-p.key"), "its script names the resolved key file and the password's placeholder: " _ $Extract(tDraft, 1, 300))
    Do ..Hold({"DBEncStartMode": "None"})
    Do $$$AssertEquals(..Propose(tNewFile, .tProposal), "", "a second change is minted")
    Do $$$AssertEquals($ClassMethod(tP, "Confirm", tProposal, {"AdminPassword": (tMarker)}, .tResult), "200 ", "and confirmed with the marker")
    Set tAnswers = tAnswers _ $Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "") _ tDraft
    Do $$$AssertTrue(tAnswers '[ tMarker, "no answer or script carries the marker")
    Set tControl = "OCUPROBESTART log control " _ $ZTimeStamp
    Do ##class(%SYS.System).WriteToConsoleLog(tControl, 0, 0)
    Set tLines = $ClassMethod(tP, "LinesAfter", "messages.log", tMessages).%ToJSON() _ $ClassMethod(tP, "LinesAfter", "alerts.log", tAlerts).%ToJSON()
    Do $$$AssertTrue(tLines [ tControl, "the log scan reads the lines written since the test began")
    Do $$$AssertTrue(tLines '[ tMarker, "messages.log and alerts.log carry no marker")
    Set tStored = ##class(OcuPilot.Test.EncryptionKeyFileWrite).StoredText(tProposal.%Get("proposalId"))
    Do $$$AssertTrue((tStored '= "") && (tStored '[ tMarker), "the proposal row and its ledger rows carry no marker")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "SentOf", "AdminPassword"), "", "and the seam recorded none")
}

/// <p>The real leg: a <code>PUT</code> of the instance's own settings, through the port, answers 200 with the
/// seven settings and changes nothing; the seam, unarmed, sends it because it changes nothing.</p>
Method TestTheUnchangedPutIsTheVendorsAndChangesNothing()
{
    Set tBefore = ..Facts()
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security.Encryption.Settings", "PUT", .tQuery, {}, .tWritten, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the unchanged PUT answers (" _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "") _ ")")
    Do $$$AssertEquals(..Puts() _ " " _ $ClassMethod(..#SEAM, "KeysOf", ..#PUT), "1 AuditEncrypt,DBEncIRISSecurity,DBEncIRISTemp,DBEncJournal,DBEncStartKMIPServer,DBEncStartKeyFile,DBEncStartMode", "one PUT of the seven settings reached the vendor")
    Do $$$AssertEquals(..Facts(), tBefore, "and nothing moved")
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security.Encryption.Settings", "PUT", .tQuery, {"DBEncJournal": true}, .tWritten, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ ..Facts(), "422 " _ tBefore, "a change the rules refuse sends nothing")
}

/// <p>The encryption facts and the audit database's lasting identity, as one string.</p>
ClassMethod Facts() As %String
{
    Set tAudit = $ClassMethod(..#PROBE, "AuditFacts")
    Quit $ClassMethod(..#PROBE, "EncryptionFacts").%ToJSON() _ "|" _ tAudit.%Get("directory") _ "|" _ tAudit.%Get("encrypted") _ "|" _ tAudit.%Get("keyId") _ "|" _ tAudit.%Get("mounted") _ "|" _ tAudit.%Get("error")
}

/// <p>Hold <var>pSettings</var> over the stock settings: None, every flag false, every value empty.</p>
ClassMethod Hold(pSettings As %DynamicObject)
{
    Set tHeld = {"DBEncStartMode": "None", "DBEncJournal": false, "DBEncIRISSecurity": false, "DBEncIRISTemp": false, "AuditEncrypt": false, "DBEncStartKMIPServer": "", "DBEncStartKeyFile": "", "DBEncDefaultKeyID": "", "DBEncJournalKeyID": ""}
    Set tIterator = pSettings.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Do tHeld.%Set(tKey, tValue, pSettings.%GetTypeOf(tKey))
    }
    Do $ClassMethod(..#SEAM, "HoldSettings", tHeld)
}

/// <p>How many settings <code>PUT</code>s the seam was asked since its calls were last cleared.</p>
ClassMethod Puts() As %Integer
{
    Set tCalls = $ClassMethod(..#SEAM, "Calls")
    Quit $Length(tCalls, ..#PUT) - 1
}

/// <p>Run the Save with <var>pBody</var>: <code>status code</code>, or <code>status field:code</code> for a
/// refusal on a field, with the answer in <var>pAnswer</var>.</p>
ClassMethod Save(pBody As %DynamicObject, Output pAnswer As %String) As %String
{
    Set tSC = $ClassMethod(..#SAVE, "Handle", pBody, .pAnswer, .tStatus)
    If $$$ISERR(tSC) Quit "error " _ $System.Status.GetErrorText(tSC)
    Quit +$Get(tStatus) _ " " _ $Select(+$Get(tStatus) = 200: "", 1: ##class(OcuPilot.Test.EncryptionProbe).Refusal(pAnswer))
}

/// <p>Mint the agent's change <var>pArgs</var> through the seam tool: <code>""</code>, or <code>status
/// refusal</code>, with the proposal in <var>pProposal</var>.</p>
ClassMethod Propose(pArgs As %DynamicObject, Output pProposal As %DynamicObject) As %String
{
    Set tSC = $ClassMethod(..#PROBE, "KeyMint", ..#SEAMTOOL, "", ##class(%DynamicObject).%FromJSON(pArgs.%ToJSON()), .pProposal, .tHttp, .tProblem)
    If $$$ISOK(tSC) Quit ""
    Quit +$Get(tHttp) _ " " _ $Get(tProblem)
}

/// <p>Change the settings by <var>pArgs</var> on the Save (<var>pCaller</var> <code>save</code>) or by a
/// minted and confirmed proposal, answering <code>200 </code> or the refusal, with the consequence the Save or
/// the card names in <var>pConsequence</var>.</p>
ClassMethod Change(pCaller As %String, pArgs As %DynamicObject, Output pConsequence As %String) As %String
{
    Set pConsequence = ""
    If pCaller = "save" {
        Set tOutcome = ..Save(pArgs, .tAnswer)
        Set pConsequence = ..Parsed(tAnswer, "consequence")
        Quit tOutcome
    }
    Set tOutcome = ..Propose(pArgs, .tProposal)
    If tOutcome '= "" Quit tOutcome
    Set pConsequence = ##class(OcuPilot.Test.EncryptionKeyWrite).Stored(tProposal, "consequence")
    Quit $ClassMethod(..#PROBE, "Confirm", tProposal, "", .tResult)
}

/// <p>Member <var>pName</var> of the JSON object <var>pText</var>, or <code>""</code>.</p>
ClassMethod Parsed(pText As %String, pName As %String) As %String
{
    Set tObject = ##class(OcuPilot.Test.EncryptionProbe).Parsed(pText)
    If '$IsObject(tObject) Quit ""
    Quit tObject.%Get(pName)
}

}
