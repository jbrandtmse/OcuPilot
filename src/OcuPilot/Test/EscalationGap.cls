/// <p>DW-63 (rework iteration 5). Fault-injection subclass of
/// <class>OcuPilot.Test.InstallerProbe</class> (so its log capture is inherited for free)
/// that forces the one state no instance this suite runs against can reach on its own:
/// the privileged routine application every
/// <class>OcuPilot.Kernel.State.Base</class>-derived escalation needs is <b>genuinely
/// absent</b>, as on a first-ever install into an empty durable volume.</p>
/// <p><b>Why this class exists.</b> A real, live-discovered first-install failure
/// (<code>ERROR #868: Application OcuPilotState not found</code>) was fixed by
/// <method>OcuPilot.Install.Installer.IsEscalationInfrastructureAbsent</method> and its
/// two call sites, and shipped with no test at all: every instance this suite runs
/// against has carried <code>OcuPilotState</code> since an early story, so the branch was
/// unreachable without a disposable container. Arming the seam here reaches it in-process
/// -- and because the predicate itself is <code>[ Private ]</code>, this subclass also
/// provides the passthroughs a test needs to drive it and
/// <method>OcuPilot.Install.Installer.EnsureVersion</method> directly.</p>
/// <p>Toggles and counters live in process-private globals rather than properties, exactly
/// as <class>OcuPilot.Test.MigrateFault</class> does and for the identical reason: the
/// real code path makes fresh class-method dispatches that never carry an instance.</p>
Class OcuPilot.Test.EscalationGap Extends OcuPilot.Test.InstallerProbe
{

/// <p>Arm or disarm the "escalation infrastructure is absent" fault. Default off.</p>
ClassMethod SetEscalationAbsent(pAbsent As %Boolean)
{
    Set ^||OcuPilotEscalationGapAbsent = pAbsent
}

/// <p>Disarm the fault and clear the version-read counter -- called from every driving
/// test's cleanup path, including its <code>Catch</code>.</p>
ClassMethod Disarm()
{
    Kill ^||OcuPilotEscalationGapAbsent, ^||OcuPilotEscalationGapReads
}

/// <p>Forces "the privileged routine application does not exist" on demand (default off),
/// otherwise the real <code>Security.Applications.Exists</code> check.</p>
ClassMethod EscalationApplicationExists(pApplication As %String) As %Boolean
{
    If +$Get(^||OcuPilotEscalationGapAbsent, 0) {
        Quit 0
    }
    Quit ##super(pApplication)
}

/// <p>Counts every call before delegating, so a test can assert that
/// <method>OcuPilot.Install.Installer.Install</method> and
/// <method>EnsureVersion</method> genuinely <b>skipped</b> the escalated version-row read
/// when the escalation infrastructure is absent -- the actual content of the
/// <code>ERROR #868</code> fix -- rather than merely surviving it.</p>
ClassMethod CurrentVersionRow(pProfile As %String, Output pRow) As %Status
{
    Set ^||OcuPilotEscalationGapReads = +$Get(^||OcuPilotEscalationGapReads, 0) + 1
    Quit ##super(pProfile, .pRow)
}

/// <p>How many times <method>CurrentVersionRow</method> has been called since the last
/// <method>ResetReadCount</method> or <method>Disarm</method>.</p>
ClassMethod VersionReadCount() As %Integer
{
    Quit +$Get(^||OcuPilotEscalationGapReads, 0)
}

/// <p>Zero the version-read counter without disarming the fault.</p>
ClassMethod ResetReadCount()
{
    Kill ^||OcuPilotEscalationGapReads
}

/// <p>Drive the real, unmodified <code>[ Private ]</code>
/// <method>OcuPilot.Install.Installer.IsEscalationInfrastructureAbsent</method> for one
/// named application, through inherited <code>..</code> dispatch -- the predicate half of
/// DW-63's pin. It opens (and restores) its own <code>%SYS</code> window internally, so
/// this passthrough needs none.</p>
ClassMethod ProbeEscalationAbsent(pApplication As %String, ByRef pReports) As %Boolean
{
    Kill tNames
    Set tNames("application") = pApplication
    Quit ..IsEscalationInfrastructureAbsent(.tNames, .pReports)
}

/// <p>Drive the real, unmodified <code>[ Private ]</code>
/// <method>OcuPilot.Install.Installer.EnsureVersion</method>, through inherited
/// <code>..</code> dispatch -- the second of DW-63's two call sites (the failure-path
/// write that used to hit the same <code>ERROR #868</code> and silently leave the
/// <code>failed</code> phase unrecorded).</p>
ClassMethod ProbeEnsureVersion(pProfile As %String, pPhase As %String, pFailingStep As %String, pSchemaVersion As %Integer, pApplication As %String, ByRef pReports) As %Status
{
    Kill tNames
    Set tNames("application") = pApplication
    Quit ..EnsureVersion(pProfile, pPhase, pFailingStep, pSchemaVersion, .tNames, .pReports)
}

}
