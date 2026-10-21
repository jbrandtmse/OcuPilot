/// <p>Test-only <class>OcuPilot.Port.AdminPort</class> subclass that overrides nothing: it exposes
/// the port's two private request-type decisions, <method>MethodFor</method> and
/// <method>TypeFor</method>, to <class>OcuPilot.Test.AdminPortMutatingPath</class>. It inherits
/// <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> as the shipped class compiles it, so
/// a change to that list is seen here once this class is recompiled.</p>
/// <p><b>Nothing this class reaches writes to the instance.</b></p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AdminPortTypeSeam Extends OcuPilot.Port.AdminPort
{

/// <p>The HTTP method the request stub carries for <var>pEndpoint</var>'s request type
/// <var>pSuffix</var>: <method>OcuPilot.Port.AdminPort.HttpMethodFor</method>'s answer.</p>
ClassMethod MethodFor(pEndpoint As %String, pSuffix As %String) As %String
{
    Quit ..HttpMethodFor(pEndpoint, pSuffix)
}

/// <p>The vendor type number for <var>pSuffix</var> on <var>pEndpoint</var>'s class:
/// <method>OcuPilot.Port.AdminPort.EndpointType</method>'s answer for the class
/// <method>OcuPilot.Port.AdminPort.EndpointClass</method> resolves.</p>
ClassMethod TypeFor(pEndpoint As %String, pSuffix As %String) As %String
{
    Quit ..EndpointType(pEndpoint, ..EndpointClass(pEndpoint), pSuffix)
}

}
