/// <p>Pins Story 24.13's read surface (AD-11, AD-29, AD-35, AD-36, AD-65) against <code>USER</code>, with analytics on and the analytics settings written through the vendor's own methods by
/// <class>OcuPilot.Test.AnalyticsProbe</class>: the Settings, Worklists, RuntimeVariables and UserIcons endpoints of <class>OcuPilot.Port.AnalyticsPort</class> answer what was stored, or the
/// classic page's default for a node that is not; a stored Google Maps key reads as the credential mask and its text is in no answer; a run-time variable's expression is read as text and never
/// runs; a cap truncates; the screens and the agent's read tools answer the same rows; no read makes a journaled write; the pairs and a namespace without analytics are refused before any vendor
/// call; and the three settings globals read as they did before the class ran.</p>
/// <p>This class runs as the unit-test process, which holds <code>%All</code>; the pair refusals of the four endpoints are also pinned by <class>OcuPilot.Test.PortGate</class>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot serving over HTTP as <class>OcuPilot.Test.Http</class>'s account and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because the probe turns analytics on for <code>USER</code> and the class empties and rewrites <code>USER</code>'s three settings globals, which it restores from a
/// snapshot taken first. One class per run.</p>
Class OcuPilot.Test.AnalyticsSettingsRead Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter SEAM = "OcuPilot.Test.AnalyticsGateSeam";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter NAMESPACE = "USER";

/// <p>The four endpoints, their screens and their tools, in tab order.</p>
Parameter ENDPOINTS = "Settings,Worklists,RuntimeVariables,UserIcons";

Parameter SCREENS = "analytics.settings,analytics.worklists,analytics.runtimevariables,analytics.usericons";

/// <p>The Settings rows the General tab holds, in the port's order, with each value the marker save stores and the default each reads when it is not stored.</p>
Parameter SETTINGNAMES = "Scheme,ChartSeriesScheme,PageTitle,CompanyName,CompanyImage,CompanyLink,GoogleMapsKey,MailEnabled,DefaultResource,DashboardNoTitle,DashboardNoBorder,Controls.showCalculated,autosaveAnalyzer,autosaveUserPortal,Worklist";

Parameter SETTINGMARKERS = "OcuProbe2413Scheme|OcuProbe2413Series|OcuProbe2413 Title|OcuProbe2413 Company|/OcuProbe2413/logo.png|http://OcuProbe2413.invalid/home|[redacted]|1|OcuProbe2413Resource|1|1|1|1|1|1";

Parameter SETTINGDEFAULTS = "simple|||||||0|||||||0";

/// <p>The text the Google Maps key row reads when a key is stored: the shared credential mask.</p>
Parameter MASK = "[redacted]";

/// <p>The read class whose row helpers (<code>RowCount</code>, <code>Names</code>, <code>RowNamed</code>, <code>Canonical</code>) this class uses.</p>
Parameter ROWS = "OcuPilot.Test.AnalyticsQualityMeasureRead";

/// <p>What <code>USER</code>'s three settings globals read as before the class changed them.</p>
Property StartDigest As %String;

/// <p>Whether <property>StartDigest</property> was taken, which an empty digest, the state of a fresh instance, cannot say.</p>
Property StartTaken As %Boolean [ InitialExpression = 0 ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsRead turns analytics on in USER and rewrites its analytics settings, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "SnapshotSettings")
    If $$$ISOK(tSC) Set ..StartDigest = $ClassMethod(..#PROBE, "SettingsDigest"), ..StartTaken = 1
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe, which restores USER's flags and its three settings globals; a failing status when anything of it is left or the three read otherwise than at the start.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsRead left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    If $$$ISOK(tSC) && ..StartTaken && ($ClassMethod(..#PROBE, "SettingsDigest") '= ..StartDigest) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsSettingsRead left USER's analytics settings changed")
    Quit tSC
}

/// <p>Every test starts with nothing stored, and states what it stores.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#PROBE, "ClearSettings")
}

