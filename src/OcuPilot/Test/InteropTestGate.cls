/// <p>Pins <class>OcuPilot.Port.InteropPort</class>'s gate on the <code>ItemTest</code> endpoint and the send tool's pairs against real
/// principals (AD-8, AD-29, AD-44, AD-62, Story 20.6): a principal missing one pair -- the Interoperability menu's
/// <code>%Ens_Portal:USE</code>, the Testing Service page's <code>%Ens_TestingService:USE</code>, READ on <code>USER</code>'s database
/// or, for the send, WRITE on it -- is refused 403 naming that pair through the port, on the screen routes and on the tool's pairs,
/// before any vendor call, so a refused call creates no request and adds no message; a principal holding exactly the set lists and
/// reads the tab and reaches the send, which the production that is not running then refuses for its state, which shows the gate was
/// passed. The send asks for no routines database.</p>
/// <p>The routines database's own WRITE, which this endpoint does not ask for, is arranged in process through
/// <class>OcuPilot.Test.InteropItemSeam</class>, because <code>USER</code> keeps both databases behind one resource. The port legs run
/// in a child process (<method>Probe</method>) that logs in as the principal, so this process never changes identity.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace that runs interoperability and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles a probe production and its request classes in
/// <code>USER</code></b> and creates five users and roles named <code>OcuP206*</code>. Each principal also holds READ on the install
/// namespace's code database and <code>%Development:USE</code>, as every caller of a route must. Only one test starts the probe
/// production, to let the principal holding exactly the pairs complete a send. The probe and the principals are removed after the
/// last test.</p>
Class OcuPilot.Test.InteropTestGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's probe production and its throwaway principals, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter FIXTURE = "OcuPilot.Test.InteropTestFixture";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter GATE = "OcuPilot.Test.InteropItemGate";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropItemTestSend";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter SCREEN = "/screens/interop.itemtest";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by
/// <code>;</code>: exactly the set, then each missing one.</p>
Parameter PRINCIPALS = "OcuP206Exact:%Development:U,%Ens_Portal:U,%Ens_TestingService:U,%DB_USER:RW;OcuP206NoPortal:%Development:U,%Ens_TestingService:U,%DB_USER:RW;OcuP206NoTesting:%Development:U,%Ens_Portal:U,%DB_USER:RW;OcuP206NoRead:%Development:U,%Ens_Portal:U,%Ens_TestingService:U;OcuP206NoWrite:%Development:U,%Ens_Portal:U,%Ens_TestingService:U,%DB_USER:R";

/// <p>The port legs a probe runs, in order, <code>&lt;endpoint&gt;|&lt;type&gt;</code>.</p>
Parameter LEGS = "ItemTest|LIST,ItemTest|TESTTARGET,ItemTest|SENDTEST";

/// <p>What each principal's three port legs answer, <code>&lt;user&gt;=&lt;the pair a refused leg names, or the code of the state
/// refusal the production that is not running gives a leg that was admitted&gt;</code> per leg in <parameter>LEGS</parameter> order,
/// separated by <code>,</code>. A read admitted answers nothing here.</p>
Parameter EXPECTED = "OcuP206Exact=,,INTEROP.PRODUCTION.NOTRUNNING;OcuP206NoPortal=%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE;OcuP206NoTesting=%Ens_TestingService:USE,%Ens_TestingService:USE,%Ens_TestingService:USE;OcuP206NoRead=%DB_USER:READ,%DB_USER:READ,%DB_USER:WRITE;OcuP206NoWrite=,,%DB_USER:WRITE";

