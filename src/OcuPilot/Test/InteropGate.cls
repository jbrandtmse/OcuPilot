/// <p>Pins <class>OcuPilot.Port.InteropPort</class>'s gate and the five production tools' pairs against
/// real principals (AD-8, AD-29, AD-62, Story 20.2): a principal missing one pair -- the Interoperability
/// menu's <code>%Ens_Portal:USE</code>, Productions' <code>%Ens_ProductionConfig:READ</code>, the code
/// lists' <code>%Ens_Code:READ</code>, a write's <code>%Ens_ProductionRun:USE</code>, READ on
/// <code>USER</code>'s database or, for a write, WRITE on it -- is refused 403 naming that pair through
/// the port, on the screen routes and on each tool's pairs, before any vendor call, so the probe
/// production is never started by a refused call; and a principal holding exactly the set reads every
/// list and starts and stops the probe production.</p>
/// <p>The port and tool legs run in a child process (<method>Probe</method>) that logs in as the
/// principal, so this process never changes identity.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace that runs
/// interoperability and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it
/// <b>compiles and runs a probe production in <code>USER</code></b> (<class>OcuPilot.Test.ProductionProbe</class>)
/// and creates seven users and roles named <code>OcuP202*</code>. Each principal also holds READ on the
/// install namespace's code database and <code>%Development:USE</code>, as every caller of a route
/// must. The probe and the principals are removed after the last test.</p>
Class OcuPilot.Test.InteropGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's probe production and its throwaway principals,
/// set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's
/// READ&gt;</code>, separated by <code>;</code>: exactly the set, then each missing one.</p>
Parameter PRINCIPALS = "OcuP202Exact:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%Ens_Code:R,%Ens_ProductionRun:U,%DB_USER:RW;OcuP202NoPortal:%Development:U,%Ens_ProductionConfig:R,%Ens_Code:R,%Ens_ProductionRun:U,%DB_USER:RW;OcuP202NoConfig:%Development:U,%Ens_Portal:U,%Ens_Code:R,%Ens_ProductionRun:U,%DB_USER:RW;OcuP202NoCode:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%Ens_ProductionRun:U,%DB_USER:RW;OcuP202NoRun:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%Ens_Code:R,%DB_USER:RW;OcuP202NoRead:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%Ens_Code:R,%Ens_ProductionRun:U;OcuP202NoWrite:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%Ens_Code:R,%Ens_ProductionRun:U,%DB_USER:R";

/// <p>The port legs a probe runs, in order, <code>&lt;endpoint&gt;|&lt;type&gt;</code>. A start is
/// followed by a stop, so a principal admitted to both leaves the probe stopped.</p>
Parameter LEGS = "Productions|LIST,Processes|LIST,Transforms|LIST,Rules|LIST,Productions|STATE,Productions|START,Productions|STOP";

/// <p>The tools whose pairs the probe evaluates.</p>
Parameter TOOLS = "InteropProductionStart,InteropProductionStop,InteropProductionRestart,InteropProductionUpdate,InteropProductionRecover";

/// <p>What each principal's seven port legs answer, <code>&lt;user&gt;=&lt;the pair a refused leg names, or
/// empty when the leg is admitted&gt;</code> per leg in <parameter>LEGS</parameter> order, separated by
/// <code>,</code>.</p>
Parameter EXPECTED = "OcuP202Exact=,,,,,,;OcuP202NoPortal=%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE;OcuP202NoConfig=%Ens_ProductionConfig:READ,,,,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ;OcuP202NoCode=,%Ens_Code:READ,%Ens_Code:READ,%Ens_Code:READ,,,;OcuP202NoRun=,,,,,%Ens_ProductionRun:USE,%Ens_ProductionRun:USE;OcuP202NoRead=%DB_USER:READ,%DB_USER:READ,%DB_USER:READ,%DB_USER:READ,%DB_USER:READ,%DB_USER:WRITE,%DB_USER:WRITE;OcuP202NoWrite=,,,,,%DB_USER:WRITE,%DB_USER:WRITE";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropGate compiles and runs a probe production in USER and creates and deletes users and roles on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = "OcuP202Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

/// <p>Remove the probe, the principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropGate left the principal or role of " _ tUser))
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
    Quit $ClassMethod(..#PROBE, "Settle")
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Settle"), "the probe production is left stopped")
    Quit $$$OK
}

