/// <p>DW-96: install derives OcuPilot's protected tables from the class dictionary, grants them
/// before any web application exists, and reads every grant back, failing when one did not
/// take. It also names, without refusing or revoking, a grant on those tables that another
/// grantee holds.</p>
/// <p>Needs the production profile installed (primed in <method>OnBeforeOneTest</method>, a
/// no-op on an installed instance) and installs and removes the disposable <code>"probe"</code>
/// profile. A grant that did not take is armed through <class>OcuPilot.Test.GrantFault</class>;
/// the widened-grant tests create a role and grants of their own and revoke them in
/// <method>DropProbeGrants</method>, and one creates an account that cannot enter
/// <code>%SYS</code> (<method>LimitedPrincipal</method>) and removes it.</p>
/// <p><b>It runs OcuPilot's production install, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>, <code>ocupilot-ci</code>), and
/// <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does
/// not arm it.</p>
Class OcuPilot.Test.GrantReadBack Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it, so the install this class
/// runs happens on the container that script builds and nowhere else.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

/// <p>Refuse to run at all unless this instance is armed for a production install.</p>
/// <p><b>A doc comment does not keep a class that installs from installing.</b> Test classes are
/// selected by package, so pointing the runner at a container someone cares about would run
/// OcuPilot's production install on it. Failing here is the honest outcome: nothing is installed
/// and the reason is named.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.GrantReadBack runs OcuPilot's PRODUCTION install on this instance -- a database, a resource, a role, three web applications, the audit registrations and the _SYSTEM unexpire -- and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was installed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.GrantFault).Disarm()
    Do ##class(OcuPilot.Test.InstallerProbe).Clear()
    Do ..DropProbeGrants()
    Do ..LimitedPrincipal(0)
    Quit ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
}

/// <p>The role <method>TestAWidenedGrantIsNamedAndKept</method> grants the schema to.</p>
Parameter GRANTEE As %String = "OcuProbe1843Grantee";

/// <p>The account and role <method>TestAnAccountThatCannotEnterSysGetsOneWarnNamingTheSwitch</method>
/// creates; the role reads the install namespace's databases and nothing else.</p>
Parameter LIMITEDUSER As %String = "OcuProbe1843Limited";

Parameter LIMITEDROLE As %String = "OcuProbe1843LimitedRole";

/// <p>A schema that is not OcuPilot's, granted on in the install namespace by the filter test.</p>
Parameter OTHERSCHEMA As %String = "OcuProbe1843Other";

/// <p>The text every widened-grant warn starts with, which an install with only the escalation
/// role's grant never emits.</p>
Parameter WIDENEDWARN As %String = "Grants on OcuPilot's protected schema are held by a grantee other than its escalation role";

/// <p>The text the warn for a privilege catalog that cannot be read starts with.</p>
Parameter UNREADABLEWARN As %String = "OcuPilot's protected schema could not be checked for grants held by other grantees";

