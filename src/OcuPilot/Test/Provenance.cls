/// <p>The web-application provenance record (Story 1.17, DW-94, the owner's decision of
/// 2026-09-11): install refuses to adopt an application it did not put at one of its own
/// paths, and uninstall removes only what the record says install created.</p>
/// <p>Every <b>assertion</b> here runs against the disposable <code>"probe"</code> profile,
/// whose application paths are derived literals distinct from production's
/// (<method>OcuPilot.Install.Installer.ProbeApplicationPath</method>), so nothing this class
/// creates, refuses or removes can reach <code>/ocupilot</code>, <code>/api/ocupilot</code> or
/// the production readiness application.</p>
/// <p><b>The one step outside that scope is <method>OnBeforeOneTest</method>, which runs a
/// production <method>Install</method> first.</b> It has to: the probe profile's protected
/// database is created through production's own escalated routine application, so a probe
/// install on an instance where production was never installed has nothing to escalate through.
/// A production install is idempotent by construction (AD-17) and repairs rather than creates on
/// any instance already installed, which every other install-time class in this suite relies on
/// too.</p>
Class OcuPilot.Test.Provenance Extends %UnitTest.TestCase
{

/// <p>The probe profile's readiness path -- the third and last application install ensures, so
/// a conflict there is the case that proves the refusal happens <b>before</b> anything is
/// created rather than after the first two already were.</p>
Parameter PROBEREADINESS As %String = "/api/probeocupilot/readiness";

/// <p>The probe profile's shell path.</p>
Parameter PROBESHELL As %String = "/probeocupilot";

/// <p>A dispatch class that is not the one the roster declares for any OcuPilot application --
/// what "somebody else's application" looks like. <class>%CSP.REST</class> itself, so the
/// application this class creates is a real, loadable one rather than a broken stub.</p>
Parameter FOREIGNCLASS As %String = "%CSP.REST";

Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Quit ..CleanProbe()
}

Method OnAfterOneTest() As %Status
{
    Quit ..CleanProbe()
}

/// <p>Return the instance to "the probe profile is not installed and nothing of its own is on
/// the instance", whatever state a test left it in.</p>
/// <p><b>The hand-removal after the uninstall is the point.</b> These tests deliberately delete
/// provenance rows, and uninstall removes only what a row records -- so an application whose row
/// a test removed survives the uninstall by design, and would then be the thing the next test
/// mistakes for its own leftovers. Every probe application the roster declares is removed by
/// name here, and its record with it, by <method>OcuPilot.Test.ProbeApps.Remove</method>.</p>
Method CleanProbe() As %Status
{
    Quit ##class(OcuPilot.Test.ProbeApps).Remove()
}

/// <p>Create a web application at <var>pPath</var> dispatching to
/// <parameter>FOREIGNCLASS</parameter> -- an application OcuPilot did not create and has no
/// record of. Switches to <code>%SYS</code> and restores (AD-16).</p>
Method CreateForeignApplication(pPath As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Kill tCreate
        Set tCreate("AutheEnabled") = 32
        Set tCreate("DispatchClass") = ..#FOREIGNCLASS
        Set tCreate("Enabled") = 1
        Set tCreate("NameSpace") = tOrigNS
        Set tCreate("Type") = 2
        Set tCreate("Description") = "Not OcuPilot's: a fixture standing in for another product's application"
        Set tSC = ##class(Security.Applications).Create(pPath, .tCreate)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Whether a web application exists at <var>pPath</var>, and its live dispatch class.</p>
Method ApplicationDispatchClass(pPath As %String) As %String
{
    Set tClass = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISOK(tSC), ##class(Security.Applications).Exists(pPath, .tObj, .tExistSC) {
            Set tGetSC = ##class(Security.Applications).Get(pPath, .tProps)
            If $$$ISOK(tGetSC) Set tClass = $Get(tProps("DispatchClass"))
        }
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Set $NAMESPACE = tOrigNS
    Quit tClass
}

