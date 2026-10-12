/// <p>Where OcuPilot installs (Story 18.13, AD-17): the namespace a path names holds the profile's
/// global mapping and applications; a second namespace is refused by install and uninstall, naming
/// the first, with nothing changed; a package resolving from another database, an IRIS below the
/// roster's floor and a definition on an unreachable credentials rung are handled at validation.</p>
/// <p><b>It runs OcuPilot's production install and creates a namespace, database, resource and
/// directory, so <method>OnBeforeAllTests</method> refuses unless
/// <parameter>ARMINGVARIABLE</parameter> reads 1.</b> The namespace keeps its routines in the
/// namespace this class runs in and its globals in a database of its own;
/// <method>OnAfterAllTests</method> removes all of it, and each test removes the probe profile from
/// both namespaces and the SQL grant the install left in the chosen one.</p>
Class OcuPilot.Test.InstallTarget Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

/// <p>The chosen namespace, its globals database and the database's guarding resource.</p>
Parameter NAMESPACE = "OCUPROBE1813";

Parameter DATABASE = "OCUPROBE1813";
Parameter RESOURCE = "%DB_OCUPROBE1813";

/// <p>The database's directory name under the manager directory.</p>
Parameter DIRECTORY = "ocuprobe1813";

/// <p>The probe profile's global mapping and database, as install names them.</p>
Parameter PROBEMAPPING = "ProbeOcuPilotState*";

Parameter PROBEDATABASE = "OCUPILOTPROBE";

/// <p>The name of the stored definition the rung leg seeds.</p>
Parameter DEFINITIONNAME = "OcuProbe1813Creds";

/// <p>The stored definition on another rung, which the rung leg must not see named.</p>
Parameter OTHERDEFINITIONNAME = "OcuProbe1813Env";

/// <p>The namespace this class runs in, which holds OcuPilot's code and the production install.
/// The prefix must not begin with "Test" (<file>.claude/rules/objectscript-testing.md</file>).</p>
Property PreparedHome As %String;

/// <p>The id of the seeded definition, or <code>""</code>.</p>
Property PreparedDefinition As %String;

/// <p>The id of the seeded definition on another rung, or <code>""</code>.</p>
Property PreparedOtherDefinition As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedHome = ""
    Set ..PreparedDefinition = ""
    Set ..PreparedOtherDefinition = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InstallTarget runs OcuPilot's PRODUCTION install and creates a namespace and a database, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was installed or created.")
    }
    Set ..PreparedHome = $NAMESPACE
    Do ..RemoveNamespace()
    Quit ..BuildNamespace()
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Set tLeft = ..RemoveNamespace()
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InstallTarget teardown left: " _ tLeft)
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    ; Every install records its stamp through the production privileged application, so production
    ; is primed first, as OcuPilot.Test.Installer does.
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    ; A probe install an earlier run left behind would colour every leg: the namespace holding it
    ; removes it, the other refuses.
    Do ..ProbeRun(..#NAMESPACE, "Uninstall")
    Do ..ProbeRun(..PreparedHome, "Uninstall")
    ; So is a seeded definition an aborted run left: its name is unique.
    For tName = ..#DEFINITIONNAME, ..#OTHERDEFINITIONNAME {
        Set tLeftId = ""
        If $$$ISOK(##class(OcuPilot.Kernel.State.Agent).GuardedByName(tName, .tLeftId)) && (tLeftId '= "") Do ##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(tLeftId)
    }
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    ; Whichever namespace holds the probe removes it; the other refuses, which is the rule under test.
    Do ..ProbeRun(..#NAMESPACE, "Uninstall")
    Do ..ProbeRun(..PreparedHome, "Uninstall")
    Do ..RevokeGrant()
    If ..PreparedDefinition '= "" {
        Do ##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(..PreparedDefinition)
        Set ..PreparedDefinition = ""
    }
    If ..PreparedOtherDefinition '= "" {
        Do ##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(..PreparedOtherDefinition)
        Set ..PreparedOtherDefinition = ""
    }
    Quit $$$OK
}

/// <p>Create the chosen namespace over a database of its own and this class's routines database.</p>
Method BuildNamespace() As %Status
{
    Quit ##class(OcuPilot.Test.ProbeNamespace).Build(..#NAMESPACE, ..#DATABASE, ..#RESOURCE, ..#DIRECTORY, ..PreparedHome)
}

