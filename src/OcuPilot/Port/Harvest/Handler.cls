/// <p>The base class every harvested handler body extends (AD-23). It carries the one member those
/// bodies call that the vendor's dispatch class supplied, <method>RenderResponseBody</method>, with
/// the same signature, and it extends <class>OcuPilot.Kernel.Utils</class> so a body's
/// <code>..SanitizeError(</code> and <code>..ReadRequestBody(</code> resolve while the body is in
/// <code>%SYS</code>, where no other OcuPilot class is visible.</p>
/// <p>A body is called only through <class>OcuPilot.Port.HarvestPort</class>.</p>
Class OcuPilot.Port.Harvest.Handler Extends OcuPilot.Kernel.Utils
{

/// <p>Record one render on the stub response <class>OcuPilot.Port.HarvestPort</class> installed.
/// Writes nothing. Only the first call's arguments are kept; the port decides what several calls
/// mean. Outside a port call (<code>%response</code> undefined, or not the port's stub) it records
/// nothing and returns an error status.</p>
ClassMethod RenderResponseBody(pStatus As %Status, pMsgPart As %DynamicArray, pResPart As %DynamicObject) As %Status
{
    If '$IsObject($Get(%response)) || '%response.%IsA("OcuPilot.Port.Harvest.Response") {
        Quit $$$ERROR($$$GeneralError, "RenderResponseBody was called outside a harvest port call")
    }
    Set %response.Renders = %response.Renders + 1
    If %response.Renders = 1 {
        Set %response.RenderStatus = $Get(pStatus, $$$OK)
        Set %response.MsgPart = $Get(pMsgPart)
        Set %response.ResPart = $Get(pResPart)
    }
    Quit $$$OK
}

}
