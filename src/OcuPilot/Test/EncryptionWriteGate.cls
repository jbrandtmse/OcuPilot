/// <p>Pins Story 18.7's pairs with least-privileged principals (A5; AD-8, AD-29): a principal holding
/// exactly Encryption key files' three pairs reads both lists and creates, adds and removes
/// administrators and adds keys on both callers, over the wire and in process; the key removal also
/// needs <code>%Admin_Manage:USE</code>, refused by name with zero port calls without it; and a principal
/// holding Security's two pairs without <code>%Admin_FileSystemAccess:USE</code> is refused every read,
/// the Save and every write naming that pair, with zero port calls, and sees the side-bar entry
/// unavailable.</p>
/// <p>The in-process legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.EncryptionWriteGateProbe</class>), which reports what
/// <class>OcuPilot.Test.EncryptionSeamPort</class> was asked; the route legs run over the wire.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>ENCRYPTIONVARIABLE</parameter> reading
/// <code>1</code>, because the class creates and deletes probe users, roles and key files
/// (<class>OcuPilot.Test.EncryptionProbe</class>) and sets the governance policy. Every probe object is
/// removed, and after each test the instance's encryption state reads as that test found it.</p>
Class OcuPilot.Test.EncryptionWriteGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the key file writes, set there alone too.</p>
Parameter ENCRYPTIONVARIABLE = "OCUPILOT_ALLOW_ENCRYPTION_CONFIG";

Parameter PROBE = "OcuPilot.Test.EncryptionProbe";

Parameter KEYS = "security.encryptionkeyfile";

Parameter ADMINS = "security.encryptionkeyfileadmins";

/// <p>The principals, each <code>user:role:pairs</code> beyond the install namespace's code read: the
/// writer holds the screens' three pairs; the remover those and <code>%Admin_Manage:USE</code>; the
/// outsider Security's two pairs alone.</p>
Parameter PRINCIPALS = "OCUPROBE187GWRITER:OCUPROBE187GWRITERROLE:%Admin_Secure:U;%Admin_FileSystemAccess:U;%DB_IRISSYS:R,OCUPROBE187GREMOVER:OCUPROBE187GREMOVERROLE:%Admin_Secure:U;%Admin_FileSystemAccess:U;%DB_IRISSYS:R;%Admin_Manage:U,OCUPROBE187GNOFILES:OCUPROBE187GNOFILESROLE:%Admin_Secure:U;%DB_IRISSYS:R";

/// <p>The Save route, relative to the API base.</p>
Parameter CREATEPATH = "/encryption-key-file";

