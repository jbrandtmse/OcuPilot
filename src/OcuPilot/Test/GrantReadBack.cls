/// <p>DW-96: install derives OcuPilot's protected tables from the class dictionary, grants them
/// before any web application exists, and reads every grant back, failing when one did not
/// take.</p>
/// <p>Needs the production profile installed (primed in <method>OnBeforeOneTest</method>, a
/// no-op on an installed instance) and installs and removes the disposable <code>"probe"</code>
/// profile. Revokes nothing: a grant that did not take is armed through
/// <class>OcuPilot.Test.GrantFault</class>.</p>
Class OcuPilot.Test.GrantReadBack Extends %UnitTest.TestCase
{

Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.GrantFault).Disarm()
    Quit ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
}

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
