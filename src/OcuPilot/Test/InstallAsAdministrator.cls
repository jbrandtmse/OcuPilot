/// <p>The install, upgrade and uninstall of the probe profile complete as an installer who holds neither
/// <code>%All</code> nor <code>OcuPilotAdmin</code>, now that the install-owned stores refuse a caller who is not an
/// administrator (AD-9). The installer's steps that write those stores run through the one frame
/// <method>OcuPilot.Install.Installer.AsAdministrator</method> gives them, so the install records its application
/// provenance, its stamp and its version row, an upgrade keys a stored proposal that lacks its target key, and the
/// uninstall removes what it recorded.</p>
/// <p>The calls run in a child process logged in as the installer
/// (<class>OcuPilot.Test.AdminPathProbe</class>); the rows are read back here by SQL, as the suite's own
/// <code>%All</code> identity. The installer principal is this class's own.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot's production install, and
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>INSTALLARMING</parameter> reading <code>1</code>, because the
/// class runs the probe profile's install and uninstall and creates and deletes a user and a role.
/// <method>OnBeforeAllTests</method> refuses anywhere either does not.</p>
Class OcuPilot.Test.InstallAsAdministrator Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the install this class runs.</p>
Parameter INSTALLARMING = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

Parameter PROBE = "OcuPilot.Test.AdminPathProbe";

/// <p>The installer: the grants <parameter>INSTALLERGRANTS</parameter> names and the install namespace's databases
/// read and write, no <code>%All</code> and no <code>OcuPilotAdmin</code>.</p>
Parameter INSTALLERUSER = "OcuPilotInstAdmInstaller";

Parameter INSTALLERROLE = "OcuPilotInstAdmInstallerRole";

/// <p>What an install and an uninstall of the probe profile need beyond the namespace's databases, measured on this
/// build by removing each in turn: <code>%Admin_Secure:USE</code> (resources, roles, applications),
/// <code>%Admin_Manage:USE</code> (the database and its mapping) and the system database's write. The install also
/// reads the class dictionary through SQL and grants OcuPilot's protected schema to the escalation role, so the
/// installer's role holds <code>SELECT</code> on <code>%Dictionary.CompiledClass</code> and the schema's four
/// privileges with the grant option (<method>EnsurePrincipals</method>). <code>%Admin_Operate</code> and
/// <code>%Development</code> are not needed.</p>
Parameter INSTALLERGRANTS = "%Admin_Secure:U,%Admin_Manage:U,%DB_IRISSYS:RW";

Parameter PROPOSALUSER = "OcuPilotProbeProposalInstallAdmin";

Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#INSTALLARMING) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InstallAsAdministrator runs the probe profile's install and uninstall and creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#INSTALLARMING _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set ..PreparedPassword = "OcuPilotInstAdm" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Set tRole = ..#INSTALLERROLE
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Do ##class(%SQL.Statement).%ExecDirect(, "REVOKE SELECT ON %Dictionary.CompiledClass FROM " _ tRole)
    Set tSC = ##class(OcuPilot.Install.Installer).StateTables(.tTables)
    Set tSchema = ""
    For {
        Set tSchema = $Order(tTables(tSchema))
        If tSchema = "" Quit
        Do ##class(%SQL.Statement).%ExecDirect(, "REVOKE ALL ON SCHEMA " _ tSchema _ " FROM " _ tRole _ " CASCADE")
    }
    Set $NAMESPACE = tOrigNS
    Quit ##class(OcuPilot.Test.AdminStateWrite).RemovePrincipals(..Cases(), "OcuPilot.Test.InstallAsAdministrator")
}

/// <p>Production is installed, the probe profile is not, and the installer starts without the role: an earlier
/// install's grant to the account stays with it, and this test starts from an account that does not hold it.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Do ..CleanProbe()
    Quit ..EnsurePrincipals(..PreparedPassword)
}

Method OnAfterOneTest() As %Status
{
    Do ..CleanProbe()
    Quit $$$OK
}