/// <p>The expected answers of <var>pUser</var>'s legs, as a <code>%List</code> of failed pairs.</p>
ClassMethod ExpectedFor(pUser As %String) As %List
{
    For tI = 1:1:$Length(..#EXPECTED, ";") {
        Set tEntry = $Piece(..#EXPECTED, ";", tI)
        If $Piece(tEntry, "=", 1) = pUser Quit
    }
    Quit $ListFromString($Piece(tEntry, "=", 2), ",")
}

/// <p>AC4: each principal's port legs are admitted or refused naming the pair <parameter>EXPECTED</parameter>
/// says, with 403 <code>AUTH.NOPRIVILEGE</code> on a refusal; the probe production is never started by a
/// refused call, and a principal admitted to both writes leaves it stopped.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_ProductionRun:USE</code> from
/// <parameter>OcuPilot.Port.InteropPort.WRITEPAIRS</parameter> -- the missing-run principal's writes reach
/// the vendor and this goes red.</p>
Method TestEachMissingPairIsRefusedByNameThroughThePort()
{
    For tI = 1:1:$Length(..#PRINCIPALS, ";") {
        Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
        Set tExpected = ..ExpectedFor(tUser)
        For tJ = 1:1:$Length(..#LEGS, ",") {
            Set tLeg = $Piece(..#LEGS, ",", tJ)
            Set tWanted = $List(tExpected, tJ)
            Do $$$AssertEquals(..LegText(tProbe, tLeg), $Select(tWanted = "": "200  ", 1: "403 AUTH.NOPRIVILEGE " _ tWanted), tUser _ ": " _ tLeg)
        }
    }
}

/// <p>AC4: the exact principal's start left the probe Running between the legs and its stop left it
/// stopped, and a refused principal's start started nothing.</p>
Method TestARefusedWriteStartsNothingAndTheExactPairsStartAndStop()
{
    Set tProbe = ..ProbeAs("OcuP202Exact")
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|OcuP202Exact", "the probe ran as the exact principal: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("Productions|STATE").state, "Stopped", "the probe reads Stopped before its start")
    Do $$$AssertEquals(tProbe.%Get("Productions|START").state, "Running", "its start leaves the probe Running")
    Do $$$AssertEquals(tProbe.%Get("Productions|STOP").state, "Stopped", "and its stop leaves it Stopped")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Current"), "", "so no production is current")
    For tUser = "OcuP202NoRun", "OcuP202NoWrite", "OcuP202NoRead", "OcuP202NoPortal", "OcuP202NoConfig" {
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("Productions|START").http, 403, tUser _ ": its start is refused")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Current"), "", tUser _ ": and no production is current afterwards")
    }
}

/// <p>AC4: on the screen routes each principal is refused naming the pair its read needs, before the
/// namespace's list is read: the Productions list and the Business processes list, and the Start row
/// action, which names the run or database pair the tool adds.</p>
Method TestEachMissingPairIsRefusedByNameOnTheScreenRoutes()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tCase = $ListBuild("OcuP202NoPortal", "/screens/interop.productions/read", "%Ens_Portal:USE"), $ListBuild("OcuP202NoConfig", "/screens/interop.productions/read", "%Ens_ProductionConfig:READ"), $ListBuild("OcuP202NoCode", "/screens/interop.processes/read", "%Ens_Code:READ"), $ListBuild("OcuP202NoRead", "/screens/interop.productions/read", "%DB_USER:READ") {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ $List(tCase, 2) _ "?ns=" _ ..#NAMESPACE _ "&maxRows=5", $List(tCase, 1), ..PreparedPassword, .tStatus, .tRaw)
        Set tBody = ""
        Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
        Do $$$AssertEquals(tStatus _ " " _ ..FailedPair(tBody), "403 " _ $List(tCase, 3), $List(tCase, 1) _ ": " _ $List(tCase, 2) _ " is refused naming the pair: " _ $Get(tRaw))
    }
    For tCase = $ListBuild("OcuP202NoRun", "%Ens_ProductionRun:USE"), $ListBuild("OcuP202NoWrite", "%DB_USER:WRITE"), $ListBuild("OcuP202NoConfig", "%Ens_ProductionConfig:READ"), $ListBuild("OcuP202NoPortal", "%Ens_Portal:USE") {
        Set tRequest = {"action": "start", "id": (..#PRODUCTION)}
        Kill tExtra
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/screens/interop.productions/action?ns=" _ ..#NAMESPACE, $List(tCase, 1), ..PreparedPassword, .tStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json", .tExtra, 60)
        Set tBody = ""
        Try { Set tBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch {}
        Do $$$AssertEquals(tStatus _ " " _ ..FailedPair(tBody), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the Start row action is refused naming the pair: " _ $Get(tRaw))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Current"), "", "no refused action started the probe")
}

/// <p>AC4: each of the five tools' pairs, evaluated for each principal in the namespace the request is
/// scoped to, fail naming the first pair the principal lacks, in the order screen pairs, run resource,
/// database write; the exact principal holds every pair.</p>
Method TestEachMissingPairIsRefusedByNameOnEachTool()
{
    Set tTools = ..#TOOLS
    For tCase = $ListBuild("OcuP202Exact", ""), $ListBuild("OcuP202NoPortal", "%Ens_Portal:USE"), $ListBuild("OcuP202NoConfig", "%Ens_ProductionConfig:READ"), $ListBuild("OcuP202NoRun", "%Ens_ProductionRun:USE"), $ListBuild("OcuP202NoWrite", "%DB_USER:WRITE") {
        Set tProbe = ..ProbeAs($List(tCase, 1))
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ $List(tCase, 1), $List(tCase, 1) _ ": the probe ran as the principal")
        For tI = 1:1:$Length(tTools, ",") {
            Set tTool = $Piece(tTools, ",", tI)
            Do $$$AssertEquals($Select($IsObject(tProbe.%Get("tools")): tProbe.tools.%Get(tTool), 1: "absent"), $List(tCase, 2), $List(tCase, 1) _ ": " _ tTool _ " fails on " _ $Select($List(tCase, 2) = "": "nothing", 1: $List(tCase, 2)))
        }
    }
}

