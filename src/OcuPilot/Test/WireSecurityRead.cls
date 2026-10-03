/// <p>The admin-port reads' privilege pair sets over the wire, against the <b>real</b>
/// <code>$System.Security.Check</code> (AD-8, DW-262, DW-264). Every one of them needs
/// <code>%DB_IRISSYS:READ</code>, because the port runs every endpoint in <code>%SYS</code>, plus
/// its own administrative resource: <code>%Admin_Secure:USE</code> for the users, roles, resources,
/// services, web applications, SSL/TLS configurations, X.509 credentials and LDAP / Kerberos lists,
/// <code>%Admin_Wallet:USE</code> for the Wallet and Secrets lists, <code>%Admin_Task:USE</code> for the
/// task schedule, <code>%Admin_Operate:USE</code> plus <code>%Admin_Manage:USE</code> for the
/// processes list, and
/// <code>%Admin_Secure:USE</code> plus <code>%Admin_Operate:USE</code> for the audit database
/// viewer -- the second because the port polls the endpoint's own queued task through
/// the async-result endpoint, which gates on it (AD-26, DW-249). A principal holding
/// some of a screen's pairs is denied on the first one it does not hold, in the navigation map, for
/// the screen and for its area, and on the read route.</p>
/// <p><b>Fourteen purpose-built principals, created in <method>OnBeforeAllTests</method> and deleted in
/// <method>OnAfterAllTests</method></b>, the shape <class>OcuPilot.Test.Wire</class> builds. Each holds
/// read on the install namespace's code database. <parameter>SECUREUSER</parameter> adds
/// <code>%Admin_Secure:U</code>; <parameter>SYSREADUSER</parameter> adds <code>%DB_IRISSYS:R</code>
/// and <code>%Admin_Operate:U</code>, the second because the API's administrative gate refuses a
/// caller holding neither an <code>%Admin_*</code> resource nor <code>%Development</code> before any screen gate runs;
/// <parameter>BOTHUSER</parameter> adds <code>%Admin_Secure:U</code> and <code>%DB_IRISSYS:R</code>;
/// <parameter>TASKUSER</parameter> adds <code>%Admin_Task:U</code> alone,
/// <parameter>TASKBOTHUSER</parameter> adds <code>%Admin_Task:U</code> and
/// <code>%DB_IRISSYS:R</code>, <parameter>OPERATEUSER</parameter> adds
/// <code>%Admin_Operate:U</code> and <code>%DB_IRISSYS:R</code>,
/// <parameter>OPERATEONLYUSER</parameter> adds <code>%Admin_Operate:U</code> alone,
/// <parameter>PROCESSUSER</parameter> adds those two plus <code>%Admin_Manage:U</code>,
/// <parameter>AUDITDENYUSER</parameter> adds <code>%Admin_Secure:U</code> and
/// <code>%DB_IRISSYS:R</code>, <parameter>AUDITUSER</parameter> adds those two plus
/// <code>%Admin_Operate:U</code>, <parameter>WALLETUSER</parameter> adds <code>%Admin_Wallet:U</code>
/// and <code>%DB_IRISSYS:R</code>, <parameter>WALLETNODBUSER</parameter> adds
/// <code>%Admin_Wallet:U</code> alone, <parameter>MANAGEUSER</parameter> (Story 6.11) adds
/// <code>%Admin_Manage:U</code> and <code>%DB_IRISSYS:R</code>, and
/// <parameter>MANAGEONLYUSER</parameter> (Story 6.12) adds <code>%Admin_Manage:U</code> alone.
/// Each screen gets its own accounts rather than widening an earlier one's, so every existing leg
/// still exercises the account it names.
/// <b>It creates security principals, so <method>OnBeforeAllTests</method> refuses to run unless
/// <parameter>ARMINGVARIABLE</parameter> arms it</b> (DW-289).</p>
/// <p>Needs the API application installed, at least one SSL/TLS configuration on the instance, which
/// <method>TestBothPairsReadEveryList</method> asserts rows for, the demo fixture, whose X.509
/// credential and <parameter>DEMOCOLLECTION</parameter> wallet collection give those lists rows, at
/// least one LDAP configuration, and a configured test account (<class>OcuPilot.Test.Http</class>)
/// that reads every role, resource, service, X.509 credential, LDAP configuration, wallet collection
/// and secret, because the pair tests hold each principal's rows to the account's.</p>
Class OcuPilot.Test.WireSecurityRead Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it, so the principals this class
/// creates exist on the container that script builds and nowhere else. Anything else -- absent,
/// empty, or a value that reads like a refusal such as <code>0</code> -- refuses (DW-289).</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal holding <code>%Admin_Secure:U</code> and not <code>%DB_IRISSYS:R</code>.</p>
Parameter SECUREUSER = "OcuPilotWireSecure";

/// <p>See <parameter>SECUREUSER</parameter>.</p>
Parameter SECUREROLE = "OcuPilotWireSecureRole";

/// <p>The principal holding <code>%DB_IRISSYS:R</code> and not <code>%Admin_Secure:U</code>.</p>
Parameter SYSREADUSER = "OcuPilotWireSysRead";

/// <p>See <parameter>SYSREADUSER</parameter>.</p>
Parameter SYSREADROLE = "OcuPilotWireSysReadRole";

/// <p>The principal holding both.</p>
Parameter BOTHUSER = "OcuPilotWireBoth";

/// <p>See <parameter>BOTHUSER</parameter>.</p>
Parameter BOTHROLE = "OcuPilotWireBothRole";

/// <p>The principal holding <code>%Admin_Task:U</code> and not <code>%DB_IRISSYS:R</code>.</p>
Parameter TASKUSER = "OcuPilotWireTask";

/// <p>See <parameter>TASKUSER</parameter>.</p>
Parameter TASKROLE = "OcuPilotWireTaskRole";

/// <p>The principal holding <code>%Admin_Task:U</code> and <code>%DB_IRISSYS:R</code>.</p>
Parameter TASKBOTHUSER = "OcuPilotWireTaskBoth";

/// <p>See <parameter>TASKBOTHUSER</parameter>.</p>
Parameter TASKBOTHROLE = "OcuPilotWireTaskBothRole";

/// <p>The principal holding <code>%Admin_Operate:U</code> and <code>%DB_IRISSYS:R</code> and not
/// <code>%Admin_Manage:U</code> -- the processes list's denied principal, and the one that shows the
/// middle pair is load-bearing rather than decorative.</p>
Parameter OPERATEUSER = "OcuPilotWireOperate";

/// <p>See <parameter>OPERATEUSER</parameter>.</p>
Parameter OPERATEROLE = "OcuPilotWireOperateRole";

/// <p>The principal holding all three of the processes list's pairs -- its allowed principal.
/// <code>%Admin_Manage:U</code> is granted to a purpose-built throwaway role on a throwaway
/// container and deleted in <method>OnAfterAllTests</method>; it is the narrower half of the
/// vendor query's own OR, the wider half being write on the IRISSYS database, which the
/// Consistency Conventions call a self-escalation primitive.</p>
Parameter PROCESSUSER = "OcuPilotWireProcess";

/// <p>See <parameter>PROCESSUSER</parameter>.</p>
Parameter PROCESSROLE = "OcuPilotWireProcessRole";

/// <p>The principal holding <code>%Admin_Operate:U</code> alone -- System usage's denied
/// principal (Story 6.9). Unlike <parameter>OPERATEUSER</parameter>, which already carries
/// <code>%DB_IRISSYS:R</code> alongside it (the processes list needs a third pair to prove, so its
/// own denied principal has to hold the database read already), System usage declares only the two
/// pairs, so proving the first one insufficient needs a principal that holds it and nothing else.</p>
Parameter OPERATEONLYUSER = "OcuPilotWireOperateOnly";

/// <p>See <parameter>OPERATEONLYUSER</parameter>.</p>
Parameter OPERATEONLYROLE = "OcuPilotWireOperateOnlyRole";

/// <p>The principal holding <code>%Admin_Secure:U</code> and <code>%DB_IRISSYS:R</code> and not
/// <code>%Admin_Operate:U</code> -- the audit database viewer's denied principal (DW-249). It holds
/// the endpoint's own gate, so what refuses it is the pair the <b>async-result poll</b> needs, which
/// no reading of <code>Record.ResourcesOR()</code> would have found.</p>
Parameter AUDITDENYUSER = "OcuPilotWireAuditDeny";

/// <p>See <parameter>AUDITDENYUSER</parameter>.</p>
Parameter AUDITDENYROLE = "OcuPilotWireAuditDenyRole";

/// <p>The principal holding all three of the audit database viewer's pairs -- its allowed
/// principal.</p>
Parameter AUDITUSER = "OcuPilotWireAudit";

/// <p>See <parameter>AUDITUSER</parameter>.</p>
Parameter AUDITROLE = "OcuPilotWireAuditRole";

/// <p>The principal holding <code>%Admin_Wallet:U</code> and <code>%DB_IRISSYS:R</code> and not
/// <code>%Admin_Secure:U</code> -- the Wallet and Secrets lists' allowed principal.</p>
Parameter WALLETUSER = "OcuPilotWireWallet";

/// <p>See <parameter>WALLETUSER</parameter>.</p>
Parameter WALLETROLE = "OcuPilotWireWalletRole";

/// <p>The principal holding <code>%Admin_Wallet:U</code> and not <code>%DB_IRISSYS:R</code>.</p>
Parameter WALLETNODBUSER = "OcuPilotWireWalletNoDb";

/// <p>See <parameter>WALLETNODBUSER</parameter>.</p>
Parameter WALLETNODBROLE = "OcuPilotWireWalletNoDbRole";

/// <p>The demo fixture's wallet collection, whose secrets the Secrets list is read for.</p>
Parameter DEMOCOLLECTION = "OcuPilotDemo";

/// <p>The principal holding <code>%Admin_Manage:U</code> and <code>%DB_IRISSYS:R</code> and not
/// <code>%Admin_Operate:U</code> -- AC7's own principal (Story 6.11): it reads the Databases
/// General view and Database volumes (both declare Manage alone as their first pair), and is
/// denied on the Free-space view and Database details, each naming <code>%Admin_Operate:USE</code>,
/// the first pair either declares that this principal does not hold.</p>
Parameter MANAGEUSER = "OcuPilotWireManage";

/// <p>See <parameter>MANAGEUSER</parameter>.</p>
Parameter MANAGEROLE = "OcuPilotWireManageRole";

/// <p>The principal holding <code>%Admin_Manage:U</code> alone, not <code>%DB_IRISSYS:R</code> --
/// the Devices list's denied principal (Story 6.12), analogous to
/// <parameter>OPERATEONLYUSER</parameter>: the Devices list declares only the two pairs
/// <parameter>MANAGEUSER</parameter> proves, so proving the first one insufficient needs a
/// principal that holds it and nothing else.</p>
Parameter MANAGEONLYUSER = "OcuPilotWireManageOnly";

/// <p>See <parameter>MANAGEONLYUSER</parameter>.</p>
Parameter MANAGEONLYROLE = "OcuPilotWireManageOnlyRole";

