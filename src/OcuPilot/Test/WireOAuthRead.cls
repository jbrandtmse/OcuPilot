/// <p>The OAuth 2.0 tabs' privilege pair sets over the wire, against the <b>real</b>
/// <code>$System.Security.Check</code> (AD-8, AD-29). Each tab declares its administrative resource and
/// <code>%DB_IRISSYS:READ</code>: <code>%Admin_OAuth2_Client:USE</code> for the Client server
/// descriptions and Client configurations tabs, <code>%Admin_Secure:USE</code> for Resource servers,
/// <code>%Admin_OAuth2_Server:USE</code> for Authorization server and
/// <code>%Admin_OAuth2_Registration:USE</code> for Server client descriptions. A principal holding exactly
/// one tab resource and the database read reads that resource's tabs with the test account's rows and
/// is refused every other tab, in the navigation map and on the read route, naming the tab's first
/// unheld pair; the area names the first area pair it lacks.</p>
/// <p><b>Five purpose-built principals, created in <method>OnBeforeAllTests</method> and deleted in
/// <method>OnAfterAllTests</method></b>, on <class>OcuPilot.Test.WireSecurityRead</class>'s shape. Each
/// holds read on the install namespace's code database. <parameter>CLIENTUSER</parameter>,
/// <parameter>SERVERUSER</parameter>, <parameter>REGUSER</parameter> and <parameter>SECUREUSER</parameter>
/// add <code>%DB_IRISSYS:R</code> and one of <code>%Admin_OAuth2_Client:U</code>,
/// <code>%Admin_OAuth2_Server:U</code>, <code>%Admin_OAuth2_Registration:U</code> and
/// <code>%Admin_Secure:U</code>; <parameter>NODBUSER</parameter> adds <code>%Admin_OAuth2_Client:U</code>
/// alone. The rows come from <class>OcuPilot.Test.OAuthProbe</class>, made and removed alongside.
/// <b>It creates security principals and OAuth 2.0 objects, so <method>OnBeforeAllTests</method> refuses
/// to run unless <parameter>ARMINGVARIABLE</parameter> arms it.</b></p>
/// <p>Needs the API application installed, the demo fixture's SSL/TLS configuration, and a configured
/// test account (<class>OcuPilot.Test.Http</class>) that reads every OAuth 2.0 object.</p>
Class OcuPilot.Test.WireOAuthRead Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it: <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal holding <code>%Admin_OAuth2_Client:U</code> and <code>%DB_IRISSYS:R</code>.</p>
Parameter CLIENTUSER = "OcuPilotWireOAuthClient";

/// <p>See <parameter>CLIENTUSER</parameter>.</p>
Parameter CLIENTROLE = "OcuPilotWireOAuthClientRole";

/// <p>The principal holding <code>%Admin_OAuth2_Server:U</code> and <code>%DB_IRISSYS:R</code>.</p>
Parameter SERVERUSER = "OcuPilotWireOAuthServer";

/// <p>See <parameter>SERVERUSER</parameter>.</p>
Parameter SERVERROLE = "OcuPilotWireOAuthServerRole";

/// <p>The principal holding <code>%Admin_OAuth2_Registration:U</code> and <code>%DB_IRISSYS:R</code>.</p>
Parameter REGUSER = "OcuPilotWireOAuthReg";

/// <p>See <parameter>REGUSER</parameter>.</p>
Parameter REGROLE = "OcuPilotWireOAuthRegRole";

/// <p>The principal holding <code>%Admin_Secure:U</code> and <code>%DB_IRISSYS:R</code>.</p>
Parameter SECUREUSER = "OcuPilotWireOAuthSecure";

/// <p>See <parameter>SECUREUSER</parameter>.</p>
Parameter SECUREROLE = "OcuPilotWireOAuthSecureRole";

/// <p>The principal holding <code>%Admin_OAuth2_Client:U</code> and not <code>%DB_IRISSYS:R</code>.</p>
Parameter NODBUSER = "OcuPilotWireOAuthNoDb";

/// <p>See <parameter>NODBUSER</parameter>.</p>
Parameter NODBROLE = "OcuPilotWireOAuthNoDbRole";

