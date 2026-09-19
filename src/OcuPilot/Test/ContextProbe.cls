/// <p>Test-only <class>OcuPilot.Api.Context</class> subclass that exposes its private
/// <method>OcuPilot.Api.Context.Body</method> so the status projection can be asserted in process,
/// with no HTTP request and no principal to create.</p>
/// <p><b>It replaces nothing.</b> The body it answers is the shipped method's own -- the same
/// <method>OcuPilot.Port.ProviderPort.ResolveEndpoint</method> and
/// <method>OcuPilot.Kernel.Egress.LeavesInstance</method> calls a route makes -- so an assertion
/// over it is an assertion about what <code>GET /agent/context</code> projects. A private method is
/// reachable from a subclass and from nowhere else, which is why this class exists rather than a
/// caller.</p>
Class OcuPilot.Test.ContextProbe Extends OcuPilot.Api.Context
{

/// <p>The status body for <var>pUser</var>, through the shipped projection.</p>
ClassMethod StatusBody(pUser As %String, Output pBody As %DynamicObject) As %Status
{
    Quit ..Body(pUser, .pBody)
}

}
