/// <p>Pins Story 24.14 Batch 2's PMML test at its edges (AD-7, AD-8, AD-41, AD-42, AD-65), against <code>USER</code> and the definition of <class>OcuPilot.Test.PmmlProbe</class>: a source that is not an SQL query,
/// a custom statement or a declared data source, is refused with SQL query's own classification and self-protection check, and an SQL the instance cannot prepare is answered at once, before anything is
/// reserved or spawned; a class or model that is absent, a data source the definition does not declare, verification records a model does not carry and a cube a principal may not read are refused by their codes
/// before the vendor runs; a body of any other shape, a caller without the developer pair and a namespace without analytics are refused; a run past its bound ends <code>stopped</code> and one its owner cancels ends
/// <code>canceled</code>, each leaving no result row; and another user's poll and cancel are 404 and a second start of the owner's is 409 busy.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and removes IRIS users and roles and, through the probes, turns analytics on
/// for <code>USER</code> and writes cubes and classes there. Every run a test starts has ended, and every run row and result row it made is removed, before the test returns.</p>
Class OcuPilot.Test.AnalyticsPmmlRunEdge Extends %UnitTest.TestCase [ DependsOn = (OcuPilot.Test.AnalyticsProbe, OcuPilot.Test.PmmlProbe) ]
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PMML = "OcuPilot.Test.PmmlProbe";

Parameter STORE = "OcuPilot.Kernel.State.SqlRun";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter QUICK = "OcuPilot.Test.PmmlTestQuick";

Parameter IDLE = "OcuPilot.Test.PmmlTestIdle";

Parameter START = "/api/ocupilot/analytics/pmml/background";

Parameter POLL = "/api/ocupilot/analytics/pmml/background/:id";

Parameter CANCEL = "/api/ocupilot/analytics/pmml/background/:id/cancel";

Parameter NAMESPACE = "USER";

