/// <p>Fixture admin API at version 3, carrying three forwards so
/// <method>OcuPilot.Port.AdminPort.HighestDispatchVersion</method> is pinned on taking the
/// <b>highest</b> rather than the first or the last. See
/// <class>OcuPilot.Test.AdminApiV1</class> for why the targets need not exist.</p>
Class OcuPilot.Test.AdminApiV3 Extends %RegisteredObject
{

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/info" Method="GET" Call="Info"/>
<Map Prefix="/v1" Forward="OcuPilot.Test.AdminApiV3.Dispatch.v1"/>
<Map Prefix="/v3" Forward="OcuPilot.Test.AdminApiV3.Dispatch.v3"/>
<Map Prefix="/v2" Forward="OcuPilot.Test.AdminApiV3.Dispatch.v2"/>
</Routes>
}

}