/// <p>Forget the gate seam's holds and arming.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>One read of <var>pEndpoint</var> in <code>USER</code> through the port: the rows in <var>pRows</var>, the HTTP status and the fault.</p>
ClassMethod Read(pEndpoint As %String, pMax As %String = 100, Output pRows, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    If pMax '= "" Set tQuery("maxRows") = pMax
    Set pRows = ""
    Set pFault = ""
    Quit $ClassMethod(..#PORT, "Invoke", pEndpoint, "LIST", .tQuery, "", .pRows, .pHttp, .pFault)
}

/// <p>The Settings rows of <var>pRows</var> as <code>name=value/stored</code> joined with <code>;</code>, in the order read.</p>
ClassMethod SettingsText(pRows As %DynamicArray) As %String
{
    If '$IsObject(pRows) Quit "unreadable"
    Set tText = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ tRow.%Get("Name") _ "=" _ tRow.%Get("Value") _ "/" _ tRow.%Get("Stored")
    }
    Quit tText
}

/// <p>The Settings rows a read should answer: each name with the value in <var>pValues</var> (a <code>|</code> list in the order of <parameter>SETTINGNAMES</parameter>) and <var>pStored</var>.</p>
ClassMethod ExpectedSettings(pValues As %String, pStored As %Boolean) As %String
{
    Set tText = ""
    For tI = 1:1:$Length(..#SETTINGNAMES, ",") {
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ $Piece(..#SETTINGNAMES, ",", tI) _ "=" _ $Piece(pValues, "|", tI) _ "/" _ pStored
    }
    Quit tText
}

/// <p>The Worklists rows of <var>pRows</var> as <code>page/panel/class/shown</code> joined with <code>;</code>, in the order read.</p>
ClassMethod WorklistsText(pRows As %DynamicArray) As %String
{
    If '$IsObject(pRows) Quit "unreadable"
    Set tText = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ tRow.%Get("Page") _ "/" _ tRow.%Get("Panel") _ "/" _ tRow.%Get("Class") _ "/" _ tRow.%Get("Shown")
    }
    Quit tText
}

/// <p>The Worklists rows a read should answer, with the options in <var>pShown</var> (a list of <code>page/panel/class</code>) shown and every other not.</p>
ClassMethod ExpectedWorklists(pShown As %List) As %String
{
    Set tText = ""
    Set tClasses = $ListBuild("%DeepSee.UserPortal.FavoritesList", "%DeepSee.UserPortal.RecentList", "%DeepSee.UserPortal.AlertList", "%DeepSee.UserPortal.DetailsList")
    For tPage = "Home", "DashboardViewer" {
        For tPanel = 1, 2 {
            For tAt = 1:1:$ListLength(tClasses) {
                Set tKey = tPage _ "/" _ tPanel _ "/" _ $List(tClasses, tAt)
                Set tText = tText _ $Select(tText = "": "", 1: ";") _ tKey _ "/" _ ''$ListFind(pShown, tKey)
            }
        }
    }
    Quit tText
}

/// <p>The names the vendor itself answers for each worklist class in <code>USER</code>, comma-separated, in the classes' order.</p>
ClassMethod WorklistNames() As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tClass = "%DeepSee.UserPortal.FavoritesList", "%DeepSee.UserPortal.RecentList", "%DeepSee.UserPortal.AlertList", "%DeepSee.UserPortal.DetailsList" {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ClassMethod(tClass, "%GetName")
        }
    } Catch ex {
        Set tText = "unreadable"
    }
    Set $NAMESPACE = tOrigNS
    Quit tText
}

/// <p>Store the marker settings through the vendor's own methods, asserting that they were stored.</p>
Method Store()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetMarkerSettings"), "the marker settings are stored through the vendor's own methods")
}

