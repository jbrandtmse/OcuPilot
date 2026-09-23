/// <p>The one smoke path (AD-45): the definition, on this instance, of <b>installed and
/// working</b>. CI runs it against a throwaway container and Epic 17's clean-clone run will run
/// the same class with the same assertions; the two differ only in what created the instance.
/// <file>scripts/smoke.sh</file> is the thin shell entry point that locates an instance, calls
/// this, prints what it returns and maps its verdict to an exit code.</p>
/// <p><b>The assertions live here, inside the instance, and that is what makes "the same script
/// with the same assertions" literally true.</b> AD-45 puts the smoke path under
/// <package>OcuPilot.Install</package>, which is an ObjectScript package; a shell script that
/// re-implemented the checks would be a second definition of installed-and-working, and the two
/// would drift. This class ships (it is in <code>OcuPilot.PKG</code>, not the test scope), so an
/// operator can ask a running instance the same question CI asks.</p>
/// <p><b>Zero executed checks is a failure, never a pass.</b> A check list that ran nothing --
/// every entry skipped, or the list empty -- reports <code>fail</code> and names the count. A
/// gate that reports "found nothing wrong" when it looked at nothing is the failure mode this
/// story exists to remove, so the counts are on every line of the verdict whether the run
/// passed or not.</p>
/// <p><b>Four outcomes, and only two of them count as executed.</b> <code>pass</code> and
/// <code>fail</code> are assertions this run actually made. <code>pending</code> is a check
/// that cannot be made yet and names the epic that makes it real -- it is reported so the list
/// is honest about its own coverage, and it never contributes to the verdict.
/// <code>skipped</code> is a check that does not apply to this instance (the demo fixtures when
/// <code>OCUPILOT_DEMO</code> was never set, sign-in when the caller supplied no credentials),
/// and it never contributes either. So a run in which everything was skipped executes nothing
/// and fails.</p>
/// <p><b>It uses <class>%Net.HttpRequest</class> directly.</b>
/// <class>OcuPilot.Test.Http</class> is the suite's over-the-wire client and is test-scope: it
/// does not ship, so this class cannot depend on it.</p>
/// <p><b>It never <code>Write</code>s</b> (AD-12). The report comes back as one string and the
/// caller prints it.</p>
Class OcuPilot.Install.Smoke Extends %RegisteredObject
{

/// <p>Last-resort port, used only when the instance's own configured web-server port cannot be
/// read. The vendor default rather than this repository's host-side mapping: this class runs
/// <b>inside</b> the instance, where the host mapping does not exist.</p>
Parameter DEFAULTPORT As %Integer = 52773;

/// <p>How long one check waits for an answer, in seconds. A connection a host accepts and never
/// answers is the shape DW-167 names on the client; here it would hang the whole smoke run, so
/// every request carries a timeout and a request that runs out is a <code>fail</code> naming the
/// check, not a hang.</p>
Parameter REQUESTTIMEOUT As %Integer = 20;

/// <p>The tool identifier of the web applications list, whose screen read the
/// <code>webapplications</code> check issues.</p>
Parameter WEBAPPLISTTOOL = "webapp.list";

/// <p>The write tool the <code>agentwrite</code> and <code>auditmarker</code> checks drive
/// (AD-45): the one shipped write, aimed at AD-25's own demo fixture.</p>
Parameter WEBAPPUPDATETOOL = "webapp.list.update";

/// <p>The resource that write grants: setting one where none was set, the one authorization
/// change AD-10 permits, and the change UJ-3 itself makes.</p>
Parameter WRITERESOURCE = "%Development";

/// <p>The limits class the mint and the turn row are bounded by, the same one the API uses.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The tool identifier of the users list, whose screen read the <code>users</code> check
/// issues.</p>
Parameter USERLISTTOOL = "permissions.users";

/// <p>The tool identifier of the SSL/TLS configurations list, whose screen read the
/// <code>ssl</code> check issues.</p>
Parameter SSLLISTTOOL = "security.ssl";

/// <p>The tool identifier of the task schedule, whose screen read the <code>tasks</code> check
/// issues.</p>
Parameter TASKLISTTOOL = "tasks.schedule";

/// <p>The tool identifier of the processes list, whose screen read the <code>processes</code> check
/// issues.</p>
Parameter PROCESSLISTTOOL = "osmgmt.processes";

/// <p>The tool identifier of the audit database viewer, whose screen read the <code>audit</code>
/// check issues.</p>
Parameter AUDITLISTTOOL = "logs.audit";

/// <p>The tool identifier of the REST API explorer, whose screen read the
/// <code>webapp.restapis</code> check issues.</p>
Parameter RESTAPILISTTOOL = "webapp.restapis";

/// <p>The tool identifier of the roles list, whose screen read the <code>roles</code> check
/// issues.</p>
Parameter ROLELISTTOOL = "permissions.roles";

/// <p>The tool identifier of the resources list, whose screen read the <code>resources</code> check
/// issues.</p>
Parameter RESOURCELISTTOOL = "permissions.resources";

/// <p>The tool identifier of the services list, whose screen read the <code>services</code> check
/// issues.</p>
Parameter SERVICELISTTOOL = "permissions.services";

/// <p>The tool identifier of the X.509 credentials list, whose screen read the <code>x509</code>
/// check issues.</p>
Parameter X509LISTTOOL = "security.x509";

/// <p>The tool identifier of the LDAP / Kerberos configurations list, whose screen read the
/// <code>ldap</code> check issues.</p>
Parameter LDAPLISTTOOL = "security.ldap";

/// <p>The tool identifier of the Wallet list, whose screen read the <code>wallet</code> check
/// issues.</p>
Parameter WALLETLISTTOOL = "security.wallet";

/// <p>The tool identifier of the OAuth 2.0 screen's Client server descriptions tab, whose screen read
/// the <code>oauthdescriptions</code> check issues.</p>
Parameter OAUTHDESCRIPTIONSTOOL = "security.oauthserverdescriptions";

/// <p>The tool identifier of the OAuth 2.0 Client configurations tab, whose screen read the
/// <code>oauthclients</code> check issues.</p>
Parameter OAUTHCLIENTSTOOL = "security.oauthclients";

/// <p>The tool identifier of the OAuth 2.0 Resource servers tab, whose screen read the
/// <code>oauthresourceservers</code> check issues.</p>
Parameter OAUTHRESOURCESERVERSTOOL = "security.oauthresourceservers";

/// <p>The tool identifier of the OAuth 2.0 Authorization server tab, whose screen read the
/// <code>oauthserver</code> check issues.</p>
Parameter OAUTHSERVERTOOL = "security.oauthserver";

/// <p>The tool identifier of the OAuth 2.0 Server client descriptions tab, whose screen read the
/// <code>oauthserverclients</code> check issues.</p>
Parameter OAUTHSERVERCLIENTSTOOL = "security.oauthserverclients";

/// <p>The tool identifier of the On-demand tasks list, whose screen read the <code>ondemand</code>
/// check issues.</p>
Parameter TASKONDEMANDTOOL = "tasks.ondemand";

/// <p>The tool identifier of the Upcoming tasks list, whose screen read the <code>upcoming</code>
/// check issues.</p>
Parameter TASKUPCOMINGTOOL = "tasks.upcoming";

/// <p>The tool identifier of Task history (all tasks), whose screen read the
/// <code>taskhistory</code> check issues (Story 6.6).</p>
Parameter TASKHISTORYTOOL = "tasks.history";

/// <p>The tool identifier of Task details, whose screen read the <code>taskdetails</code> check
/// issues, keyed by the task schedule's own first row (Story 6.7).</p>
Parameter TASKDETAILSTOOL = "tasks.taskdetails";

/// <p>The tool identifier of Process details, whose screen read the <code>processdetails</code>
/// check issues, keyed by the processes list's own first row (Story 6.8).</p>
Parameter PROCESSDETAILSTOOL = "osmgmt.processdetails";

/// <p>The tool identifier of System usage, read generically by <method>CheckAreaLists</method>
/// like any other single-object list, since it needs no parent id (Story 6.9).</p>
Parameter SYSTEMUSAGETOOL = "osmgmt.systemusage";

/// <p>The tool identifier of the Locks list, read generically by <method>CheckAreaLists</method>
/// like any other list (Story 6.10). The check expects the same exactly-one-row shape at
/// <code>maxRows=1</code> as <code>processes</code> and <code>systemusage</code>, not the
/// zero-or-one shape a possibly-empty list takes, because the locks an idle instance holds are its
/// own daemons' -- the license monitor's, the system monitor's, the task manager's and the work
/// queue's (observed: seven rows, all daemon-held, on the slot B instance, 2026-09-17). That is an
/// observation about this build, not a guarantee: a run that finds the table empty fails here, and
/// such a failure is environmental rather than a defect in the screen.</p>
Parameter LOCKLISTTOOL = "osmgmt.locks";

/// <p>The tool identifier of the Databases General view, read generically by
/// <method>CheckAreaLists</method> like any other unparented list (Story 6.11): the vendor's own
/// database directory table, never empty on any mounted instance.</p>
Parameter DATABASELISTTOOL = "osmgmt.databases";

/// <p>The tool identifier of the Databases Free-space view, read generically by
/// <method>CheckAreaLists</method> (Story 6.11): the same rows as <parameter>DATABASELISTTOOL</parameter>,
/// merged with the asynchronous <code>INFO</code> figures. Its declared read takes no criterion, so
/// it fits the generic sweep exactly as the General view does.</p>
Parameter DATABASEFREESPACELISTTOOL = "osmgmt.databasefreespace";

/// <p>The tool identifier of Database details, whose <code>CheckDatabaseDetails</code> check issues
/// it keyed by the Databases list's own first row's <code>Directory</code> (Story 6.11).</p>
Parameter DATABASEDETAILSTOOL = "osmgmt.databasedetails";

/// <p>The tool identifier of Database volumes ("Volume files"), whose <code>CheckDatabaseDetails</code>
/// check issues it keyed by the same <code>Directory</code> (Story 6.11). It is not in
/// <method>CheckAreaLists</method>'s generic name list: <code>Database.SysCRUD</code>'s own
/// <code>ValidateQueryParams</code> requires <code>dir</code> for every request type but
/// <code>POST</code> and <code>LIST</code> (verified against the instance: a <code>VOLUMELIST</code>
/// with no <code>dir</code> answers 400 <code>PORT.VALIDATION</code>), so this parent-scoped read
/// needs a real directory the same way <parameter>PROCESSDETAILSTOOL</parameter> needs a real pid.</p>
Parameter DATABASEVOLUMESTOOL = "osmgmt.databasevolumes";

/// <p>The tool identifier of the Devices list, read generically by
/// <method>CheckAreaLists</method> like any other unparented list (Story 6.12): the vendor's own
/// device table, never empty on any mounted instance.</p>
Parameter DEVICELISTTOOL = "osmgmt.devices";

/// <p>The tool identifier of the alerts.log viewer, read generically by
/// <method>CheckAreaLists</method> (Story 6.13). Its declared read is a bounded tail of a file the
/// instance writes only when it has something to say, so it is a <b>zero-or-one</b> list: an
/// instance whose alerts.log is still empty answers no row without anything being wrong.</p>
Parameter ALERTLISTTOOL = "logs.alerts";

/// <p>The tool identifier of the messages.log viewer, read generically by
/// <method>CheckAreaLists</method> (Story 6.14). Unlike <parameter>ALERTLISTTOOL</parameter> this is
/// an <b>exactly-one</b> list: every instance writes its own startup lines to
/// <file>messages.log</file>, so an empty answer here is a real failure. Distinct from the
/// <code>messageslog</code> check, which reads the same file through the page route
/// (<parameter>MESSAGESLOGPATH</parameter>) rather than through the screen's declared read.</p>
Parameter MESSAGESLISTTOOL = "logs.messages";

/// <p>The console-log page's path under the API application, and the window the
/// <code>messageslog</code> check asks for. Small: the check is that the endpoint serves the
/// instance's own log, not that it serves much of it.</p>
Parameter MESSAGESLOGPATH = "/logs/messages?maxBytes=4096";

/// <p>The application error log's namespaces level, under the API application, and what the
/// <code>applicationerrors</code> check asks for. The first drill level, because it is the one
/// that names no namespace and no date of its own: every level below it is reached by drilling
/// through the instance's own answers, and a smoke check that invented one would be asserting
/// against a namespace this instance may not record errors for.</p>
Parameter APPLICATIONERRORSPATH = "/logs/errors/namespaces";

/// <p>Run the smoke checks against this instance and report.</p>
/// <p><var>pUsername</var> and <var>pPassword</var> are the credentials the sign-in check mints
/// a token pair with; supplying none skips that check, the reads that need its token and
/// the sign-out that ends it, which is honest rather than silently green. <var>pReport</var> comes back as one
/// <code>$Char(10)</code>-separated block: one line per check, then the pending list, then the
/// counts. Returns <b>1</b> when the run passed -- at least one check executed and none
/// failed -- and 0 otherwise.</p>
ClassMethod Run(pUsername As %String = "", pPassword As %String = "", pDemo As %String = "", Output pReport As %String, Output pCounts As %String) As %Boolean
{
    Set pReport = ""
    Set pCounts = ""
    Kill tChecks
    Set tOrigin = "http://" _ ..Host() _ ":" _ ..Port()
    Set tAccessToken = ""
    Set tRefreshToken = ""
    Try {
        Do ..CheckReadiness(.tChecks)
        Do ..CheckShell(.tChecks)
        Do ..CheckDeepLink(.tChecks)
        Do ..CheckSignIn(.tChecks, pUsername, pPassword, .tAccessToken, .tRefreshToken)
        Do ..CheckApiReads(.tChecks, tAccessToken)
        Do ..CheckAreaLists(.tChecks, tAccessToken, pDemo)
        Do ..CheckTaskDetails(.tChecks, tAccessToken)
        Do ..CheckProcessDetails(.tChecks, tAccessToken)
        Do ..CheckDatabaseDetails(.tChecks, tAccessToken)
        Do ..CheckMessagesLog(.tChecks, tAccessToken)
        Do ..CheckApplicationErrors(.tChecks, tAccessToken)
        Do ..CheckScreenAction(.tChecks, tAccessToken, pDemo)
    } Catch ex {
        Do ..Note(.tChecks, "smoke", "fail", "the smoke run raised " _ ex.DisplayString())
    }
    ; Its own frame, so the pair sign-in minted is signed out whatever the reads did.
    Try {
        Do ..CheckSignOut(.tChecks, tAccessToken, tRefreshToken)
    } Catch ex {
        Do ..Note(.tChecks, "sign-out", "fail", "the sign-out check raised " _ ex.DisplayString())
    }
    Try {
        Do ..CheckAuditEvent(.tChecks)
        Do ..CheckAgentSwitches(.tChecks)
        Do ..CheckDemoFixture(.tChecks, pDemo)
        Do ..CheckAgentWrite(.tChecks, pDemo)
        Do ..CheckAgentDelete(.tChecks, pDemo)
    } Catch ex {
        Do ..Note(.tChecks, "smoke", "fail", "the smoke run raised " _ ex.DisplayString())
    }
    Quit ..Render(.tChecks, tOrigin, .pReport, .pCounts)
}

/// <p>The host every check addresses. Always the loopback interface: this class runs inside the
/// instance it is asking about, and a smoke run that could be pointed at another host would be
/// answering for the wrong one.</p>
ClassMethod Host() As %String
{
    Quit "localhost"
}

/// <p>The instance's own configured web-server port, falling back to
/// <parameter>DEFAULTPORT</parameter> when it cannot be read. Switches to <code>%SYS</code> and
/// restores (AD-16), restoring first on the error path.</p>
ClassMethod Port() As %Integer
{
    Set tPort = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Config.Startup).Get(.tProps)
        If $$$ISOK(tSC) Set tPort = $Get(tProps("WebServerPort"))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tPort = ""
    }
    If +tPort > 0 Quit +tPort
    Quit ..#DEFAULTPORT
}

