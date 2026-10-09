/// <p>Test-only seam for <class>OcuPilot.Test.WebAppPctAccess</class>: <class>OcuPilot.Port.PctAccessPort</class> whose
/// vendor <code>DELETE</code> is counted and never sent, so a test can observe whether a delete reached the vendor without
/// deleting an instance-owned entry. Every other call is the port's own. Production never calls this class.</p>
Class OcuPilot.Test.PctAccessVendorFault Extends OcuPilot.Port.PctAccessPort
{

/// <p>The vendor call, as <method>OcuPilot.Port.PctAccessPort.Call</method>, except that a <code>DELETE</code> is counted
/// in <method>VendorDeletes</method> and answers 200 with no vendor call.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If (pEndpoint = ..#ENDPOINT) && (pType = "DELETE") {
        Set ^||OcuProbe1810VendorDeletes = $Get(^||OcuProbe1810VendorDeletes) + 1
        Set pResult = ""
        Set pHttpStatus = 200
        Set pFault = ""
        Quit $$$OK
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>How many <code>DELETE</code>s this process has asked the vendor for since <method>ResetVendorDeletes</method>.</p>
ClassMethod VendorDeletes() As %Integer
{
    Quit +$Get(^||OcuProbe1810VendorDeletes)
}

/// <p>Starts the count again at zero.</p>
ClassMethod ResetVendorDeletes()
{
    Kill ^||OcuProbe1810VendorDeletes
}

}
