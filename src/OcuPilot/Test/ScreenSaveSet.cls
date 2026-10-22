/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass that answers AD-10's question from a switch
/// and records it: <method>Prohibits</method> is a <code>prohibited</code> step in the trace, keeps what it was asked
/// (<method>OcuPilot.Test.ScreenSaveTrace.AskedOf</method>), and refuses with the code armed as <code>prohibit</code>, or
/// permits when none is.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ScreenSaveSet Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod Prohibits(pToolName As %String, pTargetRef As %String, pPayload As %String, pDiff As %String, Output pProhibits As %Boolean, Output pCode As %String) As %Status
{
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Mark("prohibited")
    Do ##class(OcuPilot.Test.ScreenSaveTrace).Asked(pToolName, pTargetRef, pPayload, pDiff)
    Set pProhibits = 0
    Set pCode = ""
    Set tCode = ##class(OcuPilot.Test.ScreenSaveTrace).Armed("prohibit")
    If tCode '= "" {
        Set pProhibits = 1
        Set pCode = tCode
    }
    Quit $$$OK
}

}
