/// <p><class>OcuPilot.Port.AnalyticsPort</class> with its pair sets evaluated through
/// <class>OcuPilot.Test.ScreenGate</class>, whose held set a test declares, so <class>OcuPilot.Test.PortGate</class> drives the
/// port's refusal in a process holding <code>%All</code>. A test may also arm three answers through <method>Arm</method>:
/// <code>routines</code>, the resource that guards the routines database (an empty one is a database the instance cannot name);
/// <code>collect</code>, a vendor failure in place of the vendor reads (<code>protect</code>, <code>denied</code>,
/// <code>systemprotect</code>, <code>status</code> or <code>exception</code>); and <code>capture</code>, which keeps the logged fault text in
/// <code>^||OcuPilotAnalyticsSeam("log")</code> in place of the log. Nothing else differs from the shipped port, and an unarmed
/// seam is the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AnalyticsGateSeam Extends OcuPilot.Port.AnalyticsPort
{

/// <p>The text a failure armed through <code>collect</code> carries, which must never reach the wire.</p>
Parameter VENDORTEXT = "vendor text naming ^DeepSee.Hidden";

/// <p>The test gate, in place of the instance's own answer.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ScreenGate"
}

/// <p>Forget every armed answer.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotAnalyticsSeam
}

/// <p>Arm <var>pKey</var> with <var>pValue</var>.</p>
ClassMethod Arm(pKey As %String, pValue As %String = 1)
{
    Set ^||OcuPilotAnalyticsSeam(pKey) = pValue
}

/// <p>The armed routines resource, or the instance's own answer.</p>
ClassMethod RoutineResource(pNamespace As %String, Output pResource As %String) As %Boolean
{
    If $Data(^||OcuPilotAnalyticsSeam("routines")) {
        Set pResource = ^||OcuPilotAnalyticsSeam("routines")
        Quit (pResource '= "")
    }
    Quit ##super(pNamespace, .pResource)
}

/// <p>The armed vendor failure, or the shipped read.</p>
ClassMethod Collect(pNamespace As %String, pEndpoint As %String, pCriterion As %String, pMax As %Integer, Output pData, Output pVendorStatus As %Status, Output pCaught As %Exception.AbstractException) [ Private ]
{
    Set tMode = $Get(^||OcuPilotAnalyticsSeam("collect"))
    If tMode = "" {
        Do ##super(pNamespace, pEndpoint, pCriterion, pMax, .pData, .pVendorStatus, .pCaught)
        Quit
    }
    Kill pData
    Set pData = 0
    Set pVendorStatus = $$$OK
    Set pCaught = ""
    If tMode = "protect" {
        Set pVendorStatus = $$$ERROR($$$GeneralError, "<PROTECT> " _ ..#VENDORTEXT)
    } ElseIf tMode = "denied" {
        Set pVendorStatus = $System.Status.Error(..#CODEPRIVILEGE, ..#VENDORTEXT)
    } ElseIf tMode = "status" {
        Set pVendorStatus = $$$ERROR($$$GeneralError, ..#VENDORTEXT)
    } ElseIf tMode = "systemprotect" {
        Try {
            Throw ##class(%Exception.SystemException).%New("<PROTECT> " _ ..#VENDORTEXT, 940, "OcuPilot.Test.AnalyticsGateSeam", "")
        } Catch ex {
            Set pCaught = ex
        }
    } Else {
        Try {
            Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#VENDORTEXT))
        } Catch ex {
            Set pCaught = ex
        }
    }
}

/// <p>Keep the logged fault where a test reads it when <code>capture</code> is armed, else log as shipped.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    If '$Data(^||OcuPilotAnalyticsSeam("capture")) {
        Do ##super(pMessage, pStatus, pCode)
        Quit
    }
    Set ^||OcuPilotAnalyticsSeam("log") = $Get(^||OcuPilotAnalyticsSeam("log")) _ "[" _ pCode _ "] " _ pMessage _ ": " _ $System.Status.GetErrorText(pStatus) _ ";"
}

}
