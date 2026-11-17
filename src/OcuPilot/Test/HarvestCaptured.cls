/// <p>Pins what <class>OcuPilot.Port.HarvestPort</class> does with a body's device output (Story 24.6, AD-39's eighth exception):
/// it is discarded unless the handler takes it through <method>OcuPilot.Port.Harvest.Handler.OnCaptured</method>, which is called
/// after an OK render with the output's lines and the render's result, and an error or an exception from it is 500
/// <code>INTERNAL</code>, logged once. A failed render never calls it. Uses <class>OcuPilot.Test.HarvestCapturedFixture</class>
/// and <class>OcuPilot.Test.HarvestPortFixture</class>, and needs the install namespace and nothing else.</p>
Class OcuPilot.Test.HarvestCaptured Extends %UnitTest.TestCase
{

Parameter HANDLER = "OcuPilot.Test.HarvestCapturedFixture";

Parameter PORT = "OcuPilot.Test.HarvestPortFixture";

Method OnBeforeOneTest() As %Status
{
    Kill ^||OcuPilotHarvestCaptured
    Do $ClassMethod(..#PORT, "Clear")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotHarvestCaptured
    Do $ClassMethod(..#PORT, "Clear")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $$$OK
}

/// <p>Invoke <var>pMethod</var> of the fixture handler through the port.</p>
Method Drive(pMethod As %String, Output pResult, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    Quit $ClassMethod(..#PORT, "Invoke", ..#HANDLER, pMethod, $ListBuild($ListBuild("%Development", "USE")), .tQuery, "", .pResult, .pHttp, .pFault)
}

/// <p>A handler that takes the output gets the lines in order and the render's own result; one that does not leaves the result as
/// rendered.</p>
/// <p>Mutation (Rule 19): drop the <code>OnCaptured</code> call from <method>OcuPilot.Port.HarvestPort.Invoke</method> -- this
/// goes red.</p>
Method TestAHandlerThatTakesTheOutputGetsItsLines()
{
    Set ^||OcuPilotHarvestCaptured = "take"
    Do $$$AssertStatusOK(..Drive("Writes", .tResult, .tHttp, .tFault), "the body answers")
    Do $$$AssertEquals(tHttp _ "|" _ tResult.lines _ "|" _ tResult.text, "200|2|first|second", "its two lines reach the handler, and its additions the answer")
    Kill ^||OcuPilotHarvestCaptured
    Set ^||OcuPilotHarvestCaptured = "ignore"
    Do $$$AssertStatusOK(..Drive("Writes", .tResult2, .tHttp2, .tFault2), "a handler that ignores the output answers")
    Do $$$AssertEquals(tHttp2 _ "|" _ tResult2.%ToJSON(), "200|{}", "and the result is as rendered")
}

/// <p>An error status or an exception from the hook is 500 <code>INTERNAL</code>, logged once, with no result; a failed render
/// never reaches it.</p>
/// <p>Mutation (Rule 19): ignore the hook's status in <method>OcuPilot.Port.HarvestPort.Invoke</method> -- the error leg goes
/// red.</p>
Method TestAnErrorFromTheHookIsInternalAndLogged()
{
    For tMode = "error", "throw" {
        Do $ClassMethod(..#PORT, "Clear")
        Set ^||OcuPilotHarvestCaptured = tMode
        Do $$$AssertStatusNotOK(..Drive("Writes", .tResult, .tHttp, .tFault), tMode _ ": the body is refused")
        Do $$$AssertEquals(tHttp _ "|" _ tFault.code _ "|" _ ($Get(tResult) = "") _ "|" _ $ClassMethod(..#PORT, "LogCount"), "500|INTERNAL|1|1", tMode _ ": internal, with no result, logged once")
    }
    Kill ^||OcuPilotHarvestCaptured
    Set ^||OcuPilotHarvestCaptured = "take"
    Do $$$AssertStatusNotOK(..Drive("Fails", .tResult2, .tHttp2, .tFault2), "a failed render is refused as it was")
    Do $$$AssertTrue(tHttp2 '= 200, "the render's own fault answers: " _ tHttp2)
    Do $$$AssertEquals(+$Get(^||OcuPilotHarvestCaptured("calls")), 0, "and the hook is not called for it")
}

}
