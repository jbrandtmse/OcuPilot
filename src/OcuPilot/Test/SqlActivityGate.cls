/// <p>Pins <class>OcuPilot.Port.SqlActivityPort</class>'s gate and its statement text against real
/// principals (AD-8, AD-29, AD-35, Story 19.10), each reading a probe statement the suite's own account
/// runs in <code>USER</code>: a principal holding exactly the port's pairs lists it with its text
/// withheld and writes no <code>Protect</code> audit row; a principal missing either pair is refused
/// 403 naming it, and the side bar lists SQL activity unavailable naming it; a principal adding READ on
/// <code>USER</code>'s database still reads the text withheld (the vendor's #921); and one adding
/// <code>%Development:USE</code> as well reads the text.</p>
/// <p>The reads run in a child process (<method>OcuPilot.Test.SqlActivityProbe.Probe</method>) that logs
/// in as the principal, so this process never changes identity.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace and
/// <parameter>PRINCIPALSVARIABLE</parameter> reading <code>1</code>, because it creates five users and
/// roles named <code>OcuP1910*</code>, each also holding READ on the install namespace's code database,
/// as every caller must. The probe job is stopped after every test, and the principals are removed after
/// the last.</p>
Class OcuPilot.Test.SqlActivityGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms its throwaway principals.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.SqlActivityProbe";

Parameter NAMESPACE = "USER";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the grants it holds beyond the code database's
/// READ&gt;</code>, separated by <code>;</code>.</p>
Parameter PRINCIPALS = "OcuP1910Exact:%Admin_Operate:U,%DB_IRISSYS:R;OcuP1910NoOperate:%DB_IRISSYS:R;OcuP1910NoSys:%Admin_Operate:U;OcuP1910Read:%Admin_Operate:U,%DB_IRISSYS:R,%DB_USER:R;OcuP1910Dev:%Admin_Operate:U,%DB_IRISSYS:R,%DB_USER:R,%Development:U";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

/// <p>The probe statement's literal and pid for the running test.</p>
Property PreparedLiteral As %String;

Property PreparedPid As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedLiteral = ""
    Set ..PreparedPid = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlActivityGate creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#PRINCIPALSVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP1910Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..#PRINCIPALS, ..PreparedPassword)
    If $$$ISERR(tSC) Quit tSC
    Quit ..ReadBack()
}

/// <p>Remove the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "StopAll")
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipals", ..#PRINCIPALS))
}

/// <p>A probe statement runs in <code>USER</code> as the suite's account, its literal fresh.</p>
Method OnBeforeOneTest() As %Status
{
    Set ..PreparedLiteral = "OcuSeedGate1910" _ (10000000 + $Random(90000000))
    Set tSC = $ClassMethod(..#PROBE, "Start", ..#NAMESPACE, ..PreparedLiteral, "OcuSecretProbe1910" _ (10000000 + $Random(90000000)), .tPid)
    Set ..PreparedPid = $Get(tPid)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "StopAll"), "the probe job is stopped")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Running"), 0, "and none is left running")
    Set ..PreparedPid = ""
    Quit $$$OK
}

