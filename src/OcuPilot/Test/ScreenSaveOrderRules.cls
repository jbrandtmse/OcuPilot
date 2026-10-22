/// <p>Test-only <class>OcuPilot.Area.Security.MftConnectionRules</class> subclass that records the two answers a Save
/// renders through its rules class: <code>violations</code> for the 422 envelope and <code>notfound</code> for a failed
/// read of the target, each as a step in the trace.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ScreenSaveOrderRules Extends OcuPilot.Area.Security.MftConnectionRules
{

ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("violations")
    Quit ##super(.pViolations)
}

ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("notfound")
    Quit ##super(pSC, pHttpStatus, pFault)
}

}
