/// <p>Pins Story 24.14 Batch 1's two reads (AD-11, AD-29, AD-36, AD-60, AD-65) against <code>USER</code>, with analytics on and the viewer's fixtures saved through the vendor's own classes by
/// <class>OcuPilot.Test.AnalyticsProbe</class>: the <code>FolderItemDefinition</code> and <code>DashboardWidgets</code> endpoints of <class>OcuPilot.Port.AnalyticsPort</class> answer what
/// <code>%DeepSee.Dashboard.Pivot</code> and <code>%DeepSee.Dashboard.Definition</code> hold, as the port's rows, the screens' reads over HTTP and the agent's two derived read tools; an item that is
/// missing, too long a name, hidden from the caller or of another kind reads no row; no read makes a journaled write, touches a person's recent items or an item's last-access time; and the pairs and a
/// namespace without analytics are refused before any vendor call.</p>
/// <p>This class runs as the unit-test process, which holds <code>%All</code>; the pair refusals of the two endpoints are also pinned by <class>OcuPilot.Test.PortGate</class>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot serving over HTTP as <class>OcuPilot.Test.Http</class>'s account and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the probe
/// turns analytics on for <code>USER</code> and writes folder items there, all of which it removes after the last test.</p>
Class OcuPilot.Test.AnalyticsFolderItemView Extends %UnitTest.TestCase [ DependsOn = OcuPilot.Test.AnalyticsProbe ]
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter HIDDEN = "OcuPilot.Test.AnalyticsFolderItemHiddenSeam";

Parameter SEAM = "OcuPilot.Test.AnalyticsGateSeam";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter ROWS = "OcuPilot.Test.AnalyticsQualityMeasureRead";

Parameter NAMESPACE = "USER";

Parameter DEFINITION = "analytics.folderitemdefinition";

Parameter WIDGETS = "analytics.dashboardwidgets";

