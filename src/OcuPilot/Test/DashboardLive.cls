/// <p>Story 16.7 against the live instance, in process and as this account: the Dashboard read
/// answers every declared field with CPU a number; License usage's Summary answers the vendor's five
/// rows and By process at least one row carrying a process id; the read tool answers the fields and
/// rows the route does (AC6); and neither read moves the SAM alerts cursor (AC4, DW-1116, AD-7).</p>
/// <p><b>Run it on a throwaway only.</b> The cursor test saves the vendor's alerts cursor
/// (<code>^IRIS.Temp.SAM("LastAlertSent")</code> in <code>%SYS</code>), kills it, reads, and restores
/// it in <method>OnAfterOneTest</method>, so an external alerts scraper reading the instance in that
/// window would see its cursor absent. Needs OcuPilot installed in <code>HSCUSTOM</code> and serving
/// over HTTP as <class>OcuPilot.Test.Http</class>'s test account; creates no principal. Each
/// collection moves the sensors' stored previous values, as every sensor read does (AD-29).</p>
Class OcuPilot.Test.DashboardLive Extends %UnitTest.TestCase
{

/// <p>The Dashboard descriptor.</p>
Parameter DASHBOARD = "OcuPilot.Screen.Descriptor.Dashboard";

/// <p>License usage's Summary tab.</p>
Parameter SUMMARY = "OcuPilot.Screen.Descriptor.LicenseSummaryTab";

/// <p>License usage's By process tab.</p>
Parameter PROCESSES = "OcuPilot.Screen.Descriptor.LicenseProcessTab";

/// <p>Whether <method>SaveCursor</method> saved the cursor, so <method>OnAfterOneTest</method>
/// restores it.</p>
Property SavedCursorHeld As %Boolean [ InitialExpression = 0 ];

/// <p>The cursor node and its subtree as saved, merged here.</p>
Property SavedCursor [ MultiDimensional ];

Method OnAfterOneTest() As %Status
{
    Set tSC = $$$OK
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    If ..SavedCursorHeld {
        Kill ^|"%SYS"|IRIS.Temp.SAM("LastAlertSent")
        If $Data(..SavedCursor) Merge ^|"%SYS"|IRIS.Temp.SAM("LastAlertSent") = ..SavedCursor
        Kill ..SavedCursor
        Set ..SavedCursorHeld = 0
    }
    Quit tSC
}

/// <p>Save the alerts cursor and its subtree, for <method>OnAfterOneTest</method> to restore.</p>
Method SaveCursor()
{
    Kill ..SavedCursor
    If $Data(^|"%SYS"|IRIS.Temp.SAM("LastAlertSent")) Merge ..SavedCursor = ^|"%SYS"|IRIS.Temp.SAM("LastAlertSent")
    Set ..SavedCursorHeld = 1
}

/// <p>The Dashboard read answers one row carrying every declared field as a non-null scalar, CPU a
/// JSON number and every status member one of the dashboard's words or another vendor word.</p>
Method TestTheDashboardReadAnswersEveryFieldWithCpuANumber()
{
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DASHBOARD, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the live Dashboard read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.rows.%Size(), 1, "exactly one row, the instance's own")
    If tResult.rows.%Size() '= 1 Quit
    Set tRow = tResult.rows.%Get(0)
    Do $$$AssertEquals(tResult.fields.%Size(), 30, "all thirty declared fields")
    Set tIterator = tResult.fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Set tType = tRow.%GetTypeOf(tField)
        Do $$$AssertTrue((tType = "number") || (tType = "string"), "declared field '" _ tField _ "' is a non-null scalar, not " _ tType)
    }
    Do $$$AssertEquals(tRow.%GetTypeOf("Sensors.cpuUsage"), "number", "CPU is a JSON number: " _ tRow.%Get("Sensors.cpuUsage"))
    Do $$$AssertTrue((tRow.%Get("Sensors.cpuUsage") >= 0) && (tRow.%Get("Sensors.cpuUsage") <= 100), "and a percentage")
    Do $$$AssertTrue(tRow.%Get("Dashboard.SystemUsage.DatabaseSpace") '= "", "the database-space status carries a word")
}