Parameter DEFINITION = {##class(OcuPilot.Test.PmmlProbe).#DEFINITIONCLASS};

/// <p>A principal that reaches the API and holds <code>%DeepSee_Portal</code> but not <code>%Development</code>, so only the developer pair refuses it; and one that holds both pairs and reads <code>USER</code> but
/// not <code>%DeepSee_Admin</code>, the resource of the cube the probe's cube data source names.</p>
Parameter PRINCIPALS = "OcuP2414PmmlNoDev:%Ens_Portal:U,%DeepSee_Portal:U,%DB_USER:R;OcuP2414PmmlReader:%Ens_Portal:U,%DeepSee_Portal:U,%Development:U,%DB_USER:R";

Parameter NODEV = "OcuP2414PmmlNoDev";

Parameter READER = "OcuP2414PmmlReader";

/// <p>A cross join of the source rows with itself five times (248,832 rows) and six times (2,985,984): slow enough to stop at a short bound, and to cancel.</p>
Parameter FIVEWAY = "SELECT a.ID, a.X, a.Color, a.Y FROM ProbePmml.Source a, ProbePmml.Source b, ProbePmml.Source c, ProbePmml.Source d, ProbePmml.Source e";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPmmlRunEdge creates IRIS users and roles, turns analytics on in USER and compiles classes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set ..PreparedPassword = "OcuP2414Pmml" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PMML, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $Username)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PMML, "Create")
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals(..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.AnalyticsPmmlRunEdge")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
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

/// <p>Send <var>pMethod</var> <var>pPath</var> as <var>pUser</var> in namespace <var>pNamespace</var>, with <var>pBody</var> when it is given; the status, the parsed answer.</p>
Method Send(pMethod As %String, pPath As %String, pUser As %String, Output pStatus As %Integer, Output pAnswer, pBody = "", pNamespace As %String = {..#NAMESPACE})
{
    Set tText = $Select($IsObject(pBody): pBody.%ToJSON(), 1: pBody)
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ pNamespace, pUser, ..PasswordOf(pUser), .pStatus, .tRaw, .tHeaders, tText, "application/json")
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

/// <p>A cancel of a run whose job never enters a statement is bounded by the cancel's budget: the fixture's run is idle, so the interrupt is refused every time it is sent, and the cancel request stops
/// sending it once the fixture's two seconds have passed, not after its sixty sends (which take over six). The run is still live when the request returns, and ends <code>canceled</code> once its job
/// is released.</p>
/// <p>Mutation (Rule 19): drop the budget clause from the loop of <method>OcuPilot.Area.Analytics.PmmlTest.CancelJob</method> -- this goes red on the seconds the cancel took.</p>
Method TestACancelThatMeetsNoStatementIsBoundedByItsBudget()
{
    Kill ^IRIS.Temp.OcuPilotPmmlIdle
    Set tSC = $ClassMethod(..#STORE, "GuardedReserve", $Username, ..#NAMESPACE, 1000, ..#LIMITS, .tKey, .tBusy, .tFull, .tSweep, "pmml")
    Do $$$AssertTrue($$$ISOK(tSC) && ($Get(tKey) '= ""), "a run is reserved: " _ $Get(tKey) _ " busy " _ $Get(tBusy) _ " full " _ $Get(tFull))
    Do $$$AssertTrue($ClassMethod(..#IDLE, "Spawn", tKey, $Username, ..#NAMESPACE, $ListBuild(..#DEFINITION _ "||Colors", "verification", "", ""), .tChild), "and its idle job is spawned")
    Set tDeadline = $ZHorolog + 30
    While ('$Data(^IRIS.Temp.OcuPilotPmmlIdle("entered"))) && ($ZHorolog < tDeadline) {
        Hang 0.1
    }
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT State FROM OcuPilot_Kernel_State.SqlRun WHERE RunKey = ?", tKey)
    Set tState = $Select(tResult.%Next(): tResult.%GetData(1), 1: "")
    Do $$$AssertEquals($Data(^IRIS.Temp.OcuPilotPmmlIdle("entered")) _ " " _ tState, "1 running", "the job began its work and holds its run")
    Set tStart = $ZHorolog
    Set tSC = $ClassMethod(..#IDLE, "Cancel", tKey, $Username, .tFound)
    Set tSeconds = $ZHorolog - tStart
    Do $$$AssertTrue($$$ISOK(tSC) && tFound, "the cancel is accepted")
    Do $$$AssertTrue(tSeconds >= 1.9, "it kept sending for its budget of two seconds: " _ tSeconds)
    Do $$$AssertTrue(tSeconds < 4.5, "and stopped there, not after its sixty sends: " _ tSeconds)
    Do $ClassMethod(..#IDLE, "View", tKey, $Username, .tFound, .tView)
    Do $$$AssertEquals($Select($IsObject($Get(tView)): tView.%Get("status") _ " " _ tView.%Get("cancelRequested"), 1: ""), "running 1", "the run is still live, its cancel flag set")
    Set ^IRIS.Temp.OcuPilotPmmlIdle("release") = 1
    Set tDeadline = $ZHorolog + 30
    For {
        Do $ClassMethod(..#IDLE, "View", tKey, $Username, .tFound, .tView)
        If '$Get(tFound) || (tView.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.1
    }
    Do $$$AssertEquals($Select($IsObject($Get(tView)): tView.%Get("status"), 1: "absent"), "canceled", "and ends canceled once its job is released")
    Kill ^IRIS.Temp.OcuPilotPmmlIdle
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
    Set tDeadline = $ZHorolog + 90
    For {
        Do $ClassMethod(..#QUICK, "View", tKey, $Username, .tFound, .tView)
        If '$Get(tFound) || (tView.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Do $$$AssertEquals($Select($IsObject($Get(tView)): tView.%Get("status") _ " " _ tView.result.outcome _ " " _ tView.result.seconds, 1: "absent"), "ended stopped 2", "the run ends stopped at the fixture's two seconds: " _ $Select($IsObject($Get(tView)): tView.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Counter() - tBefore _ "|" _ $ClassMethod(..#PMML, "RowsOf", ..Counter()) _ "|" _ $ClassMethod(..#PMML, "Rows"), "1|0|0", "the run allocated its id, and the rows it wrote are gone")
}

/// <p>The owner's cancel ends a run <code>canceled</code> well before the cross join would end, and leaves no result row; the cancel's own answer is the run as it then reads.</p>
/// <p>Mutation (Rule 19): drop the <code>CancelQuery</code> from <method>OcuPilot.Area.Analytics.PmmlTest.CancelJob</method> -- the run is not interrupted and this goes red on the time it took.</p>
Method TestACancelEndsARunAndLeavesNoRow()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tBefore = ..Counter()
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, {"model": (..#DEFINITION _ "||Colors"), "source": "custom", "sql": (..#SIXWAY)})
    Do $$$AssertEquals(tStatus, 202, "the start is accepted")
    If tStatus '= 202 Quit
    Set tKey = tAnswer.%Get("id")
    Do ..AwaitRows(tBefore + 1)
    Set tAsked = $ZHorolog
    Do ..Send("POST", $Replace(..#CANCEL, ":id", tKey), tUser, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("cancelRequested"), 1: ""), "200 1", "the cancel is answered with the run, its flag set")
    ; An interrupt reaches the vendor's loop only while the job is inside the engine, so a cancel that met the job elsewhere is sent again.
    Set tDeadline = $ZHorolog + 60
    For tRetry = 1:1:6 {
        Do ..Send("GET", $Replace(..#POLL, ":id", tKey), tUser, .tStatus, .tAnswer)
        If '$IsObject(tAnswer) || (tAnswer.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 1
        If tRetry = 3 Do ..Send("POST", $Replace(..#CANCEL, ":id", tKey), tUser, .tStatus, .tAnswer)
    }
    For {
        Do ..Send("GET", $Replace(..#POLL, ":id", tKey), tUser, .tStatus, .tAnswer)
        If '$IsObject(tAnswer) || (tAnswer.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: ""), "canceled", "the run ends canceled")
    Do $$$AssertTrue(($ZHorolog - tAsked) < 60, "and not when the join would end: " _ ($ZHorolog - tAsked) _ " seconds")
    Do $$$AssertEquals(..Counter() - tBefore _ "|" _ $ClassMethod(..#PMML, "RowsOf", ..Counter()) _ "|" _ $ClassMethod(..#PMML, "Rows"), "1|0|0", "the run allocated its id, and the rows it wrote are gone")
}

/// <p>Wait up to 30 seconds for the run that holds test id <var>pId</var> to have written a result row, so that a cancel meets a run that is running.</p>
ClassMethod AwaitRows(pId As %Integer)
{
    Set tDeadline = $ZHorolog + 30
    While ($ClassMethod(..#PMML, "RowsOf", pId) = 0) && ($ZHorolog < tDeadline) {
        Hang 0.25
    }
}

/// <p>Another user's poll and cancel of a run answer the 404 an unknown id answers, <code>ANALYTICS.PMML.NOTFOUND</code>, and the owner's own second start while the run is live is 409
/// <code>ANALYTICS.PMML.BUSY</code> naming the live run; neither changes the run.</p>
/// <p>Mutation (Rule 19): drop the owner test from <method>OcuPilot.Kernel.State.SqlRun.IdForOwner</method> -- the other user's legs go red.</p>
Method TestAnotherUsersPollIsNotFoundAndASecondStartIsBusy()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tBefore = ..Counter()
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, {"model": (..#DEFINITION _ "||Colors"), "source": "custom", "sql": (..#SIXWAY)})
    Do $$$AssertEquals(tStatus, 202, "the start is accepted")
    If tStatus '= 202 Quit
    Set tKey = tAnswer.%Get("id")
    Do ..Send("GET", $Replace(..#POLL, ":id", tKey), ..#READER, .tStatus, .tAnswer)
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "404 ANALYTICS.PMML.NOTFOUND", "another user's poll finds nothing")
    Do ..Send("POST", $Replace(..#CANCEL, ":id", tKey), ..#READER, .tStatus, .tAnswer)
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "404 ANALYTICS.PMML.NOTFOUND", "and so does another user's cancel")
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, {"model": (..#DEFINITION _ "||Colors"), "source": "verification"})
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "409 ANALYTICS.PMML.BUSY", "the owner's second start is refused while the first is live")
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("runId"), 1: ""), tKey, "and names the live run")
    Do ..Send("GET", $Replace(..#POLL, ":id", tKey), tUser, .tStatus, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("status") _ " " _ tAnswer.%Get("cancelRequested"), 1: ""), "running 0", "the run itself is unchanged by either")
    Do ..Send("POST", $Replace(..#CANCEL, ":id", tKey), tUser, .tStatus, .tAnswer)
}

}
