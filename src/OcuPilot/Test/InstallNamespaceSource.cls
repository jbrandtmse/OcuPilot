/// <p>(QA) DW-191. <method>OcuPilot.Install.Installer.Uninstall</method> and
/// <method>OcuPilot.Install.Installer.StateFingerprint</method> both act on
/// <code>$NAMESPACE</code> at entry -- the namespace the caller stands in -- rather than on
/// <method>OcuPilot.Install.Installer.ResolveNamespace</method>'s default, the same reading
/// <method>OcuPilot.Install.Installer.GuardInstallNamespace</method> already gives
/// <method>Install</method>, <method>StartPath</method> and <method>MarkInstalling</method>
/// (DW-12). <b>Neither method calls <method>GuardInstallNamespace</method> at all</b> --
/// this story's own review recorded that as a deferred gap (<code>Uninstall</code> is the
/// one entry point with no namespace guard) -- so what this class pins is narrower than a
/// guard: that both methods key off the namespace they were actually called from, not off
/// the resolved default, exactly as <class>OcuPilot.Test.Installer</class>'s
/// <code>TestTheInstallTargetIsTheNamespaceInstallWasCalledFrom</code> already pins for
/// <method>Install</method>.</p>
/// <p>Driven through <class>OcuPilot.Test.NamespaceProbe</class>, armed with the candidate
/// namespace <b>other</b> than the one this suite actually runs in, so the resolved default
/// and the caller's real namespace are deliberately different -- without creating or
/// removing a namespace. Every entry point reaches <method>NamespaceExists</method> through
/// <code>..</code> dispatch (<class>NamespaceProbe</class>'s own header), so dispatching
/// through it here reaches the real, unmodified <method>Uninstall</method> and
/// <method>StateFingerprint</method> bodies.</p>
Class OcuPilot.Test.InstallNamespaceSource Extends %UnitTest.TestCase
{

Method %OnNew(initvalue As %String = "") As %Status
{
    Quit ##super(initvalue)
}

/// <p>Same priming order as <class>OcuPilot.Test.Installer</class>: every install's version
/// row escalates through the production privileged routine application.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Install.Installer).Install("probe")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.NamespaceProbe).Reset()
    Quit ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
}

