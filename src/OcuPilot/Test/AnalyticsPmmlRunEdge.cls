/// <p>Pins Story 24.14's PMML test at its edges (AD-7, AD-8, AD-41, AD-42, AD-65), against <code>USER</code> and the definition of <class>OcuPilot.Test.PmmlProbe</class>: a source that is not an SQL query,
/// a custom statement or a declared data source, is refused with SQL query's own classification and self-protection check, and an SQL the instance cannot prepare is answered at once, before anything is
/// reserved or spawned; a class or model that is absent, a data source the definition does not declare, verification records a model does not carry and a cube a principal may not read are refused by their codes
/// before the vendor runs; a body of any other shape, a caller without the developer pair and a namespace without analytics are refused; a run past its bound ends <code>stopped</code>; a cancel by a run's owner,
/// served by a web process other than the one that started the run, answers <code>canceled</code> within two seconds over a statement that scans for a long time, a fast cross join and a child in no statement,
/// ends the run's own child and no other process, and leaves no result row, no run record, no event resource, no held run lock and no live process; a wake without the stop flag is ignored, a deleted event is
/// created again, a hung child is ended at the bound plus the grace, and a stale row ends no process; and another user's poll and cancel are 404 and change nothing, and a second start of the owner's is 409 busy.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and removes IRIS users and roles and a web application, and, through the probes,
/// turns analytics on for <code>USER</code> and writes cubes and classes there. Every run a test starts has ended, and every run row, result row, run record and event resource it made is removed, before the
/// test returns.</p>
Class OcuPilot.Test.AnalyticsPmmlRunEdge Extends %UnitTest.TestCase [ DependsOn = (OcuPilot.Test.AnalyticsProbe, OcuPilot.Test.PmmlProbe, OcuPilot.Test.PmmlRunWatch, OcuPilot.Test.PmmlHoldRouter) ]
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PMML = "OcuPilot.Test.PmmlProbe";

Parameter WATCH = "OcuPilot.Test.PmmlRunWatch";

Parameter STORE = "OcuPilot.Kernel.State.SqlRun";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter QUICK = "OcuPilot.Test.PmmlTestQuick";

Parameter IDLE = "OcuPilot.Test.PmmlTestIdle";

Parameter HUNG = "OcuPilot.Test.PmmlTestHung";

Parameter START = "/api/ocupilot/analytics/pmml/background";

Parameter POLL = "/api/ocupilot/analytics/pmml/background/:id";

Parameter CANCEL = "/api/ocupilot/analytics/pmml/background/:id/cancel";

/// <p>The web application <method>CreateHoldApp</method> makes: the product application's properties over <class>OcuPilot.Test.PmmlHoldRouter</class>.</p>
Parameter HOLDAPP = "/ocupilot-t2414pmml";

Parameter PRODUCTAPP = "/api/ocupilot";

Parameter ROUTER = "OcuPilot.Test.PmmlHoldRouter";

Parameter NAMESPACE = "USER";

Parameter DEFINITION = {##class(OcuPilot.Test.PmmlProbe).#DEFINITIONCLASS};

/// <p>A principal that reaches the API and holds <code>%DeepSee_Portal</code> but not <code>%Development</code>, so only the developer pair refuses it; and one that holds both pairs and reads <code>USER</code> but
/// not <code>%DeepSee_Admin</code>, the resource of the cube the probe's cube data source names. The second is granted <code>SELECT</code> on the probe's source table once the probe is made
/// (<method>GrantReader</method>), so its custom statements run with its own rights.</p>
Parameter PRINCIPALS = "OcuP2414PmmlNoDev:%Ens_Portal:U,%DeepSee_Portal:U,%DB_USER:R;OcuP2414PmmlReader:%Ens_Portal:U,%DeepSee_Portal:U,%Development:U,%DB_USER:R";

Parameter NODEV = "OcuP2414PmmlNoDev";

Parameter READER = "OcuP2414PmmlReader";

/// <p>A cross join of the source rows with itself five times (248,832 rows): slow enough to stop at a short bound.</p>
Parameter FIVEWAY = "SELECT a.ID, a.X, a.Color, a.Y FROM ProbePmml.Source a, ProbePmml.Source b, ProbePmml.Source c, ProbePmml.Source d, ProbePmml.Source e";

/// <p>A cross join of the source rows with itself nine times (over five billion combinations) that keeps the one combination whose nine <code>X</code> values sum to nine, which is the first one scanned.
/// The child writes that row and then spends its time inside the statement's scan.</p>
Parameter SLOWSCAN = "SELECT a.ID, a.X, a.Color, a.Y FROM ProbePmml.Source a, ProbePmml.Source b, ProbePmml.Source c, ProbePmml.Source d, ProbePmml.Source e, ProbePmml.Source f, ProbePmml.Source g, ProbePmml.Source h, ProbePmml.Source i WHERE a.X + b.X + c.X + d.X + e.X + f.X + g.X + h.X + i.X = 9";

/// <p>A cross join of the source rows with itself six times (2,985,984 combinations), each of which is a row: the child is inside the statement for a small share of its time, so a cancel that interrupts the
/// statement would miss it.</p>
Parameter SIXWAY = "SELECT a.ID, a.X, a.Color, a.Y FROM ProbePmml.Source a, ProbePmml.Source b, ProbePmml.Source c, ProbePmml.Source d, ProbePmml.Source e, ProbePmml.Source f";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPmmlRunEdge creates IRIS users and roles and a web application, turns analytics on in USER and compiles classes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set ..PreparedPassword = "OcuP2414Pmml" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PMML, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $Username)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PMML, "Create")
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals(..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.AnalyticsPmmlRunEdge")
    If $$$ISOK(tSC) Set tSC = ..GrantReader()
    If $$$ISOK(tSC) Set tSC = ..CreateHoldApp()
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Grant <code>SELECT</code> on the probe's source table to <parameter>READER</parameter>, in <code>USER</code>. The grant goes with the table when the probe is removed.</p>
ClassMethod GrantReader() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT ON ProbePmml.Source TO " _ ..#READER)
        If tResult.%SQLCODE < 0 Set tSC = $$$ERROR($$$GeneralError, "the grant of SELECT on the probe's source table failed: SQLCODE " _ tResult.%SQLCODE)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create <parameter>HOLDAPP</parameter>, which has every property of the product's application <parameter>PRODUCTAPP</parameter> but its dispatch class, <parameter>ROUTER</parameter>, and its cookie path.</p>
ClassMethod CreateHoldApp() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Applications).Get(..#PRODUCTAPP, .tProps)
        If $$$ISERR(tSC) Quit
        Kill tProps("Name")
        Set tProps("DispatchClass") = ..#ROUTER
        Set tProps("CookiePath") = ..#HOLDAPP _ "/"
        Set tProps("Description") = "Story 24.14 test application: the PMML test's routes, answering the serving process id"
        If ##class(Security.Applications).Exists(..#HOLDAPP) Set tSC = ##class(Security.Applications).Delete(..#HOLDAPP)
        If $$$ISOK(tSC) Set tSC = ##class(Security.Applications).Create(..#HOLDAPP, .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete <parameter>HOLDAPP</parameter>; an error when it is still there.</p>
ClassMethod RemoveHoldApp() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(..#HOLDAPP) Set tSC = ##class(Security.Applications).Delete(..#HOLDAPP)
        If $$$ISOK(tSC) && ##class(Security.Applications).Exists(..#HOLDAPP) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPmmlRunEdge left the web application " _ ..#HOLDAPP)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit ..Settle()
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ..Settle()
    Set tSC = $$$ADDSC(tSC, ..RemoveHoldApp())
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PMML, "Remove"))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove"))
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tName = ..#NODEV, ..#READER {
            If ##class(Security.Users).Exists(tName) Do ##class(Security.Users).Delete(tName)
            If ##class(Security.Roles).Exists(tName _ "Role") Do ##class(Security.Roles).Delete(tName _ "Role")
            If ##class(Security.Users).Exists(tName) || ##class(Security.Roles).Exists(tName _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPmmlRunEdge left the principal or role of " _ tName))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    If $$$ISOK(tSC) && ('$ClassMethod(..#PMML, "Gone") || '$ClassMethod(..#PROBE, "Gone")) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPmmlRunEdge left probe state in USER: " _ $ClassMethod(..#PMML, "Left") _ " " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>Stop every live PMML run of the three accounts, wait up to 30 seconds for each to end, then remove every row of theirs; an error when a run is still live.</p>
