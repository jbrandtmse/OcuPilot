/// <p>The REST API explorer's and the OpenAPI document viewer's pair set against the <b>real</b>
/// <code>$System.Security.Check</code> (AD-8, AD-29): over the wire, and at the port called
/// directly, as it is on the tool path.</p>
/// <ul>
/// <li>A principal holding read on the install namespace's code database and both pairs reads either
/// screen in <code>HSCUSTOM</code> with 200.</li>
/// <li>A principal holding <code>%DB_IRISSYS:READ</code> and not <code>%Admin_Secure:USE</code> is
/// refused 403 <code>AUTH.NOPRIVILEGE</code> naming that pair by the route, and by
/// <method>OcuPilot.Port.MgmntPort.Invoke</method> itself before any vendor call; and the explorer
/// stays in its area's navigation entries, denied and naming the pair.</li>
/// </ul>
/// <p>The direct call runs in a child process (<class>OcuPilot.Test.MgmntDenialProbe</class>) that
/// logs in as the principal, so this process never changes identity; the child counts vendor calls
/// on <class>OcuPilot.Test.MgmntImplFixture</class> and signals the outcome back.</p>
/// <p><b>It creates security principals, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>), and <method>OnBeforeAllTests</method> refuses anywhere
/// <parameter>ARMINGVARIABLE</parameter> does not arm it. Each principal also holds
/// <code>%Admin_Operate:USE</code> or <code>%Admin_Secure:USE</code>, which clears the API's own
/// administrative gate, and read on the install namespace's code database. Their password is
/// generated for the run and never written to source; both are deleted in
/// <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.MgmntPortDenial Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal holding both pairs.</p>
Parameter BOTHUSER = "OcuPilotMgmntBoth";

/// <p>See <parameter>BOTHUSER</parameter>.</p>
Parameter BOTHROLE = "OcuPilotMgmntBothRole";

/// <p>The principal holding <code>%DB_IRISSYS:READ</code> and <code>%Admin_Operate:USE</code> and
/// not <code>%Admin_Secure:USE</code>.</p>
Parameter NOSECUREUSER = "OcuPilotMgmntNoSecure";

/// <p>See <parameter>NOSECUREUSER</parameter>.</p>
Parameter NOSECUREROLE = "OcuPilotMgmntNoSecureRole";

/// <p>The two accounts' password for this run, generated in <method>OnBeforeAllTests</method>.</p>
Property PreparedPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back each account's pairs.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSetupOk = 0
    Quit $$$OK
}

/// <p>Refuse to run unless this instance is armed for throwaway principals, then create the two
/// principals and read their pairs back.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.MgmntPortDenial creates and deletes IRIS users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so no principal was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = "OcuPilotMgmnt" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"

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

        Set tSC = ..EnsurePrincipal(..#BOTHROLE, ..#BOTHUSER, tCodeRead _ ",%Admin_Secure:U,%DB_IRISSYS:R", ..PreparedPassword)
        If $$$ISERR(tSC) Quit
        Set tSC = ..EnsurePrincipal(..#NOSECUREROLE, ..#NOSECUREUSER, tCodeRead _ ",%DB_IRISSYS:R,%Admin_Operate:U", ..PreparedPassword)
        If $$$ISERR(tSC) Quit

        Set tBoth = ($SYSTEM.Security.CheckUserPermission(..#BOTHUSER, "%Admin_Secure", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#BOTHUSER, "%DB_IRISSYS", "READ") = 1)
        Set tNoSecure = ($SYSTEM.Security.CheckUserPermission(..#NOSECUREUSER, "%Admin_Secure", "USE") '= 1) && ($SYSTEM.Security.CheckUserPermission(..#NOSECUREUSER, "%DB_IRISSYS", "READ") = 1)
        Set ..PreparedSetupOk = tBoth && tNoSecure
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the two principals' pairs: both " _ tBoth _ ", no-secure " _ tNoSecure)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the two accounts and their roles, and return a failing status if any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        For tUser = ..#BOTHUSER, ..#NOSECUREUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ tUser
        }
        For tRole = ..#BOTHROLE, ..#NOSECUREROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ tRole
        }
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.MgmntPortDenial teardown left throwaway objects on the instance: " _ tLeft)
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
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: management API principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(pUser)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(pUser, pRole, pPassword, "OcuPilot management API test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.MgmntPortDenial; deleted in OnAfterAllTests")
}

/// <p>Request <var>pTool</var>'s read with <var>pQuery</var> as <var>pUser</var>. <var>pAnswer</var>
/// is the parsed body, or <code>""</code>.</p>
Method Read(pUser As %String, pTool As %String, pQuery As %String, Output pStatus As %Integer, Output pAnswer As %DynamicObject, Output pHeaders) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ pTool _ "/read?" _ pQuery, pUser, ..PreparedPassword, .pStatus, .tBody, .pHeaders)
    If $$$ISERR(tSC) Quit tSC
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    } Catch {
        Set pAnswer = ""
    }
    Quit tSC
}

