/// <p>Test-only <class>OcuPilot.Api.Router</class> subclass, served by a web application a test creates, for <class>OcuPilot.Test.AnalyticsPmmlRunEdge</class>. It carries the PMML test's three routes, which
/// delegate to <class>OcuPilot.Area.Analytics.PmmlTest</class> as the product's do, and answers the process id of the web process that served each request in the <code>X-Pid</code> header. Its other two
/// routes let a test choose which web process serves a later request: <code>/who</code> answers the serving process, and <code>/hold</code> keeps the process <code>pid</code> busy for up to <code>s</code> seconds
/// (any process when <code>pid</code> is empty), recording it in <code>^IRIS.Temp.OcuPilotPmmlHold(pid)</code> while it holds, so that a request sent meanwhile is served by another process.</p>
Class OcuPilot.Test.PmmlHoldRouter Extends OcuPilot.Api.Router
{

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/who" Method="GET" Call="Who"/>
  <Route Url="/hold" Method="GET" Call="Hold"/>
  <Route Url="/analytics/pmml/background/:id/cancel" Method="POST" Call="Cancel"/>
  <Route Url="/analytics/pmml/background/:id" Method="GET" Call="Poll"/>
  <Route Url="/analytics/pmml/background" Method="POST" Call="Start"/>
</Routes>
}

/// <p>The serving process id, in the <code>X-Pid</code> header and the body.</p>
ClassMethod Who() As %Status
{
    Do %response.SetHeader("X-Pid", $Job)
    Quit ##class(OcuPilot.Api.Response).JSON({"pid": ($Job)})
}

/// <p>Hold this process for at most the <code>s</code> seconds the request names, when it is the process <code>pid</code> names or that is empty, or until
/// <code>^IRIS.Temp.OcuPilotPmmlHoldRelease($Job)</code> is set; the body tells whether it held.</p>
ClassMethod Hold() As %Status
{
    Do %response.SetHeader("X-Pid", $Job)
    Set tPid = %request.Get("pid", "")
    Set tHeld = 0
    If (tPid = "") || (tPid = $Job) {
        Set ^IRIS.Temp.OcuPilotPmmlHold($Job) = $ZHorolog
        Set tHeld = 1
        Set tEnd = $ZHorolog + %request.Get("s", 2)
        While ($ZHorolog < tEnd) && '$Data(^IRIS.Temp.OcuPilotPmmlHoldRelease($Job)) {
            Hang 0.02
        }
        Kill ^IRIS.Temp.OcuPilotPmmlHold($Job), ^IRIS.Temp.OcuPilotPmmlHoldRelease($Job)
    }
    Quit ##class(OcuPilot.Api.Response).JSON({"pid": ($Job), "held": (tHeld)})
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
