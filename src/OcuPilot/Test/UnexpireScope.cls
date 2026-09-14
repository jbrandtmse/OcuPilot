/// <p><b>DW-73</b> (AD-17 as amended 2026-09-11): the <code>_SYSTEM</code> unexpire runs from
/// the container start path only. <method>OcuPilot.Install.Installer.Install</method> called
/// the way IPM's <code>&lt;Invoke&gt;</code> will call it -- with no second argument -- never
/// reaches the step, even on a first install; the form
/// <method>OcuPilot.Install.Installer.StartPath</method> uses does; and
/// <method>OcuPilot.Install.Installer.StartPath</method> asks for it. On an instance reached
/// through IPM, an expired <code>_SYSTEM</code> may be the operator's deliberate choice.</p>
/// <p>The first four read <class>OcuPilot.Test.InstallerProbe</class>'s record of the step's
/// arguments, and that probe never runs the real unexpire (DW-79). The first two run on the
/// <code>"probe"</code> profile; the third drives <method>StartPath</method>, which always
/// installs production (idempotent, the same install <class>OcuPilot.Test.DemoOptIn</class>
/// already runs); the fourth fails the probe's first install at the step and retries it. The
/// fifth runs the real step from <method>OcuPilot.Install.Installer.Install</method>'s own call
/// site, through <class>OcuPilot.Test.UnexpireReal</class>, and it unexpires only a throwaway
/// account it created itself, never <code>_SYSTEM</code>. The probe profile is removed once, in
/// <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.UnexpireScope Extends %UnitTest.TestCase
{

/// <p>Removes the probe profile the tests leave installed, so no probe web application survives
/// the class (DW-242).</p>
Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.ProbeApps).Remove()
}

/// <p>The argument contract the committed <code>&lt;Invoke&gt;</code> depends on (DW-92).
/// <file>module.xml</file> calls <method>OcuPilot.Install.Installer.Install</method> with
/// <b>zero</b> <code>&lt;Arg&gt;</code> children, so every formal takes its declared default;
/// what makes that safe rather than lucky is that <var>pUnexpire</var>'s default is
/// <code>0</code>. A later edit that defaulted it to <code>1</code>, or that renamed the
/// unexpire flag onto a differently defaulted formal, would leave an IPM install silently
/// unexpiring the instance's default account with every behavioural test in this class still
/// green -- they all call the method rather than reading its signature.</p>
/// <p>The committed manifest's own bytes are pinned in
/// <file>ui/tools/ipm-manifest.test.mjs</file>: the repository is not mounted into this
/// instance, so no <code>%UnitTest</code> here can open <file>module.xml</file>. What is pinned
/// here is the contract that file relies on.</p>
/// <p>Mutation (Rule 19): change <var>pUnexpire</var>'s default to <code>1</code> in
/// <method>OcuPilot.Install.Installer.Install</method> -- red here, and red in
/// <method>TestIpmFormNeverReachesTheUnexpireStep</method> too.</p>
Method TestInstallsArgumentContractMakesTheZeroArgumentInvokeSafe()
{
    Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId("OcuPilot.Install.Installer||Install")
    Do $$$AssertTrue($IsObject(tMethod), "the method module.xml's <Invoke> names is compiled on this instance")
    Set tSpec = tMethod.FormalSpec
    Do $$$AssertTrue(tSpec '= "", "and declares formal arguments: " _ tSpec)

    Set tFound = ""
    For tI = 1:1:$Length(tSpec, ",") {
        Set tFormal = $Piece(tSpec, ",", tI)
        If $Piece(tFormal, ":", 1) = "pUnexpire" Set tFound = tFormal
    }
    Do $$$AssertNotEquals(tFound, "", "Install still declares a pUnexpire formal: " _ tSpec)
    Do $$$AssertEquals($Piece(tFound, "=", 2), 0, "and it defaults to 0, so a call with no arguments never asks for the unexpire step (DW-92)")

    ; Every other formal carries a default too: a required formal would make the zero-argument
    ; <Invoke> fail at install time rather than run with the defaults it relies on.
    For tI = 1:1:$Length(tSpec, ",") {
        Set tFormal = $Piece(tSpec, ",", tI)
        Do $$$AssertTrue(tFormal [ "=", "formal '" _ $Piece(tFormal, ":", 1) _ "' carries a default, so <Invoke> needs no <Arg> for it")
    }
}

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

/// <p>A first install whose unexpire step fails is a failed install, and the next start retries
/// it (DW-73's constraint, step-04 review of rework iteration 8). The step keeps its place before
/// the version row, so the failure is recorded on a <code>failed</code> row at schema version 0,
/// naming the step, and that row still reads as a first install to the next
/// <method>StartPath</method>-form install, which reaches the step again. Moving the step after
/// the version row, or swallowing its error, would record <code>installed</code> and never retry:
/// a container reporting healthy with <code>_SYSTEM</code> still expired. Driven through
/// <class>OcuPilot.Test.InstallerProbe</class>, armed to fail the step; nothing unexpires.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Install.Installer.Install</method>'s error check
/// after the unexpire step -- the failure is overwritten, the first install returns OK with an
/// <code>installed</code> row, red.</p>
Method TestFailedUnexpireLeavesTheFirstInstallToRetry()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Version).DeleteByProfile("probe"), "clear the probe version row, so this is a first install")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do ##class(OcuPilot.Test.InstallerProbe).SetUnexpireFails(1)
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe", 1)
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusNotOK(tSC, "a first install whose unexpire step fails is a failed install")
    Do $$$AssertTrue($System.Status.GetErrorText(tSC) [ "EnsureUnexpired", "and names the step: " _ $System.Status.GetErrorText(tSC))

    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Phase, SchemaVersion, FailingStep FROM OcuPilot_Kernel_State.Version WHERE Profile = 'probe'")
    Do $$$AssertTrue(tRS.%SQLCODE >= 0, "the probe version row query succeeds (SQLCODE " _ tRS.%SQLCODE _ ")")
    Set tRows = 0
    Set tRow = ""
    While tRS.%Next() {
        Set tRows = tRows + 1
        Set tRow = tRS.Phase _ "|" _ tRS.SchemaVersion _ "|" _ tRS.FailingStep
    }
    Do $$$AssertEquals(tRows, 1, "one probe version row records the failure")
    Do $$$AssertEquals(tRow, "failed|0|EnsureUnexpired", "failed, at schema version 0, naming the unexpire step")

    Set tSC2 = ##class(OcuPilot.Test.InstallerProbe).Install("probe", 1)
    Set tFirst = ##class(OcuPilot.Test.InstallerProbe).CapturedFirstInstallArg()
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusOK(tSC2, "the next start's install succeeds")
    Do $$$AssertEquals(tFirst, 1, "and retries the unexpire step as a first install")
}

