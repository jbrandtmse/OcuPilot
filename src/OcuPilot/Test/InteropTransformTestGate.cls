/// <p>Pins <class>OcuPilot.Port.InteropPort</class>'s gate on the <code>Transforms</code> endpoint's <code>TRANSFORM</code> and
/// <code>TRANSFORMTEST</code> and the test tool's pairs against real principals (AD-8, AD-29, AD-44, AD-62, Story 20.27): a principal
/// missing one pair -- the Interoperability menu's <code>%Ens_Portal:USE</code>, the list's <code>%Ens_Code:READ</code>, the Test
/// Transform dialog's <code>%Ens_DTLTest:USE</code>, READ on <code>USER</code>'s database or, for the test, WRITE on it -- is refused
/// 403 naming that pair through the port, on the screen routes and on the tool's pairs, before any vendor call, so a refused call runs
/// no transformation; a principal holding exactly the set lists, reads and runs the test. The list needs no <code>%Ens_DTLTest</code>.</p>
/// <p>The port legs run in a child process (<method>Probe</method>) that logs in as the principal, so this process never changes
/// identity. The principals are created by <method>OcuPilot.Test.InteropTestGate.CreatePrincipals</method>.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace that runs interoperability and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs transformations in <code>USER</code></b>
/// and creates six users and roles named <code>OcuP2027*</code>. Each principal also holds READ on the install namespace's code database
/// and <code>%Development:USE</code>, as every caller of a route must. No probe production is used. The fixture and the principals are
/// removed after the last test.</p>
Class OcuPilot.Test.InteropTransformTestGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropTransformFixture";

Parameter SHARED = "OcuPilot.Test.InteropTestGate";

Parameter GATE = "OcuPilot.Test.InteropItemGate";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropTransformTest";

Parameter NAMESPACE = "USER";

Parameter SCREEN = "/screens/interop.transforms";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by
/// <code>;</code>: exactly the set, then each missing one.</p>
Parameter PRINCIPALS = "OcuP2027Exact:%Development:U,%Ens_Portal:U,%Ens_Code:R,%Ens_DTLTest:U,%DB_USER:RW;OcuP2027NoPortal:%Development:U,%Ens_Code:R,%Ens_DTLTest:U,%DB_USER:RW;OcuP2027NoCode:%Development:U,%Ens_Portal:U,%Ens_DTLTest:U,%DB_USER:RW;OcuP2027NoDtl:%Development:U,%Ens_Portal:U,%Ens_Code:R,%DB_USER:RW;OcuP2027NoRead:%Development:U,%Ens_Portal:U,%Ens_Code:R,%Ens_DTLTest:U;OcuP2027NoWrite:%Development:U,%Ens_Portal:U,%Ens_Code:R,%Ens_DTLTest:U,%DB_USER:R";

/// <p>The port legs a probe runs, in order, <code>&lt;endpoint&gt;|&lt;type&gt;</code>.</p>
Parameter LEGS = "Transforms|LIST,Transforms|TRANSFORM,Transforms|TRANSFORMTEST";

/// <p>What each principal's three port legs answer, <code>&lt;user&gt;=&lt;the pair a refused leg names&gt;</code> per leg in
/// <parameter>LEGS</parameter> order, separated by <code>,</code>, an admitted leg naming none, separated by <code>;</code>.</p>
Parameter EXPECTED = "OcuP2027Exact=,,;OcuP2027NoPortal=%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE;OcuP2027NoCode=%Ens_Code:READ,%Ens_Code:READ,%Ens_Code:READ;OcuP2027NoDtl=,%Ens_DTLTest:USE,%Ens_DTLTest:USE;OcuP2027NoRead=%DB_USER:READ,%DB_USER:READ,%DB_USER:WRITE;OcuP2027NoWrite=,,%DB_USER:WRITE";

