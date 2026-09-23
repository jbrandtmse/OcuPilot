/// <p>Test-only <class>OcuPilot.Port.AdminPort</class> subclass with one replaced seam:
/// <method>RunSequence</method> answers a <code>DELETE</code> 200 without running the vendor, the
/// answer <code>Security.Role</code>'s <code>RunDelete</code> gives when its drop did nothing. Every
/// other request type -- the verifying re-read among them -- runs the shipped sequence against the
/// instance, so the port's own verification is what is measured.</p>
/// <p><b>Nothing this class reaches writes to the instance.</b> The delete never runs.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RoleDeletePort Extends OcuPilot.Port.AdminPort
{

ClassMethod RunSequence(pEndpoint As %String, pClass As %String, pType As %Integer, ByRef pQuery, pBody As %DynamicAbstractObject, Output pAnswer, Output pHttpStatus As %Integer, Output pLocation As %String, pMethod As %String = "GET") As %Status [ Private ]
{
    If pMethod = "DELETE" {
        Set pAnswer = {}
        Set pHttpStatus = 200
        Set pLocation = ""
        Quit $$$OK
    }
    Quit ##super(pEndpoint, pClass, pType, .pQuery, pBody, .pAnswer, .pHttpStatus, .pLocation, pMethod)
}

}