/// <p>The real step, from the call site a clean clone's first start uses (code review round 4).
/// The tests above read <class>OcuPilot.Test.InstallerProbe</class>'s record of the step's
/// arguments, and <class>OcuPilot.Test.Version</class> drives the real
/// <method>OcuPilot.Install.Installer.EnsureUnexpired</method> directly, from the install
/// namespace. Since DW-79 nothing ran the real body from inside
/// <method>OcuPilot.Install.Installer.Install</method>'s <code>%SYS</code> region any more, where
/// AC2's first start runs it: a change that works from the install namespace and fails from
/// <code>%SYS</code> -- the <code>Kernel.Utils.SwitchNamespace</code> call
/// <method>OcuPilot.Install.Installer.EnsureUnexpired</method>'s own header warns against --
/// would have broken that first start with the suite green. Here
/// <class>OcuPilot.Test.UnexpireReal</class> names a throwaway, expired account as its install
/// account, and a <method>StartPath</method>-form first install of the probe must unexpire it.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Install.Installer.EnsureUnexpired</method> switches to
/// <code>%SYS</code> through <code>##class(OcuPilot.Kernel.Utils).SwitchNamespace</code> instead
/// of its bare assignment -- the install fails at the step and the account stays expired, red,
/// while the direct-call tests in <class>OcuPilot.Test.Version</class> stay green.</p>
Method TestStartPathFormRunsTheRealUnexpireStep()
{
    Set tAccount = ##class(OcuPilot.Test.UnexpireReal).#UNEXPIREACCOUNT
    Do $$$AssertNotEquals(tAccount, "_SYSTEM", "the install account under test is a throwaway, never _SYSTEM")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.Version).CreateThrowawayExpiredAccount(tAccount), "create the throwaway expired account")
    Do $$$AssertEquals(##class(OcuPilot.Test.Version).IsExpired(tAccount), 1, "the throwaway account starts expired")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Version).DeleteByProfile("probe"), "clear the probe version row, so this is a first install")

    Set tSC = ##class(OcuPilot.Test.UnexpireReal).Install("probe", 1)
    Set tExpired = ##class(OcuPilot.Test.Version).IsExpired(tAccount)
    Do ##class(OcuPilot.Test.Version).DeleteThrowawayAccount(tAccount)

    Do $$$AssertStatusOK(tSC, "a StartPath-form first install runs the real unexpire step from inside its %SYS region and succeeds")
    Do $$$AssertEquals(tExpired, 0, "and unexpires the one named install account")
}

}
