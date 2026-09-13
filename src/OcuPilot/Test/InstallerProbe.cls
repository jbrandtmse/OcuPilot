/// <p>Test-only subclass of <class>OcuPilot.Install.Installer</class> that captures what
/// an ensure step reports through the <method>OcuPilot.Install.Installer.LogInfo</method>
/// / <method>LogWarn</method> seam, instead of writing to the console log -- the same
/// shape as <class>OcuPilot.Test.LogProbe</class> and <class>OcuPilot.Test.ErrorProbe</class>.</p>
/// <p>Every ensure step reaches the seam through <code>..</code> dispatch, so calling any
/// public entry point (<method>OcuPilot.Install.Installer.EnsureGrant</method> included)
/// on this subclass routes the real production code path into the capture below without
/// touching the production class or the real console log.</p>
Class OcuPilot.Test.InstallerProbe Extends OcuPilot.Install.Installer
{

/// <p>Captures into the process-private global <code>^||OcuPilotInstallerProbe</code>.
/// Subscripts follow ObjectScript identifier rules (no hyphens) per
/// <file>.claude/rules/objectscript-basics.md</file>.</p>
ClassMethod LogInfo(pMessage As %String, pData As %DynamicObject = "")
{
    Set tN = $Increment(^||OcuPilotInstallerProbe("info"))
    Set ^||OcuPilotInstallerProbe("info", tN) = pMessage
    Set ^||OcuPilotInstallerProbe("infoData", tN) = $Select($IsObject(pData): pData.%ToJSON(), 1: "")
    Set ^||OcuPilotInstallerProbe("lastInfo") = pMessage
    Set ^||OcuPilotInstallerProbe("lastInfoData") = $Select($IsObject(pData): pData.%ToJSON(), 1: "")
}

/// <p>See <method>LogInfo</method>.</p>
ClassMethod LogWarn(pMessage As %String, pData As %DynamicObject = "")
{
    Set tN = $Increment(^||OcuPilotInstallerProbe("warn"))
    Set ^||OcuPilotInstallerProbe("warn", tN) = pMessage
    Set ^||OcuPilotInstallerProbe("warnData", tN) = $Select($IsObject(pData): pData.%ToJSON(), 1: "")
    Set ^||OcuPilotInstallerProbe("lastWarn") = pMessage
    Set ^||OcuPilotInstallerProbe("lastWarnData") = $Select($IsObject(pData): pData.%ToJSON(), 1: "")
}

/// <p>Discard anything a previous capture left behind.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotInstallerProbe
}

/// <p>Read one captured field back. Returns <code>""</code> when nothing was captured.</p>
/// @param pField One of "lastInfo", "lastInfoData", "lastWarn", "lastWarnData"
ClassMethod Captured(pField As %String) As %String
{
    Quit $Get(^||OcuPilotInstallerProbe(pField), "")
}

/// <p>(Story 1.4) Records the <var>pAccount</var> and <var>pFirstInstall</var>
/// arguments <method>OcuPilot.Install.Installer.Install</method>'s call site actually
/// passed -- so <class>OcuPilot.Test.Version</class> can assert what the <b>call site</b>
/// computed (AC4, AC14), not only what <method>EnsureUnexpired</method> does when driven
/// directly with an explicit argument.</p>
/// <p><b>Never delegates to the real step (DW-79, rework iteration 8).</b> It used to call
/// <code>##super()</code>, so every probe install that read as a first install ran the real
/// <code>UnExpireUserPasswords("_SYSTEM")</code> on whatever instance the suite ran against,
/// undoing a deliberate expiry there. Since DW-73 only <method>OcuPilot.Install.Installer.StartPath</method>'s
/// form of <method>Install</method> reaches this step, and the tests that drive that form
/// through this class want the call site's arguments, not the side effect. What the real step
/// does is pinned directly, against throwaway accounts only
/// (<method>OcuPilot.Test.Version.TestUnexpireTargetsOnlyTheInstallAccount</method>,
/// <method>OcuPilot.Test.Version.TestSecondStartDoesNotUnexpireAgain</method>), and on a
/// throwaway container's first start.</p>
/// <p>Armed with <method>SetUnexpireFails</method>, it records its arguments and then returns
/// an error, so a test can make the step fail on a first install (step-04 review of rework
/// iteration 8). <method>Clear</method> disarms it.</p>
ClassMethod EnsureUnexpired(pAccount As %String, pFirstInstall As %Boolean, ByRef pReports) As %Status
{
    Set ^||OcuPilotInstallerProbe("unexpireAccountArg") = pAccount
    Set ^||OcuPilotInstallerProbe("firstInstallArg") = pFirstInstall
    If +$Get(^||OcuPilotInstallerProbe("unexpireFails"), 0) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InstallerProbe: induced password-unexpire failure")
    }
    Do ..Report(.pReports, "info", "Test probe: the password-unexpire step was reached and recorded, not run", {"user": (pAccount), "firstInstall": (pFirstInstall)})
    Quit $$$OK
}

