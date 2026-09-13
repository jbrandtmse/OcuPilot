/// <p>Test-only subclass of <class>OcuPilot.Test.InstallerProbe</class> whose roster reads
/// (<method>OcuPilot.Install.Installer.RosterApplication</method> and
/// <method>OcuPilot.Install.Installer.RosterAssertedProperties</method>) hand
/// <method>OcuPilot.Install.Installer.RosterNames</method> a declaration the shipped roster never
/// carries: a relative path, no <code>matchRole</code>, or an empty asserted set. Every other
/// value is the real roster's, copied so nothing armed here reaches the roster itself.</p>
/// <p>The armed fault lives in a process-private global. <method>NamesFor</method> drives the
/// real private <method>OcuPilot.Install.Installer.Names</method> through <code>..</code>
/// dispatch, so the refusal under test is the shipped code.</p>
Class OcuPilot.Test.RosterFault Extends OcuPilot.Test.InstallerProbe
{

/// <p>Arm <var>pFault</var>: <code>relative</code>, <code>nomatchrole</code> or
/// <code>noasserted</code>.</p>
ClassMethod Arm(pFault As %String)
{
    Set ^||OcuPilotRosterFault = pFault
}

/// <p>Back to the real roster.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotRosterFault
}

/// <p>Resolve <var>pProfile</var>'s names through the real <method>Names</method>.</p>
ClassMethod NamesFor(pProfile As %String, Output pNames) As %Status
{
    Quit ..Names(pProfile, .pNames)
}

ClassMethod RosterApplication(pKey As %String, Output pApplication As %DynamicObject) As %Status
{
    Set tSC = ##super(pKey, .tApp)
    Set pApplication = ""
    If $$$ISERR(tSC) Quit tSC
    Set pApplication = ##class(%DynamicObject).%FromJSON(tApp.%ToJSON())
    Set tFault = $Get(^||OcuPilotRosterFault)
    If tFault = "relative" Set pApplication.path = $Extract(pApplication.path, 2, *)
    If tFault = "nomatchrole" Do pApplication.%Remove("matchRole")
    Quit $$$OK
}

ClassMethod RosterAssertedProperties(pKey As %String) As %String
{
    If $Get(^||OcuPilotRosterFault) = "noasserted" Quit ""
    Quit ##super(pKey)
}

}
