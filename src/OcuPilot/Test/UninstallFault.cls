/// <p>DW-65 (rework iteration 6). Fault-injection subclass of
/// <class>OcuPilot.Test.InstallerProbe</class> (so its log capture is inherited for free)
/// whose <method>OcuPilot.Install.Installer.Uninstall</method> removes the demo fixtures
/// through <class>OcuPilot.Test.FixtureFault</class> instead of the base
/// <class>OcuPilot.Install.Fixture</class>. With <class>OcuPilot.Test.FixtureFault</class>'s
/// delete faults armed, a fixture delete fails for real inside the real, unmodified
/// <method>OcuPilot.Install.Fixture.Remove</method>, so the refusal
/// <method>OcuPilot.Install.Installer.Uninstall</method> makes afterwards -- it stops
/// before the protected database while any inventory row remains -- runs exactly as it
/// would in production. With the faults disarmed, removal behaves exactly like the base
/// class: <method>OcuPilot.Install.Fixture.Remove</method> deletes by the names the
/// inventory records and never reads <parameter>OcuPilot.Test.FixtureFault.APPPATH</parameter>.</p>
/// <p>Four more faults, each off by default: the read of the inventory after removal can be
/// made to fail, the inventory's privileged routine application can be reported absent, the
/// read of the web-application provenance record can be made to fail while that application
/// exists, and the read of the roles the web applications carry can be made to fail. So the
/// refusal on an unreadable inventory, the one exception to it (the protected state is already
/// gone) and the refusals on an unreadable record or unreadable roles can all be driven through
/// the real <method>OcuPilot.Install.Installer.Uninstall</method>. Reporting the application
/// absent also makes the record read answer an empty set, as it does for a profile whose
/// protected state is gone. Toggles live in process-private globals, as in
/// <class>OcuPilot.Test.FixtureFault</class>, because the real code path makes class-method
/// dispatches that never carry an instance.</p>
Class OcuPilot.Test.UninstallFault Extends OcuPilot.Test.InstallerProbe
{

/// <p>Arm or disarm the "inventory read after removal fails" fault.</p>
ClassMethod SetInventoryReadFails(pFails As %Boolean)
{
    Set ^||OcuPilotUninstallFaultRead = pFails
}

/// <p>Arm or disarm the "inventory's privileged routine application is absent" fault.</p>
ClassMethod SetInventoryAppAbsent(pAbsent As %Boolean)
{
    Set ^||OcuPilotUninstallFaultApp = pAbsent
}

/// <p>Arm or disarm the "provenance record cannot be read" fault.</p>
ClassMethod SetProvenanceReadFails(pFails As %Boolean)
{
    Set ^||OcuPilotUninstallFaultProvenance = pFails
}

/// <p>Arm or disarm the "the web applications' roles cannot be read" fault.</p>
ClassMethod SetRolesReadFails(pFails As %Boolean)
{
    Set ^||OcuPilotUninstallFaultRoles = pFails
}

/// <p>Disarm every fault this class owns. Called from every driving test's own cleanup
/// path, including its <code>Catch</code>.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotUninstallFaultRead, ^||OcuPilotUninstallFaultApp, ^||OcuPilotUninstallFaultProvenance, ^||OcuPilotUninstallFaultRoles
}

/// <p>Routes <method>OcuPilot.Install.Installer.Uninstall</method>'s fixture removal
/// through <class>OcuPilot.Test.FixtureFault</class>, whose <code>Delete*</code> seams fail
/// on demand (<method>OcuPilot.Test.FixtureFault.SetDeletesShouldFail</method>).</p>
ClassMethod RemoveDemoFixtures(pProfile As %String, ByRef pFixtureReports) As %Status [ Private ]
{
    Quit ##class(OcuPilot.Test.FixtureFault).Remove(pProfile, .pFixtureReports)
}

/// <p>Fails on demand (default off), leaving <var>pLeft</var> at <code>0</code> exactly
/// as <method>OcuPilot.Install.Fixture.Remaining</method> does on a failed read; otherwise
/// the real read.</p>
ClassMethod RemainingDemoFixtures(pProfile As %String, Output pLeft) As %Status [ Private ]
{
    If +$Get(^||OcuPilotUninstallFaultRead, 0) {
        Kill pLeft
        Set pLeft = 0
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UninstallFault: induced inventory read failure")
    }
    Quit ##super(pProfile, .pLeft)
}

/// <p>Reports every application absent on demand (default off), otherwise the real check.
/// <method>OcuPilot.Install.Installer.Uninstall</method> asks it for the inventory's own
/// application after a failed inventory read, and through the provenance read for the profile's
/// own.</p>
ClassMethod EscalationApplicationExists(pApplication As %String) As %Boolean
{
    If +$Get(^||OcuPilotUninstallFaultApp, 0) {
        Quit 0
    }
    Quit ##super(pApplication)
}

/// <p>Fails on demand (default off) while the profile's privileged routine application exists,
/// leaving <var>pRecorded</var> empty; otherwise the real read, which answers an empty set when
/// that application is absent.</p>
ClassMethod ReadApplicationProvenance(pProfile As %String, ByRef pNames, Output pRecorded, ByRef pReports) As %Status [ Private ]
{
    If +$Get(^||OcuPilotUninstallFaultProvenance, 0), '..IsEscalationInfrastructureAbsent(.pNames, .tScratch) {
        Kill pRecorded
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UninstallFault: induced provenance read failure")
    }
    Quit ##super(pProfile, .pNames, .pRecorded, .pReports)
}

/// <p>Fails on demand (default off); otherwise the real read.</p>
ClassMethod RolesInUse(ByRef pExcept, Output pRoles) As %Status [ Private ]
{
    If +$Get(^||OcuPilotUninstallFaultRoles, 0) {
        Kill pRoles
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UninstallFault: induced roles read failure")
    }
    Quit ##super(.pExcept, .pRoles)
}

}