/// <p>License usage's Summary answers the vendor's five rows, each carrying a label, and By process
/// at least one row whose process id is a number.</p>
Method TestTheSummaryAnswersFiveRowsAndByProcessAPid()
{
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SUMMARY, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the live Summary read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.rows.%Size(), 5, "the vendor's five summary rows")
    Set tIterator = tResult.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $$$AssertTrue(tRow.LicenseUnitUse '= "", "row " _ (tIndex + 1) _ " carries its label")
    }

    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#PROCESSES, "", .tProcesses, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC, "the live By process read succeeds")
    Do $$$AssertEquals(tHttp2, 200, "at 200")
    If '$IsObject(tProcesses) Quit
    Do $$$AssertTrue(tProcesses.rows.%Size() >= 1, "at least one process holds a license entry: " _ tProcesses.rows.%Size())
    If tProcesses.rows.%Size() < 1 Quit
    Do $$$AssertEquals(tProcesses.rows.%Get(0).%GetTypeOf("PID"), "number", "carrying its process id as a number")
}

/// <p>AC4 (DW-1116, AD-7): with the alerts cursor absent, a Dashboard read and a License usage read
/// leave it absent -- neither the dashboard's counts nor the sensor collection advances the cursor
/// the vendor's alerts read keeps. The cursor is saved first and restored in
/// <method>OnAfterOneTest</method>.</p>
/// <p>Mutation: call the vendor's alerts read in <method>OcuPilot.Port.MonitorPort.Invoke</method>
/// -&gt; the cursor is set and this goes red.</p>
Method TestTheAlertCursorIsUnchangedByTheDashboardAndLicenseReads()
{
    Do ..SaveCursor()
    Kill ^|"%SYS"|IRIS.Temp.SAM("LastAlertSent")
    Do $$$AssertEquals($Data(^|"%SYS"|IRIS.Temp.SAM("LastAlertSent")), 0, "the cursor starts absent")

    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DASHBOARD, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the Dashboard read succeeds")
    Do $$$AssertEquals($Data(^|"%SYS"|IRIS.Temp.SAM("LastAlertSent")), 0, "and leaves the cursor absent")

    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SUMMARY, "", .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC, "the License usage read succeeds")
    Do $$$AssertEquals($Data(^|"%SYS"|IRIS.Temp.SAM("LastAlertSent")), 0, "and leaves it absent too")
}

/// <p>AC6: each screen's read tool, called in process, answers the fields the route answers over
/// HTTP, and the same rows -- the Summary's five labels, and the Dashboard's one row with its
/// keys in order and its license limit.</p>
Method TestTheToolAnswersWhatTheRouteDraws()
{
    For tCase = $ListBuild(..#SUMMARY, "osmgmt.licensesummary"), $ListBuild(..#DASHBOARD, "osmgmt.dashboard") {
        Set tClass = $List(tCase, 1)
        Set tTool = $List(tCase, 2)
        Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
        Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(tClass, {}, 1000, .tView, .tViewHttp, .tViewFault)
        Do ##class(OcuPilot.Kernel.Scope).Clear()
        Do $$$AssertStatusOK(tSC, tTool _ ": the tool reads")
        If $$$ISERR(tSC) || '$IsObject(tView) Continue

        Set tRouteSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ tTool _ "/read?maxRows=1000", "_SYSTEM", "SYS", .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tRouteSC, tTool _ ": the route request completes")
        Do $$$AssertEquals(tStatus, 200, tTool _ ": the route answers")
        If tStatus '= 200 Continue
        Set tRoute = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
        Do $$$AssertEquals(tView.fields.%ToJSON(), tRoute.fields.%ToJSON(), tTool _ ": the same declared fields")
        Do $$$AssertEquals(tView.rows.%Size(), tRoute.rows.%Size(), tTool _ ": the same number of rows")
        If tClass = ..#SUMMARY {
            Do $$$AssertEquals(..Labels(tView.rows), ..Labels(tRoute.rows), tTool _ ": the same five labels")
        } ElseIf (tView.rows.%Size() = 1) && (tRoute.rows.%Size() = 1) {
            Do $$$AssertEquals(##class(OcuPilot.Test.SystemUsage).KeysOf(tView.rows.%Get(0)), ##class(OcuPilot.Test.SystemUsage).KeysOf(tRoute.rows.%Get(0)), tTool _ ": the same keys, in order")
            Do $$$AssertEquals(tView.rows.%Get(0).%Get("Dashboard.Licensing.LicenseLimit"), tRoute.rows.%Get(0).%Get("Dashboard.Licensing.LicenseLimit"), tTool _ ": the same license limit")
        }
    }
}

/// <p>The <code>LicenseUnitUse</code> labels of <var>pRows</var>, sorted, comma-separated.</p>
ClassMethod Labels(pRows As %DynamicArray) As %String
{
    Kill tSorted
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSorted(tRow.LicenseUnitUse) = ""
    }
    Set tText = ""
    Set tLabel = ""
    For {
        Set tLabel = $Order(tSorted(tLabel))
        If tLabel = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tLabel
    }
    Quit tText
}

}
