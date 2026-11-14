/// <p>The route side of <class>OcuPilot.Test.Harvest</class>: a handler that reads the query
/// parameter <code>case</code>, invokes that method of <class>OcuPilot.Test.HarvestFixture</class>
/// through <class>OcuPilot.Test.HarvestPortFixture</class>, and writes the answer through the one
/// response and error writers, as a route does. It is driven through
/// <method>OcuPilot.Test.Dispatch.InvokeHandler</method>, so the body that comes back is the raw,
/// unparsed one.</p>
Class OcuPilot.Test.HarvestRouteFixture Extends %RegisteredObject
{

ClassMethod Handle() As %Status
{
    Set tCase = %request.Get("case")
    Set tPairs = $ListBuild($ListBuild("%Development", "USE"))
    Set tSC = ##class(OcuPilot.Test.HarvestPortFixture).Invoke("OcuPilot.Test.HarvestFixture", tCase, tPairs, , "", .tResult, .tHttp, .tFault)
    If $IsObject(tFault) {
        Quit ##class(OcuPilot.Api.Error).Render($Select(+tHttp: +tHttp, 1: 500), tFault.%Get("error"), tFault.%Get("reason"), tFault.%Get("code"), tFault.%Get("detail"))
    }
    Quit ##class(OcuPilot.Api.Response).JSONStatus(tHttp, tResult)
}

}
