/// <p>Pins the agent's MDX read against real principals (AD-8, AD-29, AD-44, AD-64, AD-65, Story 20.35), on MDX query's three principals
/// (<class>OcuPilot.Test.AnalyticsMdxGate</class>): the one holding READ and not WRITE on <code>USER</code>'s database is refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming <code>%DB_USER:WRITE</code> before the vendor is called; the one holding WRITE reads cells, and its cell drill
/// answers the vendor's own SQLCODE -99 as an <code>error</code> outcome because it holds no SELECT on the probe's source table; the one without
/// <code>%Development:USE</code> is refused naming it; and an adjustment of the screen's pairs (AD-64) reaches the read, which a port's own check
/// of MDX query's pairs cannot show.</p>
/// <p>The read runs in a child process (<method>Probe</method>) that logs in as the principal after the scope is set to <code>USER</code>, so this
/// process never changes identity.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes
/// the users and roles <class>OcuPilot.Test.AnalyticsMdxGate</class> names and, through <class>OcuPilot.Test.AnalyticsProbe</class>, turns
/// analytics on for <code>USER</code> and writes cubes there. The principals, the adjustment and the probe are removed after the last test.</p>
Class OcuPilot.Test.AnalyticsMdxReadGate Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter GATE = "OcuPilot.Test.AnalyticsMdxGate";

Parameter TOOL = "OcuPilot.Screen.Tool.AnalyticsMdxRead";

Parameter ACCESS = "OcuPilot.Kernel.State.Access";

/// <p>MDX query's tool identifier, the key of its adjustment.</p>
Parameter SCREEN = "analytics.mdxquery";

/// <p>The pairs the adjustment replaces the screen's with: its own and one the writer lacks.</p>
Parameter ADJUSTED = "%DeepSee_Portal:USE,%Development:USE,%Admin_Secure:USE";

Parameter NAMESPACE = "USER";