/// <p>Make <method>EnsureUnexpired</method> fail (1) or succeed (0) from now on, in this process,
/// until <method>Clear</method>.</p>
ClassMethod SetUnexpireFails(pFails As %Boolean)
{
    Set ^||OcuPilotInstallerProbe("unexpireFails") = pFails
}

/// <p>See <method>EnsureUnexpired</method>. Returns <code>""</code> when no call was
/// captured.</p>
ClassMethod CapturedUnexpireAccountArg() As %String
{
    Quit $Get(^||OcuPilotInstallerProbe("unexpireAccountArg"), "")
}

/// <p>See <method>EnsureUnexpired</method>. Returns <code>""</code> when no call was
/// captured.</p>
ClassMethod CapturedFirstInstallArg() As %String
{
    Quit $Get(^||OcuPilotInstallerProbe("firstInstallArg"), "")
}

/// <p>(Story 1.4, DW-56) Records that <method>OcuPilot.Install.Installer.StartPath</method>
/// reached its demo-fixture call site, and deliberately does <b>not</b> delegate to the
/// real <method>OcuPilot.Install.Installer.CreateDemoFixtures</method>: a test driving
/// <code>StartPath(1)</code> on this probe must never create, adopt or re-run a real
/// production-profile fixture on the shared instance. Only <class>OcuPilot.Test.DemoOptIn</class>
/// drives <code>StartPath</code> through this class with the flag set; every other caller
/// passes <code>0</code>, so nothing else depends on the real call happening here.</p>
/// <p>It also records whether this process held the production profile's install lock at that
/// moment (<method>CapturedDemoFixtureLockHeld</method>), so
/// <class>OcuPilot.Test.DemoOptIn</class> can pin that <method>OcuPilot.Install.Installer.StartPath</method>
/// creates the fixtures under the lock.</p>
ClassMethod CreateDemoFixtures(ByRef pFixtureReports) As %Status [ Private ]
{
    Set ^||OcuPilotInstallerProbe("demoFixtureCalls") = $Get(^||OcuPilotInstallerProbe("demoFixtureCalls"), 0) + 1
    Set ^||OcuPilotInstallerProbe("demoFixtureLockHeld") = ..HoldsProductionInstallLock()
    Quit $$$OK
}