/// <p>The first pair each principal fails the test tool's pairs on, in the order screen pairs, the dialog's resource, database write.</p>
Parameter TOOLEXPECTED = "OcuP2027Exact=;OcuP2027NoPortal=%Ens_Portal:USE;OcuP2027NoCode=%Ens_Code:READ;OcuP2027NoDtl=%Ens_DTLTest:USE;OcuP2027NoRead=%DB_USER:WRITE;OcuP2027NoWrite=%DB_USER:WRITE";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropTransformTestGate compiles and runs probe data transformations in USER and creates and deletes users and roles on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring up a throwaway container with scripts/ci-throwaway.sh.")
    }
    Set ..PreparedPassword = "OcuP2027Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#FIXTURE, "Create")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#SHARED, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.InteropTransformTestGate")
    If $$$ISOK(tSC) Set tSC = ..ReadBack()
    ; %UnitTest skips OnAfterAllTests when this method fails, so a failed setup removes what it made here.
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the fixture, the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#FIXTURE, "Remove")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropTransformTestGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>Read the decisive grants of the principals back, a failing status naming the first that is not as declared.</p>
ClassMethod ReadBack() As %Status
{
    Set tSC = $$$OK
    For tCase = $ListBuild("OcuP2027Exact", "%Ens_DTLTest", "USE", 1), $ListBuild("OcuP2027Exact", "%DB_USER", "WRITE", 1), $ListBuild("OcuP2027NoPortal", "%Ens_Portal", "USE", 0), $ListBuild("OcuP2027NoCode", "%Ens_Code", "READ", 0), $ListBuild("OcuP2027NoDtl", "%Ens_DTLTest", "USE", 0), $ListBuild("OcuP2027NoRead", "%DB_USER", "READ", 0), $ListBuild("OcuP2027NoWrite", "%DB_USER", "READ", 1), $ListBuild("OcuP2027NoWrite", "%DB_USER", "WRITE", 0) {
        If $SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) '= $List(tCase, 4) {
            Set tSC = $$$ERROR($$$GeneralError, "the principal " _ $List(tCase, 1) _ "'s " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " did not read back as declared")
            Quit
        }
    }
    Quit tSC
}

