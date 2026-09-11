/// <p><b>DW-73</b> (AD-17 as amended 2026-09-11): the <code>_SYSTEM</code> unexpire runs from
/// the container start path only. <method>OcuPilot.Install.Installer.Install</method> called
/// the way IPM's <code>&lt;Invoke&gt;</code> will call it -- with no second argument -- never
/// reaches the step, even on a first install; the form
/// <method>OcuPilot.Install.Installer.StartPath</method> uses does; and
/// <method>OcuPilot.Install.Installer.StartPath</method> asks for it. On an instance reached
/// through IPM, an expired <code>_SYSTEM</code> may be the operator's deliberate choice.</p>
/// <p>Every assertion reads <class>OcuPilot.Test.InstallerProbe</class>'s record of the step's
/// arguments, and that probe never runs the real unexpire (DW-79), so nothing here unexpires
/// anything. The first two run on the <code>"probe"</code> profile; the third drives
/// <method>StartPath</method>, which always installs production (idempotent, the same install
/// <class>OcuPilot.Test.DemoOptIn</class> already runs). Nothing here uninstalls.</p>
Class OcuPilot.Test.UnexpireScope Extends %UnitTest.TestCase
{

/// <p>IPM's form, on a first install (no probe version row): the unexpire step is never
/// reached, and the run says why it skipped it.</p>
/// <p>Mutation (Rule 19): run the step whatever the caller asked (drop the
/// <var>pUnexpire</var> gate) -- the step is reached with a first-install argument of 1, red.</p>
Method TestIpmFormNeverReachesTheUnexpireStep()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Version).DeleteByProfile("probe"), "clear the probe version row, so this is a first install")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
    Set tAccount = ##class(OcuPilot.Test.InstallerProbe).CapturedUnexpireAccountArg()
    Set tFirst = ##class(OcuPilot.Test.InstallerProbe).CapturedFirstInstallArg()
    Set tInfo = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("info")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertStatusOK(tSC, "an IPM-form first install succeeds")
    Do $$$AssertEquals(tAccount, "", "an IPM-form install never reaches the unexpire step, even on a first install")
    Do $$$AssertEquals(tFirst, "", "so no first-install answer was ever handed to it")
    Do $$$AssertTrue(tInfo [ "only the container start path unexpires", "the run reports why it skipped the step")
}

/// <p><method>StartPath</method>'s form (<var>pUnexpire</var> = 1), on a first install: the
/// step is reached, for the one named account, as a first install.</p>
/// <p>Mutation (Rule 19): never run the step (<code>If 0</code> for the gate) -- nothing is
/// recorded, red.</p>
Method TestStartPathFormReachesTheUnexpireStep()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Version).DeleteByProfile("probe"), "clear the probe version row, so this is a first install")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe", 1)
    Set tAccount = ##class(OcuPilot.Test.InstallerProbe).CapturedUnexpireAccountArg()
    Set tFirst = ##class(OcuPilot.Test.InstallerProbe).CapturedFirstInstallArg()
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertStatusOK(tSC, "a StartPath-form first install succeeds")
    Do $$$AssertEquals(tAccount, "_SYSTEM", "the StartPath form reaches the unexpire step, for the one named account")
    Do $$$AssertEquals(tFirst, 1, "as a first install")
}

/// <p>The call site: <method>StartPath</method> asks its install for the unexpire step.
/// Production already carries an <code>installed</code> row, so the step is reached as
/// not-a-first-install and does nothing.</p>
/// <p>Mutation (Rule 19): <method>StartPath</method> calls <code>Install("")</code> without
/// asking -- the step is never reached, red.</p>
Method TestStartPathAsksForTheUnexpireStep()
{
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).StartPath(0)
    Set tAccount = ##class(OcuPilot.Test.InstallerProbe).CapturedUnexpireAccountArg()
    Set tFirst = ##class(OcuPilot.Test.InstallerProbe).CapturedFirstInstallArg()
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertStatusOK(tSC, "StartPath with the demo flag off completes install")
    Do $$$AssertEquals(tAccount, "_SYSTEM", "StartPath's own install reached the unexpire step")
    Do $$$AssertEquals(tFirst, 0, "production already carries an installed row, so it is not a first install")
}

}
