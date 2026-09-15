/// <p>Test-only subclass of <class>OcuPilot.Install.Smoke</class> whose <code>POST /refresh</code>
/// answers what <method>Arm</method> set, without issuing the request, and which counts every
/// <code>POST /logout</code> the run makes. <class>OcuPilot.Test.Smoke</class> uses it to drive
/// <method>OcuPilot.Install.Smoke.CheckSignOut</method> through refresh answers a live instance
/// never gives after a sign-out. Every other request goes to the instance unchanged.</p>
Class OcuPilot.Test.SmokeRefreshFault Extends OcuPilot.Install.Smoke
{

/// <p>Arm the refresh answer for this process: <var>pStatus</var> and <var>pBody</var>.</p>
ClassMethod Arm(pStatus As %Integer, pBody As %String = "")
{
    Kill ^||OcuPilotSmokeRefresh
    Set ^||OcuPilotSmokeRefresh("status") = pStatus
    Set ^||OcuPilotSmokeRefresh("body") = pBody
    Set ^||OcuPilotSmokeRefresh("logouts") = 0
}

/// <p>Remove the armed answer and the logout count.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotSmokeRefresh
}

/// <p>The number of <code>POST /logout</code> requests issued since <method>Arm</method>.</p>
ClassMethod Logouts() As %Integer
{
    Quit +$Get(^||OcuPilotSmokeRefresh("logouts"))
}

ClassMethod Request(pMethod As %String, pPath As %String, pAuthorization As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String) As %Status [ Private ]
{
    If $Data(^||OcuPilotSmokeRefresh("status")) && ($Extract(pPath, *-7, *) = "/refresh") {
        Set pStatus = ^||OcuPilotSmokeRefresh("status")
        Set pText = ^||OcuPilotSmokeRefresh("body")
        Quit $$$OK
    }
    If $Extract(pPath, *-6, *) = "/logout" Set ^||OcuPilotSmokeRefresh("logouts") = $Get(^||OcuPilotSmokeRefresh("logouts")) + 1
    Quit ##super(pMethod, pPath, pAuthorization, pBody, .pStatus, .pText)
}

}