Method Settle() As %Status
{
    Set tOwners = $ListBuild(##class(OcuPilot.Test.Http).GetTestUsername(), ..#NODEV, ..#READER, $Username)
    Set tDeadline = $ZHorolog + 30
    For {
        Set tLive = 0
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(UserName), RunKey FROM OcuPilot_Kernel_State.SqlRun WHERE State IN ('queued', 'running') AND COALESCE(Kind, 'sql') = 'pmml'")
        While tResult.%Next() {
            If '$ListFind(tOwners, tResult.%GetData(1)) Continue
            Set tLive = tLive + 1
            Do ##class(OcuPilot.Area.Analytics.PmmlTest).Cancel(tResult.%GetData(2), tResult.%GetData(1), .tFound)
        }
        If (tLive = 0) || ($ZHorolog > tDeadline) Quit
        Hang 0.5
        Do $ClassMethod(..#STORE, "GuardedSweep", ..#LIMITS)
    }
    For tI = 1:1:$ListLength(tOwners) Do $ClassMethod(..#STORE, "GuardedForgetUser", $List(tOwners, tI))
    Do $ClassMethod(..#PMML, "DropRows")
    If tLive Quit $$$ERROR($$$GeneralError, "a PMML run of this class was still live after 30 seconds")
    Quit $$$OK
}

/// <p>The password of <var>pUser</var>.</p>
Method PasswordOf(pUser As %String) As %String
{
    If pUser = ##class(OcuPilot.Test.Http).GetTestUsername() Quit ##class(OcuPilot.Test.Http).GetTestPassword()
    Quit ..PreparedPassword
}

/// <p>Send <var>pMethod</var> <var>pPath</var> as <var>pUser</var> in namespace <var>pNamespace</var>, with <var>pBody</var> when it is given; the status, the parsed answer, and the process id of the web
/// process that served it when the application answers one (<class>OcuPilot.Test.PmmlHoldRouter</class>).</p>
Method Send(pMethod As %String, pPath As %String, pUser As %String, Output pStatus As %Integer, Output pAnswer, pBody = "", pNamespace As %String = {..#NAMESPACE}, Output pPid As %String)
{
    Set tText = $Select($IsObject(pBody): pBody.%ToJSON(), 1: pBody)
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ pNamespace, pUser, ..PasswordOf(pUser), .pStatus, .tRaw, .tHeaders, tText, "application/json")
    Set pPid = $Get(tHeaders("X-PID"))
    Set pAnswer = ""
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    } Catch {
        Set pAnswer = $Get(tRaw)
    }
}

/// <p>A refusal as one line: the status and the envelope's code.</p>
ClassMethod Code(pStatus As %Integer, pAnswer) As %String
{
    Quit $Get(pStatus) _ " " _ $Select($IsObject($Get(pAnswer)): pAnswer.%Get("code"), 1: $Get(pAnswer))
}

/// <p>The test account's start of the model <var>pModel</var> of the probe's definition against <var>pSource</var>, with <var>pDataSource</var> or <var>pSQL</var> when they are given: the one line
/// <method>Code</method> reads, and the answer.</p>
Method Start(pModel As %String, pSource As %String, pDataSource As %String, pSQL As %String, Output pAnswer, pUser As %String = {##class(OcuPilot.Test.Http).GetTestUsername()}, pNamespace As %String = {..#NAMESPACE}) As %String
{
    Set tBody = {"model": (..#DEFINITION _ "||" _ pModel), "source": (pSource)}
    If pDataSource '= "" Do tBody.%Set("dataSource", pDataSource)
    If pSQL '= "" Do tBody.%Set("sql", pSQL)
    Do ..Send("POST", ..#START, pUser, .tStatus, .pAnswer, tBody, pNamespace)
    Quit ..Code(tStatus, pAnswer)
}

/// <p>The vendor's test-id counter, which each run advances by one.</p>
ClassMethod Counter() As %Integer
{
    Quit +$Get(^IRIS.Temp.DeepSee.PMML.ResultI("TestIdx"))
}

/// <p>How many PMML run rows exist and the sum of the source rows' <code>X</code>, as <code>rows|sum</code>: what a refused start must leave as it found it.</p>
ClassMethod Footprint() As %String
{
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE COALESCE(Kind, 'sql') = 'pmml'")
    Set tRuns = $Select(tResult.%Next(): +tResult.%GetData(1), 1: -1)
    Set tSum = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSumResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT SUM(X) FROM ProbePmml.Source")
        Set tSum = $Select(tSumResult.%Next(): tSumResult.%GetData(1), 1: "unread")
    } Catch {
        Set tSum = "unread"
    }
    Set $NAMESPACE = tOrigNS
    Quit tRuns _ "|" _ tSum
}

/// <p>AC4: a source that is not an SQL query is refused before anything is reserved, spawned or run, with SQL query's own classification: a custom statement that changes rows and a declared data source whose SQL
/// does is 422 <code>ANALYTICS.PMML.QUERYONLY</code>, a custom query and a declared data source that name OcuPilot's own state are 403 with the code SQL query's self-protection check gives the same text, and an SQL
/// the instance cannot prepare is answered <code>{outcome: error}</code> at once, with no run id. No refusal allocates a test id, starts a run or changes a source row.</p>
/// <p>Mutation (Rule 19): drop the kind test from <method>OcuPilot.Area.Analytics.PmmlTest.Check</method> -- the 422 legs go red; drop the <code>SqlConsole.Check</code> call -- the 403 legs go red.</p>
Method TestASourceThatIsNotAQueryIsRefusedBeforeAnythingRuns()
{
    Set tBefore = ..Counter() _ "|" _ ..Footprint()
    Set tChange = "UPDATE ProbePmml.Source SET X = X"
    Set tState = "SELECT ID FROM OcuPilot_Kernel_State.SqlRun"
    Set tSC = ##class(OcuPilot.Area.Explorer.SqlConsole).Check(..#NAMESPACE, tState, .tGuard, .tCheckHttp, .tCheckFault)
    Set tStateCode = $Select($IsObject($Get(tCheckFault)): tCheckFault.%Get("code"), 1: "")
    Do $$$AssertTrue((tStateCode '= "") && (tCheckHttp = 403), "SQL query's own check refuses the state query: " _ tCheckHttp _ " " _ tStateCode)
    Do $$$AssertEquals(..Start("Colors", "custom", "", tChange, .tAnswer), "422 ANALYTICS.PMML.QUERYONLY", "a custom statement that changes rows is not a query")
    Do $$$AssertEquals(..Start("Colors", "dataset", ##class(OcuPilot.Test.PmmlProbe).#CHANGESOURCE, "", .tAnswer), "422 ANALYTICS.PMML.QUERYONLY", "nor is a declared data source whose SQL does")
    Do $$$AssertEquals(..Start("Colors", "custom", "", tState, .tAnswer), "403 " _ tStateCode, "a custom query over OcuPilot's state is refused as SQL query refuses it")
    Do $$$AssertEquals(..Start("Colors", "dataset", ##class(OcuPilot.Test.PmmlProbe).#STATESOURCE, "", .tAnswer), "403 " _ tStateCode, "and so is a declared data source's")
    Set tLine = ..Start("Colors", "custom", "", "SELECT ID, X FROM ProbePmml.NoSuchTable", .tAnswer)
    Do $$$AssertEquals(tLine, "200 ", "an SQL the instance cannot prepare is answered at once, with no run: " _ tLine)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("outcome") _ "|" _ tAnswer.%IsDefined("id"), 1: ""), "error|0", "as an error outcome")
    Do $$$AssertEquals(..Counter() _ "|" _ ..Footprint(), tBefore, "nothing was allocated, started or changed")
}

/// <p>Whether <var>pClass</var> is compiled in <code>USER</code>.</p>
ClassMethod Compiled(pClass As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tExists = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tExists = ''##class(%Dictionary.CompiledClass).%ExistsId(pClass)
    } Catch {
        Set tExists = -1
    }
    Set $NAMESPACE = tOrigNS
    Quit tExists
}

/// <p>A custom SQL statement of any other kind is refused before anything is reserved, spawned or run: a statement that creates a table or a view is 422
/// <code>ANALYTICS.PMML.QUERYONLY</code> as one that inserts or deletes rows is, and one that controls a session or grants a privilege is refused with SQL query's own code for it, not this one. A second statement
/// after a query does not prepare, so it is answered as an error at once. No statement here would change a source row were it to run, and none does: no table or view is made, no source row changes
/// and no test id is allocated.</p>
/// <p>Mutation (Rule 19): drop the kind test from <method>OcuPilot.Area.Analytics.PmmlTest.Check</method> -- the DDL and DML legs go red; the session and privilege legs, which SQL query refuses first, stay green.</p>
Method TestAnSqlStatementOfAnyOtherKindIsRefusedBeforeAnythingRuns()
{
    Set tBefore = ..Counter() _ "|" _ ..Footprint()
    Set tQuery = "SELECT ID, X, Color, Y FROM ProbePmml.Source"
    For tCase = $ListBuild("a table is created", "CREATE TABLE ProbePmml.Scratch (A INT)", "422 ANALYTICS.PMML.QUERYONLY"), $ListBuild("a view is created", "CREATE VIEW ProbePmml.ScratchView AS " _ tQuery, "422 ANALYTICS.PMML.QUERYONLY"), $ListBuild("rows are inserted", "INSERT INTO ProbePmml.Source (X, Color, Y) SELECT X, Color, Y FROM ProbePmml.Source WHERE X < 0", "422 ANALYTICS.PMML.QUERYONLY"), $ListBuild("rows are deleted", "DELETE FROM ProbePmml.Source WHERE X < 0", "422 ANALYTICS.PMML.QUERYONLY"), $ListBuild("a transaction option is set", "SET TRANSACTION ISOLATION LEVEL READ COMMITTED", "422 " _ ##class(OcuPilot.Api.AtelierError).#SQLSESSION), $ListBuild("a privilege is granted", "GRANT SELECT ON ProbePmml.Source TO PUBLIC", "422 " _ ##class(OcuPilot.Api.AtelierError).#SQLADMINISTRATION) {
        Set tLine = ..Start("Colors", "custom", "", $List(tCase, 2), .tAnswer)
        Do $$$AssertEquals(tLine, $List(tCase, 3), $List(tCase, 1) _ " as a custom source: " _ tLine)
    }
    Set tLine = ..Start("Colors", "custom", "", tQuery _ "; DELETE FROM ProbePmml.Source WHERE X < 0", .tAnswer)
    Do $$$AssertEquals(tLine _ "|" _ $Select($IsObject(tAnswer): tAnswer.%Get("outcome") _ "|" _ tAnswer.%IsDefined("id"), 1: ""), "200 |error|0", "a second statement after a query is answered as an error with no run")
    Do $$$AssertEquals(..Compiled("ProbePmml.Scratch") _ ..Compiled("ProbePmml.ScratchView"), "00", "no table or view was made")
    Do $$$AssertEquals(..Counter() _ "|" _ ..Footprint(), tBefore, "nothing was allocated, started or changed")
}

/// <p>Reserve a run for the current user and spawn the fixture <var>pClass</var>'s supervisor for it, and wait for the child to begin its work: <var>pKey</var> is the run's id, <var>pSup</var> the process the
/// store records, which holds the run, and <var>pChild</var> the idle child's process id. 1 when the child is running and the run is held.</p>
ClassMethod StartIdle(pClass As %String, Output pKey As %String, Output pSup As %String, Output pChild As %String) As %Boolean
{
    Kill ^IRIS.Temp.OcuPilotPmmlIdle
    Set pSup = ""
    Set pChild = ""
    Set tSC = $ClassMethod(..#STORE, "GuardedReserve", $Username, ..#NAMESPACE, 1000, ..#LIMITS, .pKey, .tBusy, .tFull, .tSweep, "pmml")
    If $$$ISERR(tSC) || ($Get(pKey) = "") Quit 0
    If '$ClassMethod(pClass, "Spawn", pKey, $Username, ..#NAMESPACE, $ListBuild(..#DEFINITION _ "||Colors", "verification", "", ""), .tSpawned) Quit 0
    Set tDeadline = $ZHorolog + 30
    While ('$Data(^IRIS.Temp.OcuPilotPmmlIdle("entered"))) && ($ZHorolog < tDeadline) {
        Hang 0.1
    }
    Set pSup = $ClassMethod(..#WATCH, "JobOf", pKey)
    Set pChild = $Get(^IRIS.Temp.OcuPilotPmmlIdle("child"))
    Quit $Data(^IRIS.Temp.OcuPilotPmmlIdle("entered")) && (pSup '= "") && (pChild '= "") && (pSup '= pChild)
}

/// <p>The status of run <var>pKey</var> as the current user reads it through the fixture <var>pClass</var>, <code>"absent"</code> for none.</p>
ClassMethod ViewStatus(pClass As %String, pKey As %String) As %String
{
    Do $ClassMethod(pClass, "View", pKey, $Username, .tFound, .tView)
    Quit $Select($Get(tFound): tView.%Get("status"), 1: "absent")
}

/// <p>Wait up to <var>pSeconds</var> for run <var>pKey</var>, read through the fixture <var>pClass</var>, to leave <code>running</code>; its view, or <code>""</code> for a run that is gone.</p>
ClassMethod AwaitEnd(pClass As %String, pKey As %String, pSeconds As %Numeric) As %DynamicObject
{
    Set tDeadline = $ZHorolog + pSeconds
    For {
        Do $ClassMethod(pClass, "View", pKey, $Username, .tFound, .tView)
        If '$Get(tFound) Quit
        If (tView.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.05
    }
    Quit $Select($Get(tFound): tView, 1: "")
}

/// <p>AC2: a cancel of a run whose child is in no SQL statement, which the idle fixture's is, answers <code>canceled</code> within two seconds, the run's child and supervisor are gone, and the run holds no
/// record, no lock and no event resource.</p>
/// <p>Mutation (Rule 19): skip the <code>Signal</code> in <method>OcuPilot.Area.Analytics.PmmlTest.CancelJob</method> -- this goes red on the status, the live processes and the time; skip the supervisor's
/// <code>Terminate</code> in <method>OcuPilot.Area.Analytics.PmmlTest.Reap</method> -- the live child and the wait for it go red; skip <code>Finish</code> there -- the stored state reads running.</p>
Method TestACancelEndsARunWhoseJobIsInNoStatement()
{
    Do $$$AssertTrue(..StartIdle(..#IDLE, .tKey, .tSup, .tChild), "the idle child began its work and the supervisor holds the run: " _ $Get(tKey) _ " supervisor " _ $Get(tSup) _ " child " _ $Get(tChild))
    Set tStart = $ZHorolog
    Set tSC = $ClassMethod(..#IDLE, "Cancel", tKey, $Username, .tFound)
    Set tSeconds = $ZHorolog - tStart
    Do $$$AssertTrue($$$ISOK(tSC) && tFound, "the cancel is accepted")
    Set tStored = ##class(%SQL.Statement).%ExecDirect(, "SELECT State FROM OcuPilot_Kernel_State.SqlRun WHERE RunKey = ?", tKey)
    Do $$$AssertEquals($Select(tStored.%Next(): tStored.%GetData(1), 1: ""), "canceled", "the run's final state is written before the cancel returns")
    Do $$$AssertEquals(..ViewStatus(..#IDLE, tKey), "canceled", "the run reads canceled")
    Do $$$AssertTrue(tSeconds < 2, "within two seconds: " _ tSeconds)
    Do $$$AssertEquals($ClassMethod(..#WATCH, "Residue", tKey, "", tChild, tSup), $Parameter(..#WATCH, "CLEAN"), "and nothing is left: no child, no supervisor, no record, no lock, no event")
    Kill ^IRIS.Temp.OcuPilotPmmlIdle
}

/// <p>AC3: a cancel ends only the run's own child. The run's record is forged to name another process, a bystander of the same account, and the test id of rows another test seeded: the run's child is gone, the
/// bystander lives, the seeded rows are whole, and the record is gone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Analytics.PmmlTest.Reap</method> end the record's process in place of <var>pChild</var>, and drop the record's test id whatever process it names --
/// this goes red on the bystander and on the seeded rows.</p>
Method TestACancelEndsOnlyTheRunsOwnChild()
{
    Job ##class(OcuPilot.Test.PmmlTestIdle).Bystander()::5
    Set tBystander = $Test * $ZChild
    Set tSeeded = $ClassMethod(..#PMML, "Seed")
    Do $$$AssertTrue(tBystander && $ClassMethod(..#WATCH, "Alive", tBystander) && (tSeeded '= "") && ($ClassMethod(..#PMML, "RowsOf", tSeeded) = 4), "a bystander runs and another test's four rows are seeded: " _ tBystander _ " " _ tSeeded)
    Do $$$AssertTrue(..StartIdle(..#IDLE, .tKey, .tSup, .tChild), "the run's idle child began its work: " _ $Get(tKey) _ " child " _ $Get(tChild))
    Set ^IRIS.Temp.OcuPilotPmmlRun(tKey) = $ListBuild(tBystander, tSeeded)
    Set tSC = $ClassMethod(..#IDLE, "Cancel", tKey, $Username, .tFound)
    Do $$$AssertTrue($$$ISOK(tSC) && tFound, "the cancel is accepted")
    Do $$$AssertEquals(..ViewStatus(..#IDLE, tKey), "canceled", "the run reads canceled")
    Do $$$AssertEquals($ClassMethod(..#WATCH, "Residue", tKey, "", tChild, tSup), $Parameter(..#WATCH, "CLEAN"), "the run's own child and supervisor are gone and the record is removed")
    Do $$$AssertTrue($ClassMethod(..#WATCH, "Alive", tBystander), "the process the record names lives")
    Do $$$AssertEquals($ClassMethod(..#PMML, "RowsOf", tSeeded), 4, "and the rows of the test id it names are whole")
    Set ^IRIS.Temp.OcuPilotPmmlIdle("bystander") = 1
    Do $$$AssertTrue($ClassMethod(..#WATCH, "WaitGone", tBystander, 10), "the bystander is released and gone")
    Kill ^IRIS.Temp.OcuPilotPmmlIdle, ^IRIS.Temp.OcuPilotPmmlRun(tKey)
    Do $ClassMethod(..#PMML, "DropRows")
}

/// <p>A cancel of a run whose row reads running while no process holds its lock, a supervisor that ended before the cancel, ends no process: the store answers no live job, so the process id the row names, here a
/// bystander's, is not sent anything, the run reads <code>canceled</code>, and the orphaned child ends on its own release.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Analytics.PmmlTest.CancelJob</method> end the process the stored row names and treat it as live -- this goes red on the bystander.</p>
Method TestACancelOfAStaleRowEndsNoProcess()
{
    Do $$$AssertTrue(..StartIdle(..#IDLE, .tKey, .tSup, .tChild), "the idle child began its work: " _ $Get(tKey) _ " supervisor " _ $Get(tSup))
    Do $$$AssertEquals($SYSTEM.Process.Terminate(tSup), 1, "the supervisor is ended from outside, leaving its row running")
    Do $$$AssertTrue($ClassMethod(..#WATCH, "WaitGone", tSup, 10), "and it is gone")
    Job ##class(OcuPilot.Test.PmmlTestIdle).Bystander()::5
    Set tBystander = $Test * $ZChild
    Do $$$AssertTrue(tBystander && $ClassMethod(..#WATCH, "Alive", tBystander), "a bystander runs")
    Set tSQLCode = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.SqlRun SET JobId = ? WHERE %EXACT(RunKey) = ?", tBystander, tKey).%SQLCODE
    Do $$$AssertEquals(tSQLCode, 0, "the stale row names the bystander")
    Set tSC = $ClassMethod(..#IDLE, "Cancel", tKey, $Username, .tFound)
    Do $$$AssertTrue($$$ISOK(tSC) && tFound, "the cancel is accepted")
    Hang 0.5
    Do $$$AssertTrue($ClassMethod(..#WATCH, "Alive", tBystander), "the process the stale row names lives")
    Do $$$AssertEquals(..ViewStatus(..#IDLE, tKey), "canceled", "and the run reads canceled")
    Set ^IRIS.Temp.OcuPilotPmmlIdle("bystander") = 1
    Set ^IRIS.Temp.OcuPilotPmmlIdle("release") = 1
    Do $$$AssertTrue($ClassMethod(..#WATCH, "WaitGone", tBystander, 10) && $ClassMethod(..#WATCH, "WaitGone", tChild, 10), "the bystander and the orphaned child are released and gone")
    Do $System.Event.Delete(##class(OcuPilot.Area.Analytics.PmmlTest).EventName(tKey))
    Kill ^IRIS.Temp.OcuPilotPmmlIdle
}

/// <p>A wake without the owner's stop flag is ignored: a signal on the run's event, from a process that is not its owner's cancel, leaves the child and the supervisor running and the run reading
/// <code>running</code>; the owner's cancel then ends it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Analytics.PmmlTest.Await</method> end the wait on any wake without reading the stop flag -- this goes red on the run that no longer runs.</p>
Method TestAWakeWithoutTheStopFlagIsIgnored()
{
    Do $$$AssertTrue(..StartIdle(..#IDLE, .tKey, .tSup, .tChild), "the idle child began its work: " _ $Get(tKey))
    Do $System.Event.Signal(##class(OcuPilot.Area.Analytics.PmmlTest).EventName(tKey))
    Hang 1.2
    Do $$$AssertEquals(..ViewStatus(..#IDLE, tKey) _ " " _ $ClassMethod(..#WATCH, "Alive", tSup) _ " " _ $ClassMethod(..#WATCH, "Alive", tChild), "running 1 1", "the run still runs, with its supervisor and its child")
    Set tSC = $ClassMethod(..#IDLE, "Cancel", tKey, $Username, .tFound)
    Do $$$AssertEquals(..ViewStatus(..#IDLE, tKey), "canceled", "and the owner's cancel ends it")
    Do $$$AssertEquals($ClassMethod(..#WATCH, "Residue", tKey, "", tChild, tSup), $Parameter(..#WATCH, "CLEAN"), "leaving nothing")
    Kill ^IRIS.Temp.OcuPilotPmmlIdle
}

/// <p>A deleted event resource is created again, and the run still cancels: the supervisor re-creates the resource its wait found gone, within a second, and the owner's cancel then lands.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Analytics.PmmlTest.Await</method> not create a deleted event again -- this goes red on the event that stays deleted and the run that no longer reads running.</p>
Method TestADeletedEventIsCreatedAgainAndTheRunStillCancels()
{
    Do $$$AssertTrue(..StartIdle(..#IDLE, .tKey, .tSup, .tChild), "the idle child began its work: " _ $Get(tKey))
    Do $$$AssertEquals($System.Event.Delete(##class(OcuPilot.Area.Analytics.PmmlTest).EventName(tKey)), 1, "the run's event is deleted")
    Set tDeadline = $ZHorolog + 5
    While ('$ClassMethod(..#WATCH, "EventDefined", tKey)) && ($ZHorolog < tDeadline) {
        Hang 0.05
    }
    Do $$$AssertEquals($ClassMethod(..#WATCH, "EventDefined", tKey) _ " " _ ..ViewStatus(..#IDLE, tKey) _ " " _ $ClassMethod(..#WATCH, "Alive", tSup) _ " " _ $ClassMethod(..#WATCH, "Alive", tChild), "1 running 1 1", "the supervisor created it again and the run still runs")
    Set tStart = $ZHorolog
    Set tSC = $ClassMethod(..#IDLE, "Cancel", tKey, $Username, .tFound)
    Do $$$AssertTrue(($ZHorolog - tStart) < 2, "the cancel lands within two seconds: " _ ($ZHorolog - tStart))
    Do $$$AssertEquals(..ViewStatus(..#IDLE, tKey), "canceled", "the run reads canceled")
    Do $$$AssertEquals($ClassMethod(..#WATCH, "Residue", tKey, "", tChild, tSup), $Parameter(..#WATCH, "CLEAN"), "leaving nothing")
    Kill ^IRIS.Temp.OcuPilotPmmlIdle
}

/// <p>A child that ignores its bound and is never released is ended by its supervisor at the bound plus the grace, three seconds for the hung fixture: the run ends <code>ended</code> with
/// <code>{outcome: stopped, seconds: 2}</code>, and nothing is left.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Analytics.PmmlTest.Await</method> never end on its deadline -- this goes red on the run still reading running after fifteen seconds.</p>
Method TestAHungChildIsEndedAtTheBoundPlusGrace()
{
    Do $$$AssertTrue(..StartIdle(..#HUNG, .tKey, .tSup, .tChild), "the hung child began its work: " _ $Get(tKey))
    Set tStart = $ZHorolog
    Set tView = ..AwaitEnd(..#HUNG, tKey, 15)
    Set tSeconds = $ZHorolog - tStart
    Do $$$AssertEquals($Select($IsObject(tView) && $IsObject(tView.%Get("result")): tView.%Get("status") _ " " _ tView.result.outcome _ " " _ tView.result.seconds, 1: "absent"), "ended stopped 2", "the run ends stopped at the bound: " _ $Select($IsObject(tView): tView.%ToJSON(), 1: ""))
    Do $$$AssertTrue((tSeconds > 2) && (tSeconds < 8), "at the bound plus the grace, not before and not long after: " _ tSeconds)
    Do $$$AssertEquals($ClassMethod(..#WATCH, "Residue", tKey, "", tChild, tSup), $Parameter(..#WATCH, "CLEAN"), "and nothing is left")
    Kill ^IRIS.Temp.OcuPilotPmmlIdle
}

/// <p>A run that ends on its own, here an idle child that is released, ends <code>ended</code>, and its supervisor reaps and exits: no process, record, lock or event resource is left.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Analytics.PmmlTest.Work</method> skip deleting the event -- this goes red on the event left.</p>
Method TestARunThatEndsOnItsOwnLeavesNothing()
{
    Do $$$AssertTrue(..StartIdle(..#IDLE, .tKey, .tSup, .tChild), "the idle child began its work: " _ $Get(tKey))
    Set ^IRIS.Temp.OcuPilotPmmlIdle("release") = 1
    Set tView = ..AwaitEnd(..#IDLE, tKey, 10)
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status"), 1: "absent"), "ended", "the run ends")
    Do $$$AssertEquals($ClassMethod(..#WATCH, "Residue", tKey, "", tChild, tSup), $Parameter(..#WATCH, "CLEAN"), "and nothing is left")
    Kill ^IRIS.Temp.OcuPilotPmmlIdle
}

/// <p>A child that is ended from outside, as a kill of its process would, is reaped by its supervisor: the run reads <code>failed</code>, the rows of the test id the run's record names are dropped, and no
/// process, record, lock or event resource is left.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Analytics.PmmlTest.Reap</method> skip the drop of the record's rows -- this goes red on the seeded rows left; make
/// <method>OcuPilot.Area.Analytics.PmmlTest.Work</method> end the run <code>ended</code> for a child that ended on its own -- this goes red on the status.</p>
Method TestAChildEndedFromOutsideIsReapedAndTheRunReadsFailed()
{
    Set tSeeded = $ClassMethod(..#PMML, "Seed")
    Do $$$AssertTrue((tSeeded '= "") && ($ClassMethod(..#PMML, "RowsOf", tSeeded) = 4), "four rows are seeded under a test id: " _ tSeeded)
    Do $$$AssertTrue(..StartIdle(..#IDLE, .tKey, .tSup, .tChild), "the idle child began its work: " _ $Get(tKey) _ " child " _ $Get(tChild))
    Set ^IRIS.Temp.OcuPilotPmmlRun(tKey) = $ListBuild(tChild, tSeeded)
    Do $$$AssertEquals($SYSTEM.Process.Terminate(tChild), 1, "the child is ended from outside")
    Set tView = ..AwaitEnd(..#IDLE, tKey, 10)
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status"), 1: "absent"), "failed", "the run reads failed")
    Do $$$AssertEquals($ClassMethod(..#WATCH, "Residue", tKey, tSeeded, tChild, tSup), $Parameter(..#WATCH, "CLEAN"), "the supervisor dropped the record's rows and removed the record, and nothing is left")
    Kill ^IRIS.Temp.OcuPilotPmmlIdle
    Do $ClassMethod(..#PMML, "DropRows")
}

/// <p>A class or model that is not there is 404 <code>ANALYTICS.PMML.ABSENT</code>; a data source the definition does not declare, and verification records a model does not carry, are 400
/// <code>ANALYTICS.PMML.INPUT</code>; and a cube data source whose cube the caller may not read is 409 <code>ANALYTICS.PMML.CUBE</code>, each before the vendor runs: no test id is allocated.</p>
/// <p>Mutation (Rule 19): drop the <code>%CheckPrivilege</code> test from <method>OcuPilot.Port.AnalyticsPort.PmmlLookup</method> -- the cube leg goes red.</p>
Method TestAnAbsentOrUndeclaredSourceIsRefusedBeforeTheVendorRuns()
{
    Set tBefore = ..Counter() _ "|" _ ..Footprint()
    Set tBody = {"model": "OcuPilotProbe.Pmml.Gone||Colors", "source": "verification"}
    Do ..Send("POST", ..#START, ##class(OcuPilot.Test.Http).GetTestUsername(), .tStatus, .tAnswer, tBody)
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "404 ANALYTICS.PMML.ABSENT", "a class that is not there")
    Do $$$AssertEquals(..Start("Nope", "verification", "", "", .tAnswer, ##class(OcuPilot.Test.Http).GetTestUsername()), "404 ANALYTICS.PMML.ABSENT", "a model the class does not hold")
    Do $$$AssertEquals(..Start("Colors", "dataset", "NoSuchSource", "", .tAnswer), "400 ANALYTICS.PMML.INPUT", "a data source the definition does not declare")
    Do $$$AssertEquals(..Start("Plain", "verification", "", "", .tAnswer), "400 ANALYTICS.PMML.INPUT", "verification records the model does not carry")
    Do $$$AssertEquals(..Start("Colors", "dataset", ##class(OcuPilot.Test.PmmlProbe).#CUBESOURCE, "", .tAnswer, ..#READER), "409 ANALYTICS.PMML.CUBE", "a cube the caller may not read")
    Do $$$AssertEquals(..Counter() _ "|" _ ..Footprint(), tBefore, "no refusal allocated a test id or started a run")
}

/// <p>A body with a key other than the four, a value of the wrong shape, a data source with a source that takes none, a custom source with none, or a model of no usable shape is 400
/// <code>ANALYTICS.PMML.INPUT</code> before anything is looked up; a caller with only the portal's pair is 403 naming <code>%Development:USE</code>; and a namespace without analytics is 409
/// <code>ANALYTICS.NAMESPACE</code>, the poll and cancel routes' gate the same.</p>
/// <p>Mutation (Rule 19): drop the <code>%Development:USE</code> pair from <method>OcuPilot.Screen.Descriptor.AnalyticsPmmlModelTest</method> and <parameter>OcuPilot.Port.AnalyticsPort.PMMLPAIRS</parameter> -- the 403 leg goes red.</p>
Method TestAnyOtherShapeAndAnUnpairedCallerAreRefused()
{
    Set tBefore = ..Counter() _ "|" _ ..Footprint()
    Set tModel = ..#DEFINITION _ "||Colors"
    ; Each body is held as JSON text: an object reference does not survive a $ListBuild.
    For tCase = $ListBuild("a stray key", {"model": (tModel), "source": "verification", "extra": 1}.%ToJSON()), $ListBuild("a source that is not one of the three", {"model": (tModel), "source": "everything"}.%ToJSON()), $ListBuild("a model of no shape", {"model": "Colors", "source": "verification"}.%ToJSON()), $ListBuild("a dataset with no data source", {"model": (tModel), "source": "dataset"}.%ToJSON()), $ListBuild("a dataset with SQL", {"model": (tModel), "source": "dataset", "dataSource": "Rows", "sql": "SELECT 1"}.%ToJSON()), $ListBuild("verification with a data source", {"model": (tModel), "source": "verification", "dataSource": "Rows"}.%ToJSON()), $ListBuild("a custom source with no SQL", {"model": (tModel), "source": "custom"}.%ToJSON()), $ListBuild("a custom source with a blank SQL", {"model": (tModel), "source": "custom", "sql": "   "}.%ToJSON()), $ListBuild("a custom source with a data source", {"model": (tModel), "source": "custom", "sql": "SELECT 1", "dataSource": "Rows"}.%ToJSON()), $ListBuild("a source that is not text", {"model": (tModel), "source": 3}.%ToJSON()) {
        Do ..Send("POST", ..#START, ##class(OcuPilot.Test.Http).GetTestUsername(), .tStatus, .tAnswer, $List(tCase, 2))
        Do $$$AssertEquals(..Code(tStatus, tAnswer), "400 ANALYTICS.PMML.INPUT", $List(tCase, 1) _ " is refused: " _ ..Code(tStatus, tAnswer))
    }
    Do ..Send("POST", ..#START, ..#NODEV, .tStatus, .tAnswer, {"model": (tModel), "source": "verification"})
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "403 AUTH.NOPRIVILEGE", "a caller without the developer pair is refused")
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("failedPair"), 1: ""), "%Development:USE", "and the refusal names it")
    Do ..Send("POST", ..#START, ##class(OcuPilot.Test.Http).GetTestUsername(), .tStatus, .tAnswer, {"model": (tModel), "source": "verification"}, "HSCUSTOM")
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "409 ANALYTICS.NAMESPACE", "a namespace without analytics is refused")
    Do ..Send("GET", $Replace(..#POLL, ":id", "0123456789abcdef0123456789abcdef"), ..#NODEV, .tStatus, .tAnswer)
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "403 AUTH.NOPRIVILEGE", "the poll route takes the same gate")
    Do $$$AssertEquals(..Counter() _ "|" _ ..Footprint(), tBefore, "no refusal allocated a test id or started a run")
}

/// <p>A run past its bound ends <code>stopped</code> and leaves no result row: the fixture's two-second bound, over a cross join that takes longer, answers <code>{outcome: stopped, seconds: 2}</code>, and the rows
/// the run had written, and the test id's, are gone.</p>
/// <p>Mutation (Rule 19): skip the <method>OcuPilot.Port.AnalyticsPort.PmmlDrop</method> call in <method>OcuPilot.Port.AnalyticsPort.PmmlRun</method> -- this goes red on the rows left. Drop the
/// elapsed-time clause of the bound test there -- this goes red on the outcome, which reads <code>ran</code>.</p>
Method TestARunPastItsBoundIsStoppedAndLeavesNoRow()
{
    Set tBefore = ..Counter()
    Set tSC = $ClassMethod(..#STORE, "GuardedReserve", $Username, ..#NAMESPACE, 1000, ..#LIMITS, .tKey, .tBusy, .tFull, .tSweep, "pmml")
    Do $$$AssertStatusOK(tSC, "a run is reserved")
    Do $$$AssertTrue($ClassMethod(..#QUICK, "Spawn", tKey, $Username, ..#NAMESPACE, $ListBuild(..#DEFINITION _ "||Colors", "custom", "", ..#FIVEWAY), .tChild), "and its job is spawned through the fixture")
    Set tView = ..AwaitEnd(..#QUICK, tKey, 90)
    Do $$$AssertEquals($Select($IsObject(tView) && $IsObject(tView.%Get("result")): tView.%Get("status") _ " " _ tView.result.outcome _ " " _ tView.result.seconds, 1: "absent"), "ended stopped 2", "the run ends stopped at the fixture's two seconds: " _ $Select($IsObject(tView): tView.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Counter() - tBefore _ "|" _ $ClassMethod(..#PMML, "RowsOf", ..Counter()) _ "|" _ $ClassMethod(..#PMML, "Rows"), "1|0|0", "the run allocated its id, and the rows it wrote are gone")
}

/// <p>AC1 (the target): a least-privileged owner's cancel of a run that has written a result row, over a statement the child scans for a long time and over a fast cross join, served by a web process other than the
/// one that served the start, answers <code>canceled</code> within two seconds, and the run's child and supervisor are gone, with nothing left: no row for the test id, no run record, no event resource, no held run
/// lock. The start's web process is held busy while the cancel is sent where the web server lets a request reach it (<class>OcuPilot.Test.PmmlRunWatch</class>); where it does not, the server's
/// own pick serves the cancel. Either way the test asserts that the two requests were served by two processes.</p>
/// <p>Mutation (Rule 19): skip the supervisor's <code>Terminate</code> in <method>OcuPilot.Area.Analytics.PmmlTest.Reap</method> -- both legs go red on the status, the live child and the time. Skip
/// <method>OcuPilot.Port.AnalyticsPort.PmmlRun</method>'s hand-off of the test id to the stop class, or <method>OcuPilot.Area.Analytics.PmmlTest.Reap</method>'s drop of the record's rows -- both legs go red on the rows left.</p>
Method TestACancelFromAnotherWebProcessEndsARunOverEitherStatement()
{
    Do ..CancelAcross("a slow scan", ..#SLOWSCAN)
    Do ..CancelAcross("a fast cross join", ..#SIXWAY)
}

/// <p>One leg of AC1: <var>pName</var>'s run over <var>pSQL</var> is started through the hold application as <parameter>READER</parameter>, and cancels once it has written a row, from a web process other than
/// the one that served the start.</p>
Method CancelAcross(pName As %String, pSQL As %String)
{
    Set tBefore = ..Counter()
    Set tBody = {"model": (..#DEFINITION _ "||Colors"), "source": "custom", "sql": (pSQL)}
    Do ..Send("POST", ..#HOLDAPP _ "/analytics/pmml/background", ..#READER, .tStatus, .tAnswer, tBody, , .tStartPid)
    Do $$$AssertEquals(tStatus, 202, pName _ ": the start is accepted by web process " _ tStartPid)
    If tStatus '= 202 Quit
    Set tKey = tAnswer.%Get("id")
    Do $$$AssertTrue($ClassMethod(..#WATCH, "AwaitRows", tBefore + 1), pName _ ": the child has written a result row, which the cancel must drop")
    Set tSup = $ClassMethod(..#WATCH, "JobOf", tKey)
    Set tChild = $ClassMethod(..#WATCH, "ChildOf", tKey)
    Do $$$AssertTrue($ClassMethod(..#WATCH, "Alive", tSup) && $ClassMethod(..#WATCH, "Alive", tChild) && (tSup '= tChild), pName _ ": a supervisor and a child are alive: " _ tSup _ " " _ tChild)
    Set tHeld = $ClassMethod(..#WATCH, "HoldProcess", tStartPid, 10, ..#HOLDAPP _ "/hold", ..#READER, ..PreparedPassword)
    If 'tHeld {
        Do $ClassMethod(..#WATCH, "ReleaseProcess", tStartPid, 5)
        Hang 0.2
    }
    Set tAsked = $ZHorolog
    Do ..Send("POST", ..#HOLDAPP _ "/analytics/pmml/background/" _ tKey _ "/cancel", ..#READER, .tCancelStatus, .tCancelAnswer, , , .tCancelPid)
    Set tSeconds = $ZHorolog - tAsked
    Do $$$AssertTrue((tCancelPid '= "") && (tCancelPid '= tStartPid), pName _ ": another web process served the cancel: " _ tStartPid _ " then " _ tCancelPid)
    Do $$$AssertEquals(tCancelStatus _ " " _ $Select($IsObject(tCancelAnswer): tCancelAnswer.%Get("status") _ " " _ tCancelAnswer.%Get("cancelRequested"), 1: ""), "200 canceled 1", pName _ ": the cancel's own answer reads canceled")
    Do $$$AssertTrue(tSeconds < 2, pName _ ": within two seconds: " _ tSeconds)
    Do $$$AssertEquals($ClassMethod(..#WATCH, "Residue", tKey, tBefore + 1, tChild, tSup), $Parameter(..#WATCH, "CLEAN"), pName _ ": no child, no supervisor, no row for the test id, no record, no held run lock, no event")
    Do $ClassMethod(..#WATCH, "ReleaseProcess", tStartPid, 5)
    Do ..Send("GET", $Replace(..#POLL, ":id", tKey), ..#READER, .tStatus, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: ""), "canceled", pName _ ": and a poll reads it the same")
}

/// <p>Another user's poll and cancel of a run answer the 404 an unknown id answers, <code>ANALYTICS.PMML.NOTFOUND</code>, and the owner's own second start while the run is live is 409
/// <code>ANALYTICS.PMML.BUSY</code> naming the live run; neither changes the run, and another user's cancel leaves the run's child and supervisor alive and its record and event in place. The owner's own cancel then ends it.</p>
/// <p>Mutation (Rule 19): drop the owner test from <method>OcuPilot.Kernel.State.SqlRun.IdForOwner</method> -- the other user's legs go red.</p>
Method TestAnotherUsersPollIsNotFoundAndASecondStartIsBusy()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tBefore = ..Counter()
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, {"model": (..#DEFINITION _ "||Colors"), "source": "custom", "sql": (..#SLOWSCAN)})
    Do $$$AssertEquals(tStatus, 202, "the start is accepted")
    If tStatus '= 202 Quit
    Set tKey = tAnswer.%Get("id")
    Do $$$AssertTrue($ClassMethod(..#WATCH, "AwaitRows", tBefore + 1), "the child has written a result row")
    Set tSup = $ClassMethod(..#WATCH, "JobOf", tKey)
    Set tChild = $ClassMethod(..#WATCH, "ChildOf", tKey)
    Do ..Send("GET", $Replace(..#POLL, ":id", tKey), ..#READER, .tStatus, .tAnswer)
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "404 ANALYTICS.PMML.NOTFOUND", "another user's poll finds nothing")
    Do ..Send("POST", $Replace(..#CANCEL, ":id", tKey), ..#READER, .tStatus, .tAnswer)
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "404 ANALYTICS.PMML.NOTFOUND", "and so does another user's cancel")
    Do $$$AssertEquals($ClassMethod(..#WATCH, "Alive", tSup) _ $ClassMethod(..#WATCH, "Alive", tChild) _ "|" _ $ClassMethod(..#PMML, "Records") _ "|" _ $ClassMethod(..#WATCH, "EventDefined", tKey), "11|1|1", "which ends nothing: the supervisor and the child are alive, and the record and the event are in place")
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, {"model": (..#DEFINITION _ "||Colors"), "source": "verification"})
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "409 ANALYTICS.PMML.BUSY", "the owner's second start is refused while the first is live")
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("runId"), 1: ""), tKey, "and names the live run")
    Do ..Send("GET", $Replace(..#POLL, ":id", tKey), tUser, .tStatus, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("status") _ " " _ tAnswer.%Get("cancelRequested"), 1: ""), "running 0", "the run itself is unchanged by either")
    Do ..Send("POST", $Replace(..#CANCEL, ":id", tKey), tUser, .tStatus, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: ""), "canceled", "and the owner's cancel ends it")
    Do $$$AssertEquals($ClassMethod(..#WATCH, "Residue", tKey, tBefore + 1, tChild, tSup), $Parameter(..#WATCH, "CLEAN"), "leaving nothing")
}

}