/// <p>The web-applications area's navigation entries as <var>pUser</var> is served them, as JSON, or
/// <code>""</code> when the map does not answer.</p>
Method ScreensFor(pUser As %String) As %String
{
    Set tScreens = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/navigation", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit ""
    Set tIterator = ##class(%DynamicObject).%FromJSON(tBody).areas.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tArea) {
        If tArea.key = "web-applications" Set tScreens = tArea.screens.%ToJSON()
    }
    Quit tScreens
}

/// <p>Run <class>OcuPilot.Test.MgmntDenialProbe</class> as <var>pUser</var> in a child process and
/// answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.MgmntDenialProbe).Run($Job, pUser)::10
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

/// <p>A probe leg as <code>http calls code failedPair</code>, for one-line comparisons; a leg that
/// counted no vendor calls leaves the count out.</p>
ClassMethod LegText(pProbe As %DynamicObject, pEndpoint As %String) As %String
{
    Set tLeg = pProbe.%Get(pEndpoint)
    If '$IsObject(tLeg) Quit "absent"
    Set tFault = tLeg.%Get("fault")
    Set tCode = ""
    Set tPair = ""
    If $IsObject(tFault) {
        Set tCode = tFault.%Get("code")
        If $IsObject(tFault.%Get("detail")) Set tPair = tFault.detail.%Get("failedPair")
    }
    Quit tLeg.http _ $Select(tLeg.%IsDefined("calls"): " calls=" _ tLeg.calls, 1: "") _ " " _ tCode _ " " _ tPair
}

