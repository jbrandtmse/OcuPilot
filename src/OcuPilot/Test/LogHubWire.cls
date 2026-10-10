/// <p>Story 16.9 over the wire (AC6, AC10): the log hub's route and its read tool answer the same
/// seeded entry and the same per-source summary, and a <code>%Manager</code> +
/// <code>%DB_HSCUSTOM</code> principal, who holds no <code>%Ens_EventLog:USE</code>, is served the
/// hub with the event log left out and named, while messages.log, alerts.log and the Logs area stay
/// open (AD-8 as amended for DW-1755).</p>
/// <p>It writes one interoperability event in HSCUSTOM, by <class>OcuPilot.Test.LogSecondarySeed</class>'s
/// event log recipe, and creates one IRIS user, so it runs only where
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>SEEDVARIABLE</parameter> read 1 -- a
/// <file>scripts/ci-throwaway.sh</file> container -- and removes both in
/// <method>OnAfterAllTests</method>, or at once when the setup fails. It needs a configured test
/// account (<class>OcuPilot.Test.Http</class>) that reads every Logs source.</p>
Class OcuPilot.Test.LogHubWire Extends %UnitTest.TestCase
{

/// <p>The variable that arms this class: it creates a principal, as
/// <class>OcuPilot.Test.WireSecurityRead</class> does.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The variable that arms seeding the event log, as it arms
/// <class>OcuPilot.Test.LogSecondaryWire</class>.</p>
Parameter SEEDVARIABLE = "OCUPILOT_ALLOW_LOG_ROTATION";

/// <p>The namespace the event is seeded in.</p>
Parameter NAMESPACE = "HSCUSTOM";

/// <p>The text the seeded event carries.</p>
Parameter MARKER = "OcuPilotLogHubWire seeded event";

/// <p>The least-privileged principal: <code>%Manager</code> and <code>%DB_HSCUSTOM</code>.</p>
Parameter MANAGERUSER = "OcuPilotHubManager";

/// <p>The principal's roles.</p>
Parameter MANAGERROLES = "%Manager,%DB_HSCUSTOM";

/// <p>The principal that holds <code>%Ens_EventLog:USE</code> but not <code>%Ens_Portal:USE</code>.</p>
Parameter EVENTONLYUSER = "OcuPilotHubEventOnly";

/// <p>The role granting <parameter>EVENTONLYUSER</parameter> its one Ensemble resource.</p>
Parameter EVENTONLYROLE = "OcuPilotHubEventOnlyRole";

/// <p>The principal's password for this run, generated in <method>OnBeforeAllTests</method>.</p>
Property PreparedPassword As %String;

/// <p>The seeded event's id, <code>""</code> until it is written.</p>
Property PreparedEventId As %String;

/// <p>Whether the event log held nothing before the seed.</p>
Property PreparedEventEmpty As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedEventId = ""
    Set ..PreparedEventEmpty = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LogHubWire writes an interoperability event and creates IRIS users and a role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#SEEDVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LogHubWire writes an interoperability event on this instance and runs on a throwaway container only. " _ ..#SEEDVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Kill ^||OcuPilotLogHubWire
        Set ..PreparedEventEmpty = '$Data(^Ens.Util.LogD)
        For tType = 2, 3 {
            Merge ^||OcuPilotLogHubWire("monitor", tType) = ^IRIS.Temp.EnsLogMonitor(..#NAMESPACE, tType)
            Set ^||OcuPilotLogHubWire("held", tType) = ''$Data(^IRIS.Temp.EnsLogMonitor(..#NAMESPACE, tType))
        }
        Do ##class(Ens.Util.Log).LogError("OcuPilot.Test.LogHubWire", "Seed", ..#MARKER)
        Set ..PreparedEventId = $Order(^Ens.Util.LogD(""), -1)

        Set ..PreparedPassword = "OcuPilotHub" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#MANAGERUSER, .tUser, .tUserSC) Do ##class(Security.Users).Delete(..#MANAGERUSER)
        Set tSC = ##class(Security.Users).Create(..#MANAGERUSER, ..#MANAGERROLES, ..PreparedPassword, "OcuPilot log hub test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.LogHubWire; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#EVENTONLYUSER, .tUser3, .tUserSC3) Do ##class(Security.Users).Delete(..#EVENTONLYUSER)
        If ##class(Security.Roles).Exists(..#EVENTONLYROLE, .tRole, .tRoleSC) Do ##class(Security.Roles).Delete(..#EVENTONLYROLE)
        Set tSC = ##class(Security.Roles).Create(..#EVENTONLYROLE, "OcuPilot test: log hub event-log-only role (throwaway)", "%Ens_EventLog:U", "")
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Users).Create(..#EVENTONLYUSER, ..#MANAGERROLES _ "," _ ..#EVENTONLYROLE, ..PreparedPassword, "OcuPilot log hub test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.LogHubWire; deleted in OnAfterAllTests")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    ; The framework calls no OnAfterAllTests after a failed OnBeforeAllTests, so undo the seed here.
    If $$$ISERR(tSC) Do ..OnAfterAllTests()
    Quit tSC
}

/// <p>Remove the seeded event and the principal, restoring what the seed displaced, and return a
/// failing status when either survives.</p>
Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If ..PreparedEventId '= "" Do ##class(Ens.Util.Log).%DeleteId(..PreparedEventId)
        If ..PreparedEventEmpty Kill ^Ens.Util.LogD, ^Ens.Util.LogI
        For tType = 2, 3 {
            Kill ^IRIS.Temp.EnsLogMonitor(..#NAMESPACE, tType)
            If $Get(^||OcuPilotLogHubWire("held", tType)) Merge ^IRIS.Temp.EnsLogMonitor(..#NAMESPACE, tType) = ^||OcuPilotLogHubWire("monitor", tType)
        }
        Kill ^||OcuPilotLogHubWire
        Set tLeft = ""
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Ens_Util.Log WHERE Text = ?", ..#MARKER)
        If tResult.%Next() && (+tResult.%GetData(1) > 0) Set tLeft = "the seeded event"
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#MANAGERUSER, .tUser, .tUserSC) Do ##class(Security.Users).Delete(..#MANAGERUSER)
        If ##class(Security.Users).Exists(..#MANAGERUSER, .tUser2, .tUserSC2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ ..#MANAGERUSER
        If ##class(Security.Users).Exists(..#EVENTONLYUSER, .tUser3, .tUserSC3) Do ##class(Security.Users).Delete(..#EVENTONLYUSER)
        If ##class(Security.Users).Exists(..#EVENTONLYUSER, .tUser4, .tUserSC4) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "user " _ ..#EVENTONLYUSER
        If ##class(Security.Roles).Exists(..#EVENTONLYROLE, .tRole, .tRoleSC) Do ##class(Security.Roles).Delete(..#EVENTONLYROLE)
        If ##class(Security.Roles).Exists(..#EVENTONLYROLE, .tRole2, .tRoleSC2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ ..#EVENTONLYROLE
        Set $NAMESPACE = tOrigNS
        If tLeft '= "" Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.LogHubWire left on the instance: " _ tLeft)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Request <var>pPath</var> as <var>pUser</var>, the configured test account when empty.</p>
Method Fetch(pPath As %String, Output pStatus As %Integer, Output pBody As %String, pUser As %String = "") As %Status
{
    If pUser = "" Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBody, .tHeaders)
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", pPath, pUser, ..PreparedPassword, .pStatus, .pBody, .tHeaders)
}

/// <p><var>pAnswer</var>'s row carrying the seeded event, as JSON, or <code>""</code>.</p>
ClassMethod SeededRow(pAnswer As %DynamicObject) As %String
{
    Set tFound = ""
    Set tIterator = pAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.source = "logs/eventlog") && (tRow.text [ ..#MARKER) Set tFound = tRow.%ToJSON()
    }
    Quit tFound
}

/// <p>Each summary of <var>pAnswer</var> as <code>route=shown/requires</code>, comma-separated.</p>
ClassMethod Shown(pAnswer As %DynamicObject) As %String
{
    Set tOut = ""
    Set tIterator = pAnswer.sources.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tSource) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tSource.source _ "=" _ tSource.shown _ "/" _ tSource.requires
    }
    Quit tOut
}

/// <p><var>pAnswer</var>'s summary for <var>pRoute</var>, or <code>""</code>.</p>
ClassMethod Source(pAnswer As %DynamicObject, pRoute As %String) As %DynamicObject
{
    Set tFound = ""
    Set tIterator = pAnswer.sources.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tSource) {
        If tSource.source = pRoute Set tFound = tSource
    }
    Quit tFound
}

/// <p>AC10 -- the route and the <code>logs.hub.read</code> tool answer the same seeded entry and the
/// same summary of which sources are shown. Their event-log summaries come from reads taken one
/// after the other, not from one: the merged answer is cut to the newest 200 rows and a read adds
/// audit entries newer than every event-log row, so a later read counts at most as many event-log
/// rows as an earlier one, whatever else wrote to the event log before this class ran. A route
/// read, the tool's view and a second route read therefore show counts that do not rise and newest
/// events that do not fall.</p>
/// <p>Mutation (Rule 19): drop <code>sources</code> from
/// <method>OcuPilot.Screen.Tool.Read.View</method> -&gt; this goes red; give the view's event-log
/// summary a count of 9999 and a newest event in year 9999 -&gt; the two upper-bound legs go red; a
/// count of 1 and a newest event in 1970 -&gt; the two lower-bound legs go red; leave
/// <method>OcuPilot.Screen.Timeline.Compose</method>'s counts at 0 -&gt; the two "at least 1" legs go red.</p>
Method TestTheRouteAndTheToolAnswerTheSameEntriesAndSources()
{
    Set tPath = "/api/ocupilot/screens/logs.hub/read?maxRows=200"
    Set tSC = ..Fetch(tPath, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "the route request completes")
    Do $$$AssertEquals(tStatus, 200, "the route answers 200")
    Do $$$AssertEquals((tBody [ "}{"), 0, "in exactly one envelope")
    If tStatus '= 200 Quit
    Set tRoute = ##class(%DynamicObject).%FromJSON(tBody)
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View("OcuPilot.Screen.Descriptor.LogHub", {"maxRows": 200}, 200, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the tool's view answers")
    If '$IsObject($Get(tView)) Quit
    Do $$$AssertTrue($IsObject(tView.%Get("sources")), "the tool's view carries sources")
    If '$IsObject(tView.%Get("sources")) Quit
    Set tSC = ..Fetch(tPath, .tAfterStatus, .tAfterBody)
    Do $$$AssertStatusOK(tSC, "a second route request, taken after the tool's view, completes")
    Do $$$AssertEquals(tAfterStatus, 200, "and answers 200")
    If tAfterStatus '= 200 Quit
    Set tAfter = ##class(%DynamicObject).%FromJSON(tAfterBody)
    Set tSeeded = ..SeededRow(tRoute)
    Do $$$AssertTrue(tSeeded '= "", "the route's timeline holds the seeded event")
    Do $$$AssertEquals(..SeededRow(tView), tSeeded, "and the tool's the same row")
    Do $$$AssertEquals(..Shown(tView), ..Shown(tRoute), "the same sources are shown")
    Set tRouteEvent = ..Source(tRoute, "logs/eventlog")
    Set tViewEvent = ..Source(tView, "logs/eventlog")
    Set tAfterEvent = ..Source(tAfter, "logs/eventlog")
    Do $$$AssertTrue($IsObject(tRouteEvent) && $IsObject(tViewEvent) && $IsObject(tAfterEvent), "all three summarize the event log")
    If $IsObject(tRouteEvent) && $IsObject(tViewEvent) && $IsObject(tAfterEvent) {
        Do $$$AssertTrue(tRouteEvent.count >= 1, "the route counts the seeded event")
        Do $$$AssertTrue(tViewEvent.count >= 1, "and so does the tool")
        Do $$$AssertTrue(tViewEvent.count <= tRouteEvent.count, "the tool, read after the route, counts no more event-log rows than the route did: " _ tViewEvent.count _ " against " _ tRouteEvent.count)
        Do $$$AssertTrue(tAfterEvent.count <= tViewEvent.count, "and no fewer than a route read taken after it: " _ tViewEvent.count _ " against " _ tAfterEvent.count)
        Set tRouteLast = $Select($IsObject(tRouteEvent.last): tRouteEvent.last.time, 1: "")
        Set tViewLast = $Select($IsObject(tViewEvent.last): tViewEvent.last.time, 1: "")
        Set tAfterLast = $Select($IsObject(tAfterEvent.last): tAfterEvent.last.time, 1: "")
        Do $$$AssertTrue((tRouteLast '= "") && (tViewLast '= "") && '(tRouteLast ] tViewLast), "the tool's newest event is not older than the route's read before it: " _ tViewLast _ " against " _ tRouteLast)
        Do $$$AssertTrue((tViewLast '= "") && (tAfterLast '= "") && '(tViewLast ] tAfterLast), "and not newer than a route read taken after it: " _ tViewLast _ " against " _ tAfterLast)
    }
}

/// <p>AC5 (AD-21) -- a caller cannot name a source, a file or a namespace: those parameters are
/// not criteria the hub declares, so the route reads past them and answers every member, the
/// seeded event log entry included.</p>
Method TestACallerCannotNameASourceFileOrNamespace()
{
    Set tSC = ..Fetch("/api/ocupilot/screens/logs.hub/read?maxRows=200&source=logs%2Fxdbc&file=messages.log&namespace=USER", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the route answers 200: " _ $Extract(tBody, 1, 200))
    If tStatus '= 200 Quit
    Set tNamed = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tNamed.sources.%Size(), 10, "every member is summarized")
    Do $$$AssertTrue(..SeededRow(tNamed) '= "", "and the event log's seeded entry is on the timeline, though the caller named xdbc, a file and USER")
}

/// <p>AC6 -- a <code>%Manager</code> + <code>%DB_HSCUSTOM</code> principal holds no
/// <code>%Ens_EventLog:USE</code>: the hub answers 200 with the event log not shown, naming that
/// pair, and none of its rows; messages.log and alerts.log are shown and served; the Logs area
/// reads allowed.</p>
/// <p>Mutation (Rule 19): add <code>%Ens_EventLog:USE</code> to the hub's privileges -&gt; the hub
/// answers 403 and this goes red.</p>
Method TestAManagerPrincipalIsServedTheHubWithoutTheEventLog()
{
    Do $$$AssertNotEquals($SYSTEM.Security.CheckUserPermission(..#MANAGERUSER, "%Ens_EventLog", "USE"), 1, ..#MANAGERUSER _ " holds no %Ens_EventLog:USE")
    Set tSC = ..Fetch("/api/ocupilot/screens/logs.hub/read?maxRows=200", .tStatus, .tBody, ..#MANAGERUSER)
    Do $$$AssertStatusOK(tSC, "the hub request completes")
    Do $$$AssertEquals(tStatus, 200, "the hub answers 200: " _ $Extract(tBody, 1, 200))
    If tStatus '= 200 Quit
    Set tHub = ##class(%DynamicObject).%FromJSON(tBody)
    Set tEvent = ..Source(tHub, "logs/eventlog")
    Do $$$AssertEquals($Select($IsObject(tEvent): tEvent.shown _ "|" _ tEvent.requires, 1: ""), "0|%Ens_EventLog:USE", "the event log is left out, naming its pair")
    Do $$$AssertEquals(..SeededRow(tHub), "", "and none of its rows reach the timeline")
    For tRoute = "logs/messages", "logs/alerts" {
        Set tSource = ..Source(tHub, tRoute)
        Do $$$AssertEquals($Select($IsObject(tSource): tSource.shown, 1: ""), 1, tRoute _ " is shown")
    }
    For tPath = "/api/ocupilot/screens/logs.messages/read?maxRows=5", "/api/ocupilot/screens/logs.alerts/read?maxRows=5" {
        Set tSC = ..Fetch(tPath, .tPathStatus, .tPathBody, ..#MANAGERUSER)
        Do $$$AssertEquals(tPathStatus, 200, tPath _ ": served")
    }
    Set tSC = ..Fetch("/api/ocupilot/navigation", .tNavStatus, .tNavBody, ..#MANAGERUSER)
    Set tVerdict = ""
    If tNavStatus = 200 {
        Set tIterator = ##class(%DynamicObject).%FromJSON(tNavBody).areas.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tArea) {
            If tArea.key = "logs" Set tVerdict = $Select(tArea.allowed: "true", 1: "false")
        }
    }
    Do $$$AssertEquals(tVerdict, "true", "the Logs area reads allowed")
}

/// <p>DW-1921 -- a principal holding <code>%Ens_EventLog:USE</code> and read on HSCUSTOM's database
/// without <code>%Ens_Portal:USE</code> is served the hub with the event log not shown, naming
/// <code>%Ens_Portal:USE</code>, the pair the classic event log page also requires.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_Portal:USE</code> from both
/// <parameter>OcuPilot.Port.LogSourcePort.EVENTLOGPAIRS</parameter> and
/// <class>OcuPilot.Screen.Descriptor.LogEventViewer</class>'s <code>privileges</code>, the two places
/// the hub's gate reads it from -&gt; the event log is shown and this goes red; dropping only one
/// leaves it green.</p>
Method TestAHolderOfTheEventLogResourceAloneIsToldThePortalPair()
{
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#EVENTONLYUSER, "%Ens_EventLog", "USE"), 1, ..#EVENTONLYUSER _ " holds %Ens_EventLog:USE")
    Do $$$AssertNotEquals($SYSTEM.Security.CheckUserPermission(..#EVENTONLYUSER, "%Ens_Portal", "USE"), 1, "and not %Ens_Portal:USE")
    Set tSC = ..Fetch("/api/ocupilot/screens/logs.hub/read?maxRows=200", .tStatus, .tBody, ..#EVENTONLYUSER)
    Do $$$AssertStatusOK(tSC, "the hub request completes")
    Do $$$AssertEquals(tStatus, 200, "the hub answers 200: " _ $Extract(tBody, 1, 200))
    If tStatus '= 200 Quit
    Set tEvent = ..Source(##class(%DynamicObject).%FromJSON(tBody), "logs/eventlog")
    Do $$$AssertEquals($Select($IsObject(tEvent): tEvent.shown _ "|" _ tEvent.requires, 1: ""), "0|%Ens_Portal:USE", "the event log is left out, naming the portal pair")
}

}
