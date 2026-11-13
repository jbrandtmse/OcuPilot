/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass whose port answers the application lists with
/// one web application using an armed resource, and answers that application's read as an error or as nothing -- so the
/// shipped <method>GuardsPrivilegedApplication</method> runs against a read that fails. It is its own port and holds no
/// assertions.</p>
Class OcuPilot.Test.ProhibitedGuardFixture Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod PortClass() As %String
{
    Quit $ClassName()
}

/// <p>Arm the list to name <var>pResource</var> as the resource of one application, and its read to answer
/// <var>pMode</var>: <code>getfails</code> an error, <code>getempty</code> a success carrying nothing.</p>
ClassMethod Arm(pResource As %String, pMode As %String)
{
    Set ^||OcuPilotGuardFixture("resource") = pResource
    Set ^||OcuPilotGuardFixture("mode") = pMode
}

ClassMethod Disarm()
{
    Kill ^||OcuPilotGuardFixture
}

/// <p>The port's answer: every <code>LIST</code> succeeds, naming the armed resource for <code>WebApp.App</code> and
/// nothing for any other endpoint; every other call answers as the armed mode says.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 200
    Set pFault = ""
    If pType = "LIST" {
        Set pResult = []
        If pEndpoint = "WebApp.App" Do pResult.%Push({"Name": "/csp/ocupilotprobeguardfixture", "Resource": ($Get(^||OcuPilotGuardFixture("resource")))})
        Quit $$$OK
    }
    If $Get(^||OcuPilotGuardFixture("mode")) = "getempty" Quit $$$OK
    Quit $$$ERROR($$$GeneralError, "the application read is refused")
}

}
