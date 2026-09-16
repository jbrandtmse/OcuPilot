/// <p>Fixture admin API whose <code>UrlMap</code> exists and forwards to no
/// <code>Dispatch.v&lt;N&gt;</code> <b>of its own</b> -- the I/O matrix's second "admin API absent"
/// shape, distinct from a class that does not exist. The forward below points at another
/// class on purpose: the derivation must ignore a forward that is not the routing class's
/// own.</p>
Class OcuPilot.Test.AdminApiFlat Extends %RegisteredObject
{

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/info" Method="GET" Call="Info"/>
<Map Prefix="/v1" Forward="OcuPilot.Test.AdminApiV1.Dispatch.v1"/>
</Routes>
}

}