/// <p>The five accounts' password for this run, generated in <method>OnBeforeAllTests</method> and
/// never written to source.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back each account's pairs and made the probe
/// objects.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WireOAuthRead creates and deletes five IRIS users, five roles and OAuth 2.0 objects on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
        Set tSC = ..EnsurePrincipal(..#CLIENTROLE, ..#CLIENTUSER, tCodeRead _ ",%Admin_OAuth2_Client:U,%DB_IRISSYS:R")
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#SERVERROLE, ..#SERVERUSER, tCodeRead _ ",%Admin_OAuth2_Server:U,%DB_IRISSYS:R")
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#REGROLE, ..#REGUSER, tCodeRead _ ",%Admin_OAuth2_Registration:U,%DB_IRISSYS:R")
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#SECUREROLE, ..#SECUREUSER, tCodeRead _ ",%Admin_Secure:U,%DB_IRISSYS:R")
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#NODBROLE, ..#NODBUSER, tCodeRead _ ",%Admin_OAuth2_Client:U")
        If $$$ISERR(tSC) Quit
        Set tOk = 1
        For tCase = $ListBuild(..#CLIENTUSER, "%Admin_OAuth2_Client"), $ListBuild(..#SERVERUSER, "%Admin_OAuth2_Server"), $ListBuild(..#REGUSER, "%Admin_OAuth2_Registration"), $ListBuild(..#SECUREUSER, "%Admin_Secure"), $ListBuild(..#NODBUSER, "%Admin_OAuth2_Client") {
            Set tUser = $List(tCase, 1)
            For tResource = "%Admin_OAuth2_Client", "%Admin_OAuth2_Server", "%Admin_OAuth2_Registration", "%Admin_Secure", "%Admin_Wallet" {
                Set tHolds = ($SYSTEM.Security.CheckUserPermission(tUser, tResource, "USE") = 1)
                If tHolds '= (tResource = $List(tCase, 2)) Set tOk = 0
            }
            Set tHoldsDb = ($SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "READ") = 1)
            If tHoldsDb '= (tUser '= ..#NODBUSER) Set tOk = 0
        }
        Set $NAMESPACE = tOrigNS
        If 'tOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the five principals' pairs")
            Quit
        }
        Set tSC = ##class(OcuPilot.Test.OAuthProbe).Create()
        If $$$ISERR(tSC) Quit
        Set ..PreparedSetupOk = 1
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the five accounts, their roles and the probe objects, and <b>return a failing status</b> if
/// anything survives, since <code>%UnitTest.Manager</code> records no assertion from this method. An
/// unarmed run created nothing and removes nothing: the manager calls this after a refused
/// <method>OnBeforeAllTests</method> too.</p>
Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        For tUser = ..#CLIENTUSER, ..#SERVERUSER, ..#REGUSER, ..#SECUREUSER, ..#NODBUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ tUser
        }
        For tRole = ..#CLIENTROLE, ..#SERVERROLE, ..#REGROLE, ..#SECUREROLE, ..#NODBROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ tRole
        }
        Set $NAMESPACE = tOrigNS
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.WireOAuthRead teardown left throwaway objects on the instance: " _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit $$$ADDSC(tSC, ##class(OcuPilot.Test.OAuthProbe).Remove())
}

/// <p>Create (or re-grant) one throwaway role and the account that holds it.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
Method EnsurePrincipal(pRole As %String, pUser As %String, pResources As %String) As %Status
{
    Set tSC = $$$OK
    If ##class(Security.Roles).Exists(pRole, .tR, .tRS) {
        Set tModProps("Resources") = pResources
        Set tModProps("GrantedRoles") = ""
        Set tModProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(pRole, .tModProps)
    } Else {
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: OAuth 2.0 read principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(pUser)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(pUser, pRole, ..PreparedPassword, "OcuPilot OAuth 2.0 read test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.WireOAuthRead; deleted in OnAfterAllTests")
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
/// <code>allowed</code> alone or <code>allowed:failedPair</code>, or <code>""</code>.</p>
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

/// <p>Assert that <var>pUser</var>'s read of <var>pTool</var> is refused 403 <code>AUTH.NOPRIVILEGE</code>
/// naming <var>pPair</var>, with no rows.</p>
Method AssertReadRefused(pUser As %String, pTool As %String, pPair As %String)
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ pTool _ "/read?maxRows=5", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, pUser _ " " _ pTool _ ": the read request completes")
    Do $$$AssertEquals(tStatus, 403, pUser _ " " _ pTool _ ": the read is refused, never a 500")
    Set tRefusal = ""
    Try {
        Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set tRefusal = ""
    }
    If '$IsObject(tRefusal) Quit
    Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", pUser _ " " _ pTool _ ": on the screen-privilege code")
    Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), pPair, pUser _ " " _ pTool _ ": naming " _ pPair)
    Do $$$AssertEquals(tRefusal.%GetTypeOf("rows"), "unassigned", pUser _ " " _ pTool _ ": with no rows")
}

