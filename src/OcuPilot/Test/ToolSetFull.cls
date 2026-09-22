/// <p>AD-8's "the full tool set is always advertised", as something that can fail (Story 5.4,
/// AC3): a principal holding <b>one</b> administrative resource and nothing else is offered the
/// whole registry roster, identical in count and in name order to what a <code>%All</code> holder
/// is offered. Privilege is checked at call time; nothing is hidden from the model to enforce
/// it.</p>
/// <p><b>Measured as a real principal, in a child process.</b> <code>%UnitTest</code> runs as an
/// account holding <code>%All</code>, for which the real
/// <code>$System.Security.Check</code> answers yes to every resource name -- so a roster filtered
/// by privilege would look identical here. <class>OcuPilot.Test.ToolSetProbe</class> logs in as
/// the least-privileged principal and advertises there, so a filter would have something to
/// remove.</p>
/// <p><b>It creates security principals, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>), and <method>OnBeforeAllTests</method> refuses anywhere
/// <parameter>ARMINGVARIABLE</parameter> does not arm it. The account and its role are removed in
/// <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.ToolSetFull Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The least-privileged principal.</p>
Parameter LEASTUSER = "OcuPilotToolSetLeast";

/// <p>See <parameter>LEASTUSER</parameter>.</p>
Parameter LEASTROLE = "OcuPilotToolSetLeastRole";

/// <p>The one administrative resource it holds. <code>%Admin_Operate</code>, never
/// <code>%Operator</code>: that role carries <code>%DB_IRISSYS:RW</code> and is a self-escalation
/// primitive, so nothing proved with it is a measurement of least privilege.</p>
Parameter ADMINRESOURCE = "%Admin_Operate";

