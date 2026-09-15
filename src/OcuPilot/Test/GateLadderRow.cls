/// <p>Test-only subclass of <class>OcuPilot.Install.Installer</class> whose version-row read
/// (<method>OcuPilot.Install.Installer.CurrentVersionRow</method>) returns a synthetic,
/// never-saved <class>OcuPilot.Kernel.State.Version</class> object, no row, a failed
/// read, or a read that throws -- whichever a test arms. <class>OcuPilot.Test.GateLadder</class> uses it to drive
/// the real, unmodified <method>OcuPilot.Install.Installer.GateStatus</method> ladder and
/// <method>OcuPilot.Install.Installer.StateFingerprint</method> through every version-row
/// state without writing anything to the shared protected database (code review round 3).</p>
/// <p>The armed state lives in a process-private global, as in
/// <class>OcuPilot.Test.MigrateFault</class>, because the real code path makes class-method
/// dispatches that never carry an instance. Unarmed, the read fails rather than falling
/// through to the real production row, so a test that forgot to arm this class goes red
/// instead of silently asserting against shared state.</p>
Class OcuPilot.Test.GateLadderRow Extends OcuPilot.Install.Installer
{

/// <p>Serve a synthetic row carrying <var>pPhase</var>, <var>pSchemaVersion</var> and
/// <var>pUpdatedAt</var> on every read until <method>Disarm</method>.</p>
ClassMethod ArmRow(pPhase As %String, pSchemaVersion As %Integer, pUpdatedAt As %String = "2026-09-11T00:00:00Z")
{
    Set ^||OcuPilotGateLadderRow = $ListBuild("row", pPhase, pSchemaVersion, pUpdatedAt)
}

/// <p>Serve a read that succeeds and finds no row -- a genuinely first start.</p>
ClassMethod ArmNoRow()
{
    Set ^||OcuPilotGateLadderRow = $ListBuild("none")
}

/// <p>Serve a read that fails.</p>
ClassMethod ArmReadError()
{
    Set ^||OcuPilotGateLadderRow = $ListBuild("error")
}

/// <p>Serve a read that throws.</p>
ClassMethod ArmReadThrow()
{
    Set ^||OcuPilotGateLadderRow = $ListBuild("throw")
}

/// <p>Back to unarmed. Called from the driving test's cleanup.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotGateLadderRow
}

/// <p>The armed version-row state, never the real row.</p>
ClassMethod CurrentVersionRow(pProfile As %String, Output pRow) As %Status
{
    Set tSC = $$$OK
    Set pRow = $$$NULLOREF
    Set tArm = $Get(^||OcuPilotGateLadderRow)
    If tArm = "" {
        Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.GateLadderRow: arm a version-row state before reading")
    } ElseIf $ListGet(tArm, 1) = "throw" {
        Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "OcuPilot.Test.GateLadderRow: induced version-row read exception"))
    } ElseIf $ListGet(tArm, 1) = "error" {
        Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.GateLadderRow: induced version-row read failure")
    } ElseIf $ListGet(tArm, 1) = "row" {
        Set pRow = ##class(OcuPilot.Kernel.State.Version).%New()
        Set pRow.Profile = pProfile
        Set pRow.Phase = $ListGet(tArm, 2)
        Set pRow.SchemaVersion = $ListGet(tArm, 3)
        Set pRow.UpdatedAt = $ListGet(tArm, 4)
        Set pRow.BuildIdentity = ..#BUILDIDENTITY
    }
    Quit tSC
}

}
