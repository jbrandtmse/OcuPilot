/// <p>Test-only subclass of <class>OcuPilot.Install.Installer</class> that pauses an install or
/// an uninstall part-way, in the process running it, while that process holds the profile's
/// install lock (step-04 review of rework iteration 8). <class>OcuPilot.Test.InstallLock</class>
/// runs it in a second process (<code>JOB</code>) and checks, while it is paused, that the lock
/// table shows that process holding the lock: the pins that the lock is held through the run,
/// not only taken at its start.</p>
/// <p>Armed per process through a process-private global, as the other fault seams are. An
/// install pauses in <method>RunMigrations</method>, after every ensure step and before the
/// install stamp and the version row; an uninstall pauses in <method>RemoveDemoFixtures</method>,
/// after the inventory read and before anything is removed. Paused, it records that in
/// <code>^IRIS.Temp.OcuPilotLockPause(&lt;job&gt;)</code>, which the other process polls, and waits
/// for <class>OcuPilot.Test.InstallLock</class>'s go lock, for no longer than that class's
/// <code>HOLDMAXSECONDS</code>. Nothing else is overridden, so the rest of the run is the real
/// code.</p>
Class OcuPilot.Test.LockPause Extends OcuPilot.Install.Installer
{

/// <p>Pause at <var>pWhere</var> -- <code>"install"</code> or <code>"uninstall"</code> -- from
/// now on, in this process; <code>""</code> disarms.</p>
ClassMethod SetPauseAt(pWhere As %String)
{
    Set ^||OcuPilotLockPauseAt = pWhere
}

/// <p>When armed for <var>pWhere</var>: record the pause, then wait for the go lock.</p>
ClassMethod PauseIfArmed(pWhere As %String) [ Private ]
{
    If $Get(^||OcuPilotLockPauseAt) '= pWhere Quit
    Set tGo = ##class(OcuPilot.Test.InstallLock).#GOLOCK
    Set tMax = ##class(OcuPilot.Test.InstallLock).#HOLDMAXSECONDS
    Set ^IRIS.Temp.OcuPilotLockPause($Job) = "paused"
    Lock +@tGo:tMax
    If $Test Lock -@tGo
    Set ^IRIS.Temp.OcuPilotLockPause($Job) = "resumed"
}

/// <p>The install's pause point, then the real migration runner.</p>
ClassMethod RunMigrations(pProfile As %String, pFromVersion As %Integer, ByRef pReports) As %Status
{
    Do ..PauseIfArmed("install")
    Quit ##super(pProfile, pFromVersion, .pReports)
}

/// <p>The uninstall's pause point, then the real fixture removal.</p>
ClassMethod RemoveDemoFixtures(pProfile As %String, ByRef pFixtureReports) As %Status [ Private ]
{
    Do ..PauseIfArmed("uninstall")
    Quit ##super(pProfile, .pFixtureReports)
}

}
