/// <p>Pins Story 24.14 Batch 1's run of a saved pivot (AD-7, AD-41, AD-42, AD-60, AD-65), against <code>USER</code> and the viewer's fixtures from <class>OcuPilot.Test.AnalyticsProbe</class>: the three
/// routes <code>/analytics/pivot/background</code> (start, poll, cancel) answer a pivot's run as MDX query's run does, with the cells the vendor's own <code>%DeepSee.ResultSet</code> answers for the
/// pivot's <code>%GetBaseMDX()</code> and that statement as <code>statement</code>; the agent's <code>analytics.mdxquery.read</code> with <code>pivot</code> answers the same cells; a stored SQL restriction asks
/// first on the screen and is refused to the agent; a missing item, a name that is too long, an item that is not a pivot or whose cube is a KPI are refused by their codes before anything is composed or
/// spawned; a body of any other shape, and arguments naming a statement and a pivot together or neither, are refused; and the pairs and a namespace without analytics are refused before any vendor call.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and removes an IRIS user and role and, through
/// <class>OcuPilot.Test.AnalyticsProbe</class>, turns analytics on for <code>USER</code> and writes cubes and folder items there. Every run a test starts has ended, and every run row it made is removed, before
/// the test returns.</p>
Class OcuPilot.Test.AnalyticsPivotRun Extends %UnitTest.TestCase [ DependsOn = OcuPilot.Test.AnalyticsProbe ]
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter STORE = "OcuPilot.Kernel.State.SqlRun";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter TOOL = "OcuPilot.Screen.Tool.AnalyticsMdxRead";

Parameter VENDOR = "OcuPilot.Test.AnalyticsMdx";

Parameter READ = "OcuPilot.Test.AnalyticsMdxRead";

Parameter HIDDEN = "OcuPilot.Test.AnalyticsFolderItemHiddenSeam";

Parameter START = "/api/ocupilot/analytics/pivot/background";

Parameter POLL = "/api/ocupilot/analytics/pivot/background/:id";

Parameter CANCEL = "/api/ocupilot/analytics/pivot/background/:id/cancel";

Parameter MDXPOLL = "/api/ocupilot/analytics/mdx/background/:id";

/// <p>The principal that may reach the API, holds <code>%DeepSee_Portal</code> and write on the database of the run's cache but not <code>%Development</code>, so only the developer pair refuses it.</p>
/// <p>Two more principals hold both of the viewer's pairs and reach the API: <code>OcuP2414Reader</code> with write on the database of the run's cache, and <code>OcuP2414NoWrite</code> with read only.
/// Neither holds <code>%DeepSee_Admin</code>, the resource the guarded fixtures carry.</p>
Parameter PRINCIPALS = "OcuP2414NoDev:%Ens_Portal:U,%DeepSee_Portal:U,%DB_USER:RW;OcuP2414Reader:%Ens_Portal:U,%DeepSee_Portal:U,%Development:U,%DB_USER:RW;OcuP2414NoWrite:%Ens_Portal:U,%DeepSee_Portal:U,%Development:U,%DB_USER:R";

Parameter NODEV = "OcuP2414NoDev";

Parameter READER = "OcuP2414Reader";

Parameter NOWRITE = "OcuP2414NoWrite";

/// <p>The pivots a test saves and removes itself, beside the probe's.</p>
Parameter CODEPIVOT = "OcuPilotProbe/QaCode.pivot";

Parameter GUARDEDPIVOT = "OcuPilotProbe/QaGuarded.pivot";

Parameter LOCKEDPIVOT = "OcuPilotProbe/QaLocked.pivot";

