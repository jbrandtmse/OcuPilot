/// <p>Harvested-body fixture for <class>OcuPilot.Test.HarvestCaptured</class> (Story 24.6): a handler whose body writes two lines
/// and renders an empty result, and whose <method>OnCaptured</method> does what <code>^||OcuPilotHarvestCaptured</code> names:
/// <code>take</code> adds the lines to the result, <code>error</code> answers an error status and <code>throw</code> raises.</p>
Class OcuPilot.Test.HarvestCapturedFixture Extends OcuPilot.Port.Harvest.Handler
{

/// <p>Write two lines, then render an empty result.</p>
ClassMethod Writes() As %Status
{
    W "first", !
    W "second"
    Do ..RenderResponseBody($$$OK, , {})
    Quit $$$OK
}

/// <p>Write one line, then render a failure.</p>
ClassMethod Fails() As %Status
{
    W "lost"
    Do ..RenderResponseBody($$$ERROR($$$GeneralError, "not found"))
    Quit $$$OK
}

ClassMethod OnCaptured(pLines As %DynamicArray, pResult As %DynamicObject) As %Status
{
    Set tMode = $Get(^||OcuPilotHarvestCaptured)
    Set ^||OcuPilotHarvestCaptured("calls") = $Get(^||OcuPilotHarvestCaptured("calls")) + 1
    If tMode = "error" Quit $$$ERROR($$$GeneralError, "the output could not be taken")
    If tMode = "throw" Throw ##class(%Exception.General).%New("raised", 5001, , "the output raised")
    If tMode = "take" {
        Do pResult.%Set("lines", pLines.%Size(), "number")
        Do pResult.%Set("text", pLines.%Get(0) _ "|" _ pLines.%Get(1), "string")
    }
    Quit $$$OK
}

}
