/// <p>AD-8 as amended for DW-1768, over the wire and against the
/// <b>real</b> <code>$System.Security.Check</code>: an area opens when any screen its side bar lists
/// is allowed, and each screen keeps its own gate, so an unavailable screen stays listed naming its
/// failed pair and its read is still refused.</p>
/// <p><b>Four purpose-built principals, created in <method>OnBeforeAllTests</method> and deleted in
/// <method>OnAfterAllTests</method></b>, each holding read on the install namespace's code database:
/// <parameter>OPERATORUSER</parameter> adds the <code>%Operator</code> role itself, and only reads
/// here;
/// <parameter>WALLETUSER</parameter> adds <code>%Admin_Wallet:U</code> and <code>%DB_IRISSYS:R</code>;
/// <parameter>OAUTHUSER</parameter> adds <code>%Admin_OAuth2_Client:U</code> and
/// <code>%DB_IRISSYS:R</code>; and <parameter>NONEUSER</parameter> adds <code>%Admin_Journal:U</code>,
/// an administrative resource no screen declares, which clears the API's administrative floor.
/// <b>It creates security principals, so <method>OnBeforeAllTests</method> refuses to
/// run unless <parameter>ARMINGVARIABLE</parameter> arms it</b> (DW-289).</p>
/// <p>Needs the API application installed and no custom resource assigned to a classic page the
/// screens here replace.</p>
Class OcuPilot.Test.WireAreaAnyScreen Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it, so the principals this class
/// creates exist on the container that script builds and nowhere else.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal holding the <code>%Operator</code> role.</p>
Parameter OPERATORUSER = "OcuPilotWireAnyOperator";

/// <p>See <parameter>OPERATORUSER</parameter>.</p>
Parameter OPERATORROLE = "OcuPilotWireAnyOperatorRole";

/// <p>The principal holding a wallet resource and the database read, and no
/// <code>%Admin_Secure</code>.</p>
Parameter WALLETUSER = "OcuPilotWireAnyWallet";

/// <p>See <parameter>WALLETUSER</parameter>.</p>
Parameter WALLETROLE = "OcuPilotWireAnyWalletRole";

/// <p>The principal holding the OAuth 2.0 client resource and the database read, and no
/// <code>%Admin_Secure</code>.</p>
Parameter OAUTHUSER = "OcuPilotWireAnyOAuth";

/// <p>See <parameter>OAUTHUSER</parameter>.</p>
Parameter OAUTHROLE = "OcuPilotWireAnyOAuthRole";

/// <p>The principal holding no pair any screen declares.</p>
Parameter NONEUSER = "OcuPilotWireAnyNone";

/// <p>See <parameter>NONEUSER</parameter>.</p>
Parameter NONEROLE = "OcuPilotWireAnyNoneRole";