/// <p>The fourteen accounts' password for this run, generated in <method>OnBeforeAllTests</method> and
/// never written to source.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back, through
/// <code>$SYSTEM.Security.CheckUserPermission</code>, that each account holds exactly the pairs it
/// is meant to.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WireSecurityRead creates and deletes fourteen IRIS users and fourteen roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotSec" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

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
        Set tCodeRead = tSysDb.ResourceName _ ":R"

        Set tSC = ..EnsurePrincipal(..#SECUREROLE, ..#SECUREUSER, tCodeRead _ ",%Admin_Secure:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#SYSREADROLE, ..#SYSREADUSER, tCodeRead _ ",%DB_IRISSYS:R,%Admin_Operate:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#BOTHROLE, ..#BOTHUSER, tCodeRead _ ",%Admin_Secure:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#TASKROLE, ..#TASKUSER, tCodeRead _ ",%Admin_Task:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#TASKBOTHROLE, ..#TASKBOTHUSER, tCodeRead _ ",%Admin_Task:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#OPERATEROLE, ..#OPERATEUSER, tCodeRead _ ",%Admin_Operate:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#PROCESSROLE, ..#PROCESSUSER, tCodeRead _ ",%Admin_Operate:U,%Admin_Manage:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#OPERATEONLYROLE, ..#OPERATEONLYUSER, tCodeRead _ ",%Admin_Operate:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#AUDITDENYROLE, ..#AUDITDENYUSER, tCodeRead _ ",%Admin_Secure:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#AUDITROLE, ..#AUDITUSER, tCodeRead _ ",%Admin_Secure:U,%Admin_Operate:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#WALLETROLE, ..#WALLETUSER, tCodeRead _ ",%Admin_Wallet:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#WALLETNODBROLE, ..#WALLETNODBUSER, tCodeRead _ ",%Admin_Wallet:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#MANAGEROLE, ..#MANAGEUSER, tCodeRead _ ",%Admin_Manage:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#MANAGEONLYROLE, ..#MANAGEONLYUSER, tCodeRead _ ",%Admin_Manage:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit

        Set tSecure = ($SYSTEM.Security.CheckUserPermission(..#SECUREUSER, "%Admin_Secure", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#SECUREUSER, "%DB_IRISSYS", "READ") '= 1)
        Set tSysRead = ($SYSTEM.Security.CheckUserPermission(..#SYSREADUSER, "%Admin_Secure", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#SYSREADUSER, "%DB_IRISSYS", "READ") = 1)
        Set tBoth = ($SYSTEM.Security.CheckUserPermission(..#BOTHUSER, "%Admin_Secure", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#BOTHUSER, "%DB_IRISSYS", "READ") = 1)
        Set tTask = ($SYSTEM.Security.CheckUserPermission(..#TASKUSER, "%Admin_Task", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#TASKUSER, "%DB_IRISSYS", "READ") '= 1)
        Set tTaskBoth = ($SYSTEM.Security.CheckUserPermission(..#TASKBOTHUSER, "%Admin_Task", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#TASKBOTHUSER, "%DB_IRISSYS", "READ") = 1)
        Set tOperate = ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, "%Admin_Operate", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, "%DB_IRISSYS", "READ") = 1) && ($SYSTEM.Security.CheckUserPermission(..#OPERATEUSER, "%Admin_Manage", "USE") '= 1)
        Set tProcess = ($SYSTEM.Security.CheckUserPermission(..#PROCESSUSER, "%Admin_Operate", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#PROCESSUSER, "%Admin_Manage", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#PROCESSUSER, "%DB_IRISSYS", "READ") = 1)
        Set tOperateOnly = ($SYSTEM.Security.CheckUserPermission(..#OPERATEONLYUSER, "%Admin_Operate", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#OPERATEONLYUSER, "%DB_IRISSYS", "READ") '= 1)
        ; SECUREUSER is also the processes list's pair-ORDER principal, so the fact that it holds
        ; neither of that screen's administrative resources is read back rather than assumed.
        Set tSecureNoOperate = ($SYSTEM.Security.CheckUserPermission(..#SECUREUSER, "%Admin_Operate", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#SECUREUSER, "%Admin_Manage", "USE") '= 1)
        ; The audit viewer's pair set (DW-249): the denied principal holds the endpoint's own gate
        ; and the database read and NOT the async-result poll's resource, which is the whole point
        ; of the leg; the allowed one holds all three.
        Set tAuditDeny = ($SYSTEM.Security.CheckUserPermission(..#AUDITDENYUSER, "%Admin_Secure", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#AUDITDENYUSER, "%DB_IRISSYS", "READ") = 1) && ($SYSTEM.Security.CheckUserPermission(..#AUDITDENYUSER, "%Admin_Operate", "USE") '= 1)
        Set tAudit = ($SYSTEM.Security.CheckUserPermission(..#AUDITUSER, "%Admin_Secure", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#AUDITUSER, "%Admin_Operate", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#AUDITUSER, "%DB_IRISSYS", "READ") = 1)
        ; The wallet pairs: the allowed principal holds the wallet resource and the database read and
        ; not the secure resource; the denied one holds the wallet resource alone; and the both-pairs
        ; principal, which the wallet screens refuse, holds no wallet resource.
        Set tWallet = ($SYSTEM.Security.CheckUserPermission(..#WALLETUSER, "%Admin_Wallet", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#WALLETUSER, "%DB_IRISSYS", "READ") = 1) && ($SYSTEM.Security.CheckUserPermission(..#WALLETUSER, "%Admin_Secure", "USE") '= 1)
        Set tWalletNoDb = ($SYSTEM.Security.CheckUserPermission(..#WALLETNODBUSER, "%Admin_Wallet", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#WALLETNODBUSER, "%DB_IRISSYS", "READ") '= 1)
        Set tBothNoWallet = ($SYSTEM.Security.CheckUserPermission(..#BOTHUSER, "%Admin_Wallet", "USE") '= 1)
        Set tManage = ($SYSTEM.Security.CheckUserPermission(..#MANAGEUSER, "%Admin_Manage", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#MANAGEUSER, "%DB_IRISSYS", "READ") = 1) && ($SYSTEM.Security.CheckUserPermission(..#MANAGEUSER, "%Admin_Operate", "USE") '= 1)
        Set tManageOnly = ($SYSTEM.Security.CheckUserPermission(..#MANAGEONLYUSER, "%Admin_Manage", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#MANAGEONLYUSER, "%DB_IRISSYS", "READ") '= 1)
        Set ..PreparedSetupOk = tSecure && tSysRead && tBoth && tTask && tTaskBoth && tOperate && tProcess && tOperateOnly && tSecureNoOperate && tAuditDeny && tAudit && tWallet && tWalletNoDb && tBothNoWallet && tManage && tManageOnly
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the fourteen principals' pairs: secure " _ tSecure _ ", sysread " _ tSysRead _ ", both " _ tBoth _ ", task " _ tTask _ ", taskboth " _ tTaskBoth _ ", operate " _ tOperate _ ", process " _ tProcess _ ", operateonly " _ tOperateOnly _ ", secure-no-operate " _ tSecureNoOperate _ ", auditdeny " _ tAuditDeny _ ", audit " _ tAudit _ ", wallet " _ tWallet _ ", walletnodb " _ tWalletNoDb _ ", both-no-wallet " _ tBothNoWallet _ ", manage " _ tManage _ ", manageonly " _ tManageOnly)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the fourteen accounts and their roles, and <b>return a failing status</b> if any survives.
/// Reported through the status rather than assertions, which <code>%UnitTest.Manager</code> does not
/// record from this method (see <method>OcuPilot.Test.Wire.OnAfterAllTests</method>).</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        For tUser = ..#SECUREUSER, ..#SYSREADUSER, ..#BOTHUSER, ..#TASKUSER, ..#TASKBOTHUSER, ..#OPERATEUSER, ..#PROCESSUSER, ..#OPERATEONLYUSER, ..#AUDITDENYUSER, ..#AUDITUSER, ..#WALLETUSER, ..#WALLETNODBUSER, ..#MANAGEUSER, ..#MANAGEONLYUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ tUser
        }
        For tRole = ..#SECUREROLE, ..#SYSREADROLE, ..#BOTHROLE, ..#TASKROLE, ..#TASKBOTHROLE, ..#OPERATEROLE, ..#PROCESSROLE, ..#OPERATEONLYROLE, ..#AUDITDENYROLE, ..#AUDITROLE, ..#WALLETROLE, ..#WALLETNODBROLE, ..#MANAGEROLE, ..#MANAGEONLYROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ tRole
        }
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.WireSecurityRead teardown left throwaway objects on the instance: " _ tLeft)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create (or re-grant) one throwaway role and the account that holds it.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
Method EnsurePrincipal(pRole As %String, pUser As %String, pResources As %String, pPassword As %String) As %Status
{
    Set tSC = $$$OK
    If ##class(Security.Roles).Exists(pRole, .tR, .tRS) {
        Set tModProps("Resources") = pResources
        Set tModProps("GrantedRoles") = ""
        Set tModProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(pRole, .tModProps)
    } Else {
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: security read principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(pUser)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(pUser, pRole, pPassword, "OcuPilot security read test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.WireSecurityRead; deleted in OnAfterAllTests")
}

/// <p>The <var>pArea</var> entry's screens in the navigation map <var>pUser</var> is served, as JSON,
/// or <code>""</code> when the map does not answer.</p>
Method ScreensFor(pUser As %String, pArea As %String) As %String
{
    Set tScreens = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/navigation", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit ""
    Set tIterator = ##class(%DynamicObject).%FromJSON(tBody).areas.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tArea) {
        If tArea.key = pArea Set tScreens = tArea.screens.%ToJSON()
    }
    Quit tScreens
}

/// <p>The <var>pArea</var> entry's own verdict in the navigation map <var>pUser</var> is served, as
/// <code>allowed</code> alone or <code>allowed:failedPair</code>, or <code>""</code> when the map
/// does not answer.</p>
Method AreaVerdictFor(pUser As %String, pArea As %String) As %String
{
    Set tVerdict = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/navigation", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit ""
    Set tIterator = ##class(%DynamicObject).%FromJSON(tBody).areas.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tArea) {
        If tArea.key '= pArea Continue
        Set tVerdict = $Select(tArea.allowed: "true", 1: "false")
        If tArea.%IsDefined("failedPair") Set tVerdict = tVerdict _ ":" _ tArea.failedPair
    }
    Quit tVerdict
}

/// <p>Assert that <var>pUser</var>'s read of <var>pTool</var> is refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming <var>pPair</var>. <var>pQuery</var> is appended to the read's
/// query string as given, for a read that declares a criterion.</p>
Method AssertReadRefused(pUser As %String, pTool As %String, pPair As %String, pQuery As %String = "")
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ pTool _ "/read?maxRows=5" _ pQuery, pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, pUser _ " " _ pTool _ ": the read request completes")
    Do $$$AssertEquals(tStatus, 403, pUser _ " " _ pTool _ ": the read is refused")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", pUser _ " " _ pTool _ ": on the screen-privilege code")
    Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), pPair, pUser _ " " _ pTool _ ": naming " _ pPair)
    Do $$$AssertEquals(tRefusal.%GetTypeOf("rows"), "unassigned", pUser _ " " _ pTool _ ": with no rows")
}

/// <p>Story 2.8 AC5 -- the task schedule's pair set, proved with real principals. A caller holding
/// <code>%Admin_Task:USE</code> and not <code>%DB_IRISSYS:READ</code> is denied by name -- for the
/// screen, for the Tasks area and on the read route -- and granting the pair serves the list.</p>
/// <p><b>Why the denial has to be a real principal.</b> <code>%All</code> passes every resource
/// check, so the suite's own account could never observe it; and without the second pair the vendor
/// endpoint fails inside <code>%SYS</code> and the port answers 500, which is the failure the pair
/// turns into a named 403.</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class> -> the read answers 500 and the entry
/// and 403 assertions go red.</p>
Method TestTheTaskSchedulesPairSetIsEnforcedForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")

    Do $$$AssertEquals(..ScreensFor(..#TASKUSER, "tasks"), "[{""route"":""tasks/schedule/details"",""labelKey"":""taskDetailsLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""tasks/schedule/edit"",""labelKey"":""proposalEntityTask"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""tasks/schedule/history"",""labelKey"":""taskRunsLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""tasks/schedule"",""labelKey"":""taskListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""tasks/on-demand"",""labelKey"":""taskOnDemandLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""tasks/upcoming"",""labelKey"":""taskUpcomingLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""tasks/history"",""labelKey"":""taskHistoryLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""tasks/background"",""labelKey"":""backgroundTaskListLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_Operate:USE""}]", "%Admin_Task alone: the seven task screens (the unlisted task details, the New Task wizard and per-task history first) are denied on %DB_IRISSYS:READ, and Background tasks on its own %Admin_Operate:USE")
    Do $$$AssertEquals(..AreaVerdictFor(..#TASKUSER, "tasks"), "false:%DB_IRISSYS:READ", "and so is the Tasks area")
    Do ..AssertReadRefused(..#TASKUSER, "tasks.schedule", "%DB_IRISSYS:READ")

    Do $$$AssertEquals(..ScreensFor(..#TASKBOTHUSER, "tasks"), "[{""route"":""tasks/schedule/details"",""labelKey"":""taskDetailsLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""tasks/schedule/edit"",""labelKey"":""proposalEntityTask"",""sideBarPosition"":0,""allowed"":true},{""route"":""tasks/schedule/history"",""labelKey"":""taskRunsLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""tasks/schedule"",""labelKey"":""taskListLabel"",""sideBarPosition"":1,""allowed"":true},{""route"":""tasks/on-demand"",""labelKey"":""taskOnDemandLabel"",""sideBarPosition"":2,""allowed"":true},{""route"":""tasks/upcoming"",""labelKey"":""taskUpcomingLabel"",""sideBarPosition"":3,""allowed"":true},{""route"":""tasks/history"",""labelKey"":""taskHistoryLabel"",""sideBarPosition"":4,""allowed"":true},{""route"":""tasks/background"",""labelKey"":""backgroundTaskListLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_Operate:USE""}]", "both pairs: the seven task screens (the unlisted task details, the New Task wizard and per-task history first) are listed allowed, and Background tasks is denied on its own %Admin_Operate:USE")
    Do $$$AssertEquals(..AreaVerdictFor(..#TASKBOTHUSER, "tasks"), "true", "and so is the Tasks area")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/tasks.schedule/read?maxRows=1000", ..#TASKBOTHUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the task schedule read completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    If tStatus '= 200 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    ; Story 5.11 added Suspended, taken per row from the same endpoint's INFO (DW-269, AD-36): it
    ; is the eighth declared field and the only one the vendor's own LIST row does not carry.
    Set tFields = "[""Name"",""Type"",""Namespace"",""Description"",""Id"",""LastFinished"",""NextScheduled"",""Suspended""]"
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), tFields, "with the eight declared fields")
    Do $$$AssertTrue(tAnswer.rows.%Size() > 0, "and the instance's tasks listed: " _ tAnswer.rows.%Size())
    Set tBad = ""
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tKeys = []
        Set tKeyIterator = tRow.%GetIterator()
        While tKeyIterator.%GetNext(.tKey, .tValue) {
            Do tKeys.%Push(tKey)
        }
        If tKeys.%ToJSON() '= tFields Set tBad = "row " _ tIndex _ " carries " _ tKeys.%ToJSON()
        If tBad '= "" Quit
    }
    Do $$$AssertEquals(tBad, "", "every row carries exactly the eight declared fields, the detail call's Suspended among them")
    ; The banner is screen chrome the read resolves (AD-36); on a throwaway whose Task Manager is
    ; running it is the empty string, and the suspended half is the browser spec's.
    Do $$$AssertEquals(tAnswer.%GetTypeOf("banner"), "string", "the answer carries the banner key as a string")
    Do $$$AssertEquals(tAnswer.banner, "", "empty while the Task Manager is running")
}

/// <p>Story 6.5 -- the Pairs row: On-demand tasks and Upcoming tasks declare the task schedule's pair
/// set, proved with the same principals. <code>%Admin_Task:USE</code> alone is refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming <code>%DB_IRISSYS:READ</code> on both routes, never 500; with
/// both pairs each route answers 200 with the rows the configured test account reads over the wire
/// for the same cap and horizon (<method>AssertSameRowsAsTestAccount</method>).</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.TaskUpcomingList</class> -&gt; its read answers 500 and the
/// refusal assertions go red.</p>
/// <p>Mutation: add a third, unheld privilege to <class>OcuPilot.Screen.Descriptor.TaskUpcomingList</class>
/// (<code>%Admin_Operate:USE</code>) -&gt; <method>AssertSameRowsAsTestAccount</method>'s "and answers"
/// assertion for the both-pairs caller goes red instead, since the over-declared set now refuses a
/// principal holding exactly the documented pair.</p>
Method TestOnDemandAndUpcomingTasksPairSetsAreEnforcedForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")
    Do ..AssertReadRefused(..#TASKUSER, "tasks.ondemand", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#TASKUSER, "tasks.upcoming", "%DB_IRISSYS:READ", "&hoursOffset=24")

    Do ..AssertSameRowsAsTestAccount(..#TASKBOTHUSER, "tasks.ondemand")
    Do ..AssertSameRowsAsTestAccount(..#TASKBOTHUSER, "tasks.upcoming", "&hoursOffset=24")
}

/// <p>Story 6.6, Matrix "Pairs" -- Task history (all) and the per-task history declare the task
/// schedule's own pair set, proved with the same real principals: a caller holding
/// <code>%Admin_Task:USE</code> alone is denied by name on both routes, and granting
/// <code>%DB_IRISSYS:READ</code> too serves the same rows the test account reads.</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.TaskHistoryList</class> or
/// <class>OcuPilot.Screen.Descriptor.TaskRunList</class> -&gt; the registry refuses to validate the
/// roster, naming that descriptor's missing pair, before any read is served.</p>
Method TestTaskHistoryPairSetsAreEnforcedForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")
    Do ..AssertReadRefused(..#TASKUSER, "tasks.history", "%DB_IRISSYS:READ", "&search=OcuPilot")
    Do ..AssertReadRefused(..#TASKUSER, "tasks.taskhistory", "%DB_IRISSYS:READ")

    Do ..AssertSameRowsAsTestAccount(..#TASKBOTHUSER, "tasks.history", "&search=OcuPilotDemo%20nightly", "OcuPilotDemo nightly")
    Do ..AssertSameRowsAsTestAccount(..#TASKBOTHUSER, "tasks.taskhistory")
}

/// <p>The demo fixture task's own numeric <code>Id</code>, read through the test account's
/// <code>tasks.schedule</code> list -- the same discovery <class>OcuPilot.Test.TaskDetails</class>
/// performs on its own throwaway. <code>""</code> when the row cannot be found or read.</p>
Method DemoTaskId() As %String
{
    Set tId = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/tasks.schedule/read?maxRows=1000", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit tId
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Extract(tRow.Name, 1, $Length(..#DEMOCOLLECTION)) = ..#DEMOCOLLECTION {
            Set tId = tRow.Id
            Quit
        }
    }
    Quit tId
}

/// <p>Story 6.7, Matrix "Pairs" -- Task details declares the task schedule's own pair set, proved
/// with the same real principals: a caller holding <code>%Admin_Task:USE</code> alone is denied by
/// name, and granting <code>%DB_IRISSYS:READ</code> too serves the same row the test account
/// reads.</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.TaskDetails</class> -&gt; the registry refuses to validate the
/// roster, naming that descriptor's missing pair, before any read is served.</p>
Method TestTaskDetailsPairSetIsEnforcedForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")
    Set tTaskId = ..DemoTaskId()
    Do $$$AssertTrue(tTaskId '= "", "the demo task's Id was found")
    If tTaskId = "" Quit
    Do ..AssertReadRefused(..#TASKUSER, "tasks.taskdetails", "%DB_IRISSYS:READ", "&taskId=" _ tTaskId)
    Do ..AssertSameRowsAsTestAccount(..#TASKBOTHUSER, "tasks.taskdetails", "&taskId=" _ tTaskId)
}

/// <p>Story 2.9 AC5 -- the processes list's three-pair set, proved with real principals. A caller
/// holding <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code> and not
/// <code>%Admin_Manage:USE</code> is denied by name, for the screen and on the read route, while the OS
/// management area opens on the screens those two pairs admit (AD-8); a caller holding all three is
/// served the list, every row carrying exactly the seven declared fields.</p>
/// <p><b>The middle pair is the one this leg exists for.</b> The query behind the endpoint
/// (<method>%SYS.ProcessQuery.CONTROLPANELExecute</method>) checks that resource, or write on the
/// IRISSYS database, for itself, and <code>%Api.Admin.Util.ClassQuery</code> never reads what
/// <code>%Execute()</code> answered -- so the vendor's own refusal reaches OcuPilot as nothing but
/// an error status. Declaring the pair is what turns that into the refusal AD-8 asks for, and
/// dropping it from the descriptor is what makes this leg red.</p>
/// <p>Since Story 2.13 (DW-274), dropping it no longer produces a 500 either: with the screen's
/// gate passed, <class>OcuPilot.Port.AdminPort</class> probes its own
/// <parameter>QUERYPAIRS</parameter> declaration on the error path and answers <b>403</b>
/// <code>PORT.ACCESSDENIED</code> with <code>detail.failedPair</code> naming
/// <code>%Admin_Manage:USE</code>. An under-declared screen is therefore refused by name at the
/// port rather than reported as an internal error -- which is defence in depth, not the gate: the
/// descriptor's own pair set is what refuses this leg's principal, before any port is reached.</p>
/// <p><b>The declared pair ORDER is pinned by a third principal.</b> The denied principal above
/// holds the first pair, so the second is the only unheld one under either ordering and a swap is
/// invisible to it. <parameter>SECUREUSER</parameter> holds neither administrative resource, so it
/// reads whichever pair the descriptor declares first -- which is what
/// <method>OcuPilot.Screen.Gate.EvaluatePairs</method> reports and what both client fixtures
/// carry.</p>
/// <p><b>Why the denial has to be a real principal.</b> <code>%All</code> passes every resource
/// check, so the suite's own account could never observe it.</p>
/// <p>Mutation, run on a throwaway and reverted (Story 3.0, DW-307): remove
/// <code>%Admin_Manage:USE</code> from <class>OcuPilot.Screen.Descriptor.ProcessList</class> alone
/// -- the read route gates on the descriptor, not on the area -- and
/// <parameter>OPERATEUSER</parameter> was observed to receive <b>403</b>
/// <code>PORT.ACCESSDENIED</code> with <code>detail.failedPair</code> <code>%Admin_Manage:USE</code>,
/// so <method>AssertReadRefused</method>'s code assertion and this leg's
/// <method>ScreensFor</method> verdict go red while its status and <code>failedPair</code>
/// assertions and the area verdict stay green. Swap the descriptor's first two pairs, observed on
/// the same throwaway (Story 3.0, DW-322): only <parameter>SECUREUSER</parameter>'s
/// <method>ScreensFor</method> verdict goes red, naming <code>%Admin_Manage:USE</code> instead;
/// its <method>AreaVerdictFor</method> reads the area's own untouched order and stays green, with
/// every other principal's assertion.</p>
Method TestTheProcessesListsPairSetIsEnforcedForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")

    ; Story 6.11 took the roster from four screens to eight, and Story 6.12 took it from eight to
    ; nine, in ScreensForArea's own (sideBarPosition, class name) collation: the unlisted
    ; sideBarPosition-0 screens sort first, alphabetically by descriptor class name (Database
    ; details, Database free-space, Database volumes, then Process details), ahead of the listed
    ; ones in position order (Processes, Locks, System usage, Databases, Devices). Every
    ; assertion below states the full roster, not an append to an older one. Story 8.8's
    ; device editor and Story 18.2's namespace editor, unlisted, sort between Database volumes and
    ; Process details, and the Namespaces list follows Devices, at position 7. Story 18.14's three mapping
    ; lists and their editors, unlisted and gated on the Namespaces pairs, sort by class name among
    ; them, and so does Story 18.3's local database editor. Story 16.7's three unlisted License usage
    ; tabs sort among them too; its Summary tab and the Dashboard follow Namespaces at positions 8 and
    ; 9. Story 16.10's unlisted Activity log, and Story 16.25's editor after it, sort before the License
    ; usage tabs, and External language
    ; servers comes at position 10, refused on its own pair to every principal here; the Local
    ; databases list comes at position 11, and Story 18.16's Remote databases last, at position 12,
    ; its unlisted form sorting after Process details.
    ; Story 18.4's Check integrity, unlisted, sorts after Database free-space, and the Integrity log is
    ; listed at position 5, right after Databases.
    ; Story 18.5's journal file databases and details, unlisted, sort after the global mappings list,
    ; and Journals is listed last, at position 13, on OS management's operate pair and the system
    ; database's read.
    ; Story 18.19's unlisted Journal records sorts after the journal file details, on the same pairs.
    ; Story 18.6's License key and License servers are listed at 15 and 16, after Journal settings, and
    ; its unlisted license server editor sorts between License usage's By process and By user tabs, each
    ; on OS management's manage pair and the system database's read.
    Do $$$AssertEquals(..ScreensFor(..#OPERATEUSER, "os-management"), "[{""route"":""os-management/databases/details"",""labelKey"":""databaseDetailsLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/database-free-space"",""labelKey"":""databaseFreeSpaceLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/databases/integrity"",""labelKey"":""databaseIntegrityLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/databases/volumes"",""labelKey"":""databaseVolumeListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/devices/edit"",""labelKey"":""deviceFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces/global-mappings/edit"",""labelKey"":""globalMappingFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces/global-mappings"",""labelKey"":""globalMappingListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/journals/databases"",""labelKey"":""journalFileDatabaseListLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/journals/details"",""labelKey"":""journalFileDetailsLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/journal-records"",""labelKey"":""journalRecordListLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/language-servers/activity"",""labelKey"":""languageServerActivityLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_ExternalLanguageServerEdit:USE""},{""route"":""os-management/language-servers/edit"",""labelKey"":""languageServerFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_ExternalLanguageServerEdit:USE""},{""route"":""os-management/license-usage/distributed"",""labelKey"":""licenseUsageDistributed"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/license-usage/processes"",""labelKey"":""licenseUsageByProcess"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/license-servers/edit"",""labelKey"":""aboutLicenseServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/license-usage/users"",""labelKey"":""licenseUsageByUser"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/local-databases/edit"",""labelKey"":""systemInfoDatabase"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces/edit"",""labelKey"":""headerNamespaceLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces/package-mappings/edit"",""labelKey"":""packageMappingFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces/package-mappings"",""labelKey"":""packageMappingListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/processes/details"",""labelKey"":""processDetailsLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/remote-databases/edit"",""labelKey"":""remoteDatabaseFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces/routine-mappings/edit"",""labelKey"":""routineMappingFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces/routine-mappings"",""labelKey"":""routineMappingListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/processes"",""labelKey"":""processListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/locks"",""labelKey"":""lockListLabel"",""sideBarPosition"":2,""allowed"":true},{""route"":""os-management/system-usage"",""labelKey"":""systemUsageLabel"",""sideBarPosition"":3,""allowed"":true},{""route"":""os-management/databases"",""labelKey"":""databaseListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/databases/integrity-log"",""labelKey"":""databaseIntegrityLogLabel"",""sideBarPosition"":5,""allowed"":true},{""route"":""os-management/devices"",""labelKey"":""deviceListLabel"",""sideBarPosition"":6,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces"",""labelKey"":""namespaceListLabel"",""sideBarPosition"":7,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/license-usage"",""labelKey"":""licenseUsageLabel"",""sideBarPosition"":8,""allowed"":true},{""route"":""os-management/dashboard"",""labelKey"":""dashboardLabel"",""sideBarPosition"":9,""allowed"":true},{""route"":""os-management/language-servers"",""labelKey"":""languageServersLabel"",""sideBarPosition"":10,""allowed"":false,""failedPair"":""%Admin_ExternalLanguageServerEdit:USE""},{""route"":""os-management/local-databases"",""labelKey"":""localDatabaseListLabel"",""sideBarPosition"":11,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/remote-databases"",""labelKey"":""remoteDatabaseListLabel"",""sideBarPosition"":12,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/journals"",""labelKey"":""journalListLabel"",""sideBarPosition"":13,""allowed"":true},{""route"":""os-management/journal-settings"",""labelKey"":""journalSettingsLabel"",""sideBarPosition"":14,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/license-key"",""labelKey"":""licenseKeyLabel"",""sideBarPosition"":15,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/license-servers"",""labelKey"":""licenseServerListLabel"",""sideBarPosition"":16,""allowed"":false,""failedPair"":""%Admin_Manage:USE""}]", "%Admin_Operate and the database read: Process details, the processes list, the Databases General view, the Free-space view, the Volume files, Check integrity, Devices, Namespaces, Local databases, Remote databases and the three mapping lists are all denied on %Admin_Manage:USE, and so are Journal settings, which names it first (Story 18.18), and License key, License servers and the license server editor (Story 18.6), since Story 6.11's three declare it too (in two orders) and Devices, Namespaces, the mapping screens, the local and remote database screens and Check integrity do as well (Stories 6.12, 18.2, 18.14, 18.3, 18.4, 18.16); External language servers, its Activity log and its editor are denied on their own %Admin_ExternalLanguageServerEdit:USE (Stories 16.10 and 16.25); Database details, the Integrity log, Locks, System usage, License usage's four tabs, the Dashboard, Journals and its two unlisted screens -- each a two-pair set naming Operate alone -- are allowed")
    Do $$$AssertEquals(..AreaVerdictFor(..#OPERATEUSER, "os-management"), "true", "while the OS management area opens, since Locks, System usage, License usage and the Dashboard admit it (AD-8 as amended for DW-1768)")
    Do ..AssertReadRefused(..#OPERATEUSER, "osmgmt.processes", "%Admin_Manage:USE")

    ; The pair ORDER, read by a principal holding neither administrative resource: %Admin_Operate:USE
    ; is declared first, so it is the pair the gate names. A descriptor that declared the first two
    ; the other way round would name %Admin_Manage:USE here, and nothing else in this class would move.
    Do $$$AssertEquals(..ScreensFor(..#SECUREUSER, "os-management"), "[{""route"":""os-management/databases/details"",""labelKey"":""databaseDetailsLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/database-free-space"",""labelKey"":""databaseFreeSpaceLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/databases/integrity"",""labelKey"":""databaseIntegrityLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/databases/volumes"",""labelKey"":""databaseVolumeListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/devices/edit"",""labelKey"":""deviceFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces/global-mappings/edit"",""labelKey"":""globalMappingFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces/global-mappings"",""labelKey"":""globalMappingListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/journals/databases"",""labelKey"":""journalFileDatabaseListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/journals/details"",""labelKey"":""journalFileDetailsLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/journal-records"",""labelKey"":""journalRecordListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/language-servers/activity"",""labelKey"":""languageServerActivityLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_ExternalLanguageServerEdit:USE""},{""route"":""os-management/language-servers/edit"",""labelKey"":""languageServerFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_ExternalLanguageServerEdit:USE""},{""route"":""os-management/license-usage/distributed"",""labelKey"":""licenseUsageDistributed"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/license-usage/processes"",""labelKey"":""licenseUsageByProcess"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/license-servers/edit"",""labelKey"":""aboutLicenseServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/license-usage/users"",""labelKey"":""licenseUsageByUser"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/local-databases/edit"",""labelKey"":""systemInfoDatabase"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces/edit"",""labelKey"":""headerNamespaceLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces/package-mappings/edit"",""labelKey"":""packageMappingFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces/package-mappings"",""labelKey"":""packageMappingListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/processes/details"",""labelKey"":""processDetailsLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/remote-databases/edit"",""labelKey"":""remoteDatabaseFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces/routine-mappings/edit"",""labelKey"":""routineMappingFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces/routine-mappings"",""labelKey"":""routineMappingListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/processes"",""labelKey"":""processListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/locks"",""labelKey"":""lockListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/system-usage"",""labelKey"":""systemUsageLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/databases"",""labelKey"":""databaseListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/databases/integrity-log"",""labelKey"":""databaseIntegrityLogLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/devices"",""labelKey"":""deviceListLabel"",""sideBarPosition"":6,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/namespaces"",""labelKey"":""namespaceListLabel"",""sideBarPosition"":7,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/license-usage"",""labelKey"":""licenseUsageLabel"",""sideBarPosition"":8,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/dashboard"",""labelKey"":""dashboardLabel"",""sideBarPosition"":9,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/language-servers"",""labelKey"":""languageServersLabel"",""sideBarPosition"":10,""allowed"":false,""failedPair"":""%Admin_ExternalLanguageServerEdit:USE""},{""route"":""os-management/local-databases"",""labelKey"":""localDatabaseListLabel"",""sideBarPosition"":11,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/remote-databases"",""labelKey"":""remoteDatabaseListLabel"",""sideBarPosition"":12,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/journals"",""labelKey"":""journalListLabel"",""sideBarPosition"":13,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""os-management/journal-settings"",""labelKey"":""journalSettingsLabel"",""sideBarPosition"":14,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/license-key"",""labelKey"":""licenseKeyLabel"",""sideBarPosition"":15,""allowed"":false,""failedPair"":""%Admin_Manage:USE""},{""route"":""os-management/license-servers"",""labelKey"":""licenseServerListLabel"",""sideBarPosition"":16,""allowed"":false,""failedPair"":""%Admin_Manage:USE""}]", "a principal holding neither administrative resource is denied on the first pair each screen declares -- Operate for the fifteen that name it first, Manage for the twenty-two that name it first, Journal settings (Story 18.18) and Story 18.6's three among them, and External language servers' own pair for its three screens")
    Do $$$AssertEquals(..AreaVerdictFor(..#SECUREUSER, "os-management"), "false:%Admin_Operate:USE", "and so is the area, which declares them in the same order")

    Do $$$AssertEquals(..ScreensFor(..#PROCESSUSER, "os-management"), "[{""route"":""os-management/databases/details"",""labelKey"":""databaseDetailsLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/database-free-space"",""labelKey"":""databaseFreeSpaceLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/databases/integrity"",""labelKey"":""databaseIntegrityLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/databases/volumes"",""labelKey"":""databaseVolumeListLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/devices/edit"",""labelKey"":""deviceFormLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/namespaces/global-mappings/edit"",""labelKey"":""globalMappingFormLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/namespaces/global-mappings"",""labelKey"":""globalMappingListLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/journals/databases"",""labelKey"":""journalFileDatabaseListLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/journals/details"",""labelKey"":""journalFileDetailsLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/journal-records"",""labelKey"":""journalRecordListLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/language-servers/activity"",""labelKey"":""languageServerActivityLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_ExternalLanguageServerEdit:USE""},{""route"":""os-management/language-servers/edit"",""labelKey"":""languageServerFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_ExternalLanguageServerEdit:USE""},{""route"":""os-management/license-usage/distributed"",""labelKey"":""licenseUsageDistributed"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/license-usage/processes"",""labelKey"":""licenseUsageByProcess"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/license-servers/edit"",""labelKey"":""aboutLicenseServer"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/license-usage/users"",""labelKey"":""licenseUsageByUser"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/local-databases/edit"",""labelKey"":""systemInfoDatabase"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/namespaces/edit"",""labelKey"":""headerNamespaceLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/namespaces/package-mappings/edit"",""labelKey"":""packageMappingFormLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/namespaces/package-mappings"",""labelKey"":""packageMappingListLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/processes/details"",""labelKey"":""processDetailsLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/remote-databases/edit"",""labelKey"":""remoteDatabaseFormLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/namespaces/routine-mappings/edit"",""labelKey"":""routineMappingFormLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/namespaces/routine-mappings"",""labelKey"":""routineMappingListLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""os-management/processes"",""labelKey"":""processListLabel"",""sideBarPosition"":1,""allowed"":true},{""route"":""os-management/locks"",""labelKey"":""lockListLabel"",""sideBarPosition"":2,""allowed"":true},{""route"":""os-management/system-usage"",""labelKey"":""systemUsageLabel"",""sideBarPosition"":3,""allowed"":true},{""route"":""os-management/databases"",""labelKey"":""databaseListLabel"",""sideBarPosition"":4,""allowed"":true},{""route"":""os-management/databases/integrity-log"",""labelKey"":""databaseIntegrityLogLabel"",""sideBarPosition"":5,""allowed"":true},{""route"":""os-management/devices"",""labelKey"":""deviceListLabel"",""sideBarPosition"":6,""allowed"":true},{""route"":""os-management/namespaces"",""labelKey"":""namespaceListLabel"",""sideBarPosition"":7,""allowed"":true},{""route"":""os-management/license-usage"",""labelKey"":""licenseUsageLabel"",""sideBarPosition"":8,""allowed"":true},{""route"":""os-management/dashboard"",""labelKey"":""dashboardLabel"",""sideBarPosition"":9,""allowed"":true},{""route"":""os-management/language-servers"",""labelKey"":""languageServersLabel"",""sideBarPosition"":10,""allowed"":false,""failedPair"":""%Admin_ExternalLanguageServerEdit:USE""},{""route"":""os-management/local-databases"",""labelKey"":""localDatabaseListLabel"",""sideBarPosition"":11,""allowed"":true},{""route"":""os-management/remote-databases"",""labelKey"":""remoteDatabaseListLabel"",""sideBarPosition"":12,""allowed"":true},{""route"":""os-management/journals"",""labelKey"":""journalListLabel"",""sideBarPosition"":13,""allowed"":true},{""route"":""os-management/journal-settings"",""labelKey"":""journalSettingsLabel"",""sideBarPosition"":14,""allowed"":false,""failedPair"":""%Admin_Journal:USE""},{""route"":""os-management/license-key"",""labelKey"":""licenseKeyLabel"",""sideBarPosition"":15,""allowed"":true},{""route"":""os-management/license-servers"",""labelKey"":""licenseServerListLabel"",""sideBarPosition"":16,""allowed"":true}]", "all three pairs: thirty-six of the forty os-management screens are listed allowed, Story 18.6's three among them, External language servers, its Activity log and its editor refused on their own pair, and Journal settings on its own %Admin_Journal:USE (Story 18.18)")
    Do $$$AssertEquals(..AreaVerdictFor(..#PROCESSUSER, "os-management"), "true", "and so is the OS management area")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/osmgmt.processes/read?maxRows=1000", ..#PROCESSUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the processes read completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    If tStatus '= 200 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Set tFields = "[""Pid"",""Username"",""Nspace"",""Routine"",""State"",""Commands"",""Globals"",""CanReceiveBroadcast""]"
    Do $$$AssertEquals(tAnswer.fields.%ToJSON(), tFields, "with the eight declared fields, the vendor's Nspace spelling and Story 16.6's broadcast flag included")
    ; The caller is itself a process, so a zero-row answer would mean the read is not reading the
    ; instance at all.
    Do $$$AssertTrue(tAnswer.rows.%Size() > 0, "and the instance's processes listed: " _ tAnswer.rows.%Size())
    Set tBad = ""
    Set tNotNumber = ""
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tKeys = []
        Set tKeyIterator = tRow.%GetIterator()
        While tKeyIterator.%GetNext(.tKey, .tValue) {
            Do tKeys.%Push(tKey)
        }
        If tKeys.%ToJSON() '= tFields Set tBad = "row " _ tIndex _ " carries " _ tKeys.%ToJSON()
        ; The two `number` columns must arrive as JSON numbers, not as text. The client's shared
        ; view sorts numerically only on a number (OcuPilot's screen-read compare), while the right
        ; alignment and the tabular face come from the declared kind either way -- so a counter
        ; delivered as a string sorts "9" after "12345" with every other assertion still green.
        For tCounter = "Commands", "Globals" {
            If tRow.%GetTypeOf(tCounter) '= "number" {
                Set tNotNumber = "row " _ tIndex _ " carries " _ tCounter _ " as " _ tRow.%GetTypeOf(tCounter)
            }
        }
        If (tBad '= "") || (tNotNumber '= "") Quit
    }
    Do $$$AssertEquals(tBad, "", "every row carries exactly the seven declared fields, none of the four CanBe* gates among them")
    Do $$$AssertEquals(tNotNumber, "", "and both counter columns arrive as JSON numbers, which is what makes their sort numeric")
    ; A list screen that declares no banner answers the key as the empty string rather than omitting
    ; it, so the client's strip has one thing to read on every list. The type is asserted beside the
    ; value because an absent key reads back as "" too, so the value alone cannot tell the two apart.
    Do $$$AssertEquals(tAnswer.%GetTypeOf("banner"), "string", "the answer carries a banner key rather than omitting it")
    Do $$$AssertEquals(tAnswer.banner, "", "and the screen declares no banner, so none is raised")
}

/// <p>AC7, Story 6.11 -- Databases' four screens over two pair sets, proved with a real principal
/// holding exactly <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code>
/// (<parameter>MANAGEUSER</parameter>): the General view (<code>osmgmt.databases</code>) and
/// Database volumes (<code>osmgmt.databasevolumes</code>) both declare Manage alone as their first
/// pair and are served; the Free-space view (<code>osmgmt.databasefreespace</code>) and Database
/// details (<code>osmgmt.databasedetails</code>) are denied naming
/// <code>%Admin_Operate:USE</code> -- the first pair either declares that this principal does not
/// hold -- never a 500 and never an empty state. <parameter>OPERATEUSER</parameter> (holding
/// <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>, not
/// <code>%Admin_Manage:USE</code>) is the complementary leg: it reads Database details, whose two
/// pairs it holds in full, and is denied on the other three, each naming
/// <code>%Admin_Manage:USE</code>.</p>
/// <p>Mutation: remove <code>%Admin_Operate:USE</code> from
/// <class>OcuPilot.Screen.Descriptor.DatabaseFreeSpace</class>'s <code>privileges</code> ->
/// <parameter>MANAGEUSER</parameter>'s denial assertion for that screen goes red, since a principal
/// holding only Manage and the database read would then be served the async poll it cannot pass.</p>
Method TestTheDatabasesPairSetsAreEnforcedForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")

    Do ..AssertSameRowsAsTestAccount(..#MANAGEUSER, "osmgmt.databases")
    Do ..AssertReadRefused(..#MANAGEUSER, "osmgmt.databasefreespace", "%Admin_Operate:USE")
    Do ..AssertReadRefused(..#MANAGEUSER, "osmgmt.databasedetails", "%Admin_Operate:USE")

    ; Database volumes is parent-scoped: its one criterion, dir, is required before the port is
    ; asked, so a real directory is looked up first through the General view MANAGEUSER already
    ; reads.
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/osmgmt.databases/read?maxRows=1", ..#MANAGEUSER, ..PreparedPassword, .tListStatus, .tListBody, .tListHeaders)
    Do $$$AssertStatusOK(tSC, "the Databases list read completes")
    Do $$$AssertEquals(tListStatus, 200, "and answers, since MANAGEUSER holds the General view's own pair")
    Set tDir = ""
    If tListStatus = 200 {
        Set tRows = ##class(%DynamicObject).%FromJSON(tListBody).rows
        If tRows.%Size() > 0 Set tDir = tRows.%Get(0).Directory
    }
    Do $$$AssertTrue(tDir '= "", "a directory was found to key the volumes read by")
    If tDir = "" Quit

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/osmgmt.databasevolumes/read?maxRows=10&dir=" _ tDir, ..#MANAGEUSER, ..PreparedPassword, .tVolStatus, .tVolBody, .tVolHeaders)
    Do $$$AssertStatusOK(tSC, "the Database volumes read completes")
    Do $$$AssertEquals(tVolStatus, 200, "and answers, since MANAGEUSER holds VOLUMELIST's own Manage-only pair")
    If tVolStatus = 200 Do $$$AssertTrue(##class(%DynamicObject).%FromJSON(tVolBody).rows.%Size() > 0, "with at least one volume file")

    ; The complementary leg: Operate alone reads Database details in full and is denied on the
    ; other three, each naming the one pair this principal lacks, Manage.
    Set tPid = $Job
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/osmgmt.databasedetails/read?maxRows=1&dir=" _ tDir, ..#OPERATEUSER, ..PreparedPassword, .tDetStatus, .tDetBody, .tDetHeaders)
    Do $$$AssertStatusOK(tSC, "OPERATEUSER's Database details read completes")
    Do $$$AssertEquals(tDetStatus, 200, "and answers, since OPERATEUSER holds Database details' own two pairs in full")
    If tDetStatus = 200 Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tDetBody).rows.%Size(), 1, "one row, for the same directory")

    Do ..AssertReadRefused(..#OPERATEUSER, "osmgmt.databases", "%Admin_Manage:USE")
    Do ..AssertReadRefused(..#OPERATEUSER, "osmgmt.databasefreespace", "%Admin_Manage:USE")
    Do ..AssertReadRefused(..#OPERATEUSER, "osmgmt.databasevolumes", "%Admin_Manage:USE", "&dir=" _ tDir)
}

/// <p>Story 6.8, Matrix "Pairs" -- Process details declares the processes list's own three-pair
/// set, proved with the same real principals: <parameter>OPERATEUSER</parameter> (holding
/// <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>, not
/// <code>%Admin_Manage:USE</code>) is refused naming <code>%Admin_Manage:USE</code>, and
/// <parameter>PROCESSUSER</parameter> (holding exactly the three) reads 200 with one row for this
/// test process's own <code>$Job</code> -- a real, live process on this instance for the length of
/// the request -- which is AD-29's real-principal confirmation for the screen's own pair set.</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.ProcessDetails</class> -&gt; the registry refuses to validate
/// the roster, naming that descriptor's missing pair, before any read is served.</p>
Method TestTheProcessDetailsPairSetIsEnforcedForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")
    Set tPid = $Job

    Do ..AssertReadRefused(..#OPERATEUSER, "osmgmt.processdetails", "%Admin_Manage:USE", "&pid=" _ tPid)

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/osmgmt.processdetails/read?maxRows=5&pid=" _ tPid, ..#PROCESSUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the process details read completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    If tStatus '= 200 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.rows.%Size(), 1, "exactly one row, for this test process's own live pid")
    If tAnswer.rows.%Size() '= 1 Quit
    Do $$$AssertEquals(tAnswer.rows.%Get(0).Pid, tPid, "naming this test process's own Pid")
}

/// <p>Story 6.9, Matrix "Pairs" -- System usage declares exactly two pairs,
/// <code>%Admin_Operate:USE</code> then <code>%DB_IRISSYS:READ</code>: a real principal holding
/// only the first (<parameter>OPERATEONLYUSER</parameter>) is refused naming the second, and one
/// holding both (<parameter>OPERATEUSER</parameter>) reads 200 with one row carrying the eighteen
/// parts-merged fields, its <code>Usage.AllGlobalReferences</code> and
/// <code>SharedMemory.SMHAllocated</code> both JSON numbers (AD-29, AD-36).</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.SystemUsage</class> -&gt; the operate-only principal's refusal
/// assertions go red.</p>
Method TestTheSystemUsagePairSetIsEnforcedForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")

    Do ..AssertReadRefused(..#OPERATEONLYUSER, "osmgmt.systemusage", "%DB_IRISSYS:READ")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/osmgmt.systemusage/read?maxRows=5", ..#OPERATEUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the system usage read completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    If tStatus '= 200 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.rows.%Size(), 1, "exactly one row, the instance's own")
    If tAnswer.rows.%Size() '= 1 Quit
    Set tRow = tAnswer.rows.%Get(0)
    Do $$$AssertEquals(tAnswer.fields.%Size(), 18, "all eighteen declared fields")
    Do $$$AssertEquals(tRow.%GetTypeOf("Usage.AllGlobalReferences"), "number", "the counter arrives as a JSON number")
    Do $$$AssertEquals(tRow.%GetTypeOf("SharedMemory.SMHAllocated"), "number", "and so does the shared-memory allocation")
}

/// <p>AC7, Story 6.10 -- the Locks list declares the same two pairs as System usage
/// (<code>%Admin_Operate:USE</code> then <code>%DB_IRISSYS:READ</code>), so the principals that
/// prove that pair set also prove this one, in both directions:
/// <parameter>OPERATEONLYUSER</parameter> holds only the first and is refused naming the second;
/// <parameter>BOTHUSER</parameter> holds the second, plus <code>%Admin_Secure:USE</code> so it
/// clears the API's own any-<code>%Admin_</code> gate, but not the first, and is refused naming
/// it -- the direction System usage's own test does not need, since it already has
/// <parameter>OPERATEONLYUSER</parameter> for the one direction that pair order can produce
/// without a spare administrative resource; <parameter>OPERATEUSER</parameter> holds exactly both
/// and is served. No third principal is created for this test: AD-29's declared pair set is
/// already what a real least-privileged caller needs, confirmed by these three answering as
/// named rather than with a 500.</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.LockList</class> -> the operate-only principal's refusal
/// assertions go red.</p>
Method TestTheLocksListPairSetIsEnforcedForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")

    Do ..AssertReadRefused(..#OPERATEONLYUSER, "osmgmt.locks", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#BOTHUSER, "osmgmt.locks", "%Admin_Operate:USE")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/osmgmt.locks/read?maxRows=1000", ..#OPERATEUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the Locks read completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    If tStatus '= 200 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue(tAnswer.rows.%Size() > 0, "at least one row -- this instance always holds at least a system lock")
    Do $$$AssertEquals(tAnswer.fields.%Size(), 9, "all nine declared fields")
}

/// <p>AC4, Story 6.12 -- the Devices list declares the same two pairs as the Databases General
/// view and Database volumes (<code>%Admin_Manage:USE</code> then <code>%DB_IRISSYS:READ</code>),
/// proved with the same shape of real principals: <parameter>MANAGEONLYUSER</parameter>, holding
/// only the first, is refused naming the second -- the direction <parameter>MANAGEUSER</parameter>
/// alone cannot prove, since it already holds both; <parameter>OPERATEUSER</parameter>, holding
/// the second and not the first, is refused naming the first, which is what makes the declared
/// pair ORDER load-bearing on the read route rather than only in the navigation map; and
/// <parameter>MANAGEUSER</parameter> reads the same rows the test account reads, over HTTP, with
/// neither a 500 nor an empty state. No pair beyond the declared two is refused (AD-29):
/// establishing the set rather than copying it, on this throwaway, found nothing the endpoint's
/// own gate and the port's namespace-switch requirement did not already name.</p>
/// <p>Mutation: declare <code>%Admin_Operate:USE</code> as a third pair on
/// <class>OcuPilot.Screen.Descriptor.DeviceList</class> -- a declaration the grammar accepts,
/// since AD-29 makes the declared set a lower bound -> <parameter>MANAGEUSER</parameter>, which
/// holds neither Operate pair, is refused instead of served and
/// <method>AssertSameRowsAsTestAccount</method> goes red. Dropping <code>%DB_IRISSYS:READ</code>
/// instead proves nothing here: <method>OcuPilot.Screen.Registry.ReadProblem</method> refuses any
/// <code>admin</code>-port read that does not declare it, so the roster never validates and no
/// read is served to any principal.</p>
Method TestTheDevicesListPairSetIsEnforcedForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")

    Do ..AssertReadRefused(..#MANAGEONLYUSER, "osmgmt.devices", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#OPERATEUSER, "osmgmt.devices", "%Admin_Manage:USE")
    Do ..AssertSameRowsAsTestAccount(..#MANAGEUSER, "osmgmt.devices")
}

/// <p>AC6 -- <code>%Admin_Secure:USE</code> alone: the security lists -- users, roles, resources,
/// services, web applications, SSL/TLS, X.509 and LDAP / Kerberos -- and the Permissions, Web
/// applications and Security and secrets areas themselves, are listed denied on
/// <code>%DB_IRISSYS:READ</code>, and every one of those reads is refused naming it.</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.UserList</class> -> the users read answers 500 and its entry
/// and 403 assertions go red; remove it from <class>OcuPilot.Screen.Descriptor.WebAppList</class> ->
/// the web applications leg goes red; remove it from
/// <class>OcuPilot.Screen.Descriptor.SslConfigList</class> -> the SSL/TLS leg goes red.</p>
Method TestAdminSecureAloneIsDeniedOnTheSystemDatabaseRead()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")
    Do $$$AssertEquals(..ScreensFor(..#SECUREUSER, "permissions"), "[{""route"":""permissions/roles/edit"",""labelKey"":""userRoleField"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""permissions/services/edit"",""labelKey"":""serviceFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""permissions/users/edit"",""labelKey"":""processColumnUser"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""permissions/users"",""labelKey"":""userListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""permissions/roles"",""labelKey"":""userColumnRoles"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""permissions/resources"",""labelKey"":""resourceListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""permissions/services"",""labelKey"":""serviceListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""}]", "the role and users forms and the users, roles, resources and services lists are denied on %DB_IRISSYS:READ")
    Do $$$AssertEquals(..ScreensFor(..#SECUREUSER, "web-applications"), "[{""route"":""web-applications/rest-apis/document"",""labelKey"":""openApiViewerLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""web-applications/list/edit"",""labelKey"":""proposalEntityWebApplication"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""web-applications/list"",""labelKey"":""webAppListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""web-applications/rest-apis"",""labelKey"":""restApiListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""web-applications/sessions"",""labelKey"":""webSessionListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Operate:USE""}]", "and so are the web applications list, its create form, the REST API explorer and the OpenAPI document viewer, while Web sessions is denied on its own %Admin_Operate:USE (Story 16.2)")
    Do $$$AssertEquals(..ScreensFor(..#SECUREUSER, "security"), "[{""route"":""security/auditing/system-events"",""labelKey"":""auditSystemEventListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/auditing/user-events"",""labelKey"":""auditUserEventListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/ldap/edit"",""labelKey"":""ldapFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/oauth/clients/edit"",""labelKey"":""oauthClientFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/clients"",""labelKey"":""oauthTabClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/resource-servers/edit"",""labelKey"":""oauthClientTypeResource"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/oauth/resource-servers"",""labelKey"":""oauthTabResourceServers"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/oauth/server-clients/edit"",""labelKey"":""oauthRegisteredClientTitle"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/server-clients"",""labelKey"":""oauthTabServerClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/edit"",""labelKey"":""oauthServerFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/server/edit"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/oauth/server"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/ssl/edit"",""labelKey"":""sslFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/wallet/secrets/edit"",""labelKey"":""walletSecretFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/wallet/secrets"",""labelKey"":""walletSecretListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/x509/edit"",""labelKey"":""x509FormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/x509"",""labelKey"":""x509ListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/ldap"",""labelKey"":""ldapListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/wallet"",""labelKey"":""walletListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/oauth"",""labelKey"":""oauthLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/auditing"",""labelKey"":""auditingConfigurationLink"",""sideBarPosition"":6,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/allowed-directories"",""labelKey"":""allowedDirectoriesLabel"",""sideBarPosition"":7,""allowed"":false,""failedPair"":""%Admin_FileSystemAccess:USE""}]", "and so are the SSL/TLS, X.509 and LDAP / Kerberos lists, while the three wallet screens name the wallet pair they declare first and the OAuth 2.0 tabs the first pair they lack")
    Do $$$AssertEquals(..AreaVerdictFor(..#SECUREUSER, "permissions"), "false:%DB_IRISSYS:READ", "the Permissions area is denied on %DB_IRISSYS:READ")
    Do $$$AssertEquals(..AreaVerdictFor(..#SECUREUSER, "web-applications"), "false:%DB_IRISSYS:READ", "and so is the Web applications area")
    Do $$$AssertEquals(..AreaVerdictFor(..#SECUREUSER, "security"), "false:%DB_IRISSYS:READ", "and so is the Security and secrets area")
    Do ..AssertReadRefused(..#SECUREUSER, "permissions.users", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#SECUREUSER, "permissions.roles", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#SECUREUSER, "permissions.resources", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#SECUREUSER, "permissions.services", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#SECUREUSER, "webapp.list", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#SECUREUSER, "security.ssl", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#SECUREUSER, "security.x509", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#SECUREUSER, "security.ldap", "%DB_IRISSYS:READ")
}

/// <p>Story 8.1 (AD-8): the three web-application create routes refuse a caller without
/// <code>%Admin_Secure:USE</code>, naming it, before anything is read or written -- so the name
/// look-up cannot tell such a caller whether an application exists.</p>
/// <p>Mutation: drop <code>tRefused ||</code> from the three handlers' gate checks -> each route
/// writes its own answer after the refusal envelope, and the body no longer parses.</p>
Method TestTheWebApplicationCreateRoutesRefuseACallerWithoutAdminSecure()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")
    For tI = 1:1:3 {
        Set tMethod = $Piece("GET,GET,POST", ",", tI)
        Set tPath = "/api/ocupilot/web-applications" _ $Piece("/form,/name?name=%2Fcsp%2Fmyapp,", ",", tI)
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(tMethod, tPath, ..#SYSREADUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders, $Select(tMethod = "POST": "{}", 1: ""), $Select(tMethod = "POST": "application/json", 1: ""))
        Do $$$AssertStatusOK(tSC, tMethod _ " " _ tPath _ ": the request completes")
        Do $$$AssertEquals(tStatus, 403, tMethod _ " " _ tPath _ ": is refused")
        Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", tMethod _ " " _ tPath _ ": on the screen-privilege code")
        Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), "%Admin_Secure:USE", tMethod _ " " _ tPath _ ": naming %Admin_Secure:USE")
    }
}

/// <p>Story 9.1 (AD-8, AD-55): the user editor's Save refuses a caller without
/// <code>%Admin_Secure:USE</code>, and one without <code>%DB_IRISSYS:READ</code>, each naming the
/// pair it lacks, and the account it names is left as it was.</p>
/// <p>Mutation: drop the <method>OcuPilot.Area.Permissions.UserSave.Gate</method> call from
/// <method>OcuPilot.Area.Permissions.UserSave.HandleUpdate</method> -&gt; neither refusal names its
/// pair.</p>
Method TestTheUserSaveRefusesACallerWithoutItsPairs()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")
    Set tPath = "/api/ocupilot/users/" _ ##class(OcuPilot.Kernel.EntityId).Encode(..#BOTHUSER)
    Set tFullName = ##class(OcuPilot.Test.ProposalFixture).UserField(..#BOTHUSER, "FullName")
    Do $$$AssertTrue(tFullName '= "", "the target account reads")
    For tCase = $ListBuild(..#SYSREADUSER, "%Admin_Secure:USE"), $ListBuild(..#SECUREUSER, "%DB_IRISSYS:READ") {
        Set tUser = $List(tCase, 1)
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tPath, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, "{""FullName"":""OcuPilot refused Save""}", "application/json")
        Do $$$AssertStatusOK(tSC, tUser _ ": the request completes")
        Do $$$AssertEquals(tStatus, 403, tUser _ ": is refused")
        Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", tUser _ ": on the screen-privilege code")
        Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), $List(tCase, 2), tUser _ ": naming " _ $List(tCase, 2))
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).UserField(..#BOTHUSER, "FullName"), tFullName, "and nothing is written")
}

/// <p>Story 9.2 (AD-8, AD-55): the web application editor's Save refuses a caller without
/// <code>%Admin_Secure:USE</code>, and one without <code>%DB_IRISSYS:READ</code>, each naming the
/// pair it lacks, and the application it names is left as it was.</p>
/// <p>Mutation: drop the <method>OcuPilot.Area.WebApp.WebAppSave.Gate</method> call from
/// <method>OcuPilot.Area.WebApp.WebAppSave.HandleUpdate</method> -&gt; neither refusal names its
/// pair.</p>
Method TestTheWebApplicationSaveRefusesACallerWithoutItsPairs()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")
    Set tTarget = "/csp/user"
    Set tPath = "/api/ocupilot/web-applications/" _ ##class(OcuPilot.Kernel.EntityId).Encode(tTarget)
    Set tDescription = ##class(OcuPilot.Test.WebAppWire).Description(tTarget)
    For tCase = $ListBuild(..#SYSREADUSER, "%Admin_Secure:USE"), $ListBuild(..#SECUREUSER, "%DB_IRISSYS:READ") {
        Set tUser = $List(tCase, 1)
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tPath, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, "{""Description"":""OcuPilot refused Save""}", "application/json")
        Do $$$AssertStatusOK(tSC, tUser _ ": the request completes")
        Do $$$AssertEquals(tStatus, 403, tUser _ ": is refused")
        Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", tUser _ ": on the screen-privilege code")
        Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), $List(tCase, 2), tUser _ ": naming " _ $List(tCase, 2))
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.WebAppWire).Description(tTarget), tDescription, "and nothing is written")
}

/// <p>Story 9.3 (AD-8, AD-55): the role editor's Save refuses a caller without
/// <code>%Admin_Secure:USE</code>, and one without <code>%DB_IRISSYS:READ</code>, each naming the
/// pair it lacks, before the role is read -- so a role the instance does not hold is refused on the
/// pair, never answered 404.</p>
/// <p>Mutation: drop the <method>OcuPilot.Area.Permissions.RoleSave.Gate</method> call from
/// <method>OcuPilot.Area.Permissions.RoleSave.HandleUpdate</method> -&gt; each refusal reads 404
/// instead.</p>
Method TestTheRoleSaveRefusesACallerWithoutItsPairs()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")
    Set tPath = "/api/ocupilot/roles/" _ ##class(OcuPilot.Kernel.EntityId).Encode("OcuPilotNoSuchRoleWire")
    For tCase = $ListBuild(..#SYSREADUSER, "%Admin_Secure:USE"), $ListBuild(..#SECUREUSER, "%DB_IRISSYS:READ") {
        Set tUser = $List(tCase, 1)
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tPath, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, "{""Description"":""OcuPilot refused Save""}", "application/json")
        Do $$$AssertStatusOK(tSC, tUser _ ": the request completes")
        Do $$$AssertEquals(tStatus, 403, tUser _ ": is refused")
        Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", tUser _ ": on the screen-privilege code")
        Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), $List(tCase, 2), tUser _ ": naming " _ $List(tCase, 2))
    }
}

/// <p>AD-8 (Story 9.9): the reduced service and LDAP configuration forms' reads and Saves refuse a
/// principal holding one of their two pairs, naming the pair it lacks. Every name is one the instance
/// does not hold, so nothing could be written even past the gate.</p>
/// <p>Mutation: remove the <code>..Gate(.tRefused)</code> call from
/// <method>OcuPilot.Area.Permissions.ServiceSave.HandleUpdate</method> -&gt; the service Save legs go
/// red.</p>
Method TestTheReducedFormsRefuseACallerWithoutTheirPairs()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")
    Set tService = "/api/ocupilot/services/" _ ##class(OcuPilot.Kernel.EntityId).Encode("OcuPilotNoSuchServiceWire")
    Set tLdap = "/api/ocupilot/ldap/" _ ##class(OcuPilot.Kernel.EntityId).Encode("ocup99nosuchwire.invalid")
    Set tRequests = $ListBuild($ListBuild("PUT", tService, "{""ClientSystems"":[""10.0.0.1""]}"), $ListBuild("GET", "/api/ocupilot/services/form?name=OcuPilotNoSuchServiceWire", ""), $ListBuild("PUT", tLdap, "{""Description"":""OcuPilot refused Save""}"), $ListBuild("GET", "/api/ocupilot/ldap/form?name=ocup99nosuchwire.invalid", ""))
    For tCase = $ListBuild(..#SYSREADUSER, "%Admin_Secure:USE"), $ListBuild(..#SECUREUSER, "%DB_IRISSYS:READ") {
        Set tUser = $List(tCase, 1)
        For tR = 1:1:$ListLength(tRequests) {
            Set tRequest = $List(tRequests, tR)
            Set tLabel = tUser _ " " _ $List(tRequest, 1) _ " " _ $List(tRequest, 2)
            If $List(tRequest, 1) = "PUT" {
                Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", $List(tRequest, 2), tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, $List(tRequest, 3), "application/json")
            } Else {
                Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $List(tRequest, 2), tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
            }
            Do $$$AssertStatusOK(tSC, tLabel _ ": the request completes")
            Do $$$AssertEquals(tStatus, 403, tLabel _ ": is refused")
            Set tRefusal = ""
            Try { Set tRefusal = ##class(%DynamicObject).%FromJSON($Get(tBody)) } Catch {}
            Do $$$AssertEquals($Select($IsObject(tRefusal): tRefusal.code, 1: ""), "AUTH.NOPRIVILEGE", tLabel _ ": on the screen-privilege code")
            Do $$$AssertEquals($Select($IsObject(tRefusal) && $IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), $List(tCase, 2), tLabel _ ": naming " _ $List(tCase, 2))
        }
    }
}

/// <p>AC6 -- <code>%DB_IRISSYS:READ</code> without <code>%Admin_Secure</code>: the same security lists
/// are listed denied on <code>%Admin_Secure:USE</code>, and every one of those reads is refused naming
/// it. The Permissions and Security and secrets areas are denied on it too; Web applications opens,
/// its Web sessions list admitting this principal's <code>%Admin_Operate:USE</code> (AD-8 as amended
/// for DW-1768).</p>
/// <p>Mutation: remove <code>%Admin_Secure:USE</code> from
/// <class>OcuPilot.Screen.Descriptor.ServiceList</class> -&gt; the services entry reads allowed and its
/// read is refused by the port rather than by the screen gate, so the Permissions pin and the
/// services refusal go red.</p>
Method TestSystemReadWithoutAdminSecureIsDenied()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")
    Do $$$AssertEquals(..ScreensFor(..#SYSREADUSER, "permissions"), "[{""route"":""permissions/roles/edit"",""labelKey"":""userRoleField"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""permissions/services/edit"",""labelKey"":""serviceFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""permissions/users/edit"",""labelKey"":""processColumnUser"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""permissions/users"",""labelKey"":""userListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""permissions/roles"",""labelKey"":""userColumnRoles"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""permissions/resources"",""labelKey"":""resourceListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""permissions/services"",""labelKey"":""serviceListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Secure:USE""}]", "the role and users forms and the users, roles, resources and services lists are denied on %Admin_Secure:USE")
    Do $$$AssertEquals(..ScreensFor(..#SYSREADUSER, "web-applications"), "[{""route"":""web-applications/rest-apis/document"",""labelKey"":""openApiViewerLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""web-applications/list/edit"",""labelKey"":""proposalEntityWebApplication"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""web-applications/list"",""labelKey"":""webAppListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""web-applications/rest-apis"",""labelKey"":""restApiListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""web-applications/sessions"",""labelKey"":""webSessionListLabel"",""sideBarPosition"":3,""allowed"":true}]", "and so are the web applications list, its create form, the REST API explorer and the OpenAPI document viewer, while Web sessions, whose pairs this principal holds, is allowed (Story 16.2)")
    Do $$$AssertEquals(..ScreensFor(..#SYSREADUSER, "security"), "[{""route"":""security/auditing/system-events"",""labelKey"":""auditSystemEventListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/auditing/user-events"",""labelKey"":""auditUserEventListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ldap/edit"",""labelKey"":""ldapFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/clients/edit"",""labelKey"":""oauthClientFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/clients"",""labelKey"":""oauthTabClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/resource-servers/edit"",""labelKey"":""oauthClientTypeResource"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/resource-servers"",""labelKey"":""oauthTabResourceServers"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/server-clients/edit"",""labelKey"":""oauthRegisteredClientTitle"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/server-clients"",""labelKey"":""oauthTabServerClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/edit"",""labelKey"":""oauthServerFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/server/edit"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/oauth/server"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/ssl/edit"",""labelKey"":""sslFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/wallet/secrets/edit"",""labelKey"":""walletSecretFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/wallet/secrets"",""labelKey"":""walletSecretListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/x509/edit"",""labelKey"":""x509FormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/x509"",""labelKey"":""x509ListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ldap"",""labelKey"":""ldapListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/wallet"",""labelKey"":""walletListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/oauth"",""labelKey"":""oauthLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/auditing"",""labelKey"":""auditingConfigurationLink"",""sideBarPosition"":6,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/allowed-directories"",""labelKey"":""allowedDirectoriesLabel"",""sideBarPosition"":7,""allowed"":false,""failedPair"":""%Admin_FileSystemAccess:USE""}]", "and so are the SSL/TLS, X.509 and LDAP / Kerberos lists, while the three wallet screens name the wallet pair and the OAuth 2.0 tabs the first pair they lack")
    Do $$$AssertEquals(..AreaVerdictFor(..#SYSREADUSER, "permissions"), "false:%Admin_Secure:USE", "the Permissions area is denied on %Admin_Secure:USE")
    Do $$$AssertEquals(..AreaVerdictFor(..#SYSREADUSER, "web-applications"), "true", "while the Web applications area opens on Web sessions")
    Do $$$AssertEquals(..AreaVerdictFor(..#SYSREADUSER, "security"), "false:%Admin_Secure:USE", "and so is the Security and secrets area")
    Do ..AssertReadRefused(..#SYSREADUSER, "permissions.users", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#SYSREADUSER, "permissions.roles", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#SYSREADUSER, "permissions.resources", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#SYSREADUSER, "permissions.services", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#SYSREADUSER, "webapp.list", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#SYSREADUSER, "security.ssl", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#SYSREADUSER, "security.x509", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#SYSREADUSER, "security.ldap", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#SYSREADUSER, "security.wallet", "%Admin_Wallet:USE")
    Do ..AssertReadRefused(..#SYSREADUSER, "security.secrets", "%Admin_Wallet:USE", "&collection=" _ ..#DEMOCOLLECTION)
}

/// <p>AC6 -- both pairs: the security lists and the Permissions, Web applications and Security and
/// secrets areas are listed allowed, while the wallet screens and the OAuth 2.0 tabs, which declare
/// their pair as their own (Story 16.3, DW-1018), are each denied on it. The reads answer 200, every users row
/// carries a <code>Roles</code> array from its detail call, and every SSL/TLS row carries exactly the
/// four declared fields. The roles, resources and services lists read at <code>maxRows=1000</code>
/// answer exactly the rows the test account's own read answers (AD-29): the principal holding only
/// the declared pairs sees the whole instance, not a subset some backing query narrowed to it.</p>
Method TestBothPairsReadEveryList()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")
    Do $$$AssertEquals(..ScreensFor(..#BOTHUSER, "permissions"), "[{""route"":""permissions/roles/edit"",""labelKey"":""userRoleField"",""sideBarPosition"":0,""allowed"":true},{""route"":""permissions/services/edit"",""labelKey"":""serviceFormLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""permissions/users/edit"",""labelKey"":""processColumnUser"",""sideBarPosition"":0,""allowed"":true},{""route"":""permissions/users"",""labelKey"":""userListLabel"",""sideBarPosition"":1,""allowed"":true},{""route"":""permissions/roles"",""labelKey"":""userColumnRoles"",""sideBarPosition"":2,""allowed"":true},{""route"":""permissions/resources"",""labelKey"":""resourceListLabel"",""sideBarPosition"":3,""allowed"":true},{""route"":""permissions/services"",""labelKey"":""serviceListLabel"",""sideBarPosition"":4,""allowed"":true}]", "the role and users forms and the users, roles, resources and services lists are listed allowed")
    Do $$$AssertEquals(..ScreensFor(..#BOTHUSER, "web-applications"), "[{""route"":""web-applications/rest-apis/document"",""labelKey"":""openApiViewerLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""web-applications/list/edit"",""labelKey"":""proposalEntityWebApplication"",""sideBarPosition"":0,""allowed"":true},{""route"":""web-applications/list"",""labelKey"":""webAppListLabel"",""sideBarPosition"":1,""allowed"":true},{""route"":""web-applications/rest-apis"",""labelKey"":""restApiListLabel"",""sideBarPosition"":2,""allowed"":true},{""route"":""web-applications/sessions"",""labelKey"":""webSessionListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Operate:USE""}]", "and so are the web applications list, its create form, the REST API explorer and the OpenAPI document viewer, while Web sessions is denied on its own %Admin_Operate:USE (Story 16.2)")
    Do $$$AssertEquals(..ScreensFor(..#BOTHUSER, "security"), "[{""route"":""security/auditing/system-events"",""labelKey"":""auditSystemEventListLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""security/auditing/user-events"",""labelKey"":""auditUserEventListLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""security/ldap/edit"",""labelKey"":""ldapFormLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""security/oauth/clients/edit"",""labelKey"":""oauthClientFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/clients"",""labelKey"":""oauthTabClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/resource-servers/edit"",""labelKey"":""oauthClientTypeResource"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/resource-servers"",""labelKey"":""oauthTabResourceServers"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/server-clients/edit"",""labelKey"":""oauthRegisteredClientTitle"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/server-clients"",""labelKey"":""oauthTabServerClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/edit"",""labelKey"":""oauthServerFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/server/edit"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/oauth/server"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/ssl/edit"",""labelKey"":""sslFormLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""security/wallet/secrets/edit"",""labelKey"":""walletSecretFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/wallet/secrets"",""labelKey"":""walletSecretListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/x509/edit"",""labelKey"":""x509FormLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":true},{""route"":""security/x509"",""labelKey"":""x509ListLabel"",""sideBarPosition"":2,""allowed"":true},{""route"":""security/ldap"",""labelKey"":""ldapListLabel"",""sideBarPosition"":3,""allowed"":true},{""route"":""security/wallet"",""labelKey"":""walletListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/oauth"",""labelKey"":""oauthLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/auditing"",""labelKey"":""auditingConfigurationLink"",""sideBarPosition"":6,""allowed"":true},{""route"":""security/allowed-directories"",""labelKey"":""allowedDirectoriesLabel"",""sideBarPosition"":7,""allowed"":false,""failedPair"":""%Admin_FileSystemAccess:USE""}]", "and so are the SSL/TLS, X.509, LDAP / Kerberos and OAuth 2.0 resource servers lists, while the three wallet screens are denied on the wallet pair and the other OAuth 2.0 tabs on their OAuth resource")
    Do $$$AssertEquals(..AreaVerdictFor(..#BOTHUSER, "permissions"), "true", "the Permissions area is allowed")
    Do $$$AssertEquals(..AreaVerdictFor(..#BOTHUSER, "web-applications"), "true", "and so is the Web applications area")
    Do $$$AssertEquals(..AreaVerdictFor(..#BOTHUSER, "security"), "true", "and so is the Security and secrets area, on the screens these pairs open")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/webapp.list/read?maxRows=5", ..#BOTHUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the web applications read completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/security.ssl/read?maxRows=1000", ..#BOTHUSER, ..PreparedPassword, .tStatus3, .tBody3, .tHeaders3)
    Do $$$AssertStatusOK(tSC, "the SSL/TLS read completes")
    Do $$$AssertEquals(tStatus3, 200, "and answers")
    If tStatus3 = 200 {
        Set tSsl = ##class(%DynamicObject).%FromJSON(tBody3)
        Set tSslFields = "[""Name"",""Description"",""Enabled"",""Type""]"
        Do $$$AssertEquals(tSsl.fields.%ToJSON(), tSslFields, "with the four declared fields")
        Do $$$AssertTrue(tSsl.rows.%Size() > 0, "and the instance's configurations listed: " _ tSsl.rows.%Size())
        Set tSslBad = ""
        Set tSslIterator = tSsl.rows.%GetIterator()
        While tSslIterator.%GetNext(.tSslIndex, .tSslRow) {
            Set tSslKeys = []
            Set tSslKeyIterator = tSslRow.%GetIterator()
            While tSslKeyIterator.%GetNext(.tSslKey, .tSslValue) {
                Do tSslKeys.%Push(tSslKey)
            }
            If tSslKeys.%ToJSON() '= tSslFields Set tSslBad = "row " _ tSslIndex _ " carries " _ tSslKeys.%ToJSON()
            If tSslBad '= "" Quit
        }
        Do $$$AssertEquals(tSslBad, "", "every SSL/TLS row carries exactly the four declared fields")
    }

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/permissions.users/read?maxRows=1000", ..#BOTHUSER, ..PreparedPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC, "the users read completes")
    Do $$$AssertEquals(tStatus2, 200, "and answers")
    If tStatus2 '= 200 Quit
    Set tRows = ##class(%DynamicObject).%FromJSON(tBody2).rows
    Do $$$AssertTrue(tRows.%Size() > 0, "with users listed: " _ tRows.%Size())
    Set tBad = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%GetTypeOf("Roles") '= "array" Set tBad = tRow.Name _ " has a Roles that is " _ tRow.%GetTypeOf("Roles")
        If tBad '= "" Quit
    }
    Do $$$AssertEquals(tBad, "", "every row carries a Roles array")

    For tTool = "permissions.roles", "permissions.resources", "permissions.services" {
        Do ..AssertSameRowsAsTestAccount(..#BOTHUSER, tTool)
    }
}

/// <p>Assert that <var>pUser</var>'s read of <var>pTool</var> at <code>maxRows=1000</code> answers
/// 200 with a non-empty, untruncated row set equal, row for row, to the test account's own read of
/// the same screen. <var>pQuery</var> is appended to both reads' query strings as given, and when
/// <var>pEveryNameContains</var> is not empty every row's <code>Name</code> must contain it.</p>
Method AssertSameRowsAsTestAccount(pUser As %String, pTool As %String, pQuery As %String = "", pEveryNameContains As %String = "")
{
    Set tPath = "/api/ocupilot/screens/" _ pTool _ "/read?maxRows=1000" _ pQuery
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tWantStatus, .tWantBody, .tWantHeaders)
    Do $$$AssertStatusOK(tSC, pTool _ ": the test account's read completes")
    Do $$$AssertEquals(tWantStatus, 200, pTool _ ": and answers")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, pUser _ " " _ pTool _ ": the read completes")
    Do $$$AssertEquals(tStatus, 200, pUser _ " " _ pTool _ ": and answers")
    If (tWantStatus '= 200) || (tStatus '= 200) Quit
    Set tWant = ##class(%DynamicObject).%FromJSON(tWantBody)
    Set tGot = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue(tWant.rows.%Size() > 0, pTool _ ": the test account reads rows: " _ tWant.rows.%Size())
    Do $$$AssertEquals(tGot.truncated, 0, pUser _ " " _ pTool _ ": nothing is cut at 1,000")
    Do $$$AssertEquals(tGot.rows.%Size(), tWant.rows.%Size(), pUser _ " " _ pTool _ ": as many rows as the test account reads")
    Do $$$AssertTrue(tGot.rows.%ToJSON() = tWant.rows.%ToJSON(), pUser _ " " _ pTool _ ": and the same rows")
    If pEveryNameContains = "" Quit
    Set tOther = ""
    Set tIter = tGot.rows.%GetIterator()
    While tIter.%GetNext(.tKey, .tRow) {
        If '(tRow.Name [ pEveryNameContains) Set tOther = "row " _ tKey _ ": " _ tRow.Name Quit
    }
    Do $$$AssertEquals(tOther, "", pUser _ " " _ pTool _ ": every row is one the query names (" _ pEveryNameContains _ ")")
}

/// <p>Story 6.3, Matrix "Secure pairs" -- a principal holding <code>%Admin_Secure:USE</code> and
/// <code>%DB_IRISSYS:READ</code> reads the X.509 and LDAP / Kerberos lists, each answering the test
/// account's rows, and is refused the Wallet and Secrets reads naming <code>%Admin_Wallet:USE</code>.
/// Its navigation entries and the area verdict are <method>TestBothPairsReadEveryList</method>'s.</p>
/// <p>Mutation: drop <code>%Admin_Wallet:USE</code> from
/// <class>OcuPilot.Screen.Descriptor.WalletCollectionList</class> -&gt; the Wallet entry reads allowed
/// and its read is refused by the vendor rather than by the screen gate, so this method's wallet
/// refusal and <method>TestBothPairsReadEveryList</method>'s wallet pins go red.</p>
Method TestTheSecurePairsReadX509AndLdapAndNotTheWallet()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")
    For tTool = "security.x509", "security.ldap" {
        Do ..AssertSameRowsAsTestAccount(..#BOTHUSER, tTool)
    }
    Do ..AssertReadRefused(..#BOTHUSER, "security.wallet", "%Admin_Wallet:USE")
    Do ..AssertReadRefused(..#BOTHUSER, "security.secrets", "%Admin_Wallet:USE", "&collection=" _ ..#DEMOCOLLECTION)
}

/// <p>Story 6.3, Matrix "Wallet pairs" -- a principal holding <code>%Admin_Wallet:USE</code> and
/// <code>%DB_IRISSYS:READ</code> and not <code>%Admin_Secure:USE</code> sees the three wallet screens
/// allowed and reads them, the Secrets list for the demo collection, each answering the test
/// account's rows; the X.509 and LDAP / Kerberos entries and their reads are refused naming
/// <code>%Admin_Secure:USE</code>, and the Security and secrets area opens on the wallet screens (AD-8
/// as amended for DW-1768).</p>
/// <p>That the wallet reads answer this principal at all is what settles the pair set: the vendor's
/// wallet queries check no resource of their own, so no <parameter>OcuPilot.Port.AdminPort.QUERYPAIRS</parameter>
/// entry is needed for them.</p>
Method TestTheWalletPairsReadTheWalletScreens()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")
    Do $$$AssertEquals(..ScreensFor(..#WALLETUSER, "security"), "[{""route"":""security/auditing/system-events"",""labelKey"":""auditSystemEventListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/auditing/user-events"",""labelKey"":""auditUserEventListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ldap/edit"",""labelKey"":""ldapFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/clients/edit"",""labelKey"":""oauthClientFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/clients"",""labelKey"":""oauthTabClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/resource-servers/edit"",""labelKey"":""oauthClientTypeResource"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/resource-servers"",""labelKey"":""oauthTabResourceServers"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/server-clients/edit"",""labelKey"":""oauthRegisteredClientTitle"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/server-clients"",""labelKey"":""oauthTabServerClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/edit"",""labelKey"":""oauthServerFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/server/edit"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/oauth/server"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/ssl/edit"",""labelKey"":""sslFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/wallet/secrets/edit"",""labelKey"":""walletSecretFormLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""security/wallet/secrets"",""labelKey"":""walletSecretListLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""security/x509/edit"",""labelKey"":""x509FormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/x509"",""labelKey"":""x509ListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ldap"",""labelKey"":""ldapListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/wallet"",""labelKey"":""walletListLabel"",""sideBarPosition"":4,""allowed"":true},{""route"":""security/oauth"",""labelKey"":""oauthLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/auditing"",""labelKey"":""auditingConfigurationLink"",""sideBarPosition"":6,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/allowed-directories"",""labelKey"":""allowedDirectoriesLabel"",""sideBarPosition"":7,""allowed"":false,""failedPair"":""%Admin_FileSystemAccess:USE""}]", "the wallet pairs: the three wallet screens are allowed and every other screen denied on the first pair it lacks")
    Do $$$AssertEquals(..AreaVerdictFor(..#WALLETUSER, "security"), "true", "while the area opens, since the Wallet list it lists admits the principal")
    Do ..AssertSameRowsAsTestAccount(..#WALLETUSER, "security.wallet")
    Do ..AssertSameRowsAsTestAccount(..#WALLETUSER, "security.secrets", "&collection=" _ ..#DEMOCOLLECTION)
    Do ..AssertReadRefused(..#WALLETUSER, "security.x509", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#WALLETUSER, "security.ldap", "%Admin_Secure:USE")
}

/// <p>Story 6.3, Matrix "No system DB read" -- a principal holding <code>%Admin_Wallet:USE</code>
/// without <code>%DB_IRISSYS:READ</code> sees the Wallet and Secrets entries denied naming the
/// database read, and both reads are refused naming it rather than failing inside the port.
/// <parameter>SECUREUSER</parameter>'s X.509 and LDAP / Kerberos half is
/// <method>TestAdminSecureAloneIsDeniedOnTheSystemDatabaseRead</method>'s.</p>
/// <p>Mutation: drop <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.WalletSecretList</class> -&gt; the Secrets entry reads allowed and
/// its read is no longer refused by name, so its pin and refusal go red.</p>
Method TestWalletWithoutTheSystemReadIsDenied()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")
    Do $$$AssertEquals(..ScreensFor(..#WALLETNODBUSER, "security"), "[{""route"":""security/auditing/system-events"",""labelKey"":""auditSystemEventListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/auditing/user-events"",""labelKey"":""auditUserEventListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ldap/edit"",""labelKey"":""ldapFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/clients/edit"",""labelKey"":""oauthClientFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/clients"",""labelKey"":""oauthTabClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/resource-servers/edit"",""labelKey"":""oauthClientTypeResource"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/resource-servers"",""labelKey"":""oauthTabResourceServers"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/server-clients/edit"",""labelKey"":""oauthRegisteredClientTitle"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/server-clients"",""labelKey"":""oauthTabServerClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/edit"",""labelKey"":""oauthServerFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/server/edit"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/oauth/server"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/ssl/edit"",""labelKey"":""sslFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/wallet/secrets/edit"",""labelKey"":""walletSecretFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/wallet/secrets"",""labelKey"":""walletSecretListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/x509/edit"",""labelKey"":""x509FormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/x509"",""labelKey"":""x509ListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ldap"",""labelKey"":""ldapListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/wallet"",""labelKey"":""walletListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/oauth"",""labelKey"":""oauthLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/auditing"",""labelKey"":""auditingConfigurationLink"",""sideBarPosition"":6,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/allowed-directories"",""labelKey"":""allowedDirectoriesLabel"",""sideBarPosition"":7,""allowed"":false,""failedPair"":""%Admin_FileSystemAccess:USE""}]", "the wallet resource alone: the three wallet screens are denied on %DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#WALLETNODBUSER, "security.wallet", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#WALLETNODBUSER, "security.secrets", "%DB_IRISSYS:READ", "&collection=" _ ..#DEMOCOLLECTION)
}

/// <p>Story 2.10 AC5 (DW-249) -- the audit database viewer's pair set, proved with real principals.
/// A caller holding <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code> but not
/// <code>%Admin_Operate:USE</code> is denied by name -- for the screen and on the read route -- and
/// granting the third pair serves the list. The Logs area opens for it on the analytics log, whose
/// pair is public (AD-8 as amended for DW-1768).</p>
/// <p><b>Why the second pair is the interesting one.</b> The endpoint's own
/// <code>Record.ResourcesOR()</code> answers <code>%Admin_Secure</code> alone, so a pair set read
/// off it would admit this principal. What refuses it is the endpoint the <b>port</b> polls the
/// queued task through: the async-result endpoint gates on
/// <code>%Admin_Operate</code>, and the refusal would arrive <i>after</i> the LIST had been queued
/// (AD-26, DW-249). Declaring the pair is what turns that into a named 403 before anything is
/// queued -- which is also why <b>no async-task row is left behind</b>, asserted here by counting
/// the rows around the refused read.</p>
/// <p>Mutation: remove <code>%Admin_Operate:USE</code> from
/// <class>OcuPilot.Screen.Descriptor.AuditList</class> <b>and</b> the <code>logs</code> area in
/// <class>OcuPilot.Screen.Area</class> -> the denial leg goes red, because the search is no longer
/// refused by name. Remove <code>%Admin_Secure:USE</code> from the area alone ->
/// <class>OcuPilot.Test.Descriptor</class>'s coverage tests go red naming the uncovered pair.</p>
/// <p>Mutation for the marker half: stop <method>OcuPilot.Screen.Read.SeedCriteria</method> writing
/// the value into the query -&gt; the filtered read answers the unfiltered page and the
/// wrong-Source scan goes red. Its companion, the foreign-Source count on the unfiltered page, is
/// what makes that scan mean narrowing rather than an empty search: a count comparison could not,
/// since both reads are capped at 25 and both fill it.</p>
Method TestTheAuditListsPairSetIsEnforcedForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")

    Set tBefore = ..AsyncTaskCount()
    Do $$$AssertTrue(tBefore >= 0, "the async-task list reads before the refused read (" _ tBefore _ ")")

    Do $$$AssertEquals(..ScreensFor(..#AUDITDENYUSER, "logs"), "[{""route"":""logs/alerts"",""labelKey"":""alertLogListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/messages"",""labelKey"":""messagesLogListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/errors"",""labelKey"":""errorLogListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/audit"",""labelKey"":""auditListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/systemmonitor"",""labelKey"":""systemMonitorLogListLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/taskerrors"",""labelKey"":""taskErrorLogListLabel"",""sideBarPosition"":6,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/xdbc"",""labelKey"":""xdbcErrorLogListLabel"",""sideBarPosition"":7,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/sqldiagnostics"",""labelKey"":""sqlDiagnosticsLogListLabel"",""sideBarPosition"":8,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/eventlog"",""labelKey"":""eventLogListLabel"",""sideBarPosition"":9,""allowed"":false,""failedPair"":""%Ens_EventLog:USE""},{""route"":""logs/analytics"",""labelKey"":""analyticsLogListLabel"",""sideBarPosition"":10,""allowed"":true},{""route"":""logs/hub"",""labelKey"":""logHubLabel"",""sideBarPosition"":11,""allowed"":false,""failedPair"":""%Admin_Operate:USE""}]", "%Admin_Secure and the database read: every Logs screen needing %Admin_Operate:USE is denied on it, the log hub among them, the event log on its own pair, and the analytics log, whose pair is public, is open")
    Do $$$AssertEquals(..AreaVerdictFor(..#AUDITDENYUSER, "logs"), "true", "while the Logs area opens on the analytics log")
    Do ..AssertReadRefused(..#AUDITDENYUSER, "logs.audit", "%Admin_Operate:USE")
    Do $$$AssertEquals(..AsyncTaskCount(), tBefore, "and the refused read queued nothing, so no async-task row is left behind (DW-249)")

    ; The pair ORDER, read by a principal holding neither of the screen's administrative resources:
    ; %Admin_Secure:USE is declared first, so it is the pair the gate names. A descriptor that
    ; declared the first two the other way round would name %Admin_Operate:USE here.
    Do $$$AssertEquals(..ScreensFor(..#TASKUSER, "logs"), "[{""route"":""logs/alerts"",""labelKey"":""alertLogListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/messages"",""labelKey"":""messagesLogListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/errors"",""labelKey"":""errorLogListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/audit"",""labelKey"":""auditListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""logs/systemmonitor"",""labelKey"":""systemMonitorLogListLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/taskerrors"",""labelKey"":""taskErrorLogListLabel"",""sideBarPosition"":6,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/xdbc"",""labelKey"":""xdbcErrorLogListLabel"",""sideBarPosition"":7,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/sqldiagnostics"",""labelKey"":""sqlDiagnosticsLogListLabel"",""sideBarPosition"":8,""allowed"":false,""failedPair"":""%Admin_Operate:USE""},{""route"":""logs/eventlog"",""labelKey"":""eventLogListLabel"",""sideBarPosition"":9,""allowed"":false,""failedPair"":""%Ens_EventLog:USE""},{""route"":""logs/analytics"",""labelKey"":""analyticsLogListLabel"",""sideBarPosition"":10,""allowed"":true},{""route"":""logs/hub"",""labelKey"":""logHubLabel"",""sideBarPosition"":11,""allowed"":false,""failedPair"":""%Admin_Operate:USE""}]", "a principal holding neither administrative resource is denied on the first pair each screen declares -- %Admin_Operate for the log files, the application error log, four secondary logs and the log hub, %Admin_Secure for the audit viewer, %Ens_EventLog for the event log")

    Do $$$AssertEquals(..ScreensFor(..#AUDITUSER, "logs"), "[{""route"":""logs/alerts"",""labelKey"":""alertLogListLabel"",""sideBarPosition"":1,""allowed"":true},{""route"":""logs/messages"",""labelKey"":""messagesLogListLabel"",""sideBarPosition"":2,""allowed"":true},{""route"":""logs/errors"",""labelKey"":""errorLogListLabel"",""sideBarPosition"":3,""allowed"":true},{""route"":""logs/audit"",""labelKey"":""auditListLabel"",""sideBarPosition"":4,""allowed"":true},{""route"":""logs/systemmonitor"",""labelKey"":""systemMonitorLogListLabel"",""sideBarPosition"":5,""allowed"":true},{""route"":""logs/taskerrors"",""labelKey"":""taskErrorLogListLabel"",""sideBarPosition"":6,""allowed"":true},{""route"":""logs/xdbc"",""labelKey"":""xdbcErrorLogListLabel"",""sideBarPosition"":7,""allowed"":true},{""route"":""logs/sqldiagnostics"",""labelKey"":""sqlDiagnosticsLogListLabel"",""sideBarPosition"":8,""allowed"":true},{""route"":""logs/eventlog"",""labelKey"":""eventLogListLabel"",""sideBarPosition"":9,""allowed"":false,""failedPair"":""%Ens_EventLog:USE""},{""route"":""logs/analytics"",""labelKey"":""analyticsLogListLabel"",""sideBarPosition"":10,""allowed"":true},{""route"":""logs/hub"",""labelKey"":""logHubLabel"",""sideBarPosition"":11,""allowed"":true}]", "all three pairs: the first four Logs screens, every secondary log but the event log, and the log hub are listed allowed")
    Do $$$AssertEquals(..AreaVerdictFor(..#AUDITUSER, "logs"), "true", "and so is the Logs area")

    ; The served read, through the port's self-queued async path (AD-26) and with a declared
    ; server-search criterion on the query string: a criterion the descriptor names reaches the
    ; vendor query, and the rows come back narrowed to it.
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/logs.audit/read?maxRows=25", ..#AUDITUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the audit read completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    If tStatus '= 200 Quit
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.fields.%Size(), 24, "with the twenty-four declared fields")
    Do $$$AssertEquals(tAnswer.fields.%Get(0), "SystemID", "in the vendor's own ROWSPEC order")
    Do $$$AssertTrue(tAnswer.rows.%Size() > 0, "and the instance's audit rows listed: " _ tAnswer.rows.%Size())
    Do $$$AssertTrue(tAnswer.rows.%Size() <= 25, "bounded by the cap: " _ tAnswer.rows.%Size())
    Do $$$AssertEquals(tAnswer.%GetTypeOf("banner"), "string", "the answer carries a banner key rather than omitting it")
    Do $$$AssertEquals(tAnswer.banner, "", "and the screen declares no banner, so none is raised")
    Set tUnfiltered = tAnswer.rows.%Size()

    ; A declared criterion on the route narrows the search on the SERVER. The marker's own Source is
    ; used, because the installer registers it and the instance holds rows under it; a Source that
    ; matches nothing would leave this assertion true for the wrong reason, so the count is bounded
    ; from both sides.
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/logs.audit/read?maxRows=25&eventSources=" _ $Parameter("OcuPilot.Kernel.State.Base", "AUDITSOURCE"), ..#AUDITUSER, ..PreparedPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC, "the marker-filtered read completes")
    Do $$$AssertEquals(tStatus2, 200, "and answers")
    If tStatus2 '= 200 Quit
    Set tMarked = ##class(%DynamicObject).%FromJSON(tBody2)
    ; The lower bound first: with no rows the wrong-source scan below has nothing to disagree with
    ; and would pass for a criterion that matched nothing.
    Do $$$AssertTrue(tMarked.rows.%Size() > 0, "the marker's own Source returned rows: " _ tMarked.rows.%Size())
    Set tWrongSource = ""
    Set tIterator = tMarked.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("EventSource") '= $Parameter("OcuPilot.Kernel.State.Base", "AUDITSOURCE") Set tWrongSource = "row " _ tIndex _ " carries EventSource " _ tRow.%Get("EventSource")
        If tWrongSource '= "" Quit
    }
    Do $$$AssertEquals(tWrongSource, "", "every row the declared eventSources criterion returned carries that Source, so the search ran on the server")
    ; The other side of the narrowing, and the one a shared cap can express: the unfiltered page
    ; holds rows from another Source, which the filtered one therefore does not. A count comparison
    ; could not say this -- both reads are capped at 25 and both fill it.
    Set tForeign = 0
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("EventSource") '= $Parameter("OcuPilot.Kernel.State.Base", "AUDITSOURCE") Set tForeign = tForeign + 1
    }
    Do $$$AssertTrue(tForeign > 0, "the unfiltered page holds rows from another Source (" _ tForeign _ " of " _ tUnfiltered _ "), so the filtered read above is narrower than it and not the same page under another name")

    ; An off-list choice value is refused before the port is called, so an unrecognized mechanism
    ; can never widen the result the way the vendor's own -1 conversion would (AC7).
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/logs.audit/read?maxRows=25&authentication=Bogus", ..#AUDITUSER, ..PreparedPassword, .tStatus3, .tBody3, .tHeaders3)
    Do $$$AssertStatusOK(tSC, "the off-list read completes")
    Do $$$AssertEquals(tStatus3, 400, "and is refused")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody3)
    Do $$$AssertEquals(tRefusal.code, "READ.CRITERION", "on the criterion machine code")
    Do $$$AssertTrue(tRefusal.reason [ "authentication", "naming the criterion: " _ tRefusal.reason)
    Do $$$AssertEquals(..AsyncTaskCount(), tBefore, "and nothing was queued for it either")

    ; A declared one is served, which is what makes the refusal above a refusal rather than a
    ; screen that answers 400 to everything.
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/logs.audit/read?maxRows=25&authentication=Password", ..#AUDITUSER, ..PreparedPassword, .tStatus4, .tBody4, .tHeaders4)
    Do $$$AssertStatusOK(tSC, "the declared-value read completes")
    Do $$$AssertEquals(tStatus4, 200, "and answers")
}

/// <p>Story 16.8 (AD-8, DW-1755) -- the Logs area keeps Release 1's pair set, and the event log's
/// <code>%Ens_EventLog:USE</code> gates that screen alone. <parameter>AUDITUSER</parameter> holds
/// exactly the Logs area's three pairs and not that one: the Logs area opens, messages.log and
/// alerts.log pass their gates on their routes and read tools, and only the event log's route and read
/// tool are refused, naming its pair.</p>
/// <p>The alerts.log route has two outcomes past the gate (AD-21): 200 with the file's tail, or, on an
/// instance that has raised no alert and so has no alerts.log, 404 <code>LOG.ABSENT</code>. Any other
/// answer, a 403 included, is red. The other three paths answer 200 either way.</p>
/// <p>Mutation (Rule 19): remove <code>%Ens_EventLog:USE</code> from
/// <class>OcuPilot.Screen.Descriptor.LogEventViewer</class> and from
/// <parameter>OcuPilot.Port.LogSourcePort.EVENTLOGPAIRS</parameter> -&gt; the event log's refusals stop
/// naming it and go red. Add <code>%Ens_EventLog:USE</code> to
/// <parameter>OcuPilot.Port.LogSourcePort.ALERTSPAIRS</parameter> -&gt; the alerts.log route answers 403
/// and this goes red.</p>
Method TestTheLogsAreaStaysOpenWithoutTheEventLogsPair()
{
    Do $$$AssertNotEquals($SYSTEM.Security.CheckUserPermission(..#AUDITUSER, "%Ens_EventLog", "USE"), 1, ..#AUDITUSER _ " does not hold %Ens_EventLog:USE")
    Do $$$AssertEquals(..AreaVerdictFor(..#AUDITUSER, "logs"), "true", "the Logs area opens")
    Set tAlertsTail = "/api/ocupilot/logs/alerts?maxBytes=4096"
    For tPath = "/api/ocupilot/logs/messages", tAlertsTail, "/api/ocupilot/screens/logs.messages/read?maxRows=5", "/api/ocupilot/screens/logs.alerts/read?maxRows=5" {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, ..#AUDITUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tPath _ ": the request completes")
        If (tPath = tAlertsTail) && (tStatus = 404) {
            Set tAbsent = ""
            Try { Set tAbsent = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
            Do $$$AssertEquals($Select($IsObject(tAbsent): tAbsent.code, 1: ""), "LOG.ABSENT", tPath _ ": a 404 names the file's absence, which is answered past the gate: " _ $Extract(tBody, 1, 200))
        } Else {
            Do $$$AssertEquals(tStatus, 200, tPath _ ": served: " _ $Extract(tBody, 1, 200))
        }
    }
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/logs/eventlog", ..#AUDITUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the event log route request completes")
    Do $$$AssertEquals(tStatus, 403, "the event log route is refused")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", "on the screen-privilege code")
    Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), "%Ens_EventLog:USE", "naming %Ens_EventLog:USE")
    Do ..AssertReadRefused(..#AUDITUSER, "logs.eventlog", "%Ens_EventLog:USE")
}

/// <p>Story 6.14 AC9 (DW-1025) -- an unprivileged caller's async read leaves no
/// <code>&lt;PROTECT&gt;</code> in the file the console-log screen displays.</p>
/// <p><b>The principal is the measurement.</b> <parameter>AUDITUSER</parameter> is served the audit
/// read, which the admin port runs through its own queued path (AD-26), and it does <b>not</b> hold
/// write on the database the async task rows live in -- read back here rather than assumed, because
/// the whole finding is that <method>OcuPilot.Port.AdminPort.ForgetTask</method>'s delete runs as the
/// caller. The suite's own account holds <code>%All</code>, so this refusal is observable on a real
/// principal and nowhere else.</p>
/// <p>The sweep reads only the bytes <file>messages.log</file> grew by across the call, so an
/// earlier run's line cannot make it pass or fail.</p>
/// <p>Mutation: attempt <method>OcuPilot.Port.AdminPort.ForgetTask</method>'s delete without asking
/// <method>OcuPilot.Port.AdminPort.MayDeleteTask</method> and log every failure, the
/// <code>&lt;PROTECT&gt;</code> included, and recompile the package -&gt; the read still answers 200
/// and the appended bytes carry the vendor's protect text, so both sweep assertions go red.</p>
Method TestAnUnprivilegedAsyncReadLeavesNoProtectInTheConsoleLog()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")
    Set tResource = ..RowsResource()
    Do $$$AssertTrue(tResource '= "", "the database the async task rows live in names its resource: " _ tResource)
    Do $$$AssertNotEquals($SYSTEM.Security.CheckUserPermission(..#AUDITUSER, tResource, "WRITE"), 1, ..#AUDITUSER _ " does not hold " _ tResource _ ":WRITE, so its async read is the unprivileged case")

    Set tPath = ##class(%File).NormalizeFilename(##class(OcuPilot.Port.LogSourcePort).FileFor("messages"), ##class(OcuPilot.Port.LogSourcePort).ManagerDirectory())
    Set tBeforeSize = ##class(%File).GetFileSize(tPath)
    Do $$$AssertTrue(tBeforeSize > 0, "the console log is readable before the call: " _ tPath _ " (" _ tBeforeSize _ " bytes)")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/logs.audit/read?maxRows=1", ..#AUDITUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the audit read completes")
    Do $$$AssertEquals(tStatus, 200, "and is served, so the port reached its queued path rather than being refused before it")

    Set tAppended = ..ConsoleLogSince(tPath, tBeforeSize)
    ; Read the sweep itself first: both assertions below are absences, so a sweep that could not
    ; read the appended region would satisfy them without having looked at anything.
    Do $$$AssertEquals(tAppended [ "the console log could not be", 0, "the sweep read the appended region rather than failing to: " _ tAppended)
    Do $$$AssertEquals(tAppended [ "an async task row could not be removed", 0, "no fault is logged for the row the delete left alone: " _ tAppended)
    Do $$$AssertEquals(tAppended [ "<PROTECT>", 0, "and the vendor's protect text reaches no log OcuPilot writes: " _ tAppended)
}

/// <p>The bytes <var>pPath</var> holds beyond <var>pFrom</var>, or <code>""</code> when it has not
/// grown. Bounded to one long string: the appended region of one call, never the whole file.</p>
/// <p><b>A sweep that could not read answers a sentence, not <code>""</code></b>: the caller's two
/// assertions are absences, so a failed link or seek would otherwise read as "nothing was logged"
/// and pass. <method>MoveTo</method> is <class>%Stream.FileBinary</class>'s, which
/// <class>%Stream.FileCharacter</class> inherits unchanged, so the position is the byte
/// <method>%File.GetFileSize</method> reported and not a character count.</p>
Method ConsoleLogSince(pPath As %String, pFrom As %Integer) As %String
{
    Set tText = ""
    Try {
        Set tStream = ##class(%Stream.FileCharacter).%New()
        If 'tStream.LinkToFile(pPath) {
            Set tText = "the console log could not be opened for the sweep: " _ pPath
            Quit
        }
        If 'tStream.MoveTo(pFrom + 1) {
            Set tText = "the console log could not be positioned at byte " _ (pFrom + 1) _ ": " _ pPath
            Quit
        }
        Set tText = tStream.Read(1000000)
    } Catch ex {
        Set tText = "the console log could not be re-read: " _ ex.DisplayString()
    }
    Quit tText
}

/// <p>The resource of IRISLOCALDATA, the database the vendor's async task rows live in, read from
/// the instance, or <code>""</code>.</p>
Method RowsResource() As %String
{
    Set tResource = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDatabase = ##class(Config.Databases).Open("IRISLOCALDATA")
        If $IsObject(tDatabase) Set tResource = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tResource = ""
    }
    Quit tResource
}

/// <p>How many queued async-task rows the instance holds, or <code>-1</code> when the list cannot
/// be read. Read through the port as this suite's own <code>%All</code> account, never as the
/// principal under test, and through the port rather than by naming the vendor class (AD-27).</p>
Method AsyncTaskCount() As %Integer
{
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("AsyncResult", "LIST", , , .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject(tRows) Quit -1
    If 'tRows.%IsA("%DynamicArray") Quit -1
    Quit tRows.%Size()
}

/// <p>AC3, Story 16.7 -- the Dashboard and License usage's four tabs declare System usage's two pairs
/// (<code>%Admin_Operate:USE</code> then <code>%DB_IRISSYS:READ</code>), proved with the principals
/// that prove the Locks list's set, in both directions and on all five reads:
/// <parameter>BOTHUSER</parameter> holds the second, and not the first, and is refused naming the
/// first; <parameter>OPERATEONLYUSER</parameter> holds only the first and is refused naming the
/// second; <parameter>OPERATEUSER</parameter> holds exactly both and reads two of them with 200 -- the
/// Dashboard's one row with CPU a number, the monitor port's gate passing on the same two pairs, and
/// the license Summary's rows.</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.Dashboard</class> -&gt; the operate-only principal passes the
/// screen's gate and is not refused naming the pair, and its Dashboard refusal leg goes red.</p>
Method TestTheDashboardAndLicenseUsagePairSetsAreEnforcedForARealPrincipal()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the fourteen principals' pairs")

    For tTool = "osmgmt.dashboard", "osmgmt.licensesummary", "osmgmt.licenseprocesses", "osmgmt.licenseusers", "osmgmt.licensedistributed" {
        Do ..AssertReadRefused(..#BOTHUSER, tTool, "%Admin_Operate:USE")
        Do ..AssertReadRefused(..#OPERATEONLYUSER, tTool, "%DB_IRISSYS:READ")
    }

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/osmgmt.dashboard/read?maxRows=5", ..#OPERATEUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the Dashboard read completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    If tStatus = 200 {
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tAnswer.rows.%Size(), 1, "one row, the instance's own")
        If tAnswer.rows.%Size() = 1 Do $$$AssertEquals(tAnswer.rows.%Get(0).%GetTypeOf("Sensors.cpuUsage"), "number", "carrying CPU as a number")
    }

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/osmgmt.licensesummary/read?maxRows=5", ..#OPERATEUSER, ..PreparedPassword, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC, "the License usage read completes")
    Do $$$AssertEquals(tStatus2, 200, "and answers")
    If tStatus2 = 200 {
        Set tAnswer2 = ##class(%DynamicObject).%FromJSON(tBody2)
        Do $$$AssertEquals(tAnswer2.rows.%Size(), 5, "the vendor's five summary rows")
    }
}

}