Parameter CROSSJOIN = "SELECT {[Measures].[Amount]} ON 0, NON EMPTY CROSSJOIN({[Sub].[H1].[Sub].&[1],[Sub].[H1].[Sub].&[2]},{[Sub2].[H1].[Sub2].&[0],[Sub2].[H1].[Sub2].&[1]}) ON 1 FROM [OcuPilotProbeGrid]";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxReadGate creates and deletes users and roles, turns analytics on in USER and writes cubes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP2035Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $Parameter(..#GATE, "WRITER"))
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals($Parameter(..#GATE, "PRINCIPALS"), ..PreparedPassword, "OcuPilot.Test.AnalyticsMdxReadGate")
    If $$$ISOK(tSC) Set tSC = ..ReadBack()
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Read the decisive grants back: the reader holds READ and not WRITE on <code>%DB_USER</code>, the writer both, and the viewer no
/// <code>%Development</code>.</p>
Method ReadBack() As %Status
{
    Set tReader = $Parameter(..#GATE, "READER")
    Set tWriter = $Parameter(..#GATE, "WRITER")
    Set tViewer = $Parameter(..#GATE, "VIEWER")
    Set tSC = $$$OK
    For tCase = $ListBuild(tReader, "%DB_USER", "READ", 1), $ListBuild(tReader, "%DB_USER", "WRITE", 0), $ListBuild(tWriter, "%DB_USER", "WRITE", 1), $ListBuild(tWriter, "%Admin_Secure", "USE", 0), $ListBuild(tViewer, "%Development", "USE", 0), $ListBuild(tWriter, "%Development", "USE", 1) {
        If $SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) '= $List(tCase, 4) {
            Set tSC = $$$ERROR($$$GeneralError, "the principal " _ $List(tCase, 1) _ "'s " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " did not read back as declared")
            Quit
        }
    }
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Quit ..Unadjust()
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ..Unadjust()
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove"))
    Set tPrincipals = $Parameter(..#GATE, "PRINCIPALS")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(tPrincipals, ";") {
            Set tUser = $Piece($Piece(tPrincipals, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxReadGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxReadGate left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>Adjust MDX query's pairs to <parameter>ADJUSTED</parameter> (AD-64).</p>
Method Adjust() As %Status
{
    Quit $ClassMethod(..#ACCESS, "GuardedPut", ..#SCREEN, ..#ADJUSTED, 0, $Username)
}

/// <p>Remove MDX query's adjustment, if it holds one.</p>
Method Unadjust() As %Status
{
    Set tSC = $ClassMethod(..#ACCESS, "GuardedGet", ..#SCREEN, .tPairs, .tVersion, .tFound)
    If $$$ISOK(tSC) && tFound Set tSC = $ClassMethod(..#ACCESS, "GuardedRemove", ..#SCREEN, tVersion)
    Quit tSC
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.AnalyticsMdxReadGate).Probe($Job, pUser, ..#NAMESPACE)::10
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

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, set the scope to <var>pNamespace</var>, read the grid's
/// crossjoin and one cell's drill through the tool, and signal <code>{loggedIn, username, cells, drill}</code>, each leg as
/// <method>Leg</method>'s line, to process <var>pParent</var>, or <code>{error}</code> when something raised.</p>
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
        Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
        Do tOut.%Set("cells", ..Leg({"statement": (..#CROSSJOIN)}))
        Do tOut.%Set("drill", ..Leg({"statement": (..#CROSSJOIN), "drill": {"row": 2, "column": 1}}))
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>One read of the tool with <var>pArgs</var> as the process's user, as <code>&lt;http&gt;|&lt;code&gt;|&lt;failed pair&gt;|&lt;outcome&gt;|&lt;1 when the
/// message names SQLCODE -99&gt;</code>.</p>
ClassMethod Leg(pArgs As %DynamicObject) As %String
{
    Set tSC = $ClassMethod(..#TOOL, "View", "", pArgs, 200, .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit +$Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ "|" _ $Select($IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: ""), 1: "|") _ "||"
    Quit tHttp _ "||" _ tResult.%Get("outcome") _ "|" _ $Select(tResult.%Get("message") [ "SQLCODE: -99": 1, 1: 0)
}

/// <p>AC6: the principal holding READ and not WRITE on <code>USER</code>'s database is refused 403 <code>AUTH.NOPRIVILEGE</code> naming
/// <code>%DB_USER:WRITE</code>, on a cells read and on a drill, because every prepare and execute writes the vendor's result cache there.</p>
/// <p>Mutation (Rule 19): skip the cache database's WRITE check in <method>OcuPilot.Port.AnalyticsPort.MdxAdmit</method> -- the reader's read reaches
/// the vendor and fails on an unnamed <code>&lt;PROTECT&gt;</code>, and this goes red.</p>
Method TestAPrincipalWithoutWriteOnTheCacheDatabaseIsRefusedNamingIt()
{
    Set tProbe = ..ProbeAs($Parameter(..#GATE, "READER"))
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ $Parameter(..#GATE, "READER"), "the probe ran as the reader: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("cells") _ " " _ tProbe.%Get("drill"), "403|AUTH.NOPRIVILEGE|%DB_USER:WRITE|| 403|AUTH.NOPRIVILEGE|%DB_USER:WRITE||", "both reads are refused naming the cache database's WRITE")
}

/// <p>AC6: the principal that also holds WRITE reads a cells query to its cells, and a cell's drill answers the vendor's own SQLCODE -99 as an
/// <code>error</code> outcome, because the listing reads the probe's source table, which it holds no SELECT on.</p>
/// <p>Mutation (Rule 19): ignore <code>drill</code> in <method>OcuPilot.Port.AnalyticsPort.MdxRun</method> (pass an empty row) -- the drill reads the
/// cells instead and this goes red.</p>
Method TestAWriterReadsCellsAndItsDrillAnswersTheVendorsSqlRefusal()
{
    Set tProbe = ..ProbeAs($Parameter(..#GATE, "WRITER"))
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ $Parameter(..#GATE, "WRITER"), "the probe ran as the writer: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("cells"), "200||cells|0", "its cells read runs")
    Do $$$AssertEquals(tProbe.%Get("drill"), "200||error|1", "and its drill ends with the vendor's SQLCODE -99 as an error outcome")
}

/// <p>AC6: the principal without <code>%Development:USE</code> is refused 403 naming it, before the vendor is called.</p>
/// <p>Mutation (Rule 19): none alone. The read's own evaluation of MDX query's pairs and the port's check of the same pairs
/// (<parameter>OcuPilot.Port.AnalyticsPort.MDXPAIRS</parameter>) each refuse here, so it takes both removals to redden this leg; the adjustment leg
/// below is what shows the read's own evaluation is made.</p>
Method TestAPrincipalWithoutTheDeveloperPairIsRefusedNamingIt()
{
    Set tProbe = ..ProbeAs($Parameter(..#GATE, "VIEWER"))
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ $Parameter(..#GATE, "VIEWER"), "the probe ran as the viewer: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("cells") _ " " _ tProbe.%Get("drill"), "403|AUTH.NOPRIVILEGE|%Development:USE|| 403|AUTH.NOPRIVILEGE|%Development:USE||", "both reads are refused naming %Development:USE")
}

/// <p>AC6, AD-64: an adjustment of MDX query's pairs reaches the read. With <code>%Admin_Secure:USE</code> added, the writer, who passes the port's
/// own check of MDX query's pairs, is refused naming it; with the adjustment removed it reads again. The port's check repeats the screen's declared
/// pairs, so only the read's own evaluation of the screen's pairs can refuse here.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Screen.Gate.Evaluate</method> in <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.View</method> -- the
/// adjusted writer reads and this goes red.</p>
Method TestAnAdjustmentOfTheScreensPairsReachesTheRead()
{
    Do $$$AssertStatusOK(..Adjust(), "the screen's pairs are adjusted")
    Set tProbe = ..ProbeAs($Parameter(..#GATE, "WRITER"))
    Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ $Parameter(..#GATE, "WRITER"), "the probe ran as the writer: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("cells"), "403|AUTH.NOPRIVILEGE|%Admin_Secure:USE||", "the adjusted read is refused naming the added pair")
    Do $$$AssertStatusOK(..Unadjust(), "the adjustment is removed")
    Set tProbe = ..ProbeAs($Parameter(..#GATE, "WRITER"))
    Do $$$AssertEquals(tProbe.%Get("cells"), "200||cells|0", "and the writer reads again")
}

}