/// <p>The expected answers of <var>pUser</var>'s legs, as a <code>%List</code>.</p>
ClassMethod ExpectedFor(pUser As %String) As %List
{
    For tI = 1:1:$Length(..#EXPECTED, ";") {
        Set tEntry = $Piece(..#EXPECTED, ";", tI)
        If $Piece(tEntry, "=", 1) = pUser Quit
    }
    Quit $ListFromString($Piece(tEntry, "=", 2), ",")
}

/// <p>AC8: each principal's three port legs are admitted or refused naming the pair <parameter>EXPECTED</parameter> says, with 403
/// <code>AUTH.NOPRIVILEGE</code> on a refusal; the exact principal lists, reads and runs, and no refused call ran a
/// transformation.</p>
/// <p>Mutation (Rule 19): drop the dialog's pair from <method>OcuPilot.Port.InteropPort.Pairs</method> -- the missing-dialog principal's
/// legs reach the vendor and this goes red.</p>
Method TestEachMissingPairIsRefusedByNameThroughThePort()
{
    Set tRuns = $ClassMethod(..#FIXTURE, "Runs")
    Set tCounts = $ClassMethod(..#FIXTURE, "Counts")
    For tI = 1:1:$Length(..#PRINCIPALS, ";") {
        Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
        Set tExpected = ..ExpectedFor(tUser)
        For tJ = 1:1:$Length(..#LEGS, ",") {
            Set tLeg = $Piece(..#LEGS, ",", tJ)
            Set tWanted = $List(tExpected, tJ)
            Do $$$AssertEquals($ClassMethod(..#GATE, "LegText", tProbe, tLeg), $Select(tWanted = "": "200  ", 1: "403 AUTH.NOPRIVILEGE " _ tWanted), tUser _ ": " _ tLeg)
        }
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Runs") - tRuns, 1, "only the exact principal's test ran the transformation")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts"), tCounts, "and nothing was stored")
}

/// <p>AC8: the test tool's pairs, evaluated for each principal in the namespace the request is scoped to, fail naming the first pair the
/// principal lacks, in the order screen pairs, dialog resource, database write; the exact principal holds every pair.</p>
/// <p>Mutation (Rule 19): set <parameter>DATABASEPERMISSION</parameter> to <code>READ</code> on
/// <class>OcuPilot.Screen.Tool.InteropTransformTest</class> -- the write rows go red.</p>
Method TestEachMissingPairIsRefusedByNameOnTheTool()
{
    For tI = 1:1:$Length(..#TOOLEXPECTED, ";") {
        Set tEntry = $Piece(..#TOOLEXPECTED, ";", tI)
        Set tUser = $Piece(tEntry, "=", 1)
        Set tProbe = ..ProbeAs(tUser, "", 1)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal")
        Do $$$AssertEquals($Select($IsObject(tProbe.%Get("tools")): tProbe.tools.%Get("run"), 1: "absent"), $Piece(tEntry, "=", 2), tUser _ ": the test fails on " _ $Select($Piece(tEntry, "=", 2) = "": "nothing", 1: $Piece(tEntry, "=", 2)))
    }
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tPairs = $ClassMethod(..#TOOL, "PrivilegePairs", "", .tResolved)
    Set tText = ""
    For tI = 1:1:$ListLength(tPairs) {
        Set tText = tText _ "," _ $ListToString($List(tPairs, tI), ":")
    }
    Do $$$AssertTrue((tText [ "%Ens_Portal:USE") && (tText [ "%Ens_Code:READ") && (tText [ "%Ens_DTLTest:USE") && (tText [ "%DB_USER:WRITE") && (tText '[ "Testing"), "its pairs name the menu, the list, the dialog's resource and the globals database: " _ tText)
}

/// <p>AC8: on the screen routes each principal is refused naming the pair its read or action needs, before a transformation runs:
/// the list's read and the Test action; a principal without READ on the namespace's database is refused at the namespace entry before
/// any pair of the route; the principal without the dialog's resource still reads the list; and the exact principal reads the list and
/// its Test runs the transformation.</p>
/// <p>Mutation (Rule 19): name <code>%Ens_TestingService</code> as <class>OcuPilot.Screen.Tool.InteropTransformTest</class>'s
/// <parameter>WRITERESOURCE</parameter> -- the missing-dialog row and the exact principal's run go red. Dropping the dialog's pair from
/// <method>OcuPilot.Port.InteropPort.Pairs</method> alone leaves these rows green, because the tool's own pairs refuse first.</p>
Method TestEachMissingPairIsRefusedByNameOnTheScreenRoutes()
{
    Set tRuns = $ClassMethod(..#FIXTURE, "Runs")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tCase = $ListBuild("OcuP2027NoPortal", "%Ens_Portal:USE"), $ListBuild("OcuP2027NoCode", "%Ens_Code:READ"), $ListBuild("OcuP2027NoRead", "%DB_USER:READ") {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#SCREEN _ "/read?ns=" _ ..#NAMESPACE _ "&maxRows=5", $List(tCase, 1), ..PreparedPassword, .tStatus, .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#GATE, "FailedPair", tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the list's read is refused naming the pair: " _ $Get(tRaw))
    }
    For tCase = $ListBuild("OcuP2027NoPortal", "%Ens_Portal:USE"), $ListBuild("OcuP2027NoCode", "%Ens_Code:READ"), $ListBuild("OcuP2027NoDtl", "%Ens_DTLTest:USE"), $ListBuild("OcuP2027NoWrite", "%DB_USER:WRITE"), $ListBuild("OcuP2027NoRead", "%DB_USER:READ") {
        Set tStatus = ..ActAs($List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#GATE, "FailedPair", tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the Test action is refused naming the pair: " _ $Get(tRaw))
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Runs") - tRuns, 0, "no refused call ran a transformation")
    For tUser = "OcuP2027Exact", "OcuP2027NoDtl" {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#SCREEN _ "/read?ns=" _ ..#NAMESPACE _ "&maxRows=5", tUser, ..PreparedPassword, .tStatus, .tRaw)
        Set tRows = ""
        Try { Set tRows = ##class(%DynamicObject).%FromJSON(tRaw).rows.%Size() } Catch {}
        Do $$$AssertTrue((tStatus = 200) && (tRows > 0), tUser _ " reads the list's rows: " _ tStatus _ " " _ tRows)
    }
    Set tStatus = ..ActAs("OcuP2027Exact", .tRaw)
    Set tOutput = ""
    Try { Set tOutput = ##class(%DynamicObject).%FromJSON(tRaw).output.status } Catch {}
    Do $$$AssertEquals(tStatus _ " " _ tOutput, "200 done", "and the exact principal's Test runs the transformation: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Runs") - tRuns, 1, "once")
}

/// <p>The person's Test action on the XML transformation as <var>pUser</var>, with a sound message, as the status; the raw answer in
/// <var>pRaw</var>.</p>
Method ActAs(pUser As %String, Output pRaw) As %Integer
{
    Set tBody = {"action": "test", "values": {}}
    Do tBody.%Set("id", $Parameter(..#FIXTURE, "XML") _ ".cls", "string")
    Do tBody.values.%Set("content", $ClassMethod(..#FIXTURE, "Message", "x"), "string")
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#SCREEN _ "/action?ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, pUser, ..PreparedPassword, .tStatus, .pRaw, .tHeaders, tBody.%ToJSON(), "application/json", .tExtra, 90)
    Quit +$Get(tStatus)
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String, pLegs As %String = {..#LEGS}, pTools As %Boolean = 0) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropTransformTestGate).Probe($Job, pUser, ..#NAMESPACE, pLegs, pTools)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 180)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 180 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of <var>pLegs</var> through
/// <class>OcuPilot.Port.InteropPort</class> in <var>pNamespace</var> against the XML transformation, evaluate the test tool's pairs for a
/// request scoped to <var>pNamespace</var> when <var>pTools</var> is set, and signal <code>{loggedIn, username, "&lt;endpoint&gt;|&lt;type&gt;": {http, code,
/// failedPair}, tools: {run: failed pair}}</code> to process <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String, pLegs As %String = {..#LEGS}, pTools As %Boolean = 0)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        For tI = 1:1:$Length(pLegs, ",") {
            If pLegs = "" Quit
            Set tLegName = $Piece(pLegs, ",", tI)
            Set tType = $Piece(tLegName, "|", 2)
            Kill tQuery
            Set tQuery("namespace") = pNamespace
            If tType = "LIST" {
                Set tQuery("maxRows") = 5
            } Else {
                Set tQuery("id") = $Parameter(..#FIXTURE, "XML") _ ".cls"
                Set tQuery("content") = $ClassMethod(..#FIXTURE, "Message", "x")
            }
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke($Piece(tLegName, "|", 1), tType, .tQuery, "", .tResult, .tHttp, .tFault)
            Set tLeg = {}
            Do tLeg.%Set("http", +tHttp, "number")
            If $IsObject(tFault) {
                Do tLeg.%Set("code", tFault.%Get("code"))
                If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
            }
            Do tOut.%Set(tLegName, tLeg)
        }
        If pTools {
            Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
            Set tPairs = $ClassMethod(..#TOOL, "PrivilegePairs", "", .tResolved)
            Set tFailed = ""
            If 'tResolved {
                Set tFailed = "unresolved"
            } Else {
                If ##class(OcuPilot.Screen.Gate).EvaluateRequired(tPairs, .tFailed) Set tFailed = ""
            }
            Do tOut.%Set("tools", {"run": (tFailed)})
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

}
