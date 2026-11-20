/// <p>Test-only fixture for Story 24.14 Batch 2's run suites: <class>OcuPilot.Port.AnalyticsPort</class> with two seams a test arms through <method>Arm</method>, so that
/// <method>OcuPilot.Port.AnalyticsPort.PmmlRun</method> can be ended every way without a slow source: <code>stop</code>, whose stop hook (<method>StopRequested</method>, this class being its own stop
/// class) answers no on its first ask and yes on every later one, so the owner's cancel lands once the vendor has returned; and <code>fault</code>, which makes the read of the answer raise. Unarmed,
/// it is the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.PmmlRunSeam Extends OcuPilot.Port.AnalyticsPort
{

/// <p>Forget every armed seam.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotPmmlRunSeam
}

/// <p>Arm <var>pKey</var>, <code>stop</code> or <code>fault</code>.</p>
ClassMethod Arm(pKey As %String)
{
    Set ^||OcuPilotPmmlRunSeam(pKey) = 1
}

/// <p>The stop hook: when <code>stop</code> is armed, no on the first ask and yes after it.</p>
ClassMethod StopRequested(pKey As %String) As %Boolean
{
    If '$Data(^||OcuPilotPmmlRunSeam("stop")) Quit 0
    Set ^||OcuPilotPmmlRunSeam("asked") = $Get(^||OcuPilotPmmlRunSeam("asked")) + 1
    Quit ^||OcuPilotPmmlRunSeam("asked") > 1
}

/// <p>The shipped answer, or an exception when <code>fault</code> is armed.</p>
ClassMethod PmmlAnswer(pTestId As %Integer, pMode As %String) As %DynamicObject
{
    If $Data(^||OcuPilotPmmlRunSeam("fault")) Throw ##class(%Exception.General).%New("PmmlAnswer", 5001, , "the armed fault")
    Quit ##super(pTestId, pMode)
}

}
