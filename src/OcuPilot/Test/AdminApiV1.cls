/// <p>Fixture admin API at version 1, for
/// <method>OcuPilot.Port.AdminPort.HighestDispatchVersion</method>. It carries nothing but a
/// <code>UrlMap</code> shaped like the vendor's, so the real derivation runs against real
/// XData and the instance's own admin API is never touched.</p>
/// <p>The forward names a <code>Dispatch.v1</code> class that does not exist, deliberately:
/// the derivation reads the route table's text and never resolves the target.</p>
Class OcuPilot.Test.AdminApiV1 Extends %RegisteredObject
{

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/info" Method="GET" Call="Info"/>
<Map Prefix="/v1" Forward="OcuPilot.Test.AdminApiV1.Dispatch.v1"/>
</Routes>
}

}
