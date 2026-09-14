/// <p>The security reads' privilege pair set over the wire, against the <b>real</b>
/// <code>$System.Security.Check</code> (AD-8, DW-262, DW-264): the users list, the web applications
/// list and the SSL/TLS configurations list each need <code>%Admin_Secure:USE</code> <b>and</b>
/// <code>%DB_IRISSYS:READ</code>, and a principal
/// holding one of the two is denied on the other in the navigation map, for all three screens and
/// their areas, and on the read route.</p>
/// <p><b>Three purpose-built principals, created in <method>OnBeforeAllTests</method> and deleted in
/// <method>OnAfterAllTests</method></b>, the shape <class>OcuPilot.Test.Wire</class> builds. Each holds
/// read on the install namespace's code database. <parameter>SECUREUSER</parameter> adds
/// <code>%Admin_Secure:U</code>; <parameter>SYSREADUSER</parameter> adds <code>%DB_IRISSYS:R</code>
/// and <code>%Admin_Operate:U</code>, the second because the API's administrative gate refuses a
/// caller holding no <code>%Admin_*</code> resource before any screen gate runs;
/// <parameter>BOTHUSER</parameter> adds <code>%Admin_Secure:U</code> and <code>%DB_IRISSYS:R</code>.
/// <b>It creates security principals, so it runs on a throwaway container only.</b></p>
/// <p>Needs the API application installed and at least one SSL/TLS configuration on the instance,
/// which <method>TestBothPairsReadEveryList</method> asserts rows for.</p>
Class OcuPilot.Test.WireSecurityRead Extends %UnitTest.TestCase
{

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

/// <p>The three accounts' password for this run, generated in <method>OnBeforeAllTests</method> and
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

        Set tSecure = ($SYSTEM.Security.CheckUserPermission(..#SECUREUSER, "%Admin_Secure", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#SECUREUSER, "%DB_IRISSYS", "READ") '= 1)
        Set tSysRead = ($SYSTEM.Security.CheckUserPermission(..#SYSREADUSER, "%Admin_Secure", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#SYSREADUSER, "%DB_IRISSYS", "READ") = 1)
        Set tBoth = ($SYSTEM.Security.CheckUserPermission(..#BOTHUSER, "%Admin_Secure", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#BOTHUSER, "%DB_IRISSYS", "READ") = 1)
        Set ..PreparedSetupOk = tSecure && tSysRead && tBoth
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the three principals' pairs: secure " _ tSecure _ ", sysread " _ tSysRead _ ", both " _ tBoth)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the three accounts and their roles, and <b>return a failing status</b> if any survives.
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
        For tUser = ..#SECUREUSER, ..#SYSREADUSER, ..#BOTHUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ tUser
        }
        For tRole = ..#SECUREROLE, ..#SYSREADROLE, ..#BOTHROLE {
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
/// <code>AUTH.NOPRIVILEGE</code> naming <var>pPair</var>.</p>
Method AssertReadRefused(pUser As %String, pTool As %String, pPair As %String)
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ pTool _ "/read?maxRows=5", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, pUser _ " " _ pTool _ ": the read request completes")
    Do $$$AssertEquals(tStatus, 403, pUser _ " " _ pTool _ ": the read is refused")
    Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", pUser _ " " _ pTool _ ": on the screen-privilege code")
    Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), pPair, pUser _ " " _ pTool _ ": naming " _ pPair)
}

/// <p>AC6 -- <code>%Admin_Secure:USE</code> alone: all three security lists, and the Permissions,
/// Web applications and Security and secrets areas themselves, are listed denied on
/// <code>%DB_IRISSYS:READ</code>, and all three reads are refused naming it.</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.UserList</class> -> the users read answers 500 and its entry
/// and 403 assertions go red; remove it from <class>OcuPilot.Screen.Descriptor.WebAppList</class> ->
/// the web applications leg goes red; remove it from
/// <class>OcuPilot.Screen.Descriptor.SslConfigList</class> -> the SSL/TLS leg goes red; remove it
/// from the <code>permissions</code> area in
/// <class>OcuPilot.Screen.Area</class> -> the Permissions area assertion goes red.</p>
Method TestAdminSecureAloneIsDeniedOnTheSystemDatabaseRead()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the three principals' pairs")
    Do $$$AssertEquals(..ScreensFor(..#SECUREUSER, "permissions"), "[{""route"":""permissions/users"",""labelKey"":""userListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""}]", "the users list is denied on %DB_IRISSYS:READ")
    Do $$$AssertEquals(..ScreensFor(..#SECUREUSER, "web-applications"), "[{""route"":""web-applications/list"",""labelKey"":""webAppListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""}]", "and so is the web applications list")
    Do $$$AssertEquals(..ScreensFor(..#SECUREUSER, "security"), "[{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""}]", "and so is the SSL/TLS configurations list")
    Do $$$AssertEquals(..AreaVerdictFor(..#SECUREUSER, "permissions"), "false:%DB_IRISSYS:READ", "the Permissions area is denied on %DB_IRISSYS:READ")
    Do $$$AssertEquals(..AreaVerdictFor(..#SECUREUSER, "web-applications"), "false:%DB_IRISSYS:READ", "and so is the Web applications area")
    Do $$$AssertEquals(..AreaVerdictFor(..#SECUREUSER, "security"), "false:%DB_IRISSYS:READ", "and so is the Security and secrets area")
    Do ..AssertReadRefused(..#SECUREUSER, "permissions.users", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#SECUREUSER, "webapp.list", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#SECUREUSER, "security.ssl", "%DB_IRISSYS:READ")
}

/// <p>AC6 -- <code>%DB_IRISSYS:READ</code> without <code>%Admin_Secure</code>: all three security
/// lists and their three areas are listed denied on <code>%Admin_Secure:USE</code>, and all three
/// reads are refused naming it.</p>
Method TestSystemReadWithoutAdminSecureIsDenied()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the three principals' pairs")
    Do $$$AssertEquals(..ScreensFor(..#SYSREADUSER, "permissions"), "[{""route"":""permissions/users"",""labelKey"":""userListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""}]", "the users list is denied on %Admin_Secure:USE")
    Do $$$AssertEquals(..ScreensFor(..#SYSREADUSER, "web-applications"), "[{""route"":""web-applications/list"",""labelKey"":""webAppListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""}]", "and so is the web applications list")
    Do $$$AssertEquals(..ScreensFor(..#SYSREADUSER, "security"), "[{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""}]", "and so is the SSL/TLS configurations list")
    Do $$$AssertEquals(..AreaVerdictFor(..#SYSREADUSER, "permissions"), "false:%Admin_Secure:USE", "the Permissions area is denied on %Admin_Secure:USE")
    Do $$$AssertEquals(..AreaVerdictFor(..#SYSREADUSER, "web-applications"), "false:%Admin_Secure:USE", "and so is the Web applications area")
    Do $$$AssertEquals(..AreaVerdictFor(..#SYSREADUSER, "security"), "false:%Admin_Secure:USE", "and so is the Security and secrets area")
    Do ..AssertReadRefused(..#SYSREADUSER, "permissions.users", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#SYSREADUSER, "webapp.list", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#SYSREADUSER, "security.ssl", "%Admin_Secure:USE")
}

/// <p>AC6 -- both pairs: all three lists and their three areas are listed allowed, all three reads
/// answer 200, every users row
/// carries a <code>Roles</code> array from its detail call, and every SSL/TLS row carries exactly the
/// four declared fields.</p>
Method TestBothPairsReadEveryList()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the three principals' pairs")
    Do $$$AssertEquals(..ScreensFor(..#BOTHUSER, "permissions"), "[{""route"":""permissions/users"",""labelKey"":""userListLabel"",""sideBarPosition"":1,""allowed"":true}]", "the users list is listed allowed")
    Do $$$AssertEquals(..ScreensFor(..#BOTHUSER, "web-applications"), "[{""route"":""web-applications/list"",""labelKey"":""webAppListLabel"",""sideBarPosition"":1,""allowed"":true}]", "and so is the web applications list")
    Do $$$AssertEquals(..ScreensFor(..#BOTHUSER, "security"), "[{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":true}]", "and so is the SSL/TLS configurations list")
    Do $$$AssertEquals(..AreaVerdictFor(..#BOTHUSER, "permissions"), "true", "the Permissions area is allowed")
    Do $$$AssertEquals(..AreaVerdictFor(..#BOTHUSER, "web-applications"), "true", "and so is the Web applications area")
    Do $$$AssertEquals(..AreaVerdictFor(..#BOTHUSER, "security"), "true", "and so is the Security and secrets area")
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
}

}
