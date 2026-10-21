/// <p>Pins MDX query's gate against real principals (AD-8, AD-29, AD-44, AD-65, Story 20.33): a principal holding the developer floor and READ on
/// <code>USER</code>'s database but not WRITE (the <b>reader</b>) is refused naming <code>%DB_USER:WRITE</code>, before any vendor call would
/// have answered an unnamed <code>&lt;PROTECT&gt;</code>, because every prepare and execute writes the vendor's result cache there; a principal
/// that also holds WRITE (the <b>writer</b>) runs a cells query, and its cell drill answers the vendor's own SQLCODE -99 as an
/// <code>error</code> outcome, because it holds no SELECT on the probe's source table; a principal without <code>%Development:USE</code> (the
/// <b>viewer</b>) is refused naming it.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes
/// users and roles named <code>OcuP2033*</code> and, through <class>OcuPilot.Test.AnalyticsProbe</class>, turns analytics on for <code>USER</code>
/// and writes cubes there. The principals and the probe are removed after the last test.</p>
Class OcuPilot.Test.AnalyticsMdxGate Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter STORE = "OcuPilot.Kernel.State.SqlRun";

Parameter START = "/api/ocupilot/analytics/mdx/background";

Parameter POLL = "/api/ocupilot/analytics/mdx/background/:id";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>.</p>
Parameter PRINCIPALS = "OcuP2033GateReader:%Development:U,%DB_USER:R;OcuP2033GateWriter:%Development:U,%DB_USER:RW;OcuP2033GateViewer:%Ens_Portal:U,%DB_USER:RW";

Parameter READER = "OcuP2033GateReader";

Parameter WRITER = "OcuP2033GateWriter";

Parameter VIEWER = "OcuP2033GateViewer";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxGate creates and deletes users and roles, turns analytics on in USER and writes cubes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP2033Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", ..#WRITER)
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals(..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.AnalyticsMdxGate")
    If $$$ISOK(tSC) Set tSC = ..ReadBack()
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Read the decisive grants back: the reader holds READ and not WRITE on <code>%DB_USER</code>, the writer both, and the viewer no
/// <code>%Development</code>.</p>
Method ReadBack() As %Status
{
    For tCase = $ListBuild(..#READER, "%DB_USER", "READ", 1), $ListBuild(..#READER, "%DB_USER", "WRITE", 0), $ListBuild(..#WRITER, "%DB_USER", "WRITE", 1), $ListBuild(..#VIEWER, "%DB_USER", "WRITE", 1), $ListBuild(..#VIEWER, "%Development", "USE", 0), $ListBuild(..#WRITER, "%Development", "USE", 1) {
        If $SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) '= $List(tCase, 4) Quit $$$ERROR($$$GeneralError, "the principal " _ $List(tCase, 1) _ "'s " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " did not read back as declared")
    }
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    For tI = 1:1:$Length(..#PRINCIPALS, ";") {
        Do $ClassMethod(..#STORE, "GuardedForgetUser", $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1))
    }
    Quit $$$OK
}

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
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxGate left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>POST <var>pBody</var> to the start route as <var>pUser</var> in <code>USER</code>: the status and the parsed answer.</p>
Method Start(pUser As %String, pBody As %DynamicObject, Output pStatus As %Integer, Output pAnswer)
{
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#START _ "?ns=USER", pUser, ..PreparedPassword, .pStatus, .tRaw, .tHeaders, pBody.%ToJSON(), "application/json")
    Set pAnswer = ""
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pAnswer = $Get(tRaw) }
}

