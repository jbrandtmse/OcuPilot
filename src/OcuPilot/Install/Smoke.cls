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

/// <p>Run the smoke checks against this instance and report.</p>
/// <p><var>pUsername</var> and <var>pPassword</var> are the credentials the sign-in check mints
/// a token pair with; supplying none skips that check, the three reads that need its token and
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
        Do ..CheckDemoFixture(.tChecks, pDemo)
        Do ..AddPending(.tChecks)
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
/// <var>pAccessToken</var> is what the three reads below carry and <var>pRefreshToken</var> is
/// what <method>CheckSignOut</method> proves dead; with no credentials supplied this is skipped
/// and so are they.</p>
ClassMethod CheckSignIn(ByRef pChecks, pUsername As %String, pPassword As %String, Output pAccessToken As %String, Output pRefreshToken As %String) [ Private ]
{
    Set pAccessToken = ""
    Set pRefreshToken = ""
    If pUsername = "" {
        Do ..Note(.pChecks, "signin", "skipped", "no credentials were supplied to this run, so no token pair was minted and the three API reads below were not attempted")
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

/// <p>OcuPilot's own audit event is registered with <code>Security.Events</code>. An
/// unregistered triple makes <code>$System.Security.Audit</code> return 0 and drop the event
/// with no error and no log line, so this is the check that keeps every later audit assertion
/// from being vacuous.</p>
ClassMethod CheckAuditEvent(ByRef pChecks) [ Private ]
{
    ; The three parameter reads happen BEFORE the switch. A fresh ##class(OcuPilot.*) dispatch
    ; issued while $NAMESPACE is %SYS raises <CLASS DOES NOT EXIST> -- OcuPilot's code is mapped
    ; nowhere but the install namespace (OcuPilot.Install.Installer's own header). Reading them
    ; inside the switched window made this check report "not registered" for an event that was.
    Set tSource = ##class(OcuPilot.Kernel.State.Base).#AUDITSOURCE
    Set tType = ##class(OcuPilot.Kernel.State.Base).#AUDITTYPE
    Set tName = ##class(OcuPilot.Kernel.State.Base).#AUDITNAME
    Set tOrigNS = $NAMESPACE
    Set tExists = 0
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Security.Events).Exists(tSource, tType, tName, .tObj, .tSC)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tExists = 0
    }
    If 'tExists {
        Do ..Note(.pChecks, "auditevent", "fail", "OcuPilot's audit event is not registered, so every audit row it would write is dropped silently")
        Quit
    }
    Do ..Note(.pChecks, "auditevent", "pass")
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

/// <p>The checks this instance cannot make yet, each naming the epic that makes it real. They
/// are listed rather than omitted so the report is honest about its own coverage, and they
/// never move the verdict.</p>
ClassMethod AddPending(ByRef pChecks) [ Private ]
{
    Do ..Note(.pChecks, "arealists", "pending", "one live list per portal area -- Epic 2 turns each area's first live list into a real check here")
    Do ..Note(.pChecks, "agentwrite", "pending", "a confirmed agent write, proposed, reviewed and applied -- Epic 3")
    Do ..Note(.pChecks, "auditmarker", "pending", "the audit row that write leaves behind -- Epic 3")
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
