/// <p>What Story 24.17 Batch 5's armed system monitor suites share: the arming check, the probe production of <class>OcuPilot.Test.ProductionProbe</class> in <code>USER</code>, which a test starts
/// when it needs one running and which every test removes, so <code>USER</code> is as found; the seam's mode; the port's calls through the shipped class or a seam; the screen's read route and the
/// agent's read tool; and the vendor's own call made beside the port's, with the meters that stay the same between two calls.</p>
/// <p>The vendor's call writes its own bookkeeping records (<code>^SYS.EnsMetrics</code>), which the suites allow and no other write. <b>The suites start a production only in <code>USER</code></b>,
/// and the class refuses to start while that namespace holds a production that is not the probe's.</p>
/// <p><b>Not run itself</b>: it declares no test.</p>
Class OcuPilot.Test.InteropSystemMonitorCase Extends %UnitTest.TestCase [ Abstract ]
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter SEAM = "OcuPilot.Test.InteropSystemMonitorSeam";

Parameter CAPSEAM = "OcuPilot.Test.InteropSystemMonitorCapSeam";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter SHARED = "OcuPilot.Test.InteropAlertCase";

Parameter MODE = "^IRIS.Temp.OcuProbe2417SmMode";

/// <p>The four endpoints, in the order the screens are numbered.</p>
Parameter ENDPOINTS = "SystemMonitor,SystemMonitorProcesses,SystemMonitorQueues,SystemMonitorTasks";

/// <p>The meters whose value does not move between two calls made a moment apart on an idle instance, which the port's row and the vendor's call made beside it must agree on.</p>
Parameter STABLE = "EnsNamespace,EnsProductionsRunning,EnsProductionsTroubled,LicenseLimit,DatabaseSpace,DatabaseJournal,JournalSpace,LockTable,WriteDaemon,EnsActiveQueues,EnsErrors,EnsAlerts";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, ..%ClassName(1) _ " starts the probe production in USER and creates principals on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set tSC = $ClassMethod(..#PROBE, "CheckOwn")
    If $$$ISERR(tSC) Quit $$$ERROR($$$GeneralError, ..%ClassName(1) _ " refuses to start: USER holds a production that is not the probe's, so nothing was run.")
    If '$ClassMethod(..#PROBE, "Gone") Do $ClassMethod(..#PROBE, "Remove")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Do $ClassMethod(..#PROBE, "Remove")
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "ClearLog")
    Kill ^IRIS.Temp.OcuProbe2417SmMode
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "ClearLog")
    Kill ^IRIS.Temp.OcuProbe2417SmMode
    Do $ClassMethod(..#PROBE, "Remove")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Gone"), "the probe production is stopped and removed, so USER is as found")
    Quit $$$OK
}

/// <p>Create the probe production in <code>USER</code>, start it, wait until it runs and until the vendor's last answer is old enough for the next read to see it (<method>AgeSnapshot</method>).</p>
ClassMethod StartProbe() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Create")
    If $$$ISERR(tSC) Quit tSC
    Set tProduction = $Parameter(..#PROBE, "PRODUCTION")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "USER"
        Set tSC = ##class(Ens.Director).StartProduction(tProduction)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "AwaitRunning", 60)
    If $$$ISERR(tSC) Quit tSC
    Do ..AgeSnapshot()
    Quit $$$OK
}

/// <p>Wait until the vendor's last answer is older than the interval it keeps one for (10 seconds): a call made inside that interval is answered from the last one's counts, so a read that must see a
/// production start or stop is made after this.</p>
ClassMethod AgeSnapshot()
{
    Hang 11
}