/// <p>The four accounts' password for this run, generated in <method>OnBeforeAllTests</method> and
/// never written to source.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back that each account holds exactly the pairs
/// it is meant to.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WireAreaAnyScreen creates and deletes four IRIS users and four roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotAny" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

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

        Set tSC = ..EnsurePrincipal(..#OPERATORROLE, ..#OPERATORUSER, tCodeRead, ..PreparedPassword, "%Operator")
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#WALLETROLE, ..#WALLETUSER, tCodeRead _ ",%Admin_Wallet:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#OAUTHROLE, ..#OAUTHUSER, tCodeRead _ ",%Admin_OAuth2_Client:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#NONEROLE, ..#NONEUSER, tCodeRead _ ",%Admin_Journal:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit

        Set tOperator = ..Holds(..#OPERATORUSER, "%Admin_Operate:USE,%DB_IRISSYS:READ,%DB_IRISSYS:WRITE", "%Admin_Secure:USE,%Admin_Manage:USE,%Admin_Task:USE")
        Set tWallet = ..Holds(..#WALLETUSER, "%Admin_Wallet:USE,%DB_IRISSYS:READ", "%Admin_Secure:USE,%Admin_Operate:USE,%Admin_OAuth2_Client:USE")
        Set tOAuth = ..Holds(..#OAUTHUSER, "%Admin_OAuth2_Client:USE,%DB_IRISSYS:READ", "%Admin_Secure:USE,%Admin_Operate:USE,%Admin_Wallet:USE")
        Set tNone = ..Holds(..#NONEUSER, "%Admin_Journal:USE", "%DB_IRISSYS:READ,%Admin_Secure:USE,%Admin_Operate:USE,%Admin_Task:USE,%Admin_Manage:USE")
        Set ..PreparedSetupOk = tOperator && tWallet && tOAuth && tNone
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the four principals' pairs: operator " _ tOperator _ ", wallet " _ tWallet _ ", oauth " _ tOAuth _ ", none " _ tNone)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the four accounts and their roles, and <b>return a failing status</b> if any survives.
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
        For tUser = ..#OPERATORUSER, ..#WALLETUSER, ..#OAUTHUSER, ..#NONEUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ tUser
        }
        For tRole = ..#OPERATORROLE, ..#WALLETROLE, ..#OAUTHROLE, ..#NONEROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ tRole
        }
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.WireAreaAnyScreen teardown left throwaway objects on the instance: " _ tLeft)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create (or re-grant) one throwaway role and the account that holds it, and
/// <var>pOtherRoles</var> (comma-separated existing roles) beside it.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
Method EnsurePrincipal(pRole As %String, pUser As %String, pResources As %String, pPassword As %String, pOtherRoles As %String = "") As %Status
{
    Set tSC = $$$OK
    If ##class(Security.Roles).Exists(pRole, .tR, .tRS) {
        Set tModProps("Resources") = pResources
        Set tModProps("GrantedRoles") = ""
        Set tModProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(pRole, .tModProps)
    } Else {
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: area verdict principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(pUser)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(pUser, pRole _ $Select(pOtherRoles = "": "", 1: "," _ pOtherRoles), pPassword, "OcuPilot area verdict test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.WireAreaAnyScreen; deleted in OnAfterAllTests")
}

/// <p>Whether <var>pUser</var> holds every <code>resource:permission</code> in <var>pHeld</var> and
/// none in <var>pNotHeld</var>, read back through <code>$SYSTEM.Security.CheckUserPermission</code>,
/// since <code>Security.Users.Create</code> accepts a role it cannot grant.</p>
ClassMethod Holds(pUser As %String, pHeld As %String, pNotHeld As %String) As %Boolean
{
    Set tOk = 1
    For tI = 1:1:$Length(pHeld, ",") {
        Set tPair = $Piece(pHeld, ",", tI)
        If $SYSTEM.Security.CheckUserPermission(pUser, $Piece(tPair, ":", 1), $Piece(tPair, ":", 2)) '= 1 Set tOk = 0
    }
    For tI = 1:1:$Length(pNotHeld, ",") {
        Set tPair = $Piece(pNotHeld, ",", tI)
        If $SYSTEM.Security.CheckUserPermission(pUser, $Piece(tPair, ":", 1), $Piece(tPair, ":", 2)) = 1 Set tOk = 0
    }
    Quit tOk
}

/// <p>The navigation map <var>pUser</var> is served, or <code>""</code> when it does not answer
/// 200.</p>
Method MapFor(pUser As %String) As %DynamicObject
{
    Set tMap = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/navigation", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit ""
    Try {
        Set tMap = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set tMap = ""
    }
    Quit tMap
}

/// <p>Every area's verdict in <var>pMap</var>, in rail order, as <code>key=open</code> or
/// <code>key=failedPair</code>.</p>
ClassMethod AreaVerdicts(pMap As %DynamicObject) As %String
{
    Set tOut = ""
    If '$IsObject(pMap) Quit tOut
    Set tIterator = pMap.areas.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tArea) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: " ") _ tArea.key _ "=" _ $Select(tArea.allowed: "open", 1: tArea.%Get("failedPair"))
    }
    Quit tOut
}

/// <p>The verdicts of the screens <var>pArea</var>'s side bar lists in <var>pMap</var>, in side-bar
/// order, as <code>route=open</code> or <code>route=failedPair</code>.</p>
ClassMethod ListedVerdicts(pMap As %DynamicObject, pArea As %String) As %String
{
    Set tOut = ""
    If '$IsObject(pMap) Quit tOut
    Set tIterator = pMap.areas.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tArea) {
        If tArea.key '= pArea Continue
        Set tScreens = tArea.screens.%GetIterator()
        While tScreens.%GetNext(.tScreenIndex, .tScreen) {
            If +tScreen.sideBarPosition = 0 Continue
            Set tOut = tOut _ $Select(tOut = "": "", 1: " ") _ tScreen.route _ "=" _ $Select(tScreen.allowed: "open", 1: tScreen.%Get("failedPair"))
        }
    }
    Quit tOut
}