/// <p>The installer, as <code>$ListBuild(user, role, grants)</code>.</p>
ClassMethod Cases() As %List
{
    Quit $ListBuild($ListBuild(..#INSTALLERUSER, ..#INSTALLERROLE, ..#INSTALLERGRANTS))
}

/// <p>Create the installer's role with the install namespace's databases read and write plus
/// <parameter>INSTALLERGRANTS</parameter>, and its account, then read back that it holds neither <code>%All</code> nor
/// <code>OcuPilotAdmin</code> (<method>OcuPilot.Test.AdminPathWrite.EnsurePrincipals</method>). The SQL grants the install
/// needs are the one step that class does not take, because they name the install's own schemas and run in the install
/// namespace.</p>
ClassMethod EnsurePrincipals(pPassword As %String) As %Status
{
    Set tSC = ##class(OcuPilot.Test.AdminPathWrite).EnsurePrincipals(pPassword, ..Cases())
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        ; The install reads the class dictionary and grants OcuPilot's protected schema to the escalation role, which SQL
        ; allows only a grantor that holds the schema's privileges with the grant option.
        Set tRole = $List($List(..Cases(), 1), 2)
        Set $NAMESPACE = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT ON %Dictionary.CompiledClass TO " _ tRole)
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the installer's dictionary grant failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
            Quit
        }
        Set tSC = ##class(OcuPilot.Install.Installer).StateTables(.tTables)
        If $$$ISERR(tSC) Quit
        Set tSchema = ""
        For {
            Set tSchema = $Order(tTables(tSchema))
            If tSchema = "" Quit
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT,INSERT,UPDATE,DELETE ON SCHEMA " _ tSchema _ " TO " _ tRole _ " WITH GRANT OPTION")
            If tRS.%SQLCODE < 0 {
                Set tSC = $$$ERROR($$$GeneralError, "the installer's schema grant failed: SQLCODE=" _ tRS.%SQLCODE _ " " _ tRS.%Message)
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Return the instance to "the probe profile is not installed and no proposal of this class remains".</p>
Method CleanProbe()
{
    Do ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do ##class(OcuPilot.Test.ProbeApps).Remove()
    Do ##class(OcuPilot.Test.ProposalFixture).Remove(.tRemaining)
}

/// <p>The first column of the first row <var>pSql</var> answers when bound to <var>pValue</var>, or
/// <code>""</code>.</p>
ClassMethod Stored(pSql As %String, pValue As %String = "") As %String
{
    Quit ##class(OcuPilot.Test.InstallRecordWrite).Stored(pSql, pValue)
}

/// <p>The rows the probe profile has recorded: its provenance rows, stamp rows and version phase, as
/// <code>apps|stamps|phase</code>.</p>
ClassMethod Records() As %String
{
    Quit ..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.WebApp WHERE Profile = ?", "probe") _ "|" _ ..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Stamp WHERE Profile = ?", "probe") _ "|" _ ..Stored("SELECT Phase FROM OcuPilot_Kernel_State.Version WHERE Profile = ?", "probe")
}

/// <p>Seed one live proposal with a target and leave it with no target key, as a proposal stored before the key
/// existed is; answer its key, or <code>""</code>.</p>
Method SeedKeyless() As %String
{
    Kill tValues
    Set tValues("user") = ..#PROPOSALUSER
    Set tValues("convKey") = "probe-install-admin-conv"
    Set tValues("turnKey") = "probe-install-admin-turn"
    Set tValues("toolName") = "webapp.list.update"
    Set tValues("targetRef") = "webapp|USER|/csp/ocupilotinstalladmin"
    Set tValues("fingerprint") = "0"
    Set tValues("arguments") = "{}"
    Set tValues("payload") = "{}"
    Set tValues("diff") = "[]"
    Set tValues("unchangedCount") = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Proposal SET TargetKey = NULL WHERE %EXACT(ProposalKey) = ?", tKey)
    Do $$$AssertEquals(tRS.%ROWCOUNT, 1, "and left with no target key")
    Quit tKey
}

/// <p>An installer holding neither <code>%All</code> nor <code>OcuPilotAdmin</code> installs the probe profile,
/// installs it again over a stored proposal that lacks its target key, and uninstalls it. Each completes, the
/// install writes the provenance, stamp and version rows, the second gives the proposal its key, the uninstall
/// removes the rows, the applications and a demo inventory row seeded for the profile, and the installer's process is
/// without the administrative role after each step.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Install.Installer.AsAdministrator</method> skips its role addition ->
/// the first install fails and this goes red; the same method made to skip it for the <code>deleteStamps</code> step
/// alone -> the uninstall leaves the stamp rows and the last records assertion goes red; the same method made to skip it for the
/// <code>gatewayMark</code> step alone -> the gateway-report assertion goes red; the same method made to skip it for the
/// <code>demoRemove</code> step alone -> the uninstall keeps the demo inventory row and goes red.</p>
Method TestAProbeInstallUpgradeAndUninstallCompleteAsTheInstaller()
{
    Set tInstaller = ..#INSTALLERUSER
    Set tRoster = $ListLength(##class(OcuPilot.Test.ProbeApps).Paths())
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(tInstaller, [{"kind": "Install.ProbeInstall"}], ..#PROBE)
    Do $$$AssertEquals(tRun.%Get("username") _ "|" _ tRun.%Get("holdsAdmin") _ "|" _ (tRun.%Get("roles") [ "%All"), tInstaller _ "|0|0", "the child runs as the installer, without OcuPilotAdmin or %All")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminPathWrite).LegText(tRun, 1), "Install.ProbeInstall ok=1 code=", "the first probe install completes: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
    Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1)
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("holdsAdmin"), 1: ""), 0, "and the installer's process is without the administrative role afterwards")
    Do $$$AssertEquals(..Records(), tRoster _ "|1|installed", "it recorded every application's provenance, its stamp and an installed version row")
    Do $$$AssertEquals(..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.WebApp WHERE Profile = ? AND GatewayReported = 0", "probe"), 0, "and marked each application's gateway report as made, which the installer's process can write only as an administrator")

    Set tKey = ..SeedKeyless()
    If tKey = "" Quit
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(tInstaller, [{"kind": "Install.ProbeInstall"}], ..#PROBE)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminPathWrite).LegText(tRun, 1), "Install.ProbeInstall ok=1 code=", "the install over a keyless proposal completes: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
    Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1)
    Do $$$AssertEquals(tRun.%Get("holdsAdmin") _ "|" _ $Select($IsObject(tLeg): tLeg.%Get("holdsAdmin"), 1: ""), "0|0", "the installer starts and ends the upgrade without the administrative role")
    Do $$$AssertEquals(..Records(), tRoster _ "|2|installed", "and added a stamp")
    Do $$$AssertTrue(..Stored("SELECT TargetKey FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = ?", tKey) '= "", "and the keyless proposal has its key")

    Set tDemo = ##class(OcuPilot.Kernel.State.Demo).%New()
    Set tDemo.Profile = "probe"
    Set tDemo.Kind = "errorentry"
    Set tDemo.Name = "probe install-admin error entry"
    Set tDemo.Scope = "HSCUSTOM"
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Base).GuardedSave(tDemo), "a demo inventory row is seeded for the probe profile, of a kind with no object to remove")
    Set tDemo = ""
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(tInstaller, [{"kind": "Install.ProbeUninstall"}], ..#PROBE)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminPathWrite).LegText(tRun, 1), "Install.ProbeUninstall ok=1 code=", "the probe uninstall completes: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
    Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1)
    Do $$$AssertEquals(tRun.%Get("holdsAdmin") _ "|" _ $Select($IsObject(tLeg): tLeg.%Get("holdsAdmin"), 1: ""), "0|0", "the installer starts and ends the uninstall without the administrative role")
    Do $$$AssertEquals(..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", "probe"), 0, "and removed the probe's demo inventory row, which the installer's process can delete only as an administrator")
    Do $$$AssertEquals(..Records(), "0|0|", "and removed the probe's provenance, stamp and version rows")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProbeApps).Existing(), "", "and its applications")
}

}