/// <p>The port class <var>pClass</var>'s <code>LIST</code> of <var>pEndpoint</var> in <var>pNamespace</var> as <code>status code</code>, the rows in <var>pResult</var>, the envelope in
/// <var>pFault</var>. <var>pQuery</var> names the call's other keys.</p>
ClassMethod Verdict(pEndpoint As %String, Output pResult, Output pFault, ByRef pQuery, pNamespace As %String = "USER", pClass As %String = {..#PORT}) As %String
{
    Quit $ClassMethod(..#SHARED, "Verdict", pEndpoint, "LIST", .pResult, .pFault, .pQuery, pNamespace, pClass)
}

/// <p>The vendor's own call, made as the classic page makes it and beside the port's: its meter values in <var>pValues</var>. A process with no web request is given the minimal context the
/// vendor needs while a production runs, which this class makes for itself so that the port's own handling is not what it compares against.</p>
ClassMethod VendorBeside(Output pValues) As %Status
{
    Kill pValues
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        If '$IsObject($Get(%request)) {
            New %request, %response, %session
            Set %request = ##class(%CSP.Request).%New()
            Set %response = ##class(%CSP.Response).%New()
            Set %session = ##class(%CSP.Session).%New("OcuP2417SmBeside", 0)
            Set $NAMESPACE = "%SYS"
            Set tSC = ##class(%SYS.Ensemble).GetEnsMetrics("", 0, .tValues, .tStatus, .tMsg)
        } Else {
            Set $NAMESPACE = "%SYS"
            Set tSC = ##class(%SYS.Ensemble).GetEnsMetrics("", 0, .tValues, .tStatus, .tMsg)
        }
        ; The vendor leaves one exclusive and one shared lock behind each call, which this process would hold until it ends.
        Lock -^SYS.EnsMetrics
        Lock -^SYS.EnsMetrics#"S"
        Set $NAMESPACE = tOrigNS
        Merge pValues = tValues
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The screen's read route for <var>pRoute</var> (<code>interop.systemmonitor</code> and its drill-downs) as the test account: the status in <var>pStatus</var> and the answer.</p>
ClassMethod Route(pRoute As %String, Output pStatus As %Integer, Output pAnswer) As %Status
{
    Quit $ClassMethod(..#SHARED, "Call", "GET", "/screens/" _ pRoute _ "/read", "", .pStatus, .pAnswer, "USER")
}

/// <p>The agent's read tool <var>pRoute</var>.read, with <var>pArgs</var> (an object): the rows in <var>pResult</var> and the status.</p>
ClassMethod ReadTool(pRoute As %String, Output pResult, Output pHttp As %Integer) As %Status
{
    Set pResult = ""
    Set pHttp = 0
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(pRoute _ ".read", .tTool)
    If '$IsObject($Get(tTool)) Quit $$$ERROR($$$GeneralError, pRoute _ ".read is not a registered tool")
    Quit ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 1000, .pResult, .pHttp, .tFault)
}

/// <p>The names and values of the stable meters (<parameter>STABLE</parameter>) of <var>pRow</var> (an object) or of <var>pValues</var> (the vendor's array) as one text, in a fixed order.</p>
ClassMethod StableText(pRow As %DynamicObject = "", ByRef pValues) As %String
{
    Set tText = ""
    For tI = 1:1:$Length(..#STABLE, ",") {
        Set tName = $Piece(..#STABLE, ",", tI)
        Set tText = tText _ tName _ "=" _ $Select($IsObject(pRow): pRow.%Get(tName), 1: $Get(pValues(tName))) _ ";"
    }
    Quit tText
}

/// <p>The rows of <var>pRows</var> as one text, <code>a|b|c</code> for each row's members <var>pFields</var>, rows joined by <code>;</code>, in the order they come.</p>
ClassMethod Canon(pRows, pFields As %String) As %String
{
    Set tText = ""
    If '$IsObject($Get(pRows)) Quit "no rows"
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tLine = ""
        For tI = 1:1:$Length(pFields, ",") {
            Set tLine = tLine _ $Select(tI = 1: "", 1: "|") _ tRow.%Get($Piece(pFields, ",", tI))
        }
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ tLine
    }
    Quit tText
}

}