/// <p>Whether this process holds the production profile's install lock right now, as the lock
/// table records it: <code>^["^^&lt;manager directory&gt;"]OcuPilotInstallLock("production")</code>
/// (<method>OcuPilot.Install.Installer.InstallLockName</method> for <code>""</code>, taken
/// through its extended reference into <code>%SYS</code>).</p>
ClassMethod HoldsProductionInstallLock() As %Boolean
{
    Set tRef = "^[""^^" _ $System.Util.ManagerDirectory() _ """]OcuPilotInstallLock(""production"")"
    Quit (";" _ ##class(OcuPilot.Test.InstallLock).LocksHeldBy($Job)) [ (";" _ tRef _ ";")
}

/// <p>See <method>CreateDemoFixtures</method>. Returns <code>""</code> when it was never
/// reached.</p>
ClassMethod CapturedDemoFixtureLockHeld() As %String
{
    Quit $Get(^||OcuPilotInstallerProbe("demoFixtureLockHeld"), "")
}

/// <p>How many times <method>CreateDemoFixtures</method> was reached since the last
/// <method>Clear</method>. Returns <code>0</code> when it was never reached.</p>
ClassMethod CapturedDemoFixtureCalls() As %Integer
{
    Quit +$Get(^||OcuPilotInstallerProbe("demoFixtureCalls"), 0)
}

/// <p>Every message captured at <var>pLevel</var> during the run, joined with
/// <code>$Char(10)</code> -- unlike <method>Captured</method>'s "last" fields, this
/// survives a later report at the same level overwriting the one a test actually cares
/// about (e.g. <method>OcuPilot.Install.Installer.EnsureGrant</method>'s own "info"
/// report running after <method>OcuPilot.Install.Installer.EnsureAuditingEnabled</method>'s).
/// Returns <code>""</code> when nothing was captured at that level.</p>
/// @param pLevel "info" or "warn"
ClassMethod CapturedAll(pLevel As %String) As %String
{
    Set tResult = ""
    Set tN = $Order(^||OcuPilotInstallerProbe(pLevel, ""))
    While tN '= "" {
        Set tResult = tResult _ $Select(tResult = "": "", 1: $Char(10)) _ ^||OcuPilotInstallerProbe(pLevel, tN)
        Set tN = $Order(^||OcuPilotInstallerProbe(pLevel, tN))
    }
    Quit tResult
}

/// <p>Every report captured at <var>pLevel</var> during the run, as
/// <code>&lt;message&gt;&lt;tab&gt;&lt;data as JSON&gt;</code> per line. <method>CapturedAll</method>
/// keeps only the messages, which is enough for a report identified by its wording, but not
/// for one identified by what it carries -- the CSP Gateway registration gap is reported once
/// per created web application with the path in <code>data.path</code>, so a test asserting
/// "one line per application this run created" has to see the data (Story 1.5).</p>
/// @param pLevel "info" or "warn"
ClassMethod CapturedAllWithData(pLevel As %String) As %String
{
    Set tResult = ""
    Set tN = $Order(^||OcuPilotInstallerProbe(pLevel, ""))
    While tN '= "" {
        Set tResult = tResult _ $Select(tResult = "": "", 1: $Char(10)) _ ^||OcuPilotInstallerProbe(pLevel, tN) _ $Char(9) _ $Get(^||OcuPilotInstallerProbe(pLevel _ "Data", tN), "")
        Set tN = $Order(^||OcuPilotInstallerProbe(pLevel, tN))
    }
    Quit tResult
}

/// <p>Drive <method>OcuPilot.Install.Installer.AssertApplications</method> over one synthetic
/// application description, switching to <code>%SYS</code> and restoring (AD-16).</p>
/// <p><b>Why a seam is needed at all.</b> The install-time assertion is the last step of a
/// successful install, so on a healthy instance it only ever passes -- every state it refuses
/// is one the ensure steps just finished making impossible. Its refusal arms are therefore
/// unreachable end-to-end, and were reached by no test until Story 1.17's matrix audit: an
/// assertion whose failure path nothing executes is the vacuous gate this story exists to
/// remove. This calls the real private method through <code>..</code> dispatch, so what the
/// test drives is the shipped code and not a copy.</p>
/// @param pKey the roster key to describe
/// @param pName the web application path to assert
/// @param pRole the matching role name the caller claims the roster declares
ClassMethod AssertOneApplication(pKey As %String, pName As %String, pRole As %String) As %Status
{
    Kill tNames, tReports
    Set tNames("appKeys") = pKey
    Set tNames("appName", pKey) = pName
    Set tNames("appRole", pKey) = pRole
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tSC = ..AssertApplications(.tNames, tOrigNS, .tReports)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