/// <p>Append one check outcome. <var>pOutcome</var> is <code>pass</code>, <code>fail</code>,
/// <code>pending</code> or <code>skipped</code>; <var>pReason</var> is what a reader needs to
/// act on it, and is required on every outcome but <code>pass</code>.</p>
/// <p><b>Public, not <code>[ Private ]</code></b> -- the same documented deviation
/// <method>OcuPilot.Install.Installer.WantFromRoster</method> carries, and for the same reason:
/// <class>OcuPilot.Test.Smoke</class> builds synthetic check sets with it, so the verdict rule
/// below is asserted against sets a real instance cannot be put into -- an empty one, and one
/// in which every check was skipped. It is not a second entry point: it installs nothing,
/// checks nothing and reads nothing.</p>
ClassMethod Note(ByRef pChecks, pName As %String, pOutcome As %String, pReason As %String = "")
{
    Set tN = $Increment(pChecks)
    Set pChecks(tN, "name") = pName
    Set pChecks(tN, "outcome") = pOutcome
    Set pChecks(tN, "reason") = pReason
}

/// <p>Issue one HTTP request from the instance to itself and report status, body and one named
/// response header. Returns a failing <code>%Status</code> only for a transport failure -- any
/// HTTP status at all is an answer and comes back through <var>pStatus</var>.</p>
ClassMethod Request(pMethod As %String, pPath As %String, pAuthorization As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pStatus = 0
    Set pText = ""
    Try {
        Set tReq = ##class(%Net.HttpRequest).%New()
        Set tReq.Server = ..Host()
        Set tReq.Port = ..Port()
        Set tReq.Timeout = ..#REQUESTTIMEOUT
        If pAuthorization '= "" {
            Set tSC = tReq.SetHeader("Authorization", pAuthorization)
            If $$$ISERR(tSC) Quit
        }
        If pBody '= "" {
            Set tReq.ContentType = "application/json"
            Do tReq.EntityBody.Write(pBody)
        }
        If pMethod = "GET" {
            Set tSC = tReq.Get(pPath)
        } ElseIf pMethod = "POST" {
            Set tSC = tReq.Post(pPath)
        } Else {
            Set tSC = $$$ERROR($$$GeneralError, "unsupported method " _ pMethod)
        }
        If $$$ISERR(tSC) Quit
        Set pStatus = tReq.HttpResponse.StatusCode
        Set tData = tReq.HttpResponse.Data
        If $IsObject(tData) {
            Do tData.Rewind()
            While 'tData.AtEnd {
                Set pText = pText _ tData.Read(32000)
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The readiness endpoint, over real HTTP, as an <b>anonymous</b> caller -- no credentials
/// at all, which is what a monitor outside the instance has. The trailing slash is IRIS's own
/// rule for a REST web application (see <class>OcuPilot.Api.Readiness</class>).</p>
ClassMethod CheckReadiness(ByRef pChecks) [ Private ]
{
    ; A roster this instance cannot read is its own failure, named as one. Without this the
    ; request went to "" and the report blamed whatever HTTP status the instance root returned --
    ; a misleading answer to a question that was never asked.
    Set tPath = ..ReadinessPath()
    If tPath = "" {
        Do ..Note(.pChecks, "readiness", "fail", "the roster on this instance declares no readiness path, so there was nothing to ask")
        Quit
    }
    Set tSC = ..Request("GET", tPath, "", "", .tStatus, .tText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "readiness", "fail", "the readiness endpoint could not be reached: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If tStatus '= 200 {
        Do ..Note(.pChecks, "readiness", "fail", "the readiness endpoint answered HTTP " _ tStatus _ " to an anonymous caller")
        Quit
    }
    Set tState = ""
    Set tInstalled = 0
    Try {
        Set tObj = ##class(%DynamicAbstractObject).%FromJSON(tText)
        Set tState = tObj.state
        Set tInstalled = ''tObj.installed
    } Catch {
        Set tState = ""
    }
    If tState = "" {
        Do ..Note(.pChecks, "readiness", "fail", "the readiness endpoint answered 200 with a body carrying no state")
        Quit
    }
    If (tState '= "installed") || 'tInstalled {
        Do ..Note(.pChecks, "readiness", "fail", "readiness reports state '" _ tState _ "', so OcuPilot is not installed on this instance")
        Quit
    }
    Do ..Note(.pChecks, "readiness", "pass")
}

/// <p>The readiness endpoint's path, derived from the roster rather than spelled here, so a
/// path change is one roster edit (DW-192). Falls back to nothing readable rather than to a
/// guessed literal: a smoke run that cannot find the declared path says so.</p>
ClassMethod ReadinessPath() As %String
{
    Set tPath = ..RosterPath("readiness")
    If tPath = "" Quit ""
    Quit tPath _ "/"
}

/// <p>The path the roster declares for application <var>pKey</var>, or <code>""</code>.</p>
ClassMethod RosterPath(pKey As %String) As %String
{
    Set tPath = ""
    Try {
        Set tSC = ##class(OcuPilot.Install.Roster).Application(pKey, .tApp)
        If $$$ISOK(tSC) Set tPath = tApp.path
    } Catch {
        Set tPath = ""
    }
    Quit tPath
}

/// <p>The shell application's root, served anonymously. A 503 carrying
/// <code>STATIC.NOBUNDLE</code> is a <b>fail</b>, not a skip: an instance with no client bundle
/// is installed but not working, which is exactly the distinction this script exists to
/// make.</p>
ClassMethod CheckShell(ByRef pChecks) [ Private ]
{
    Set tShell = ..RosterPath("shell")
    If tShell = "" {
        Do ..Note(.pChecks, "shell", "fail", "the roster on this instance declares no shell path, so there was nothing to ask")
        Quit
    }
    Set tRoot = tShell _ "/"
    Set tSC = ..Request("GET", tRoot, "", "", .tStatus, .tText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "shell", "fail", "the shell could not be reached: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If tStatus '= 200 {
        Do ..Note(.pChecks, "shell", "fail", "the shell answered HTTP " _ tStatus _ " at " _ tRoot _ $Select(tText [ "STATIC.NOBUNDLE": " -- no built client bundle is installed", 1: ""))
        Quit
    }
    If tText '[ "<base href=" {
        Do ..Note(.pChecks, "shell", "fail", "the shell answered 200 with a document that declares no base href")
        Quit
    }
    Do ..Note(.pChecks, "shell", "pass")
}

/// <p>A deep link into the shell: a client route no file exists for must answer the shell's own
/// document, which is what makes a pasted or reloaded URL work.</p>
ClassMethod CheckDeepLink(ByRef pChecks) [ Private ]
{
    ; The same guard CheckReadiness and CheckShell carry, and for the same reason: an
    ; unreadable roster leaves the base "" and the request goes to /namespaces at the instance
    ; root, where the report blames whatever answered for a question that was never asked.
    Set tShell = ..RosterPath("shell")
    If tShell = "" {
        Do ..Note(.pChecks, "deeplink", "fail", "the roster on this instance declares no shell path, so there was nothing to ask")
        Quit
    }
    Set tPath = tShell _ "/namespaces"
    Set tSC = ..Request("GET", tPath, "", "", .tStatus, .tText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "deeplink", "fail", "the deep link could not be reached: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If (tStatus '= 200) || (tText '[ "<base href=") {
        Do ..Note(.pChecks, "deeplink", "fail", "the deep link " _ tPath _ " answered HTTP " _ tStatus _ " rather than the shell document")
        Quit
    }
    Do ..Note(.pChecks, "deeplink", "pass")
}

/// <p>Sign in and mint a token pair against the API application's own token endpoint.
/// <var>pAccessToken</var> is what the reads below carry and <var>pRefreshToken</var> is
/// what <method>CheckSignOut</method> proves dead; with no credentials supplied this is skipped
/// and so are they.</p>
ClassMethod CheckSignIn(ByRef pChecks, pUsername As %String, pPassword As %String, Output pAccessToken As %String, Output pRefreshToken As %String) [ Private ]
{
    Set pAccessToken = ""
    Set pRefreshToken = ""
    If pUsername = "" {
        Do ..Note(.pChecks, "signin", "skipped", "no credentials were supplied to this run, so no token pair was minted and the API reads below were not attempted")
        Quit
    }
    Set tApi = ..RosterPath("api")
    If tApi = "" {
        Do ..Note(.pChecks, "signin", "fail", "the roster on this instance declares no API path, so there was nothing to sign in to")
        Quit
    }
    Set tBody = {}
    Do tBody.%Set("user", pUsername)
    Do tBody.%Set("password", pPassword)
    Set tSC = ..Request("POST", tApi _ "/login", "", tBody.%ToJSON(), .tStatus, .tText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "signin", "fail", "the token endpoint could not be reached: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If tStatus '= 200 {
        Do ..Note(.pChecks, "signin", "fail", "signing in as '" _ pUsername _ "' answered HTTP " _ tStatus)
        Quit
    }
    Try {
        Set tObj = ##class(%DynamicAbstractObject).%FromJSON(tText)
        Set pAccessToken = tObj."access_token"
        Set tRefresh = tObj."refresh_token"
    } Catch {
        Set pAccessToken = ""
        Set tRefresh = ""
    }
    If (pAccessToken = "") || ($Get(tRefresh) = "") {
        Set pAccessToken = ""
        Do ..Note(.pChecks, "signin", "fail", "signing in answered 200 without both halves of a token pair")
        Quit
    }
    Set pRefreshToken = tRefresh
    Do ..Note(.pChecks, "signin", "pass")
}

/// <p>Sign out the pair <method>CheckSignIn</method> minted, so a smoke run leaves no live
/// session behind: a Bearer-only <code>POST /logout</code>, which ends that session alone, then
/// a <code>POST /refresh</code> with the minted refresh token in the body, which must be refused
/// with 401. A refresh that is accepted is signed out too before the check fails; any other
/// answer fails the check, since it shows no refusal. Skipped when no pair
/// was minted.</p>
ClassMethod CheckSignOut(ByRef pChecks, pAccessToken As %String, pRefreshToken As %String) [ Private ]
{
    If (pAccessToken = "") || (pRefreshToken = "") {
        Do ..Note(.pChecks, "sign-out", "skipped", "no token pair was minted by this run, so there was nothing to sign out")
        Quit
    }
    Set tApi = ..RosterPath("api")
    If tApi = "" {
        Do ..Note(.pChecks, "sign-out", "fail", "the roster on this instance declares no API path, so the minted pair could not be signed out")
        Quit
    }
    Set tSC = ..Request("POST", tApi _ "/logout", "Bearer " _ pAccessToken, "", .tStatus, .tText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "sign-out", "fail", "the logout endpoint could not be reached: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If tStatus '= 200 {
        Do ..Note(.pChecks, "sign-out", "fail", "signing out answered HTTP " _ tStatus)
        Quit
    }
    Set tBody = {}
    Do tBody.%Set("refresh_token", pRefreshToken)
    Set tSC = ..Request("POST", tApi _ "/refresh", "", tBody.%ToJSON(), .tRefreshStatus, .tRefreshText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "sign-out", "fail", "the refresh endpoint could not be reached to confirm the sign-out: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If tRefreshStatus = 200 {
        Set tNewAccess = ""
        Try {
            Set tNewAccess = ##class(%DynamicAbstractObject).%FromJSON(tRefreshText)."access_token"
        } Catch {
            Set tNewAccess = ""
        }
        If tNewAccess '= "" Do ..Request("POST", tApi _ "/logout", "Bearer " _ tNewAccess, "", .tStatus2, .tText2)
        Do ..Note(.pChecks, "sign-out", "fail", "the refresh token minted by sign-in was still accepted after signing out")
        Quit
    }
    If tRefreshStatus '= 401 {
        Do ..Note(.pChecks, "sign-out", "fail", "the refresh after signing out answered HTTP " _ tRefreshStatus _ ", not the 401 that refuses a dead refresh token")
        Quit
    }
    Do ..Note(.pChecks, "sign-out", "pass")
}

/// <p>The three shell reads every screen depends on, each with the minted access token: the
/// instance identity, the namespace roster and the navigation map.</p>
ClassMethod CheckApiReads(ByRef pChecks, pAccessToken As %String) [ Private ]
{
    Set tBase = ..RosterPath("api")
    If tBase = "" {
        For tI = 1:1:3 {
            Do ..Note(.pChecks, $Piece("instance,namespaces,navigation", ",", tI), "fail", "the roster on this instance declares no API path, so there was nothing to read")
        }
        Quit
    }
    For tI = 1:1:3 {
        Set tName = $Piece("instance,namespaces,navigation", ",", tI)
        If pAccessToken = "" {
            Do ..Note(.pChecks, tName, "skipped", "no token pair was minted by this run, so the authenticated read was not attempted")
            Continue
        }
        Set tSC = ..Request("GET", tBase _ "/" _ tName, "Bearer " _ pAccessToken, "", .tStatus, .tText)
        If $$$ISERR(tSC) {
            Do ..Note(.pChecks, tName, "fail", "the read could not be reached: " _ $System.Status.GetErrorText(tSC))
            Continue
        }
        If tStatus '= 200 {
            Do ..Note(.pChecks, tName, "fail", "GET " _ tBase _ "/" _ tName _ " answered HTTP " _ tStatus)
            Continue
        }
        If $Extract($ZStrip(tText, "<W")) '= "{" {
            Do ..Note(.pChecks, tName, "fail", "GET " _ tBase _ "/" _ tName _ " answered 200 with a body that is not a JSON object")
            Continue
        }
        Do ..Note(.pChecks, tName, "pass")
    }
}