/// <p>The five governance keys, enabled over the snapshot for every test.</p>
Parameter GOVERNANCEKEYS = "security.encryptionkeyfile.create,security.encryptionkeyfile.addkey,security.encryptionkeyfile.removekey,security.encryptionkeyfileadmins.addadministrator,security.encryptionkeyfileadmins.removeadministrator";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The encryption facts before each test.</p>
Property PreparedFacts As %String(MAXLEN = "");

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedFacts = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#ENCRYPTIONVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EncryptionWriteGate creates and deletes users, roles and encryption key files on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#ENCRYPTIONVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set ..PreparedPassword = "OcuProbe187Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "EncryptionFacts").%ToJSON()
    Kill tSettings
    For tI = 1:1:$Length(..#GOVERNANCEKEYS, ",") Set tSettings($Piece(..#GOVERNANCEKEYS, ",", tI)) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Length(..#PRINCIPALS, ",") {
        Set tEntry = $Piece(..#PRINCIPALS, ",", tI)
        Set tSC = $ClassMethod(..#PROBE, "SeedPrincipal", $Piece(tEntry, ":", 1), $Piece(tEntry, ":", 2), $Translate($Piece(tEntry, ":", 3, 99), ";", ","), ..PreparedPassword)
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "SeedDirectory", .tCreated)
}

Method OnAfterOneTest() As %Status
{
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object, principals and key files included, is removed")
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

/// <p>A principal holding exactly the screens' three pairs reads both lists and creates a key file over
/// the wire, the Save answering JSON marked <code>no-store</code>; and in process the Save, the
/// administrator add and remove and the key add, and the agent's confirm of an add, each write through
/// the seam.</p>
Method TestTheScreensPairsReadAndWrite()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-g.key"), "a key file")
    Set tUser = ..User(1)
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tQuery = "?maxRows=10&root=" _ $ZConvert($ClassMethod(tP, "Root"), "O", "URL") _ "&path=" _ $ZConvert($ClassMethod(tP, "RelativeName", "probe-g.key"), "O", "URL")
    For tScreen = ..#KEYS, ..#ADMINS {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/" _ tScreen _ "/read" _ tQuery, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tScreen _ "'s read answers the writer: " _ $Extract(tBody, 1, 200))
    }
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"root": ($ClassMethod(tP, "Root")), "path": ($ClassMethod(tP, "RelativeName", "probe-w.key")), "AdminName": "OcuProbe187Admin", "AdminPassword": "OcuProbe187-Pass1", "KeyLen": 256, "Description": "OCUPROBE187 W"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "POST " _ ..#CREATEPATH _ " answers the writer: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CACHE-CONTROL")), "L"), "no-store", "marked no-store")
    Set tAnswer = $ClassMethod(tP, "Parsed", tBody)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("keyId"), 1: ""), $ClassMethod(tP, "Contents", "probe-w.key").%Get("keys").%Get(0).%Get("Id"), "answering the new key's id")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"root": ($ClassMethod(tP, "Root")), "path": ($ClassMethod(tP, "RelativeName", "probe-w.key")), "AdminName": "OcuProbe187Admin", "AdminPassword": "OcuProbe187-Pass1", "KeyLen": 256, "Extra": "x"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(tP, "Refusal", tBody), "400 Extra:PORT.FIELD.UNEXPECTED", "a key outside the form's is refused")
    Set tId = $ClassMethod(tP, "KeyFileId", "probe-g.key")
    Set tSC = $ClassMethod(tP, "Mint", "OcuPilot.Screen.Tool.EncryptionKeyFileAddKey", "probe-g.key", {"AdminName": "OcuProbe187Admin", "KeyLen": 128, "Description": "OCUPROBE187 GA"}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "the agent's add is minted for the writer (" _ tProblem _ ")")
    Set tPlan = []
    Do tPlan.%Push({"kind": "save", "body": {"root": ($ClassMethod(tP, "Root")), "path": ($ClassMethod(tP, "RelativeName", "probe-s.key")), "AdminName": "OcuProbe187Admin", "AdminPassword": "OcuProbe187-Pass1", "KeyLen": 192, "Description": "OCUPROBE187 S"}})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: "")), "secrets": {"AdminPassword": "OcuProbe187-Pass1"}})
    Do tPlan.%Push({"kind": "action", "screen": (..#ADMINS), "body": {"action": "addadministrator", "id": (tId), "values": {"OldAdminName": "OcuProbe187Admin", "NewAdminName": "OcuProbe187Admin2", "OldAdminPassword": "OcuProbe187-Pass1", "NewAdminPassword": "OcuProbe187-Pass2"}}})
    Do tPlan.%Push({"kind": "action", "screen": (..#ADMINS), "body": {"action": "removeadministrator", "id": (tId), "values": {"Admin": "OCUPROBE187ADMIN2"}}})
    Do tPlan.%Push({"kind": "action", "screen": (..#KEYS), "body": {"action": "addkey", "id": (tId), "values": {"AdminName": "OcuProbe187Admin", "KeyLen": "256", "Description": "OCUPROBE187 GK", "AdminPassword": "OcuProbe187-Pass1"}}})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tCase = $ListBuild(1, 201, "Security.Encryption.File/POST", "the Save"), $ListBuild(2, 200, "Security.Encryption.KeyInFile/POST", "the agent's key add confirm"), $ListBuild(3, 200, "Security.Encryption.AdminInFile/POST", "the administrator add"), $ListBuild(4, 200, "Security.Encryption.AdminInFile/DELETE", "the administrator remove"), $ListBuild(5, 200, "Security.Encryption.KeyInFile/POST", "the key add") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: ""), $List(tCase, 2) _ " " _ $List(tCase, 3), $List(tCase, 4) _ " succeeds (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
    }
    Do $$$AssertEquals($ClassMethod(tP, "Contents", "probe-g.key").%Get("keys").%Size(), 3, "the file holds the two added keys beside its own")
}

/// <p>The key removal needs <code>%Admin_Manage:USE</code> beyond the screens' pairs: refused by name with
/// zero port calls on both callers without it, and written on both callers with it.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Screen.Tool.EncryptionKeyFileRemoveKey.EXTRAPAIRS</parameter>
/// -- the writer's removal reaches the port and this goes red.</p>
Method TestTheKeyRemovalNeedsAdminManage()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-m.key", , , 256, "OCUPROBE187 M", .tKey), "a key file")
    Set tId = $ClassMethod(tP, "KeyFileId", "probe-m.key")
    Set tAdded = $ClassMethod(tP, "Run", "Security.Encryption.KeyInFile", "POST", {"keyfile": (tId), "AdminName": "OcuProbe187Admin", "KeyLen": "128", "Description": "OCUPROBE187 M2"}, {"AdminPassword": "OcuProbe187-Pass1"}, "OcuPilot.Port.EncryptionPort")
    ; A third key, so the file never reads as holding none (the vendor's list then fails and logs).
    Do $ClassMethod(tP, "Run", "Security.Encryption.KeyInFile", "POST", {"keyfile": (tId), "AdminName": "OcuProbe187Admin", "KeyLen": "128", "Description": "OCUPROBE187 M3"}, {"AdminPassword": "OcuProbe187-Pass1"}, "OcuPilot.Port.EncryptionPort")
    Set tSecond = ""
    Set tIterator = $ClassMethod(tP, "Contents", "probe-m.key").%Get("keys").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Description") = "OCUPROBE187 M2" Set tSecond = tRow.%Get("Id")
    }
    Do $$$AssertNotEquals(tSecond, "", "with a second key, for the screen's removal (" _ tAdded.%Get("http") _ ")")
    For tCase = $ListBuild(1, "403 AUTH.NOPRIVILEGE %Admin_Manage:USE calls=0 writes=", "the writer"), $ListBuild(2, "200  calls=", "the remover") {
        Set tUser = ..User($List(tCase, 1))
        Set tSC = $ClassMethod(tP, "Mint", "OcuPilot.Screen.Tool.EncryptionKeyFileRemoveKey", "probe-m.key", {"KeyId": (tKey)}, .tProposal, .tHttp, .tProblem, tUser)
        Do $$$AssertStatusOK(tSC, "the agent's removal is minted for " _ tUser _ " (" _ tProblem _ ")")
        Set tPlan = []
        Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
        Do tPlan.%Push({"kind": "action", "screen": (..#KEYS), "body": {"action": "removekey", "id": (tId), "values": {"KeyId": (tSecond)}}})
        Set tRun = ..RunAs(tUser, tPlan)
        Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
        If $List(tCase, 1) = 1 {
            For tI = 1:1:2 {
                Do $$$AssertEquals(..LegText(tRun, tI), $List(tCase, 2), $List(tCase, 3) _ "'s leg " _ tI _ " is refused naming the pair before any port call")
            }
            Do $$$AssertEquals($ClassMethod(tP, "Contents", "probe-m.key").%Get("keys").%Size(), 3, "every key stays")
        } Else {
            For tI = 1:1:2 {
                Set tLeg = ..Leg(tRun, tI)
                Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: ""), "200 Security.Encryption.KeyInFile/DELETE", "the remover's " _ $Select(tI = 1: "confirm", 1: "screen removal") _ " removes its key (" _ ..LegText(tRun, tI) _ ")")
            }
            Do $$$AssertEquals($ClassMethod(tP, "Contents", "probe-m.key").%Get("keys").%Size(), 1, "and the third key stays")
        }
    }
}

/// <p>Without <code>%Admin_FileSystemAccess:USE</code>: both reads and the Save over the wire, and in
/// process the Save, every screen action and the agent's confirm, are refused 403 naming the pair with
/// zero port calls, and the side-bar entry's own gate names it.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_FileSystemAccess:USE</code> from
/// <method>OcuPilot.Screen.Tool.EncryptionKeyFileWrite.PrivilegePairs</method> by declaring the descriptor's
/// pairs without it -- the confirm reaches the port and this goes red.</p>
Method TestWithoutTheFileSystemPairEveryReadAndWriteIsRefused()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-n.key", , , 256, "OCUPROBE187 N", .tKey), "a key file")
    Set tBefore = $ClassMethod(tP, "Contents", "probe-n.key").%ToJSON()
    Set tUser = ..User(3)
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tQuery = "?maxRows=10&root=" _ $ZConvert($ClassMethod(tP, "Root"), "O", "URL") _ "&path=" _ $ZConvert($ClassMethod(tP, "RelativeName", "probe-n.key"), "O", "URL")
    For tScreen = ..#KEYS, ..#ADMINS {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/" _ tScreen _ "/read" _ tQuery, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
        Do $$$AssertEquals(tStatus _ " " _ ..FailedPair(tBody), "403 %Admin_FileSystemAccess:USE", tScreen _ "'s read is refused naming the pair: " _ $Extract(tBody, 1, 200))
    }
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"root": ($ClassMethod(tP, "Root")), "path": ($ClassMethod(tP, "RelativeName", "probe-x.key")), "AdminName": "OcuProbe187Admin", "AdminPassword": "OcuProbe187-Pass1", "KeyLen": 256}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..FailedPair(tBody), "403 %Admin_FileSystemAccess:USE", "the Save is refused naming the pair: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tId = $ClassMethod(tP, "KeyFileId", "probe-n.key")
    Set tSC = $ClassMethod(tP, "Mint", "OcuPilot.Screen.Tool.EncryptionKeyFileAddKey", "probe-n.key", {"AdminName": "OcuProbe187Admin", "KeyLen": 128, "Description": "OCUPROBE187 NA"}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "the agent's add is minted for the outsider (" _ tProblem _ ")")
    Set tPlan = []
    Do tPlan.%Push({"kind": "save", "body": {"root": ($ClassMethod(tP, "Root")), "path": ($ClassMethod(tP, "RelativeName", "probe-y.key")), "AdminName": "OcuProbe187Admin", "AdminPassword": "OcuProbe187-Pass1", "KeyLen": 256}})
    Do tPlan.%Push({"kind": "action", "screen": (..#ADMINS), "body": {"action": "addadministrator", "id": (tId), "values": {"OldAdminName": "OcuProbe187Admin", "NewAdminName": "OcuProbe187Admin2", "OldAdminPassword": "OcuProbe187-Pass1", "NewAdminPassword": "OcuProbe187-Pass2"}}})
    Do tPlan.%Push({"kind": "action", "screen": (..#ADMINS), "body": {"action": "removeadministrator", "id": (tId), "values": {"Admin": "OCUPROBE187ADMIN"}}})
    Do tPlan.%Push({"kind": "action", "screen": (..#KEYS), "body": {"action": "addkey", "id": (tId), "values": {"AdminName": "OcuProbe187Admin", "KeyLen": "256", "Description": "OCUPROBE187 NK", "AdminPassword": "OcuProbe187-Pass1"}}})
    Do tPlan.%Push({"kind": "action", "screen": (..#KEYS), "body": {"action": "removekey", "id": (tId), "values": {"KeyId": (tKey)}}})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: "")), "secrets": {"AdminPassword": "OcuProbe187-Pass1"}})
    Do tPlan.%Push({"kind": "entry", "descriptor": "OcuPilot.Screen.Descriptor.EncryptionKeyFile"})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1:1:6 {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %Admin_FileSystemAccess:USE calls=0 writes=", "leg " _ tI _ " is refused naming the file-system pair before any port call")
    }
    Set tLeg = ..Leg(tRun, 7)
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("failedPair"), 1: ""), "403 %Admin_FileSystemAccess:USE", "the side-bar entry is unavailable, naming the pair")
    Do $$$AssertEquals($ClassMethod(tP, "Contents", "probe-n.key").%ToJSON(), tBefore, "and the file is unchanged")
    Do $$$AssertEquals($ClassMethod(tP, "FileState", "probe-x.key") _ $ClassMethod(tP, "FileState", "probe-y.key"), "0|0|", "and no file was created")
}

/// <p>The principal of entry <var>pIndex</var> of <parameter>PRINCIPALS</parameter>.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $Piece($Piece(..#PRINCIPALS, ",", pIndex), ":", 1)
}

/// <p>An envelope's <code>detail.failedPair</code>.</p>
ClassMethod FailedPair(pText As %String) As %String
{
    Set tAnswer = ##class(OcuPilot.Test.EncryptionProbe).Parsed(pText)
    If '$IsObject(tAnswer) || '$IsObject(tAnswer.%Get("detail")) Quit ""
    Quit tAnswer.%Get("detail").%Get("failedPair")
}

/// <p>Run <class>OcuPilot.Test.EncryptionWriteGateProbe</class> as <var>pUser</var> over <var>pPlan</var>
/// in a child process and answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.EncryptionWriteGateProbe).Run($Job, pUser, tPlan)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 300)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 300 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>Who the child ran as, <code>username loggedIn</code>, or its error.</p>
ClassMethod Ran(pRun As %DynamicObject) As %String
{
    If '$IsObject(pRun) Quit "no answer"
    If pRun.%IsDefined("error") Quit pRun.%Get("error")
    Quit pRun.%Get("username") _ " " _ pRun.%Get("loggedIn")
}

/// <p>Step <var>pIndex</var> (from 1) of the child's answer <var>pRun</var>, or <code>""</code>.</p>
ClassMethod Leg(pRun As %DynamicObject, pIndex As %Integer) As %DynamicObject
{
    If '$IsObject(pRun) || (pRun.%GetTypeOf("steps") '= "array") Quit ""
    Quit pRun.%Get("steps").%Get(pIndex - 1)
}

/// <p>Step <var>pIndex</var> as <code>http code failedPair calls=n writes=w</code>.</p>
ClassMethod LegText(pRun As %DynamicObject, pIndex As %Integer) As %String
{
    Set tLeg = ..Leg(pRun, pIndex)
    If '$IsObject(tLeg) Quit "no leg"
    If tLeg.%Get("http") = 200 Quit "200  calls="
    Quit tLeg.%Get("http") _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair") _ " calls=" _ tLeg.%Get("calls") _ " writes=" _ tLeg.%Get("writes")
}

}