/// <p>Assert that <var>pUser</var>'s read of <var>pTool</var> at <code>maxRows=1000</code> answers 200
/// with a non-empty, untruncated row set equal, row for row, to the test account's own read (AD-29).</p>
Method AssertSameRowsAsTestAccount(pUser As %String, pTool As %String)
{
    Set tPath = "/api/ocupilot/screens/" _ pTool _ "/read?maxRows=1000"
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
}

/// <p>Matrix "Pairs", CLIENT -- <code>%Admin_OAuth2_Client:USE</code> and <code>%DB_IRISSYS:READ</code>
/// read the Client server descriptions and Client configurations tabs, each with the test account's
/// rows, and every other tab is refused naming its first pair.</p>
/// <p>Mutation: drop <code>%Admin_OAuth2_Client:USE</code> from
/// <class>OcuPilot.Screen.Descriptor.OAuthClientTab</class> -&gt; its entry reads allowed for the
/// server, registration and secure principals, so their three tests go red while this one stays
/// green.</p>
Method TestTheClientPairsReadTheClientTabs()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the five principals' pairs and made the probe objects")
    Do $$$AssertEquals(..ScreensFor(..#CLIENTUSER, "security"), "[{""route"":""security/oauth/clients"",""labelKey"":""oauthTabClients"",""sideBarPosition"":0,""allowed"":true},{""route"":""security/oauth/resource-servers"",""labelKey"":""oauthTabResourceServers"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/server-clients"",""labelKey"":""oauthTabServerClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/server"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/wallet/secrets/edit"",""labelKey"":""walletSecretFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/wallet/secrets"",""labelKey"":""walletSecretListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/x509/edit"",""labelKey"":""x509FormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/x509"",""labelKey"":""x509ListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ldap"",""labelKey"":""ldapListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/wallet"",""labelKey"":""walletListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/oauth"",""labelKey"":""oauthLabel"",""sideBarPosition"":5,""allowed"":true}]", "the Security and secrets entries, each denied on the first pair this principal lacks")
    Do $$$AssertEquals(..AreaVerdictFor(..#CLIENTUSER, "security"), "false:%Admin_Secure:USE", "and the area names the first area pair it lacks")
    Do ..AssertSameRowsAsTestAccount(..#CLIENTUSER, "security.oauthserverdescriptions")
    Do ..AssertSameRowsAsTestAccount(..#CLIENTUSER, "security.oauthclients")
    Do ..AssertReadRefused(..#CLIENTUSER, "security.oauthresourceservers", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#CLIENTUSER, "security.oauthserver", "%Admin_OAuth2_Server:USE")
    Do ..AssertReadRefused(..#CLIENTUSER, "security.oauthserverclients", "%Admin_OAuth2_Registration:USE")
}

/// <p>Matrix "Pairs", SERVER -- <code>%Admin_OAuth2_Server:USE</code> and <code>%DB_IRISSYS:READ</code>
/// read the Authorization server tab with the test account's row, and every other tab is refused
/// naming its first pair.</p>
Method TestTheServerPairsReadTheAuthorizationServerTab()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the five principals' pairs and made the probe objects")
    Do $$$AssertEquals(..ScreensFor(..#SERVERUSER, "security"), "[{""route"":""security/oauth/clients"",""labelKey"":""oauthTabClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/resource-servers"",""labelKey"":""oauthTabResourceServers"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/server-clients"",""labelKey"":""oauthTabServerClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/server"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":true},{""route"":""security/wallet/secrets/edit"",""labelKey"":""walletSecretFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/wallet/secrets"",""labelKey"":""walletSecretListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/x509/edit"",""labelKey"":""x509FormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/x509"",""labelKey"":""x509ListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ldap"",""labelKey"":""ldapListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/wallet"",""labelKey"":""walletListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/oauth"",""labelKey"":""oauthLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""}]", "the Security and secrets entries, each denied on the first pair this principal lacks")
    Do $$$AssertEquals(..AreaVerdictFor(..#SERVERUSER, "security"), "false:%Admin_Secure:USE", "and the area names the first area pair it lacks")
    Do ..AssertReadRefused(..#SERVERUSER, "security.oauthserverdescriptions", "%Admin_OAuth2_Client:USE")
    Do ..AssertReadRefused(..#SERVERUSER, "security.oauthclients", "%Admin_OAuth2_Client:USE")
    Do ..AssertReadRefused(..#SERVERUSER, "security.oauthresourceservers", "%Admin_Secure:USE")
    Do ..AssertSameRowsAsTestAccount(..#SERVERUSER, "security.oauthserver")
    Do ..AssertReadRefused(..#SERVERUSER, "security.oauthserverclients", "%Admin_OAuth2_Registration:USE")
}

/// <p>Matrix "Pairs", REG, and AC5's refusal -- <code>%Admin_OAuth2_Registration:USE</code> and
/// <code>%DB_IRISSYS:READ</code> read the Server client descriptions tab with the test account's rows,
/// and every other tab is refused naming its first pair.</p>
/// <p>Mutation: drop <code>%Admin_OAuth2_Registration:USE</code> from
/// <class>OcuPilot.Screen.Descriptor.OAuthServerClientTab</class> -&gt; the tab reads allowed, or refused
/// on <code>%DB_IRISSYS:READ</code>, for the other four principals, so their tests go red while this one
/// stays green.</p>
Method TestTheRegistrationPairsReadTheServerClientsTab()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the five principals' pairs and made the probe objects")
    Do $$$AssertEquals(..ScreensFor(..#REGUSER, "security"), "[{""route"":""security/oauth/clients"",""labelKey"":""oauthTabClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/resource-servers"",""labelKey"":""oauthTabResourceServers"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/server-clients"",""labelKey"":""oauthTabServerClients"",""sideBarPosition"":0,""allowed"":true},{""route"":""security/oauth/server"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/wallet/secrets/edit"",""labelKey"":""walletSecretFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/wallet/secrets"",""labelKey"":""walletSecretListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/x509/edit"",""labelKey"":""x509FormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/x509"",""labelKey"":""x509ListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ldap"",""labelKey"":""ldapListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/wallet"",""labelKey"":""walletListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/oauth"",""labelKey"":""oauthLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""}]", "the Security and secrets entries, each denied on the first pair this principal lacks")
    Do $$$AssertEquals(..AreaVerdictFor(..#REGUSER, "security"), "false:%Admin_Secure:USE", "and the area names the first area pair it lacks")
    Do ..AssertReadRefused(..#REGUSER, "security.oauthserverdescriptions", "%Admin_OAuth2_Client:USE")
    Do ..AssertReadRefused(..#REGUSER, "security.oauthclients", "%Admin_OAuth2_Client:USE")
    Do ..AssertReadRefused(..#REGUSER, "security.oauthresourceservers", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#REGUSER, "security.oauthserver", "%Admin_OAuth2_Server:USE")
    Do ..AssertSameRowsAsTestAccount(..#REGUSER, "security.oauthserverclients")
}

/// <p>Matrix "Pairs", SECURE, and AC5 -- <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>
/// read the Resource servers tab with the test account's rows; the other four tabs are listed gated and
/// refused naming their resource; and the area is denied on <code>%Admin_Wallet:USE</code>.</p>
Method TestTheSecurePairsReadTheResourceServersTab()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the five principals' pairs and made the probe objects")
    Do $$$AssertEquals(..ScreensFor(..#SECUREUSER, "security"), "[{""route"":""security/oauth/clients"",""labelKey"":""oauthTabClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""},{""route"":""security/oauth/resource-servers"",""labelKey"":""oauthTabResourceServers"",""sideBarPosition"":0,""allowed"":true},{""route"":""security/oauth/server-clients"",""labelKey"":""oauthTabServerClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/server"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/wallet/secrets/edit"",""labelKey"":""walletSecretFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/wallet/secrets"",""labelKey"":""walletSecretListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/x509/edit"",""labelKey"":""x509FormLabel"",""sideBarPosition"":0,""allowed"":true},{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":true},{""route"":""security/x509"",""labelKey"":""x509ListLabel"",""sideBarPosition"":2,""allowed"":true},{""route"":""security/ldap"",""labelKey"":""ldapListLabel"",""sideBarPosition"":3,""allowed"":true},{""route"":""security/wallet"",""labelKey"":""walletListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/oauth"",""labelKey"":""oauthLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%Admin_OAuth2_Client:USE""}]", "the Security and secrets entries, each denied on the first pair this principal lacks")
    Do $$$AssertEquals(..AreaVerdictFor(..#SECUREUSER, "security"), "false:%Admin_Wallet:USE", "and the area names the first area pair it lacks")
    Do ..AssertReadRefused(..#SECUREUSER, "security.oauthserverdescriptions", "%Admin_OAuth2_Client:USE")
    Do ..AssertReadRefused(..#SECUREUSER, "security.oauthclients", "%Admin_OAuth2_Client:USE")
    Do ..AssertSameRowsAsTestAccount(..#SECUREUSER, "security.oauthresourceservers")
    Do ..AssertReadRefused(..#SECUREUSER, "security.oauthserver", "%Admin_OAuth2_Server:USE")
    Do ..AssertReadRefused(..#SECUREUSER, "security.oauthserverclients", "%Admin_OAuth2_Registration:USE")
}

/// <p>Matrix "No system DB read" -- <code>%Admin_OAuth2_Client:USE</code> without
/// <code>%DB_IRISSYS:READ</code> sees the Client server descriptions and Client configurations entries
/// denied naming the database read, and both reads are refused naming it, never failing inside the
/// port.</p>
/// <p>Mutation: drop <code>%DB_IRISSYS:READ</code> from
/// <class>OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab</class> -&gt; its entry reads allowed and
/// the read is no longer refused by name.</p>
Method TestTheClientResourceWithoutTheSystemReadIsDenied()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the five principals' pairs and made the probe objects")
    Do $$$AssertEquals(..ScreensFor(..#NODBUSER, "security"), "[{""route"":""security/oauth/clients"",""labelKey"":""oauthTabClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""},{""route"":""security/oauth/resource-servers"",""labelKey"":""oauthTabResourceServers"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/oauth/server-clients"",""labelKey"":""oauthTabServerClients"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Registration:USE""},{""route"":""security/oauth/server"",""labelKey"":""oauthTabServer"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_OAuth2_Server:USE""},{""route"":""security/wallet/secrets/edit"",""labelKey"":""walletSecretFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/wallet/secrets"",""labelKey"":""walletSecretListLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/x509/edit"",""labelKey"":""x509FormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ssl"",""labelKey"":""sslListLabel"",""sideBarPosition"":1,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/x509"",""labelKey"":""x509ListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/ldap"",""labelKey"":""ldapListLabel"",""sideBarPosition"":3,""allowed"":false,""failedPair"":""%Admin_Secure:USE""},{""route"":""security/wallet"",""labelKey"":""walletListLabel"",""sideBarPosition"":4,""allowed"":false,""failedPair"":""%Admin_Wallet:USE""},{""route"":""security/oauth"",""labelKey"":""oauthLabel"",""sideBarPosition"":5,""allowed"":false,""failedPair"":""%DB_IRISSYS:READ""}]", "the Security and secrets entries, each denied on the first pair this principal lacks")
    Do $$$AssertEquals(..AreaVerdictFor(..#NODBUSER, "security"), "false:%Admin_Secure:USE", "and the area names the first area pair it lacks")
    Do ..AssertReadRefused(..#NODBUSER, "security.oauthserverdescriptions", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#NODBUSER, "security.oauthclients", "%DB_IRISSYS:READ")
    Do ..AssertReadRefused(..#NODBUSER, "security.oauthresourceservers", "%Admin_Secure:USE")
    Do ..AssertReadRefused(..#NODBUSER, "security.oauthserver", "%Admin_OAuth2_Server:USE")
    Do ..AssertReadRefused(..#NODBUSER, "security.oauthserverclients", "%Admin_OAuth2_Registration:USE")
}

}
