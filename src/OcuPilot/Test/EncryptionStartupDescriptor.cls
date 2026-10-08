/// <p>Pins Story 18.23's declarations (C2, C9): the encryption startup settings descriptor, its tool's kind,
/// port, pairs and declared secret, <class>OcuPilot.Api.EncryptionError</class>'s codes and sentences, the
/// baseline key shipped disabled, <code>PROHIBITED.STARTUPINTERACTIVE</code>'s sentence and its predicate over
/// the settings a write leaves, the tool's merge and consequences, the derived field list's credential rows,
/// and <method>OcuPilot.Port.EncryptionPort.Snippet</method>'s startup branches.</p>
/// <p><b>Reads only.</b> The snippet and consequence legs read the instance's settings and change nothing;
/// the version gate's branch runs through <class>OcuPilot.Test.EncryptionSeamPort</class> armed
/// <code>settingsv1</code>, which answers the template only. After each test the encryption state and the
/// audit database's identity read as that test found them.</p>
Class OcuPilot.Test.EncryptionStartupDescriptor Extends %UnitTest.TestCase
{

Parameter SCREEN = "OcuPilot.Screen.Descriptor.EncryptionStartup";

Parameter TOOL = "OcuPilot.Screen.Tool.EncryptionStartupUpdate";

Parameter PORT = "OcuPilot.Port.EncryptionPort";

Parameter SEAM = "OcuPilot.Test.EncryptionSeamPort";

Parameter ERRORS = "OcuPilot.Api.EncryptionError";

Parameter PROHIBITED = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The encryption facts and the audit database's identity before each test.</p>
Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = ##class(OcuPilot.Test.EncryptionStartupWrite).Facts()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Clear")
    Set tFacts = ##class(OcuPilot.Test.EncryptionStartupWrite).Facts()
    Do $$$AssertTrue((tFacts '[ """error"":") && (..PreparedFacts '[ """error"":"), "the facts were read whole before and after the test")
    Do $$$AssertEquals(tFacts, ..PreparedFacts, "no encryption setting moved and the audit database is the one the test found")
    Quit $$$OK
}

/// <p>C9: the form is Security's unlisted <code>form-page</code> on the route the link names, over the
/// settings read, with Security's two pairs and no own pair, the password the one declared secret, three
/// prompts, no refresh and the classic Database Encryption page.</p>
/// <p>Mutation (Rule 19): give the descriptor a <code>sideBarPosition</code> of 11 -- the position leg goes
/// red.</p>
Method TestTheScreenIsDeclaredAsTheSpecPlacesIt()
{
    Set tClass = ..#SCREEN
    Do $$$AssertEquals($ClassMethod(tClass, "Route"), "security/database-encryption/startup", "the route")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "security", "in Security and secrets")
    Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), 0, "unlisted")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "form-page", "a form page")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "classicPage"), "%CSP.UI.Portal.EncryptionDatabase", "the classic page")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "toolIdentifier"), "security.encryptionstartup", "the tool identifier")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ " " _ $ClassMethod(tClass, "Scope"), "encryption-startup instance", "the singleton entity")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "id").%Get("kind"), "single", "one id")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Secure:USE,%DB_IRISSYS:READ", "Security's two pairs")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "OwnPrivilegePairs")), "", "and no own pair")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SecretArguments")), "AdminPassword", "the password is the declared secret")
    Set tPrompts = $ClassMethod(tClass, "Field", "suggestedPrompts")
    Do $$$AssertEquals(tPrompts.%Size() _ " " _ tPrompts.%Get(0).%Get("groupKey"), "3 userPromptGroupAccess", "three prompts")
    Do $$$AssertEquals(+$ClassMethod(tClass, "Field", "refreshes"), 0, "no auto-refresh")
    Set tRead = $ClassMethod(tClass, "Read")
    Do $$$AssertEquals(tRead.%Get("source").%Get("port") _ " " _ tRead.%Get("source").%Get("endpoint") _ " " _ tRead.%Get("source").%Get("type"), "admin Security.Encryption.Settings GET", "the settings read")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionKeyRead).Joined(tRead.%Get("fields")), "DBEncStartMode,DBEncJournal,DBEncIRISSecurity,DBEncIRISTemp,AuditEncrypt,DBEncStartKMIPServer,DBEncStartKeyFile,DBEncDefaultKeyID,DBEncJournalKeyID", "of the nine settings")
}

/// <p>C9: the tool is an advertised merge write on the encryption port, its pairs Security's and the
/// file-system pair only when a root is sent, its one secret the password, which its schema never
/// carries, and the startup key file never settable.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Screen.Tool.EncryptionStartupUpdate.ArgumentPairs</method>'s
/// root branch -- the argument pairs leg goes red.</p>
Method TestTheToolDeclaresItsKindPortPairsAndSecret()
{
    Set tTool = ..#TOOL
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("security.encryptionstartup.update", .tEntry)
    Do $$$AssertTrue($IsObject($Get(tEntry)), "the tool is registered")
    Do $$$AssertEquals($Parameter(tTool, "KIND") _ " " _ $ClassMethod(tTool, "Advertised"), "write 1", "an advertised write")
    Do $$$AssertEquals($ClassMethod(tTool, "PortClass") _ " " _ $ClassMethod(tTool, "ReadType") _ " " _ $ClassMethod(tTool, "WriteType") _ " " _ $ClassMethod(tTool, "SendsBody"), ..#PORT _ " GET PUT 1", "a merge write through the encryption port")
    Do $$$AssertEquals($Parameter(tTool, "CLASSICPAGES") _ "|" _ $ClassMethod(tTool, "Destructive"), "|0", "no other classic page, and not destructive by declaration")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tTool, "PrivilegePairs", "", .tResolved)), "%Admin_Secure:USE,%DB_IRISSYS:READ", "Security's two pairs and no other")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tTool, "ArgumentPairs", "", {"root": "/r/", "path": "k.key"}, .tResolved)), "%Admin_FileSystemAccess:USE", "the file-system pair when a root is sent")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tTool, "ArgumentPairs", "", {"DBEncStartMode": "Interactive"}, .tResolved)), "", "and none otherwise")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "ChannelSecretNames", "", .tDeclared)), "AdminPassword", "the confirm channel is open to the password alone")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "SettableFields")), "DBEncStartMode,DBEncJournal,DBEncIRISSecurity,DBEncIRISTemp,AuditEncrypt,DBEncStartKMIPServer,DBEncJournalKeyID,DBEncDefaultKeyID,AdminName,root,path,AdminPassword", "the settable fields, the password the confirm supplies among them")
    Set tProperties = $ClassMethod(tTool, "InputSchema").%Get("properties")
    Do $$$AssertEquals(tProperties.%IsDefined("AdminPassword") _ tProperties.%IsDefined("DBEncStartKeyFile"), "00", "the schema carries neither the password nor the startup key file")
    Do $$$AssertEquals(tProperties.%Get("AuditEncrypt").%Get("type") _ " " _ tProperties.%Get("DBEncStartMode").%Get("enum").%ToJSON(), "boolean [""None"",""Interactive"",""Unattended"",""KMIP""]", "a flag is a boolean and the mode one of four")
    Do $$$AssertEquals($ClassMethod(tTool, "MintClass"), "OcuPilot.Screen.Tool.EncryptionStartupMint", "its mint asks the gate and the rules first")
}

/// <p>Every startup code answers its one sentence through the class and through
/// <class>OcuPilot.Api.Error</class>'s two dispatches; the tool's consequence codes are the class's, and the
/// kernel's audit effect is its <code>AUDIT.ENCRYPTIONCHANGE</code>.</p>
Method TestTheCodesAnswerTheirSentences()
{
    Set tClass = ..#ERRORS
    Set tCodes = $ClassMethod(tClass, "Codes")
    Do $$$AssertEquals($ListLength(tCodes), 27, "twenty-seven codes: Story 18.7's nine, Story 18.22's six and Story 18.23's twelve")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = $ClassMethod(tClass, "ReasonFor", tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ " answers it through the violation dispatch")
    }
    Set tViolations = $ClassMethod(tClass, "ViolationCodes")
    For tCode = "ENCRYPTION.STARTUP.KMIPSERVER", "ENCRYPTION.STARTUP.KEYFILE", "ENCRYPTION.STARTUP.NEEDSSTART", "ENCRYPTION.STARTUP.NOKEY", "ENCRYPTION.STARTUP.KEYINACTIVE" {
        Do $$$AssertTrue($ListFind(tViolations, tCode) && ($ClassMethod(tClass, "FieldOf", tCode) '= ""), tCode _ " is a violation code with its field")
    }
    Set tModes = $ListFromString($Parameter(..#TOOL, "MODECONSEQUENCES"))
    Do $$$AssertEquals($ListToString(tModes), $Parameter(tClass, "STARTUPNONE") _ "," _ $Parameter(tClass, "STARTUPINTERACTIVE") _ "," _ $Parameter(tClass, "STARTUPUNATTENDED") _ "," _ $Parameter(tClass, "STARTUPKMIP"), "the tool's mode codes are the class's")
    Do $$$AssertEquals($Parameter(..#TOOL, "RESTARTCONSEQUENCE") _ " " _ $Parameter(..#TOOL, "JOURNALCONSEQUENCE"), $Parameter(tClass, "STARTUPRESTART") _ " " _ $Parameter(tClass, "STARTUPJOURNAL"), "and its restart and journal codes")
    Do $$$AssertEquals($Parameter(..#PROHIBITED, "EFFECTAUDITENCRYPTION"), $Parameter(tClass, "AUDITENCRYPTIONCHANGE"), "the kernel's audit effect is the class's code")
    Do $$$AssertEquals($ClassMethod(tClass, "ReasonFor", "AUDIT.ENCRYPTIONCHANGE"), $Parameter(tClass, "REASONAUDITENCRYPTIONCHANGE"), "which carries the audit sentence")
    Do $$$AssertTrue($Parameter(tClass, "REASONSTARTUPUNATTENDED") [ "Not recommended.", "Unattended's sentence is marked not recommended")
    Do $$$AssertTrue($Parameter(tClass, "REASONSTARTUPINTERACTIVE") [ "so Interactive is not offered", "and Interactive's says why it is not offered")
}

/// <p>AD-22: the tool's key ships disabled in the baseline.</p>
/// <p>Mutation (Rule 19): set <code>security.encryptionstartup.update</code> to <code>true</code> in
/// <class>OcuPilot.Kernel.Governance.Baseline</class> -- this goes red.</p>
Method TestTheBaselineKeyShipsDisabled()
{
    Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed("security.encryptionstartup.update", .tListed)
    Do $$$AssertEquals(tListed _ " " _ tValue, "1 0", "security.encryptionstartup.update is listed and disabled")
}

/// <p>AD-10, AD-53: <code>PROHIBITED.STARTUPINTERACTIVE</code> answers its own parameter, which names no
/// caller, and is one of the set's thirty-two codes.</p>
Method TestTheInteractiveRefusalIsItsParameterAndNamesNoCaller()
{
    Set tProhibited = ..#PROHIBITED
    Set tReason = $ClassMethod(tProhibited, "ReasonFor", "PROHIBITED.STARTUPINTERACTIVE")
    Do $$$AssertEquals(tReason, $Parameter(tProhibited, "STARTUPINTERACTIVEREASON"), "the refusal answers its parameter")
    Do $$$AssertTrue(($ZConvert(tReason, "L") '[ "the agent"), "naming no caller")
    Do $$$AssertEquals($ListLength($ClassMethod(tProhibited, "Codes")), 32, "thirty-two codes")
    Do $$$AssertTrue($ListFind($ClassMethod(tProhibited, "Codes"), "PROHIBITED.STARTUPINTERACTIVE"), "and it is one of them")
    Do $$$AssertTrue($ListFind($ClassMethod(tProhibited, "CoveredTypes"), "encryption-startup"), "the startup settings are a covered type")
}

/// <p>AD-10, Decision 8: the startup arm judges the settings a write leaves, each read from the payload
/// where it carries one and from the instance otherwise, in both orders: Interactive chosen while the audit
/// log, IRISSECURITY or IRISTEMP is encrypted or being encrypted, or by a write that also turns it off, and
/// one of them encrypted under Interactive; turning one off under Interactive, and any other mode, is not
/// refused. While one of their databases is still encrypted on disk, every write that leaves Interactive is
/// refused, with every flag off, and one that leaves it is not.</p>
/// <p>Mutation (Rule 19): drop <code>DBEncIRISTemp</code> from
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.STARTUPREQUIREDFLAGS</parameter> -- the IRISTEMP legs go
/// red; ignore <method>OcuPilot.Kernel.Proposal.Prohibited.LeavesInteractiveRequired</method>'s
/// <var>pEncryptedOnDisk</var> -- the on-disk legs go red.</p>
Method TestTheStartupArmJudgesTheSettingsTheWriteLeaves()
{
    Set tP = ..#PROHIBITED
    Set tNone = {"DBEncStartMode": "None", "DBEncJournal": false, "DBEncIRISSecurity": false, "DBEncIRISTemp": false, "AuditEncrypt": false}
    Set tInteractive = {"DBEncStartMode": "Interactive", "DBEncJournal": false, "DBEncIRISSecurity": false, "DBEncIRISTemp": false, "AuditEncrypt": false}
    For tFlag = "AuditEncrypt", "DBEncIRISSecurity", "DBEncIRISTemp" {
        Set tHeld = ##class(%DynamicObject).%FromJSON(tNone.%ToJSON())
        Do tHeld.%Set("DBEncStartMode", "Unattended", "string")
        Do tHeld.%Set(tFlag, 1, "boolean")
        Do $$$AssertTrue($ClassMethod(tP, "LeavesInteractiveRequired", {"DBEncStartMode": "Interactive"}, tHeld), "Interactive chosen while " _ tFlag _ " is set is refused")
        Set tPayload = {"DBEncStartMode": "Interactive"}
        Do tPayload.%Set(tFlag, 0, "boolean")
        Do $$$AssertTrue($ClassMethod(tP, "LeavesInteractiveRequired", tPayload, tHeld), "Interactive chosen while " _ tFlag _ " is set is refused when the same write turns it off")
        Set tPayload = {"DBEncStartMode": "Interactive"}
        Do tPayload.%Set(tFlag, 1, "boolean")
        Do $$$AssertTrue($ClassMethod(tP, "LeavesInteractiveRequired", tPayload, tNone), "Interactive chosen while " _ tFlag _ " is being set is refused")
        Set tPayload = {}
        Do tPayload.%Set(tFlag, 1, "boolean")
        Do $$$AssertTrue($ClassMethod(tP, "LeavesInteractiveRequired", tPayload, tInteractive), tFlag _ " set under Interactive is refused")
        Set tPayload = {"DBEncStartMode": "Unattended"}
        Do tPayload.%Set(tFlag, 0, "boolean")
        Do $$$AssertTrue('$ClassMethod(tP, "LeavesInteractiveRequired", tPayload, tHeld), "leaving Interactive alone with " _ tFlag _ " set is not refused")
        Set tPayload = {}
        Do tPayload.%Set(tFlag, 0, "boolean")
        Set tUnder = ##class(%DynamicObject).%FromJSON(tInteractive.%ToJSON())
        Do tUnder.%Set(tFlag, 1, "boolean")
        Do $$$AssertTrue('$ClassMethod(tP, "LeavesInteractiveRequired", tPayload, tUnder), "turning " _ tFlag _ " off under Interactive is not refused")
    }
    Do $$$AssertTrue('$ClassMethod(tP, "LeavesInteractiveRequired", {"DBEncJournal": true}, tInteractive), "journal encryption under Interactive is not refused")
    Do $$$AssertTrue('$ClassMethod(tP, "LeavesInteractiveRequired", {"DBEncStartMode": "Interactive"}, tNone), "Interactive with nothing encrypted is not refused")
    Set tUnattended = ##class(%DynamicObject).%FromJSON(tNone.%ToJSON())
    Do tUnattended.%Set("DBEncStartMode", "Unattended", "string")
    Do $$$AssertTrue($ClassMethod(tP, "LeavesInteractiveRequired", {"DBEncStartMode": "Interactive"}, tUnattended, 1), "Interactive chosen with every flag off while a database is still encrypted on disk is refused")
    Do $$$AssertTrue($ClassMethod(tP, "LeavesInteractiveRequired", {"DBEncJournal": true}, tInteractive, 1), "a write that keeps Interactive while a database is still encrypted on disk is refused")
    Do $$$AssertTrue('$ClassMethod(tP, "LeavesInteractiveRequired", {"DBEncStartMode": "Unattended"}, tInteractive, 1), "leaving Interactive while a database is still encrypted on disk is not refused")
    Do $$$AssertTrue('$ClassMethod(tP, "LeavesInteractiveRequired", {"DBEncStartMode": "Interactive"}, tUnattended, 0), "Interactive chosen with every flag off and nothing encrypted on disk is not refused")
}

/// <p>C3, Decision 1: the merge leaves out the startup key file, an <code>AuditEncrypt</code> it does not
/// change (the port reads it at the write) and a key id it does not change; a changed
/// <code>AuditEncrypt</code> is carried with no key the port does not send; the unchanged count is the
/// payload's properties no row names.</p>
/// <p>Mutation (Rule 19): keep the fresh read's <code>AuditEncrypt</code> in
/// <method>OcuPilot.Screen.Tool.EncryptionStartupUpdate.MergeUpdate</method> when the arguments do not change
/// it -- the first leg goes red; keep an unchanged key id -- the third goes red.</p>
Method TestTheMergeShapesThePayload()
{
    Set tTool = ..#TOOL
    Set tFresh = {"DBEncStartMode": "Unattended", "DBEncJournal": false, "DBEncIRISSecurity": false, "DBEncIRISTemp": false, "AuditEncrypt": true, "DBEncStartKMIPServer": "", "DBEncStartKeyFile": "/k/start.key", "DBEncDefaultKeyID": "K1", "DBEncJournalKeyID": "K1"}
    Set tSettable = $ClassMethod(tTool, "SettableFields")
    Set tSC = $ClassMethod(tTool, "MergeUpdate", tFresh, {"Name": "SYSTEM", "DBEncStartMode": "KMIP", "DBEncStartKMIPServer": "kms"}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "a mode change merges (" _ $Get(tProblem) _ ")")
    Do $$$AssertEquals(..Keys(tPayload), "DBEncIRISSecurity,DBEncIRISTemp,DBEncJournal,DBEncStartKMIPServer,DBEncStartMode", "its payload carries the mode, the server and three flags, and no AuditEncrypt, key file or key id")
    Do $$$AssertEquals(..Fields(tDiff) _ " " _ tUnchanged, "DBEncStartMode,DBEncStartKMIPServer 3", "two rows and three unchanged")
    Set tSC = $ClassMethod(tTool, "MergeUpdate", tFresh, {"Name": "SYSTEM", "AuditEncrypt": false}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "an audit change merges")
    Do $$$AssertEquals(tPayload.%Get("AuditEncrypt") _ " " _ ..Keys(tPayload) _ " " _ ..Fields(tDiff), "0 AuditEncrypt,DBEncIRISSecurity,DBEncIRISTemp,DBEncJournal,DBEncStartKMIPServer,DBEncStartMode AuditEncrypt", "its payload carries the change, which its one row names, and no key the port does not send")
    Set tSC = $ClassMethod(tTool, "MergeUpdate", tFresh, {"Name": "SYSTEM", "AuditEncrypt": true, "DBEncJournalKeyID": "K2"}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "a key id change merges")
    Do $$$AssertEquals(..Keys(tPayload) _ " " _ ..Fields(tDiff), "DBEncIRISSecurity,DBEncIRISTemp,DBEncJournal,DBEncJournalKeyID,DBEncStartKMIPServer,DBEncStartMode DBEncJournalKeyID", "an unchanged AuditEncrypt and default key id are left out, the changed journal key id carried")
    Set tSC = $ClassMethod(tTool, "MergeUpdate", tFresh, {"Name": "SYSTEM", "AdminName": "Somebody"}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals(..Fields(tDiff) _ " " _ tPayload.%IsDefined("AdminName") _ tPayload.%IsDefined("AdminPassword"), " 00", "an administrator without a new key file is neither carried nor asked for")
}

/// <p>C2: the card names the change's consequence, first match: the audit log's encryption, the chosen
/// start mode, IRISSECURITY or IRISTEMP, then journal encryption; a change to none of them names none.</p>
/// <p>Mutation (Rule 19): drop Unattended's code from
/// <parameter>OcuPilot.Screen.Tool.EncryptionStartupUpdate.MODECONSEQUENCES</parameter> -- the Unattended leg
/// goes red.</p>
Method TestTheConsequenceNamesEachChange()
{
    Set tTool = ..#TOOL
    Set tHeld = {"DBEncStartMode": "None", "DBEncJournal": false, "DBEncIRISSecurity": false, "DBEncIRISTemp": false, "AuditEncrypt": false}
    For tCase = $ListBuild("{""DBEncStartMode"":""None""}", ""), $ListBuild("{""DBEncStartMode"":""Interactive""}", "ENCRYPTION.STARTUP.INTERACTIVE"), $ListBuild("{""DBEncStartMode"":""Unattended""}", "ENCRYPTION.STARTUP.UNATTENDED"), $ListBuild("{""DBEncStartMode"":""KMIP""}", "ENCRYPTION.STARTUP.KMIP"), $ListBuild("{""DBEncStartMode"":""None"",""DBEncIRISTemp"":true}", "ENCRYPTION.STARTUP.RESTART"), $ListBuild("{""DBEncStartMode"":""None"",""DBEncIRISSecurity"":true}", "ENCRYPTION.STARTUP.RESTART"), $ListBuild("{""DBEncStartMode"":""None"",""DBEncJournal"":true}", "ENCRYPTION.STARTUP.JOURNAL"), $ListBuild("{""DBEncStartMode"":""Unattended"",""AuditEncrypt"":true}", "AUDIT.ENCRYPTIONCHANGE") {
        Set tPayload = ##class(%DynamicObject).%FromJSON($List(tCase, 1))
        Do $$$AssertEquals($ClassMethod(tTool, "ConsequenceOver", tPayload, tHeld), $List(tCase, 2), $List(tCase, 1) _ " names " _ $List(tCase, 2))
    }
    Set tUnattended = ##class(%DynamicObject).%FromJSON(tHeld.%ToJSON())
    Do tUnattended.%Set("DBEncStartMode", "Unattended", "string")
    Do $$$AssertEquals($ClassMethod(tTool, "ConsequenceOver", {"DBEncStartMode": "None"}, tUnattended), "ENCRYPTION.STARTUP.NONE", "leaving Unattended for None names None's")
    Do $$$AssertEquals($ClassMethod(tTool, "Consequence", {"DBEncStartMode": "None"}, 0, "AUDIT.ENCRYPTIONCHANGE"), "AUDIT.ENCRYPTIONCHANGE", "the kernel's audit effect comes first")
}

/// <p>AD-3: the derived field list holds the eleven template rows, the password classified secret and the
/// administrator compared as written (AD-58).</p>
Method TestTheFieldListDerivesTheCredentialRows()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Screen.Tool.ToolFields", "Tools")
    Do tXData.Data.Rewind()
    Set tEntry = ##class(%DynamicObject).%FromJSON(tXData.Data).%Get("security.encryptionstartup.update")
    Do $$$AssertTrue($IsObject(tEntry), "the tool has a generated field entry")
    Set tRows = ""
    Set tIterator = tEntry.%Get("fields").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tRows = tRows _ $Select(tRows = "": "", 1: ",") _ tRow.%Get("path") _ ":" _ tRow.%Get("class") _ $Select(tRow.%Get("compare") '= "": ":" _ tRow.%Get("compare"), 1: "")
    }
    Do $$$AssertEquals(tRows, "DBEncStartMode:ordinary,DBEncJournal:ordinary,DBEncIRISSecurity:ordinary,DBEncIRISTemp:ordinary,AuditEncrypt:ordinary,DBEncStartKMIPServer:ordinary,DBEncStartKeyFile:ordinary,DBEncJournalKeyID:ordinary,DBEncDefaultKeyID:ordinary,AdminName:ordinary:written,AdminPassword:secret", "the eleven rows, the password secret")
}

/// <p>AD-59: the write renders as one <code>rest</code> step carrying the seven settings the vendor requires
/// over the instance's settings, and a refusal as one <code>comment</code> step: the version gate's, a file
/// named by the caller, and a rule's.</p>
/// <p>Mutation (Rule 19): drop the version gate from
/// <method>OcuPilot.Port.EncryptionPort.StartupSnippet</method> -- the <code>settingsv1</code> leg renders a call
/// and goes red.</p>
Method TestTheSnippetRendersEachBranch()
{
    Set tContext = {"origin": "https://example.invalid", "user": "_SYSTEM"}
    Kill tQuery
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.Encryption.Settings", "PUT", .tQuery, {"DBEncStartMode": "Interactive"}, tContext)
    Do $$$AssertEquals(tSteps.%Size() _ " " _ tSteps.%Get(0).%Get("kind"), "1 rest", "a write is one rest step")
    Set tText = tSteps.%Get(0).%Get("text")
    For tKey = "DBEncStartMode", "DBEncJournal", "DBEncIRISSecurity", "DBEncIRISTemp", "AuditEncrypt", "DBEncStartKMIPServer", "DBEncStartKeyFile" {
        Do $$$AssertTrue(tText [ ("""" _ tKey _ """"), "carrying " _ tKey)
    }
    Do $$$AssertTrue((tText '[ "AdminPassword") && (tText '[ "DBEncDefaultKeyID"), "and no credential or unchanged key id")
    Kill tQuery
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.Encryption.Settings", "PUT", .tQuery, {"DBEncStartMode": "Unattended"}, tContext)
    Do $$$AssertEquals(tSteps.%Size() _ " " _ tSteps.%Get(0).%Get("kind") _ " " _ tSteps.%Get(0).%Get("text"), "1 comment " _ $Parameter(..#ERRORS, "REASONSTARTUPKEYFILE"), "Unattended with no key file renders the rule's refusal")
    Kill tQuery
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.Encryption.Settings", "PUT", .tQuery, {"DBEncStartMode": "KMIP", "DBEncStartKMIPServer": "kms"}, tContext)
    Do $$$AssertEquals(tSteps.%Get(0).%Get("kind") _ " " _ tSteps.%Get(0).%Get("text"), "comment " _ $Parameter(..#ERRORS, "REASONSTARTUPKMIPSERVER"), "KMIP naming a server the instance has not configured renders the rule's refusal")
    Kill tQuery
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.Encryption.Settings", "PUT", .tQuery, {"DBEncStartKeyFile": "/etc/x"}, tContext)
    Do $$$AssertEquals(tSteps.%Get(0).%Get("kind") _ " " _ tSteps.%Get(0).%Get("text"), "comment " _ $Parameter("OcuPilot.Api.Error", "REASONPATHNAME"), "a file the caller names renders the path refusal")
    Do $ClassMethod(..#SEAM, "Arm", "settingsv1")
    Kill tQuery
    Set tSteps = $ClassMethod(..#SEAM, "Snippet", "Security.Encryption.Settings", "PUT", .tQuery, {"DBEncStartMode": "KMIP"}, tContext)
    Do $$$AssertEquals(tSteps.%Size() _ " " _ tSteps.%Get(0).%Get("kind") _ " " _ tSteps.%Get(0).%Get("text"), "1 comment " _ $Parameter(..#ERRORS, "REASONSETTINGSVERSION"), "a template without the credentials renders the version gate's refusal")
}

/// <p>A dynamic object's keys, sorted and comma-joined.</p>
ClassMethod Keys(pObject As %DynamicObject) As %String
{
    If '$IsObject(pObject) Quit ""
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tNames(tKey) = ""
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tNames(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

/// <p>A diff's field names, in its order, comma-joined.</p>
ClassMethod Fields(pDiff As %DynamicArray) As %String
{
    If '$IsObject(pDiff) Quit ""
    Set tOut = ""
    Set tIterator = pDiff.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tRow.%Get("field")
    }
    Quit tOut
}

}