/// <p>One live read for each built list screen (AD-45 asks for at least one per area), read with the
/// minted access token: the web applications list (<code>webapplications</code>), the users list
/// (<code>users</code>), the SSL/TLS configurations list (<code>ssl</code>), the task schedule
/// (<code>tasks</code>), the processes list (<code>processes</code>), the audit database viewer
/// (<code>audit</code>), the REST API explorer (<code>webapp.restapis</code>), the roles, resources
/// and services lists (<code>roles</code>, <code>resources</code>, <code>services</code>), and the
/// X.509, LDAP / Kerberos and Wallet lists (<code>x509</code>, <code>ldap</code>,
/// <code>wallet</code>), each one screen read at <code>maxRows=1</code> that answers 200 with a
/// <code>rows</code> array of exactly one row. The signed-in principal needs each list's pairs --
/// <code>%DB_IRISSYS:READ</code> throughout, with <code>%Admin_Secure:USE</code> for the first three,
/// <code>%Admin_Task:USE</code> for the fourth, <code>%Admin_Operate:USE</code> plus
/// <code>%Admin_Manage:USE</code> for the fifth, and <code>%Admin_Secure:USE</code> plus
/// <code>%Admin_Operate:USE</code> for the sixth, <code>%Admin_Secure:USE</code> for the seventh
/// through the twelfth, and <code>%Admin_Wallet:USE</code> for the thirteenth -- or the read answers
/// 403 and the check fails. Skipped, like the shell reads, when no token was minted.</p>
/// <p><b>The five OAuth 2.0 tabs</b> (<code>oauthdescriptions</code>, <code>oauthclients</code>,
/// <code>oauthresourceservers</code>, <code>oauthserver</code>, <code>oauthserverclients</code>) read
/// the same way and pass on a 200 answering zero rows or one: no fixture creates OAuth 2.0 objects
/// (AD-25), so an instance may hold none. They need <code>%Admin_OAuth2_Client:USE</code> for the
/// first two, <code>%Admin_Secure:USE</code> for the third, <code>%Admin_OAuth2_Server:USE</code> for
/// the fourth and <code>%Admin_OAuth2_Registration:USE</code> for the fifth, each with
/// <code>%DB_IRISSYS:READ</code>.</p>
/// <p><b>The On-demand and Upcoming tasks lists</b> (<code>ondemand</code>, <code>upcoming</code>) read
/// the same way at <code>maxRows=1</code>, needing the task schedule's pairs, and expect exactly one
/// row: the vendor answers every task as on demand, and several stock system tasks run within any
/// 24 hours, so both hold one on a clean container. Upcoming is read with no horizon, which the vendor
/// answers as 24 hours.</p>
/// <p><b>Task history</b> (<code>taskhistory</code>) reads the same way at <code>maxRows=1</code>
/// with no criteria, needing the task schedule's pairs, and passes on zero or one row like the OAuth
/// 2.0 checks: a fresh container may hold no run history yet, so an empty answer is not a
/// failure.</p>
/// <p><b>The X.509 and Wallet lists hold a row only where the demo fixture put one</b> (AD-25), so
/// when the demo was not requested (<var>pDemo</var>, resolved as
/// <method>CheckDemoFixture</method> resolves it) a 200 answering an empty <code>rows</code> array
/// skips those two checks rather than failing them. With the demo requested, an empty array fails
/// them as it fails every other list.</p>
/// <p>The audit read is the one that crosses the port's async path (AD-26), so it is also the
/// check that says the self-queued LIST is polled to an answer on a live instance.</p>
/// <p><b>System usage</b> (<code>systemusage</code>, Story 6.9) reads the same way at
/// <code>maxRows=1</code> with no criteria and expects exactly one row, like
/// <code>processes</code>: the vendor's <code>Monitor</code> endpoint always answers, so an
/// instance with no row is a real failure, not an empty-fixture case.</p>
/// <p><b>Locks</b> (<code>locks</code>, Story 6.10) reads the same way at <code>maxRows=1</code>
/// with no criteria and expects exactly one row, like <code>processes</code> and
/// <code>systemusage</code>, because an idle instance's locks are its own daemons';
/// <parameter>LOCKLISTTOOL</parameter> records what was observed and how to read a failure.</p>
/// <p><b>messages.log</b> (<code>messages</code>, Story 6.14) reads the same way at
/// <code>maxRows=1</code> and expects exactly one row, for
/// <parameter>MESSAGESLISTTOOL</parameter>'s reason: every instance writes its own startup lines to
/// that file, so unlike <code>alerts</code> it is not a zero-or-one list.</p>
ClassMethod CheckAreaLists(ByRef pChecks, pAccessToken As %String, pDemo As %String = "") [ Private ]
{
    Set tDemoWanted = ($Select(pDemo '= "": pDemo, 1: $System.Util.GetEnviron("OCUPILOT_DEMO")) = "1")
    Set tBase = ..RosterPath("api")
    For tI = 1:1:28 {
        Set tName = $Piece("webapplications,users,ssl,tasks,processes,audit,webapp.restapis,roles,resources,services,x509,ldap,wallet,oauthdescriptions,oauthclients,oauthresourceservers,oauthserver,oauthserverclients,ondemand,upcoming,taskhistory,systemusage,locks,databases,databasefreespace,devices,alerts,messages", ",", tI)
        ; Every index names its own tool and the last arm names none: a list added to the bound and
        ; the name list without its own arm reads an empty path and fails, rather than re-reading
        ; the previous list under the new name and passing.
        Set tTool = $Select(tI = 1: ..#WEBAPPLISTTOOL, tI = 2: ..#USERLISTTOOL, tI = 3: ..#SSLLISTTOOL, tI = 4: ..#TASKLISTTOOL, tI = 5: ..#PROCESSLISTTOOL, tI = 6: ..#AUDITLISTTOOL, tI = 7: ..#RESTAPILISTTOOL, tI = 8: ..#ROLELISTTOOL, tI = 9: ..#RESOURCELISTTOOL, tI = 10: ..#SERVICELISTTOOL, tI = 11: ..#X509LISTTOOL, tI = 12: ..#LDAPLISTTOOL, tI = 13: ..#WALLETLISTTOOL, tI = 14: ..#OAUTHDESCRIPTIONSTOOL, tI = 15: ..#OAUTHCLIENTSTOOL, tI = 16: ..#OAUTHRESOURCESERVERSTOOL, tI = 17: ..#OAUTHSERVERTOOL, tI = 18: ..#OAUTHSERVERCLIENTSTOOL, tI = 19: ..#TASKONDEMANDTOOL, tI = 20: ..#TASKUPCOMINGTOOL, tI = 21: ..#TASKHISTORYTOOL, tI = 22: ..#SYSTEMUSAGETOOL, tI = 23: ..#LOCKLISTTOOL, tI = 24: ..#DATABASELISTTOOL, tI = 25: ..#DATABASEFREESPACELISTTOOL, tI = 26: ..#DEVICELISTTOOL, tI = 27: ..#ALERTLISTTOOL, tI = 28: ..#MESSAGESLISTTOOL, 1: "")
        If tBase = "" {
            Do ..Note(.pChecks, tName, "fail", "the roster on this instance declares no API path, so there was nothing to read")
            Continue
        }
        If pAccessToken = "" {
            Do ..Note(.pChecks, tName, "skipped", "no token pair was minted by this run, so the authenticated read was not attempted")
            Continue
        }
        Set tPath = tBase _ "/screens/" _ tTool _ "/read?maxRows=1"
        Set tSC = ..Request("GET", tPath, "Bearer " _ pAccessToken, "", .tStatus, .tText)
        If $$$ISERR(tSC) {
            Do ..Note(.pChecks, tName, "fail", "the read could not be reached: " _ $System.Status.GetErrorText(tSC))
            Continue
        }
        If tStatus '= 200 {
            Do ..Note(.pChecks, tName, "fail", "GET " _ tPath _ " answered HTTP " _ tStatus)
            Continue
        }
        Set tCount = -1
        Try {
            Set tRows = ##class(%DynamicAbstractObject).%FromJSON(tText).%Get("rows")
            If $IsObject(tRows) && tRows.%IsA("%Library.DynamicArray") Set tCount = tRows.%Size()
        } Catch {
            Set tCount = -1
        }
        If (tCount = 0) && 'tDemoWanted && ((tName = "x509") || (tName = "wallet")) {
            Do ..Note(.pChecks, tName, "skipped", "the list is empty and the demo opt-in flag is not set for this instance, so no demo fixture row was expected (AD-25)")
            Continue
        }
        Set tZeroOrOne = ''$ListFind($ListBuild("oauthdescriptions", "oauthclients", "oauthresourceservers", "oauthserver", "oauthserverclients", "taskhistory", "alerts"), tName)
        If tZeroOrOne && ((tCount = 0) || (tCount = 1)) {
            Do ..Note(.pChecks, tName, "pass")
            Continue
        }
        If tZeroOrOne {
            Do ..Note(.pChecks, tName, "fail", "GET " _ tPath _ " answered 200 without a rows array of zero rows or one")
            Continue
        }
        If tCount '= 1 {
            Do ..Note(.pChecks, tName, "fail", "GET " _ tPath _ " answered 200 without a rows array of exactly one row")
            Continue
        }
        Do ..Note(.pChecks, tName, "pass")
    }
}

