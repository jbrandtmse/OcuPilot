/// <p>Pins <class>OcuPilot.Port.InteropPort</class>'s gate on the Items endpoint and the four item tools'
/// pairs against real principals (AD-8, AD-29, AD-44, AD-62, Story 20.3): a principal missing one pair -- the
/// Interoperability menu's <code>%Ens_Portal:USE</code>, Productions' <code>%Ens_ProductionConfig:READ</code>,
/// an item write's <code>%Ens_ProductionConfig:WRITE</code>, READ on <code>USER</code>'s database or, for a
/// write, WRITE on it -- is refused 403 naming that pair through the port, on the screen routes, on the Save
/// route and on each tool's pairs, before any vendor call, so a refused call changes no item; a principal
/// holding exactly the set lists and reads the items and disables, enables, adds and removes one through the
/// port, and reads, disables and enables one through the screen.</p>
/// <p>The routines database's own WRITE (a resource the globals database's cannot stand in for) and a
/// namespace under source control are arranged in process through <class>OcuPilot.Test.InteropItemSeam</class>,
/// because <code>USER</code> keeps both databases behind one resource and no throwaway can be put under
/// source control.</p>
/// <p>The port legs run in a child process (<method>Probe</method>) that logs in as the principal, so this
/// process never changes identity.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace that runs interoperability and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles a probe production in
/// <code>USER</code></b> (<class>OcuPilot.Test.ProductionProbe</class>) and creates six users and roles named
/// <code>OcuP203*</code>. Each principal also holds READ on the install namespace's code database and
/// <code>%Development:USE</code>, as every caller of a route must. The probe and the principals are removed
/// after the last test.</p>
Class OcuPilot.Test.InteropItemGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's probe production and its throwaway principals, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter NAMESPACE = "USER";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Parameter ITEM = "OcuPilotProbeOp";

Parameter ADDED = "OcuP203Added";

Parameter SCREEN = "/screens/interop.items";

/// <p>The item list a probe production holds before and after every test.</p>
Parameter BASELINE = "OcuPilotProbeOp:1,OcuPilotProbeSvc:1";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>,
/// separated by <code>;</code>: exactly the set, then each missing one.</p>
Parameter PRINCIPALS = "OcuP203Exact:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:RW,%DB_USER:RW;OcuP203NoPortal:%Development:U,%Ens_ProductionConfig:RW,%DB_USER:RW;OcuP203NoCfgRead:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:W,%DB_USER:RW;OcuP203NoCfgWrite:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%DB_USER:RW;OcuP203NoRead:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:RW;OcuP203NoWrite:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:RW,%DB_USER:R";

/// <p>The port legs a probe runs, in order, <code>&lt;endpoint&gt;|&lt;type&gt;</code>. The disable is followed
/// by the enable and the add by the remove, so a principal admitted to all leaves the probe as it was.</p>
Parameter LEGS = "Items|LIST,Items|ITEM,Items|DISABLE,Items|ENABLE,Items|ADD,Items|REMOVE";

/// <p>The tools whose pairs the probe evaluates.</p>
Parameter TOOLS = "InteropItemEnable,InteropItemDisable,InteropItemRemove,InteropItemAdd";

/// <p>What each principal's six port legs answer, <code>&lt;user&gt;=&lt;the pair a refused leg names, or
/// empty when the leg is admitted&gt;</code> per leg in <parameter>LEGS</parameter> order, separated by
/// <code>,</code>.</p>
Parameter EXPECTED = "OcuP203Exact=,,,,,;OcuP203NoPortal=%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE;OcuP203NoCfgRead=%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:READ;OcuP203NoCfgWrite=,,%Ens_ProductionConfig:WRITE,%Ens_ProductionConfig:WRITE,%Ens_ProductionConfig:WRITE,%Ens_ProductionConfig:WRITE;OcuP203NoRead=%DB_USER:READ,%DB_USER:READ,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE;OcuP203NoWrite=,,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE";

/// <p>The first pair each principal's four tools fail on, in the order screen pairs, configuration write,
/// database write.</p>
Parameter TOOLEXPECTED = "OcuP203Exact=;OcuP203NoPortal=%Ens_Portal:USE;OcuP203NoCfgRead=%Ens_ProductionConfig:READ;OcuP203NoCfgWrite=%Ens_ProductionConfig:WRITE;OcuP203NoRead=%DB_USER:WRITE;OcuP203NoWrite=%DB_USER:WRITE";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemGate compiles a probe production in USER and creates and deletes users and roles on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = "OcuP203Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISERR(tSC) Quit $$$ADDSC(tSC, ..OnAfterAllTests())
    Set tSC = ..EnsurePrincipals()
    ; %UnitTest skips OnAfterAllTests when this method fails, so a failed setup removes what it made here.
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
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemGate left the principal or role of " _ tUser))
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
    Quit $ClassMethod(..#CONTROL, "Reset")
}

