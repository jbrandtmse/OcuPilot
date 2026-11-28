/// <p>Test-only <class>OcuPilot.Api.Router</class> subclass, served by a web application a test creates, for <class>OcuPilot.Test.AnalyticsPmmlRunEdge</class>. It carries the PMML test's three routes, which
/// delegate to <class>OcuPilot.Area.Analytics.PmmlTest</class> as the product's do, and answers the process id of the web process that served each request in the <code>X-Pid</code> header.</p>
Class OcuPilot.Test.PmmlHoldRouter Extends OcuPilot.Api.Router
{

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/analytics/pmml/background/:id/cancel" Method="POST" Call="Cancel"/>
  <Route Url="/analytics/pmml/background/:id" Method="GET" Call="Poll"/>
  <Route Url="/analytics/pmml/background" Method="POST" Call="Start"/>
</Routes>
}

ClassMethod Start() As %Status
{
    Do %response.SetHeader("X-Pid", $Job)
    Quit ##class(OcuPilot.Area.Analytics.PmmlTest).HandleStart()
}

ClassMethod Poll(pId As %String) As %Status
{
    Do %response.SetHeader("X-Pid", $Job)
    Quit ##class(OcuPilot.Area.Analytics.PmmlTest).HandlePoll(pId)
}

ClassMethod Cancel(pId As %String) As %Status
{
    Do %response.SetHeader("X-Pid", $Job)
    Quit ##class(OcuPilot.Area.Analytics.PmmlTest).HandleCancel(pId)
}

}