/// <p>Task details (<code>taskdetails</code>, Story 6.7): the task schedule's own first row supplies
/// the <code>taskId</code> its parent-scoped read requires, so this check reads
/// <parameter>TASKLISTTOOL</parameter> again at <code>maxRows=1</code> to find one, needing the
/// same pairs <code>tasks</code> already checked, and then reads
/// <parameter>TASKDETAILSTOOL</parameter> for that id, expecting exactly one row that names that
/// <code>Id</code> and carries the task's own <code>TimePeriod</code>. Skipped, like
/// <method>CheckMessagesLog</method>, when no token was minted; failed, naming why, when the
/// schedule read answers no row to key the second read by -- a fresh container without even the
/// stock system tasks is not one this check can pass on, unlike the zero-or-one lists above.</p>
ClassMethod CheckTaskDetails(ByRef pChecks, pAccessToken As %String) [ Private ]
{
    Set tBase = ..RosterPath("api")
    If tBase = "" {
        Do ..Note(.pChecks, "taskdetails", "fail", "the roster on this instance declares no API path, so there was nothing to read")
        Quit
    }
    If pAccessToken = "" {
        Do ..Note(.pChecks, "taskdetails", "skipped", "no token pair was minted by this run, so the authenticated read was not attempted")
        Quit
    }
    Set tSchedulePath = tBase _ "/screens/" _ ..#TASKLISTTOOL _ "/read?maxRows=1"
    Set tSC = ..Request("GET", tSchedulePath, "Bearer " _ pAccessToken, "", .tScheduleStatus, .tScheduleText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "taskdetails", "fail", "the task schedule could not be reached to find an id: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If tScheduleStatus '= 200 {
        Do ..Note(.pChecks, "taskdetails", "fail", "GET " _ tSchedulePath _ " answered HTTP " _ tScheduleStatus)
        Quit
    }
    Set tTaskId = ""
    Try {
        Set tRows = ##class(%DynamicAbstractObject).%FromJSON(tScheduleText).%Get("rows")
        If $IsObject(tRows) && tRows.%IsA("%Library.DynamicArray") && (tRows.%Size() > 0) Set tTaskId = tRows.%Get(0).%Get("Id")
    } Catch {
        Set tTaskId = ""
    }
    If tTaskId = "" {
        Do ..Note(.pChecks, "taskdetails", "fail", "the task schedule answered no row to read a task id from")
        Quit
    }
    Set tPath = tBase _ "/screens/" _ ..#TASKDETAILSTOOL _ "/read?maxRows=1&taskId=" _ tTaskId
    Set tSC = ..Request("GET", tPath, "Bearer " _ pAccessToken, "", .tStatus, .tText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "taskdetails", "fail", "the read could not be reached: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If tStatus '= 200 {
        Do ..Note(.pChecks, "taskdetails", "fail", "GET " _ tPath _ " answered HTTP " _ tStatus)
        Quit
    }
    Set tCount = -1
    Set tSameTask = 0
    Try {
        Set tRows = ##class(%DynamicAbstractObject).%FromJSON(tText).%Get("rows")
        If $IsObject(tRows) && tRows.%IsA("%Library.DynamicArray") Set tCount = tRows.%Size()
        If tCount = 1 Set tSameTask = (tRows.%Get(0).%Get("Id") = tTaskId) && (tRows.%Get(0).%GetTypeOf("TimePeriod") '= "unassigned")
    } Catch {
        Set tCount = -1
    }
    If tCount '= 1 {
        Do ..Note(.pChecks, "taskdetails", "fail", "GET " _ tPath _ " answered 200 without a rows array of exactly one row")
        Quit
    }
    If 'tSameTask {
        Do ..Note(.pChecks, "taskdetails", "fail", "GET " _ tPath _ " answered a row that is not task " _ tTaskId _ "'s details")
        Quit
    }
    Do ..Note(.pChecks, "taskdetails", "pass")
}

/// <p>Process details (<code>processdetails</code>, Story 6.8): the processes list's own first row
/// supplies the <code>pid</code> its parent-scoped read requires, so this check reads
/// <parameter>PROCESSLISTTOOL</parameter> again at <code>maxRows=1</code> to find one, needing the
/// same pairs <code>processes</code> already checked, and then reads
/// <parameter>PROCESSDETAILSTOOL</parameter> for that pid, expecting exactly one row that names
/// that <code>Pid</code>. Skipped, like <method>CheckMessagesLog</method>, when no token was
/// minted; failed, naming why, when the extracted <code>pid</code> is empty -- no row, or a row
/// with no <code>Pid</code> key -- to key the second read by. A live instance always has at
/// least one process (this one), so that is a real failure.</p>
ClassMethod CheckProcessDetails(ByRef pChecks, pAccessToken As %String) [ Private ]
{
    Set tBase = ..RosterPath("api")
    If tBase = "" {
        Do ..Note(.pChecks, "processdetails", "fail", "the roster on this instance declares no API path, so there was nothing to read")
        Quit
    }
    If pAccessToken = "" {
        Do ..Note(.pChecks, "processdetails", "skipped", "no token pair was minted by this run, so the authenticated read was not attempted")
        Quit
    }
    Set tListPath = tBase _ "/screens/" _ ..#PROCESSLISTTOOL _ "/read?maxRows=1"
    Set tSC = ..Request("GET", tListPath, "Bearer " _ pAccessToken, "", .tListStatus, .tListText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "processdetails", "fail", "the processes list could not be reached to find a pid: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If tListStatus '= 200 {
        Do ..Note(.pChecks, "processdetails", "fail", "GET " _ tListPath _ " answered HTTP " _ tListStatus)
        Quit
    }
    Set tPid = ""
    Try {
        Set tRows = ##class(%DynamicAbstractObject).%FromJSON(tListText).%Get("rows")
        If $IsObject(tRows) && tRows.%IsA("%Library.DynamicArray") && (tRows.%Size() > 0) Set tPid = tRows.%Get(0).%Get("Pid")
    } Catch {
        Set tPid = ""
    }
    If tPid = "" {
        Do ..Note(.pChecks, "processdetails", "fail", "the processes list answered no row with a Pid to read")
        Quit
    }
    Set tPath = tBase _ "/screens/" _ ..#PROCESSDETAILSTOOL _ "/read?maxRows=1&pid=" _ tPid
    Set tSC = ..Request("GET", tPath, "Bearer " _ pAccessToken, "", .tStatus, .tText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "processdetails", "fail", "the read could not be reached: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If tStatus '= 200 {
        Do ..Note(.pChecks, "processdetails", "fail", "GET " _ tPath _ " answered HTTP " _ tStatus)
        Quit
    }
    Set tCount = -1
    Set tSamePid = 0
    Try {
        Set tRows = ##class(%DynamicAbstractObject).%FromJSON(tText).%Get("rows")
        If $IsObject(tRows) && tRows.%IsA("%Library.DynamicArray") Set tCount = tRows.%Size()
        If tCount = 1 Set tSamePid = (tRows.%Get(0).%Get("Pid") = tPid)
    } Catch {
        Set tCount = -1
    }
    If tCount '= 1 {
        Do ..Note(.pChecks, "processdetails", "fail", "GET " _ tPath _ " answered 200 without a rows array of exactly one row")
        Quit
    }
    If 'tSamePid {
        Do ..Note(.pChecks, "processdetails", "fail", "GET " _ tPath _ " answered a row that is not process " _ tPid _ "'s details")
        Quit
    }
    Do ..Note(.pChecks, "processdetails", "pass")
}

