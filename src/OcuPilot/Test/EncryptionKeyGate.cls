/// <p>Pins Story 18.22's pairs with least-privileged principals (B8; AD-8, AD-29): a principal holding
/// exactly Security's two pairs and <code>%Admin_FileSystemAccess:USE</code> reads both lists and activates
/// and deactivates database and data-element keys on both callers; one holding Security's two pairs alone
/// reads and deactivates and is refused every activation naming the file-system pair with zero port calls;
/// and one without <code>%Admin_Secure:USE</code> is refused both reads and every screen write naming it,
/// with zero port calls, and sees both side-bar entries unavailable. No principal withholds
/// <code>%DB_IRISSYS:READ</code>.</p>
/// <p>The in-process legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.EncryptionWriteGateProbe</class>), whose
/// <class>OcuPilot.Test.EncryptionSeamPort</class> is armed <code>activation</code>, so no real key is
/// activated; the read legs also run over the wire.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>ENCRYPTIONVARIABLE</parameter> reading
/// <code>1</code>, because the class creates and deletes probe users, roles and key files
/// (<class>OcuPilot.Test.EncryptionKeyProbe</class>) and sets the governance policy. Every probe object is
/// removed, and after each test the instance's encryption state reads as that test found it.</p>
Class OcuPilot.Test.EncryptionKeyGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the key file writes, set there alone too.</p>
Parameter ENCRYPTIONVARIABLE = "OCUPILOT_ALLOW_ENCRYPTION_CONFIG";

Parameter PROBE = "OcuPilot.Test.EncryptionKeyProbe";

Parameter DATABASE = "security.databaseencryption";

Parameter DATAELEMENT = "security.dataelementencryption";

/// <p>The principals, each <code>user:role:pairs</code> beyond the install namespace's code read: the
/// activator holds the activations' three pairs; the deactivator Security's two alone; the outsider the
/// file-system pair and the system database's read, without Security's resource.</p>
Parameter PRINCIPALS = "OCUPROBEACTGACTIVATOR:OCUPROBEACTGACTIVATORROLE:%Admin_Secure:U;%Admin_FileSystemAccess:U;%DB_IRISSYS:R,OCUPROBEACTGDEACTIVATOR:OCUPROBEACTGDEACTIVATORROLE:%Admin_Secure:U;%DB_IRISSYS:R,OCUPROBEACTGOUTSIDER:OCUPROBEACTGOUTSIDERROLE:%Admin_FileSystemAccess:U;%DB_IRISSYS:R";

/// <p>The four governance keys, enabled over the snapshot for every test.</p>
Parameter GOVERNANCEKEYS = "security.databaseencryption.activate,security.databaseencryption.deactivate,security.dataelementencryption.activate,security.dataelementencryption.deactivate";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EncryptionKeyGate creates and deletes users, roles and encryption key files on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#ENCRYPTIONVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set ..PreparedPassword = "OcuProbeActGate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "EncryptionFacts").%ToJSON()
    Do ##class(OcuPilot.Test.EncryptionSeamPort).Clear()
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
    Do ##class(OcuPilot.Test.EncryptionSeamPort).Clear()
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