/// <p>The account's password for this run. Prefix deliberately not "Test".</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back the account's one resource, and its
/// absence of a second.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ToolSetFull creates and deletes IRIS users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so no principal was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotToolSet" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNsObj = ##class(Config.Namespaces).Open(tInstallNs)
        If '$IsObject(tNsObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open namespace configuration for " _ tInstallNs)
            Quit
        }
        Set tDbObj = ##class(Config.Databases).Open(tNsObj.Routines)
        If '$IsObject(tDbObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open the routine database " _ tNsObj.Routines)
            Quit
        }
        Set tSysDb = ##class(SYS.Database).%OpenId(tDbObj.Directory)
        If '$IsObject(tSysDb) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open SYS.Database for the routine database directory")
            Quit
        }
        Set tSC = ..EnsurePrincipal(tSysDb.ResourceName _ ":R," _ ..#ADMINRESOURCE _ ":U")
        If $$$ISERR(tSC) Quit

        Set ..PreparedSetupOk = ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, ..#ADMINRESOURCE, "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#LEASTUSER, "%Admin_Secure", "USE") '= 1)
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the principal holds exactly one administrative resource")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        If ##class(Security.Users).Exists(..#LEASTUSER, .tU, .tUS) Do ##class(Security.Users).Delete(..#LEASTUSER)
        If ##class(Security.Users).Exists(..#LEASTUSER, .tU2, .tUS2) Set tLeft = "user " _ ..#LEASTUSER
        If ##class(Security.Roles).Exists(..#LEASTROLE, .tR, .tRS) Do ##class(Security.Roles).Delete(..#LEASTROLE)
        If ##class(Security.Roles).Exists(..#LEASTROLE, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ ..#LEASTROLE
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.ToolSetFull teardown left throwaway objects on the instance: " _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create (or re-grant) the throwaway role and the account that holds it.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
Method EnsurePrincipal(pResources As %String) As %Status
{
    Set tSC = $$$OK
    If ##class(Security.Roles).Exists(..#LEASTROLE, .tR, .tRS) {
        Set tModProps("Resources") = pResources
        Set tModProps("GrantedRoles") = ""
        Set tModProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(..#LEASTROLE, .tModProps)
    } Else {
        Set tSC = ##class(Security.Roles).Create(..#LEASTROLE, "OcuPilot test: least-privileged tool-set principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(..#LEASTUSER, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(..#LEASTUSER)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(..#LEASTUSER, ..#LEASTROLE, ..PreparedPassword, "OcuPilot tool-set test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.ToolSetFull; deleted in OnAfterAllTests")
}

/// <p>Run <class>OcuPilot.Test.ToolSetProbe</class> as <var>pUser</var> in a child process and
/// answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.ToolSetProbe).Run($Job, pUser)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 60)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 60 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p><b>AC3</b> -- the advertised tool set a least-privileged principal is offered is the whole
/// registry roster, identical to a <code>%All</code> holder's.</p>
/// <p>Mutation (Rule 19): filter
/// <method>OcuPilot.Screen.Tool.Registry.ProviderTools</method>'s roster by
/// <method>OcuPilot.Screen.Gate.HoldsPrivilege</method> -> this goes red, because the probe's
/// principal holds one resource and the roster is not.</p>
Method TestEveryToolIsAdvertisedToALeastPrivilegedPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principal holds exactly one administrative resource")

    ; The roster, as the suite's own %All identity sees it.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Agent.Dispatch).Advertise(.tAll), "the %All holder's turn advertises its tools")
    Set tAllCount = +$Get(tAll)
    Do $$$AssertTrue(tAllCount > 0, "the registry advertises at least one tool")
    Set tAllNames = ""
    For tI = 1:1:tAllCount Set tAllNames = tAllNames _ $Select(tI = 1: "", 1: ",") _ $Get(tAll(tI, "name"))

    ; And the same question asked as the least-privileged principal.
    Set tProbe = ..ProbeAs(..#LEASTUSER)
    Do $$$AssertEquals(tProbe.%Get("error"), "", "the probe ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("loggedIn"), 1, "and logged in as the principal")
    Do $$$AssertEquals(tProbe.%Get("username"), ..#LEASTUSER, "which is who it advertised as")
    Do $$$AssertEquals(tProbe.%Get("status"), "", "the advertisement itself did not fail")
    Do $$$AssertEquals(tProbe.%Get("count"), tAllCount, "the least-privileged principal is offered every tool: " _ tProbe.%Get("count") _ " against " _ tAllCount)
    Do $$$AssertEquals(tProbe.%Get("names"), tAllNames, "in the same order, by the same names")

    ; The control: the principal really is least-privileged, so the identical rosters above are a
    ; measurement and not two readings of the same %All identity.
    Do $$$AssertEquals(##class(OcuPilot.Test.AsTheUserProbe).CarriesRole(tProbe.%Get("roles"), "%All"), 0, "and it held no %All while it asked: " _ tProbe.%Get("roles"))
}

/// <p><b>AC3</b> -- the roster the turn advertises is exactly what
/// <method>OcuPilot.Screen.Tool.Registry.ListTools</method> returns, name for name. The
/// advertisement is a projection of the registry, never a second list.</p>
/// <p>Mutation (Rule 19): drop one tool from
/// <method>OcuPilot.Kernel.Agent.Dispatch.Advertise</method>'s answer -> this goes red.</p>
Method TestTheAdvertisedSetIsTheRegistryRoster()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ListTools(.tList), "the registry lists its tools")
    Set tExpected = ""
    Set tIterator = tList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tExpected = tExpected _ $Select(tExpected = "": "", 1: ",") _ ##class(OcuPilot.Screen.Tool.Registry).WireName(tTool.%Get("name"))
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Agent.Dispatch).Advertise(.tTools), "and the turn advertises its tools")
    Set tAdvertised = ""
    For tI = 1:1:+$Get(tTools) Set tAdvertised = tAdvertised _ $Select(tI = 1: "", 1: ",") _ $Get(tTools(tI, "name"))
    Do $$$AssertEquals(tAdvertised, tExpected, "the advertised roster is the registry's, name for name")
}

}
