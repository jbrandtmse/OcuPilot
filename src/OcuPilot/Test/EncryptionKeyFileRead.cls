/// <p>Pins Story 18.7's two key-file reads (A1, A5; AD-21, AD-36): the screen's declared reads and the
/// read tools answer the same rows of a seeded key file; missing criteria, a missing file and a file
/// that is not a key file are refused; a key file whose last key was removed reads as holding none; a
/// raw <code>file</code> sent to <class>OcuPilot.Port.AdminPort</class> is refused before any vendor
/// call; and no answer carries key material.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class seeds probe key files
/// under <code>&lt;ManagerDirectory&gt;ocuprobe187/</code> (<class>OcuPilot.Test.EncryptionProbe</class>),
/// removed before all, after each and after all. After each test the instance's encryption state reads
/// as that test found it.</p>
Class OcuPilot.Test.EncryptionKeyFileRead Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ENCRYPTION_CONFIG";

Parameter PROBE = "OcuPilot.Test.EncryptionProbe";

Parameter KEYSSCREEN = "OcuPilot.Screen.Descriptor.EncryptionKeyFile";

Parameter ADMINSSCREEN = "OcuPilot.Screen.Descriptor.EncryptionKeyFileAdminList";

/// <p>The encryption facts before each test.</p>
Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EncryptionKeyFileRead creates encryption key files on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "EncryptionFacts").%ToJSON()
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Quit $ClassMethod(..#PROBE, "SeedDirectory", .tCreated)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "the probe directory and every probe object are removed")
    Set tFacts = $ClassMethod(..#PROBE, "EncryptionFacts")
    Do $$$AssertTrue('tFacts.%IsDefined("error") && (..PreparedFacts '[ """error"":"), "the encryption facts were read whole before and after the test")
    Do $$$AssertEquals(tFacts.%ToJSON(), ..PreparedFacts, "no key is activated and no encryption setting moved")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>A1: the keys screen's read and <code>security.encryptionkeyfile.read</code>, and the
/// administrators screen's read and <code>security.encryptionkeyfileadmins.read</code>, answer the same
/// rows of one seeded file: one administrator, one key with its identifier, bit length and description,
/// and no other member; and the write tools' fresh read (<code>KEYFILE</code>) answers the same rows.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.EncryptionPort.Keys</method> adds a key's raw material
/// member to each key row -- the screen reads project it away, and the fresh read leg goes red.</p>
Method TestBothReadsAnswerTheSameRowsOnScreenAndTool()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-r.key", , , 256, "OCUPROBE187 R", .tKey), "a key file with one 256-bit key")
    Kill tCriteria
    Set tCriteria("root") = $ClassMethod(tP, "Root")
    Set tCriteria("path") = $ClassMethod(tP, "RelativeName", "probe-r.key")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#KEYSSCREEN, 100, .tKeys, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the keys screen's read answers")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#ADMINSSCREEN, 100, .tAdmins, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the administrators screen's read answers")
    Do $$$AssertEquals($Select($IsObject($Get(tKeys)): tKeys.%Get("rows").%ToJSON(), 1: ""), "[{""Id"":""" _ tKey _ """,""KeyLen"":256,""Description"":""OCUPROBE187 R""}]", "one key with its identifier, bit length and description, and no other member")
    Do $$$AssertEquals($Select($IsObject($Get(tAdmins)): tAdmins.%Get("rows").%ToJSON(), 1: ""), "[{""Name"":""OCUPROBE187ADMIN""}]", "one administrator")
    For tCase = $ListBuild("security.encryptionkeyfile.read", "keys"), $ListBuild("security.encryptionkeyfileadmins.read", "admins") {
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($List(tCase, 1), .tTool)
        Do $$$AssertTrue($IsObject($Get(tTool)), $List(tCase, 1) _ " is registered")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"root": (tCriteria("root")), "path": (tCriteria("path"))}, 200, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ " answers")
        Set tScreen = $Select($List(tCase, 2) = "keys": tKeys, 1: tAdmins)
        Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("rows").%ToJSON(), 1: ""), tScreen.%Get("rows").%ToJSON(), $List(tCase, 1) _ " answers the screen's rows")
    }
    Set tFresh = $ClassMethod(tP, "Run", "Security.Encryption.KeyInFile", "KEYFILE", {"root": (tCriteria("root")), "path": (tCriteria("path"))}, "", "OcuPilot.Port.EncryptionPort")
    Set tFreshKeys = $Select($IsObject(tFresh.%Get("result")): tFresh.%Get("result").%Get("Keys"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tFreshKeys): tFreshKeys.%ToJSON(), 1: ""), tKeys.%Get("rows").%ToJSON(), "the write tools' fresh read answers the same keys, and no other member")
}

/// <p>A1: missing criteria are 400 <code>READ.CRITERION</code>, a missing file 400
/// <code>PATH.NOFILE</code> on <code>path</code>, and a text file 422
/// <code>ENCRYPTION.KEYFILE.UNREADABLE</code> on <code>path</code>, decided without a logged vendor
/// failure.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.EncryptionPort.List</method> hands the vendor the
/// caller's <code>path</code> as its <code>file</code> unresolved -- the missing-file leg goes red.</p>
Method TestMissingCriteriaAMissingFileAndATextFileAreRefused()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedTextFile", "not-a-key.txt"), "a text file")
    Kill tCriteria
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#KEYSSCREEN, 100, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ ..Code($Get(tFault)), "400 READ.CRITERION", "no criteria is refused")
    For tCase = $ListBuild("missing.key", "400 path:PATH.NOFILE"), $ListBuild("not-a-key.txt", "422 path:ENCRYPTION.KEYFILE.UNREADABLE") {
        Kill tCriteria
        Set tCriteria("root") = $ClassMethod(tP, "Root")
        Set tCriteria("path") = $ClassMethod(tP, "RelativeName", $List(tCase, 1))
        Set tMessages = $ClassMethod(tP, "LineCount", "messages.log")
        For tScreen = ..#KEYSSCREEN, ..#ADMINSSCREEN {
            Set tSC = ##class(OcuPilot.Screen.Read).Execute(tScreen, 100, .tResult, .tHttp, .tFault, .tCriteria)
            Do $$$AssertEquals(+$Get(tHttp) _ " " _ ..Code($Get(tFault)), $List(tCase, 2), $List(tCase, 1) _ " is refused on " _ tScreen)
        }
        Do $$$AssertEquals($ClassMethod(tP, "LinesAfter", "messages.log", tMessages).%Size(), 0, "with no line logged")
    }
}

/// <p>A key file whose last key was removed (the vendor allows it) reads as holding no key, with its
/// administrators listed.</p>
Method TestAKeyFileWithNoKeyReadsAsHoldingNone()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-z.key", , , 128, "OCUPROBE187 Z", .tKey), "a key file")
    Do $$$AssertStatusOK($ClassMethod(tP, "RemoveFromFile", "probe-z.key", tKey), "whose one key is removed")
    Kill tCriteria
    Set tCriteria("root") = $ClassMethod(tP, "Root")
    Set tCriteria("path") = $ClassMethod(tP, "RelativeName", "probe-z.key")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#KEYSSCREEN, 100, .tKeys, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tKeys)): tKeys.%Get("rows").%ToJSON(), 1: ""), "200 []", "the keys read answers no row")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#ADMINSSCREEN, 100, .tAdmins, .tHttp, .tFault, .tCriteria)
    Do $$$AssertEquals($Select($IsObject($Get(tAdmins)): tAdmins.%Get("rows").%Size(), 1: 0), 1, "and the administrator is listed")
}

/// <p>AD-2: a key list answered with a fault other than the vendor's no-key refusal fails the screen's
/// read and the tools' fresh read alike; it never reads as a key file holding no key.</p>
/// <p>Mutation (Rule 19): read every 500 on the key list as no key in
/// <method>OcuPilot.Port.EncryptionPort.Keys</method> -- both legs answer 200 and this goes red.</p>
Method TestAKeyListThatFailsOtherwiseFailsTheRead()
{
    Set tP = ..#PROBE
    Set tSeam = "OcuPilot.Test.EncryptionSeamPort"
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-f.key"), "a key file")
    Do $ClassMethod(tSeam, "Clear")
    Do $ClassMethod(tSeam, "Arm", "keysfail")
    For tType = "LIST", "KEYFILE" {
        Kill tQuery
        Set tQuery("root") = $ClassMethod(tP, "Root")
        Set tQuery("path") = $ClassMethod(tP, "RelativeName", "probe-f.key")
        Set tSC = $ClassMethod(tSeam, "Invoke", "Security.Encryption.KeyInFile", tType, .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $$$ISERR(tSC), "500 1", tType _ ": the read fails rather than answering no key")
    }
    Do $ClassMethod(tSeam, "Clear")
}

/// <p>A5, AD-21: a raw <code>file</code> query parameter, any case, a <code>File</code> body member or a
/// <code>DBEncStartKeyFile</code> sent to <class>OcuPilot.Port.AdminPort</class>, or to
/// <class>OcuPilot.Port.EncryptionPort</class> itself, is refused 400 <code>PATH.NAME</code> before the
/// endpoint runs. Both ports resolve every endpoint to <class>OcuPilot.Test.EndpointFixture</class>, so no
/// vendor endpoint runs even if a guard regresses: the activation, deactivation and settings routes are
/// no test's to reach.</p>
/// <p>Mutation (Rule 19): drop the <parameter>OcuPilot.Port.AdminPort.PATHRESOLVED</parameter> guard from
/// <method>OcuPilot.Port.AdminPort.InvokeLocated</method>, or the <code>NamesKeyFile</code> refusal from
/// <method>OcuPilot.Port.EncryptionPort.Invoke</method> -- that port's legs go red.</p>
Method TestARawFileToTheAdminPortIsRefusedBeforeTheVendor()
{
    Set tP = ..#PROBE
    Do $$$AssertStatusOK($ClassMethod(tP, "SeedKeyFile", "probe-f.key"), "a key file")
    Set tFile = $ClassMethod(tP, "FilePath", "probe-f.key")
    For tPort = "OcuPilot.Test.PortFixture", "OcuPilot.Test.EncryptionEndpointPort" {
        For tCase = $ListBuild("Security.Encryption.KeyInFile", "LIST", "file", ""), $ListBuild("Security.Encryption.AdminInFile", "LIST", "FILE", ""), $ListBuild("Security.Encryption.File", "POST", "", "File"), $ListBuild("Security.Encryption.Settings", "PUT", "", "DBEncStartKeyFile") {
            Kill tQuery
            Set tBody = ""
            If $List(tCase, 3) '= "" Set tQuery($List(tCase, 3)) = tFile
            If $List(tCase, 4) '= "" {
                Set tBody = {}
                Do tBody.%Set($List(tCase, 4), $ClassMethod(tP, "FilePath", "probe-raw.key"), "string")
            }
            Do ##class(OcuPilot.Test.PortFixture).Clear()
            Do ##class(OcuPilot.Test.EndpointFixture).Clear()
            Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.EndpointFixture")
            Set tSC = $ClassMethod(tPort, "Invoke", $List(tCase, 1), $List(tCase, 2), .tQuery, tBody, .tResult, .tHttp, .tFault)
            Do $$$AssertEquals(+$Get(tHttp) _ " " _ ..Code($Get(tFault)), "400 PATH.NAME", tPort _ ": " _ $List(tCase, 1) _ " " _ $List(tCase, 2) _ " with a raw file is refused")
            Do $$$AssertEquals(##class(OcuPilot.Test.EndpointFixture).Recorded("constructed"), "", tPort _ ": before any endpoint is built")
        }
    }
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.EndpointFixture).Clear()
}

/// <p>A fault's code, or the first violation's <code>field:code</code>.</p>
ClassMethod Code(pFault) As %String
{
    If '$IsObject(pFault) Quit ""
    Set tDetail = pFault.%Get("detail")
    If $IsObject(tDetail) && (tDetail.%GetTypeOf("violations") = "array") && (tDetail.%Get("violations").%Size() > 0) Quit tDetail.%Get("violations").%Get(0).%Get("field") _ ":" _ tDetail.%Get("violations").%Get(0).%Get("code")
    Quit pFault.%Get("code")
}

}
