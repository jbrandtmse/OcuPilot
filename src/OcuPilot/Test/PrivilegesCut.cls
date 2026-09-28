/// <p>Fixture: the shipped <code>GET /permissions/check</code> handler over
/// <class>OcuPilot.Test.PermissionCheckCut</class>, whose composition read is cut at its cap, so
/// <class>OcuPilot.Test.PermissionCheck</class> can pin the route's 503 envelope in process.</p>
/// <p>Driven through <method>OcuPilot.Test.Dispatch.InvokeHandler</method>: the router's
/// <code>UrlMap</code> names <class>OcuPilot.Api.Privileges</class> by class, so a subclass has no
/// route of its own to arrive on.</p>
Class OcuPilot.Test.PrivilegesCut Extends OcuPilot.Api.Privileges
{

ClassMethod CheckClass() As %String
{
    Quit "OcuPilot.Test.PermissionCheckCut"
}

}