/// <p>AC1 and AC3: the principal holding exactly the port's pairs lists another account's probe in
/// <code>USER</code>, its text withheld because it holds no READ on <code>USER</code>'s database, and
/// its read writes no <code>Protect</code> audit row because the vendor's text call is never made.</p>
/// <p>Mutation (Rule 19): skip the pre-check in
/// <method>OcuPilot.Port.SqlActivityPort.StatementText</method> -- the vendor's call raises
/// <code>&lt;PROTECT&gt;</code>, the read fails and the audit leg goes red.</p>
Method TestTheExactPairsListWithTheTextWithheld()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ProtectCount", .tBefore), "the Protect rows are counted")
    Set tProbe = ..ProbeAs("OcuP1910Exact")
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username") _ "|" _ tProbe.%Get("http"), "|OcuP1910Exact|200", "the principal reads: " _ tProbe.%ToJSON())
    Set tRow = tProbe.%Get("row")
    Do $$$AssertTrue($IsObject(tRow), "the probe is a row")
    If $IsObject(tRow) {
        Do $$$AssertEquals(tRow.Namespace _ "|" _ tRow.UserName _ "|" _ tRow.Statement, ..#NAMESPACE _ "|" _ $Username _ "|", "another account's statement in USER, its text withheld")
    }
    Do $$$AssertTrue(tProbe.%Get("rows") '[ ..PreparedLiteral, "no row carries the probe's text")
    Do $$$AssertEquals(tProbe.screen.allowed, 1, "and the side bar lists SQL activity available")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ProtectCount", .tAfter), "the Protect rows are counted again")
    Do $$$AssertEquals(tAfter - tBefore, 0, "the read wrote no Protect audit row")
}

/// <p>AC2: a principal missing <code>%Admin_Operate:USE</code>, or <code>%DB_IRISSYS:READ</code>, is
/// refused 403 <code>PORT.ACCESSDENIED</code> naming it, and the side bar lists SQL activity
/// unavailable naming it.</p>
/// <p>Mutation (Rule 19): drop <code>%DB_IRISSYS:READ</code> from
/// <parameter>OcuPilot.Port.SqlActivityPort.PAIRS</parameter> -- the NoSys principal reads and this
/// goes red.</p>
Method TestEachMissingPairIsRefusedByName()
{
    For tCase = $ListBuild("OcuP1910NoOperate", "%Admin_Operate:USE"), $ListBuild("OcuP1910NoSys", "%DB_IRISSYS:READ") {
        Set tUser = $List(tCase, 1)
        Set tPair = $List(tCase, 2)
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
        Do $$$AssertEquals(tProbe.%Get("http") _ " " _ tProbe.%Get("code") _ " " _ tProbe.%Get("failedPair"), "403 " _ ##class(OcuPilot.Api.Error).#PORTACCESSDENIED _ " " _ tPair, tUser _ ": the read is refused naming the pair")
        Do $$$AssertEquals(tProbe.%Get("rows") _ "|" _ tProbe.%Get("row"), "|", tUser _ ": and answers no row")
        Do $$$AssertEquals(tProbe.screen.allowed _ " " _ tProbe.screen.failedPair, "0 " _ tPair, tUser _ ": the side bar lists SQL activity unavailable naming it")
    }
}

/// <p>AC3: with READ on <code>USER</code>'s database and without <code>%Development:USE</code>, another
/// account's text is withheld (the vendor's #921), still with no <code>Protect</code> audit row; with
/// <code>%Development:USE</code> as well, the text is shown, carrying the probe's literal.</p>
/// <p>Mutation (Rule 19): map #921 to a failure in
/// <method>OcuPilot.Port.SqlActivityPort.StatementText</method> -- the Read principal's read fails and
/// this goes red.</p>
Method TestTheTextNeedsDevelopmentAndTheDatabase()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ProtectCount", .tBefore), "the Protect rows are counted")
    Set tProbe = ..ProbeAs("OcuP1910Read")
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username") _ "|" _ tProbe.%Get("http"), "|OcuP1910Read|200", "the principal holding USER's READ reads: " _ tProbe.%ToJSON())
    Set tRow = tProbe.%Get("row")
    Do $$$AssertTrue($IsObject(tRow) && (tRow.Statement = ""), "its text is withheld")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ProtectCount", .tAfter), "the Protect rows are counted again")
    Do $$$AssertEquals(tAfter - tBefore, 0, "the withheld text wrote no Protect audit row")
    Set tProbe = ..ProbeAs("OcuP1910Dev")
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username") _ "|" _ tProbe.%Get("http"), "|OcuP1910Dev|200", "the principal holding %Development:USE reads: " _ tProbe.%ToJSON())
    Set tRow = tProbe.%Get("row")
    Do $$$AssertTrue($IsObject(tRow) && (tRow.Statement [ ..PreparedLiteral), "and its text is shown")
}

/// <p>Run <method>OcuPilot.Test.SqlActivityProbe.Probe</method> as <var>pUser</var> in a child process
/// and answer what it signalled, or an object carrying <code>error</code>.</p>
Method ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.SqlActivityProbe).Probe($Job, pUser, ..PreparedPid)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 60)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 60 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>Read the decisive grants back from the instance.</p>
Method ReadBack() As %Status
{
    Set tSC = $$$OK
    For tCase = $ListBuild("OcuP1910Exact", "%Admin_Operate", "USE", 1), $ListBuild("OcuP1910Exact", "%DB_USER", "READ", 0), $ListBuild("OcuP1910NoOperate", "%Admin_Operate", "USE", 0), $ListBuild("OcuP1910NoSys", "%DB_IRISSYS", "READ", 0), $ListBuild("OcuP1910Read", "%DB_USER", "READ", 1), $ListBuild("OcuP1910Read", "%Development", "USE", 0), $ListBuild("OcuP1910Dev", "%Development", "USE", 1) {
        If $SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) '= $List(tCase, 4) {
            Set tSC = $$$ERROR($$$GeneralError, "the principal " _ $List(tCase, 1) _ "'s " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " did not read back as declared")
            Quit
        }
    }
    Quit tSC
}

}