/// <p>The seam and the fake gate are cleared, and the probe's items are asserted as they began and put back when they are not.</p>
Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Disarm")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), ..#BASELINE, "the probe production's items are left as they began")
    Do $ClassMethod(..#CONTROL, "Reset")
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

/// <p>AC4: each principal's six port legs are admitted or refused naming the pair <parameter>EXPECTED</parameter>
/// says, with 403 <code>AUTH.NOPRIVILEGE</code> on a refusal; a refused leg changes no item, and the exact
/// principal's disable, enable, add and remove leave the items as they began.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_ProductionConfig:WRITE</code> from
/// <parameter>OcuPilot.Port.InteropPort.ITEMWRITEPAIRS</parameter> -- the missing-write principal's item
/// writes reach the vendor and this goes red.</p>
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
        Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), ..#BASELINE, tUser _ ": the items are as they began")
    }
}

/// <p>AC4: each of the four tools' pairs, evaluated for each principal in the namespace the request is scoped
/// to, fail naming the first pair the principal lacks, in the order screen pairs, configuration write,
/// database write; the exact principal holds every pair.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_ProductionConfig:WRITE</code> from
/// <method>OcuPilot.Screen.Tool.InteropItemAction.PrivilegePairs</method> -- the missing-write row goes
/// red.</p>
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

