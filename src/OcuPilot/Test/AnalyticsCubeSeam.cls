/// <p><class>OcuPilot.Port.AnalyticsPort</class> with the vendor's build and synchronize answered by a status a test arms, so
/// <class>OcuPilot.Test.AnalyticsCubeManager</class> drives the port's mapping of each answer in process without changing a cube. The state
/// is read from the instance as shipped; only <method>VendorBuild</method>, <method>VendorSynchronize</method> and <method>LogFault</method>
/// differ, and an unarmed seam answers OK with no statistics.</p>
/// <p><method>Arm</method> names the answer: <code>ok</code>, <code>errors</code> (the build's #20006 with two failed rows),
/// <code>lock</code> (#20005), <code>absent</code> (#20013), <code>protect</code> (<code>&lt;PROTECT&gt;</code>), <code>other</code> (an
/// error whose text is <parameter>VENDORTEXT</parameter>) or <code>exception</code>. <method>Calls</method> counts the vendor calls made,
/// and the logged fault text is kept where <method>Logged</method> reads it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AnalyticsCubeSeam Extends OcuPilot.Port.AnalyticsPort
{

/// <p>The text of the error armed as <code>other</code>, which must reach the log and never the wire.</p>
Parameter VENDORTEXT = "vendor text naming ^DeepSee.Hidden";

/// <p>Forget every armed answer, the call count and the logged text.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotCubeSeam
}

/// <p>Arm the answer <var>pMode</var> for the build and the synchronize.</p>
ClassMethod Arm(pMode As %String)
{
    Set ^||OcuPilotCubeSeam("mode") = pMode
}

/// <p>How many vendor calls were made since <method>Reset</method>.</p>
ClassMethod Calls() As %Integer
{
    Quit +$Get(^||OcuPilotCubeSeam("calls"))
}

/// <p>The fault text logged since <method>Reset</method>.</p>
ClassMethod Logged() As %String
{
    Quit $Get(^||OcuPilotCubeSeam("log"))
}

/// <p>The armed answer, as a status, with the statistics or counts the vendor would have given in <var>pStats</var> and
/// <var>pCaught</var> set for <code>exception</code>.</p>
ClassMethod Answer(pCube As %String, pBuild As %Boolean, Output pStats, Output pCaught As %Exception.AbstractException) As %Status [ Private ]
{
    Kill pStats
    Set pCaught = ""
    Set ^||OcuPilotCubeSeam("calls") = $Get(^||OcuPilotCubeSeam("calls")) + 1
    Set tMode = $Get(^||OcuPilotCubeSeam("mode"), "ok")
    Set tIndex = $ZConvert(pCube, "U")
    If pBuild {
        Set pStats("cubes", tIndex, "factCount") = 7
        Set pStats("cubes", tIndex, "errors") = $Select(tMode = "errors": 2, 1: 0)
    } Else {
        Set pStats = 3
        Set pStats(tIndex) = 3
    }
    If tMode = "ok" Quit $$$OK
    If tMode = "errors" Quit $System.Status.Error(..#CODEBUILDERRORS, "the build had errors")
    If tMode = "lock" Quit $System.Status.Error(..#CODELOCK, "the cube is locked")
    If tMode = "absent" Quit $System.Status.Error(..#CODENOCUBE, "no such cube")
    If tMode = "errorsplus" Quit $System.Status.AppendStatus($System.Status.Error(..#CODEBUILDERRORS, "the build had errors"), $$$ERROR($$$GeneralError, ..#VENDORTEXT))
    If tMode = "privilege" Quit $System.Status.Error(..#CODEPRIVILEGE)
    If tMode = "protect" Quit $$$ERROR($$$GeneralError, "<PROTECT> " _ ..#VENDORTEXT)
    If tMode = "exception" {
        Try {
            Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, ..#VENDORTEXT))
        } Catch ex {
            Set pCaught = ex
        }
        Quit $$$OK
    }
    Quit $$$ERROR($$$GeneralError, ..#VENDORTEXT)
}

/// <p>The armed answer in place of the vendor's build.</p>
ClassMethod VendorBuild(pNamespace As %String, pCube As %String, Output pStats, Output pCaught As %Exception.AbstractException, Output pWritten As %String) As %Status
{
    Set pWritten = ""
    Quit ..Answer(pCube, 1, .pStats, .pCaught)
}

/// <p>The armed answer in place of the vendor's synchronize.</p>
ClassMethod VendorSynchronize(pNamespace As %String, pCube As %String, Output pFacts, Output pCaught As %Exception.AbstractException, Output pWritten As %String) As %Status
{
    Set pWritten = ""
    Quit ..Answer(pCube, 0, .pFacts, .pCaught)
}

/// <p>Keep the logged fault text where a test reads it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Set ^||OcuPilotCubeSeam("log") = $Get(^||OcuPilotCubeSeam("log")) _ "[" _ pCode _ "] " _ pMessage _ ": " _ $System.Status.GetErrorText(pStatus) _ ";"
}

}
