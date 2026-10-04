/// <p>Pins Story 18.7's declarations (A0, A5, A6): the three encryption key file descriptors (routes,
/// positions, pairs and own pair, classic pages, prompts, entity type, criteria and hints), the five
/// tools' pairs, pages, secrets and destructive flags, <class>OcuPilot.Api.EncryptionError</class>'s codes
/// and sentences, the five baseline keys shipped disabled, <code>PROHIBITED.OCUPILOTKEY</code>'s sentence,
/// <method>OcuPilot.Port.EncryptionPort.Snippet</method>'s refusal branches and
/// <method>OcuPilot.Port.AdminPort.NamesKeyFile</method>.</p>
/// <p>Reads only: it names no file the instance holds, so every snippet branch it renders is a
/// refusal, decided before any vendor call.</p>
Class OcuPilot.Test.EncryptionDescriptor Extends %UnitTest.TestCase
{

Parameter KEYS = "OcuPilot.Screen.Descriptor.EncryptionKeyFile";

Parameter ADMINS = "OcuPilot.Screen.Descriptor.EncryptionKeyFileAdminList";

Parameter FORM = "OcuPilot.Screen.Descriptor.EncryptionKeyFileForm";

Parameter PORT = "OcuPilot.Port.EncryptionPort";

/// <p>The three screens: route, position, archetype, classic page, tool identifier.</p>
Method TestTheThreeScreensAreDeclaredAsTheSpecPlacesThem()
{
    For tCase = $ListBuild(..#KEYS, "security/encryption-key-file", 8, "list (server criteria)", "%CSP.UI.Portal.EncryptionManage", "security.encryptionkeyfile"), $ListBuild(..#ADMINS, "security/encryption-key-file/administrators", 0, "list (server criteria)", "%CSP.UI.Portal.EncryptionManage", "security.encryptionkeyfileadmins"), $ListBuild(..#FORM, "security/encryption-key-file/create", 0, "form-page", "%CSP.UI.Portal.EncryptionCreate", "security.encryptionkeyfileform") {
        Set tClass = $List(tCase, 1)
        Do $$$AssertEquals($ClassMethod(tClass, "Route"), $List(tCase, 2), tClass _ "'s route")
        Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "security", tClass _ " is in Security and secrets")
        Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), $List(tCase, 3), tClass _ "'s side-bar position")
        Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), $List(tCase, 4), tClass _ "'s archetype")
        Do $$$AssertEquals($ClassMethod(tClass, "Field", "classicPage"), $List(tCase, 5), tClass _ "'s classic page")
        Do $$$AssertEquals($ClassMethod(tClass, "Field", "toolIdentifier"), $List(tCase, 6), tClass _ "'s tool identifier")
        Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), "encryption-key-file", tClass _ "'s entity type")
        Do $$$AssertEquals($ClassMethod(tClass, "Scope"), "instance", tClass _ "'s scope")
        Do $$$AssertEquals(..Pairs($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Secure:USE,%Admin_FileSystemAccess:USE,%DB_IRISSYS:READ", tClass _ "'s pairs, in order")
        Do $$$AssertEquals(..Pairs($ClassMethod(tClass, "OwnPrivilegePairs")), "%Admin_FileSystemAccess:USE", tClass _ "'s own pair")
        Do $$$AssertEquals($ClassMethod(tClass, "Field", "suggestedPrompts").%Size(), 3, tClass _ " carries three prompts")
    }
    Do $$$AssertEquals($ListToString($ClassMethod(..#KEYS, "RowActionIds")) _ " " _ $ClassMethod(..#KEYS, "PrimaryActionId"), "addkey,removekey create", "the keys screen's actions")
    Do $$$AssertEquals($ListToString($ClassMethod(..#ADMINS, "RowActionIds")), "addadministrator,removeadministrator", "the administrators screen's actions")
    Do $$$AssertEquals($ListToString($ClassMethod(..#KEYS, "SecretArguments")) _ " " _ $ListToString($ClassMethod(..#ADMINS, "SecretArguments")), "AdminPassword OldAdminPassword,NewAdminPassword", "the declared secrets")
    For tClass = ..#KEYS, ..#ADMINS {
        Set tRead = $ClassMethod(tClass, "Read")
        Do $$$AssertEquals(tRead.%Get("source").%Get("port"), "encryption", tClass _ " reads through the encryption port")
        Set tFields = tRead.%Get("criteria").%Get("fields")
        Do $$$AssertEquals(tFields.%Get(0).%Get("param") _ ":" _ tFields.%Get(0).%Get("kind") _ ":" _ tFields.%Get(0).%Get("maxLength") _ " " _ tFields.%Get(1).%Get("param") _ ":" _ tFields.%Get(1).%Get("kind") _ ":" _ tFields.%Get(1).%Get("maxLength"), "root:text:1024 path:text:807", tClass _ "'s criteria")
        Do $$$AssertEquals(tFields.%Get(0).%Get("hint"), "An allowed directory exactly as the Allowed directories screen lists it.", tClass _ "'s root hint")
        Do $$$AssertEquals(tFields.%Get(1).%Get("hint"), "The key file's name under that directory, up to eight /-separated parts.", tClass _ "'s path hint")
    }
}

/// <p>The five tools: pairs (the screen's three, and <code>%Admin_Manage:USE</code> for the key removal),
/// classic pages, declared secrets within the descriptor's, destructive flags and port.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Screen.Tool.EncryptionKeyFileRemoveKey.EXTRAPAIRS</parameter>
/// -- the removal's pairs leg goes red.</p>
Method TestTheFiveToolsDeclareTheirPairsPagesAndSecrets()
{
    Set tThree = "%Admin_Secure:USE,%Admin_FileSystemAccess:USE,%DB_IRISSYS:READ"
    For tCase = $ListBuild("EncryptionKeyFileCreate", tThree, "%CSP.UI.Portal.EncryptionCreate", "AdminPassword", 0), $ListBuild("EncryptionKeyFileAddAdmin", tThree, "%CSP.UI.Portal.Dialog.EncAddAdmin", "OldAdminPassword,NewAdminPassword", 0), $ListBuild("EncryptionKeyFileRemoveAdmin", tThree, "", "", 1), $ListBuild("EncryptionKeyFileAddKey", tThree, "%CSP.UI.Portal.Dialog.EncAddAdmin", "AdminPassword", 0), $ListBuild("EncryptionKeyFileRemoveKey", tThree _ ",%Admin_Manage:USE", "", "", 1) {
        Set tClass = "OcuPilot.Screen.Tool." _ $List(tCase, 1)
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
        Do $$$AssertEquals(..Pairs(tPairs), $List(tCase, 2), tClass _ "'s pairs")
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), $List(tCase, 3), tClass _ "'s classic pages")
        Do $$$AssertEquals($Parameter(tClass, "SECRETBODY"), $List(tCase, 4), tClass _ "'s secrets")
        Do $$$AssertEquals(+$Parameter(tClass, "DESTRUCTIVE"), $List(tCase, 5), tClass _ "'s destructive flag")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass"), ..#PORT, tClass _ " reaches its target through the encryption port")
        Set tSecrets = $ClassMethod(tClass, "SecretBodyNames")
        Set tDeclared = $ClassMethod(tClass, "SecretArguments", "", .tIs)
        For tI = 1:1:$ListLength(tSecrets) {
            Do $$$AssertTrue($ListFind(tDeclared, $List(tSecrets, tI)), tClass _ "'s secret " _ $List(tSecrets, tI) _ " is its descriptor's declared secret")
        }
    }
}

/// <p>Every <code>ENCRYPTION.*</code> code answers its one sentence through the class and through
/// <class>OcuPilot.Api.Error</class>'s two dispatches, and each tool's state refusal is the sentence the
/// port answers for the same state.</p>
Method TestTheErrorCodesAnswerTheirSentences()
{
    Set tClass = "OcuPilot.Api.EncryptionError"
    Set tCodes = $ClassMethod(tClass, "Codes")
    Do $$$AssertEquals($ListLength(tCodes), 9, "nine codes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = $ClassMethod(tClass, "ReasonFor", tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ " answers it through the violation dispatch")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ " and through the tool dispatch")
    }
    Do $$$AssertEquals($ClassMethod(tClass, "ReasonFor", "ENCRYPTION.KEYFILE.KEYLEN"), "Choose 128, 192 or 256 bits.", "the key length sentence")
    Do $$$AssertEquals($ClassMethod(tClass, "ReasonFor", "ENCRYPTION.KEYFILE.ADMINNAME"), "Enter an administrator name of up to 50 characters.", "the administrator name sentence carries the limit")
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.EncryptionKeyFileAddAdmin", "REASONADMINTAKEN"), $Parameter(tClass, "REASONADMINTAKEN"), "the taken name's sentence is one sentence")
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.EncryptionKeyFileRemoveAdmin", "REASONADMINLAST"), $Parameter(tClass, "REASONADMINLAST"), "the last administrator's")
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.EncryptionKeyFileRemoveAdmin", "REASONADMINABSENT"), $Parameter(tClass, "REASONADMINABSENT"), "the absent administrator's")
    Do $$$AssertEquals($Parameter("OcuPilot.Screen.Tool.EncryptionKeyFileRemoveKey", "REASONKEYABSENT"), $Parameter(tClass, "REASONKEYABSENT"), "the absent key's")
    Set tRules = "OcuPilot.Area.Security.EncryptionRules"
    Do $$$AssertEquals($ClassMethod(tRules, "FieldCode", "AdminName", "OcuProbe187" _ $Char(256)), "ENCRYPTION.KEYFILE.ADMINNAME", "a name holding a character above $Char(255) breaks the name rule")
    Do $$$AssertEquals($ClassMethod(tRules, "FieldCode", "NewAdminPassword", "abc" _ $Char(300)), "ENCRYPTION.KEYFILE.PASSWORD", "and a password holding one the password rule")
    Do $$$AssertEquals($ClassMethod(tRules, "FieldCode", "AdminName", "OcuProbe187" _ $Char(255)), "", "while $Char(255) itself is accepted")
}

/// <p>AD-22, Decision 3: the five keys ship disabled in the baseline.</p>
/// <p>Mutation (Rule 19): set <code>security.encryptionkeyfile.removekey</code> to <code>true</code> in
/// <class>OcuPilot.Kernel.Governance.Baseline</class> -- this goes red.</p>
Method TestTheFiveKeysShipDisabled()
{
    For tKey = "security.encryptionkeyfile.addkey", "security.encryptionkeyfile.create", "security.encryptionkeyfile.removekey", "security.encryptionkeyfileadmins.addadministrator", "security.encryptionkeyfileadmins.removeadministrator" {
        Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed(tKey, .tListed)
        Do $$$AssertEquals(tListed _ " " _ tValue, "1 0", tKey _ " is listed and disabled")
    }
}

/// <p>AD-10, AD-53: <code>PROHIBITED.OCUPILOTKEY</code> answers its own parameter, which names no
/// caller.</p>
Method TestTheKeyRefusalIsItsParameterAndNamesNoCaller()
{
    Set tProhibited = "OcuPilot.Kernel.Proposal.Prohibited"
    Set tReason = $ClassMethod(tProhibited, "ReasonFor", $Parameter(tProhibited, "OCUPILOTKEY"))
    Do $$$AssertEquals(tReason, $Parameter(tProhibited, "OCUPILOTKEYREASON"), "the key refusal answers its parameter")
    Do $$$AssertTrue(tReason [ "depends on data this key encrypts", "the published sentence, written once in the set (OcuPilot.Test.Prohibited counts it)")
    Do $$$AssertTrue(($ZConvert(tReason, "L") '[ "the agent"), "naming no caller")
    Do $$$AssertTrue($ListFind($ClassMethod(tProhibited, "Codes"), "PROHIBITED.OCUPILOTKEY"), "and it is one of the set's codes")
}

/// <p>AD-59: each write branch the port would refuse renders one <code>comment</code> step carrying the
/// refusal's sentence and no call: a key file named by nothing, a root that is not an allowed directory,
/// a key length of 100, and a key file that is not there.</p>
Method TestTheScriptRendersARefusalAsOneComment()
{
    Set tRoot = $System.Util.ManagerDirectory()
    Kill tQuery
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.Encryption.KeyInFile", "DELETE", .tQuery, "", {})
    Do $$$AssertEquals(..Step(tSteps), "comment " _ ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS, "a key file named by nothing")
    Kill tQuery
    Set tQuery("keyfile") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("/ocuprobe187-not-allowed/", "probe.key"))
    Set tQuery("KeyId") = "X"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.Encryption.KeyInFile", "DELETE", .tQuery, "", {})
    Do $$$AssertEquals(..Step(tSteps), "comment " _ ##class(OcuPilot.Api.Error).#REASONPATHROOT, "a root that is not allowed")
    Kill tQuery
    Set tQuery("keyfile") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tRoot, "ocuprobe187-absent/probe.key"))
    Set tQuery("AdminName") = "OcuProbe187Admin"
    Set tQuery("KeyLen") = "100"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.Encryption.KeyInFile", "POST", .tQuery, {"AdminPassword": "<AdminPassword>"}, {})
    Do $$$AssertEquals(..Step(tSteps), "comment Choose 128, 192 or 256 bits.", "a key length the rules refuse")
    Set tQuery("KeyLen") = "256"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Security.Encryption.KeyInFile", "POST", .tQuery, {"AdminPassword": "<AdminPassword>"}, {})
    Do $$$AssertEquals(..Step(tSteps), "comment " _ ##class(OcuPilot.Api.Error).#REASONPATHNOFILE, "a key file that is not there")
}

/// <p>AD-21: <method>OcuPilot.Port.AdminPort.NamesKeyFile</method> names a <code>Security.Encryption.*</code>
/// call carrying a <code>file</code> query parameter in any case, a <code>File</code> body member or a
/// non-empty <code>DBEncStartKeyFile</code>, and nothing else.</p>
Method TestTheAdminPortNamesOnlyAKeyFileCall()
{
    Set tPort = "OcuPilot.Port.AdminPort"
    Kill tQuery
    Set tQuery("File") = "/x"
    Do $$$AssertEquals($ClassMethod(tPort, "NamesKeyFile", "Security.Encryption.KeyInFile", .tQuery, ""), 1, "a file query parameter in any case")
    Do $$$AssertEquals($ClassMethod(tPort, "NamesKeyFile", "Journal.File", .tQuery, ""), 0, "never on another endpoint")
    Kill tQuery
    Do $$$AssertEquals($ClassMethod(tPort, "NamesKeyFile", "Security.Encryption.File", .tQuery, {"File": "/x"}), 1, "a File body member")
    Do $$$AssertEquals($ClassMethod(tPort, "NamesKeyFile", "Security.Encryption.Settings", .tQuery, {"DBEncStartKeyFile": "/x"}), 1, "a non-empty DBEncStartKeyFile")
    Do $$$AssertEquals($ClassMethod(tPort, "NamesKeyFile", "Security.Encryption.Settings", .tQuery, {"DBEncStartKeyFile": ""}), 0, "but not an empty one")
    Do $$$AssertEquals($ClassMethod(tPort, "NamesKeyFile", "Security.Encryption.Key", .tQuery, {}), 0, "and nothing for a call naming no file")
}

/// <p>A pair list as <code>resource:permission</code>, comma-joined.</p>
ClassMethod Pairs(pPairs As %List) As %String
{
    Set tOut = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tPair = $List(pPairs, tI)
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $List(tPair, 1) _ ":" _ $List(tPair, 2)
    }
    Quit tOut
}

/// <p>A one-step script as <code>kind text</code>, or the step count.</p>
ClassMethod Step(pSteps As %DynamicArray) As %String
{
    If '$IsObject(pSteps) Quit "none"
    If pSteps.%Size() '= 1 Quit pSteps.%Size() _ " steps"
    Quit pSteps.%Get(0).%Get("kind") _ " " _ pSteps.%Get(0).%Get("text")
}

}
