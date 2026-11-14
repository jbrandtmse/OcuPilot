/// <p>The wire side of <class>OcuPilot.Test.HarvestWire</class>: a REST dispatch class a throwaway web
/// application serves, whose one route reads the query parameter <code>case</code> (and <code>k</code>,
/// and a JSON body on a POST), invokes that method of <class>OcuPilot.Test.HarvestFixture</class>
/// through <class>OcuPilot.Test.HarvestPortFixture</class> in a real CSP job, and writes the answer
/// through the one response and error writers. The response header <code>X-Harvest-Namespace</code>
/// carries <code>$NAMESPACE</code> as the route saw it once the port had returned.</p>
Class OcuPilot.Test.HarvestWireFixture Extends %CSP.REST
{

Parameter UseSession = 0;

Parameter CONTENTTYPE = "application/json";

Parameter HandleCorsRequest = 0;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/run" Method="GET" Call="Run" />
  <Route Url="/run" Method="POST" Call="Run" />
</Routes>
}

ClassMethod Run() As %Status
{
    Set tCase = %request.Get("case")
    Set tPairs = $ListBuild($ListBuild("%Development", "USE"))
    If %request.Get("k") '= "" Set tQuery("k") = %request.Get("k")
    Set tBody = ""
    If %request.Method = "POST" Do ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody)
    Set tSC = ##class(OcuPilot.Test.HarvestPortFixture).Invoke("OcuPilot.Test.HarvestFixture", tCase, tPairs, .tQuery, tBody, .tResult, .tHttp, .tFault)
    Do %response.SetHeader("X-Harvest-Namespace", $NAMESPACE)
    If $IsObject(tFault) {
        Quit ##class(OcuPilot.Api.Error).Render($Select(+tHttp: +tHttp, 1: 500), tFault.%Get("error"), tFault.%Get("reason"), tFault.%Get("code"), tFault.%Get("detail"))
    }
    Quit ##class(OcuPilot.Api.Response).JSONStatus(tHttp, tResult)
}

}