/// <p>The failed pair a refusal envelope names, or <code>""</code>.</p>
ClassMethod FailedPair(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("detail")) Quit ""
    Quit pBody.detail.%Get("failedPair")
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or
/// an object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropGate).Probe($Job, pUser, ..#NAMESPACE, ..#PRODUCTION)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 120)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 120 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>One leg of a probe as <code>http code failedPair</code>.</p>
ClassMethod LegText(pProbe As %DynamicObject, pLeg As %String) As %String
{
    If '$IsObject(pProbe) || '$IsObject(pProbe.%Get(pLeg)) Quit "absent"
    Set tLeg = pProbe.%Get(pLeg)
    Quit tLeg.http _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair")
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of
/// <parameter>LEGS</parameter> through <class>OcuPilot.Port.InteropPort</class> in <var>pNamespace</var>
/// naming <var>pId</var>, evaluate each of <parameter>TOOLS</parameter>' pairs for a request scoped to
/// <var>pNamespace</var>, and signal <code>{loggedIn, username, "&lt;endpoint&gt;|&lt;type&gt;": {http,
/// code, failedPair, state}, tools: {&lt;tool&gt;: failed pair}}</code> to process <var>pParent</var>, or
/// <code>{error}</code> when something raised. It runs in its own process so the login never touches the
/// test's own identity.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String, pId As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        For tI = 1:1:$Length(..#LEGS, ",") {
            Set tLegName = $Piece(..#LEGS, ",", tI)
            Kill tQuery
            Set tQuery("namespace") = pNamespace
            Set tQuery("id") = pId
            Set tQuery("maxRows") = 5
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            ; A production stopped the moment it started still holds its scheduler's first message
            ; and stops Suspended; the pause lets the start settle.
            If tLegName = "Productions|STOP" Hang 3
            Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke($Piece(tLegName, "|", 1), $Piece(tLegName, "|", 2), .tQuery, "", .tResult, .tHttp, .tFault)
            Set tLeg = {}
            Do tLeg.%Set("http", +tHttp, "number")
            If $IsObject(tFault) {
                Do tLeg.%Set("code", tFault.%Get("code"))
                If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
            }
            If $IsObject($Get(tResult)) && (tResult.%GetTypeOf("State") = "string") Do tLeg.%Set("state", tResult.%Get("State"))
            Do tOut.%Set(tLegName, tLeg)
        }
        Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
        Set tTools = {}
        For tI = 1:1:$Length(..#TOOLS, ",") {
            Set tTool = $Piece(..#TOOLS, ",", tI)
            Set tPairs = $ClassMethod("OcuPilot.Screen.Tool." _ tTool, "PrivilegePairs", "", .tResolved)
            Set tFailed = ""
            If 'tResolved {
                Set tFailed = "unresolved"
            } Else {
                If ##class(OcuPilot.Screen.Gate).EvaluateRequired(tPairs, .tFailed) Set tFailed = ""
            }
            Do tTools.%Set(tTool, tFailed)
        }
        Do tOut.%Set("tools", tTools)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Create each of <parameter>PRINCIPALS</parameter> with a role of its own holding its pairs and READ
/// on the install namespace's code database, then read the decisive grants back.</p>
Method EnsurePrincipals() As %Status
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
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tEntry = $Piece(..#PRINCIPALS, ";", tI)
            Set tUser = $Piece(tEntry, ":", 1)
            Set tRole = tUser _ "Role"
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the interoperability port's gate (throwaway)", tHome _ ":R," _ $Piece(tEntry, ":", 2, *), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot interoperability gate test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.InteropGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        For tCase = $ListBuild("OcuP202Exact", "%Ens_ProductionRun", "USE", 1), $ListBuild("OcuP202NoRun", "%Ens_ProductionRun", "USE", 0), $ListBuild("OcuP202NoPortal", "%Ens_Portal", "USE", 0), $ListBuild("OcuP202NoConfig", "%Ens_ProductionConfig", "READ", 0), $ListBuild("OcuP202NoCode", "%Ens_Code", "READ", 0), $ListBuild("OcuP202NoRead", "%DB_USER", "READ", 0), $ListBuild("OcuP202NoWrite", "%DB_USER", "WRITE", 0), $ListBuild("OcuP202NoWrite", "%DB_USER", "READ", 1) {
            If $SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) '= $List(tCase, 4) {
                Set tSC = $$$ERROR($$$GeneralError, "the principal " _ $List(tCase, 1) _ "'s " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " did not read back as declared")
                Quit
            }
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
