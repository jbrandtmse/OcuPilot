/// <p>Test-only subclass of <class>OcuPilot.Install.Smoke</class> whose screen reads answer what
/// <method>Arm</method> set, without issuing the request. <class>OcuPilot.Test.Smoke</class> uses it
/// to drive <method>OcuPilot.Install.Smoke.CheckAreaLists</method> through a 200 whose body is not a
/// one-row <code>rows</code> array. Every other request goes to the instance unchanged.</p>
Class OcuPilot.Test.SmokeListFault Extends OcuPilot.Install.Smoke
{

/// <p>Arm the screen-read answer for this process: <var>pStatus</var> and <var>pBody</var>.</p>
ClassMethod Arm(pStatus As %Integer, pBody As %String = "")
{
    Kill ^||OcuPilotSmokeList
    Set ^||OcuPilotSmokeList("status") = pStatus
    Set ^||OcuPilotSmokeList("body") = pBody
}

/// <p>Remove the armed answer.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotSmokeList
}

ClassMethod Request(pMethod As %String, pPath As %String, pAuthorization As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String) As %Status [ Private ]
{
    If $Data(^||OcuPilotSmokeList("status")) && (pPath [ "/screens/") {
        Set pStatus = ^||OcuPilotSmokeList("status")
        Set pText = ^||OcuPilotSmokeList("body")
        Quit $$$OK
    }
    Quit ##super(pMethod, pPath, pAuthorization, pBody, .pStatus, .pText)
}

}
