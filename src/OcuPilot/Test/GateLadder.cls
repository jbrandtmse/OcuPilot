/// <p>AC7's derivation half (AD-38): how <method>OcuPilot.Install.Installer.GateStatus</method>
/// -- the one decision <class>OcuPilot.Api.Router</class>'s traffic gate and the compose
/// health check both read -- is derived from the version stamp, rung by rung.
/// <class>OcuPilot.Test.Gate</class> forces the gate's answer through
/// <class>OcuPilot.Test.GateFixture</class>, so it pins the router's mapping from a status to
/// an envelope and never how the status comes out of a version row; until code review round
/// 3 the <code>failed</code> and <code>upgraderequired</code> rungs, and the fail-closed
/// answer for an absent or unreadable row, had no test at all (<method>Phase</method>'s
/// fail-closed test reads a method no production code calls).</p>
/// <p>Also pins AC4's fingerprint rule from the version row's side: the schema version and
/// the phase are part of <method>OcuPilot.Install.Installer.StateFingerprint</method>, and
/// <property>UpdatedAt</property> is not -- deterministically, where
/// <method>OcuPilot.Test.Installer.TestProductionInstallIsIdempotent</method> needs a pause
/// past a second boundary to see the latter.</p>
/// <p>Writes nothing: every row here is synthetic and never saved
/// (<class>OcuPilot.Test.GateLadderRow</class>), so no test touches the shared production
/// version row. Installs and uninstalls nothing.</p>
Class OcuPilot.Test.GateLadder Extends %UnitTest.TestCase
{

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.GateLadderRow).Disarm()
    Quit $$$OK
}

