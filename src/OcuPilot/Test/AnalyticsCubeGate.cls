/// <p>Pins the cube manager's gate against real principals (AD-8, AD-29, AD-44, AD-65, Story 20.34), over HTTP and, in a child process that
/// logs in as each, through <class>OcuPilot.Port.AnalyticsPort</class>: a principal without <code>%DeepSee_Admin:USE</code> (<b>P1</b>) is
/// refused the list and both actions naming it, before any vendor call; a principal holding it, the developer floor and READ and WRITE on
/// <code>USER</code>'s database (<b>P3</b>) reads the list, builds a cube through the screen, and does not see a cube whose resource it
/// lacks, an action on that cube reading absent; a principal holding the pair and READ alone (<b>P4</b>) reads the list and is refused both
/// actions naming <code>%DB_USER:WRITE</code> before any vendor call. After P3's Build, the Cubes list answers the new last build and
/// facts, and the agent's <code>analytics.cubemanager.read</code>, run as P3, answers the rows the screen answers.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and
/// deletes users and roles named <code>OcuP2034*</code> and, through <class>OcuPilot.Test.AnalyticsProbe</class>, turns analytics on in
/// <code>USER</code> and writes, builds and removes cubes there, the hidden cube among them. Each principal also holds READ on the install
/// namespace's code database, as every caller of a route must. The principals and the probe are removed after the last test.</p>
Class OcuPilot.Test.AnalyticsCubeGate Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter MANAGER = "OcuPilot.Test.AnalyticsCubeManager";

Parameter GATE = "OcuPilot.Test.AnalyticsGate";

Parameter NAMESPACE = "USER";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by <code>;</code>:
/// P1 without the Cube Registry's pair, P3 with it and WRITE on <code>USER</code>, P4 with it and READ alone.</p>
Parameter PRINCIPALS = "OcuP2034NoAdmin:%Development:U,%DB_USER:RW;OcuP2034Manager:%Development:U,%DeepSee_Admin:U,%DB_USER:RW;OcuP2034ReadOnly:%Development:U,%DeepSee_Admin:U,%DB_USER:R";

Parameter P1 = "OcuP2034NoAdmin";

Parameter P3 = "OcuP2034Manager";

Parameter P4 = "OcuP2034ReadOnly";