/// <p><var>pUser</var>'s read of <var>pTool</var> as <code>status</code>, or
/// <code>status code failedPair</code> for a refusal.</p>
Method ReadOutcome(pUser As %String, pTool As %String) As %String
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ pTool _ "/read?maxRows=5", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) Quit "no answer"
    If tStatus = 200 Quit tStatus
    Set tRefusal = ""
    Try {
        Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set tRefusal = ""
    }
    If '$IsObject(tRefusal) Quit tStatus
    Quit tStatus _ " " _ tRefusal.code _ " " _ $Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: "")
}

/// <p>A holder of the <code>%Operator</code> role opens Logs and OS management, and Tasks and
/// Web applications through Background tasks and Web sessions; the screens its pairs admit are open,
/// the others are listed naming their pair, and their reads are refused. Permissions and Security
/// and secrets list no screen it can open and stay gated.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Gate.EvaluateArea</method> answer
/// <method>OcuPilot.Screen.Gate.EvaluatePairs</method> over the area's declared set -- the all-pairs
/// rule -- and recompile the package -> the area row goes red; the screen rows and reads stay
/// green.</p>
Method TestOperatorsPairsOpenLogsAndOsManagement()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the four principals' pairs")
    Set tMap = ..MapFor(..#OPERATORUSER)
    Do $$$AssertTrue($IsObject(tMap), "the navigation map answers the principal")
    Do $$$AssertEquals(..AreaVerdicts(tMap), "home=open logs=open os-management=open tasks=open permissions=%Admin_Secure:USE web-applications=open security=%Admin_Secure:USE system-explorer=%Development:USE agent=open", "Logs, OS management, Tasks and Web applications open, and Permissions and Security stay gated: " _ ..AreaVerdicts(tMap))
    Do $$$AssertEquals(..ListedVerdicts(tMap, "logs"), "logs/alerts=open logs/messages=open logs/errors=open logs/audit=%Admin_Secure:USE logs/systemmonitor=open logs/taskerrors=open logs/xdbc=open logs/sqldiagnostics=open logs/eventlog=%Ens_EventLog:USE logs/analytics=open logs/hub=open", "Logs lists every screen, the audit viewer and the event log naming the pair each needs: " _ ..ListedVerdicts(tMap, "logs"))
    Do $$$AssertEquals(..ListedVerdicts(tMap, "os-management"), "os-management/processes=%Admin_Manage:USE os-management/locks=open os-management/system-usage=open os-management/databases=%Admin_Manage:USE os-management/databases/integrity-log=open os-management/devices=%Admin_Manage:USE os-management/namespaces=%Admin_Manage:USE os-management/license-usage=open os-management/dashboard=open os-management/language-servers=%Admin_ExternalLanguageServerEdit:USE os-management/local-databases=%Admin_Manage:USE", "OS management lists every screen, those needing another resource naming it: " _ ..ListedVerdicts(tMap, "os-management"))
    Set tRead = ..ReadOutcome(..#OPERATORUSER, "osmgmt.locks")
    Do $$$AssertEquals(tRead, 200, "Locks reads: " _ tRead)
    Set tRead = ..ReadOutcome(..#OPERATORUSER, "osmgmt.processes")
    Do $$$AssertEquals(tRead, "403 AUTH.NOPRIVILEGE %Admin_Manage:USE", "while Processes keeps its own gate: " _ tRead)
    Set tRead = ..ReadOutcome(..#OPERATORUSER, "logs.audit")
    Do $$$AssertEquals(tRead, "403 AUTH.NOPRIVILEGE %Admin_Secure:USE", "and so does the audit database viewer: " _ tRead)
}

/// <p>A wallet holder and an OAuth 2.0 client holder each open Security and secrets and see only
/// their own screen open; every other listed screen names its pair, and its read is refused.</p>
/// <p>Mutation (Rule 19): the all-pairs rule of
/// <method>TestOperatorsPairsOpenLogsAndOsManagement</method> -> both area rows go red.</p>
Method TestAWalletHolderAndAnOAuthHolderOpenSecurity()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the four principals' pairs")
    Set tWallet = ..MapFor(..#WALLETUSER)
    Do $$$AssertEquals(..AreaVerdicts(tWallet), "home=open logs=open os-management=%Admin_Operate:USE tasks=%Admin_Task:USE permissions=%Admin_Secure:USE web-applications=%Admin_Secure:USE security=open system-explorer=%Development:USE agent=open", "the wallet holder opens Security and secrets, and Logs on the public analytics log: " _ ..AreaVerdicts(tWallet))
    Do $$$AssertEquals(..ListedVerdicts(tWallet, "security"), "security/ssl=%Admin_Secure:USE security/x509=%Admin_Secure:USE security/ldap=%Admin_Secure:USE security/wallet=open security/oauth=%Admin_OAuth2_Client:USE security/auditing=%Admin_Secure:USE security/allowed-directories=%Admin_FileSystemAccess:USE", "and sees only Wallet open: " _ ..ListedVerdicts(tWallet, "security"))
    Set tRead = ..ReadOutcome(..#WALLETUSER, "security.wallet")
    Do $$$AssertEquals(tRead, 200, "which reads: " _ tRead)
    Set tRead = ..ReadOutcome(..#WALLETUSER, "security.ssl")
    Do $$$AssertEquals(tRead, "403 AUTH.NOPRIVILEGE %Admin_Secure:USE", "while SSL/TLS keeps its own gate: " _ tRead)

    Set tOAuth = ..MapFor(..#OAUTHUSER)
    Do $$$AssertEquals(..AreaVerdicts(tOAuth), "home=open logs=open os-management=%Admin_Operate:USE tasks=%Admin_Task:USE permissions=%Admin_Secure:USE web-applications=%Admin_Secure:USE security=open system-explorer=%Development:USE agent=open", "the OAuth 2.0 client holder opens Security and secrets, and Logs on the public analytics log: " _ ..AreaVerdicts(tOAuth))
    Do $$$AssertEquals(..ListedVerdicts(tOAuth, "security"), "security/ssl=%Admin_Secure:USE security/x509=%Admin_Secure:USE security/ldap=%Admin_Secure:USE security/wallet=%Admin_Wallet:USE security/oauth=open security/auditing=%Admin_Secure:USE security/allowed-directories=%Admin_FileSystemAccess:USE", "and sees only OAuth 2.0 open: " _ ..ListedVerdicts(tOAuth, "security"))
    Set tRead = ..ReadOutcome(..#OAUTHUSER, "security.oauthserverdescriptions")
    Do $$$AssertEquals(tRead, 200, "which reads: " _ tRead)
    Set tRead = ..ReadOutcome(..#OAUTHUSER, "security.wallet")
    Do $$$AssertEquals(tRead, "403 AUTH.NOPRIVILEGE %Admin_Wallet:USE", "while the Wallet list keeps its own gate: " _ tRead)
}

/// <p>A holder of none of an area's screens sees the area gated, naming the first pair of its
/// declared set it lacks, and every screen of it listed unavailable. The principal holds one
/// administrative resource no screen declares, so every gated area but Logs is such an area; Logs
/// opens on the analytics log alone, whose <code>%DeepSee_Portal:USE</code> a stock instance grants
/// publicly.</p>
/// <p>Mutation (Rule 19): the all-pairs rule turns only the Logs verdict red here, since it and the
/// rule it replaces agree for a holder of none; have <method>OcuPilot.Screen.Gate.EvaluateArea</method>
/// answer allowed when no listed screen opens -> the six gated areas go red.</p>
Method TestAHolderOfNoneOfAnAreasScreensSeesItGated()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the four principals' pairs")
    Set tMap = ..MapFor(..#NONEUSER)
    Do $$$AssertTrue($IsObject(tMap), "the navigation map answers a principal holding one administrative resource")
    Do $$$AssertEquals(..AreaVerdicts(tMap), "home=open logs=open os-management=%Admin_Operate:USE tasks=%Admin_Task:USE permissions=%Admin_Secure:USE web-applications=%Admin_Secure:USE security=%Admin_Secure:USE system-explorer=%Development:USE agent=open", "the six gated areas it holds no screen of each name their set's first pair: " _ ..AreaVerdicts(tMap))
    Set tOpen = ""
    For tArea = "logs", "os-management", "tasks", "permissions", "web-applications", "security", "system-explorer" {
        Set tListed = ..ListedVerdicts(tMap, tArea)
        Do $$$AssertTrue(tListed '= "", tArea _ " still lists its screens")
        For tI = 1:1:$Length(tListed, " ") {
            If $Piece($Piece(tListed, " ", tI), "=", 2) = "open" Set tOpen = tOpen _ " " _ $Piece($Piece(tListed, " ", tI), "=", 1)
        }
    }
    Do $$$AssertEquals(tOpen, " logs/analytics", "and of all their screens only the analytics log is open: " _ tOpen)
}

}