/// <p>The probe's viewer fixtures, by name.</p>
Parameter VIEWPIVOT = {##class(OcuPilot.Test.AnalyticsProbe).#VIEWPIVOT};

Parameter VIEWRUN = {##class(OcuPilot.Test.AnalyticsProbe).#VIEWRUN};

Parameter VIEWMANUAL = {##class(OcuPilot.Test.AnalyticsProbe).#VIEWMANUAL};

Parameter VIEWKPI = {##class(OcuPilot.Test.AnalyticsProbe).#VIEWKPI};

Parameter VIEWBOARD = {##class(OcuPilot.Test.AnalyticsProbe).#VIEWBOARD};

Parameter VIEWMDX = {##class(OcuPilot.Test.AnalyticsProbe).#VIEWMDX};

Parameter VIEWKPICUBE = {##class(OcuPilot.Test.AnalyticsProbe).#VIEWKPICUBE};

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemView turns analytics on in USER and writes folder items there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $Username)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "CreateViewerItems")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsFolderItemView left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#HIDDEN, "Unhide")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#HIDDEN, "Unhide")
    Quit $$$OK
}

/// <p>One read of <var>pEndpoint</var> of the item <var>pItem</var> in <var>pNamespace</var> through <var>pPort</var>: the rows in <var>pRows</var>, the HTTP status and the fault.</p>
ClassMethod Read(pEndpoint As %String, pItem As %String, Output pRows, Output pHttp As %Integer, Output pFault, pPort As %String = {..#PORT}, pNamespace As %String = {..#NAMESPACE}) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("maxRows") = 100
    Set tQuery("item") = pItem
    Set pRows = ""
    Set pFault = ""
    Quit $ClassMethod(pPort, "Invoke", pEndpoint, "LIST", .tQuery, "", .pRows, .pHttp, .pFault)
}

/// <p>What <code>%DeepSee.Dashboard.Pivot</code> or <code>%DeepSee.Dashboard.Definition</code> holds for <var>pName</var>, opened in <code>USER</code> and read property by property: the
/// Definition row the item should read as and, for a dashboard, the Widgets rows, as <code>{definition, widgets}</code>.</p>
ClassMethod Stored(pName As %String) As %DynamicObject
{
    Set tOut = {"definition": {}, "widgets": []}
    Set tModified = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tItem = ##class(%DeepSee.UserLibrary.Utils).%OpenFolderItem(pName)
        Set tRow = tOut.definition
        Do tRow.%Set("Name", tItem.fullName, "string")
        Do tRow.%Set("Type", tItem.%GetTypeName(), "string")
        Do tRow.%Set("Title", tItem.title, "string")
        Do tRow.%Set("Description", tItem.description, "string")
        Do tRow.%Set("Owner", tItem.owner, "string")
        Set tModified = tItem.timeModified
        Do tRow.%Set("Modified", tModified, "string")
        If tItem.%IsA("%DeepSee.Dashboard.Pivot") {
            Do tRow.%Set("Cube", tItem.cubeName, "string")
            For tPart = $ListBuild("Rows", "rowLevels"), $ListBuild("Columns", "columnLevels"), $ListBuild("Measures", "measures"), $ListBuild("Filters", "filters") {
                Set tList = $Property(tItem, $List(tPart, 2))
                Set tText = ""
                For tAt = 1:1:tList.Count() Set tText = tText _ $Select(tAt = 1: "", 1: $Char(10)) _ tList.GetAt(tAt).spec
                Do tRow.%Set($List(tPart, 1), tText, "string")
            }
            Set tText = ""
            For tAt = 1:1:tItem.calculatedMembers.Count() Set tText = tText _ $Select(tAt = 1: "", 1: $Char(10)) _ tItem.calculatedMembers.GetAt(tAt).memberName
            Do tRow.%Set("Calculated", tText, "string")
            Do tRow.%Set("MDX", $Select(tItem.manualMode: tItem.userMDX, 1: ""), "string")
            Do tRow.%Set("Restriction", tItem.sqlRestriction, "string")
        } Else {
            For tField = "Cube", "Rows", "Columns", "Measures", "Filters", "Calculated", "MDX", "Restriction" Do tRow.%Set(tField, "", "string")
            For tAt = 1:1:tItem.widgets.Count() {
                Set tWidget = tItem.widgets.GetAt(tAt)
                Set tWidgetRow = {}
                Do tWidgetRow.%Set("Dashboard", tItem.fullName, "string")
                Do tWidgetRow.%Set("Position", tAt, "number")
                Do tWidgetRow.%Set("Title", tWidget.title, "string")
                Do tWidgetRow.%Set("Type", tWidget.type, "string")
                Do tWidgetRow.%Set("DataSource", tWidget.dataSource, "string")
                Do tWidgetRow.%Set("LinkedTo", tWidget.dataLink, "string")
                Do tWidgetRow.%Set("NotPivot", ($Piece(tWidget.dataSource, ".", $Length(tWidget.dataSource, ".")) = "kpi") || (tWidget.dataSource = ""), "boolean")
                Do tOut.widgets.%Push(tWidgetRow)
            }
        }
    } Catch ex {
        Set tOut = {"error": (ex.DisplayString())}
    }
    Set $NAMESPACE = tOrigNS
    ; The vendor stamps UTC; the port reads it as the instance's local time, which only this namespace's classes can format.
    If tOut.%IsDefined("definition") && tOut.definition.%IsDefined("Modified") Do tOut.definition.%Set("Modified", ##class(OcuPilot.Port.AnalyticsPort).LocalStamp(tModified), "string")
    Quit tOut
}

/// <p>The one Definition row <var>pRows</var> holds, as JSON, or <code>"no row"</code>.</p>
ClassMethod Line(pRows As %DynamicArray) As %String
{
    If '$IsObject(pRows) || (pRows.%Size() '= 1) Quit "no row"
    Quit pRows.%Get(0).%ToJSON()
}

/// <p>The same read as the screen at <code>GET /screens/&lt;screen&gt;/read</code> answers it (the rows), and as the agent's derived tool <code>&lt;screen&gt;.read</code> answers it, in
/// <var>pScreen</var> and <var>pTool</var>; <var>pStatus</var> is the screen's HTTP status and <var>pToolHttp</var> the tool's.</p>
ClassMethod Surfaces(pScreen As %String, pItem As %String, Output pScreenRows, Output pToolRows, Output pStatus As %Integer, Output pToolHttp As %Integer)
{
    Set pScreenRows = ""
    Set pToolRows = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/" _ pScreen _ "/read?maxRows=100&item=" _ $ZConvert(pItem, "O", "URL"), "", .pStatus, .tAnswer)
    If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("rows")) Set pScreenRows = tAnswer.rows
    Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg(pScreen _ ".read", {"item": (pItem)}, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
    Set pToolHttp = tLeg.%Get("http")
    If $IsObject(tLeg.%Get("rows")) Set pToolRows = tLeg.rows
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>AC1: a pivot saved through <code>%DeepSee.Dashboard.Pivot</code> with a row level, a column level, a measure, a filter, a calculated member and a restriction reads, by the port, by the screen
/// and by the derived tool, as one Definition row equal to each property it holds, and its Widgets tab has no rows.</p>
/// <p>Mutation (Rule 19): read <code>Filters</code> from <code>rowLevels</code> in <method>OcuPilot.Port.AnalyticsPort.ReadFolderItem</method> -- the Filters field of every leg goes red.</p>
Method TestAPivotsDefinitionIsWhatItsClassHolds()
{
    Set tStored = ..Stored(..#VIEWPIVOT)
    Do $$$AssertTrue('tStored.%IsDefined("error"), "the pivot is read from the vendor's class: " _ tStored.%ToJSON())
    Do $$$AssertEquals(tStored.definition.Rows _ "|" _ tStored.definition.Calculated _ "|" _ tStored.definition.Restriction, "[Place].[H1].[Category].Members" _ $Char(10) _ "[Seen].[H1].[Year].Members|Twice|Amount > 0", "the fixture holds two row levels, a calculated member and a restriction")
    Set tSC = ..Read("FolderItemDefinition", ..#VIEWPIVOT, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..Line(tRows), "200|" _ tStored.definition.%ToJSON(), "the port's row is every property the class holds")
    Do ..Surfaces(..#DEFINITION, ..#VIEWPIVOT, .tScreen, .tTool, .tStatus, .tToolHttp)
    Do $$$AssertEquals(tStatus _ "|" _ ..Line(tScreen), "200|" _ tStored.definition.%ToJSON(), "the screen reads the same row")
    Do $$$AssertEquals(tToolHttp _ "|" _ ..Line(tTool), "200|" _ ..Line(tScreen), "and so does the agent's tool")
    Set tSC = ..Read("DashboardWidgets", ..#VIEWPIVOT, .tWidgets, .tWidgetsHttp, .tFault)
    Do $$$AssertEquals(tWidgetsHttp _ "|" _ $ClassMethod(..#ROWS, "RowCount", tWidgets), "200|0", "a pivot has no widgets")
}

/// <p>AC1: a dashboard saved through <code>%DeepSee.Dashboard.Definition</code> with three widgets reads three Widgets rows in the stored order, each equal to its stored properties: a widget on a pivot is
/// not <code>NotPivot</code>, one on a KPI is, and one that takes its data from another has no data source and keeps its link; the same by the screen and the tool. Its Definition row has no pivot field.</p>
/// <p>Mutation (Rule 19): read <code>LinkedTo</code> from <code>dataSource</code> in <method>OcuPilot.Port.AnalyticsPort.ReadFolderItemView</method> -- the third widget's row goes red on every leg.</p>
Method TestADashboardsWidgetsAreInTheOrderTheyAreStored()
{
    Set tStored = ..Stored(..#VIEWBOARD)
    Do $$$AssertEquals(tStored.widgets.%Size(), 3, "the fixture holds three widgets: " _ tStored.%ToJSON())
    Do $$$AssertEquals(tStored.widgets.%Get(0).NotPivot _ tStored.widgets.%Get(1).NotPivot _ tStored.widgets.%Get(2).NotPivot, "011", "the pivot's widget is not a NotPivot, the KPI's and the linked one are, as booleans")
    Set tSC = ..Read("DashboardWidgets", ..#VIEWBOARD, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ tRows.%ToJSON(), "200|" _ tStored.widgets.%ToJSON(), "the port reads the three widgets in order, each as stored")
    Do ..Surfaces(..#WIDGETS, ..#VIEWBOARD, .tScreen, .tTool, .tStatus, .tToolHttp)
    Do $$$AssertEquals(tStatus _ "|" _ ..Canon(tScreen), "200|" _ ..Canon(tRows), "the screen reads the same rows")
    Do $$$AssertEquals(tToolHttp _ "|" _ ..Canon(tTool), "200|" _ ..Canon(tRows), "and so does the agent's tool")
    Set tSC = ..Read("FolderItemDefinition", ..#VIEWBOARD, .tDefinition, .tDefinitionHttp, .tFault)
    Do $$$AssertEquals(tDefinitionHttp _ "|" _ ..Line(tDefinition), "200|" _ tStored.definition.%ToJSON(), "the dashboard's Definition row has the pivot fields empty")
    Set tRow = $Select($IsObject(tDefinition) && (tDefinition.%Size() = 1): tDefinition.%Get(0), 1: {})
    Do $$$AssertEquals(tRow.Type _ "|" _ tRow.Cube _ "|" _ tRow.MDX, "Dashboard||", "it is a dashboard")
}

/// <p>AC1: a widget's data source is a pivot unless it is empty or its extension is <code>kpi</code>, <code>metric</code> or <code>worksheet</code>, as the classic pivot widget decides; a name with no
/// extension, a pivot and a longer extension that merely ends the same way are pivots.</p>
/// <p>Mutation (Rule 19): drop <code>"metric"</code> from the extension list in <method>OcuPilot.Port.AnalyticsPort.WidgetNotPivot</method> -- the metric leg goes red.</p>
Method TestAWidgetsDataSourceIsAPivotUnlessItsExtensionSaysOtherwise()
{
    For tCase = $ListBuild("", 1), $ListBuild("A/B.kpi", 1), $ListBuild("A/B.metric", 1), $ListBuild("A/B.worksheet", 1), $ListBuild("A/B.pivot", 0), $ListBuild("A/B", 0), $ListBuild("A/B.kpix", 0) {
        Do $$$AssertEquals($ClassMethod(..#PORT, "WidgetNotPivot", $List(tCase, 1)), $List(tCase, 2), "'" _ $List(tCase, 1) _ "' is " _ $Select($List(tCase, 2): "not ", 1: "") _ "a pivot")
    }
}

/// <p>The rows of <var>pRows</var>, sorted as <class>OcuPilot.Test.AnalyticsQualityMeasureRead</class>'s <code>Canonical</code>, or <code>"none"</code>.</p>
ClassMethod Canon(pRows As %DynamicArray) As %String
{
    If '$IsObject(pRows) Quit "none"
    Quit $ClassMethod(..#ROWS, "Canonical", pRows)
}

/// <p>AC1: a pivot in manual mode shows its own MDX, and one that is not in manual mode shows none; a pivot over a KPI is a pivot and reads its stored cube name.</p>
/// <p>Mutation (Rule 19): answer <code>userMDX</code> whether or not <code>manualMode</code> is set in <method>OcuPilot.Port.AnalyticsPort.ReadFolderItem</method> -- the matrix's MDX leg goes red.</p>
Method TestAManualPivotShowsItsOwnMdxAndOthersShowNone()
{
    Set tSC = ..Read("FolderItemDefinition", ..#VIEWMANUAL, .tManual, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..Line(tManual), "200|" _ ..Stored(..#VIEWMANUAL).definition.%ToJSON(), "the manual pivot reads as stored")
    Do $$$AssertEquals($Select($IsObject(tManual) && (tManual.%Size() = 1): tManual.%Get(0).MDX, 1: "no row"), ..#VIEWMDX, "its MDX is the one it holds")
    Set tSC = ..Read("FolderItemDefinition", ..#VIEWPIVOT, .tPlain, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tPlain) && (tPlain.%Size() = 1): tPlain.%Get(0).MDX, 1: "no row"), "", "a pivot that is not in manual mode shows no MDX")
    Set tSC = ..Read("FolderItemDefinition", ..#VIEWKPI, .tKpi, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tKpi) && (tKpi.%Size() = 1): tKpi.%Get(0).Cube, 1: "no row"), ..#VIEWKPICUBE, "a pivot over a KPI reads its stored cube name")
}

/// <p>A missing name, a name of 601 characters, an empty criterion, an item the caller's resources hide, and an item of another kind (a dashboard asked for as a pivot's Widgets, an item that is neither
/// a pivot nor a dashboard) each read no row, for both endpoints; a hidden item reads no row though it exists.</p>
/// <p>Mutation (Rule 19): drop the <code>FolderItemVisible</code> test from <method>OcuPilot.Port.AnalyticsPort.ReadFolderItemView</method> -- the hidden leg goes red.</p>
Method TestAbsentHiddenAndOtherItemsReadNoRow()
{
    Set tLong = $Translate($Justify("", 601), " ", "x") _ ".pivot"
    For tName = "OcuPilotProbe/Gone.pivot", tLong, "", ..#VIEWBOARD _ "x", $Extract(..#VIEWRUN, 1, 12) {
        For tEndpoint = "FolderItemDefinition", "DashboardWidgets" {
            Set tSC = ..Read(tEndpoint, tName, .tRows, .tHttp, .tFault)
            Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#ROWS, "RowCount", tRows), "200|0", tEndpoint _ " of '" _ $Extract(tName, 1, 30) _ "' reads no row")
        }
    }
    Set tSC = ..Read("DashboardWidgets", ..#VIEWRUN, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals($ClassMethod(..#ROWS, "RowCount", tRows), 0, "a pivot has no Widgets rows")
    Do $ClassMethod(..#HIDDEN, "Hide", ..#VIEWBOARD)
    For tEndpoint = "FolderItemDefinition", "DashboardWidgets" {
        Set tSC = ..Read(tEndpoint, ..#VIEWBOARD, .tRows, .tHttp, .tFault, ..#HIDDEN)
        Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(..#ROWS, "RowCount", tRows), "200|0", tEndpoint _ " of an item the vendor hides from the caller reads no row")
    }
    Do $ClassMethod(..#HIDDEN, "Unhide")
    Set tSC = ..Read("DashboardWidgets", ..#VIEWBOARD, .tRows, .tHttp, .tFault, ..#HIDDEN)
    Do $$$AssertEquals($ClassMethod(..#ROWS, "RowCount", tRows), 3, "while the same item unhidden reads its three widgets")
}

/// <p>The text a process's recent items and the items' last-access times read as: each user's <code>recent</code> node of <code>^DeepSee.UserPreferences</code> in <code>USER</code>, and the
/// <code>lastAccessed</code> of the viewer's items.</p>
ClassMethod Touched() As %String
{
    Set tText = ""
    Set tUser = ""
    For {
        Set tUser = $Order(^|"USER"|DeepSee.UserPreferences(tUser))
        If tUser = "" Quit
        If $Data(^|"USER"|DeepSee.UserPreferences(tUser, "recent")) Set tText = tText _ tUser _ "=recent;"
    }
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tName = ..#VIEWPIVOT, ..#VIEWRUN, ..#VIEWMANUAL, ..#VIEWKPI, ..#VIEWBOARD {
            Set tItem = ##class(%DeepSee.UserLibrary.Utils).%OpenFolderItem(tName)
            Set tText = tText _ tName _ "=" _ tItem.lastAccessed _ "/" _ tItem.timeModified _ ";"
        }
    } Catch ex {
        Set tText = tText _ "unreadable: " _ ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    Quit tText
}

/// <p>AC3: no read of the matrix writes. Every read of both endpoints for every fixture, through the port and through the two derived tools, makes no journaled write in the calling process (the SQL
/// engine's own statement bookkeeping is not charged to them), and with the two screens' reads over HTTP no person's recent items or item's last-access or modified time changes. The scan is proved able to
/// see a write: a control write made inside the same window is found by name.</p>
/// <p>Mutation (Rule 19): call <code>%RegisterRecentItem</code> for the opened item in <method>OcuPilot.Port.AnalyticsPort.ReadFolderItem</method> -- this goes red on the recent items.</p>
Method TestAAReadsWriteNothingAndTouchNoRecentItem()
{
    Set tBefore = ..Touched()
    Set tMark = $ClassMethod(..#PROBE, "JournalMark")
    Set tAnswers = ""
    For tName = ..#VIEWPIVOT, ..#VIEWRUN, ..#VIEWMANUAL, ..#VIEWKPI, ..#VIEWBOARD {
        For tEndpoint = "FolderItemDefinition", "DashboardWidgets" {
            Set tSC = ..Read(tEndpoint, tName, .tRows, .tHttp, .tFault)
            Set tAnswers = tAnswers _ tHttp
        }
    }
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    For tScreen = ..#DEFINITION, ..#WIDGETS {
        Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg(tScreen _ ".read", {"item": (..#VIEWBOARD)}, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
        Set tAnswers = tAnswers _ tLeg.%Get("http")
    }
    Do ##class(OcuPilot.Kernel.Scope).Clear()
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
    For tI = 1:1:tTotal {
        If $Get(tAllWrites(tI)) [ "OcuPilotProbeAnalyticsScan" Set tSeen = tSeen + 1
    }
    Do $$$AssertEquals(tAnswers, "200200200200200200200200200200200200", "every read answers 200")
    Do $$$AssertEquals(tReads, 0, "the reads made no journaled write" _ $Select(tReads > 0: ": " _ tFirst, tReads < 0: " (the journal rolled to another file)", 1: ""))
    Do $$$AssertEquals(tSeen, 1, "while the scan finds the control write made after them")
    For tScreen = ..#DEFINITION, ..#WIDGETS {
        Do ..Surfaces(tScreen, ..#VIEWBOARD, .tScreenRows, .tToolRows, .tStatus, .tToolHttp)
        Do ..Surfaces(tScreen, ..#VIEWPIVOT, .tScreenRows, .tToolRows, .tStatus, .tToolHttp)
    }
    Do $$$AssertEquals(..Touched(), tBefore, "no recent item or last-access time changed, including after the screens' reads over HTTP")
}

/// <p>The gate: with only the portal's pair held a read of each endpoint is refused 403, naming <code>%Development:USE</code>, and a namespace that does not report analytics is refused 409
/// <code>ANALYTICS.NAMESPACE</code>, for the reads and for the composition of a pivot's statement, each before the item is looked for: the item the fixtures hold is read in <code>USER</code> and
/// would read no row in a namespace that lacks it, so a read of the other namespace that answers a refusal reached the gate first. The pair refusals of the endpoints are also pinned by
/// <class>OcuPilot.Test.PortGate</class>.</p>
/// <p>Mutation (Rule 19): list <code>%DeepSee_PortalEdit:USE</code> in place of <code>%Development:USE</code> in <parameter>OcuPilot.Port.AnalyticsPort.FOLDERPAIRS</parameter> -- the 403 legs go red.</p>
Method TestTheGateRefusesBeforeTheItemIsLookedFor()
{
    For tEndpoint = "FolderItemDefinition", "DashboardWidgets" {
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_Portal", "USE")
        Set tSC = ..Read(tEndpoint, ..#VIEWBOARD, .tRows, .tHttp, .tFault, ..#SEAM, ..#NAMESPACE)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "403|AUTH.NOPRIVILEGE", tEndpoint _ ": without the developer pair the read is refused")
        Do $$$AssertEquals($Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: ""), "%Development:USE", tEndpoint _ ": and the refusal names the pair")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
        Set tSC = ..Read(tEndpoint, ..#VIEWBOARD, .tRows, .tHttp, .tFault, ..#SEAM, "HSCUSTOM")
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "409|ANALYTICS.NAMESPACE", tEndpoint _ ": a namespace without analytics is refused")
    }
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_Portal", "USE")
    Set tSC = $ClassMethod(..#SEAM, "PivotStatement", ..#NAMESPACE, ..#VIEWRUN, .tStatement, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ tStatement, "403|AUTH.NOPRIVILEGE|", "composing a pivot's statement is refused without the pair, and composes nothing")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Set tSC = $ClassMethod(..#SEAM, "PivotStatement", "HSCUSTOM", ..#VIEWRUN, .tStatement, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "") _ "|" _ tStatement, "409|ANALYTICS.NAMESPACE|", "and in a namespace without analytics")
}

}