/// <p>Database details and Database volumes (<code>databasedetails</code>,
/// <code>databasevolumes</code>, Story 6.11): the Databases General view's own first row supplies
/// the <code>dir</code> both parent-scoped reads require, so this check reads
/// <parameter>DATABASELISTTOOL</parameter> again at <code>maxRows=1</code> to find one, needing the
/// same pairs <code>databases</code> already checked, and then reads
/// <parameter>DATABASEDETAILSTOOL</parameter> and <parameter>DATABASEVOLUMESTOOL</parameter> for
/// that directory, each expecting at least one row. <code>dir</code> travels unescaped in the query
/// string: RFC 3986 lets <code>/</code> represent data inside a <code>query</code> component, so a
/// directory path's separators need no percent-encoding there -- unlike a route's own single path
/// segment (AD-13), which is a different position with a different rule. It is not that
/// <code>/</code> is unreserved; it is reserved, and permitted in this one position. Skipped, like
/// <method>CheckMessagesLog</method>, when no token was minted; failed, naming why, when the
/// Databases list answers no row to key the two reads by -- a mounted instance always has at least
/// one database (its own IRISSYS), so that is a real failure. Database details expects exactly one
/// row naming that <code>Directory</code>; Database volumes expects at least one row, since a
/// multi-file database answers more than one.</p>
ClassMethod CheckDatabaseDetails(ByRef pChecks, pAccessToken As %String) [ Private ]
{
    Set tBase = ..RosterPath("api")
    If tBase = "" {
        Do ..Note(.pChecks, "databasedetails", "fail", "the roster on this instance declares no API path, so there was nothing to read")
        Do ..Note(.pChecks, "databasevolumes", "fail", "the roster on this instance declares no API path, so there was nothing to read")
        Quit
    }
    If pAccessToken = "" {
        Do ..Note(.pChecks, "databasedetails", "skipped", "no token pair was minted by this run, so the authenticated read was not attempted")
        Do ..Note(.pChecks, "databasevolumes", "skipped", "no token pair was minted by this run, so the authenticated read was not attempted")
        Quit
    }
    Set tListPath = tBase _ "/screens/" _ ..#DATABASELISTTOOL _ "/read?maxRows=1"
    Set tSC = ..Request("GET", tListPath, "Bearer " _ pAccessToken, "", .tListStatus, .tListText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "databasedetails", "fail", "the Databases list could not be reached to find a directory: " _ $System.Status.GetErrorText(tSC))
        Do ..Note(.pChecks, "databasevolumes", "fail", "the Databases list could not be reached to find a directory: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If tListStatus '= 200 {
        Do ..Note(.pChecks, "databasedetails", "fail", "GET " _ tListPath _ " answered HTTP " _ tListStatus)
        Do ..Note(.pChecks, "databasevolumes", "fail", "GET " _ tListPath _ " answered HTTP " _ tListStatus)
        Quit
    }
    Set tDir = ""
    Try {
        Set tRows = ##class(%DynamicAbstractObject).%FromJSON(tListText).%Get("rows")
        If $IsObject(tRows) && tRows.%IsA("%Library.DynamicArray") && (tRows.%Size() > 0) Set tDir = tRows.%Get(0).%Get("Directory")
    } Catch {
        Set tDir = ""
    }
    If tDir = "" {
        Do ..Note(.pChecks, "databasedetails", "fail", "the Databases list answered no row with a Directory to read")
        Do ..Note(.pChecks, "databasevolumes", "fail", "the Databases list answered no row with a Directory to read")
        Quit
    }

    Set tPath = tBase _ "/screens/" _ ..#DATABASEDETAILSTOOL _ "/read?maxRows=1&dir=" _ tDir
    Set tSC = ..Request("GET", tPath, "Bearer " _ pAccessToken, "", .tStatus, .tText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "databasedetails", "fail", "the read could not be reached: " _ $System.Status.GetErrorText(tSC))
    } ElseIf tStatus '= 200 {
        Do ..Note(.pChecks, "databasedetails", "fail", "GET " _ tPath _ " answered HTTP " _ tStatus)
    } Else {
        Set tCount = -1
        Set tSameDir = 0
        Try {
            Set tRows = ##class(%DynamicAbstractObject).%FromJSON(tText).%Get("rows")
            If $IsObject(tRows) && tRows.%IsA("%Library.DynamicArray") Set tCount = tRows.%Size()
            If tCount = 1 Set tSameDir = (tRows.%Get(0).%Get("Directory") = tDir)
        } Catch {
            Set tCount = -1
        }
        If tCount '= 1 {
            Do ..Note(.pChecks, "databasedetails", "fail", "GET " _ tPath _ " answered 200 without a rows array of exactly one row")
        } ElseIf 'tSameDir {
            Do ..Note(.pChecks, "databasedetails", "fail", "GET " _ tPath _ " answered a row that is not " _ tDir _ "'s details")
        } Else {
            Do ..Note(.pChecks, "databasedetails", "pass")
        }
    }

    Set tVolPath = tBase _ "/screens/" _ ..#DATABASEVOLUMESTOOL _ "/read?maxRows=10&dir=" _ tDir
    Set tSC = ..Request("GET", tVolPath, "Bearer " _ pAccessToken, "", .tVolStatus, .tVolText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "databasevolumes", "fail", "the read could not be reached: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If tVolStatus '= 200 {
        Do ..Note(.pChecks, "databasevolumes", "fail", "GET " _ tVolPath _ " answered HTTP " _ tVolStatus)
        Quit
    }
    Set tVolCount = -1
    Try {
        Set tVolRows = ##class(%DynamicAbstractObject).%FromJSON(tVolText).%Get("rows")
        If $IsObject(tVolRows) && tVolRows.%IsA("%Library.DynamicArray") Set tVolCount = tVolRows.%Size()
    } Catch {
        Set tVolCount = -1
    }
    If tVolCount < 1 {
        Do ..Note(.pChecks, "databasevolumes", "fail", "GET " _ tVolPath _ " answered 200 without a rows array of at least one row -- every mounted database has at least its primary volume file")
        Quit
    }
    Do ..Note(.pChecks, "databasevolumes", "pass")
}

/// <p>The console-log page, read with the minted access token: one bounded page of the instance's
/// own <file>messages.log</file>, which must answer 200 with a <code>lines</code> array. The
/// signed-in principal needs <code>%Admin_Operate:USE</code>, or the read answers 403 and the
/// check fails. Skipped, like the shell reads, when no token was minted.</p>
/// <p>It is the one check outside <method>CheckAreaLists</method>, because the endpoint has no
/// screen and so no tool identifier to read through: it is <b>read-only</b> against the live log
/// and writes, rotates and removes nothing.</p>
ClassMethod CheckMessagesLog(ByRef pChecks, pAccessToken As %String) [ Private ]
{
    Set tBase = ..RosterPath("api")
    If tBase = "" {
        Do ..Note(.pChecks, "messageslog", "fail", "the roster on this instance declares no API path, so there was nothing to read")
        Quit
    }
    If pAccessToken = "" {
        Do ..Note(.pChecks, "messageslog", "skipped", "no token pair was minted by this run, so the authenticated read was not attempted")
        Quit
    }
    Set tPath = tBase _ ..#MESSAGESLOGPATH
    Set tSC = ..Request("GET", tPath, "Bearer " _ pAccessToken, "", .tStatus, .tText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "messageslog", "fail", "the console log page could not be reached: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If tStatus '= 200 {
        Do ..Note(.pChecks, "messageslog", "fail", "GET " _ tPath _ " answered HTTP " _ tStatus)
        Quit
    }
    Set tLines = -1
    Try {
        Set tArray = ##class(%DynamicAbstractObject).%FromJSON(tText).%Get("lines")
        If $IsObject(tArray) && tArray.%IsA("%Library.DynamicArray") Set tLines = tArray.%Size()
    } Catch {
        Set tLines = -1
    }
    If tLines < 0 {
        Do ..Note(.pChecks, "messageslog", "fail", "GET " _ tPath _ " answered 200 without a lines array")
        Quit
    }
    Do ..Note(.pChecks, "messageslog", "pass")
}

/// <p>The application error log's namespaces level, read with the minted access token: the
/// namespaces this instance records application errors for, which must answer 200 with a
/// <code>rows</code> array. The signed-in principal needs <code>%Admin_Operate:USE</code> and
/// <code>%DB_IRISSYS:READ</code> -- the database <code>SYS.ApplicationError</code> is executed from
/// -- or the read answers 403 and the check fails. Skipped, like the shell reads, when no token was
/// minted.</p>
/// <p>It is the second check outside <method>CheckAreaLists</method>, for the reason
/// <method>CheckMessagesLog</method> is: the screen declares no read, so there is no tool
/// identifier to read it through. It is <b>read-only</b>: it writes nothing to
/// <code>^ERRORS</code> and deletes nothing.</p>
/// <p><b>An empty array passes and a missing one fails.</b> An instance that has never faulted
/// records no application errors at all, which is a correct answer from a serving endpoint; what
/// the check is about is that the endpoint answers the page contract.</p>
ClassMethod CheckApplicationErrors(ByRef pChecks, pAccessToken As %String) [ Private ]
{
    Set tBase = ..RosterPath("api")
    If tBase = "" {
        Do ..Note(.pChecks, "applicationerrors", "fail", "the roster on this instance declares no API path, so there was nothing to read")
        Quit
    }
    If pAccessToken = "" {
        Do ..Note(.pChecks, "applicationerrors", "skipped", "no token pair was minted by this run, so the authenticated read was not attempted")
        Quit
    }
    Set tPath = tBase _ ..#APPLICATIONERRORSPATH
    Set tSC = ..Request("GET", tPath, "Bearer " _ pAccessToken, "", .tStatus, .tText)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "applicationerrors", "fail", "the application error log could not be reached: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If tStatus '= 200 {
        Do ..Note(.pChecks, "applicationerrors", "fail", "GET " _ tPath _ " answered HTTP " _ tStatus)
        Quit
    }
    Set tRows = -1
    Try {
        Set tArray = ##class(%DynamicAbstractObject).%FromJSON(tText).%Get("rows")
        If $IsObject(tArray) && tArray.%IsA("%Library.DynamicArray") Set tRows = tArray.%Size()
    } Catch {
        Set tRows = -1
    }
    If tRows < 0 {
        Do ..Note(.pChecks, "applicationerrors", "fail", "GET " _ tPath _ " answered 200 without a rows array")
        Quit
    }
    Do ..Note(.pChecks, "applicationerrors", "pass")
}

/// <p>Every audit event type OcuPilot's roster declares is registered with
/// <code>Security.Events</code>. An unregistered triple makes
/// <code>$System.Security.Audit</code> return 0 and drop the event with no error and no log line,
/// so this is the check that keeps every later audit assertion from being vacuous.</p>
/// <p><b>The roster is swept, and a partially-registered instance is <code>skipped</code>, not
/// <code>fail</code></b> -- the <method>CheckAgentSwitches</method> precedent. The baseline triple
/// is the grant marker every install since Story 1.3 registers; its absence is a real failure. A
/// later roster entry can be missing for one honest reason as well -- the instance's last install
/// predates it, and <parameter>OcuPilot.Install.Installer.SCHEMAVERSION</parameter> is deliberately
/// not raised for a roster that grew, so nothing else distinguishes "never installed since" from
/// "deleted". The check names which are missing and says so.</p>
ClassMethod CheckAuditEvent(ByRef pChecks) [ Private ]
{
    ; Every read of an OcuPilot class happens BEFORE the switch. A fresh ##class(OcuPilot.*)
    ; dispatch issued while $NAMESPACE is %SYS raises <CLASS DOES NOT EXIST> -- OcuPilot's code is
    ; mapped nowhere but the install namespace (OcuPilot.Install.Installer's own header). Reading
    ; them inside the switched window made this check report "not registered" for an event that was.
    Set tSource = ##class(OcuPilot.Kernel.State.Base).#AUDITSOURCE
    Set tType = ##class(OcuPilot.Kernel.State.Base).#AUDITTYPE
    Set tBaseline = ##class(OcuPilot.Kernel.State.Base).#AUDITNAME
    Set tRoster = ##class(OcuPilot.Kernel.Audit.Event).Names()
    If $ListLength(tRoster) = 0 {
        Do ..Note(.pChecks, "auditevent", "fail", "OcuPilot's audit-event roster is empty, so this check would assert nothing")
        Quit
    }
    Set tOrigNS = $NAMESPACE
    Set tMissing = ""
    ; The missing names are kept as a LIST as well as as a sentence: the baseline test below is a
    ; membership question, and asking it of the sentence would read a later entry whose name begins
    ; with the baseline's as the baseline itself.
    Set tMissingNames = ""
    Set tRead = 0
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tRoster) {
            Set tName = $List(tRoster, tI)
            If '##class(Security.Events).Exists(tSource, tType, tName, .tObj, .tSC) {
                Set tMissingNames = tMissingNames _ $ListBuild(tName)
                Set tMissing = tMissing _ $Select(tMissing = "": "", 1: ", ") _ tSource _ "/" _ tType _ "/" _ tName
            }
            Set tRead = tRead + 1
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tRead = -1
    }
    If tRead '= $ListLength(tRoster) {
        Do ..Note(.pChecks, "auditevent", "fail", "OcuPilot's audit-event registrations could not be read, so whether a row it writes is dropped is unknown")
        Quit
    }
    If tMissing = "" {
        Do ..Note(.pChecks, "auditevent", "pass")
        Quit
    }
    If $ListFind(tMissingNames, tBaseline) {
        Do ..Note(.pChecks, "auditevent", "fail", "OcuPilot's baseline audit event is not registered, so every audit row it would write is dropped silently: " _ tMissing)
        Quit
    }
    Do ..Note(.pChecks, "auditevent", "skipped", "the instance's last install predates part of OcuPilot's audit-event roster, so rows under these triples are dropped until it installs again: " _ tMissing)
}