/// <p>The activator reads both lists over the wire, and in process confirms the agent's database
/// activation, deactivates that key on the screen, and activates and deactivates a data-element key on the
/// screen; the deactivator deactivates on the screen and reads both lists. Each write reaches the seam.</p>
Method TestTheDeclaredPairsReadAndWrite()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "act-g.key", , , 256, "OCUPROBEACT G", .tKey), "a key file")
    For tIndex = 1, 2 {
        Set tUser = ..User(tIndex)
        For tScreen = ..#DATABASE, ..#DATAELEMENT {
            Do $$$AssertEquals(..WireRead(tScreen, tUser), "200 ", tScreen _ "'s read answers " _ tUser)
        }
    }
    Set tUser = ..User(1)
    Do ##class(OcuPilot.Test.EncryptionSeamPort).Arm("activation")
    Set tSC = $ClassMethod(tP, "KeyMint", "OcuPilot.Test.SeamDatabaseKeyActivate", "act-g.key", {"AdminName": ($Parameter(tP, "ADMIN"))}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "the agent's activation is minted for the activator (" _ tProblem _ ")")
    Set tPlan = []
    Do tPlan.%Push({"kind": "arm", "mode": "activation", "held": {"database": [], "dataElement": []}})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: "")), "secrets": {"AdminPassword": ($Parameter(tP, "PASSWORD"))}})
    Do tPlan.%Push({"kind": "action", "screen": (..#DATABASE), "body": {"action": "deactivate", "id": "SYSTEM", "values": {"KeyId": (tKey)}}})
    Do tPlan.%Push({"kind": "action", "screen": (..#DATAELEMENT), "body": (##class(OcuPilot.Test.EncryptionKeyWrite).Activation("act-g.key"))})
    Do tPlan.%Push({"kind": "action", "screen": (..#DATAELEMENT), "body": {"action": "deactivate", "id": "SYSTEM", "values": {"KeyId": (tKey)}}})
    Set tRun = ##class(OcuPilot.Test.EncryptionWriteGate).RunAs(tUser, tPlan)
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionWriteGate).Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tCase = $ListBuild(2, "Security.Encryption.File/ACTIVATE", "the agent's database activation confirm"), $ListBuild(3, "Security.Encryption.Key/DEACTIVATE", "the database deactivation"), $ListBuild(4, "Security.Encryption.File/ACTIVATE", "the data-element activation"), $ListBuild(5, "Security.Encryption.Key/DEACTIVATE", "the data-element deactivation") {
        Set tLeg = ##class(OcuPilot.Test.EncryptionWriteGate).Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: ""), "200 " _ $List(tCase, 2), $List(tCase, 3) _ " succeeds (" _ ##class(OcuPilot.Test.EncryptionWriteGate).LegText(tRun, $List(tCase, 1)) _ ")")
    }
    Set tUser = ..User(2)
    Set tPlan = []
    ; The read goes first: a screen action's output capture leaves the child's device closed.
    Do tPlan.%Push({"kind": "read", "descriptor": "OcuPilot.Screen.Descriptor.DatabaseEncryption"})
    Do tPlan.%Push({"kind": "entry", "descriptor": "OcuPilot.Screen.Descriptor.DataElementEncryption"})
    Do tPlan.%Push({"kind": "arm", "mode": "activation", "held": {"database": [{"Id": (tKey), "KeyLen": 256, "IsDefault": true}], "dataElement": [{"Id": (tKey)}]}})
    Do tPlan.%Push({"kind": "action", "screen": (..#DATABASE), "body": {"action": "deactivate", "id": "SYSTEM", "values": {"KeyId": (tKey)}}})
    Do tPlan.%Push({"kind": "action", "screen": (..#DATAELEMENT), "body": {"action": "deactivate", "id": "SYSTEM", "values": {"KeyId": (tKey)}}})
    Set tRun = ##class(OcuPilot.Test.EncryptionWriteGate).RunAs(tUser, tPlan)
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionWriteGate).Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 4, 5 {
        Set tLeg = ##class(OcuPilot.Test.EncryptionWriteGate).Leg(tRun, tI)
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: ""), "200 Security.Encryption.Key/DEACTIVATE", "the deactivator's leg " _ tI _ " deactivates (" _ ##class(OcuPilot.Test.EncryptionWriteGate).LegText(tRun, tI) _ ")")
    }
    For tI = 1, 2 {
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionWriteGate).LegText(tRun, tI), "200  calls=", "the deactivator's leg " _ tI _ " reads and opens the screen (" _ ##class(OcuPilot.Test.EncryptionWriteGate).LegText(tRun, tI) _ ")")
    }
}

/// <p>Without <code>%Admin_FileSystemAccess:USE</code>, both screens' activations and the agent's confirm
/// are refused naming the pair before any port call.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Screen.Tool.DatabaseKeyActivate.EXTRAPAIRS</parameter>
/// -- the database activation reaches the port and this goes red.</p>
Method TestWithoutTheFileSystemPairEveryActivationIsRefused()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "act-n.key", , , 256, "OCUPROBEACT N", .tKey), "a key file")
    Set tUser = ..User(2)
    Do ##class(OcuPilot.Test.EncryptionSeamPort).Arm("activation")
    Set tSC = $ClassMethod(tP, "KeyMint", "OcuPilot.Test.SeamDataElementKeyActivate", "act-n.key", {"AdminName": ($Parameter(tP, "ADMIN"))}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "the agent's activation is minted for the deactivator (" _ tProblem _ ")")
    Set tPlan = []
    Do tPlan.%Push({"kind": "arm", "mode": "activation", "held": {"database": [], "dataElement": []}})
    Do tPlan.%Push({"kind": "action", "screen": (..#DATABASE), "body": (##class(OcuPilot.Test.EncryptionKeyWrite).Activation("act-n.key"))})
    Do tPlan.%Push({"kind": "action", "screen": (..#DATAELEMENT), "body": (##class(OcuPilot.Test.EncryptionKeyWrite).Activation("act-n.key"))})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: "")), "secrets": {"AdminPassword": ($Parameter(tP, "PASSWORD"))}})
    Set tRun = ##class(OcuPilot.Test.EncryptionWriteGate).RunAs(tUser, tPlan)
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionWriteGate).Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 2:1:4 {
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionWriteGate).LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %Admin_FileSystemAccess:USE calls=0 writes=", "leg " _ tI _ " is refused naming the file-system pair before any port call")
    }
}

/// <p>Without <code>%Admin_Secure:USE</code>, both reads over the wire, and in process both screens'
/// activations and deactivations, are refused naming the pair with zero port calls, and both side-bar
/// entries are unavailable.</p>
Method TestWithoutSecuritysResourceEveryReadAndWriteIsRefused()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "act-o.key", , , 256, "OCUPROBEACT O", .tKey), "a key file")
    Set tUser = ..User(3)
    For tScreen = ..#DATABASE, ..#DATAELEMENT {
        Do $$$AssertEquals(..WireRead(tScreen, tUser), "403 %Admin_Secure:USE", tScreen _ "'s read is refused naming the pair")
    }
    Set tPlan = []
    Do tPlan.%Push({"kind": "arm", "mode": "activation", "held": {"database": [{"Id": (tKey), "KeyLen": 256, "IsDefault": true}], "dataElement": [{"Id": (tKey)}]}})
    Do tPlan.%Push({"kind": "action", "screen": (..#DATABASE), "body": (##class(OcuPilot.Test.EncryptionKeyWrite).Activation("act-o.key"))})
    Do tPlan.%Push({"kind": "action", "screen": (..#DATAELEMENT), "body": (##class(OcuPilot.Test.EncryptionKeyWrite).Activation("act-o.key"))})
    Do tPlan.%Push({"kind": "action", "screen": (..#DATABASE), "body": {"action": "deactivate", "id": "SYSTEM", "values": {"KeyId": (tKey)}}})
    Do tPlan.%Push({"kind": "action", "screen": (..#DATAELEMENT), "body": {"action": "deactivate", "id": "SYSTEM", "values": {"KeyId": (tKey)}}})
    Do tPlan.%Push({"kind": "entry", "descriptor": "OcuPilot.Screen.Descriptor.DatabaseEncryption"})
    Do tPlan.%Push({"kind": "entry", "descriptor": "OcuPilot.Screen.Descriptor.DataElementEncryption"})
    Set tRun = ##class(OcuPilot.Test.EncryptionWriteGate).RunAs(tUser, tPlan)
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionWriteGate).Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 2:1:5 {
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionWriteGate).LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %Admin_Secure:USE calls=0 writes=", "leg " _ tI _ " is refused naming Security's resource before any port call")
    }
    For tI = 6, 7 {
        Set tLeg = ##class(OcuPilot.Test.EncryptionWriteGate).Leg(tRun, tI)
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("failedPair"), 1: ""), "403 %Admin_Secure:USE", "side-bar entry " _ (tI - 5) _ " is unavailable, naming the pair")
    }
}

/// <p>The principal of entry <var>pIndex</var> of <parameter>PRINCIPALS</parameter>.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $Piece($Piece(..#PRINCIPALS, ",", pIndex), ":", 1)
}

/// <p><var>pScreen</var>'s read over the wire as <var>pUser</var>, answered as <code>status failedPair</code>.</p>
Method WireRead(pScreen As %String, pUser As %String) As %String
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/" _ pScreen _ "/read?maxRows=10", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Quit $Get(tStatus) _ " " _ ##class(OcuPilot.Test.EncryptionWriteGate).FailedPair($Get(tBody))
}

}