Parameter ACTION = "/screens/analytics.cubemanager/action";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsCubeGate creates and deletes users and roles, turns analytics on in USER and writes cubes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set ..PreparedPassword = "OcuP2034Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", ..#P3)
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals(..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.AnalyticsCubeGate")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the principals, their roles and the probe; a failing status when any survives.</p>
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
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsCubeGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsCubeGate left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>The cubes are put back as the probe created them, the hidden cube removed.</p>
Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveHidden"), "the hidden cube is removed")
    Do $$$AssertStatusOK($ClassMethod(..#MANAGER, "Rebuild"), "the probe cubes are built as they were created")
    Quit $$$OK
}

/// <p>A request over the wire as <var>pUser</var>, scoped to <parameter>NAMESPACE</parameter>: the HTTP status, the raw body in
/// <var>pRaw</var>.</p>
Method Call(pMethod As %String, pPath As %String, pUser As %String, pBody As %String, Output pRaw) As %Integer
{
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tUrl, pUser, ..PreparedPassword, .tStatus, .pRaw, .tHeaders, pBody, $Select(pBody = "": "", 1: "application/json"))
    Quit +$Get(tStatus)
}

/// <p>The person's row action <var>pAction</var> on the cube <var>pName</var> as <var>pUser</var>: the HTTP status and the refusal
/// <code>&lt;code&gt;|&lt;failed pair&gt;</code> the body carries (<code>""</code> for none).</p>
Method Act(pAction As %String, pName As %String, pUser As %String, Output pRaw) As %String
{
    Set tStatus = ..Call("POST", ..#ACTION, pUser, {"action": (pAction), "id": (pName)}.%ToJSON(), .pRaw)
    Quit tStatus _ " " _ ..Refusal(pRaw)
}

/// <p>The refusal a raw body carries, as <code>&lt;code&gt;|&lt;failed pair&gt;</code>; <code>""</code> for a body that is not a refusal.</p>
ClassMethod Refusal(pRaw As %String) As %String
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    If '$IsObject(tBody) || (tBody.%Get("code") = "") Quit ""
    Quit tBody.%Get("code") _ "|" _ $Select($IsObject(tBody.%Get("detail")): tBody.detail.%Get("failedPair"), 1: "")
}

/// <p>The rows of a list read's raw body, as a <class>%DynamicArray</class>, or <code>""</code>.</p>
ClassMethod RowsOf(pRaw As %String) As %DynamicArray
{
    Set tBody = ""
    Try { Set tBody = ##class(%DynamicObject).%FromJSON(pRaw) } Catch {}
    Quit $Select($IsObject(tBody) && $IsObject(tBody.%Get("rows")): tBody.rows, 1: "")
}

/// <p>The names of the probe cubes in a list read's raw body, sorted by the list, comma-separated.</p>
ClassMethod Names(pRaw As %String) As %String
{
    Set tNames = ""
    Set tRows = ..RowsOf(pRaw)
    If '$IsObject(tRows) Quit "unreadable"
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Extract(tRow.%Get("Name"), 1, 13) = "OcuPilotProbe" Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.%Get("Name")
    }
    Quit tNames
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.AnalyticsCubeGate).Probe($Job, pUser, ..#NAMESPACE)::10
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

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, ask the port for the cube manager's list, a
/// build of Categories and a synchronize of Visits in <var>pNamespace</var> (each as <code>&lt;http&gt;|&lt;code&gt;|&lt;failed pair&gt;</code>), and
/// run the agent's <code>analytics.cubemanager.read</code> scoped to it; P3 also asks the call-counting seam for a build of the hidden cube
/// (<code>hidden</code>: <code>&lt;http&gt;|&lt;code&gt;|&lt;vendor calls&gt;</code>). It signals <code>{loggedIn, username, legs, tool, hidden}</code> to process
/// <var>pParent</var>, or <code>{error}</code> when something raised. The build and the synchronize are asked of principals the gate
/// refuses: the probe never lets a principal that is admitted write.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        Set tLegs = {}
        For tCase = $ListBuild("List", "LIST", ""), $ListBuild("Build", "BUILD", "OcuPilotProbeCategories"), $ListBuild("Synchronize", "SYNCHRONIZE", "OcuPilotProbeVisits") {
            If ($List(tCase, 2) '= "LIST") && (pUsername = ..#P3) Continue
            Kill tQuery
            Set tQuery("namespace") = pNamespace
            If $List(tCase, 3) '= "" Set tQuery("id") = $List(tCase, 3)
            Set tFault = ""
            Set tSC = ##class(OcuPilot.Port.AnalyticsPort).Invoke("CubeManager", $List(tCase, 2), .tQuery, "", .tRows, .tHttp, .tFault)
            Do tLegs.%Set($List(tCase, 1), tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code") _ "|" _ $Select($IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: ""), 1: "|"))
        }
        Do tOut.%Set("legs", tLegs)
        Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
        Do tOut.%Set("tool", ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.cubemanager.read", {}, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS")))
        If pUsername = ..#P3 {
            ; A Build of the hidden cube through the call-counting seam, which answers OK where the vendor would be called: the port's own
            ; check must answer absent before it.
            Do ##class(OcuPilot.Test.AnalyticsCubeSeam).Reset()
            Kill tQuery
            Set tQuery("namespace") = pNamespace
            Set tQuery("id") = "OcuPilotProbeHidden"
            Set tFault = ""
            Set tSC = ##class(OcuPilot.Test.AnalyticsCubeSeam).Invoke("CubeManager", "BUILD", .tQuery, "", .tRows, .tHttp, .tFault)
            Do tOut.%Set("hidden", tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ ##class(OcuPilot.Test.AnalyticsCubeSeam).Calls())
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>AC4: P1, holding the portal's pair but not the Cube Registry's, is refused the Cube manager's list and both of its actions
/// 403 <code>AUTH.NOPRIVILEGE</code> naming <code>%DeepSee_Admin:USE</code>, over HTTP and through the port, and the cube's facts are as
/// they were.</p>
/// <p>Mutation (Rule 19): drop <code>%DeepSee_Admin:USE</code> from <parameter>OcuPilot.Port.AnalyticsPort.MANAGERPAIRS</parameter> -- the port legs go
/// red, and so does <method>OcuPilot.Test.PortGate</method>'s denial leg.</p>
Method TestAPrincipalWithoutTheCubeRegistrysPairIsRefusedNamingIt()
{
    Set tRefused = "403 AUTH.NOPRIVILEGE|%DeepSee_Admin:USE"
    Set tFacts = $ClassMethod(..#MANAGER, "Facts", "OcuPilotProbeVisits")
    Set tStatus = ..Call("GET", "/screens/analytics.cubemanager/read", ..#P1, "", .tRaw)
    Do $$$AssertEquals(tStatus _ " " _ ..Refusal(tRaw), tRefused, "the list is refused: " _ $Extract(tRaw, 1, 200))
    For tAction = "build", "synchronize" {
        Do $$$AssertEquals(..Act(tAction, "OcuPilotProbeVisits", ..#P1, .tRaw), tRefused, tAction _ " is refused: " _ $Extract(tRaw, 1, 200))
    }
    Set tProbe = ..ProbeAs(..#P1)
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..#P1, "the port probe ran as P1: " _ tProbe.%ToJSON())
    If $IsObject(tProbe.%Get("legs")) {
        Do $$$AssertEquals(tProbe.legs.%Get("List") _ ";" _ tProbe.legs.%Get("Build") _ ";" _ tProbe.legs.%Get("Synchronize"), "403|AUTH.NOPRIVILEGE|%DeepSee_Admin:USE;403|AUTH.NOPRIVILEGE|%DeepSee_Admin:USE;403|AUTH.NOPRIVILEGE|%DeepSee_Admin:USE", "the port refuses the list and both writes naming the pair")
    }
    Do $$$AssertEquals($ClassMethod(..#MANAGER, "Facts", "OcuPilotProbeVisits"), tFacts, "and no fact moved")
}

/// <p>AC4: P4, holding the Cube Registry's pair and READ on <code>USER</code> alone, reads the list and is refused Build and Synchronize
/// 403 naming <code>%DB_USER:WRITE</code>, over HTTP and through the port, before any vendor call: no build event is recorded.</p>
/// <p>Mutation (Rule 19): check READ in place of WRITE in <method>OcuPilot.Port.AnalyticsPort.AdmitDestination</method>, and drop the WRITE pair from
/// <method>OcuPilot.Screen.Tool.AnalyticsAction.PrivilegePairs</method> -- P4's legs go red.</p>
Method TestAPrincipalWithoutWriteOnTheFactDatabaseCanListButNotAct()
{
    Set tEvents = $ClassMethod(..#MANAGER, "Events")
    Set tStatus = ..Call("GET", "/screens/analytics.cubemanager/read", ..#P4, "", .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ (..Names(tRaw) [ "OcuPilotProbeVisits"), "200|1", "P4 reads the list: " _ $Extract(tRaw, 1, 200))
    For tAction = "build", "synchronize" {
        Do $$$AssertEquals(..Act(tAction, "OcuPilotProbeVisits", ..#P4, .tRaw), "403 AUTH.NOPRIVILEGE|%DB_USER:WRITE", tAction _ " is refused naming WRITE on the fact database: " _ $Extract(tRaw, 1, 200))
    }
    Set tProbe = ..ProbeAs(..#P4)
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..#P4, "the port probe ran as P4: " _ tProbe.%ToJSON())
    If $IsObject(tProbe.%Get("legs")) {
        Do $$$AssertEquals(tProbe.legs.%Get("List") _ ";" _ tProbe.legs.%Get("Build") _ ";" _ tProbe.legs.%Get("Synchronize"), "200||;403|AUTH.NOPRIVILEGE|%DB_USER:WRITE;403|AUTH.NOPRIVILEGE|%DB_USER:WRITE", "the port answers the list and refuses both writes naming WRITE")
    }
    Do $$$AssertEquals($ClassMethod(..#MANAGER, "Events"), tEvents, "and the vendor recorded no build event")
}

/// <p>AC4: with the hidden cube present, whose resource P3 lacks, the list P3 reads omits it, and a Build of it reads absent (404) with
/// nothing built, where the vendor's own check still applies on top of the gate.</p>
/// <p>The port shows a cube only when the vendor's <code>%GetCubeList</code> lists it for the caller, and that list applies the vendor's
/// <code>%CheckPrivilege</code>. The vendor's build answers #20013 for a hidden cube as well, so the HTTP legs alone cannot show the port's
/// check; the port leg counts the vendor calls through <class>OcuPilot.Test.AnalyticsCubeSeam</class>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.CubeShownHere</method> answer 1 for any name -- the port leg goes red, one vendor
/// call made.</p>
Method TestACubeTheCallersResourcesHideIsAbsent()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateHidden"), "the hidden cube is created")
    Set tEvents = $ClassMethod(..#MANAGER, "Events")
    Set tStatus = ..Call("GET", "/screens/analytics.cubemanager/read", ..#P3, "", .tRaw)
    Do $$$AssertEquals(tStatus _ "|" _ ..Names(tRaw), "200|OcuPilotProbeCategories,OcuPilotProbeGrid,OcuPilotProbeGuarded,OcuPilotProbeVisits", "P3 reads the probe cubes and not the hidden one: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertEquals($Piece(..Act("build", "OcuPilotProbeHidden", ..#P3, .tRaw), " ", 1), 404, "a Build of the hidden cube reads absent: " _ $Extract(tRaw, 1, 200))
    Set tProbe = ..ProbeAs(..#P3)
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..#P3, "the port probe ran as P3: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("hidden"), "404|PORT.NOTFOUND|0", "and the port answers absent for it before the vendor is called, which the call-counting seam shows")
    Do $$$AssertEquals($ClassMethod(..#MANAGER, "Events"), tEvents, "and the vendor recorded no build event")
}

/// <p>AC1, AC4, AC7: P3 builds Visits through the screen; the build is done and the Cubes list P3 reads answers the new last build and the
/// facts; the Cube manager's screen read answers a non-empty list of rows; the agent's <code>analytics.cubemanager.read</code>, run as P3 in a
/// child process, answers the rows the screen answers, and its Visits row carries 1000 facts and a non-empty last build equal to the one the
/// <code>STATE</code> read answers.</p>
/// <p>Mutation (Rule 19): answer OK without calling the vendor in <method>OcuPilot.Port.AnalyticsPort.VendorBuild</method> -- the Cubes-list leg goes
/// red; stop <method>OcuPilot.Port.AnalyticsPort.Rows</method> setting <code>LastBuild</code> on the Cube manager's row -- the read-tool leg goes red.</p>
Method TestAManagerBuildsThroughTheScreenAndTheAgentsReadAnswersTheScreensRows()
{
    Do ##class(OcuPilot.Test.AnalyticsCubeActions).Empty("OcuPilotProbeVisits")
    Do $$$AssertEquals($ClassMethod(..#MANAGER, "Facts", "OcuPilotProbeVisits"), 0, "Visits' facts are killed")
    Set tStatus = ..Act("build", "OcuPilotProbeVisits", ..#P3, .tRaw)
    Do $$$AssertEquals(tStatus, "200 ", "P3's Build is admitted and done: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#MANAGER, "Facts", "OcuPilotProbeVisits"), 1000, "Visits is rebuilt")
    Set tStatus = ..Call("GET", "/screens/analytics.cubes/read", ..#P3, "", .tRaw)
    Set tCubes = ..RowsOf(tRaw)
    Set tRow = $ClassMethod(..#MANAGER, "RowOf", tCubes, "OcuPilotProbeVisits")
    Set tAsk = $ClassMethod(..#MANAGER, "Ask", "STATE", "OcuPilotProbeVisits", .tState, .tFault)
    Do $$$AssertTrue($IsObject(tRow) && $IsObject(tState) && (tRow.Facts = 1000) && (tRow.LastBuild = tState.LastBuild), "the Cubes list answers the new facts and last build: " _ $Extract(tRaw, 1, 200))
    Set tStatus = ..Call("GET", "/screens/analytics.cubemanager/read", ..#P3, "", .tScreenRaw)
    Set tScreenRows = ..RowsOf(tScreenRaw)
    Do $$$AssertEquals(tStatus, 200, "the Cube manager reads for P3")
    Set tProbe = ..ProbeAs(..#P3)
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ ..#P3, "the tool probe ran as P3: " _ tProbe.%ToJSON())
    Do $$$AssertTrue($IsObject(tScreenRows) && (tScreenRows.%Size() > 0), "the Cube manager's screen read answers a non-empty list of rows: " _ $Extract(tScreenRaw, 1, 200))
    Do $$$AssertTrue($IsObject(tProbe.%Get("tool")), "the agent's read ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.tool.%Get("http"), 200, "the agent's read answers: " _ tProbe.tool.%ToJSON())
    Do $$$AssertTrue($IsObject(tProbe.tool.%Get("rows")) && (tProbe.tool.rows.%ToJSON() = tScreenRows.%ToJSON()), "and answers the rows the screen answers")
    Set tToolRow = $ClassMethod(..#MANAGER, "RowOf", tProbe.tool.%Get("rows"), "OcuPilotProbeVisits")
    Do $$$AssertTrue($IsObject(tToolRow) && $IsObject(tState) && (tToolRow.Facts = 1000) && (tToolRow.LastBuild '= "") && (tToolRow.LastBuild = tState.LastBuild), "the agent's Visits row carries 1000 facts and the last build the state read answers: " _ tProbe.tool.%ToJSON())
}

}
