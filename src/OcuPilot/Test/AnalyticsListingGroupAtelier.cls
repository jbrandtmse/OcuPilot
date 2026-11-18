/// <p><class>OcuPilot.Port.AtelierPort</class> whose next compiles, armed through <method>Arm</method>, answer that the instance refused the class, so
/// <class>OcuPilot.Test.AnalyticsListingGroupWriteEdge</class> drives the listing group writes' undo in process: a compile it fails is reported as a compile that
/// found an error, and every other call, a later compile included, is the shipped port's. A failed compile compiles nothing, so the class holds the text the write
/// saved, as it would after a refusal that left it so.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AnalyticsListingGroupAtelier Extends OcuPilot.Port.AtelierPort
{

/// <p>Fail the next <var>pCount</var> compiles.</p>
ClassMethod Arm(pCount As %Integer = 1)
{
    Set ^||OcuPilotListingGroupAtelier = pCount
}

/// <p>Forget any armed failure.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotListingGroupAtelier
}

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pDocument As %DynamicObject) As %Status
{
    If (pType = ..#TYPECOMPILE) && (+$Get(^||OcuPilotListingGroupAtelier) > 0) {
        Set ^||OcuPilotListingGroupAtelier = ^||OcuPilotListingGroupAtelier - 1
        Set pResult = {"lines": ["armed failure of the compile"], "errors": true}
        Set pHttpStatus = 200
        Set pFault = ""
        Set pDocument = ""
        Quit $$$OK
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .pDocument)
}

}