/// <p>The agent switches an install leaves behind: <b>no switch row, and no per-user hold</b>, so
/// the kill switch is off and nothing restrains the agent on an instance that has just been
/// installed (FR-19, FR-20).</p>
/// <p>It is asked here rather than only in the unit suite because the unit suite empties the two
/// stores in its own setup: a test that deletes the row before reading it cannot tell an install
/// that wrote none from one that wrote a row and left the agent switched off.</p>
/// <p><b>An instance whose switches have been used is <code>skipped</code>, not
/// <code>fail</code>.</b> The first administrator to save the Switches screen writes the row, and
/// no route deletes it, so a check that failed on any row would report every instance using the
/// feature as broken -- on the long-lived instance and in CI alike. What the smoke run can still
/// answer honestly is the fresh-install question, and only on an instance that is still fresh.</p>
/// <p>The two stores are read through <class>OcuPilot.Kernel.State.Base</class>'s guarded methods,
/// never by SQL against the protected tables (AD-9): <method>OcuPilot.Kernel.State.Switch.Resolve</method>
/// answers an empty <code>updatedAt</code> exactly when no row has been written, and
/// <method>OcuPilot.Kernel.State.Hold.GuardedList</method> enumerates the holds.</p>
ClassMethod CheckAgentSwitches(ByRef pChecks) [ Private ]
{
    Set tReadSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tValues)
    If $$$ISERR(tReadSC) {
        Do ..Note(.pChecks, "agentswitches", "fail", "the agent switch state could not be read, so whether the agent is switched off is unknown: " _ $System.Status.GetErrorText(tReadSC))
        Quit
    }
    Set tHoldSC = ##class(OcuPilot.Kernel.State.Hold).GuardedList(.tIds)
    If $$$ISERR(tHoldSC) {
        Do ..Note(.pChecks, "agentswitches", "fail", "the per-user agent holds could not be read, so whether the agent is switched off for someone is unknown: " _ $System.Status.GetErrorText(tHoldSC))
        Quit
    }
    Set tHolds = +$Get(tIds)
    If $Get(tValues("updatedAt")) '= "" {
        Do ..Note(.pChecks, "agentswitches", "skipped", "the agent switches have been written on this instance, last at " _ tValues("updatedAt") _ ", so whether the install wrote none cannot be told here")
        Quit
    }
    If tHolds '= 0 {
        Do ..Note(.pChecks, "agentswitches", "skipped", "the instance carries " _ tHolds _ " per-user agent hold(s), which an operator created, so whether the install wrote none cannot be told here")
        Quit
    }
    Set tSC = ##class(OcuPilot.Kernel.Restraint).Verdict($Username, "", .tVerdict)
    If $$$ISERR(tSC) {
        Do ..Note(.pChecks, "agentswitches", "fail", "the restraint verdict could not be read: " _ $System.Status.GetErrorText(tSC))
        Quit
    }
    If +$Get(tVerdict("killSwitch")) {
        Do ..Note(.pChecks, "agentswitches", "fail", "the agent is switched off on this instance, with no switch row to say why")
        Quit
    }
    Do ..Note(.pChecks, "agentswitches", "pass")
}

/// <p>The opt-in demo fixtures (AD-25), asserted only when <code>OCUPILOT_DEMO</code> asked for
/// them. A run that did not ask skips this rather than passing it, so an instance that never
/// created a fixture is not reported as one that created them correctly.</p>
/// <p><var>pDemo</var> is <code>"1"</code> to assert them, <code>"0"</code> to skip, and
/// <code>""</code> to read <code>OCUPILOT_DEMO</code> from this process's own environment.
/// <b>The caller's answer is preferred because this process's environment is not the
/// container's.</b> Verified on this build, and recorded for the same reason in
/// <file>scripts/container-start.sh</file>: a session spawned down the instance's own process
/// tree sees a visibly narrower environment than the container's declared one, and
/// <code>$System.Util.GetEnviron("OCUPILOT_DEMO")</code> answers <code>""</code> on a container
/// whose compose file sets it. <file>scripts/smoke.sh</file> resolves the flag from PID 1's own
/// environment and hands it in, so "demo not requested" and "demo requested but undetectable"
/// are not the same answer.</p>
ClassMethod CheckDemoFixture(ByRef pChecks, pDemo As %String = "") [ Private ]
{
    Set tWanted = $Select(pDemo '= "": pDemo, 1: $System.Util.GetEnviron("OCUPILOT_DEMO"))
    If tWanted '= "1" {
        Do ..Note(.pChecks, "demofixture", "skipped", "the demo opt-in flag is not set for this instance, so no demo walkthrough fixture was expected (AD-25)")
        Quit
    }
    Set tCount = 0
    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Demo).GuardedIdsForProfile("", .tIds)
        If $$$ISOK(tSC) Set tCount = +$Get(tIds)
    } Catch {
        Set tCount = 0
    }
    If tCount = 0 {
        Do ..Note(.pChecks, "demofixture", "fail", "OCUPILOT_DEMO is set and the demo fixture inventory records nothing")
        Quit
    }
    Do ..Note(.pChecks, "demofixture", "pass")
}

/// <p>The other caller of the same operation (AD-53): a person's own row action on the demo
/// fixture, over the real <code>POST /screens/:screen/action</code> route as the browser makes it,
/// with the bearer token this run already signed in for.</p>
/// <p>It asserts the consumer's own tier rather than the operation's internal state: the route
/// answers the AD-14 verb and the canonical target, and the instance's own record of the
/// application moves. Enable then disable, so the fixture ends in the disabled, no-resource state
/// its install creates -- which is the state <method>CheckAgentWrite</method> asserts against
/// later in the same run.</p>
/// <p>Skipped, not failed, where the demo fixture was never created or is not this install's:
/// AD-25 forbids modifying an application OcuPilot did not make.</p>
ClassMethod CheckScreenAction(ByRef pChecks, pAccessToken As %String, pDemo As %String = "") [ Private ]
{
    Set tSkip = ""
    Try {
        Set tWanted = $Select(pDemo '= "": pDemo, 1: $System.Util.GetEnviron("OCUPILOT_DEMO"))
        If tWanted '= "1" {
            Set tSkip = "the demo opt-in flag is not set for this instance, so the " _ ..WriteTarget() _ " fixture a row action needs was never created (AD-25)"
            Quit
        }
        If '..WriteTargetOwned() {
            Set tSkip = ..WriteTarget() _ " is absent, or carries an application this install did not create, which AD-25 forbids modifying"
            Quit
        }
        Set tSpelling = ..ApplicationName(..WriteTarget())
        If tSpelling = "" {
            Set tSkip = "this instance's own record of " _ ..WriteTarget() _ " could not be read, so there is no application to act on"
            Quit
        }
        Set tBase = ..RosterPath("api")
        If tBase = "" {
            Set tSkip = "the install roster declares no API application path"
            Quit
        }
        Set tPath = tBase _ "/screens/" _ ..#WEBAPPLISTTOOL _ "/action"

        Set tEnableSC = ..ScreenAction(tPath, pAccessToken, "enable", tSpelling, .tEnableStatus, .tEnableText)
        If $$$ISERR(tEnableSC) || (tEnableStatus '= 200) {
            Do ..Note(.pChecks, "screenaction", "fail", "the row's enable answered HTTP " _ +$Get(tEnableStatus) _ ": " _ $Extract($Get(tEnableText), 1, 200))
            Quit
        }
        Set tAnswer = ##class(%DynamicAbstractObject).%FromJSON(tEnableText)
        If '$IsObject(tAnswer) || (tAnswer.%Get("action") '= "updated") {
            Do ..Note(.pChecks, "screenaction", "fail", "the row's enable answered no 'updated' action: " _ $Extract($Get(tEnableText), 1, 200))
            Quit
        }
        If ..ApplicationEnabled(..WriteTarget()) '= 1 {
            Do ..Note(.pChecks, "screenaction", "fail", "the route answered 200 and this instance still reports " _ ..WriteTarget() _ " disabled")
            Quit
        }

        Set tDisableSC = ..ScreenAction(tPath, pAccessToken, "disable", tSpelling, .tDisableStatus, .tDisableText)
        If $$$ISERR(tDisableSC) || (tDisableStatus '= 200) {
            Do ..Note(.pChecks, "screenaction", "fail", "the row's disable answered HTTP " _ +$Get(tDisableStatus) _ ": " _ $Extract($Get(tDisableText), 1, 200))
            Quit
        }
        If ..ApplicationEnabled(..WriteTarget()) '= 0 {
            Do ..Note(.pChecks, "screenaction", "fail", "the fixture was left enabled, which is not the state its install creates")
            Quit
        }
        Do ..Note(.pChecks, "screenaction", "pass", "the row's enable and disable ran over " _ tPath _ " and this instance's own record moved both ways")
    } Catch ex {
        Set tSkip = ""
        Do ..Note(.pChecks, "screenaction", "fail", "the row-action check raised " _ ex.DisplayString())
    }
    If tSkip '= "" Do ..Note(.pChecks, "screenaction", "skipped", tSkip)
}

/// <p>One row action over the wire: <code>POST</code> <var>pPath</var> carrying
/// <code>{action, id}</code>, as the browser sends it.</p>
ClassMethod ScreenAction(pPath As %String, pAccessToken As %String, pAction As %String, pId As %String, Output pStatus As %Integer, Output pText As %String) As %Status [ Private ]
{
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", pId, "string")
    Quit ..Request("POST", pPath, "Bearer " _ pAccessToken, tBody.%ToJSON(), .pStatus, .pText)
}

/// <p>Whether this instance reports the web application at <var>pPath</var> enabled, or
/// <code>""</code> when it holds none. Switches to <code>%SYS</code> and restores, restoring first
/// on the error path (AD-16).</p>
ClassMethod ApplicationEnabled(pPath As %String) As %String [ Private ]
{
    Set tEnabled = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(pPath, .tApp, .tSC), $IsObject(tApp) Set tEnabled = ''tApp.Enabled
        Set tApp = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tEnabled = ""
    }
    Quit tEnabled
}