/// <p>DW-191, half one. <method>OcuPilot.Install.Installer.StateFingerprint</method> reads
/// the probe's global mapping (among other namespace-scoped objects) in the namespace it was
/// called from. Armed so the resolved default is the <b>other</b> candidate namespace, a
/// fingerprint taken through the armed probe must still equal one taken through the
/// production class unarmed -- both read the same, real, current namespace's objects,
/// unaffected by what the resolved default would be.</p>
/// <p>Mutation (Rule 19): change <method>StateFingerprint</method>'s
/// <code>Set tInstallNs = tOrigNS</code> to <code>Set tInstallNs = ..ResolveNamespace()</code>
/// -- dispatched through the armed probe, <code>..ResolveNamespace()</code> resolves
/// polymorphically to the armed <code>NamespaceExists</code> and answers the other candidate,
/// so the mapping component is read from a namespace where the probe's mapping does not
/// exist. <var>tActual</var> then differs from <var>tExpected</var>, red.</p>
Method TestStateFingerprintReadsTheCallersNamespaceNotTheResolvedDefault()
{
    Set tHere = $NAMESPACE
    Set tOther = $Select(tHere = "USER": "HSCUSTOM", 1: "USER")
    Do $$$AssertNotEquals(tOther, tHere, "the armed default is a different namespace from this one")

    Set tExpected = ##class(OcuPilot.Install.Installer).StateFingerprint("probe")

    Do ##class(OcuPilot.Test.NamespaceProbe).Arm(tOther)
    Try {
        Set tResolved = ##class(OcuPilot.Test.NamespaceProbe).ResolveNamespace()
        Set tActual = ##class(OcuPilot.Test.NamespaceProbe).StateFingerprint("probe")
    } Catch ex {
        Do ##class(OcuPilot.Test.NamespaceProbe).Reset()
        Throw ex
    }
    Do ##class(OcuPilot.Test.NamespaceProbe).Reset()

    Do $$$AssertEquals(tResolved, tOther, "the armed instance really did resolve a default other than the current namespace")
    ; Two runs compared for equality are evidence only if either produced a fingerprint:
    ; StateFingerprint answers "ERROR:..." whenever Names() fails, and two such answers compare
    ; equal to each other for a reason that has nothing to do with what this test claims.
    Do $$$AssertTrue(tExpected '[ "ERROR:", "the unarmed run produced a fingerprint, not a failure: " _ tExpected)
    Do $$$AssertTrue(tActual '[ "ERROR:", "and so did the armed run: " _ tActual)
    Do $$$AssertEquals(tActual, tExpected, "StateFingerprint reads the namespace the call was made from -- unaffected by what the resolved default would be")
}

/// <p>DW-191, half two. A confirmed <code>Uninstall</code>, dispatched through the armed
/// probe, must still remove the probe's global mapping from the namespace it was actually
/// called from -- not leave it in place because the resolved default pointed somewhere
/// else.</p>
/// <p>Mutation (Rule 19): the same change as above, made to <method>Uninstall</method>
/// instead: <code>Set tInstallNs = tOrigNS</code> to <code>Set tInstallNs = ..ResolveNamespace()</code>.
/// Dispatched through the armed probe, the mapping delete then targets the other candidate
/// namespace, where the probe's mapping does not exist, so
/// <code>Config.MapGlobals.Exists</code> in <var>tHere</var> stays true after the call
/// returns, and the assertion below goes red.</p>
Method TestUninstallActsOnTheNamespaceItWasCalledFrom()
{
    Set tHere = $NAMESPACE
    Set tOther = $Select(tHere = "USER": "HSCUSTOM", 1: "USER")
    Do $$$AssertNotEquals(tOther, tHere, "the armed default is a different namespace from this one")

    Set tOrigNS = $NAMESPACE
    Try {
        Set tSwitchSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        Do $$$AssertStatusOK(tSwitchSC, "switch to %SYS")
        Do $$$AssertTrue(##class(Config.MapGlobals).Exists(tHere, "ProbeOcuPilotState*", .tE0, .tS0), "the probe's global mapping exists in this namespace before uninstall")
    } Catch ex0 {
        Set $NAMESPACE = tOrigNS
        Throw ex0
    }
    Set $NAMESPACE = tOrigNS

    Do ##class(OcuPilot.Test.NamespaceProbe).Arm(tOther)
    Try {
        Set tResolved = ##class(OcuPilot.Test.NamespaceProbe).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Test.NamespaceProbe).Uninstall("probe", 1)
    } Catch ex {
        Do ##class(OcuPilot.Test.NamespaceProbe).Reset()
        Throw ex
    }
    Do ##class(OcuPilot.Test.NamespaceProbe).Reset()

    Do $$$AssertEquals(tResolved, tOther, "the armed instance really did resolve a default other than the current namespace")
    Do $$$AssertStatusOK(tSC, "uninstall, dispatched through the armed namespace probe, still succeeds")

    Set tOrigNS2 = $NAMESPACE
    Try {
        Set tSwitchSC2 = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS2)
        Do $$$AssertStatusOK(tSwitchSC2, "switch to %SYS")
        Do $$$AssertTrue('##class(Config.MapGlobals).Exists(tHere, "ProbeOcuPilotState*", .tE1, .tS1), "the mapping is removed from the namespace uninstall was actually called from, not the armed resolved default")
    } Catch ex2 {
        Set $NAMESPACE = tOrigNS2
        Throw ex2
    }
    Set $NAMESPACE = tOrigNS2
}

/// <p>The demo-fixture namespace fix (this story's <code>## Auto Run Result</code>):
/// <method>OcuPilot.Install.Fixture.Create</method> binds fixtures to <code>$NAMESPACE</code>
/// at entry, not to <method>OcuPilot.Install.Installer.ResolveNamespace</method>'s default --
/// otherwise, under <code>OCUPILOT_NAMESPACE</code>, fixtures would be created in, and bound
/// to, a namespace OcuPilot was never installed into.</p>
/// <p><b>Why this is a source pin, not a live one.</b> Every class
/// <method>Create</method> needs -- <class>OcuPilot.Kernel.Utils</class>,
/// <class>OcuPilot.Kernel.State.Demo</class> -- is compiled only into the install namespace
/// (AD-9), which on this instance is also <method>ResolveNamespace</method>'s resolved
/// default: the two spellings coincide wherever this suite can run, so no arrangement of
/// <class>OcuPilot.Test.NamespaceProbe</class> can make a live call to
/// <method>Create</method> observe a divergence (the same limitation this story's own
/// deferred item VG2/IA4 records for <method>Uninstall</method> and
/// <method>StateFingerprint</method>, which this class pins live instead because those two
/// methods need no OcuPilot class from inside the switched region to do it). Reads
/// <class>OcuPilot.Install.Fixture</class>'s own compiled UDL source back through
/// <class>%Compiler.UDL.TextServices</class> (<file>.claude/rules/reference-folders.md</file>'s
/// documented technique for reading a class's source from inside IRIS) rather than the
/// filesystem: the live <code>ocupilot</code> container this suite runs against predates
/// Story 1.4 and mounts no source tree at all (<code>CLAUDE.md</code>'s Container section),
/// so a path under a read-only <code>./src</code> mount is not something this instance can
/// promise.</p>
/// <p>Mutation (Rule 19): change <method>OcuPilot.Install.Fixture.Create</method>'s
/// <code>Set tInstallNs = tOrigNS</code> to
/// <code>Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()</code> --
/// both assertions below go red: the fix's own line is no longer present, and the call this
/// story's Design Notes forbid is.</p>
Method TestFixtureCreateUsesTheCallersNamespaceNotTheResolvedDefault()
{
    Set tClassName = "OcuPilot.Install.Fixture"
    Do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId(tClassName), tClassName _ " must be compiled on this instance")

    Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString(, tClassName, .tText)
    Do $$$AssertStatusOK(tSC, "read " _ tClassName _ "'s own compiled UDL source back")
    Do $$$AssertTrue(tText '= "", tClassName _ " read back non-empty source")

    Set tStart = $Find(tText, "ClassMethod Create(pProfile")
    Do $$$AssertTrue(tStart > 0, tClassName _ " must declare Create(pProfile...)")
    Set tEnd = $Find(tText, "ClassMethod WebAppOwnedByProfile", tStart)
    Do $$$AssertTrue(tEnd > tStart, "Create() must be followed by WebAppOwnedByProfile in source order")
    Set tBody = $Extract(tText, tStart, tEnd - 1)

    Do $$$AssertTrue(tBody [ "Set tInstallNs = tOrigNS", "Create() binds fixtures to $NAMESPACE at entry, not a resolved default")
    ; The method's own comment names ResolveNamespace in prose (explaining what it does NOT
    ; do), so the pin looks for an actual call -- "ResolveNamespace(" -- never the bare word,
    ; which the comment legitimately contains.
    Do $$$AssertTrue((tBody [ "ResolveNamespace(") = 0, "Create() must never call Installer.ResolveNamespace()")
}

}