/// <p>Remove what <method>BuildNamespace</method> creates, and answer what is still there.</p>
Method RemoveNamespace() As %String
{
    Quit ##class(OcuPilot.Test.ProbeNamespace).Remove(..#NAMESPACE, ..#DATABASE, ..#RESOURCE, ..#DIRECTORY, ..#PROBEMAPPING _ "," _ ##class(OcuPilot.Kernel.State.Base).#MAPPINGPATTERN)
}

/// <p>The probe profile's application paths, derived from the roster as install derives them.</p>
ClassMethod ProbeApps() As %String
{
    Set tPaths = ""
    If $$$ISERR(##class(OcuPilot.Install.Roster).Get(.tRoster)) Quit ""
    Set tIt = tRoster.applications.%GetIterator()
    While tIt.%GetNext(.tKey, .tApplication) {
        Set tPaths = tPaths _ $Select(tPaths = "": "", 1: ",") _ ##class(OcuPilot.Install.Installer).ProbeApplicationPath(tApplication.path)
    }
    Quit tPaths
}

/// <p>Revoke the SQL grant install makes in the chosen namespace; uninstall leaves it.</p>
Method RevokeGrant()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRole = ##class(OcuPilot.Kernel.State.Base).#DBRESOURCE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "REVOKE SELECT,INSERT,UPDATE,DELETE ON SCHEMA OcuPilot_Kernel_State FROM " _ tRole)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>Run <var>pMethod</var> (<code>Install</code> or <code>Uninstall</code>) for the probe profile
/// from namespace <var>pNs</var>, through the probe subclass, and answer its status. The caller's
/// namespace is restored.</p>
Method ProbeRun(pNs As %String, pMethod As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNs
        If pMethod = "Install" {
            Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
        } Else {
            Set tSC = ##class(OcuPilot.Test.InstallerProbe).Uninstall("probe", 1)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The database <var>pNs</var>'s global mapping <var>pPattern</var> targets, or <code>""</code>.</p>
Method MappingDatabase(pNs As %String, pPattern As %String) As %String
{
    Set tDatabase = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If ##class(Config.MapGlobals).Exists(pNs, pPattern, .tMapping) Set tDatabase = tMapping.Database
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tDatabase = "(unreadable)"
    }
    Set $NAMESPACE = tOrigNS
    Quit tDatabase
}

/// <p>The namespace web application <var>pPath</var> runs in, or <code>""</code> when it is absent.</p>
Method ApplicationNamespace(pPath As %String) As %String
{
    Set tNs = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If ##class(Security.Applications).Exists(pPath) {
            Set tSC = ##class(Security.Applications).Get(pPath, .tProps)
            Set tNs = $Get(tProps("NameSpace"))
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tNs = "(unreadable)"
    }
    Set $NAMESPACE = tOrigNS
    Quit tNs
}

/// <p>How many <code>Stamp</code> or <code>Version</code> rows the probe profile has in
/// <var>pNs</var>'s globals, where its rows land when the namespace has no production mapping.</p>
Method ProbeRows(pNs As %String, pTable As %String) As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNs
        Set tSql = $Select(pTable = "Stamp": "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Stamp WHERE Profile = 'probe'", 1: "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Version WHERE Profile = 'probe'")
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSql)
        If tRS.%Next() Set tCount = tRS.%GetData(1)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p><method>OcuPilot.Install.Installer.StateFingerprint</method> of <var>pProfile</var> in <var>pNs</var>.</p>
Method Fingerprint(pNs As %String, pProfile As %String = "probe") As %String
{
    Set tFingerprint = "(unreadable)"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNs
        Set tFingerprint = ##class(OcuPilot.Install.Installer).StateFingerprint(pProfile)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Set $NAMESPACE = tOrigNS
    Quit tFingerprint
}