/// <p>AD-45's two remaining checks, driven as one sequence because they are one event: a proposal
/// minted and confirmed through the shipped path against AD-25's demo fixture
/// (<code>agentwrite</code>), and the <code>AgentWrite</code> row that write leaves in the audit
/// database (<code>auditmarker</code>).</p>
/// <p><b>The only check that writes to the instance, so it restores what it changed.</b> The
/// fixture is created disabled with no resource and AD-25 forbids modifying one this install did
/// not make, so a run that left it enabled would contradict
/// <class>OcuPilot.Install.Fixture</class>'s own created-state contract and make a second run
/// assert against a target in a state no install produced. The restore sends the instance's own
/// record of the application with those two fields put back to the state the install creates, not
/// the state this run found: a run interrupted between the write and the restore would otherwise
/// have its own drift restored by every run after it.</p>
/// <p><b>A fixture not in that state is a <code>fail</code>, not a pass.</b> A write over an
/// application already enabled with the resource changes nothing, and every assertion after it
/// would hold of a write that did nothing -- so the mint's own diff is checked to name both
/// fields, and the fixture is put back either way.</p>
/// <p><b>Every read, the write and the restore are keyed by one resolution</b>:
/// <method>ApplicationName</method>'s reading of <class>Security.Applications</class>, which
/// answers the spelling the instance stores. The proposal's <code>TargetRef</code> is never used
/// as an id here -- <method>OcuPilot.Kernel.EntityRef.Key</method> folds it (AD-13's canonical
/// form), and a check that took its id from there would be reporting on an application it
/// resolved by a name the instance does not hold. <b>Measured on this build, and the reason this
/// is a correctness property rather than a refusal:</b> both
/// <method>Security.Applications.Exists</method> and the vendor's <code>WebApp.App</code>
/// <code>GET</code> resolve a web-application name case-insensitively, so a folded id would find
/// the same application and answer plausibly. <class>OcuPilot.Test.Smoke</class> drives the whole
/// check against an application the instance spells in mixed case, and pins that resolution
/// directly.</p>
/// <p><b><code>skipped</code>, never <code>fail</code>, where the environment cannot carry it</b>
/// -- no demo opt-in, no fixture, a fixture this install did not create, or a turn of this user
/// already running. The reason travels even where the assertion cannot (DW-1402), so
/// <code>executed=</code> stays honest, and it names the cause it actually met rather than the
/// likeliest one. <b>No skip writes.</b> A skipped check did not run, so it has nothing to put
/// back, and a restore on that path would be normalising a drift this run did not cause. The
/// restore on a <code>fail</code> is the opposite case and is deliberate: there the state was
/// asserted against and found wrong, and the next run has to be able to assert against it again.</p>
/// <p><b><code>OcuPilot.PKG</code> classes only</b> (this class's own scope wall): the turn row
/// comes from <class>OcuPilot.Kernel.State.Turn</class>'s guarded reserve, begin and finish, and
/// the write target is AD-25's fixture rather than a probe application a test class would make.</p>
ClassMethod CheckAgentWrite(ByRef pChecks, pDemo As %String = "") [ Private ]
{
    Set tSkip = ""
    Set tTurnKey = ""
    Try {
        Set tWanted = $Select(pDemo '= "": pDemo, 1: $System.Util.GetEnviron("OCUPILOT_DEMO"))
        If tWanted '= "1" {
            Set tSkip = "the demo opt-in flag is not set for this instance, so the " _ ..WriteTarget() _ " fixture a confirmed write needs was never created (AD-25)"
            Quit
        }
        If '..WriteTargetOwned() {
            Set tSkip = ..WriteTarget() _ " is absent, or carries an application this install did not create, which AD-25 forbids modifying"
            Quit
        }
        Set tSpelling = ..ApplicationName(..WriteTarget())
        If tSpelling = "" {
            Set tSkip = "this instance's own record of " _ ..WriteTarget() _ " could not be read, so there is no application to write to"
            Quit
        }

        Kill tQuery
        Set tQuery(##class(OcuPilot.Screen.Tool.Write).IdParam()) = tSpelling
        Set tReadSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tBefore, .tReadHttp, .tReadFault)
        If $$$ISERR(tReadSC) || '$IsObject($Get(tBefore)) {
            Do ..Note(.pChecks, "agentwrite", "fail", "the fixture could not be read fresh before the write (HTTP " _ +$Get(tReadHttp) _ ")")
            Do ..Note(.pChecks, "auditmarker", "fail", "no write was made, so no audit row could be looked for")
            Quit
        }
        ; The body the restore sends: the instance's own record of the application with the two
        ; fields this write changes put back to the state Fixture.CreateWebApp creates -- not the
        ; state this run happened to find. A run interrupted between the write and the restore
        ; would otherwise have its own drift restored by the next one, forever.
        Set tRestoreBody = ##class(%DynamicAbstractObject).%FromJSON(tBefore.%ToJSON())
        Do tRestoreBody.%Set("Enabled", 0, "boolean")
        Do tRestoreBody.%Set("Resource", "", "string")

        Set tReserveSC = ##class(OcuPilot.Kernel.State.Turn).GuardedReserve($Username, "", ##class(OcuPilot.Api.Error).#TURNABANDONEDJOBLOST, ..#LIMITS, .tTurnKey, .tBusy, .tSweepSC)
        If $$$ISERR(tReserveSC) || tBusy || (tTurnKey = "") {
            ; The reason names the cause rather than the likeliest cause (DW-1402): a reserve that
            ; errored is not a busy slot, and reporting it as one sends the reader at the wrong
            ; thing. And the restore body is dropped: this arm has written nothing, so putting the
            ; fixture back would be restoring a state this run did not cause -- a skip means the
            ; check did not run, and a check that did not run touches the instance not at all.
            Set tSkip = $Select($$$ISERR(tReserveSC): "a turn row could not be reserved for this check: " _ $System.Status.GetErrorText(tReserveSC), 1: "a turn of " _ $Username _ " is already running on this instance, so this check would race it for the one turn slot")
            Set tTurnKey = ""
            Set tRestoreBody = ""
            Quit
        }
        Do ##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tTurnKey, $Username, ..#LIMITS, .tBegun, .tStarted)
        Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tTurnKey, $Username, "completed", "", "", "", 0, ..#LIMITS)

        Set tArgs = {}
        Do tArgs.%Set(##class(OcuPilot.Screen.Tool.Write).IdArgument(), tSpelling, "string")
        Do tArgs.%Set("Enabled", 1, "boolean")
        Do tArgs.%Set("Resource", ..#WRITERESOURCE, "string")
        Set tMintSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint(##class(OcuPilot.Screen.Tool.WebAppUpdate).#DESCRIPTORCLASS, ..#WEBAPPUPDATETOOL, $Username, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .tMintHttp, .tMintFault, ##class(OcuPilot.Screen.Tool.WebAppUpdate).Endpoint(), ##class(OcuPilot.Screen.Tool.Write).IdParam(), tSpelling, ##class(OcuPilot.Screen.Tool.Write).IdArgument(), ##class(OcuPilot.Screen.Tool.WebAppUpdate).SettableFields())
        If $$$ISERR(tMintSC) || '$IsObject($Get(tProposal)) {
            Do ..Note(.pChecks, "agentwrite", "fail", "the proposal could not be minted: " _ $System.Status.GetErrorText(tMintSC))
            Do ..Note(.pChecks, "auditmarker", "fail", "no write was made, so no audit row could be looked for")
            Quit
        }
        Set tProposalId = tProposal.%Get("proposalId")
        ; A fixture already enabled with the resource yields a diff with no rows, and every
        ; assertion below would then hold of a write that changed nothing. The state is asserted
        ; through the mint's own diff rather than through a second read, because the diff is what
        ; the user would have reviewed.
        Set tChanged = ""
        Set tChangedIterator = tProposal.%Get("changed").%GetIterator()
        While tChangedIterator.%GetNext(.tChangedIndex, .tChangedRow) {
            Set tChanged = tChanged _ $Select(tChanged = "": "", 1: ",") _ tChangedRow.%Get("field")
        }
        If (tChanged '= "Enabled,Resource") && (tChanged '= "Resource,Enabled") {
            Do ..Note(.pChecks, "agentwrite", "fail", ..WriteTarget() _ " was not in the disabled, no-resource state its install creates, so this write would have changed '" _ tChanged _ "' rather than both fields; it is put back and the next run asserts against it")
            Do ..Note(.pChecks, "auditmarker", "fail", "the write this row would account for changed nothing")
            Quit
        }
        Set tSince = ..AuditNow()
        Set tConfirmSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposalId, "", $Username, .tResult, .tConfirmHttp, .tConfirmCode, .tConfirmDetail)
        If $$$ISERR(tConfirmSC) {
            Do ..Note(.pChecks, "agentwrite", "fail", "the confirm was refused at HTTP " _ +$Get(tConfirmHttp) _ " with " _ $Get(tConfirmCode))
            Do ..Note(.pChecks, "auditmarker", "fail", "no write was made, so no audit row could be looked for")
            Quit
        }

        Kill tQuery
        Set tQuery(##class(OcuPilot.Screen.Tool.Write).IdParam()) = tSpelling
        Set tBackSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tAfter, .tBackHttp, .tBackFault)
        Set tProblem = ""
        If $$$ISERR(tBackSC) || '$IsObject($Get(tAfter)) {
            Set tProblem = "the target could not be read back after the write (HTTP " _ +$Get(tBackHttp) _ ")"
        } ElseIf ''tAfter.%Get("Enabled") '= 1 {
            Set tProblem = "the confirmed write did not enable " _ tSpelling
        } ElseIf tAfter.%Get("Resource") '= ..#WRITERESOURCE {
            Set tProblem = "the confirmed write left the resource '" _ tAfter.%Get("Resource") _ "' rather than " _ ..#WRITERESOURCE
        }
        If tProblem = "" {
            Do ..Note(.pChecks, "agentwrite", "pass")
        } Else {
            Do ..Note(.pChecks, "agentwrite", "fail", tProblem)
        }

        Set tRows = ..MarkerRows(tSince, tProposalId)
        If tRows = 1 {
            Do ..Note(.pChecks, "auditmarker", "pass")
        } ElseIf tRows < 0 {
            Do ..Note(.pChecks, "auditmarker", "fail", "the audit database could not be read, so whether the write was marked is unknown")
        } Else {
            Do ..Note(.pChecks, "auditmarker", "fail", tRows _ " audit row(s) carry this write's proposal id; the marker AD-15 requires is one")
        }
    } Catch ex {
        Do ..Note(.pChecks, "agentwrite", "fail", "the agent-write check raised " _ ex.DisplayString())
        Do ..Note(.pChecks, "auditmarker", "fail", "no write could be accounted for")
        Set tSkip = ""
    }
    ; Its own frame: the fixture is restored and the turn row removed whatever the checks above
    ; decided, including on the raise, so a failed run leaves nothing behind for the next one.
    Do ..RestoreWriteTarget($Get(tSpelling), $Get(tRestoreBody), tTurnKey)
    If tSkip '= "" {
        Do ..Note(.pChecks, "agentwrite", "skipped", tSkip)
        Do ..Note(.pChecks, "auditmarker", "skipped", tSkip)
    }
}