/// <p>AC4: on the screen routes each principal is refused naming the pair its read or action needs, before
/// the production's items are read or written: the Items list's read, the Disable row action, and the Save
/// that adds an item, the last also for a body the rules after the gate would refuse, so the refusal is the
/// Save's own gate and not a later one; a principal without READ on the namespace's database is refused at the
/// namespace entry, <code>NS.DENIED</code>, before any pair of the route; and the exact principal reads the
/// list and disables and enables an item through the screen.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_ProductionConfig:WRITE</code> from
/// <method>OcuPilot.Screen.Tool.InteropItemAction.PrivilegePairs</method> -- the action and Save rows go
/// red; delete the <code>..Gate</code> call from <method>OcuPilot.Area.Interop.ItemSave.HandleCreate</method> --
/// the illegal-name Save rows go red.</p>
Method TestEachMissingPairIsRefusedByNameOnTheScreenRoutes()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tCase = $ListBuild("OcuP203NoPortal", "%Ens_Portal:USE"), $ListBuild("OcuP203NoCfgRead", "%Ens_ProductionConfig:READ"), $ListBuild("OcuP203NoRead", "%DB_USER:READ") {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#SCREEN _ "/read?ns=" _ ..#NAMESPACE _ "&production=" _ ..#PRODUCTION _ "&maxRows=5", $List(tCase, 1), ..PreparedPassword, .tStatus, .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ..FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the Items list is refused naming the pair: " _ $Get(tRaw))
    }
    For tCase = $ListBuild("OcuP203NoPortal", "%Ens_Portal:USE"), $ListBuild("OcuP203NoCfgRead", "%Ens_ProductionConfig:READ"), $ListBuild("OcuP203NoCfgWrite", "%Ens_ProductionConfig:WRITE"), $ListBuild("OcuP203NoWrite", "%DB_USER:WRITE"), $ListBuild("OcuP203NoRead", "%DB_USER:READ") {
        Set tRequest = {"action": "disable"}
        Do tRequest.%Set("id", $ClassMethod(..#CONTROL, "IdOf", ..#ITEM), "string")
        Set tStatus = ..Post(..#SCREEN _ "/action", tRequest, $List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ..FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the Disable row action is refused naming the pair: " _ $Get(tRaw))
        Set tSave = {"ClassName": "OcuPilotProbe.Interop.Op", "PoolSize": 1, "Enabled": false}
        Do tSave.%Set("Production", ..#PRODUCTION, "string")
        Do tSave.%Set("Name", ..#ADDED, "string")
        Set tStatus = ..Post("/interop/items", tSave, $List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ..FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the Save is refused naming the pair: " _ $Get(tRaw))
        Do tSave.%Set("Name", "-OcuP203Bad", "string")
        Set tStatus = ..Post("/interop/items", tSave, $List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ..FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": a Save of an illegal name is refused naming the pair, not the name: " _ $Get(tRaw))
    }
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), ..#BASELINE, "no refused request changed an item")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#SCREEN _ "/read?ns=" _ ..#NAMESPACE _ "&production=" _ ..#PRODUCTION _ "&maxRows=5", "OcuP203Exact", ..PreparedPassword, .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus _ " " _ ..RowNames(tRaw), "200 OcuPilotProbeOp,OcuPilotProbeSvc", "the exact principal reads the probe's two items: " _ $Get(tRaw))
    Set tRequest = {"action": "disable"}
    Do tRequest.%Set("id", $ClassMethod(..#CONTROL, "IdOf", ..#ITEM), "string")
    Set tStatus = ..Post(..#SCREEN _ "/action", tRequest, "OcuP203Exact", .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the exact principal's Disable is admitted: " _ $Get(tRaw))
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), "OcuPilotProbeOp:0,OcuPilotProbeSvc:1", "and it disabled the probe's operation")
    Set tRequest = {"action": "enable"}
    Do tRequest.%Set("id", $ClassMethod(..#CONTROL, "IdOf", ..#ITEM), "string")
    Set tStatus = ..Post(..#SCREEN _ "/action", tRequest, "OcuP203Exact", .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the exact principal's Enable is admitted: " _ $Get(tRaw))
}

/// <p>AC4: an item write also needs WRITE on the routines database, named by its own resource when that is
/// not the globals database's (the production class is saved in <code>^oddDEF</code>); a write refused for
/// it changes no item, a read of the list does not ask for it, and a principal holding it passes the gate --
/// shown by a refusal that comes after the gate.</p>
/// <p>Mutation (Rule 19): drop the routines-database pair from
/// <method>OcuPilot.Port.InteropPort.Invoke</method> -- the refused row goes red.</p>
Method TestAnItemWriteNeedsTheRoutinesDatabaseToo()
{
    Set tSeam = ..#SEAM
    Set tResource = "%DB_OCUP203ROUTINES"
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_ProductionConfig", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_ProductionConfig", "WRITE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "WRITE")
    Do $ClassMethod(tSeam, "Arm", tResource)
    For tType = "DISABLE", "ENABLE", "ADD", "REMOVE" {
        Set tHttp = ..Leg(tSeam, tType, ..#ITEM, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..FaultText(tFault), "403 AUTH.NOPRIVILEGE " _ tResource _ ":WRITE", tType _ " is refused naming the routines database")
    }
    Do $$$AssertEquals(..Leg(tSeam, "LIST", "", .tFault), 200, "the list does not ask for the routines database")
    Do $$$AssertEquals(..Leg(tSeam, "ITEM", ..#ITEM, .tFault), 200, "and neither does the item read")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), ..#BASELINE, "no refused write changed an item")
    Do ##class(OcuPilot.Test.ScreenGate).Hold(tResource, "WRITE")
    Set tHttp = ..Leg(tSeam, "ENABLE", ..#ITEM, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..FaultText(tFault), "409 INTEROP.ITEM.ENABLED", "a principal holding it passes the gate and is refused for the state, which the enabled item is in")
}

/// <p>AC3: a namespace under source control refuses every item read of one item and every item write by
/// <code>INTEROP.ITEM.SOURCECONTROL</code> before the vendor is called, and the list is still readable.</p>
/// <p>Mutation (Rule 19): drop the <code>SourceControlled</code> refusal from
/// <method>OcuPilot.Port.InteropPort.PerformItem</method> -- the write rows go red; keep its 409 and add a
/// <code>LogFault</code> call beside it -- the log row alone goes red, which shows the seam's capture is
/// engaged.</p>
Method TestAnItemWriteInASourceControlledNamespaceIsRefused()
{
    Set tSeam = ..#SEAM
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_ProductionConfig", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Ens_ProductionConfig", "WRITE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "WRITE")
    Do $ClassMethod(tSeam, "Arm", "", 1)
    Do $$$AssertEquals(..Leg(tSeam, "LIST", "", .tFault), 200, "the list is readable")
    For tType = "ITEM", "DISABLE", "ENABLE", "ADD", "REMOVE" {
        Set tHttp = ..Leg(tSeam, tType, $Select(tType = "ADD": ..#ADDED, 1: ..#ITEM), .tFault)
        Do $$$AssertEquals(tHttp _ " " _ ..FaultText(tFault), "409 INTEROP.ITEM.SOURCECONTROL", tType _ " is refused for source control")
    }
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), ..#BASELINE, "no refused call changed an item")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "and nothing was logged as a fault")
}

/// <p>One port call through <var>pSeam</var> for the probe production's item <var>pName</var>; its HTTP status,
/// the wire fault in <var>pFault</var>.</p>
ClassMethod Leg(pSeam As %String, pType As %String, pName As %String, Output pFault) As %Integer
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tBody = ""
    If pType = "LIST" {
        Set tQuery("production") = ..#PRODUCTION
        Set tQuery("maxRows") = 1000
    } Else {
        Set tQuery("id") = $ClassMethod(..#CONTROL, "IdOf", pName)
    }
    If pType = "ADD" Set tBody = {"ClassName": "OcuPilotProbe.Interop.Op", "PoolSize": 1, "Enabled": false}
    Set tSC = $ClassMethod(pSeam, "Invoke", "Items", pType, .tQuery, tBody, .tResult, .tHttp, .pFault)
    Quit +$Get(tHttp)
}

/// <p><code>code failedPair</code> of a wire fault, <code>""</code> when it is not an object.</p>
ClassMethod FaultText(pFault) As %String
{
    If '$IsObject(pFault) Quit ""
    Set tText = pFault.%Get("code")
    If $IsObject(pFault.%Get("detail")) && (pFault.detail.%Get("failedPair") '= "") Set tText = tText _ " " _ pFault.detail.%Get("failedPair")
    Quit tText
}

/// <p>The failed pair a refusal envelope (raw JSON) names, or <code>""</code>.</p>
ClassMethod FailedPair(pRaw) As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("detail")) Quit ""
    Quit tBody.detail.%Get("failedPair")
}

/// <p>The names of a list read's rows (raw JSON), comma-separated.</p>
ClassMethod RowNames(pRaw) As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) || '$IsObject(tBody.%Get("rows")) Quit ""
    Set tText = ""
    Set tIterator = tBody.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.Name
    }
    Quit tText
}

/// <p><var>pBody</var> posted to <var>pPath</var> as <var>pUser</var>, scoped to <parameter>NAMESPACE</parameter>;
/// the status, and the raw answer in <var>pRaw</var>.</p>
Method Post(pPath As %String, pBody As %DynamicObject, pUser As %String, Output pRaw) As %Integer
{
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ "?ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, pUser, ..PreparedPassword, .tStatus, .pRaw, .tHeaders, pBody.%ToJSON(), "application/json", .tExtra, 90)
    Quit +$Get(tStatus)
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an
/// object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropItemGate).Probe($Job, pUser, ..#NAMESPACE, ..#PRODUCTION)::10
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

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of
/// <parameter>LEGS</parameter> through <class>OcuPilot.Port.InteropPort</class> in <var>pNamespace</var>
/// against the item and the added item of <var>pProduction</var>, evaluate each of <parameter>TOOLS</parameter>'
/// pairs for a request scoped to <var>pNamespace</var>, and signal <code>{loggedIn, username,
/// "&lt;endpoint&gt;|&lt;type&gt;": {http, code, failedPair}, tools: {&lt;tool&gt;: failed pair}}</code> to
/// process <var>pParent</var>, or <code>{error}</code> when something raised. It runs in its own process so
/// the login never touches the test's own identity.</p>
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
            Set tType = $Piece(tLegName, "|", 2)
            Kill tQuery
            Set tQuery("namespace") = pNamespace
            Set tBody = ""
            If tType = "LIST" {
                Set tQuery("production") = pProduction
                Set tQuery("maxRows") = 5
            } ElseIf (tType = "ADD") || (tType = "REMOVE") {
                Set tQuery("id") = pProduction _ $Char(1) _ ..#ADDED
                If tType = "ADD" Set tBody = {"ClassName": "OcuPilotProbe.Interop.Op", "PoolSize": 1, "Enabled": false}
            } Else {
                Set tQuery("id") = pProduction _ $Char(1) _ ..#ITEM
            }
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke($Piece(tLegName, "|", 1), tType, .tQuery, tBody, .tResult, .tHttp, .tFault)
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

/// <p>Create each of <parameter>PRINCIPALS</parameter> with a role of its own holding its pairs and READ on
/// the install namespace's code database, then read the decisive grants back.</p>
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
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the item endpoint's gate (throwaway)", tHome _ ":R," _ $Piece(tEntry, ":", 2, *), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot item gate test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.InteropItemGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        For tCase = $ListBuild("OcuP203Exact", "%Ens_ProductionConfig", "WRITE", 1), $ListBuild("OcuP203Exact", "%Ens_ProductionConfig", "READ", 1), $ListBuild("OcuP203NoPortal", "%Ens_Portal", "USE", 0), $ListBuild("OcuP203NoCfgRead", "%Ens_ProductionConfig", "READ", 0), $ListBuild("OcuP203NoCfgRead", "%Ens_ProductionConfig", "WRITE", 1), $ListBuild("OcuP203NoCfgWrite", "%Ens_ProductionConfig", "WRITE", 0), $ListBuild("OcuP203NoCfgWrite", "%Ens_ProductionConfig", "READ", 1), $ListBuild("OcuP203NoRead", "%DB_USER", "READ", 0), $ListBuild("OcuP203NoRead", "%DB_USER", "WRITE", 0), $ListBuild("OcuP203NoWrite", "%DB_USER", "WRITE", 0), $ListBuild("OcuP203NoWrite", "%DB_USER", "READ", 1) {
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