/// <p>Assert nothing of the probe profile remains in <var>pNs</var>: no mapping, no application.</p>
Method AssertProbeAbsent(pNs As %String, pWhat As %String)
{
    Do $$$AssertEquals(..MappingDatabase(pNs, ..#PROBEMAPPING), "", pWhat _ ": no probe mapping in " _ pNs)
    Set tApps = ..ProbeApps()
    Do $$$AssertTrue(tApps '= "", pWhat _ ": the roster derives the probe's applications")
    For tI = 1:1:$Length(tApps, ",") {
        Set tPath = $Piece(tApps, ",", tI)
        Do $$$AssertNotEquals(..ApplicationNamespace(tPath), pNs, pWhat _ ": " _ tPath _ " does not run in " _ pNs)
    }
}

/// <p><b>The namespace a path names is the target.</b> Install in the chosen namespace maps the
/// profile's globals there and runs its applications there; a second run leaves the fingerprint
/// equal and adds only its own stamp; uninstall from there removes both.</p>
Method TestTheChosenNamespaceHoldsTheMappingAndTheApplications()
{
    Set tT = ..#NAMESPACE
    Do ..AssertProbeAbsent(..PreparedHome, "before the install")
    Set tStampsBefore = ..ProbeRows(tT, "Stamp")
    Do $$$AssertTrue(tStampsBefore >= 0, "the chosen namespace's stamps read: " _ tStampsBefore)
    Do $$$AssertStatusOK(..ProbeRun(tT, "Install"), "install runs in the chosen namespace")
    Do $$$AssertEquals(..MappingDatabase(tT, ..#PROBEMAPPING), ..#PROBEDATABASE, "the chosen namespace maps the profile's globals onto the profile's database")
    Do $$$AssertEquals(..MappingDatabase(..PreparedHome, ..#PROBEMAPPING), "", "and the namespace production runs in maps none")
    Set tApps = ..ProbeApps()
    For tI = 1:1:$Length(tApps, ",") {
        Set tPath = $Piece(tApps, ",", tI)
        Do $$$AssertEquals(..ApplicationNamespace(tPath), tT, tPath _ " runs in the chosen namespace")
    }

    Set tFingerprint = ..Fingerprint(tT)
    Set tStamps = ..ProbeRows(tT, "Stamp")
    Set tVersions = ..ProbeRows(tT, "Version")
    Do $$$AssertEquals(tStamps, tStampsBefore + 1, "the first run recorded its stamp")
    Do $$$AssertStatusOK(..ProbeRun(tT, "Install"), "a second run completes")
    Do $$$AssertEquals(..Fingerprint(tT), tFingerprint, "and leaves the state fingerprint unchanged")
    Do $$$AssertEquals(..ProbeRows(tT, "Stamp"), tStamps + 1, "the only new row is that run's stamp")
    Do $$$AssertEquals(..ProbeRows(tT, "Version"), tVersions, "the version row is the same one")

    Do $$$AssertStatusOK(..ProbeRun(tT, "Uninstall"), "uninstall from the chosen namespace completes")
    Do ..AssertProbeAbsent(tT, "after the uninstall")
}

/// <p><b>One install namespace per instance.</b> With the profile installed in the namespace
/// production runs in, install and uninstall from the chosen namespace are each refused naming the
/// first and the remedy, and the guard refuses the same way for production's own names (an
/// <code>Install("")</code> from here would move the production install, were the guard missing, so
/// the guard is called directly). Nothing changes in either namespace.</p>
Method TestASecondNamespaceIsRefusedAndNothingChanges()
{
    Set tT = ..#NAMESPACE
    Set tHome = ..PreparedHome
    Do $$$AssertStatusOK(..ProbeRun(tHome, "Install"), "the profile is installed in the namespace production runs in")
    Set tHomeFingerprint = ..Fingerprint(tHome)
    Set tProductionFingerprint = ..Fingerprint(tHome, "")
    Set tStamps = ..ProbeRows(tT, "Stamp")
    Set tVersions = ..ProbeRows(tT, "Version")
    Do $$$AssertTrue((tStamps >= 0) && (tVersions >= 0), "the chosen namespace's rows read: " _ tStamps _ ", " _ tVersions)
    Do ..AssertRefusal(..ProbeRun(tT, "Install"), "Install from a second namespace")
    Do ..AssertRefusal(..ProbeRun(tT, "Uninstall"), "Uninstall from a second namespace")

    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = tT
    Set tNames("mappingPattern") = ##class(OcuPilot.Kernel.State.Base).#MAPPINGPATTERN
    Set tNames("database") = ##class(OcuPilot.Kernel.State.Base).#DATABASENAME
    Set tGuardSC = ##class(OcuPilot.Test.InstallerProbe).GuardOneInstallNamespace("Install", .tNames, tT)
    Set $NAMESPACE = tOrigNS
    Do ..AssertRefusal(tGuardSC, "the guard, for production's own mapping held in " _ tHome)

    ; The IPM manifest's guard invoke asks the same questions for production, changing nothing.
    Set $NAMESPACE = tT
    Set tTargetSC = ##class(OcuPilot.Install.Installer).GuardTarget()
    Set $NAMESPACE = tHome
    Set tHomeTargetSC = ##class(OcuPilot.Install.Installer).GuardTarget()
    Set $NAMESPACE = tOrigNS
    Do ..AssertRefusal(tTargetSC, "the IPM guard invoke")
    Do $$$AssertStatusOK(tHomeTargetSC, "and passes in the namespace that holds the install")

    Do $$$AssertEquals(..Fingerprint(tHome), tHomeFingerprint, "the profile's state in " _ tHome _ " is unchanged")
    Do $$$AssertEquals(..Fingerprint(tHome, ""), tProductionFingerprint, "and so is production's")
    Do $$$AssertEquals(..MappingDatabase(tHome, ##class(OcuPilot.Kernel.State.Base).#MAPPINGPATTERN), ##class(OcuPilot.Kernel.State.Base).#DATABASENAME, "production's mapping is still where it was")
    Do ..AssertProbeAbsent(tT, "after the refusals")
    Do $$$AssertEquals(..MappingDatabase(tT, ##class(OcuPilot.Kernel.State.Base).#MAPPINGPATTERN), "", "the chosen namespace gained no production mapping")
    Do $$$AssertEquals(..ProbeRows(tT, "Stamp"), tStamps, "no stamp was written there")
    Do $$$AssertEquals(..ProbeRows(tT, "Version"), tVersions, "and no version row")
}

/// <p><b>A namespace that holds the mapping itself is not refused for another holder</b>, as an
/// earlier release could leave an instance: with the profile installed in the namespace production
/// runs in and its pattern mapped onto its database in the chosen namespace too, the guard passes in
/// each, so either can be upgraded or uninstalled.</p>
Method TestANamespaceHoldingTheMappingItselfIsNotRefused()
{
    Set tT = ..#NAMESPACE
    Do $$$AssertStatusOK(..ProbeRun(..PreparedHome, "Install"), "the profile is installed in the namespace production runs in")
    Set tMapSC = ##class(OcuPilot.Test.ProbeNamespace).SetMapping(tT, ..#PROBEMAPPING, ..#PROBEDATABASE)
    Set tOrigNS = $NAMESPACE
    Set tNames("mappingPattern") = ..#PROBEMAPPING
    Set tNames("database") = ..#PROBEDATABASE
    Set $NAMESPACE = tT
    Set tSecondSC = ##class(OcuPilot.Test.InstallerProbe).GuardOneInstallNamespace("Install", .tNames, tT)
    Set $NAMESPACE = tOrigNS
    Set tFirstSC = ##class(OcuPilot.Test.InstallerProbe).GuardOneInstallNamespace("Uninstall", .tNames, tOrigNS)
    Do ##class(OcuPilot.Test.ProbeNamespace).SetMapping(tT, ..#PROBEMAPPING, "")
    Do $$$AssertStatusOK(tMapSC, "the chosen namespace is given the profile's mapping too")
    Do $$$AssertStatusOK(tSecondSC, "the guard passes in the chosen namespace, which holds it: " _ $System.Status.GetErrorText(tSecondSC))
    Do $$$AssertStatusOK(tFirstSC, "and in the first, beside it: " _ $System.Status.GetErrorText(tFirstSC))
}

/// <p>Assert <var>pStatus</var> refuses, naming the namespace that holds the install and the remedy.</p>
Method AssertRefusal(pStatus As %Status, pWhat As %String)
{
    Do $$$AssertStatusNotOK(pStatus, pWhat _ " is refused")
    Set tText = $System.Status.GetErrorText(pStatus)
    Do $$$AssertTrue(tText [ ("'" _ ..PreparedHome _ "'"), pWhat _ " names " _ ..PreparedHome _ ": " _ tText)
    Do $$$AssertTrue(tText [ "uninstall OcuPilot there first with ##class(OcuPilot.Install.Installer).Uninstall(", pWhat _ " names the remedy: " _ tText)
}

/// <p><b>The package must resolve from the namespace's own routine database (AD-9).</b> A foreign
/// destination is refused naming both, and nothing is written. The namespace's real destination
/// passes.</p>
Method TestAPackageResolvedFromAnotherDatabaseIsRefused()
{
    Set tT = ..#NAMESPACE
    Set tForeign = "^/elsewhere/other/"
    Do ##class(OcuPilot.Test.InstallerProbe).SetPackageDestination(tForeign)
    Set tSC = ..ProbeRun(tT, "Install")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusNotOK(tSC, "install is refused where the package resolves from another database")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue(tText [ tForeign, "the refusal names the package's destination: " _ tText)
    Do $$$AssertTrue(tText [ ##class(%SYS.Namespace).GetRoutineDest(tT), "and the namespace's own routine database: " _ tText)
    Do ..AssertProbeAbsent(tT, "after the refusal")
    Do $$$AssertEquals(..ProbeRows(tT, "Version"), 0, "no version row was written")

    ; The IPM manifest's guard invoke, run in the namespace that holds the install, asks it too.
    Do ##class(OcuPilot.Test.InstallerProbe).SetPackageDestination(tForeign)
    Set tTargetSC = ##class(OcuPilot.Test.InstallerProbe).GuardTarget()
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusNotOK(tTargetSC, "the IPM guard invoke refuses a package that resolves from another database")
    Do $$$AssertTrue($System.Status.GetErrorText(tTargetSC) [ tForeign, "naming its destination: " _ $System.Status.GetErrorText(tTargetSC))

    ; A destination that cannot be read is refused, not waved through.
    Do ##class(OcuPilot.Test.InstallerProbe).SetPackageDestination("")
    Set tUnreadable = ##class(OcuPilot.Test.InstallerProbe).GuardPackageHome("Install", ..PreparedHome)
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusNotOK(tUnreadable, "an unreadable package destination is refused")

    Set $NAMESPACE = tT
    Set tReal = ##class(OcuPilot.Install.Installer).GuardPackageHome("Install", tT)
    Set $NAMESPACE = ..PreparedHome
    Do $$$AssertStatusOK(tReal, "the namespace's real package destination passes")
}

/// <p><b>The installer enforces the roster's IRIS floor (DW-1333)</b>, comparing numbers piece by
/// piece. Below it install is refused naming both versions and writes nothing; at it, above it and
/// at a higher minor with more digits it passes; uninstall is not gated.</p>
Method TestAnInstanceBelowTheFloorIsRefused()
{
    Set tT = ..#NAMESPACE
    Do ##class(OcuPilot.Install.Roster).Get(.tRoster)
    Set tFloor = $Extract(tRoster.systemRequirements.version, 3, *)
    Set tMajor = +$Piece(tFloor, ".", 1)
    Set tMinor = +$Piece(tFloor, ".", 2)
    Set tBelow = $Select(tMinor > 0: tMajor _ "." _ (tMinor - 1), 1: (tMajor - 1) _ ".9")
    Do ##class(OcuPilot.Test.InstallerProbe).SetInstanceVersion(tBelow)
    Set tSC = ..ProbeRun(tT, "Install")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusNotOK(tSC, "install is refused on " _ tBelow _ ", below the roster's " _ tFloor)
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue((tText [ tBelow) && (tText [ tFloor), "the refusal names both versions: " _ tText)
    Do ..AssertProbeAbsent(tT, "after the refusal")
    Do $$$AssertEquals(..ProbeRows(tT, "Version"), 0, "no version row was written")

    ; The IPM manifest's guard invoke, run in the namespace that holds the install, asks it too.
    Do ##class(OcuPilot.Test.InstallerProbe).SetInstanceVersion(tBelow)
    Set tTargetSC = ##class(OcuPilot.Test.InstallerProbe).GuardTarget()
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusNotOK(tTargetSC, "the IPM guard invoke refuses " _ tBelow _ " too")
    Do $$$AssertTrue($System.Status.GetErrorText(tTargetSC) [ tFloor, "naming the floor: " _ $System.Status.GetErrorText(tTargetSC))

    ; A version that cannot be read is refused, not waved through.
    Do ##class(OcuPilot.Test.InstallerProbe).SetInstanceVersion("")
    Set tUnreadable = ##class(OcuPilot.Test.InstallerProbe).GuardVersionFloor("Install")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusNotOK(tUnreadable, "an unreadable instance version is refused")
    Do $$$AssertTrue($System.Status.GetErrorText(tUnreadable) [ "version unreadable", "saying so: " _ $System.Status.GetErrorText(tUnreadable))

    For tPasses = tFloor, tMajor _ "." _ (tMinor + 8), (tMajor + 1) _ ".1" {
        Do ##class(OcuPilot.Test.InstallerProbe).SetInstanceVersion(tPasses)
        Set tGuardSC = ##class(OcuPilot.Test.InstallerProbe).GuardVersionFloor("Install")
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Do $$$AssertStatusOK(tGuardSC, tPasses _ " meets the floor " _ tFloor)
    }

    Do $$$AssertStatusOK(..ProbeRun(tT, "Install"), "install runs on this instance's own version")
    Do ##class(OcuPilot.Test.InstallerProbe).SetInstanceVersion(tBelow)
    Set tUninstallSC = ..ProbeRun(tT, "Uninstall")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do $$$AssertStatusOK(tUninstallSC, "uninstall is not gated by the floor")
    Do ..AssertProbeAbsent(tT, "after the uninstall")
}

/// <p><b>A definition on a credentials rung the namespace cannot reach is reported, never
/// refused.</b> Where the rung reads unavailable, install succeeds and warns naming the stored
/// definition; where it reads available, nothing names it; a store that cannot be read is a warn
/// and install still succeeds. Run in the namespace production runs in, whose
/// <code>OcuPilot*</code> mapping is where the definition is stored.</p>
Method TestACredsDefinitionIsReportedWhereTheRungIsUnavailable()
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = ..#DEFINITIONNAME
    Set tRow.Provider = "anthropic"
    Set tRow.Model = "probe"
    Set tRow.CredType = "creds"
    Set tRow.CredentialName = ..#DEFINITIONNAME _ "Key"
    Set tCreateSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
    Do $$$AssertStatusOK(tCreateSC, "a definition on the creds rung is stored")
    If $$$ISERR(tCreateSC) Quit
    Set ..PreparedDefinition = tRow.%Id()
    Set tRow = ""

    ; A definition on another rung is stored beside it and must not be named.
    Set tOther = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tOther.Name = ..#OTHERDEFINITIONNAME
    Set tOther.Provider = "anthropic"
    Set tOther.Model = "probe"
    Set tOther.CredType = "env"
    Set tOther.EnvVarName = "OCUPROBE1813_KEY"
    Set tOtherSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tOther)
    Do $$$AssertStatusOK(tOtherSC, "a definition on the env rung is stored beside it")
    If $$$ISOK(tOtherSC) Set ..PreparedOtherDefinition = tOther.%Id()
    Set tOther = ""

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do ##class(OcuPilot.Test.InstallerProbe).SetRungAvailable(0)
    Do $$$AssertStatusOK(..ProbeRun(..PreparedHome, "Install"), "install succeeds where the rung is unavailable")
    Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
    Do $$$AssertTrue(tWarns [ ..#DEFINITIONNAME, "a warning names the definition: " _ tWarns)
    Do $$$AssertEquals(tWarns [ ..#OTHERDEFINITIONNAME, 0, "and none names the definition on the env rung")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do ##class(OcuPilot.Test.InstallerProbe).SetRungAvailable(1)
    Do $$$AssertStatusOK(..ProbeRun(..PreparedHome, "Install"), "install succeeds where the rung is available")
    Do $$$AssertEquals(##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn") [ ..#DEFINITIONNAME, 0, "and nothing names the definition")

    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do ##class(OcuPilot.Test.InstallerProbe).SetRungAvailable(0)
    Do ##class(OcuPilot.Test.InstallerProbe).SetDefinitionsUnreadable(1)
    Do $$$AssertStatusOK(..ProbeRun(..PreparedHome, "Install"), "install succeeds when the stored definitions cannot be read")
    Do $$$AssertTrue(##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn") [ "could not be read", "and warns that they could not be read")
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
}

/// <p><b>The installer's rung predicate is the ladder's own</b>, asked of the namespace it runs in:
/// unarmed, it answers what <method>OcuPilot.Kernel.Secret.Ladder.CredentialsRungAvailable</method>
/// answers in the namespace production runs in and in the chosen namespace, which is not
/// interoperability-enabled and so reads 0.</p>
Method TestTheInstallersRungPredicateIsTheLaddersOwn()
{
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Set tOrigNS = $NAMESPACE
    For tNs = ..PreparedHome, ..#NAMESPACE {
        Set $NAMESPACE = tNs
        Set tInstaller = ##class(OcuPilot.Test.InstallerProbe).CredentialsRungAvailable()
        Set tLadder = ##class(OcuPilot.Kernel.Secret.Ladder).CredentialsRungAvailable()
        Set $NAMESPACE = tOrigNS
        Do $$$AssertEquals(tInstaller, tLadder, "the installer's rung predicate is the ladder's own in " _ tNs)
        If tNs = ..#NAMESPACE Do $$$AssertEquals(tLadder, 0, "and the chosen namespace, without interoperability, reads 0")
    }
}

}