/// <p>Story 7.1's integration check (<code>agentdelete</code>): the agent's own delete tool,
/// <class>OcuPilot.Screen.Tool.WebAppDelete</class>, mints a proposal against AD-25's demo fixture
/// through its tool entry point on a completed turn, the card's own row for it reads destructive,
/// the user's confirm runs through the shipped transition, and this instance's own record no
/// longer holds the application.</p>
/// <p><b>It puts the fixture back as install creates it</b>, through
/// <method>OcuPilot.Install.Fixture.Create</method> -- install's own creator, which recreates an
/// absent fixture disabled with no resource and keeps the inventory row that already records it, so
/// <method>WriteTargetOwned</method> still answers yes and the next run finds what this one found.
/// That call does to the other demo fixtures what every container start does: each one present is
/// left as it is, and one application-error entry is seeded. A fixture that did not come back in
/// that state is a <code>fail</code>.</p>
/// <p>Runs after every other check that reads the fixture. <code>skipped</code>, never
/// <code>fail</code>, where <method>CheckAgentWrite</method> skips, and where
/// <method>WriteTarget</method> is not the path that creator makes: an application it did not make
/// is one this check could not put back.</p>
ClassMethod CheckAgentDelete(ByRef pChecks, pDemo As %String = "") [ Private ]
{
    Set tSkip = ""
    Set tProblem = ""
    Set tTurnKey = ""
    Set tNamespace = ""
    Set tAttempted = 0
    Try {
        Set tWanted = $Select(pDemo '= "": pDemo, 1: $System.Util.GetEnviron("OCUPILOT_DEMO"))
        If tWanted '= "1" {
            Set tSkip = "the demo opt-in flag is not set for this instance, so the " _ ..WriteTarget() _ " fixture a confirmed delete needs was never created (AD-25)"
            Quit
        }
        If ..WriteTarget() '= ##class(OcuPilot.Install.Fixture).#APPPATH {
            Set tSkip = ..WriteTarget() _ " is not the application install's own fixture creator makes, so a delete of it could not be put back"
            Quit
        }
        If '..WriteTargetOwned() {
            Set tSkip = ..WriteTarget() _ " is absent, or carries an application this install did not create, which AD-25 forbids modifying"
            Quit
        }
        Set tSpelling = ..ApplicationName(..WriteTarget())
        If tSpelling = "" {
            Set tSkip = "this instance's own record of " _ ..WriteTarget() _ " could not be read, so there is no application to delete"
            Quit
        }

        ; The namespace install bound the fixture to, which is the one the restore binds it to again.
        Kill tQuery
        Set tQuery(##class(OcuPilot.Screen.Tool.WebAppDelete).IdParam()) = tSpelling
        Set tReadSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tBefore, .tReadHttp, .tReadFault)
        If $$$ISOK(tReadSC) && $IsObject($Get(tBefore)) Set tNamespace = tBefore.%Get("NameSpace")
        If tNamespace = "" {
            Set tProblem = "the fixture's namespace could not be read before the delete (HTTP " _ +$Get(tReadHttp) _ "), so it could not be put back afterwards"
            Quit
        }

        Set tReserveSC = ##class(OcuPilot.Kernel.State.Turn).GuardedReserve($Username, "", ##class(OcuPilot.Api.Error).#TURNABANDONEDJOBLOST, ..#LIMITS, .tTurnKey, .tBusy, .tSweepSC)
        If $$$ISERR(tReserveSC) || tBusy || (tTurnKey = "") {
            Set tSkip = $Select($$$ISERR(tReserveSC): "a turn row could not be reserved for this check: " _ $System.Status.GetErrorText(tReserveSC), 1: "a turn of " _ $Username _ " is already running on this instance, so this check would race it for the one turn slot")
            Set tTurnKey = ""
            Quit
        }
        Do ##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tTurnKey, $Username, ..#LIMITS, .tBegun, .tStarted)
        Do ##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tTurnKey, $Username, "completed", "", "", "", 0, ..#LIMITS)

        ; The tool's own entry point, acting for that turn as the turn job does; the stash is
        ; cleared before the confirm, which refuses a call made on a turn's behalf (AD-40).
        Set tArgs = {}
        Do tArgs.%Set(##class(OcuPilot.Screen.Tool.WebAppDelete).IdArgument(), tSpelling, "string")
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
        Set tMintSC = ##class(OcuPilot.Screen.Tool.WebAppDelete).View("", tArgs, 0, .tProposal, .tMintHttp, .tMintFault)
        Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
        If $$$ISERR(tMintSC) || '$IsObject($Get(tProposal)) {
            Set tProblem = "the delete proposal could not be minted (HTTP " _ +$Get(tMintHttp) _ "): " _ $System.Status.GetErrorText(tMintSC)
            Quit
        }
        Set tProposalId = tProposal.%Get("proposalId")

        ; Asserted on the row the card itself is drawn from, not on the tool's declaration.
        Set tDestructive = ""
        Set tRowsSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurnKey, $Username, .tRows)
        If $$$ISOK(tRowsSC) && $IsObject($Get(tRows)) {
            Set tRowIterator = tRows.%GetIterator()
            While tRowIterator.%GetNext(.tRowIndex, .tRow) {
                If $IsObject(tRow) && (tRow.%Get("proposalId") = tProposalId) Set tDestructive = tRow.%Get("destructive")
            }
        }
        If tDestructive '= 1 {
            Set tProblem = "the minted delete proposal's card row does not read destructive"
            Quit
        }

        Set tAttempted = 1
        Set tConfirmSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposalId, "", $Username, .tResult, .tConfirmHttp, .tConfirmCode, .tConfirmDetail)
        If $$$ISERR(tConfirmSC) {
            Set tProblem = "the confirm was refused at HTTP " _ +$Get(tConfirmHttp) _ " with " _ $Get(tConfirmCode)
            Quit
        }
        If ..ApplicationName(..WriteTarget()) '= "" {
            Set tProblem = "the confirm answered and this instance still holds " _ ..WriteTarget()
            Quit
        }
    } Catch ex {
        Set tSkip = ""
        Set tProblem = "the agent-delete check raised " _ ex.DisplayString()
    }
    ; Its own frame: whatever the checks above decided, a fixture this check may have removed is
    ; put back, and the turn row and its proposal are removed.
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Try {
        If tAttempted && (tNamespace '= "") && (..ApplicationName(..WriteTarget()) = "") {
            Kill tReports
            Do ##class(OcuPilot.Install.Fixture).Create("", .tReports, , tNamespace)
        }
        If tAttempted {
            Kill tQuery
            Set tQuery(##class(OcuPilot.Screen.Tool.WebAppDelete).IdParam()) = ..WriteTarget()
            Set tBackSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tAfter, .tBackHttp, .tBackFault)
            If $$$ISERR(tBackSC) || '$IsObject($Get(tAfter)) {
                Set tProblem = tProblem _ $Select(tProblem = "": "", 1: "; ") _ ..WriteTarget() _ " was not put back (HTTP " _ +$Get(tBackHttp) _ ")"
            } ElseIf ('..WriteTargetOwned()) || (''tAfter.%Get("Enabled") '= 0) || (tAfter.%Get("Resource") '= "") {
                Set tProblem = tProblem _ $Select(tProblem = "": "", 1: "; ") _ ..WriteTarget() _ " was put back, but not disabled, with no resource and recorded as this install's own"
            }
        }
    } Catch exRestore {
        Set tProblem = tProblem _ $Select(tProblem = "": "", 1: "; ") _ "putting " _ ..WriteTarget() _ " back raised " _ exRestore.DisplayString()
    }
    Do ..RestoreWriteTarget("", "", tTurnKey)
    If tSkip '= "" {
        Do ..Note(.pChecks, "agentdelete", "skipped", tSkip)
    } ElseIf tProblem '= "" {
        Do ..Note(.pChecks, "agentdelete", "fail", tProblem)
    } Else {
        Do ..Note(.pChecks, "agentdelete", "pass", "a destructive webapp.list.delete proposal was minted and confirmed, " _ ..WriteTarget() _ " was gone, and install's own creator put it back")
    }
}

/// <p>The web application AD-25's demo fixture creates and the <code>agentwrite</code> check
/// writes to. Overridable so <class>OcuPilot.Test.Smoke</class> can drive the same check against
/// an application whose spelling is not its own fold; production never overrides it.</p>
ClassMethod WriteTarget() As %String
{
    Quit ##class(OcuPilot.Install.Fixture).#APPPATH
}

/// <p>Whether this install's own inventory records <method>WriteTarget</method> as a fixture it
/// created (AD-25). Overridable beside <method>WriteTarget</method>, for the same reason.</p>
ClassMethod WriteTargetOwned() As %Boolean
{
    Quit ##class(OcuPilot.Install.Fixture).WebAppOwnedByProfile("")
}

/// <p>The name <var>pPath</var>'s web application carries on this instance, <b>case-preserved</b>,
/// or <code>""</code> when the instance holds none. <class>Security.Applications</class> resolves
/// a name case-insensitively and answers the spelling it stores, which is the spelling every read
/// and every write this check makes is keyed by.</p>
/// <p>Switches to <code>%SYS</code> and restores, restoring first on the error path (AD-16).</p>
/// <p><b>Public, not <code>[ Private ]</code></b> -- the same documented deviation
/// <method>Note</method> and <method>Render</method> carry: it is the one place this class decides
/// what a web application is called, and <class>OcuPilot.Test.Smoke</class> asserts its answer
/// against an application the instance spells in mixed case. It resolves nothing and writes
/// nothing.</p>
ClassMethod ApplicationName(pPath As %String) As %String
{
    Set tName = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(pPath, .tApp, .tSC), $IsObject(tApp) Set tName = tApp.Name
        Set tApp = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tName = ""
    }
    Quit tName
}

/// <p>Put <var>pBody</var> back on <var>pName</var>, and remove the turn row <var>pTurnKey</var>
/// and its proposals. <var>pBody</var> is the instance's own record of the application with the two
/// fields this check changes returned to the state <method>OcuPilot.Install.Fixture.CreateWebApp</method>
/// creates -- <b>a <class>%DynamicObject</class>, never its JSON text</b>: the port's body is
/// parsed by the vendor endpoint, which reads a string as carrying no properties at all and
/// answers 200 having written nothing.</p>
/// <p><b>Best effort, and silent.</b> It reports nothing of its own: a restore that failed does
/// not change what the checks above observed, and the next run reads a fixture that is not in its
/// created state and fails naming that, which is where a failed restore surfaces.</p>
ClassMethod RestoreWriteTarget(pName As %String = "", pBody As %DynamicObject = "", pTurnKey As %String = "") [ Private ]
{
    Try {
        If (pName '= "") && $IsObject(pBody) {
            Kill tQuery
            Set tQuery(##class(OcuPilot.Screen.Tool.Write).IdParam()) = pName
            Do ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "PUT", .tQuery, pBody, .tWritten, .tHttp, .tFault)
        }
    } Catch {
    }
    Try {
        If pTurnKey '= "" {
            Do ##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForTurn(pTurnKey)
            Do ##class(OcuPilot.Kernel.State.Turn).GuardedDelete(pTurnKey)
        }
    } Catch {
    }
}

/// <p>The audit database's own clock, in the form <code>%SYS.Audit.UTCTimeStamp</code> carries --
/// the lower bound the marker read below is bounded by.</p>
/// <p><b>Truncated to whole seconds deliberately.</b> That column is <class>%String</class>
/// (<code>%SYS.Audit.cls</code>), so <code>&gt;=</code> compares lexicographically, and a bound
/// carrying more fractional digits than the stored value sorts <i>after</i> the very row it must
/// include. This build writes three fractional digits, so the widths happen to agree today --
/// which is a measurement, not a contract, and widening the bound costs nothing because the
/// proposal id and not the time is what identifies the row.</p>
ClassMethod AuditNow() As %String [ Private ]
{
    Quit $ZDateTime($ZTimeStamp, 3, , 0)
}

/// <p>How many <code>AgentWrite</code> rows the audit database holds since <var>pSince</var>
/// carrying <var>pProposalId</var>, or <code>-1</code> when the read itself failed.</p>
/// <p><b>Bounded by <code>UTCTimeStamp</code> and <code>%NOINDEX</code> on the event predicates</b>
/// (DW-85): the table's event indexes are brought up to date by a background pass, so a row this
/// process has just written is not yet in them, and an indexed read would answer zero for a marker
/// that landed.</p>
ClassMethod MarkerRows(pSince As %String, pProposalId As %String) As %Integer [ Private ]
{
    If pProposalId = "" Quit -1
    Set tSource = ##class(OcuPilot.Kernel.Audit.Event).Source()
    Set tType = ##class(OcuPilot.Kernel.Audit.Event).Type()
    Set tEvent = ##class(OcuPilot.Kernel.Audit.Event).#EVENTAGENTWRITE
    Set tRows = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT EventData FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = ? AND %NOINDEX EventType = ? AND %NOINDEX Event = ?", pSince, tSource, tType, tEvent)
        If tRS.%SQLCODE >= 0 {
            Set tRows = 0
            While tRS.%Next() {
                If tRS.%Get("EventData") [ pProposalId Set tRows = tRows + 1
            }
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tRows = -1
    }
    Quit tRows
}

/// <p>Render the report and decide the verdict. One line per check, the counts last, and the
/// counts are printed whether the run passed or failed -- a gate that cannot say how much it
/// looked at cannot be told apart from one that looked at nothing.</p>
/// <p><b>Public, not <code>[ Private ]</code></b>, for the reason <method>Note</method> is: it
/// is the verdict rule, and <class>OcuPilot.Test.Smoke</class> drives it directly over check
/// sets no real instance produces.</p>
ClassMethod Render(ByRef pChecks, pOrigin As %String, Output pReport As %String, Output pCounts As %String) As %Boolean
{
    Set tPass = 0, tFail = 0, tPending = 0, tSkipped = 0
    Set pReport = "ocupilot-smoke: " _ pOrigin
    Set tN = $Order(pChecks(""))
    While tN '= "" {
        Set tOutcome = pChecks(tN, "outcome")
        Set tReason = pChecks(tN, "reason")
        ; Padded on the RIGHT to a fixed column, so the outcomes are left-aligned and the check
        ; names line up in a terminal. $Justify pads on the left, which would right-align them.
        Set pReport = pReport _ $Char(10) _ "  " _ $Extract(tOutcome _ "         ", 1, 9) _ pChecks(tN, "name") _ $Select(tReason = "": "", 1: " -- " _ tReason)
        If tOutcome = "pass" Set tPass = tPass + 1
        If tOutcome = "fail" Set tFail = tFail + 1
        If tOutcome = "pending" Set tPending = tPending + 1
        If tOutcome = "skipped" Set tSkipped = tSkipped + 1
        ; Fail closed on an outcome outside the four this class writes. Counted as nothing, a
        ; mistyped or empty outcome lowers the executed count silently and can never fail the
        ; run -- which is the vacuous pass this whole class exists to make impossible.
        ; $ListFind, not the [ operator: [ is a substring test, so "ass" and "" both match.
        If '$ListFind($ListBuild("pass", "fail", "pending", "skipped"), tOutcome) Set tFail = tFail + 1
        Set tN = $Order(pChecks(tN))
    }
    Set tExecuted = tPass + tFail
    Set pCounts = "executed=" _ tExecuted _ " passed=" _ tPass _ " failed=" _ tFail _ " pending=" _ tPending _ " skipped=" _ tSkipped
    Set tOk = (tExecuted > 0) && (tFail = 0)
    Set pReport = pReport _ $Char(10) _ "ocupilot-smoke: " _ pCounts
    If tExecuted = 0 {
        Set pReport = pReport _ $Char(10) _ "ocupilot-smoke: FAILED -- this run executed 0 checks, which is a failure and never a pass"
    } ElseIf 'tOk {
        Set pReport = pReport _ $Char(10) _ "ocupilot-smoke: FAILED -- " _ tFail _ " check(s) failed; the first is named above"
    } Else {
        Set pReport = pReport _ $Char(10) _ "ocupilot-smoke: PASSED"
    }
    Quit tOk
}

}