/// <p>Start <var>pBody</var> as <var>pUser</var>, expect 202 and poll its run until it ends; the last answer.</p>
Method RunToEnd(pUser As %String, pBody As %DynamicObject) As %DynamicObject
{
    Do ..Start(pUser, pBody, .tStatus, .tAnswer)
    If tStatus '= 202 Quit $Select($IsObject(tAnswer): tAnswer, 1: {"error": (tAnswer)})
    Set tKey = tAnswer.%Get("id")
    Set tDeadline = $ZHorolog + 30
    For {
        Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Replace(..#POLL, ":id", tKey) _ "?ns=USER", pUser, ..PreparedPassword, .tStatus, .tRaw)
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
        If (tAnswer.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Quit tAnswer
}

/// <p>The refusal a start answers, as <code>&lt;status&gt; &lt;code&gt; &lt;failed pair&gt;</code>.</p>
ClassMethod Refusal(pStatus As %Integer, pAnswer) As %String
{
    If '$IsObject(pAnswer) Quit pStatus _ " " _ pAnswer
    Quit pStatus _ " " _ pAnswer.%Get("code") _ " " _ $Select($IsObject(pAnswer.%Get("detail")): pAnswer.detail.%Get("failedPair"), 1: "")
}

/// <p>AC7: the reader, holding READ on <code>USER</code>'s database and not WRITE, is refused 403 <code>AUTH.NOPRIVILEGE</code> naming
/// <code>%DB_USER:WRITE</code>, and no run is reserved; the viewer is refused naming <code>%Development:USE</code>.</p>
/// <p>Mutation (Rule 19): skip the cache database's WRITE check in <method>OcuPilot.Port.AnalyticsPort.MdxAdmit</method> -- the reader's
/// start is answered 202 and its run fails on an unnamed <code>&lt;PROTECT&gt;</code>, and this goes red. Drop <code>%Development:USE</code> from
/// <parameter>OcuPilot.Port.AnalyticsPort.MDXPAIRS</parameter> -- the screen's own pair still refuses the viewer, so
/// <code>OcuPilot.Test.PortGate</code> goes red instead.</p>
Method TestTheCacheDatabasesWritePairAndTheDeveloperPairAreNamed()
{
    Do ..Start(..#READER, {"statement": "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeGrid]"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(..Refusal(tStatus, tAnswer), "403 AUTH.NOPRIVILEGE %DB_USER:WRITE", "the reader is refused naming the cache database's WRITE")
    Do ..Start(..#VIEWER, {"statement": "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeGrid]"}, .tStatus, .tAnswer)
    Do $$$AssertEquals(..Refusal(tStatus, tAnswer), "403 AUTH.NOPRIVILEGE %Development:USE", "the viewer is refused naming %Development:USE")
    Set tRows = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) IN (?, ?)", ..#READER, ..#VIEWER)
    Do $$$AssertTrue(tRows.%Next() && (tRows.%GetData(1) = 0), "and neither reserved a run")
}

/// <p>AC7: the writer runs a cells query to its cells, and a cell's drill-through answers the vendor's own SQLCODE -99 as an
/// <code>error</code> outcome, because the listing reads the probe's source table, which the writer holds no SELECT on.</p>
Method TestAWriterRunsCellsAndItsDrillAnswersTheVendorsSqlRefusal()
{
    Set tView = ..RunToEnd(..#WRITER, {"statement": (..#CROSSJOIN)})
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status") _ " " _ tView.result.outcome _ " " _ tView.result.rows.%Size(), 1: ""), "ended cells 2", "the writer's cells query runs: " _ $Select($IsObject(tView): tView.%ToJSON(), 1: ""))
    Do $ClassMethod(..#STORE, "GuardedForgetUser", ..#WRITER)
    Set tView = ..RunToEnd(..#WRITER, {"statement": (..#CROSSJOIN), "drill": {"row": 2, "column": 1}})
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status") _ " " _ tView.result.outcome _ " " _ (tView.result.message [ "SQLCODE: -99"), 1: ""), "ended error 1", "its drill-through ends with the vendor's SQLCODE -99 as an error outcome: " _ $Select($IsObject(tView): $Extract(tView.%ToJSON(), 1, 300), 1: ""))
}

}