/// <p>Installed at the deployed schema version: the only row that serves.</p>
/// <p>Mutation (Rule 19): the fail-open default in <method>GateStatus</method> -- start from
/// <code>installed</code> at the deployed version instead of <code>installing</code> at 0 --
/// leaves this green and turns <method>TestAbsentRowRefusesAsInstalling</method> and
/// <method>TestUnreadableRowRefusesAsInstalling</method> red.</p>
Method TestInstalledAtTheDeployedVersionServes()
{
    Set tDeployed = ##class(OcuPilot.Install.Installer).DeployedSchemaVersion()
    Do ##class(OcuPilot.Test.GateLadderRow).ArmRow("installed", tDeployed)
    Do $$$AssertEquals(##class(OcuPilot.Test.GateLadderRow).GateStatus(), "installed", "a row installed at the deployed schema version serves")
}

/// <p>A <code>failed</code> row refuses as <code>failed</code>, whatever its schema version.</p>
/// <p>Mutation (Rule 19): delete the <code>failed</code> rung from <method>GateStatus</method>,
/// and a failed row reads <code>installing</code> -- red.</p>
Method TestFailedRowRefusesAsFailed()
{
    Set tDeployed = ##class(OcuPilot.Install.Installer).DeployedSchemaVersion()
    Do ##class(OcuPilot.Test.GateLadderRow).ArmRow("failed", tDeployed)
    Do $$$AssertEquals(##class(OcuPilot.Test.GateLadderRow).GateStatus(), "failed", "a failed row at the deployed version refuses as failed")
    Do ##class(OcuPilot.Test.GateLadderRow).ArmRow("failed", 0)
    Do $$$AssertEquals(##class(OcuPilot.Test.GateLadderRow).GateStatus(), "failed", "a failed first install (schema version 0) refuses as failed")
}

/// <p>A row installed below the deployed schema version refuses as
/// <code>upgraderequired</code> -- the state of every start after new code raises
/// <parameter>OcuPilot.Install.Installer.SCHEMAVERSION</parameter>, until install migrates.</p>
/// <p>Mutation (Rule 19): delete the <code>upgraderequired</code> rung from
/// <method>GateStatus</method>, and the row reads <code>installed</code> -- the gate would
/// serve new code against an unmigrated schema. Red.</p>
Method TestRowBehindTheDeployedVersionRefusesAsUpgradeRequired()
{
    Set tDeployed = ##class(OcuPilot.Install.Installer).DeployedSchemaVersion()
    Do ##class(OcuPilot.Test.GateLadderRow).ArmRow("installed", tDeployed - 1)
    Do $$$AssertEquals(##class(OcuPilot.Test.GateLadderRow).GateStatus(), "upgraderequired", "a row installed below the deployed schema version refuses as upgraderequired")
}

/// <p>A row installed ahead of the deployed schema version -- a refused downgrade -- never
/// serves. It reads <code>installing</code>, the code round 1 chose for it.</p>
Method TestRowAheadOfTheDeployedVersionNeverServes()
{
    Set tDeployed = ##class(OcuPilot.Install.Installer).DeployedSchemaVersion()
    Do ##class(OcuPilot.Test.GateLadderRow).ArmRow("installed", tDeployed + 1)
    Do $$$AssertEquals(##class(OcuPilot.Test.GateLadderRow).GateStatus(), "installing", "a row installed ahead of the deployed schema version never serves")
}

/// <p>A row whose phase is still <code>installing</code> refuses as <code>installing</code>.</p>
Method TestUnfinishedRowRefusesAsInstalling()
{
    Set tDeployed = ##class(OcuPilot.Install.Installer).DeployedSchemaVersion()
    Do ##class(OcuPilot.Test.GateLadderRow).ArmRow("installing", tDeployed)
    Do $$$AssertEquals(##class(OcuPilot.Test.GateLadderRow).GateStatus(), "installing", "an unfinished row refuses as installing")
}

/// <p>No row at all -- a genuinely first start -- refuses as <code>installing</code>, never
/// <code>installed</code> (the Design Notes' golden example, applied to the method that is
/// actually wired in).</p>
Method TestAbsentRowRefusesAsInstalling()
{
    Do ##class(OcuPilot.Test.GateLadderRow).ArmNoRow()
    Do $$$AssertEquals(##class(OcuPilot.Test.GateLadderRow).GateStatus(), "installing", "an absent version row refuses as installing")
}

/// <p>A failed read refuses as <code>installing</code>: a read failure is never read as
/// <code>installed</code> (the frozen matrix row "Version row unreadable").</p>
Method TestUnreadableRowRefusesAsInstalling()
{
    Do ##class(OcuPilot.Test.GateLadderRow).ArmReadError()
    Do $$$AssertEquals(##class(OcuPilot.Test.GateLadderRow).GateStatus(), "installing", "an unreadable version row refuses as installing")
}

/// <p>AC4: <method>OcuPilot.Install.Installer.StateFingerprint</method> changes when the
/// version row's phase or schema version changes, and does not change when only its
/// <property>UpdatedAt</property> does -- a record of when install last ran is not drift.
/// Reads the production profile's objects read-only; the version row is synthetic.</p>
/// <p>Mutations (Rule 19): drop the schema version and phase from the fingerprint, and the
/// two "differs" assertions go red; add <property>UpdatedAt</property> to it, and the
/// "unchanged" assertion goes red.</p>
Method TestFingerprintCarriesSchemaVersionAndPhaseButNotUpdatedAt()
{
    Set tDeployed = ##class(OcuPilot.Install.Installer).DeployedSchemaVersion()
    Do ##class(OcuPilot.Test.GateLadderRow).ArmRow("installed", tDeployed, "2026-01-01T00:00:00Z")
    Set tBase = ##class(OcuPilot.Test.GateLadderRow).StateFingerprint("")
    Do $$$AssertTrue($Extract(tBase, 1, 6) '= "ERROR:", "the fingerprint was computed: " _ tBase)

    Do ##class(OcuPilot.Test.GateLadderRow).ArmRow("installed", tDeployed, "2026-02-02T12:34:56Z")
    Do $$$AssertEquals(##class(OcuPilot.Test.GateLadderRow).StateFingerprint(""), tBase, "a row that differs only in UpdatedAt leaves the fingerprint unchanged")

    Do ##class(OcuPilot.Test.GateLadderRow).ArmRow("failed", tDeployed, "2026-01-01T00:00:00Z")
    Do $$$AssertNotEquals(##class(OcuPilot.Test.GateLadderRow).StateFingerprint(""), tBase, "a row whose phase differs changes the fingerprint")

    Do ##class(OcuPilot.Test.GateLadderRow).ArmRow("installed", tDeployed + 1, "2026-01-01T00:00:00Z")
    Do $$$AssertNotEquals(##class(OcuPilot.Test.GateLadderRow).StateFingerprint(""), tBase, "a row whose schema version differs changes the fingerprint")
}

}
