/// <p>AD-29's <b>two ways together</b>, for the three log sources (Story 5.4, AC6).</p>
/// <ul>
/// <li><b>Way one, here:</b> each source's declared pair set carries the resource the classic
/// portal page it replaces requires (<code>%Admin_Operate</code>, the resource
/// <code>/csp/sys/op</code> carries), the descriptor and the port declare the same set, and the
/// port refuses when that pair is not held -- observed by driving the refusal.</li>
/// <li><b>Way two, elsewhere:</b> the same sets run as real least-privileged principals over the
/// wire, in <class>OcuPilot.Test.LogSourceDenial</class> and
/// <class>OcuPilot.Test.ErrorLogDenial</class>. Reading a declaration alone settles nothing, which
/// is why neither half is this class's on its own.</li>
/// </ul>
/// <p><b>Live-safe.</b> It spawns nothing, creates no principal and writes nothing; the denials
/// are driven through the ports' own gate seams, because <code>%UnitTest</code> runs as an account
/// holding <code>%All</code>.</p>
Class OcuPilot.Test.LogPairs Extends %UnitTest.TestCase
{

/// <p>The port whose pair sets are under test.</p>
Parameter PORT = "OcuPilot.Port.LogSourcePort";

/// <p>The gate whose held set a test declares.</p>
Parameter GATE = "OcuPilot.Test.ScreenGate";

/// <p>The resource the classic portal requires of all three pages: <code>/csp/sys/op</code>
/// carries it, and <file>irislib/%CSP/UI/Portal/ViewLog.cls</file> names it explicitly.</p>
Parameter CLASSICRESOURCE = "%Admin_Operate";

/// <p>The permission that resource is required at.</p>
Parameter CLASSICPERMISSION = "USE";

/// <p>One row per log source, <code>|</code>-separated, as
/// <code>&lt;descriptor&gt;=&lt;port parameter&gt;</code>.</p>
Parameter SOURCES = "OcuPilot.Screen.Descriptor.LogMessageViewer=MESSAGESPAIRS|OcuPilot.Screen.Descriptor.LogAlertViewer=ALERTSPAIRS|OcuPilot.Screen.Descriptor.LogErrorList=ERRORSINSTANCEPAIRS";

/// <p>Story 16.8's six sources, <code>|</code>-separated, as
/// <code>&lt;descriptor&gt;=&lt;port parameter&gt;=&lt;classic page&gt;</code>, followed by
/// <code>=&lt;pair&gt;</code> where the source also requires a pair its classic page does not name:
/// the background task error log's <code>%DB_IRISSYS:READ</code>, because its task list is read in
/// <code>%SYS</code> (Story 16.5).</p>
Parameter SECONDARYSOURCES = "OcuPilot.Screen.Descriptor.LogSystemMonitorViewer=SYSTEMMONITORPAIRS=%CSP.UI.Portal.ViewLog|OcuPilot.Screen.Descriptor.LogTaskErrorViewer=TASKERRORSPAIRS=%CSP.UI.Portal.BackgroundTaskError=%DB_IRISSYS:READ|OcuPilot.Screen.Descriptor.LogXdbcViewer=XDBCPAIRS=%CSP.UI.Portal.xDBCErrorNamespaces|OcuPilot.Screen.Descriptor.LogSqlDiagnosticsViewer=SQLDIAGNOSTICSPAIRS=%CSP.UI.Portal.SQL.Logs|OcuPilot.Screen.Descriptor.LogEventViewer=EVENTLOGPAIRS=EnsPortal.EventLog=%Ens_Portal:USE|OcuPilot.Screen.Descriptor.LogAnalyticsViewer=ANALYTICSPAIRS=%DeepSee.UI.LogViewer";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogSourceFixture).SetGateClass("")
    Do ##class(OcuPilot.Test.ErrorLogFixture).SetGateClass("")
    Quit $$$OK
}