/// <p>AC1: with the markers stored, the General tab answers fifteen rows, each the value the vendor's save stored and stored; the key reads as the mask. The page's flag of customized
/// worklists and the mail flag read as the numbers the page shows.</p>
/// <p>Mutation (Rule 19): answer the key's stored text in <method>OcuPilot.Port.AnalyticsPort.Rows</method> in place of the mask -- this goes red on the key row.</p>
Method TestTheStoredSettingsAreReadAsStored()
{
    Do ..Store()
    Set tSC = ..Read("Settings", 100, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the settings read answers")
    Do $$$AssertEquals($ClassMethod(..#ROWS, "RowCount", tRows), 15, "one row per node the page saves")
    Do $$$AssertEquals(..SettingsText(tRows), ..ExpectedSettings(..#SETTINGMARKERS, 1), "each row is the stored value, and stored")
    Set tKey = $ClassMethod(..#ROWS, "RowNamed", tRows, "GoogleMapsKey")
    Do $$$AssertTrue($IsObject(tKey), "the key's row is read")
    If $IsObject(tKey) Do $$$AssertEquals(tKey.Value _ "|" _ tKey.Stored, ..#MASK _ "|1", "the key row reads the mask and says a key is stored")
}

/// <p>AC1: with nothing stored, the General tab answers the fifteen rows with the classic page's defaults and <code>Stored</code> false (the scheme <code>simple</code>, the mail and
/// customized-worklist flags 0, the rest empty), the Worklists tab sixteen rows none shown, and the variables and icons no row.</p>
/// <p>Mutation (Rule 19): read <code>Stored</code> as 1 for every row of the settings branch of <method>OcuPilot.Port.AnalyticsPort.Collect</method> -- the settings leg goes red.</p>
Method TestAnUnsetNodeReadsThePagesDefault()
{
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), "", "nothing is stored in the three settings globals")
    Set tSC = ..Read("Settings", 100, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#ROWS, "RowCount", tRows), "200|15", "the settings read answers fifteen rows")
    Do $$$AssertEquals(..SettingsText(tRows), ..ExpectedSettings(..#SETTINGDEFAULTS, 0), "each reads the page's default and not stored")
    Set tSC = ..Read("Worklists", 100, .tWorklists, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#ROWS, "RowCount", tWorklists), "200|16", "the worklists read answers sixteen rows")
    Do $$$AssertEquals(..WorklistsText(tWorklists), ..ExpectedWorklists($ListBuild()), "none is shown")
    Set tSC = ..Read("RuntimeVariables", 100, .tVariables, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#ROWS, "RowCount", tVariables), "200|0", "no run-time variable is a row")
    Set tSC = ..Read("UserIcons", 100, .tIcons, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#ROWS, "RowCount", tIcons), "200|0", "and no icon is")
}

/// <p>AC1: with the markers stored, Worklists shows exactly the two options set through the vendor's <code>SetOption</code>, each row naming the class and the name the class answers; the
/// two variables and the icon are read as the vendor's lists hold them, the variable's expression as text.</p>
Method TestTheWorklistsVariablesAndIconsAreAsStored()
{
    Do ..Store()
    Set tSC = ..Read("Worklists", 100, .tWorklists, .tHttp, .tFault)
    Do $$$AssertEquals(..WorklistsText(tWorklists), ..ExpectedWorklists($ListBuild("Home/1/%DeepSee.UserPortal.FavoritesList", "DashboardViewer/2/%DeepSee.UserPortal.DetailsList")), "exactly the two options set are shown")
    Set tNames = ""
    Set tIterator = tWorklists.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tIndex < 4 Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.Worklist
    }
    Do $$$AssertEquals(tNames, ..WorklistNames(), "each worklist's name is the one its class answers")
    Do $$$AssertEquals(tWorklists.%Get(0).Panel _ "|" _ tWorklists.%Get(15).Panel, "1|2", "the panel is a number")
    Set tSC = ..Read("RuntimeVariables", 100, .tVariables, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#ROWS, "Names", tVariables), "200|" _ $Parameter(..#PROBE, "SETTINGSVARIABLETWO") _ "," _ $Parameter(..#PROBE, "SETTINGSVARIABLE"), "the two variables are rows, in the vendor's order")
    Set tVariable = $ClassMethod(..#ROWS, "RowNamed", tVariables, $Parameter(..#PROBE, "SETTINGSVARIABLE"))
    Do $$$AssertTrue($IsObject(tVariable), "the first variable's row is read")
    If $IsObject(tVariable) Do $$$AssertEquals(tVariable.Value _ "|" _ tVariable.Comment _ "|" _ tVariable.Context, "$Increment(^OcuProbe2413Ran)|OcuProbe2413 comment|OcuProbe2413Context", "the expression, comment and context are as stored, the expression as text")
    Set tVariable = $ClassMethod(..#ROWS, "RowNamed", tVariables, $Parameter(..#PROBE, "SETTINGSVARIABLETWO"))
    Do $$$AssertTrue($IsObject(tVariable), "the second variable's row is read")
    If $IsObject(tVariable) Do $$$AssertEquals(tVariable.Value _ "|" _ tVariable.Comment _ "|" _ tVariable.Context, """text""_$Char(10)||", "a variable with no comment or context reads them empty")
    Set tSC = ..Read("UserIcons", 100, .tIcons, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#ROWS, "Names", tIcons), "200|" _ $Parameter(..#PROBE, "SETTINGSICON"), "the icon is a row")
    Set tIcon = $ClassMethod(..#ROWS, "RowNamed", tIcons, $Parameter(..#PROBE, "SETTINGSICON"))
    Do $$$AssertTrue($IsObject(tIcon), "the icon's row is read")
    If $IsObject(tIcon) Do $$$AssertEquals(tIcon.Path, "/OcuProbe2413/icon.png", "with its path as stored")
}

/// <p>AC5: the stored key's text is in no answer: not in the port's rows, the screen's read over HTTP or the agent's read tool, for the General tab, and in none of the other three tabs
/// either; the General tab's row reads the mask in each. A key stored as empty, which the save does when it is not given one, reads as no key: stored, and no mask.</p>
/// <p>Mutation (Rule 19): answer the key's own value in the <code>Value</code> of <method>OcuPilot.Port.AnalyticsPort.Rows</method> -- every leg of this goes red.</p>
Method TestTheStoredKeyIsNeverAnswered()
{
    Do ..Store()
    Set tKeyText = $Parameter(..#PROBE, "SETTINGSKEY")
    Set tCap = $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    For tI = 1:1:4 {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Set tScreen = $Piece(..#SCREENS, ",", tI)
        Set tSC = ..Read(tEndpoint, 100, .tRows, .tHttp, .tFault)
        Do $$$AssertTrue($IsObject(tRows) && (tRows.%ToJSON() '[ tKeyText), tEndpoint _ ": the key is not in the port's rows")
        Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/" _ tScreen _ "/read?maxRows=100", "", .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus, 200, tScreen _ ": the screen reads")
        Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() '[ tKeyText), tScreen _ ": the key is not in the screen's read")
        Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg(tScreen _ ".read", {}, tCap)
        Do $$$AssertEquals(tLeg.%Get("http"), 200, tScreen _ ".read answers")
        Do $$$AssertTrue(tLeg.%ToJSON() '[ tKeyText, tScreen _ ".read: the key is not in the agent's answer")
        If tI = 1 {
            Set tScreenKey = $Select($IsObject(tAnswer.%Get("rows")): $ClassMethod(..#ROWS, "RowNamed", tAnswer.rows, "GoogleMapsKey"), 1: "")
            Set tToolKey = $Select($IsObject(tLeg.%Get("rows")): $ClassMethod(..#ROWS, "RowNamed", tLeg.rows, "GoogleMapsKey"), 1: "")
            Do $$$AssertTrue($IsObject(tScreenKey) && $IsObject(tToolKey), "the screen and the tool each carry the key's row")
            If $IsObject(tScreenKey) && $IsObject(tToolKey) Do $$$AssertEquals(tScreenKey.Value _ "|" _ tToolKey.Value, ..#MASK _ "|" _ ..#MASK, "and it reads the mask in each")
        }
    }
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tEmpty = ##class(%ZEN.proxyObject).%New()
    Set tOrigNS = $NAMESPACE
    Set tMessage = "not saved"
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tMessage = ##class(%DeepSee.UI.Settings).SaveToServer(tEmpty)
    } Catch tEx {
        Set tMessage = tEx.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(tMessage, "", "the vendor's save stores a page given nothing")
    Set tSC = ..Read("Settings", 100, .tRows, .tHttp, .tFault)
    Set tKey = $ClassMethod(..#ROWS, "RowNamed", tRows, "GoogleMapsKey")
    Do $$$AssertTrue($IsObject(tKey), "the key's row is read after the save")
    If $IsObject(tKey) Do $$$AssertEquals(tKey.Value _ "|" _ tKey.Stored, "|1", "a key stored as empty is stored and reads no mask")
    Set tScheme = $ClassMethod(..#ROWS, "RowNamed", tRows, "Scheme")
    Do $$$AssertTrue($IsObject(tScheme), "the scheme's row is read after the save")
    If $IsObject(tScheme) Do $$$AssertEquals(tScheme.Value _ "|" _ tScheme.Stored, "|1", "and a scheme stored as empty reads empty, as the page shows it")
}

/// <p>AC4: a run-time variable's expression is read as text and never runs: after every read of the matrix, here and in the journal-scanning test, the global the stored expression would set is
/// still undefined.</p>
/// <p>Mutation (Rule 19): evaluate each variable's expression in the variables branch of <method>OcuPilot.Port.AnalyticsPort.Collect</method> through the vendor's evaluating read -- this goes red on the global.</p>
Method TestAVariablesExpressionNeverRuns()
{
    Do ..Store()
    Set tAnswers = ..ReadEverything()
    Do $$$AssertEquals(tAnswers, "200,200,200,200|200,200,200,200|200,200", "every read answers")
    Do $$$AssertEquals($Data(^|"USER"|OcuProbe2413Ran), 0, "the global the expression would set is undefined after every read")
    Set tSC = ..Read("RuntimeVariables", 100, .tVariables, .tHttp, .tFault)
    Set tVariable = $ClassMethod(..#ROWS, "RowNamed", tVariables, $Parameter(..#PROBE, "SETTINGSVARIABLE"))
    Do $$$AssertTrue($IsObject(tVariable) && (tVariable.Value = "$Increment(^OcuProbe2413Ran)"), "while the variable's row shows the expression")
}

/// <p>The cap: a maxRows below the count answers that many rows through the port, and the screens report the read truncated (AD-36); a cap equal to the count reports nothing cut.</p>
/// <p>Mutation (Rule 19): drop the <code>pMax</code> stop of the worklists branch in <method>OcuPilot.Port.AnalyticsPort.Collect</method> -- the worklists leg goes red.</p>
Method TestACapBoundsTheListsAndTheScreensSaySo()
{
    Do ..Store()
    For tCase = $ListBuild("Settings", "analytics.settings", 15), $ListBuild("Worklists", "analytics.worklists", 16), $ListBuild("RuntimeVariables", "analytics.runtimevariables", 2) {
        Set tEndpoint = $List(tCase, 1)
        Set tSC = ..Read(tEndpoint, 1, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#ROWS, "RowCount", tRows), "200|1", tEndpoint _ ": a cap of one answers one row")
        Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/" _ $List(tCase, 2) _ "/read?maxRows=1", "", .tStatus, .tCut)
        Do $$$AssertEquals(tStatus, 200, tEndpoint _ ": the screen reads under a cap of one")
        Do $$$AssertTrue($IsObject(tCut), tEndpoint _ ": the capped read answers a body")
        If $IsObject(tCut) Do $$$AssertEquals(tCut.%Get("truncated") _ "|" _ $Select($IsObject(tCut.%Get("rows")): tCut.rows.%Size(), 1: -1), "1|1", tEndpoint _ ": one row, and the read says it was cut")
        Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/" _ $List(tCase, 2) _ "/read?maxRows=" _ $List(tCase, 3), "", .tStatus, .tFit)
        Do $$$AssertTrue($IsObject(tFit), tEndpoint _ ": the read at the count answers a body")
        If $IsObject(tFit) Do $$$AssertEquals(tFit.%Get("truncated") _ "|" _ $Select($IsObject(tFit.%Get("rows")): tFit.rows.%Size(), 1: -1), "0|" _ $List(tCase, 3), tEndpoint _ ": a cap equal to the count answers every row and says nothing was cut")
    }
}

/// <p>AC2 (Integration, Rule 1): each screen's read over HTTP and the agent's read tool answer the same rows with the markers stored, and the rows are the ones the stored settings make, so the
/// comparison is never of two empty reads.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.Read.View</method> answer no rows -- this goes red on every screen.</p>
Method TestTheScreensAndTheAgentsToolsAnswerTheSameRows()
{
    Do ..Store()
    Set tCap = $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    For tI = 1:1:4 {
        Set tId = $Piece(..#SCREENS, ",", tI)
        Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/" _ tId _ "/read?maxRows=100", "", .tStatus, .tScreen)
        Do $$$AssertEquals(tStatus, 200, tId _ ": the screen reads")
        Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg(tId _ ".read", {}, tCap)
        Do $$$AssertEquals(tLeg.%Get("http") _ "|" _ tLeg.%Get("error"), "200|", tId _ ": the agent's read tool answers: " _ tLeg.%ToJSON())
        Do $$$AssertTrue($IsObject(tScreen) && $IsObject(tLeg.%Get("rows")) && $IsObject(tScreen.%Get("rows")), tId _ ": both reads carry rows")
        If $IsObject(tScreen) && $IsObject(tLeg.%Get("rows")) && $IsObject(tScreen.%Get("rows")) {
            Do $$$AssertEquals(tLeg.rows.%Size(), $Piece("15,16,2,1", ",", tI), tId _ ": with the rows the markers make")
            Do $$$AssertEquals($ClassMethod(..#ROWS, "Canonical", tLeg.rows), $ClassMethod(..#ROWS, "Canonical", tScreen.rows), tId _ ": the tool's rows are the screen's, the tool's in its descriptor's sort order and the screen's in the port's")
        }
    }
}

/// <p>The gate: with only the portal's pair held a read of each endpoint is refused 403, naming <code>%Development:USE</code>, and a namespace that does not report analytics is refused
/// 409 <code>ANALYTICS.NAMESPACE</code>, each before any vendor call. The namespace refusals are answered while a vendor failure is armed on the gate seam, so a vendor call before the gate would
/// answer 500; with the namespace that reports analytics the armed failure is reached, which proves the arming. The refusals of the full roster are also pinned by <class>OcuPilot.Test.PortGate</class>.</p>
/// <p>Mutation (Rule 19): list <code>%DeepSee_PortalEdit:USE</code> in place of <code>%Development:USE</code> in <parameter>OcuPilot.Port.AnalyticsPort.SETTINGSPAIRS</parameter> -- the refusal legs go red.</p>
Method TestTheGateRefusesBeforeAnyVendorCall()
{
    Do $ClassMethod(..#SEAM, "Arm", "collect", "status")
    For tI = 1:1:4 {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_Portal", "USE")
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "403|AUTH.NOPRIVILEGE", tEndpoint _ ": without the developer pair the read is refused")
        Do $$$AssertEquals($Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: ""), "%Development:USE", tEndpoint _ ": and the refusal names the pair")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
        Kill tQuery
        Set tQuery("namespace") = "HSCUSTOM"
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "409|ANALYTICS.NAMESPACE", tEndpoint _ ": a namespace without analytics is refused")
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 500, tEndpoint _ ": in a namespace that reports analytics the armed vendor failure is reached, so the refusals above came first")
    }
}

/// <p>AC4: no read of the matrix makes a journaled write in the calling process. The journal window covers every read this test makes, which are the instance's first only when no class or spec that reads the settings ran before it. The
/// records it does not charge to them are the SQL engine's own: its statement index (<code>^rINDEXSQL</code>) and its <code>^%SYS("sql")</code> bookkeeping,
/// which a statement's first run on a fresh instance writes. The scan is proved able to see a write: a control write made inside the same window is found by name among its
/// records, and the reads before it found none. It covers the process's journaled databases; a write to a database that is not journaled is not seen.</p>
/// <p>Mutation (Rule 19): evaluate each variable's expression in the variables branch of <method>OcuPilot.Port.AnalyticsPort.Collect</method> through the vendor's evaluating read -- the no-write leg goes red,
/// naming the record.</p>
Method TestAAReadsMakeNoJournaledWrite()
{
    Do ..Store()
    ; The framework journals each assertion it records, so nothing is asserted until both scans are done.
    Set tMark = $ClassMethod(..#PROBE, "JournalMark")
    Set tAnswers = ..ReadEverything()
    Set tTotal = $ClassMethod(..#PROBE, "JournalWrites", tMark, .tReadWrites)
    Set tReads = $Select(tTotal < 0: tTotal, 1: 0)
    Set tFirst = ""
    For tI = 1:1:tTotal {
        Set tRecord = tReadWrites(tI)
        If (tRecord '[ "]rINDEXSQL(") && (tRecord '[ "]%SYS(""sql"",") Set tReads = tReads + 1, tFirst = tFirst _ $Select(tFirst = "": "", 1: "; ") _ tRecord
    }
    Set ^|"USER"|OcuPilotProbeAnalyticsScan = 1
    Set tTotal = $ClassMethod(..#PROBE, "JournalWrites", tMark, .tAllWrites)
    Kill ^|"USER"|OcuPilotProbeAnalyticsScan
    Set tSeen = 0
    Set tControl = ""
    For tI = 1:1:tTotal {
        If $Get(tAllWrites(tI)) [ "OcuPilotProbeAnalyticsScan" Set tSeen = tSeen + 1, tControl = tAllWrites(tI)
    }
    Do $$$AssertEquals(tAnswers, "200,200,200,200|200,200,200,200|200,200", "the four reads, the agent's four reads and the two capped reads answer")
    Do $$$AssertEquals(tReads, 0, "the reads made no journaled write" _ $Select(tReads > 0: ": " _ tFirst, tReads < 0: " (the journal rolled to another file)", 1: ""))
    Do $$$AssertEquals(tSeen, 1, "while the scan finds the control write made after them" _ $Select(tTotal < 0: " (the journal rolled to another file)", tSeen '= 1: " (records: " _ tTotal _ ")", 1: ": " _ tControl))
    Do $$$AssertEquals($Data(^|"USER"|OcuProbe2413Ran), 0, "and the stored expression never ran")
}

/// <p>Every read the AC4 scan covers: the four endpoints, the agent's four read tools and two reads cut by a cap of one. Answers the HTTP statuses as
/// <code>endpoints|tools|capped</code>.</p>
Method ReadEverything() As %String
{
    Set tEndpointsHttp = ""
    For tI = 1:1:4 {
        Set tSC = ..Read($Piece(..#ENDPOINTS, ",", tI), 100, .tRows, .tHttp, .tFault)
        Set tEndpointsHttp = tEndpointsHttp _ $Select(tEndpointsHttp = "": "", 1: ",") _ tHttp
    }
    Set tCap = $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tToolsHttp = ""
    For tI = 1:1:4 {
        Set tToolsHttp = tToolsHttp _ $Select(tToolsHttp = "": "", 1: ",") _ ##class(OcuPilot.Test.AnalyticsGate).ToolLeg($Piece(..#SCREENS, ",", tI) _ ".read", {}, tCap).%Get("http")
    }
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tSC = ..Read("Settings", 1, .tRows, .tCapHttp, .tFault)
    Set tSC = ..Read("Worklists", 1, .tRows, .tHttp, .tFault)
    Quit tEndpointsHttp _ "|" _ tToolsHttp _ "|" _ tCapHttp _ "," _ tHttp
}

/// <p>Story 24.13 Batch 2: each General row carries the kind of value it takes and the sentence that says so (<code>Kind</code>, <code>Accepts</code>): a scheme and the mail flag are choices the
/// vendor's lists name, the flags are booleans, the texts take up to 2,000 characters and the Google Maps key is a secret that says so whether or not one is stored; each Worklists row carries
/// <code>Customized</code>, the flag the portal reads before any option, false with nothing stored and true once the worklists are customized.</p>
/// <p>Mutation (Rule 19): read <code>Kind</code> of the key as <code>text</code> in <method>OcuPilot.Port.AnalyticsPort.Rows</method> -- the key leg goes red; read <code>Customized</code> as false
/// in <method>OcuPilot.Port.AnalyticsPort.Collect</method> -- the customized leg goes red.</p>
Method TestTheRowsCarryTheirKindAndWhetherWorklistsAreCustomized()
{
    Set tSC = ..Read("Settings", 100, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the settings read answers with nothing stored")
    For tCase = $ListBuild("Scheme", "choice", "One of simple, bluechip, chrome, contemporary, mba, roswell."), $ListBuild("ChartSeriesScheme", "choice", "One of urban, tuscan, caribbean, rustbelt, bright, gray, pastel, solid."), $ListBuild("MailEnabled", "choice", "One of 1, 2, 0."), $ListBuild("DashboardNoTitle", "boolean", "0 (off) or 1 (on)."), $ListBuild("Worklist", "boolean", "0 (off) or 1 (on)."), $ListBuild("PageTitle", "text", "Text of up to 2000 characters."), $ListBuild("GoogleMapsKey", "secret", "Text of up to 2000 characters.") {
        Set tRow = $ClassMethod(..#ROWS, "RowNamed", tRows, $List(tCase, 1))
        Do $$$AssertTrue($IsObject(tRow), $List(tCase, 1) _ ": its row is read")
        If $IsObject(tRow) Do $$$AssertEquals(tRow.Kind _ "|" _ tRow.Accepts, $List(tCase, 2) _ "|" _ $List(tCase, 3), $List(tCase, 1) _ ": its kind and the sentence that says what it accepts")
    }
    Set tSC = ..Read("Worklists", 100, .tWorklists, .tWorklistHttp, .tFault)
    Do $$$AssertEquals(tWorklistHttp _ "|" _ $Select($IsObject(tWorklists): tWorklists.%Size(), 1: ""), "200|16", "the Worklists read answers its sixteen rows with nothing stored")
    If '$IsObject(tWorklists) Quit
    Set tCustomized = 0
    Set tIterator = tWorklists.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tOne) {
        Set tCustomized = tCustomized + tOne.Customized
    }
    Do $$$AssertEquals(tCustomized, 0, "no Worklists row says the worklists are customized while nothing is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SetMarkerSettings"), "the markers are stored, among them the flag of customized worklists")
    Set tSC = ..Read("Worklists", 100, .tAfter, .tAfterHttp, .tFault)
    Set tCustomized = 0
    Set tIterator = tAfter.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tOne) {
        Set tCustomized = tCustomized + tOne.Customized
    }
    Do $$$AssertEquals(tCustomized, 16, "all sixteen rows say so once the worklists are customized")
}

/// <p>AC7: removing the markers by restoring the snapshot leaves the three settings globals as they were when the class started, no marker in any of them and no snapshot: the
/// fixture's own check sees the markers while they are stored, and the digest of the three equals the one taken first. It sorts last, so no other test runs on what it restores.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Test.AnalyticsProbe.RestoreSettings</method> leave <code>^DeepSee.User.Icons</code> as the markers made it -- this goes red, naming the marker.</p>
Method TestZRestoringTheSettingsLeavesThemAsFound()
{
    Do ..Store()
    Do $$$AssertTrue($ClassMethod(..#PROBE, "SettingsLeft") [ "marker", "while the markers are stored the fixture reports them: " _ $ClassMethod(..#PROBE, "SettingsLeft"))
    Do $$$AssertTrue($ClassMethod(..#PROBE, "SettingsDigest") '= ..StartDigest, "and the three globals read otherwise than at the start")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreSettings"), "the settings are restored from the snapshot")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsLeft"), "", "no marker and no snapshot remains: " _ $ClassMethod(..#PROBE, "SettingsLeft"))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SettingsDigest"), ..StartDigest, "and the three globals read as they did at the start")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SnapshotSettings"), "a snapshot is taken again, as the class's cleanup expects one")
}

}
