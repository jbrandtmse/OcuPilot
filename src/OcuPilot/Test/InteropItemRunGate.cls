/// <p>Pins <class>OcuPilot.Port.InteropPort</class>'s gate on the item runtime read and writes and the three tools' pairs against real
/// principals (AD-8, AD-29, AD-44, AD-62, Story 20.25): a principal missing one pair -- the Interoperability menu's
/// <code>%Ens_Portal:USE</code>, Productions' <code>%Ens_ProductionConfig:READ</code>, the write's <code>%Ens_ConfigItemRun:USE</code>,
/// READ on <code>USER</code>'s database or, for a write, WRITE on it -- is refused 403 naming that pair through the port, on the
/// Production items row action and on each tool's pairs, before any vendor call, so a refused call changes no item. A principal holding
/// exactly the set -- and neither <code>%Ens_ProductionRun:USE</code> nor <code>%Ens_ProductionConfig:WRITE</code> -- reads the item's
/// runtime, stops, starts and restarts it through the port, and stops and starts it through the screen.</p>
/// <p>The port legs run in a child process (<method>Probe</method>) that logs in as the principal, so this process never changes
/// identity. The principal and probe methods are the shape of <class>OcuPilot.Test.InteropItemGate</class>'s, whose own hard-code that
/// class's principals, legs and tools.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace that runs interoperability and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a probe production in
/// <code>USER</code></b> (<class>OcuPilot.Test.ProductionProbe</class>) and creates six users and roles named <code>OcuP225*</code>. Each
/// principal also holds READ on the install namespace's code database and <code>%Development:USE</code>, as every caller of a route must.
/// The probe and the principals are removed after the last test.</p>
Class OcuPilot.Test.InteropItemRunGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter RUN = "OcuPilot.Test.InteropItemRun";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter ITEM = "OcuPilotProbeOp";

Parameter SCREEN = "/screens/interop.items";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by
/// <code>;</code>: exactly the set, then each missing one.</p>
Parameter PRINCIPALS = "OcuP225Exact:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%Ens_ConfigItemRun:U,%DB_USER:RW;OcuP225NoPortal:%Development:U,%Ens_ProductionConfig:R,%Ens_ConfigItemRun:U,%DB_USER:RW;OcuP225NoCfgRead:%Development:U,%Ens_Portal:U,%Ens_ConfigItemRun:U,%DB_USER:RW;OcuP225NoRun:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%DB_USER:RW;OcuP225NoRead:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%Ens_ConfigItemRun:U;OcuP225NoWrite:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%Ens_ConfigItemRun:U,%DB_USER:R";

/// <p>The port legs a probe runs, in order, <code>&lt;endpoint&gt;|&lt;type&gt;</code>. The stop is followed by the start and the restart,
/// so a principal admitted to all leaves the item running.</p>
Parameter LEGS = "Items|ITEMRUN,Items|STOPITEM,Items|STARTITEM,Items|RESTARTITEM";

/// <p>The tools whose pairs the probe evaluates.</p>
Parameter TOOLS = "InteropItemStop,InteropItemStart,InteropItemRestart";

/// <p>What each principal's four port legs answer, <code>&lt;user&gt;=&lt;the pair a refused leg names, or empty when the leg is
/// admitted&gt;</code> per leg in <parameter>LEGS</parameter> order, separated by <code>,</code>.</p>
Parameter EXPECTED = "OcuP225Exact=,,,;OcuP225NoPortal=%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE;OcuP225NoCfgRead=%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ;OcuP225NoRun=,%Ens_ConfigItemRun:USE,%Ens_ConfigItemRun:USE,%Ens_ConfigItemRun:USE;OcuP225NoRead=%DB_USER:READ,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE;OcuP225NoWrite=,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE";

