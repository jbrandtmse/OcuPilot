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