/// <p>The first pair each principal fails the send tool's pairs on, in the order screen pairs, database write.</p>
Parameter TOOLEXPECTED = "OcuP206Exact=;OcuP206NoPortal=%Ens_Portal:USE;OcuP206NoTesting=%Ens_TestingService:USE;OcuP206NoRead=%DB_USER:WRITE;OcuP206NoWrite=%DB_USER:WRITE";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropTestGate compiles a probe production in USER and creates and deletes users and roles on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring up a throwaway container with scripts/ci-throwaway.sh.")
    }
    Set ..PreparedPassword = "OcuP206Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "Create")
    If $$$ISOK(tSC) Set tSC = ..EnsurePrincipals()
    ; %UnitTest skips OnAfterAllTests when this method fails, so a failed setup removes what it made here.
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe, the fixture, the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#FIXTURE, "Remove")
    Set tProbe = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = tProbe
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropTestGate left the principal or role of " _ tUser))
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
    Do $ClassMethod(..#SEAM, "Disarm")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#PROBE, "Settle")
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Disarm")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is left stopped")
    Quit $$$OK
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

/// <p>AC7: each principal's three port legs are admitted or refused naming the pair <parameter>EXPECTED</parameter> says, with 403
/// <code>AUTH.NOPRIVILEGE</code> on a refusal; the exact principal's send is admitted and refused for the state of a production that
/// is not running, and no refused call created a request or added a message.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_TestingService:USE</code> from <parameter>OcuPilot.Port.InteropPort.TESTPAIRS</parameter> --
/// the missing-service principal's legs reach the vendor and this goes red.</p>
Method TestEachMissingPairIsRefusedByNameThroughThePort()
{
    Set tBefore = $ClassMethod(..#FIXTURE, "Counts")
    For tI = 1:1:$Length(..#PRINCIPALS, ";") {
        Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
        Set tExpected = ..ExpectedFor(tUser)
        For tJ = 1:1:$Length(..#LEGS, ",") {
            Set tLeg = $Piece(..#LEGS, ",", tJ)
            Set tWanted = $List(tExpected, tJ)
            Set tText = $Select(tWanted = "": "200  ", tWanted [ "INTEROP.": "409 " _ tWanted _ " ", 1: "403 AUTH.NOPRIVILEGE " _ tWanted)
            Do $$$AssertEquals($ClassMethod(..#GATE, "LegText", tProbe, tLeg), tText, tUser _ ": " _ tLeg)
        }
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts"), tBefore, "no request was saved and no message added")
}

/// <p>AC7: the send tool's pairs, evaluated for each principal in the namespace the request is scoped to, fail naming the first pair
/// the principal lacks, in the order screen pairs, database write; the exact principal holds every pair, and no tool names the
/// routines database.</p>
/// <p>Mutation (Rule 19): set <parameter>DATABASEPERMISSION</parameter> to <code>READ</code> on
/// <class>OcuPilot.Screen.Tool.InteropItemTestSend</class> -- the write rows go red.</p>
Method TestEachMissingPairIsRefusedByNameOnTheTool()
{
    For tI = 1:1:$Length(..#TOOLEXPECTED, ";") {
        Set tEntry = $Piece(..#TOOLEXPECTED, ";", tI)
        Set tUser = $Piece(tEntry, "=", 1)
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal")
        Do $$$AssertEquals($Select($IsObject(tProbe.%Get("tools")): tProbe.tools.%Get("send"), 1: "absent"), $Piece(tEntry, "=", 2), tUser _ ": the send fails on " _ $Select($Piece(tEntry, "=", 2) = "": "nothing", 1: $Piece(tEntry, "=", 2)))
    }
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tPairs = $ClassMethod(..#TOOL, "PrivilegePairs", "", .tResolved)
    Set tText = ""
    For tI = 1:1:$ListLength(tPairs) {
        Set tText = tText _ "," _ $ListToString($List(tPairs, tI), ":")
    }
    Do $$$AssertTrue((tText [ "%Ens_Portal:USE") && (tText [ "%Ens_TestingService:USE") && (tText [ "%DB_USER:WRITE") && (tText '[ "%Ens_ProductionConfig"), "its pairs name the menu, the Testing Service page and the globals database, and no production configuration")
}

/// <p>AC7: on the screen routes each principal is refused naming the pair its read or action needs, before the item's rows are read or
/// a request is built: the tab's read and the Test action; a principal without READ on the namespace's database is refused at the
/// namespace entry before any pair of the route; and the exact principal reads the tab and its Test is refused for the state of a
/// production that is not running.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_TestingService:USE</code> from <parameter>OcuPilot.Port.InteropPort.TESTPAIRS</parameter> --
/// the missing-service rows go red.</p>
Method TestEachMissingPairIsRefusedByNameOnTheScreenRoutes()
{
    Set tBefore = $ClassMethod(..#FIXTURE, "Counts")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tItem = ..#PRODUCTION _ "||" _ $Parameter(..#FIXTURE, "ECHONAME")
    For tCase = $ListBuild("OcuP206NoPortal", "%Ens_Portal:USE"), $ListBuild("OcuP206NoTesting", "%Ens_TestingService:USE"), $ListBuild("OcuP206NoRead", "%DB_USER:READ") {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#SCREEN _ "/read?ns=" _ ..#NAMESPACE _ "&item=" _ tItem _ "&maxRows=5", $List(tCase, 1), ..PreparedPassword, .tStatus, .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#GATE, "FailedPair", tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the tab's read is refused naming the pair: " _ $Get(tRaw))
    }
    For tCase = $ListBuild("OcuP206NoPortal", "%Ens_Portal:USE"), $ListBuild("OcuP206NoTesting", "%Ens_TestingService:USE"), $ListBuild("OcuP206NoWrite", "%DB_USER:WRITE"), $ListBuild("OcuP206NoRead", "%DB_USER:READ") {
        Set tStatus = ..ActAs($List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#GATE, "FailedPair", tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the Test action is refused naming the pair: " _ $Get(tRaw))
    }
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#SCREEN _ "/read?ns=" _ ..#NAMESPACE _ "&item=" _ tItem _ "&maxRows=5", "OcuP206Exact", ..PreparedPassword, .tStatus, .tRaw)
    Set tRows = ""
    Try { Set tRows = ##class(%DynamicObject).%FromJSON(tRaw).rows.%Size() } Catch {}
    Do $$$AssertTrue((tStatus = 200) && (tRows > 0), "the exact principal reads the tab's rows: " _ tStatus _ " " _ tRows)
    Set tStatus = ..ActAs("OcuP206Exact", .tRaw)
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(tRaw).code } Catch {}
    Do $$$AssertEquals(tStatus _ " " _ tCode, "409 " _ ##class(OcuPilot.Api.InteropError).#NOTRUNNING, "and its Test passes the gate and is refused for the production's state: " _ $Get(tRaw))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Counts"), tBefore, "no refused request saved a request or added a message")
}

/// <p>AC7: the send asks for the globals database alone: with every pair held and WRITE held on the globals database but a routines
/// database that is another resource and not held, the port's send passes the gate and is refused for the state of a production that
/// is not running, and a principal holding exactly the pairs is not asked for more.</p>
/// <p>Mutation (Rule 19): add the routines database's WRITE to the send's pairs in <method>OcuPilot.Port.InteropPort.Invoke</method>
/// -- this goes red.</p>
Method TestTheSendAsksForNoRoutinesDatabase()
{
    Set tSeam = ..#SEAM
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_TestingService", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "WRITE")
    Do $ClassMethod(tSeam, "Arm", "%DB_OCUP206ROUTINES")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..#PRODUCTION _ "||" _ $Parameter(..#FIXTURE, "ECHONAME")
    Set tQuery("requestClass") = $Parameter(..#FIXTURE, "REQUESTCLASS")
    Set tQuery("fields") = "{""Text"":""x""}"
    Set tSC = $ClassMethod(tSeam, "Invoke", "ItemTest", "SENDTEST", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#GATE, "FaultText", tFault), "409 " _ ##class(OcuPilot.Api.InteropError).#NOTRUNNING, "the send passes the gate without the routines database")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_TestingService", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Set tSC = $ClassMethod(tSeam, "Invoke", "ItemTest", "SENDTEST", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $ClassMethod(..#GATE, "FaultText", tFault), "403 AUTH.NOPRIVILEGE %DB_USER:WRITE", "while READ on the globals database alone is refused naming its WRITE")
    Kill tQuery("requestClass"), tQuery("fields")
    Set tSC = $ClassMethod(tSeam, "Invoke", "ItemTest", "TESTTARGET", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 200, "and the composed read asks for READ alone")
}

/// <p>AC7: on a running production a principal holding exactly the pairs completes a send -- it saves the request, sends it through the
/// testing service and reads the answer with nothing beyond the pairs and WRITE on the globals database, which is the gate as the
/// vendor checks no privilege -- while the principal that lacks WRITE on the globals database is still refused naming it.</p>
/// <p>Mutation (Rule 19): have <method>OcuPilot.Port.InteropPort.PerformTest</method> set a node of <code>^%SYS</code>, a database the
/// pairs do not grant -- the exact principal's send is answered 500 and this goes red.</p>
Method TestAPrincipalHoldingExactlyThePairsCompletesASend()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Start"), "the probe production runs with the testing service registered")
    Set tLeg = "ItemTest|SENDTEST"
    Set tProbe = ..ProbeAs("OcuP206Exact", tLeg)
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|OcuP206Exact", "the probe ran as the principal: " _ tProbe.%ToJSON())
    Do $$$AssertEquals($ClassMethod(..#GATE, "LegText", tProbe, tLeg), "200  ", "its send is answered")
    Set tAnswered = $Select($IsObject(tProbe.%Get(tLeg)): tProbe.%Get(tLeg).%Get("status"), 1: "")
    Do $$$AssertEquals(tAnswered, "done", "and the target's answer came back")
    Set tProbe = ..ProbeAs("OcuP206NoWrite", tLeg)
    Do $$$AssertEquals($ClassMethod(..#GATE, "LegText", tProbe, tLeg), "403 AUTH.NOPRIVILEGE %DB_USER:WRITE", "while the principal without WRITE on the globals database is refused naming it")
}

/// <p>The person's Test action on the echo item as <var>pUser</var>, with a sound request, as the status; the raw answer in
/// <var>pRaw</var>.</p>
Method ActAs(pUser As %String, Output pRaw) As %Integer
{
    Set tBody = {"action": "test", "values": {}}
    Do tBody.%Set("id", ..#PRODUCTION _ $Char(1) _ $Parameter(..#FIXTURE, "ECHONAME"), "string")
    Do tBody.values.%Set("requestClass", $Parameter(..#FIXTURE, "REQUESTCLASS"), "string")
    Do tBody.values.%Set("fields", "{""Text"":""x""}", "string")
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ ..#SCREEN _ "/action?ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, pUser, ..PreparedPassword, .tStatus, .pRaw, .tHeaders, tBody.%ToJSON(), "application/json", .tExtra, 90)
    Quit +$Get(tStatus)
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String, pLegs As %String = {..#LEGS}) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropTestGate).Probe($Job, pUser, ..#NAMESPACE, ..#PRODUCTION, pLegs)::10
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

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of <var>pLegs</var>
/// through <class>OcuPilot.Port.InteropPort</class> in <var>pNamespace</var> against the echo item of <var>pProduction</var>, evaluate
/// the send tool's pairs for a request scoped to <var>pNamespace</var>, and signal <code>{loggedIn, username, "&lt;endpoint&gt;|&lt;type&gt;":
/// {http, status, code, failedPair}, tools: {send: failed pair}}</code> to process <var>pParent</var>, or <code>{error}</code> when something
/// raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String, pProduction As %String, pLegs As %String = {..#LEGS})
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Set tItem = pProduction _ "||" _ $Parameter(..#FIXTURE, "ECHONAME")
        Set tRequestClass = $Parameter(..#FIXTURE, "REQUESTCLASS")
        For tI = 1:1:$Length(pLegs, ",") {
            Set tLegName = $Piece(pLegs, ",", tI)
            Set tType = $Piece(tLegName, "|", 2)
            Kill tQuery
            Set tQuery("namespace") = pNamespace
            If tType = "LIST" {
                Set tQuery("item") = tItem
                Set tQuery("maxRows") = 5
            } Else {
                Set tQuery("id") = tItem
                If tType = "SENDTEST" {
                    Set tQuery("requestClass") = tRequestClass
                    Set tQuery("fields") = "{""Text"":""x""}"
                }
            }
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke($Piece(tLegName, "|", 1), tType, .tQuery, "", .tResult, .tHttp, .tFault)
            Set tLeg = {}
            Do tLeg.%Set("http", +tHttp, "number")
            If $IsObject($Get(tResult)) && (tResult.%GetTypeOf("status") = "string") Do tLeg.%Set("status", tResult.status)
            If $IsObject(tFault) {
                Do tLeg.%Set("code", tFault.%Get("code"))
                If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
            }
            Do tOut.%Set(tLegName, tLeg)
        }
        Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
        Set tPairs = $ClassMethod(..#TOOL, "PrivilegePairs", "", .tResolved)
        Set tFailed = ""
        If 'tResolved {
            Set tFailed = "unresolved"
        } Else {
            If ##class(OcuPilot.Screen.Gate).EvaluateRequired(tPairs, .tFailed) Set tFailed = ""
        }
        Do tOut.%Set("tools", {"send": (tFailed)})
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Create each of <var>pPrincipals</var> (<code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by
/// <code>;</code>) with <var>pPassword</var> and a role of its own holding its pairs and READ on the install namespace's code database.
/// <var>pOwner</var> is the class that deletes them afterwards, named in their comment. Shared with
/// <class>OcuPilot.Test.InteropTransformTestGate</class>.</p>
ClassMethod CreatePrincipals(pPrincipals As %String, pPassword As %String, pOwner As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(tOrigNS, .tHome, .tGlobals, .tMapped, .tResolved)
        If 'tResolved || (tHome = "") {
            Set tSC = $$$ERROR($$$GeneralError, "the install namespace's code database could not be resolved")
            Quit
        }
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(pPrincipals, ";") {
            Set tEntry = $Piece(pPrincipals, ";", tI)
            Set tUser = $Piece(tEntry, ":", 1)
            Set tRole = tUser _ "Role"
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: a gate principal's role (throwaway)", tHome _ ":R," _ $Piece(tEntry, ":", 2, *), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, pPassword, "OcuPilot gate principal (throwaway)", "", "", "", 0, 1, "Created by " _ pOwner _ "; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create each of <parameter>PRINCIPALS</parameter> (<method>CreatePrincipals</method>), then read the decisive grants back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = ..CreatePrincipals(..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.InteropTestGate")
    Try {
        If $$$ISERR(tSC) Quit
        For tCase = $ListBuild("OcuP206Exact", "%Ens_TestingService", "USE", 1), $ListBuild("OcuP206Exact", "%DB_USER", "WRITE", 1), $ListBuild("OcuP206NoPortal", "%Ens_Portal", "USE", 0), $ListBuild("OcuP206NoTesting", "%Ens_TestingService", "USE", 0), $ListBuild("OcuP206NoRead", "%DB_USER", "READ", 0), $ListBuild("OcuP206NoWrite", "%DB_USER", "READ", 1), $ListBuild("OcuP206NoWrite", "%DB_USER", "WRITE", 0) {
            If $SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) '= $List(tCase, 4) {
                Set tSC = $$$ERROR($$$GeneralError, "the principal " _ $List(tCase, 1) _ "'s " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " did not read back as declared")
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