/// <p>A principal holding both pairs reads the explorer and the document viewer in
/// <code>HSCUSTOM</code> with 200, and calling the port directly as that principal reaches the
/// vendor -- which is what makes the refused principal's zero calls a measurement of the gate.</p>
Method TestAPrincipalHoldingBothPairsReadsEitherScreen()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")
    Set tSC = ..Read(..#BOTHUSER, "webapp.restapis", "maxRows=1000&ns=HSCUSTOM", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the explorer request completes")
    Do $$$AssertEquals(tStatus, 200, "the explorer is read")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.rows) && (tAnswer.rows.%Size() > 0), "with rows")

    Set tSC = ..Read(..#BOTHUSER, "webapp.openapi", "application=%2Fapi%2Focupilot&maxRows=1000&ns=HSCUSTOM", .tStatus, .tAnswer, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the document request completes")
    Do $$$AssertEquals(tStatus, 200, "the document is read")
    Do $$$AssertTrue($IsObject(tAnswer) && $IsObject(tAnswer.rows) && (tAnswer.rows.%Size() > 0) && $IsObject(tAnswer.document), "with rows and the document")

    Set tProbe = ..ProbeAs(..#BOTHUSER)
    Do $$$AssertEquals(tProbe.%Get("error"), "", "the probe ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("username"), ..#BOTHUSER, "as the principal")
    Do $$$AssertEquals(..LegText(tProbe, "Applications"), "200 calls=2  ", "a direct explorer call reaches the vendor")
    Do $$$AssertEquals(..LegText(tProbe, "Document"), "200 calls=1  ", "and so does a direct document call")
    Do $$$AssertEquals(..LegText(tProbe, "Port"), "200  ", "and the production port answers the explorer read")
}

/// <p>A principal without <code>%Admin_Secure:USE</code> is refused 403 <code>AUTH.NOPRIVILEGE</code>
/// naming it by the route for both screens, and by the port called directly on both endpoints with
/// no vendor call made; the explorer and the viewer stay in the area's navigation entries, denied and
/// naming the pair. The route leg compares the route gate's own reason, so a refusal that only the
/// port's gate made reads red.</p>
/// <p>Mutation: drop <code>EvaluatePairs</code> from <method>OcuPilot.Port.MgmntPort.Invoke</method>
/// -&gt; the direct legs answer 200 with vendor calls; move it after the vendor call -&gt; they answer
/// 403 with calls above zero. Either goes red.</p>
Method TestAPrincipalWithoutAdminSecureIsRefusedByTheRouteAndByThePort()
{
    Do $$$AssertTrue(..PreparedSetupOk, "setup confirmed the principals' pairs")
    For tCase = $ListBuild("webapp.restapis", "maxRows=5&ns=HSCUSTOM"), $ListBuild("webapp.openapi", "application=%2Fapi%2Focupilot&maxRows=5&ns=HSCUSTOM") {
        Set tTool = $List(tCase, 1)
        Set tSC = ..Read(..#NOSECUREUSER, tTool, $List(tCase, 2), .tStatus, .tAnswer, .tHeaders)
        Do $$$AssertStatusOK(tSC, tTool _ ": the request completes")
        Do $$$AssertEquals(tStatus, 403, tTool _ ": the route refuses")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tTool _ ": as application/json")
        Set tPair = ""
        If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")) Set tPair = tAnswer.detail.failedPair
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code _ " " _ tAnswer.reason, 1: "") _ " " _ tPair, "AUTH.NOPRIVILEGE This account may not read that screen %Admin_Secure:USE", tTool _ ": the route's own gate refuses, naming the pair")
    }

    Set tScreens = ..ScreensFor(..#NOSECUREUSER)
    Do $$$AssertTrue(tScreens [ "{""route"":""web-applications/rest-apis"",""labelKey"":""restApiListLabel"",""sideBarPosition"":2,""allowed"":false,""failedPair"":""%Admin_Secure:USE""}", "the explorer stays listed in its area, denied and naming the pair: " _ tScreens)
    Do $$$AssertTrue(tScreens [ "{""route"":""web-applications/rest-apis/document"",""labelKey"":""openApiViewerLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Secure:USE""}", "and so does the viewer's route entry")

    Set tProbe = ..ProbeAs(..#NOSECUREUSER)
    Do $$$AssertEquals(tProbe.%Get("error"), "", "the probe ran: " _ tProbe.%ToJSON())
    Do $$$AssertEquals(tProbe.%Get("loggedIn"), 1, "the probe logged in")
    Do $$$AssertEquals(tProbe.%Get("username"), ..#NOSECUREUSER, "as the principal")
    Do $$$AssertEquals(..LegText(tProbe, "Applications"), "403 calls=0 AUTH.NOPRIVILEGE %Admin_Secure:USE", "a direct explorer call is refused by the port naming the pair, with no vendor call")
    Do $$$AssertEquals(..LegText(tProbe, "Document"), "403 calls=0 AUTH.NOPRIVILEGE %Admin_Secure:USE", "and so is a direct document call")
    Do $$$AssertEquals(..LegText(tProbe, "Port"), "403 AUTH.NOPRIVILEGE %Admin_Secure:USE", "and so is a call to the production port itself")
}

}