/// <p>Whether the profile's protected database exists -- the object install creates first, and
/// so the evidence that a refusal really did create nothing.</p>
Method ProbeDatabaseExists() As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISOK(tSC) Set tExists = ''##class(Config.Databases).Exists("OCUPILOTPROBE", .tObj, .tExistSC)
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Set $NAMESPACE = tOrigNS
    Quit tExists
}

/// <p>DW-94 -- an application at one of the roster's paths that OcuPilot has no record of
/// creating, and that does not dispatch to the class the roster declares, is a refusal naming
/// the path and the conflict. The install creates and repairs <b>nothing</b>: the check is the
/// first act inside the <code>%SYS</code> window, so not even the protected database is
/// made.</p>
/// <p>The conflict is placed at the <b>third</b> application deliberately. Run per application
/// inside the ensure loop, this would be refused only after the first two had been created; the
/// database assertion below is what tells those two orderings apart.</p>
/// <p>Mutation (Rule 19): delete the
/// <method>OcuPilot.Install.Installer.RefuseForeignApplications</method> call from
/// <method>OcuPilot.Install.Installer.Install</method> -- the install succeeds, adopts the
/// foreign application and rewrites it to OcuPilot's asserted properties, so the refusal
/// assertion and the dispatch-class assertion both go red.</p>
Method TestForeignApplicationAtARosterPathIsRefusedAndNothingIsCreated()
{
    Do $$$AssertStatusOK(..CreateForeignApplication(..#PROBEREADINESS), "the fixture application is created at OcuPilot's path")
    Do $$$AssertTrue('..ProbeDatabaseExists(), "and the probe profile is not installed before this run")

    Set tSC = ##class(OcuPilot.Install.Installer).Install("probe")
    Do $$$AssertStatusNotOK(tSC, "install refuses rather than adopting an application it did not create")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue(tText [ ..#PROBEREADINESS, "the refusal names the path: " _ tText)
    Do $$$AssertTrue(tText [ ..#FOREIGNCLASS, "and the dispatch class it found")
    Do $$$AssertTrue(tText [ "OcuPilot.Api.Readiness", "and the one the roster declares")

    Do $$$AssertEquals(..ApplicationDispatchClass(..#PROBEREADINESS), ..#FOREIGNCLASS, "the foreign application is left exactly as it was -- nothing was repaired")
    Do $$$AssertTrue('..ProbeDatabaseExists(), "and nothing was created: the refusal is the first act inside the %SYS window")
    Do $$$AssertEquals(..ApplicationDispatchClass(..#PROBESHELL), "", "not even the first application the loop would have reached")
}

/// <p>DW-94, the other direction -- an application at a roster path that <b>does</b> dispatch to
/// the class the roster declares is OcuPilot's: an install that predates the provenance record,
/// or IPM's own <code>&lt;WebApplication&gt;</code> element, which is generated from this same
/// roster and creates the application in <code>Activate</code> before the
/// <code>When="After"</code> <code>&lt;Invoke&gt;</code> runs install at all. It is recorded and
/// repaired, not refused.</p>
/// <p>Mutation (Rule 19): make
/// <method>OcuPilot.Install.Installer.RefuseForeignApplications</method> refuse on the absence
/// of a record alone, without reading the dispatch class -- this goes red, and so does every
/// install on the live instance and on the IPM path.</p>
Method TestAnApplicationCarryingTheDeclaredDispatchClassIsRecognisedAndRecorded()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "a first probe install succeeds")
    Do $$$AssertEquals(..RecordedOrigin(..#PROBEREADINESS), "created", "install recorded the application it created")

    ; Forget the record, leaving the application exactly where install put it -- the shape an
    ; instance installed before the record existed, and the shape the IPM path produces.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#PROBEREADINESS), "the record is removed, the application is not")
    Do $$$AssertEquals(..RecordedOrigin(..#PROBEREADINESS), "", "so this run starts with no record of it")

    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "install recognises it rather than refusing")
    Do $$$AssertEquals(..RecordedOrigin(..#PROBEREADINESS), "adopted", "and records how it came to know about it")
    Do $$$AssertEquals(..ApplicationDispatchClass(..#PROBEREADINESS), "OcuPilot.Api.Readiness", "the application is still OcuPilot's")
}

/// <p>The origin recorded for <var>pPath</var>, or <code>""</code> when no row exists.</p>
Method RecordedOrigin(pPath As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.State.WebApp).GuardedForPath(pPath, .tRow)
    If $$$ISERR(tSC) Quit ""
    If '$IsObject(tRow) Quit ""
    Quit tRow.Origin
}

/// <p>DW-94 -- uninstall removes every application the record says install created, and leaves
/// one it has no record of exactly where it is, reporting it. "Uninstall removes only what
/// install created" is the promise; an application some other product owns surviving an
/// OcuPilot uninstall is the thing it promises.</p>
/// <p>Mutation (Rule 19): make
/// <method>OcuPilot.Install.Installer.Uninstall</method> delete every roster path it finds,
/// ignoring <code>tRecorded</code> -- the survivor assertion goes red and the warn assertion
/// goes red with it.</p>
Method TestUninstallRemovesOnlyWhatInstallCreatedAndReportsTheRest()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "a probe install succeeds")
    Do $$$AssertEquals(..ApplicationDispatchClass(..#PROBESHELL), "OcuPilot.Api.StaticHandler", "the shell application exists")
    Do $$$AssertEquals(..ApplicationDispatchClass(..#PROBEREADINESS), "OcuPilot.Api.Readiness", "and so does the readiness application")

    ; Forget one application's record while leaving the application in place: from uninstall's
    ; point of view that is an application it has no evidence of having created.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#PROBEREADINESS), "one provenance record is removed")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Uninstall("probe", 1)
    Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAllWithData("warn")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()

    Do $$$AssertStatusOK(tSC, "uninstall succeeds: an application it never recorded is not a failure")
    Do $$$AssertEquals(..ApplicationDispatchClass(..#PROBESHELL), "", "everything install recorded is removed")
    Do $$$AssertEquals(..ApplicationDispatchClass(..#PROBEREADINESS), "OcuPilot.Api.Readiness", "and the one it has no record of is left in place")
    Do $$$AssertTrue(tWarns [ "no record of install having created it", "which is reported rather than done silently")
    Do $$$AssertTrue(tWarns [ ..#PROBEREADINESS, "and the report names it")
}

/// <p>DW-94 -- an application uninstall leaves in place keeps its <b>matching role</b>, not just
/// its existence. Deleting a role strips the name from every application still matching it, so
/// removing the role of an application this run deliberately kept would take that application's
/// AD-21 privilege floor with it: an anonymous caller would then get 500 and a
/// <code>&lt;PROTECT&gt;</code> naming the database directory. "Left in place and reported" has
/// to mean still working.</p>
/// <p>Mutation (Rule 19): drop the <code>'$Data(tRemovedKeys(tRKey)) Continue</code> guard from
/// <method>OcuPilot.Install.Installer.Uninstall</method>'s role loop -> the kept application's
/// <code>MatchRoles</code> comes back empty and this goes red.</p>
Method TestUninstallLeavesAKeptApplicationsPrivilegeFloorIntact()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "a probe install succeeds")
    Do $$$AssertEquals(..MatchRolesOf(..#PROBEREADINESS), ":ProbeOcuPilotReadiness", "the readiness application carries its floor")

    ; Forget its record, so uninstall has no evidence it created this application.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#PROBEREADINESS), "one provenance record is removed")

    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Uninstall("probe", 1), "uninstall succeeds")

    Do $$$AssertEquals(..ApplicationDispatchClass(..#PROBEREADINESS), "OcuPilot.Api.Readiness", "the unrecorded application is still there")
    Do $$$AssertEquals(..MatchRolesOf(..#PROBEREADINESS), ":ProbeOcuPilotReadiness", "and still carries the matching role it needs to answer at all")
}

/// <p>The live <code>MatchRoles</code> of the application at <var>pPath</var>, or
/// <code>""</code>. Switches to <code>%SYS</code> and restores (AD-16).</p>
Method MatchRolesOf(pPath As %String) As %String
{
    Set tRoles = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISOK(tSC), ##class(Security.Applications).Exists(pPath, .tObj, .tExistSC) {
            Set tGetSC = ##class(Security.Applications).Get(pPath, .tProps)
            If $$$ISOK(tGetSC) Set tRoles = $Get(tProps("MatchRoles"))
        }
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Set $NAMESPACE = tOrigNS
    Quit tRoles
}

/// <p>DW-94 -- a repeat install over an instance it already recorded neither refuses nor
/// re-records: the origin stays what it was, so the record is a fact about how the application
/// arrived rather than about the last run.</p>
Method TestARepeatInstallDoesNotRewriteTheRecord()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "a first probe install succeeds")
    Do $$$AssertEquals(..RecordedOrigin(..#PROBESHELL), "created", "recorded as created")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "a repeat install succeeds")
    Do $$$AssertEquals(..RecordedOrigin(..#PROBESHELL), "created", "and the origin is unchanged")
}

/// <p>DW-242 -- the leftover check the CI runner reads after every class
/// (<method>OcuPilot.Test.ProbeApps.Existing</method>) sees every application a probe install
/// records, checked against install's own provenance rows rather than against the roster walk it
/// shares with <method>OcuPilot.Test.ProbeApps.Remove</method>; and removal clears an application
/// whose row was deleted, and that application's matching role, which a plain uninstall leaves
/// behind.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Test.ProbeApps.Paths</method> skip the last roster
/// key -> the first equality goes red; drop the role delete from
/// <method>OcuPilot.Test.ProbeApps.Remove</method> -> the last assertion goes red.</p>
Method TestTheLeftoverCheckSeesEveryRecordedProbeApplication()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "a probe install succeeds")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).GuardedPathsForProfile("probe", .tRecorded), "the probe profile's records are read")
    Set tExpected = ""
    Set tPath = ""
    For {
        Set tPath = $Order(tRecorded(tPath))
        If tPath = "" Quit
        Set tExpected = tExpected _ $Select(tExpected = "": "", 1: " ") _ tPath
    }
    Do $$$AssertTrue(tExpected '= "", "install recorded at least one probe application")
    Set tExisting = ##class(OcuPilot.Test.ProbeApps).Existing()
    For tI = 1:1:$Length(tExisting, " ") {
        If $Piece(tExisting, " ", tI) '= "" Set tSeen($Piece(tExisting, " ", tI)) = ""
    }
    Set tActual = ""
    Set tPath = ""
    For {
        Set tPath = $Order(tSeen(tPath))
        If tPath = "" Quit
        Set tActual = tActual _ $Select(tActual = "": "", 1: " ") _ tPath
    }
    Do $$$AssertEquals(tActual, tExpected, "the leftover check reports every application install recorded")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(..#PROBEREADINESS), "one provenance record is removed")
    Do $$$AssertTrue(..RoleExists("ProbeOcuPilotReadiness"), "install created the readiness application's matching role")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProbeApps).Remove(), "removal succeeds")
    Do $$$AssertEquals(..ApplicationDispatchClass(..#PROBEREADINESS), "", "the application whose record was removed is gone too")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProbeApps).Existing(), "", "and the leftover check reports none")
    Do $$$AssertTrue('..RoleExists("ProbeOcuPilotReadiness"), "and that application's matching role is gone with it")
}

/// <p>Whether the role <var>pRole</var> exists. Switches to <code>%SYS</code> and restores
/// (AD-16).</p>
Method RoleExists(pRole As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISOK(tSC) Set tExists = ''##class(Security.Roles).Exists(pRole)
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Set $NAMESPACE = tOrigNS
    Quit tExists
}

}
