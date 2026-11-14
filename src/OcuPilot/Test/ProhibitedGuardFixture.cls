/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass whose port answers the application lists with
/// one web application using an armed resource, and answers that application's read, or the privileged routine
/// application list, as <method>Arm</method>'s mode says -- so the shipped <method>GuardsPrivilegedApplication</method>
/// runs against a lookup that fails. It is its own port and holds no assertions.</p>
Class OcuPilot.Test.ProhibitedGuardFixture Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod PortClass() As %String
{
    Quit $ClassName()
}

/// <p>Arm the list to name <var>pResource</var> as the resource of one application, and its read to answer
/// <var>pMode</var>: <code>getfails</code> an error, <code>getempty</code> a success carrying nothing,
/// <code>getthrows</code> an exception. <code>routinelistfails</code> instead answers the privileged routine
/// application list with an error and reads as <code>getfails</code> otherwise.</p>
ClassMethod Arm(pResource As %String, pMode As %String)
{
    Set ^||OcuPilotGuardFixture("resource") = pResource
    Set ^||OcuPilotGuardFixture("mode") = pMode
}

ClassMethod Disarm()
{
    Kill ^||OcuPilotGuardFixture
}

/// <p>The port's answer: a <code>LIST</code> names the armed resource for <code>WebApp.App</code> and nothing for any
/// other endpoint, except that <code>Security.PrivilegedRoutine</code> answers an error under
/// <code>routinelistfails</code>; every other call answers as the armed mode says.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 200
    Set pFault = ""
    If pType = "LIST" {
        If pEndpoint = "Security.PrivilegedRoutine" && ($Get(^||OcuPilotGuardFixture("mode")) = "routinelistfails") Quit $$$ERROR($$$GeneralError, "the list is refused")
        Set pResult = []
        If pEndpoint = "WebApp.App" Do pResult.%Push({"Name": "/csp/ocupilotprobeguardfixture", "Resource": ($Get(^||OcuPilotGuardFixture("resource")))})
        Quit $$$OK
    }
    If $Get(^||OcuPilotGuardFixture("mode")) = "getempty" Quit $$$OK
    If $Get(^||OcuPilotGuardFixture("mode")) = "getthrows" Throw ##class(%Exception.General).%New("the application read raised")
    Quit $$$ERROR($$$GeneralError, "the application read is refused")
}

}