Parameter VISITS = {##class(OcuPilot.Test.AnalyticsProbe).#VISITS};

/// <p>The viewer's two screens.</p>
Parameter DEFINITION = "analytics.folderitemdefinition";

Parameter WIDGETS = "analytics.dashboardwidgets";

/// <p>The resource the guarded pivots carry.</p>
Parameter GUARD = "%DeepSee_Admin";

/// <p>The subscript of the node the code-bearing pivot's braces would increment.</p>
Parameter NODE = 360;

Parameter NAMESPACE = "USER";

Parameter VIEWPIVOT = {##class(OcuPilot.Test.AnalyticsProbe).#VIEWPIVOT};

Parameter VIEWRUN = {##class(OcuPilot.Test.AnalyticsProbe).#VIEWRUN};

Parameter VIEWKPI = {##class(OcuPilot.Test.AnalyticsProbe).#VIEWKPI};

Parameter VIEWBOARD = {##class(OcuPilot.Test.AnalyticsProbe).#VIEWBOARD};

/// <p>The principal's password for this run.</p>
Property PreparedPassword As %String;

/// <p>The content type of the last response <method>Send</method> read.</p>
Property PreparedType As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedType = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPivotRun creates an IRIS user and role, turns analytics on in USER and writes cubes and folder items there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set ..PreparedPassword = "OcuP2414Run" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $Username)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "CreateViewerItems")
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals(..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.AnalyticsPivotRun")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#HIDDEN, "Unhide")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#HIDDEN, "Unhide")
    Do ..DeletePivots()
    Quit ..Settle()
}

Method OnAfterAllTests() As %Status
{
    Do ..DeletePivots()
    Set tSC = ..Settle()
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove"))
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tName = ..#NODEV, ..#READER, ..#NOWRITE {
            If ##class(Security.Users).Exists(tName) Do ##class(Security.Users).Delete(tName)
            If ##class(Security.Roles).Exists(tName _ "Role") Do ##class(Security.Roles).Delete(tName _ "Role")
            If ##class(Security.Users).Exists(tName) || ##class(Security.Roles).Exists(tName _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPivotRun left the principal or role of " _ tName))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPivotRun left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>Stop every live run of this class's two accounts, wait up to 20 seconds for each to end, then remove every row of theirs; an error when a run is still live.</p>
Method Settle() As %Status
{
    Set tOwners = $ListBuild(##class(OcuPilot.Test.Http).GetTestUsername(), ..#NODEV, ..#READER, ..#NOWRITE)
    Set tDeadline = $ZHorolog + 20
    For {
        Set tLive = 0
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(UserName), RunKey FROM OcuPilot_Kernel_State.SqlRun WHERE State IN ('queued', 'running') AND COALESCE(Kind, 'sql') = 'pivot'")
        While tResult.%Next() {
            If '$ListFind(tOwners, tResult.%GetData(1)) Continue
            Set tLive = tLive + 1
            Do ##class(OcuPilot.Area.Analytics.PivotRun).Cancel(tResult.%GetData(2), tResult.%GetData(1), .tFound)
        }
        If (tLive = 0) || ($ZHorolog > tDeadline) Quit
        Hang 0.5
        Do $ClassMethod(..#STORE, "GuardedSweep", ..#LIMITS)
    }
    For tI = 1:1:$ListLength(tOwners) {
        Do $ClassMethod(..#STORE, "GuardedForgetUser", $List(tOwners, tI))
    }
    If tLive Quit $$$ERROR($$$GeneralError, "a pivot run of this class was still live after 20 seconds")
    Quit $$$OK
}

/// <p>Save, in <code>USER</code>, the pivot <var>pName</var> on the Visits cube through the vendor's own class: guarded by <var>pResource</var> when it is given, locked when
/// <var>pLocked</var>, and in manual mode with <var>pMdx</var> as its MDX when that is given.</p>
ClassMethod SavePivot(pName As %String, pResource As %String = "", pLocked As %Boolean = 0, pMdx As %String = "") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tPivot = ##class(%DeepSee.Dashboard.Pivot).%New()
        Set tPivot.fullName = pName
        Set tPivot.cubeName = ..#VISITS
        Set tPivot.owner = "_SYSTEM"
        Set tPivot.resource = pResource
        Set tPivot.locked = pLocked
        If pMdx '= "" {
            Set tPivot.manualMode = 1
            Set tPivot.userMDX = pMdx
        }
        For tPart = $ListBuild("rowLevels", "[Place].[H1].[Category].Members"), $ListBuild("measures", "[Measures].[Amount]") {
            Set tLevel = ##class(%DeepSee.Dashboard.PivotLevel).%New()
            Set tLevel.spec = $List(tPart, 2)
            Set tCollection = $Property(tPivot, $List(tPart, 1))
            Do tCollection.Insert(tLevel)
        }
        Set tSC = tPivot.%Save()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete the pivots <method>SavePivot</method> saved for a test, whether or not it ran to its end, unlocking a locked one first.</p>
ClassMethod DeletePivots() As %Status
{
    Set tOrigNS = $NAMESPACE
    For tName = ..#CODEPIVOT, ..#GUARDEDPIVOT, ..#LOCKEDPIVOT {
        Try {
            Set $NAMESPACE = ..#NAMESPACE
            Set tItem = ##class(%DeepSee.UserLibrary.Utils).%OpenFolderItem(tName)
            If $IsObject(tItem) && tItem.locked {
                Set tItem.locked = 0
                Do tItem.%Save()
            }
            Set tItem = ""
            Do ##class(%DeepSee.UserLibrary.Utils).%DeleteFolderItem(tName)
        } Catch {
        }
        Set $NAMESPACE = tOrigNS
    }
    Kill ^|"USER"|OcuPilotProbeMdxSplice(..#NODE)
    Quit $$$OK
}

/// <p>The viewer's read of <var>pItem</var> on the screen <var>pScreen</var> as <var>pUser</var>: the status in <var>pStatus</var>, the answer in <var>pAnswer</var>, and how many rows it
/// holds, or -1 when it holds none.</p>
Method ScreenRead(pScreen As %String, pItem As %String, pUser As %String, Output pStatus As %Integer, Output pAnswer) As %Integer
{
    Do ..Send("GET", "/api/ocupilot/screens/" _ pScreen _ "/read?maxRows=100&item=" _ $ZConvert(pItem, "O", "URL"), pUser, .pStatus, .pAnswer)
    Quit $Select($IsObject(pAnswer) && $IsObject(pAnswer.%Get("rows")): pAnswer.rows.%Size(), 1: -1)
}

/// <p>The password of <var>pUser</var>.</p>
Method PasswordOf(pUser As %String) As %String
{
    If pUser = ##class(OcuPilot.Test.Http).GetTestUsername() Quit ##class(OcuPilot.Test.Http).GetTestPassword()
    Quit ..PreparedPassword
}

/// <p>Send <var>pMethod</var> <var>pPath</var> (an absolute path, in namespace <var>pNamespace</var>) as <var>pUser</var>, with <var>pBody</var> when it is given; the status, the parsed answer.</p>
Method Send(pMethod As %String, pPath As %String, pUser As %String, Output pStatus As %Integer, Output pAnswer, pBody = "", pNamespace As %String = {..#NAMESPACE})
{
    Set tText = $Select($IsObject(pBody): pBody.%ToJSON(), 1: pBody)
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ pNamespace, pUser, ..PasswordOf(pUser), .pStatus, .tRaw, .tHeaders, tText, "application/json")
    Set ..PreparedType = $Piece($Get(tHeaders("CONTENT-TYPE")), ";", 1)
    Set pAnswer = ""
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    } Catch {
        Set pAnswer = $Get(tRaw)
    }
}

/// <p>Start <var>pBody</var> as the suite's account, expect 202 and poll the run until it no longer reads running (or for <var>pSeconds</var>); the last answer, or the start's own when it was
/// not accepted. <var>pStatus</var> is the start's HTTP status and <var>pKey</var> the run id.</p>
Method RunToEnd(pBody As %DynamicObject, Output pStatus As %Integer, Output pKey As %String, pSeconds As %Numeric = 30) As %DynamicObject
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set pKey = ""
    Do ..Send("POST", ..#START, tUser, .pStatus, .tAnswer, pBody)
    If pStatus '= 202 Quit $Select($IsObject(tAnswer): tAnswer, 1: {"error": (tAnswer)})
    Set pKey = tAnswer.%Get("id")
    Set tDeadline = $ZHorolog + pSeconds
    For {
        Do ..Send("GET", $Replace(..#POLL, ":id", pKey), tUser, .tStatus, .tAnswer)
        If '$IsObject(tAnswer) || (tAnswer.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Quit tAnswer
}

/// <p>A refusal as one line: the status and the envelope's code.</p>
ClassMethod Code(pStatus As %Integer, pAnswer) As %String
{
    Quit $Get(pStatus) _ " " _ $Select($IsObject($Get(pAnswer)): pAnswer.%Get("code"), 1: $Get(pAnswer))
}

/// <p>The vendor's own composition of the saved pivot <var>pName</var>, in <code>USER</code>.</p>
ClassMethod BaseMdx(pName As %String) As %String
{
    Set tText = "vendor failed"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tText = ##class(%DeepSee.UserLibrary.Utils).%OpenFolderItem(pName).%GetBaseMDX()
    } Catch ex {
        Set tText = "vendor raised " _ ex.Name
    }
    Set $NAMESPACE = tOrigNS
    Quit tText
}

/// <p>How many run rows the suite's account has.</p>
ClassMethod Rows() As %Integer
{
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ?", ##class(OcuPilot.Test.Http).GetTestUsername())
    Quit $Select(tResult.%Next(): +tResult.%GetData(1), 1: -1)
}

/// <p>The agent's <code>analytics.mdxquery.read</code> with <var>pArgs</var>, as the running account in <code>USER</code>: the HTTP status in <var>pHttp</var>, the result and the fault.</p>
ClassMethod Agent(pArgs As %DynamicObject, Output pResult, Output pHttp As %Integer, Output pFault) As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = $ClassMethod(..#TOOL, "View", "", pArgs, 200, .pResult, .pHttp, .pFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit tSC
}

/// <p>AC2 (Integration, Rule 1), the screen's leg: a person runs the saved pivot and its cells, labels and counts are what the vendor's own result set answers for the pivot's <code>%GetBaseMDX()</code>;
/// the answer names that statement; the run is its own kind, which MDX query's poll route does not find.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Analytics.PivotRun.Resolve</method> answer the pivot's own name as the statement -- the run answers the vendor's error and this goes red on the cells.</p>
Method TestARunAnswersTheCellsTheVendorAnswersForThePivotsMdx()
{
    Set tMdx = ..BaseMdx(..#VIEWRUN)
    Do $$$AssertTrue(tMdx [ "SELECT", "the vendor composes the pivot's statement: " _ tMdx)
    Set tView = ..RunToEnd({"item": (..#VIEWRUN)}, .tStart, .tKey)
    Do $$$AssertEquals(tStart, 202, "the start is accepted")
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status") _ " " _ tView.result.outcome, 1: ""), "ended cells", "the run polls to its cells: " _ $Select($IsObject(tView): tView.%ToJSON(), 1: tView))
    If '$IsObject(tView) || '$IsObject(tView.%Get("result")) Quit
    Do $$$AssertEquals(tView.result.statement, tMdx, "the answer names the composed statement")
    Do $$$AssertEquals($ClassMethod(..#VENDOR, "Flatten", tView.result), $ClassMethod(..#VENDOR, "VendorCells", tMdx), "the cells are the vendor's own for it: " _ $ClassMethod(..#VENDOR, "Flatten", tView.result))
    Do $$$AssertEquals(tView.result.rows.%Size() _ " " _ tView.result.rowsAvailable, "5 5", "one row for each of the five categories")
    Do ..Send("GET", $Replace(..#MDXPOLL, ":id", tKey), ##class(OcuPilot.Test.Http).GetTestUsername(), .tPoll, .tAnswer)
    Do $$$AssertEquals(..Code(tPoll, tAnswer), "404 ANALYTICS.MDX.NOTFOUND", "and MDX query's poll route does not find a pivot run")
}

/// <p>The three routes each answer one JSON envelope: the start 202 with the run's id and status, the poll 200 with the run, the cancel 200 with the run as it then reads (an ended run is answered
/// as it is), and an id no run holds is answered 404 by the poll and the cancel alike, as JSON.</p>
/// <p>Mutation (Rule 19): drop the pivot cancel route's delegation in <method>OcuPilot.Api.Router.AnalyticsPivotBackgroundCancel</method> -- the cancel leg goes red.</p>
Method TestTheThreeRoutesEachAnswerOneJsonEnvelope()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, {"item": (..#VIEWRUN)})
    Do $$$AssertEquals(tStatus _ " " _ ..PreparedType _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: ""), "202 application/json running", "the start answers 202 with the run's id and status as JSON")
    Set tKey = $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: "")
    Do $$$AssertTrue($Match(tKey, "^[0-9a-f]{32}$"), "the id is 32 hexadecimal characters: " _ tKey)
    Set tDeadline = $ZHorolog + 30
    For {
        Do ..Send("GET", $Replace(..#POLL, ":id", tKey), tUser, .tStatus, .tAnswer)
        If '$IsObject(tAnswer) || (tAnswer.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Do $$$AssertEquals(tStatus _ " " _ ..PreparedType _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: ""), "200 application/json ended", "the poll answers 200 with the ended run as JSON")
    Do ..Send("POST", $Replace(..#CANCEL, ":id", tKey), tUser, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..PreparedType _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: ""), "200 application/json ended", "the cancel of an ended run answers it as it is, as JSON")
    Set tAbsent = "0123456789abcdef0123456789abcdef"
    Do ..Send("GET", $Replace(..#POLL, ":id", tAbsent), tUser, .tStatus, .tAnswer)
    Do $$$AssertEquals(..PreparedType _ " " _ ..Code(tStatus, tAnswer), "application/json 404 ANALYTICS.MDX.NOTFOUND", "a poll of an id no run holds is the 404 envelope")
    Do ..Send("POST", $Replace(..#CANCEL, ":id", tAbsent), tUser, .tStatus, .tAnswer)
    Do $$$AssertEquals(..PreparedType _ " " _ ..Code(tStatus, tAnswer), "application/json 404 ANALYTICS.MDX.NOTFOUND", "and so is a cancel of one")
}

/// <p>AC2, the agent's leg: <code>analytics.mdxquery.read</code> with <code>pivot</code> answers the cells of the same statement, which it names, so the person's run and the agent's read agree.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.View</method> read the statement argument for a pivot call -- it answers 400 and this goes red.</p>
Method TestTheAgentRunsTheSamePivotToTheSameCells()
{
    Set tMdx = ..BaseMdx(..#VIEWRUN)
    Set tSC = ..Agent({"pivot": (..#VIEWRUN)}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tResult): tResult.%Get("outcome"), 1: ""), "200 cells", "the agent's read runs the pivot: " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.statement, tMdx, "its result names the composed statement")
    Do $$$AssertEquals($ClassMethod(..#READ, "FlattenCells", tResult), $ClassMethod(..#VENDOR, "VendorCells", tMdx), "and the cells are the vendor's own for it")
    Set tView = ..RunToEnd({"item": (..#VIEWRUN)}, .tStart, .tKey)
    Do $$$AssertEquals($ClassMethod(..#VENDOR, "Flatten", tView.result), $ClassMethod(..#READ, "FlattenCells", tResult), "the person's run and the agent's read answer the same cells")
}

/// <p>A drill of a cell of a pivot's grid: the same body with <code>drill</code> composes the pivot again and answers the listing of that cell, which the grid's drill buttons ask for; a cell the
/// answer does not have ends the run failed.</p>
/// <p>Mutation (Rule 19): drop the drill's row from the request <method>OcuPilot.Area.Analytics.MdxQuery.Process</method> runs -- the listing leg goes red.</p>
Method TestADrillOfAPivotsCellAnswersThatCellsListing()
{
    Set tView = ..RunToEnd({"item": (..#VIEWRUN), "drill": {"row": 1, "column": 1}}, .tStart, .tKey)
    Do $$$AssertEquals(tStart _ " " _ $Select($IsObject(tView): tView.%Get("status") _ " " _ tView.result.outcome, 1: ""), "202 ended rows", "the drill polls to a listing: " _ $Select($IsObject(tView): $Extract(tView.%ToJSON(), 1, 300), 1: tView))
    If '$IsObject(tView) || '$IsObject(tView.%Get("result")) Quit
    Do $$$AssertTrue(tView.result.rows.%Size() > 0, "the listing holds the cell's facts")
    Do $$$AssertEquals(tView.result.statement, ..BaseMdx(..#VIEWRUN), "and names the pivot's composed statement")
}

/// <p>AC4: a pivot whose stored restriction makes its MDX run SQL asks first on the screen, answering <code>confirm</code> and naming <code>%SQLRESTRICT</code> with nothing reserved, and runs once the same
/// body carries <code>confirmed: true</code>; the agent's read of the same pivot is refused 422 <code>ANALYTICS.MDX.SQL</code>.</p>
/// <p>Mutation (Rule 19): skip the detection in <method>OcuPilot.Area.Analytics.MdxQuery.Check</method> -- the first start answers 202 and this goes red.</p>
Method TestARestrictionAsksFirstAndTheAgentIsRefused()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, {"item": (..#VIEWPIVOT)})
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("outcome") _ " " _ tAnswer.constructs.%ToJSON(), "200 confirm [""%SQLRESTRICT""]", "the restriction is answered confirm: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(tAnswer.%Get("consequence"), $Parameter("OcuPilot.Port.AnalyticsPort", "MDXCONSEQUENCE"), "with the consequence")
    Do $$$AssertEquals(..Rows(), 0, "and nothing is reserved")
    ; The Visits cube does not allow the %SQLRESTRICT dimension, so the vendor's prepare answers its own error for the confirmed run: the run reached the vendor.
    Set tView = ..RunToEnd({"item": (..#VIEWPIVOT), "confirmed": true}, .tStart, .tKey)
    Do $$$AssertEquals(tStart _ " " _ $Select($IsObject(tView): tView.%Get("outcome"), 1: ""), "200 error", "confirmed, it is not asked again and reaches the vendor: " _ $Select($IsObject(tView): $Extract(tView.%ToJSON(), 1, 300), 1: tView))
    Do $$$AssertTrue($IsObject(tView) && (tView.%Get("message") [ "%SQLRESTRICT"), "the vendor's own error names the restriction dimension")
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("statement"), 1: ""), ..BaseMdx(..#VIEWPIVOT), "and the start's own error answer names the composed statement")
    Set tSC = ..Agent({"pivot": (..#VIEWPIVOT)}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "422 ANALYTICS.MDX.SQL", "the agent's read of it is refused")
}

/// <p>AC4: a missing item, a name of 601 characters, an item a resource hides, the dashboard's name and a pivot over a KPI are refused before anything is composed or spawned: 404
/// <code>ANALYTICS.FOLDERITEM.ABSENT</code> for the first three and 409 <code>ANALYTICS.PIVOT.CUBE</code> for the last two, on the screen's start and in the agent's read.</p>
/// <p>Mutation (Rule 19): drop the cube test from <method>OcuPilot.Port.AnalyticsPort.PivotStatement</method> -- the KPI leg answers a vendor error and this goes red.</p>
Method TestAbsentAndNonPivotItemsAreRefusedBeforeAnythingRuns()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tLong = $Translate($Justify("", 601), " ", "x") _ ".pivot"
    For tCase = $ListBuild("OcuPilotProbe/Gone.pivot", "404 ANALYTICS.FOLDERITEM.ABSENT"), $ListBuild(tLong, "404 ANALYTICS.FOLDERITEM.ABSENT"), $ListBuild("", "404 ANALYTICS.FOLDERITEM.ABSENT"), $ListBuild(..#VIEWBOARD, "409 ANALYTICS.PIVOT.CUBE"), $ListBuild(..#VIEWKPI, "409 ANALYTICS.PIVOT.CUBE") {
        Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, {"item": ($List(tCase, 1))})
        Do $$$AssertEquals(..Code(tStatus, tAnswer), $List(tCase, 2), "the start refuses '" _ $Extract($List(tCase, 1), 1, 30) _ "'")
        Set tSC = ..Agent({"pivot": ($List(tCase, 1))}, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), $List(tCase, 2), "and so does the agent")
    }
    Do $$$AssertEquals(..Rows(), 0, "no run was reserved")
    Do $ClassMethod(..#HIDDEN, "Hide", ..#VIEWRUN)
    Set tSC = $ClassMethod(..#HIDDEN, "PivotStatement", ..#NAMESPACE, ..#VIEWRUN, .tStatement, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ tStatement, "404 ANALYTICS.FOLDERITEM.ABSENT|", "an item the vendor hides from the caller is refused as absent and composes nothing")
    Do $ClassMethod(..#HIDDEN, "Unhide")
    Set tSC = $ClassMethod(..#HIDDEN, "PivotStatement", ..#NAMESPACE, ..#VIEWRUN, .tStatement, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ (tStatement = ..BaseMdx(..#VIEWRUN)), "0|1", "while the same item unhidden composes the vendor's statement")
}

/// <p>The body's shape: a key other than <code>item</code>, <code>drill</code> and <code>confirmed</code> (a statement among them), an item that is not a string and a <code>confirmed</code> that is not
/// <code>true</code> are 400 <code>ANALYTICS.MDX.INPUT</code> before anything is composed. The agent's arguments name exactly one of <code>statement</code> and <code>pivot</code>: both, or neither, are 400
/// <code>TOOL.ARGUMENTS</code>.</p>
/// <p>Mutation (Rule 19): drop the exactly-one test from <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.View</method> -- the two argument legs go red.</p>
Method TestTheBodyAndTheArgumentsHaveOneShape()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    For tBody = {"item": (..#VIEWRUN), "extra": true}, {"statement": "SELECT FROM [OcuPilotProbeVisits]"}, {"item": 5}, {"item": (..#VIEWRUN), "confirmed": false}, {"item": (..#VIEWRUN), "drill": {"row": 0, "column": 1}}, {"item": (..#VIEWRUN), "statement": "SELECT FROM [OcuPilotProbeVisits]"} {
        Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, tBody)
        Do $$$AssertEquals(..Code(tStatus, tAnswer), "400 ANALYTICS.MDX.INPUT", "bad input is refused: " _ $Extract(tBody.%ToJSON(), 1, 80))
    }
    For tArgs = {"pivot": (..#VIEWRUN), "statement": "SELECT FROM [OcuPilotProbeVisits]"}, {} {
        Set tSC = ..Agent(tArgs, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "400 TOOL.ARGUMENTS", "the agent's arguments are refused: " _ tArgs.%ToJSON())
    }
    Do $$$AssertEquals(..Rows(), 0, "nothing was reserved")
}

/// <p>The gate: a principal without <code>%Development:USE</code> is refused 403 on the start, and a namespace without analytics is refused 409 <code>ANALYTICS.NAMESPACE</code> by the start and by the
/// agent's read, each before the item is looked for (the fixtures are in <code>USER</code>, so a lookup in the other namespace would answer absent).</p>
/// <p>Mutation (Rule 19): drop <code>%Development:USE</code> from <parameter>OcuPilot.Port.AnalyticsPort.MDXPAIRS</parameter> and from the privileges of the Definition tab's descriptor -- the 403 leg goes red (either alone stays green).</p>
Method TestTheGateRefusesBeforeAnyLookup()
{
    Do ..Send("POST", ..#START, ..#NODEV, .tStatus, .tAnswer, {"item": (..#VIEWRUN)})
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "403 AUTH.NOPRIVILEGE", "a principal holding the portal's pair and write on the cache's database, but not the developer pair, is refused")
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("failedPair"), 1: ""), "%Development:USE", "and the refusal names that pair")
    Do ..Send("POST", ..#START, ##class(OcuPilot.Test.Http).GetTestUsername(), .tStatus, .tAnswer, {"item": (..#VIEWRUN)}, "HSCUSTOM")
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "409 ANALYTICS.NAMESPACE", "a namespace without analytics is refused")
    Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
    Set tSC = $ClassMethod(..#TOOL, "View", "", {"pivot": (..#VIEWRUN)}, 200, .tResult, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "409 ANALYTICS.NAMESPACE", "and so is the agent's read")
    Do $$$AssertEquals(..Rows(), 0, "no run was reserved")
}

/// <p>A pivot whose stored MDX carries text that runs server-side code (a manual pivot whose statement names <code>%SEARCH</code> with braces that would increment a node) is asked first on the
/// screen, answering <code>confirm</code> with <code>%SEARCH</code> named and nothing reserved, and refused to the agent as 422 <code>ANALYTICS.MDX.SQL</code>; the node its braces would define
/// stays undefined on both.</p>
/// <p>Mutation (Rule 19): skip the detection in <method>OcuPilot.Area.Analytics.MdxQuery.Check</method> and in <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.View</method> -- both legs go red.</p>
Method TestAPivotWhoseStoredMdxRunsCodeAsksFirstAndTheAgentIsRefused()
{
    Set tNode = ..#NODE
    Kill ^|"USER"|OcuPilotProbeMdxSplice(tNode)
    Set tMdx = "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeVisits] WHERE %SEARCH.&[ID > {$Increment(^OcuPilotProbeMdxSplice(" _ tNode _ "))}]"
    Do $$$AssertStatusOK(..SavePivot(..#CODEPIVOT, "", 0, tMdx), "the manual pivot is saved")
    Do $$$AssertEquals(..BaseMdx(..#CODEPIVOT), tMdx, "the vendor composes the stored text unchanged")
    Do ..Send("POST", ..#START, ##class(OcuPilot.Test.Http).GetTestUsername(), .tStatus, .tAnswer, {"item": (..#CODEPIVOT)})
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("outcome") _ " " _ tAnswer.constructs.%ToJSON(), 1: tAnswer), "200 confirm [""%SEARCH""]", "the screen asks first, naming the construct")
    Do $$$AssertEquals(..Rows(), 0, "and reserves nothing")
    Set tSC = ..Agent({"pivot": (..#CODEPIVOT)}, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "422 ANALYTICS.MDX.SQL", "the agent's read is refused")
    Do $$$AssertEquals($Data(^|"USER"|OcuPilotProbeMdxSplice(tNode)), 0, "the node the braces would increment is undefined")
}

/// <p>A pivot guarded by a resource the caller lacks, and a locked one the same resource guards (which the vendor opens without that check), are absent to a principal that holds both of the viewer's
/// pairs and lacks the resource: the Definition read answers no row and the run's start is 404 <code>ANALYTICS.FOLDERITEM.ABSENT</code>. The account that holds the resource reads each, and the principal
/// reads an unguarded pivot and starts its run, which is the control.</p>
/// <p>Mutation (Rule 19): drop the <code>%CheckResource</code> test from <method>OcuPilot.Port.AnalyticsPort.ReadFolderItem</method> -- the locked leg goes red (the vendor's own existence check refuses the guarded one alone).</p>
Method TestAGuardedOrLockedPivotIsAbsentToAPrincipalWhoLacksItsResource()
{
    Do $$$AssertStatusOK(..SavePivot(..#GUARDEDPIVOT, ..#GUARD), "the guarded pivot is saved")
    Do $$$AssertStatusOK(..SavePivot(..#LOCKEDPIVOT, ..#GUARD, 1), "the locked guarded pivot is saved")
    Set tSuite = ##class(OcuPilot.Test.Http).GetTestUsername()
    For tName = ..#GUARDEDPIVOT, ..#LOCKEDPIVOT {
        Set tRows = ..ScreenRead(..#DEFINITION, tName, tSuite, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ tRows, "200|1", tName _ ": the account that holds the resource reads it")
        Set tRows = ..ScreenRead(..#DEFINITION, tName, ..#READER, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ tRows, "200|0", tName _ ": the principal that lacks it reads no row")
        Do ..Send("POST", ..#START, ..#READER, .tStatus, .tAnswer, {"item": (tName)})
        Do $$$AssertEquals(..Code(tStatus, tAnswer), "404 ANALYTICS.FOLDERITEM.ABSENT", tName _ ": and its run is refused as absent")
    }
    Set tRows = ..ScreenRead(..#DEFINITION, ..#VIEWRUN, ..#READER, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ tRows, "200|1", "control: the same principal reads an unguarded pivot")
    Do ..Send("POST", ..#START, ..#READER, .tStatus, .tAnswer, {"item": (..#VIEWRUN)})
    Do $$$AssertEquals(tStatus, 202, "and starts its run")
    If $IsObject(tAnswer) && (tAnswer.%Get("id") '= "") Do ..Send("POST", $Replace(..#CANCEL, ":id", tAnswer.%Get("id")), ..#READER, .tStatus, .tCancel)
}

/// <p>The run needs write on the database of the MDX cache, and the reads do not: a principal holding both pairs and read on that database reads the Definition and Widgets tabs as the
/// account does, and its run's start is refused 403 before the item is looked for.</p>
/// <p>Mutation (Rule 19): drop the destination check from <method>OcuPilot.Port.AnalyticsPort.MdxAdmit</method> -- the start answers 202 and this goes red.</p>
Method TestTheRunNeedsWriteOnTheCacheDatabaseAndTheReadsDoNot()
{
    Set tRows = ..ScreenRead(..#DEFINITION, ..#VIEWRUN, ..#NOWRITE, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ tRows, "200|1", "the Definition tab reads for a principal with read only")
    Set tRows = ..ScreenRead(..#WIDGETS, ..#VIEWBOARD, ..#NOWRITE, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ tRows, "200|3", "and so does the Widgets tab")
    Do ..Send("POST", ..#START, ..#NOWRITE, .tStatus, .tAnswer, {"item": (..#VIEWRUN)})
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "403 AUTH.NOPRIVILEGE", "the run's start is refused")
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("failedPair"), 1: ""), "%DB_USER:WRITE", "naming the write on the cache's database")
    Do $$$AssertEquals(..Rows(), 0, "and nothing is reserved")
}

}
