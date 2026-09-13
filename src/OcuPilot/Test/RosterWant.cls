/// <p>(QA) DW-194. <method>OcuPilot.Install.Installer.WantFromRoster</method>'s three
/// refusal branches and <method>OcuPilot.Install.Installer.ApplicationFingerprint</method>'s
/// <code>NOPROPERTIES</code> guard shipped with this story's own review recording that
/// neither had a test, because both methods were <code>[ Private ]</code>. Both are now
/// Public for exactly this reason (the same documented deviation
/// <method>OcuPilot.Install.Installer.EnsureGrant</method> already carries), so this class
/// drives each branch directly with hand-built arrays -- no install, no namespace switch,
/// no instance state at all: <method>WantFromRoster</method> only ever reads the
/// <var>pNames</var>/<var>pComputed</var> arrays a caller hands it, and the
/// <code>NOPROPERTIES</code> guard returns before <method>ApplicationFingerprint</method>
/// ever touches <code>Security.Applications</code>.</p>
Class OcuPilot.Test.RosterWant Extends %UnitTest.TestCase
{

/// <p>A property the roster declares under <b>both</b> <code>manifest</code> and
/// <code>installer</code> for the same application is refused, naming the property and the
/// application -- <method>OcuPilot.Install.Installer.WantFromRoster</method>'s first
/// refusal branch.</p>
/// <p>Mutation (Rule 19): delete this branch's <code>If $Data(pWant(tName))</code> guard --
/// the call returns <code>$$$OK</code> and <var>tWant</var> silently keeps the instance-derived
/// value in place of the manifest one, both assertions below going red.</p>
Method TestRefusesAPropertyDeclaredAsBothManifestAndInstaller()
{
    Kill tNames, tComputed, tWant, tDescription
    Set tNames("appManifest", "shell", "Path") = "/wrong"
    Set tNames("appInstaller", "shell", "Path") = ""
    Set tComputed("Path") = "/right"

    Set tSC = ##class(OcuPilot.Install.Installer).WantFromRoster(.tNames, "shell", .tComputed, .tWant, .tDescription)
    Do $$$AssertStatusNotOK(tSC, "a property declared on both halves is refused")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue(tText [ "both as a manifest value and as instance-derived", "the refusal names the conflict: " _ tText)
    Do $$$AssertTrue(tText [ "'Path'", "the refusal names the property: " _ tText)
}

/// <p>A property the roster's <code>installer</code> list marks instance-derived, for which
/// <method>OcuPilot.Install.Installer.EnsureApplications</method> computed no value, is
/// refused -- the second
/// refusal branch.</p>
/// <p>Mutation (Rule 19): change the guard's <code>'$Data(pComputed(tName))</code> to
/// <code>$Data(pComputed(tName))</code> (inverted) -- the refusal never fires and
/// <var>pWant</var> is instead built with an undefined array reference, red.</p>
Method TestRefusesAnInstallerPropertyWithNoComputedValue()
{
    Kill tNames, tComputed, tWant, tDescription
    Set tNames("appInstaller", "shell", "MatchRoles") = ""

    Set tSC = ##class(OcuPilot.Install.Installer).WantFromRoster(.tNames, "shell", .tComputed, .tWant, .tDescription)
    Do $$$AssertStatusNotOK(tSC, "an instance-derived property with no computed value is refused")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue(tText [ "and install computed no value for it", "the refusal says why: " _ tText)
    Do $$$AssertTrue(tText [ "'MatchRoles'", "the refusal names the property: " _ tText)
}

/// <p>A value <method>OcuPilot.Install.Installer.EnsureApplications</method>
/// computed that the roster's <code>installer</code> list does not name is refused -- the
/// third refusal branch. This is what keeps a name added to the computed set from silently
/// widening what an application asserts without a matching roster edit.</p>
/// <p>Mutation (Rule 19): delete this branch entirely -- the loop then validates nothing for
/// that name and the value is silently <b>dropped</b> rather than folded into <var>pWant</var>
/// (only the roster-declared names are written), so an application asserts one property fewer
/// than the computed set intended and nothing says so. This test's status and error-text
/// assertions go red.</p>
Method TestRefusesAComputedValueTheRosterDoesNotMarkInstanceDerived()
{
    Kill tNames, tComputed, tWant, tDescription
    Set tNames("appManifest", "shell", "Enabled") = 1
    Set tComputed("NameSpace") = "HSCUSTOM"

    Set tSC = ##class(OcuPilot.Install.Installer).WantFromRoster(.tNames, "shell", .tComputed, .tWant, .tDescription)
    Do $$$AssertStatusNotOK(tSC, "a computed value the roster does not mark instance-derived is refused")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue(tText [ "which the roster does not mark instance-derived", "the refusal says why: " _ tText)
    Do $$$AssertTrue(tText [ "'NameSpace'", "the refusal names the property: " _ tText)
}

/// <p>The success path, for contrast with the three refusals above: a manifest value and an
/// instance-derived one, correctly declared, resolve into one <var>pWant</var> set and the
/// roster's own description.</p>
Method TestResolvesTheUnionWhenManifestAndInstallerAgree()
{
    Kill tNames, tComputed, tWant, tDescription
    Set tNames("appManifest", "shell", "Enabled") = 1
    Set tNames("appInstaller", "shell", "NameSpace") = ""
    Set tNames("appDescription", "shell") = "test application"
    Set tComputed("NameSpace") = "HSCUSTOM"

    Set tSC = ##class(OcuPilot.Install.Installer).WantFromRoster(.tNames, "shell", .tComputed, .tWant, .tDescription)
    Do $$$AssertStatusOK(tSC, "a manifest value and a correctly-declared instance-derived value resolve together")
    Do $$$AssertEquals(tWant("Enabled"), 1, "the manifest value is carried through")
    Do $$$AssertEquals(tWant("NameSpace"), "HSCUSTOM", "the computed value is carried through under its roster-declared name")
    Do $$$AssertEquals(tDescription, "test application", "the roster's own description is returned")
}

/// <p>DW-194. <method>OcuPilot.Install.Installer.ApplicationFingerprint</method>'s
/// <code>NOPROPERTIES</code> guard: an empty asserted-property set contributes the literal
/// string <code>NOPROPERTIES</code>, never an empty component, so "nothing was compared"
/// can never compare equal to, and so be misread as, "the application is absent" (an
/// absent application also contributes <code>""</code>). Called with a path that does not
/// exist on any instance -- the guard returns before <code>Security.Applications</code> is
/// ever touched, so this needs no <code>%SYS</code> switch.</p>
/// <p>Mutation (Rule 19): delete the <code>If pProperties = "" Quit "NOPROPERTIES"</code>
/// guard -- an empty property set then falls through to the absent-application check and
/// returns <code>""</code>, red.</p>
Method TestApplicationFingerprintReportsNoPropertiesRatherThanAnEmptyComponent()
{
    Do $$$AssertEquals(##class(OcuPilot.Install.Installer).ApplicationFingerprint("/does-not-exist-on-any-instance-rosterwant", ""), "NOPROPERTIES", "an empty asserted-property set contributes the constant NOPROPERTIES, not an empty component")
}

}
