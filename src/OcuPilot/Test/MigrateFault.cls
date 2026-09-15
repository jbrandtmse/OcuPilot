/// <p>Fault-injection subclass of <class>OcuPilot.Test.InstallerProbe</class> (so its
/// log capture is inherited for free) whose migration registry contains a step that
/// touches real data and a step that fails on demand -- the
/// <class>OcuPilot.Test.InstallerFault</class> pattern, applied to
/// <method>OcuPilot.Install.Installer.MigrationStep</method> instead of
/// <method>EnsureGrant</method>. Registers two steps above the deployed
/// <parameter>SCHEMAVERSION</parameter> (2 and 3), each doubling as both the
/// ordering/survival fixture and the failure-propagation fixture, toggled by
/// <method>SetShouldFail</method> so one class serves both without duplicating the
/// registry.</p>
Class OcuPilot.Test.MigrateFault Extends OcuPilot.Test.InstallerProbe
{

Parameter SCHEMAVERSION = 3;

/// <p>Toggle read by <method>MigrationStep</method>'s version-3 branch. Stored in a
/// process-private global rather than a property so it survives across the fresh
/// <code>##class(...)</code> dispatches <method>OcuPilot.Install.Installer.Install</method>
/// makes to itself -- an instance property would not, since <code>Install</code> is a
/// <code>ClassMethod</code> and never holds one.</p>
ClassMethod SetShouldFail(pShouldFail As %Boolean)
{
    Set ^||OcuPilotMigrateFaultShouldFail = pShouldFail
}

/// <p>Defaults to failing -- a fault-injection subclass that silently stopped failing
/// because a test forgot to arm it would be a worse failure mode than one that fails
/// until deliberately disarmed.</p>
ClassMethod ShouldFail() As %Boolean
{
    Quit +$Get(^||OcuPilotMigrateFaultShouldFail, 1)
}

/// <p>Toggle read by <method>CurrentVersionRow</method>. Default off, gated
/// independently of <method>ShouldFail</method>, so
/// <method>OcuPilot.Test.Version.TestUnreadableVersionRowResolvesToUnreadable</method>
/// can force a version-row read failure without disturbing this class's other,
/// migration-ordering uses.</p>
ClassMethod SetVersionReadShouldFail(pShouldFail As %Boolean)
{
    Set ^||OcuPilotMigrateFaultVersionReadFail = pShouldFail
}

/// <p>Forces the "read failed" branch on demand (default off) -- see
/// <method>SetVersionReadShouldFail</method>.</p>
ClassMethod CurrentVersionRow(pProfile As %String, Output pRow) As %Status
{
    If +$Get(^||OcuPilotMigrateFaultVersionReadFail, 0) {
        Set pRow = $$$NULLOREF
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.MigrateFault: induced version-row read failure")
    }
    Quit ##super(pProfile, .pRow)
}

/// <p>Toggle read by <method>GatewayResponseTimeout</method>. Default off -- see
/// <method>SetVersionReadShouldFail</method>'s identical shape.</p>
ClassMethod SetGatewayReadShouldFail(pShouldFail As %Boolean)
{
    Set ^||OcuPilotMigrateFaultGatewayFail = pShouldFail
}

/// <p>Forces "neither the registry nor a configuration file answers" on demand
/// (default off), for
/// <method>OcuPilot.Test.Version.TestGatewayTimeoutUnavailableIsReportedNotFatal</method>
/// -- without this, forcing that branch for real would need a genuinely Gateway-less
/// instance, which this one is not.</p>
ClassMethod GatewayResponseTimeout(Output pTimeout As %String, Output pSource As %String) As %Status
{
    Set pTimeout = ""
    Set pSource = ""
    If +$Get(^||OcuPilotMigrateFaultGatewayFail, 0) {
        Quit $$$OK
    }
    Quit ##super(.pTimeout, .pSource)
}

/// <p>Version 2: touches real data (a probe-profile write through the escalated frame),
/// proving the runner can carry a step that does more than bookkeeping. Version 3: fails
/// when <method>ShouldFail</method> is true, otherwise also touches data. Any other
/// version falls back to the real registry via <code>##super()</code>.</p>
ClassMethod MigrationStep(pTargetVersion As %Integer, pProfile As %String, ByRef pReports) As %Status
{
    If pTargetVersion = 2 {
        Quit ##class(OcuPilot.Kernel.State.Base).GuardedProbeSet("migrationStepV2", "ran-for-" _ pProfile)
    }
    If pTargetVersion = 3 {
        If ..ShouldFail() {
            Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.MigrateFault: induced migration failure at version 3")
        }
        Quit ##class(OcuPilot.Kernel.State.Base).GuardedProbeSet("migrationStepV3", "ran-for-" _ pProfile)
    }
    Quit ##super(pTargetVersion, pProfile, .pReports)
}

}