/// <p>The derived set equals what the dictionary reports, class by class, for every class in
/// <class>OcuPilot.Kernel.State.Base</class>'s package, and it names the tables the guarded
/// reads query.</p>
/// <p>Mutation (Rule 19): drop the <code>Abstract = 0</code> filter from
/// <method>OcuPilot.Install.Installer.StateTables</method> -- the abstract base's table joins
/// the set and the equality goes red.</p>
Method TestDerivedTablesEqualTheDictionary()
{
    Set tSC = ##class(OcuPilot.Install.Installer).StateTables(.tDerived)
    Do $$$AssertStatusOK(tSC, "the tables are derived")

    Set tPackage = ##class(OcuPilot.Kernel.State.Base).%PackageName()
    Set tSC = $System.OBJ.GetPackageList(.tClasses, tPackage)
    Do $$$AssertStatusOK(tSC, "the package's classes are listed")
    Set tSeen = 0
    Set tClass = ""
    For {
        Set tClass = $Order(tClasses(tClass))
        If tClass = "" Quit
        Set tSeen = tSeen + 1
        Set tDef = ##class(%Dictionary.CompiledClass).%OpenId(tClass)
        Do $$$AssertTrue($IsObject(tDef), "the dictionary holds " _ tClass)
        If '$IsObject(tDef) Continue
        If (tDef.ClassType '= "persistent") || tDef.Abstract Continue
        Set tExpected(tDef.SqlSchemaName, tDef.SqlQualifiedNameQ) = ""
    }
    Do $$$AssertTrue(tSeen >= 5, "the package listing found the state classes (found " _ tSeen _ ")")
    Do $$$AssertEquals(..Flatten(.tDerived), ..Flatten(.tExpected), "the derived schemas and tables equal the dictionary's")
    For tTable = "Version", "Stamp", "WebApp", "Demo" {
        Do $$$AssertTrue($Data(tDerived("OcuPilot_Kernel_State", "OcuPilot_Kernel_State." _ tTable)), "the set carries OcuPilot_Kernel_State." _ tTable _ ", the table the guarded reads query")
    }
}

/// <p>After a real install, every derived table's grant reads back as held by the escalation
/// role through the production check.</p>
Method TestEveryDerivedTableReadsBackAsHeld()
{
    Set tRole = ##class(OcuPilot.Kernel.State.Base).#DBRESOURCE
    Set tSC = ##class(OcuPilot.Install.Installer).StateTables(.tTables)
    Do $$$AssertStatusOK(tSC, "the tables are derived")
    Set tSchema = ""
    For {
        Set tSchema = $Order(tTables(tSchema))
        If tSchema = "" Quit
        Set tTable = ""
        For {
            Set tTable = $Order(tTables(tSchema, tTable))
            If tTable = "" Quit
            Do $$$AssertTrue(##class(OcuPilot.Install.Installer).SqlPrivilegeHeld(tRole, tTable, $NAMESPACE), tRole _ " holds " _ tTable)
        }
    }
    Do $$$AssertTrue('##class(OcuPilot.Install.Installer).SqlPrivilegeHeld("%Operator", "OcuPilot_Kernel_State.Version", $NAMESPACE), "a role never granted the schema does not read back as holding it")
}

/// <p>A grant that did not take fails the install at <code>EnsureSqlPrivileges</code>, naming
/// the table and the role; no stamp is recorded, and no web application was created before the
/// grant.</p>
/// <p>Mutations (Rule 19): remove the read-back loop from
/// <method>OcuPilot.Install.Installer.EnsureSqlPrivileges</method> -- the install succeeds and
/// red. Move <code>EnsureSqlPrivileges</code> back after <code>EnsureApplications</code> -- the
/// probe's applications exist and the last assertion goes red.</p>
Method TestAGrantThatDidNotTakeFailsTheInstall()
{
    Set tRole = ##class(OcuPilot.Kernel.State.Base).#DBRESOURCE
    Set tTable = "OcuPilot_Kernel_State.Version"
    Set tStampsBefore = ..ProbeStampCount()
    Set tStart = $NAMESPACE
    ; Uninstall removes only the applications install recorded, so a probe application an earlier
    ; interrupted run left behind would mask the ordering this test pins.
    Set tLeft = ..ProbeApplications()
    Do $$$AssertEquals(tLeft, "", "precondition: no probe web application exists before the install (found: " _ tLeft _ ")")

    Do ##class(OcuPilot.Test.GrantFault).ArmNotHeld(tTable)
    Set tSC = ##class(OcuPilot.Test.GrantFault).Install("probe")
    Do ##class(OcuPilot.Test.GrantFault).Disarm()

    Do $$$AssertStatusNotOK(tSC, "the install fails")
    Set tText = $System.Status.GetErrorText(tSC)
    Do $$$AssertTrue(tText [ "EnsureSqlPrivileges", "at EnsureSqlPrivileges: " _ tText)
    Do $$$AssertTrue(tText [ tTable, "naming the table")
    Do $$$AssertTrue(tText [ tRole, "and the role")
    Do $$$AssertEquals($NAMESPACE, tStart, "the namespace is restored")
    Do $$$AssertEquals(..ProbeStampCount(), tStampsBefore, "no stamp is recorded")

    Do $$$AssertEquals(..ProbeApplications(), "", "no probe web application was created before the grant")
}

/// <p>A grant on OcuPilot's schema, a table or a column held by a grantee other than the escalation
/// role does not fail install and is not revoked, and one warn names each such grantee, object and
/// privilege and the remedy. The escalation role's own grant is never named.</p>
/// <p>Mutations (Rule 19): drop the <code>ReportWidenedGrants</code> call from
/// <method>OcuPilot.Install.Installer.EnsureSqlPrivileges</method> -- the warn assertions go red.
/// Drop the escalation-role filter from <method>OcuPilot.Install.Installer.ReportWidenedGrants</method>
/// -- the install with only the escalation role's grant names that role, and both escalation-role
/// assertions go red. Delete the
/// column arm of the object classification, or relabel a privilege letter -- the column assertion or
/// the privilege-list assertion goes red.</p>
Method TestAWidenedGrantIsNamedAndKept()
{
    Set tEscalation = ##class(OcuPilot.Kernel.State.Base).#DBRESOURCE
    Set tGrantee = ..#GRANTEE
    Set tSC = ##class(OcuPilot.Install.Installer).StateTables(.tTables)
    Do $$$AssertStatusOK(tSC, "the tables are derived")
    Set tSchema = $Order(tTables(""))
    Set tTable = $Order(tTables(tSchema, ""))
    Do $$$AssertTrue((tSchema '= "") && (tTable '= ""), "there is a schema and a table to grant on: " _ tSchema _ ", " _ tTable)
    Set tColumn = ..ProbeColumn(tTable)
    Do $$$AssertTrue(tColumn '= "", "the table has a column to grant on: " _ tColumn)
    Do ..DropProbeGrants()

    Try {
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Do $$$AssertStatusOK(##class(OcuPilot.Test.InstallerProbe).Install("probe"), "a probe install with only the escalation role's grant succeeds")
        Set tBefore = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
        Do $$$AssertTrue('(tBefore [ tGrantee) && '(tBefore [ ("_PUBLIC SELECT on table " _ tTable)), "and names neither of the grants this test is about to make: " _ tBefore)
        Do $$$AssertTrue('(tBefore [ tEscalation), "nor the escalation role, whose grant is the only one install made: " _ tBefore)

        Do $$$AssertStatusOK(..ProbeRole("create"), "the probe grantee role is created")
        Set tR1 = ##class(%SQL.Statement).%ExecDirect(, "GRANT %ALTER,SELECT,INSERT,UPDATE,DELETE ON SCHEMA " _ tSchema _ " TO " _ tGrantee)
        Do $$$AssertEquals(tR1.%SQLCODE, 0, "the role is granted five privileges on the schema: " _ tR1.%Message)
        Set tR3 = ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT (" _ tColumn _ ") ON " _ tTable _ " TO " _ tGrantee)
        Do $$$AssertEquals(tR3.%SQLCODE, 0, "and SELECT on one column of a table: " _ tR3.%Message)
        Set tR2 = ##class(%SQL.Statement).%ExecDirect(, "GRANT SELECT ON " _ tTable _ " TO _PUBLIC")
        Do $$$AssertEquals(tR2.%SQLCODE, 0, "_PUBLIC is granted SELECT on a table: " _ tR2.%Message)

        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
        Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
        Do $$$AssertStatusOK(tSC, "install succeeds beside the two grants: " _ $System.Status.GetErrorText(tSC))
        Do $$$AssertEquals($Length(tWarns, ..#WIDENEDWARN) - 1, 1, "one warn reports the widened grants: " _ tWarns)
        Set tUpper = $ZConvert(tWarns, "U")
        Do $$$AssertTrue((tUpper [ $ZConvert(tGrantee _ " %ALTER,DELETE,INSERT,SELECT,UPDATE on schema " _ tSchema, "U")), "it names the role, every privilege and the schema")
        Do $$$AssertTrue((tUpper [ $ZConvert(tGrantee _ " SELECT on column " _ tTable _ "." _ tColumn, "U")), "and the role's one column")
        Do $$$AssertTrue((tUpper [ $ZConvert("_PUBLIC SELECT on table " _ tTable, "U")), "and _PUBLIC, its privilege and the table")
        Do $$$AssertTrue((tWarns [ "REVOKE") && (tWarns [ "PROHIBITED.OCUPILOTSQLPRIVILEGE"), "and the remedy")
        Do $$$AssertTrue('(tWarns [ tEscalation), "and never the escalation role")

        Do $$$AssertTrue(##class(OcuPilot.Install.Installer).SqlPrivilegeHeld(tEscalation, tTable, $NAMESPACE), "the escalation role still holds its grant")
        Do $$$AssertEquals($SYSTEM.SQL.Security.CheckPrivilege(tGrantee, 1, tTable, "s", $NAMESPACE), 1, "the role still holds SELECT on the table through the schema")
        Do $$$AssertEquals($SYSTEM.SQL.Security.CheckPrivilege("_PUBLIC", 1, tTable, "s", $NAMESPACE), 1, "and _PUBLIC still holds SELECT on its table")
    } Catch ex {
        Do ..DropProbeGrants()
        Throw ex
    }
    Do ..DropProbeGrants()
    Do $$$AssertEquals($SYSTEM.SQL.Security.CheckPrivilege("_PUBLIC", 1, tTable, "s", $NAMESPACE), 0, "clean-up revoked the _PUBLIC grant")
}

/// <p>A check that finds no grant on OcuPilot's objects to any grantee but the escalation role warns
/// nothing at all. It reads the real catalog for a schema and table no grant names, so what else the
/// instance grants does not matter.</p>
/// <p>Mutation (Rule 19): delete <code>If tText = "" Quit $$$OK</code> from
/// <method>OcuPilot.Install.Installer.ReportWidenedGrants</method> -- an empty widened-grant warn is
/// logged and this goes red.</p>
Method TestACheckThatFindsNoOtherGranteeWarnsNothing()
{
    Set tNone("OcuProbe1843None", "OcuProbe1843None.Nothing") = ""
    Try {
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Set tSC = ##class(OcuPilot.Test.InstallerProbe).DriveReportWidenedGrants($NAMESPACE, .tNone)
        Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Do $$$AssertStatusOK(tSC, "the check answers OK: " _ $System.Status.GetErrorText(tSC))
        Do $$$AssertEquals(tWarns, "", "and warns nothing when no grant names the schema or its table")
    } Catch ex {
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Throw ex
    }
}

/// <p>A SQL privilege catalog that cannot be read turns the widened-grant check into one warn and
/// leaves install succeeding: detection never fails install.</p>
/// <p>Mutation (Rule 19): drop the warn in the failure branch of
/// <method>OcuPilot.Install.Installer.ReportWidenedGrants</method> -- the warn assertion goes red.</p>
Method TestAnUnreadablePrivilegeCatalogIsOneWarn()
{
    Try {
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Do ##class(OcuPilot.Test.InstallerProbe).SetPrivilegeCatalogUnreadable(1)
        Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe")
        Set tWarns = ##class(OcuPilot.Test.InstallerProbe).CapturedAll("warn")
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Do $$$AssertStatusOK(tSC, "install succeeds when the catalog cannot be read: " _ $System.Status.GetErrorText(tSC))
        Do $$$AssertEquals($Length(tWarns, ..#UNREADABLEWARN) - 1, 1, "one warn says the catalog could not be read: " _ tWarns)
        Do $$$AssertTrue('(tWarns [ ..#WIDENEDWARN), "and none names a widened grant")
    } Catch ex {
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Throw ex
    }
}

/// <p>A catalog query that exists but answers a failing status when executed is one warn carrying
/// that status, and the check still answers OK.</p>
/// <p>Mutation (Rule 19): drop the status check after <code>tRS.Execute()</code> in
/// <method>OcuPilot.Install.Installer.ReportWidenedGrants</method> -- the failed read is no longer
/// reported as the query's status and this goes red.</p>
Method TestACatalogQueryThatFailsToExecuteIsOneWarn()
{
    Try {
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Do ##class(OcuPilot.Test.InstallerProbe).SetPrivilegeCatalogExecuteFails(1)
        Set tWarns = ##class(OcuPilot.Test.InstallerProbe).WidenedGrantWarns($NAMESPACE, .tSC, 1)
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Do $$$AssertStatusOK(tSC, "the check answers OK when the catalog read fails: " _ $System.Status.GetErrorText(tSC))
        Do $$$AssertEquals($Length(tWarns, ..#UNREADABLEWARN) - 1, 1, "one warn says the catalog could not be read: " _ tWarns)
        Do $$$AssertTrue(tWarns [ "DirectoryList", "and carries the status the query answered: " _ tWarns)
        Do $$$AssertTrue('(tWarns [ ..#WIDENEDWARN), "and none names a widened grant")
    } Catch ex {
        Do ##class(OcuPilot.Test.InstallerProbe).Clear()
        Throw ex
    }
}

/// <p>Only a grant in the install namespace on OcuPilot's own schema is reported: the grantee's grant
/// on a same-named schema in another namespace, and on another schema here, are not; its grant on
/// OcuPilot's schema here is, once.</p>
/// <p>Mutations (Rule 19): drop the namespace comparison in
/// <method>OcuPilot.Install.Installer.ReportWidenedGrants</method>, or its object classification
/// (<code>If tKind = "" Continue</code>) -- the "neither grant is reported" leg goes red.</p>
Method TestOnlyAGrantOnOcuPilotsSchemaInTheInstallNamespaceIsReported()
{
    Set tGrantee = ..#GRANTEE
    Set tHere = $NAMESPACE
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).StateTables(.tTables), "the tables are derived")
    Set tSchema = $Order(tTables(""))
    Do ..DropProbeGrants()
    Do $$$AssertStatusOK(..ProbeRole("create"), "the probe grantee role is created")
    Do $$$AssertEquals(..SqlIn("%SYS", "GRANT SELECT ON SCHEMA " _ tSchema _ " TO " _ tGrantee), 0, "the role is granted OcuPilot's schema name in another namespace")
    Do $$$AssertEquals(..SqlIn(tHere, "GRANT SELECT ON SCHEMA " _ ..#OTHERSCHEMA _ " TO " _ tGrantee), 0, "and a schema that is not OcuPilot's here")
    Do $$$AssertTrue('(##class(OcuPilot.Test.InstallerProbe).WidenedGrantWarns(tHere) [ tGrantee), "neither grant is reported")
    Do $$$AssertEquals(..SqlIn(tHere, "GRANT SELECT ON SCHEMA " _ tSchema _ " TO " _ tGrantee), 0, "the role is granted OcuPilot's schema here")
    Set tWarns = ##class(OcuPilot.Test.InstallerProbe).WidenedGrantWarns(tHere)
    Do $$$AssertEquals($Length(tWarns, tGrantee) - 1, 1, "and is named once: " _ tWarns)
    Do $$$AssertTrue('(tWarns [ ..#OTHERSCHEMA), "without the other schema")
}

/// <p>An account that cannot enter <code>%SYS</code> turns the check into one warn naming the refused
/// switch and answers OK.</p>
/// <p>Mutation (Rule 19): drop the failure branch after the namespace switch in
/// <method>OcuPilot.Install.Installer.ReportWidenedGrants</method> -- the warn stops naming it.</p>
Method TestAnAccountThatCannotEnterSysGetsOneWarnNamingTheSwitch()
{
    Do $$$AssertStatusOK(..LimitedPrincipal(1), "the account is created")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).StateTables(.tTables), "the tables are derived")
    Set tSchema = $Order(tTables(""))
    Set tOut = ..RunAsLimited(tSchema, $Order(tTables(tSchema, "")))
    Do $$$AssertEquals(tOut.%Get("error"), "", "the child ran: " _ tOut.%ToJSON())
    Do $$$AssertEquals(tOut.%Get("username"), ..#LIMITEDUSER, "as the limited account")
    Do $$$AssertEquals(tOut.%Get("status"), "OK", "and the check answers OK")
    Set tWarns = tOut.%Get("warns")
    Do $$$AssertEquals($Length(tWarns, ..#UNREADABLEWARN) - 1, 1, "one warn says the catalog could not be read: " _ tWarns)
    Do $$$AssertTrue(tWarns [ "PROTECT", "and names the switch the account was refused: " _ tWarns)
}

/// <p>Run <var>pStatement</var> in namespace <var>pNamespace</var>, restore the namespace, and answer
/// the SQLCODE (<code>-1000</code> when it raised).</p>
ClassMethod SqlIn(pNamespace As %String, pStatement As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tCode = ##class(%SQL.Statement).%ExecDirect(, pStatement).%SQLCODE
    } Catch ex {
        Set tCode = -1000
    }
    Set $NAMESPACE = tOrigNS
    Quit tCode
}

/// <p>Create (<var>pCreate</var> 1) or delete (0) the account <parameter>LIMITEDUSER</parameter> and
/// its role <parameter>LIMITEDROLE</parameter>, which holds read on the install namespace's databases
/// and nothing else, so the account cannot enter <code>%SYS</code>. Switches and restores (AD-16).</p>
ClassMethod LimitedPrincipal(pCreate As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        If ##class(Security.Users).Exists(..#LIMITEDUSER) Do ##class(Security.Users).Delete(..#LIMITEDUSER)
        If ##class(Security.Roles).Exists(..#LIMITEDROLE) Do ##class(Security.Roles).Delete(..#LIMITEDROLE)
        If 'pCreate Quit
        Set tResources = ""
        For tName = tNamespace.Globals, tNamespace.Routines {
            Set tResource = ##class(SYS.Database).%OpenId(##class(Config.Databases).Open(tName).Directory).ResourceName _ ":R"
            If tResources '[ tResource Set tResources = tResources _ $Select(tResources = "": "", 1: ",") _ tResource
        }
        Set tSC = ##class(Security.Roles).Create(..#LIMITEDROLE, "OcuPilot.Test.GrantReadBack disposable role", tResources, "")
        If $$$ISERR(tSC) Quit
        Set tPassword = "OcuPilotGrb" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
        Set tSC = ##class(Security.Users).Create(..#LIMITEDUSER, ..#LIMITEDROLE, tPassword, "OcuPilot.Test.GrantReadBack disposable account", "", "", "", 0, 1, "Created by OcuPilot.Test.GrantReadBack; deleted by it")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Run <method>Limited</method> over table <var>pTable</var> of schema <var>pSchema</var> (derived by
/// the caller; the account holds no SQL privilege to derive them) in a child process and answer what
/// it signalled, or an object carrying <code>error</code>.</p>
ClassMethod RunAsLimited(pSchema As %String, pTable As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.GrantReadBack).Limited($Job, ..#LIMITEDUSER, $NAMESPACE, pSchema, pTable)::10
        If '$Test {
            Do tOut.%Set("error", "the child process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 60)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the child process signalled nothing within 60 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child: log in as <var>pUser</var>, run <method>OcuPilot.Test.InstallerProbe.DriveReportWidenedGrants</method>
/// for <var>pInstallNs</var> over table <var>pTable</var> of schema <var>pSchema</var> and signal
/// <code>{error, username, status, warns}</code> to process <var>pParent</var>.</p>
/// <p><b>Caller contract:</b> <code>JOB</code>ed by <method>RunAsLimited</method> and by nothing else;
/// <code>$System.Security.Login</code> switches this process's own user context.</p>
ClassMethod Limited(pParent As %Integer, pUser As %String, pInstallNs As %String, pSchema As %String, pTable As %String)
{
    Set tOut = {"error": ""}
    Try {
        If '$SYSTEM.Security.Login(pUser) {
            Do tOut.%Set("error", "the login as " _ pUser _ " failed")
            Quit
        }
        Do tOut.%Set("username", $Username, "string")
        Set tTables(pSchema, pTable) = ""
        Set tSC = ##class(OcuPilot.Test.InstallerProbe).DriveReportWidenedGrants(pInstallNs, .tTables)
        Do tOut.%Set("status", $Select($$$ISOK(tSC): "OK", 1: $System.Status.GetErrorText(tSC)), "string")
        Do tOut.%Set("warns", ##class(OcuPilot.Test.InstallerProbe).CapturedAllWithData("warn"), "string")
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>The name of a column of <var>pTable</var> (<code>&lt;schema&gt;.&lt;table&gt;</code>) other than
/// its id, read from the class dictionary's SQL catalog; <code>""</code> when it has none.</p>
ClassMethod ProbeColumn(pTable As %String) As %String
{
    Set tColumn = ""
    Try {
        Set tStmt = ##class(%SQL.Statement).%New()
        Set tSC = tStmt.%Prepare("SELECT TOP 1 COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME <> 'ID' ORDER BY ORDINAL_POSITION")
        If $$$ISERR(tSC) Quit
        Set tRS = tStmt.%Execute($Piece(pTable, ".", 1), $Piece(pTable, ".", 2))
        If tRS.%Next() Set tColumn = tRS.%GetData(1)
    } Catch ex {
        Set tColumn = ""
    }
    Quit tColumn
}

/// <p>Create (<var>pAction</var> <code>"create"</code>) or delete (<code>"delete"</code>) the role
/// <parameter>GRANTEE</parameter> in <code>%SYS</code>; both are no-ops when the role is already
/// in the requested state. Switches and restores (AD-16).</p>
Method ProbeRole(pAction As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tExists = ##class(Security.Roles).Exists(..#GRANTEE)
        If (pAction = "create") && 'tExists {
            Set tSC = ##class(Security.Roles).Create(..#GRANTEE, "OcuPilot.Test.GrantReadBack disposable role")
        } ElseIf (pAction = "delete") && tExists {
            Set tSC = ##class(Security.Roles).Delete(..#GRANTEE)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Revoke the grants <method>TestAWidenedGrantIsNamedAndKept</method> makes and delete its role.
/// Every step is a no-op when there is nothing to undo; a failure surfaces through the next
/// assertion that reads the grant.</p>
Method DropProbeGrants()
{
    Try {
        Set tSC = ##class(OcuPilot.Install.Installer).StateTables(.tTables)
        If $$$ISOK(tSC) {
            Set tSchema = $Order(tTables(""))
            Set tTable = $Order(tTables(tSchema, ""))
            Set tColumn = ..ProbeColumn(tTable)
            Do ##class(%SQL.Statement).%ExecDirect(, "REVOKE %ALTER,SELECT,INSERT,UPDATE,DELETE ON SCHEMA " _ tSchema _ " FROM " _ ..#GRANTEE)
            If tColumn '= "" Do ##class(%SQL.Statement).%ExecDirect(, "REVOKE SELECT (" _ tColumn _ ") ON " _ tTable _ " FROM " _ ..#GRANTEE)
            Do ##class(%SQL.Statement).%ExecDirect(, "REVOKE SELECT ON " _ tTable _ " FROM _PUBLIC")
            Do ..SqlIn("%SYS", "REVOKE SELECT ON SCHEMA " _ tSchema _ " FROM " _ ..#GRANTEE)
            Do ..SqlIn($NAMESPACE, "REVOKE SELECT ON SCHEMA " _ ..#OTHERSCHEMA _ " FROM " _ ..#GRANTEE)
        }
        Do ..ProbeRole("delete")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
}

/// <p>The probe profile's web applications that exist on this instance, space-separated,
/// <code>""</code>, or <code>error: &lt;text&gt;</code> when the check failed, as
/// <method>OcuPilot.Test.ProbeApps.Existing</method> answers.</p>
Method ProbeApplications() As %String
{
    Quit ##class(OcuPilot.Test.ProbeApps).Existing()
}

/// <p>The number of stamp rows the probe profile carries.</p>
Method ProbeStampCount() As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OcuPilot_Kernel_State.Stamp WHERE Profile = 'probe'")
    If 'tRS.%Next() Quit -1
    Quit tRS.N
}

/// <p>A two-level array as a sorted <code>schema|table</code> list, for one equality.</p>
Method Flatten(ByRef pTables) As %String
{
    Set tOut = ""
    Set tSchema = ""
    For {
        Set tSchema = $Order(pTables(tSchema))
        If tSchema = "" Quit
        Set tTable = ""
        For {
            Set tTable = $Order(pTables(tSchema, tTable))
            If tTable = "" Quit
            Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tSchema _ "|" _ tTable
        }
    }
    Quit tOut
}

}