/// <p><b>AC6, way one</b> -- each log source's declared pair set carries the classic page's own
/// resource, and the descriptor and the port declare the same set.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Operate:USE</code> from
/// <parameter>OcuPilot.Port.LogSourcePort.MESSAGESPAIRS</parameter> -> this goes red.</p>
Method TestEachLogSourceDeclaresItsClassicPagesResource()
{
    Set tWanted = ..#CLASSICRESOURCE _ ":" _ ..#CLASSICPERMISSION
    For tI = 1:1:$Length(..#SOURCES, "|") {
        Set tRow = $Piece(..#SOURCES, "|", tI)
        Set tDescriptor = $Piece(tRow, "=", 1)
        Set tParameter = $Piece(tRow, "=", 2)

        Set tPortSpec = $Parameter(..#PORT, tParameter)
        Do $$$AssertTrue(tPortSpec [ tWanted, tParameter _ ": carries the classic page's resource: " _ tPortSpec)

        Set tDeclared = ##class(OcuPilot.Screen.Gate).RequiredPairs(tDescriptor, .tResolved)
        Do $$$AssertEquals(tResolved, 1, tDescriptor _ ": its requirement is readable")
        Set tDeclaredSpec = ##class(OcuPilot.Kernel.Audit.Ledger).PairsToString(tDeclared, .tCut)
        Do $$$AssertEquals(tCut, 0, tDescriptor _ ": its requirement is spelled in full")
        Do $$$AssertTrue(tDeclaredSpec [ tWanted, tDescriptor _ ": declares the classic page's resource too: " _ tDeclaredSpec)

        ; The port's set and the descriptor's set are the same requirement, so a user reaches a
        ; line through OcuPilot only if they could have read it directly (AD-29).
        Set tPortPairs = ##class(OcuPilot.Screen.Gate).ParsePairSpec(tPortSpec)
        Set tPortNormalized = ##class(OcuPilot.Kernel.Audit.Ledger).PairsToString(tPortPairs, .tPortCut)
        Do $$$AssertEquals(tDeclaredSpec, tPortNormalized, tDescriptor _ ": the screen and the port require the same set")
    }
}

/// <p>Story 16.8, way one -- each secondary log declares its classic page, and its port pair set is
/// that page's own <code>RESOURCE</code> at <code>USE</code> (the first, where the page names
/// alternatives), or the Logs area's <code>%Admin_Operate:USE</code> where the page names none, then
/// the extra pair the row names; the descriptor declares the same set.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Port.LogSourcePort.EVENTLOGPAIRS</parameter> to
/// <code>%Admin_Operate:USE</code> -&gt; the event log row goes red; drop <code>%DB_IRISSYS:READ</code>
/// from <parameter>OcuPilot.Port.LogSourcePort.TASKERRORSPAIRS</parameter> -&gt; the task error log
/// row goes red.</p>
Method TestEachSecondaryLogDeclaresItsClassicPagesResource()
{
    For tI = 1:1:$Length(..#SECONDARYSOURCES, "|") {
        Set tRow = $Piece(..#SECONDARYSOURCES, "|", tI)
        Set tDescriptor = $Piece(tRow, "=", 1)
        Set tPortSpec = $Parameter(..#PORT, $Piece(tRow, "=", 2))
        Set tPage = $Piece(tRow, "=", 3)

        Set tSC = $ClassMethod(tDescriptor, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tDescriptor _ ": parses")
        If $$$ISERR(tSC) Continue
        Do $$$AssertEquals(tDeclaration.classicPage, tPage, tDescriptor _ ": declares its classic page")

        Set tParameter = ##class(%Dictionary.CompiledParameter).%OpenId(tPage _ "||RESOURCE")
        Set tResource = $Piece($Piece($Select($IsObject(tParameter): tParameter.Default, 1: ""), ",", 1), ":", 1)
        Set tWanted = $Select(tResource = "": ..#CLASSICRESOURCE, 1: tResource) _ ":" _ ..#CLASSICPERMISSION
        If $Piece(tRow, "=", 4) '= "" Set tWanted = tWanted _ "," _ $Piece(tRow, "=", 4)
        Do $$$AssertEquals(tPortSpec, tWanted, tDescriptor _ ": the port's pair is " _ tPage _ "'s own resource, with any extra pair the row names")

        Set tDeclared = ##class(OcuPilot.Screen.Gate).RequiredPairs(tDescriptor, .tResolved)
        Set tDeclaredSpec = ##class(OcuPilot.Kernel.Audit.Ledger).PairsToString(tDeclared, .tCut)
        Set tPortSpecNormalized = ##class(OcuPilot.Kernel.Audit.Ledger).PairsToString(##class(OcuPilot.Screen.Gate).ParsePairSpec(tPortSpec), .tPortCut)
        Do $$$AssertEquals(tDeclaredSpec, tPortSpecNormalized, tDescriptor _ ": the screen and the port require the same set")
    }
}

/// <p><b>AC6</b> -- the console log refuses a caller who holds everything except
/// <code>%Admin_Operate:USE</code>, naming that pair, before the file is opened; and the same
/// caller granted it is served.</p>
/// <p>Mutation (Rule 19): remove the gate evaluation from
/// <method>OcuPilot.Port.LogSourcePort.Page</method> -> this goes red.</p>
Method TestTheConsoleLogRefusesWithoutAdminOperate()
{
    Do ##class(OcuPilot.Test.LogSourceFixture).SetGateClass(..#GATE)
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    ; Everything the source could require except the one pair under test, so the refusal below is
    ; attributable to that pair and not to a caller who held nothing.
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Secure", "USE")

    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Page("messages", "", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the console log is refused")
    Do $$$AssertEquals(tHttp, ##class(OcuPilot.Kernel.Denial).#STATUS, "with 403")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Kernel.Denial).Code(), "AUTH.NOPRIVILEGE")
    Do $$$AssertEquals($Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.failedPair, 1: ""), ..#CLASSICRESOURCE _ ":" _ ..#CLASSICPERMISSION, "naming exactly the pair the classic page requires")

    Do ##class(OcuPilot.Test.ScreenGate).Hold(..#CLASSICRESOURCE, ..#CLASSICPERMISSION)
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Page("messages", "", "", "", .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC, "and the same caller granted that one pair is served: " _ $Select($IsObject(tFault2): tFault2.%ToJSON(), 1: ""))
}

/// <p><b>AC6</b> -- the application error log refuses the same caller at the same pair, through
/// its own entry.</p>
/// <p>Mutation (Rule 19): remove the gate evaluation from
/// <method>OcuPilot.Port.LogSourcePort.Errors</method> -> this goes red.</p>
Method TestTheErrorLogRefusesWithoutAdminOperate()
{
    Do ##class(OcuPilot.Test.ErrorLogFixture).SetGateClass(..#GATE)
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")

    Set tSC = ##class(OcuPilot.Test.ErrorLogFixture).Errors("namespaces", "", "", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the application error log is refused")
    Do $$$AssertEquals(tHttp, ##class(OcuPilot.Kernel.Denial).#STATUS, "with 403")
    Do $$$AssertEquals($Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.failedPair, 1: ""), ..#CLASSICRESOURCE _ ":" _ ..#CLASSICPERMISSION, "naming exactly the pair the classic page requires")

    Do ##class(OcuPilot.Test.ScreenGate).Hold(..#CLASSICRESOURCE, ..#CLASSICPERMISSION)
    Set tSC = ##class(OcuPilot.Test.ErrorLogFixture).Errors("namespaces", "", "", "", "", .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC, "and the same caller granted that one pair is served: " _ $Select($IsObject(tFault2): tFault2.%ToJSON(), 1: ""))
}

}