/// <p>The first pair each principal's three tools fail on, in the order screen pairs, the run pair, database write.</p>
Parameter TOOLEXPECTED = "OcuP225Exact=;OcuP225NoPortal=%Ens_Portal:USE;OcuP225NoCfgRead=%Ens_ProductionConfig:READ;OcuP225NoRun=%Ens_ConfigItemRun:USE;OcuP225NoRead=%DB_USER:WRITE;OcuP225NoWrite=%DB_USER:WRITE";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemRunGate compiles and runs a probe production in USER and creates and deletes users and roles on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = "OcuP225Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISERR(tSC) Quit $$$ADDSC(tSC, ..OnAfterAllTests())
    Set tSC = ..EnsurePrincipals()
    If $$$ISOK(tSC) Set tSC = ..StartProbe()
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
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
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemRunGate left the principal or role of " _ tUser))
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
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertEquals($ClassMethod(..#RUN, "Facts", ..#ITEM), "enabled=1 stopped=0 own=1 jobs=1 needs=0", "the probe's operation is running, not stopped and nothing is pending")
    Quit $$$OK
}

/// <p>Start the probe production through the port and wait for the plain operation's job.</p>
ClassMethod StartProbe() As %Status
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = ..#PRODUCTION
    Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke("Productions", "START", .tQuery, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    For tTry = 1:1:30 {
        If $ClassMethod(..#RUN, "Facts", ..#ITEM) = "enabled=1 stopped=0 own=1 jobs=1 needs=0" Quit
        Hang 0.5
    }
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

/// <p>AC5: each principal's four port legs are admitted or refused naming the pair <parameter>EXPECTED</parameter> says, with 403
/// <code>AUTH.NOPRIVILEGE</code> on a refusal; a refused leg changes nothing, and the exact principal -- who holds neither
/// <code>%Ens_ProductionRun:USE</code> nor <code>%Ens_ProductionConfig:WRITE</code> -- stops, starts and restarts the item.</p>
/// <p>Mutation (Rule 19): drop <code>ITEMRUNPAIR</code> from <method>OcuPilot.Port.InteropPort.Pairs</method> -- the missing-run-pair
/// principal's writes reach the vendor and this goes red.</p>
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
        Do $$$AssertStatusOK($ClassMethod(..#RUN, "WaitJobs", 1), tUser _ ": the item's job runs again after any start")
        Do $$$AssertEquals($ClassMethod(..#RUN, "Facts", ..#ITEM), "enabled=1 stopped=0 own=1 jobs=1 needs=0", tUser _ ": the item is running as it began")
    }
}

/// <p>AC5: each of the three tools' pairs, evaluated for each principal in the namespace the request is scoped to, fail naming the first
/// pair the principal lacks, in the order screen pairs, the run pair, database write; the exact principal holds every pair.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_ConfigItemRun:USE</code> from <parameter>OcuPilot.Screen.Tool.InteropItemRunAction.WRITERESOURCE</parameter>
/// -- the missing-run-pair row goes red.</p>
Method TestEachMissingPairIsRefusedByNameOnEachTool()
{
    For tI = 1:1:$Length(..#TOOLEXPECTED, ";") {
        Set tEntry = $Piece(..#TOOLEXPECTED, ";", tI)
        Set tUser = $Piece(tEntry, "=", 1)
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal")
        For tJ = 1:1:$Length(..#TOOLS, ",") {
            Set tTool = $Piece(..#TOOLS, ",", tJ)
            Do $$$AssertEquals($Select($IsObject(tProbe.%Get("tools")): tProbe.tools.%Get(tTool), 1: "absent"), $Piece(tEntry, "=", 2), tUser _ ": " _ tTool _ " fails on " _ $Select($Piece(tEntry, "=", 2) = "": "nothing", 1: $Piece(tEntry, "=", 2)))
        }
    }
}

/// <p>AC5: on the Production items row action each principal is refused naming the pair the action needs, before the item is touched,
/// and the exact principal's Stop and Start are admitted and leave the item running.</p>
/// <p>Mutation (Rule 19): name a pair the principals hold in <parameter>OcuPilot.Screen.Tool.InteropItemRunAction.WRITERESOURCE</parameter> --
/// the missing-run-pair row goes red.</p>
Method TestEachMissingPairIsRefusedByNameOnTheRowAction()
{
    Set tId = $ClassMethod(..#CONTROL, "IdOf", ..#ITEM)
    For tCase = $ListBuild("OcuP225NoPortal", "%Ens_Portal:USE"), $ListBuild("OcuP225NoCfgRead", "%Ens_ProductionConfig:READ"), $ListBuild("OcuP225NoRun", "%Ens_ConfigItemRun:USE"), $ListBuild("OcuP225NoWrite", "%DB_USER:WRITE"), $ListBuild("OcuP225NoRead", "%DB_USER:READ") {
        For tAction = "stop", "start", "restart" {
            Set tRequest = {"action": (tAction)}
            Do tRequest.%Set("id", tId, "string")
            Set tStatus = ..Post(..#SCREEN _ "/action", tRequest, $List(tCase, 1), .tRaw)
            Do $$$AssertEquals(tStatus _ " " _ ..FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the " _ tAction _ " row action is refused naming the pair: " _ $Get(tRaw))
        }
    }
    Do $$$AssertEquals($ClassMethod(..#RUN, "Facts", ..#ITEM), "enabled=1 stopped=0 own=1 jobs=1 needs=0", "no refused request changed the item")
    For tAction = "stop", "start" {
        Set tRequest = {"action": (tAction)}
        Do tRequest.%Set("id", tId, "string")
        Set tStatus = ..Post(..#SCREEN _ "/action", tRequest, "OcuP225Exact", .tRaw)
        Do $$$AssertEquals(tStatus, 200, "the exact principal's " _ tAction _ " is admitted: " _ $Get(tRaw))
        If tAction = "stop" Do $$$AssertEquals($ClassMethod(..#RUN, "Facts", ..#ITEM), "enabled=1 stopped=1 own=0 jobs=0 needs=0", "and it stopped the item")
    }
    Do $$$AssertStatusOK($ClassMethod(..#RUN, "WaitJobs", 1), "and the start runs its job again")
}

/// <p>The failed pair a refusal envelope (raw JSON) names, or <code>""</code>.</p>
ClassMethod FailedPair(pRaw) As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("detail")) Quit ""
    Quit tBody.detail.%Get("failedPair")
}

/// <p><var>pBody</var> posted to <var>pPath</var> as <var>pUser</var>, scoped to <parameter>NAMESPACE</parameter>; the status, and the raw
/// answer in <var>pRaw</var>.</p>
Method Post(pPath As %String, pBody As %DynamicObject, pUser As %String, Output pRaw) As %Integer
{
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ "?ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, pUser, ..PreparedPassword, .tStatus, .pRaw, .tHeaders, pBody.%ToJSON(), "application/json", .tExtra, 90)
    Quit +$Get(tStatus)
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropItemRunGate).Probe($Job, pUser, ..#NAMESPACE, ..#PRODUCTION)::10
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

/// <p>One leg of a probe as <code>http code failedPair</code>.</p>
ClassMethod LegText(pProbe As %DynamicObject, pLeg As %String) As %String
{
    If '$IsObject(pProbe) || '$IsObject(pProbe.%Get(pLeg)) Quit "absent"
    Set tLeg = pProbe.%Get(pLeg)
    Quit tLeg.http _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair")
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of <parameter>LEGS</parameter> through
/// <class>OcuPilot.Port.InteropPort</class> in <var>pNamespace</var> against the item of <var>pProduction</var>, evaluate each of
/// <parameter>TOOLS</parameter>' pairs for a request scoped to <var>pNamespace</var>, and signal <code>{loggedIn, username,
/// "&lt;endpoint&gt;|&lt;type&gt;": {http, code, failedPair}, tools: {&lt;tool&gt;: failed pair}}</code> to process <var>pParent</var>, or
/// <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String, pProduction As %String)
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
            Set tQuery("id") = pProduction _ $Char(1) _ ..#ITEM
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke($Piece(tLegName, "|", 1), $Piece(tLegName, "|", 2), .tQuery, "", .tResult, .tHttp, .tFault)
            Set tLeg = {}
            Do tLeg.%Set("http", +tHttp, "number")
            If $IsObject(tFault) {
                Do tLeg.%Set("code", tFault.%Get("code"))
                If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
            }
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

/// <p>Create each of <parameter>PRINCIPALS</parameter> with a role of its own holding its pairs and READ on the install namespace's code
/// database, then read the decisive grants back.</p>
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
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the item runtime gate (throwaway)", tHome _ ":R," _ $Piece(tEntry, ":", 2, *), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot item runtime gate test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.InteropItemRunGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        For tCase = $ListBuild("OcuP225Exact", "%Ens_ConfigItemRun", "USE", 1), $ListBuild("OcuP225Exact", "%Ens_ProductionRun", "USE", 0), $ListBuild("OcuP225Exact", "%Ens_ProductionConfig", "WRITE", 0), $ListBuild("OcuP225NoPortal", "%Ens_Portal", "USE", 0), $ListBuild("OcuP225NoCfgRead", "%Ens_ProductionConfig", "READ", 0), $ListBuild("OcuP225NoRun", "%Ens_ConfigItemRun", "USE", 0), $ListBuild("OcuP225NoRead", "%DB_USER", "READ", 0), $ListBuild("OcuP225NoRead", "%DB_USER", "WRITE", 0), $ListBuild("OcuP225NoWrite", "%DB_USER", "WRITE", 0), $ListBuild("OcuP225NoWrite", "%DB_USER", "READ", 1) {
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
