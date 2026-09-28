/// <p>Home's Findings panel (Story 16.21): nine checks over settings that put the instance at risk
/// or stop it working, answered by <class>OcuPilot.Api.UiFindings</class> as
/// <code>GET /api/ocupilot/ui/findings</code>. It is shell chrome, like <code>/ui/system</code>: not
/// a screen, a declared read, a tool or screen context (AD-24), and nothing re-reads it on a
/// tick (AD-43).</p>
/// <p><b>Each check is read as the caller through its owning screen</b> (AD-8, AD-29): that
/// screen's pair gate (<method>OcuPilot.Kernel.Shell.Effective.Gate</method>), then its declared read
/// (AD-36), then any per-row detail call through the port the way
/// <class>OcuPilot.Kernel.Proposal.Impact</class> makes it. A check the caller may not read is
/// <parameter>STATUSUNCHECKED</parameter> naming the pair, a read cut at its cap is
/// <parameter>STATUSTRUNCATED</parameter>, and a source that raises is
/// <parameter>STATUSFAILED</parameter> and logged once (<class>OcuPilot.Kernel.Shell.FieldRead</class>).
/// Only a <parameter>STATUSCHECKED</parameter> check may say there is nothing to report, and only
/// it contributes findings.</p>
/// <p>The answer is <code>{checks: [{check, group, status, pair?}], findings: [{check, group, name,
/// id, route, scope, detail?, expired?, fix, refused?}]}</code>. <code>fix</code> is
/// <parameter>FIXAGENT</parameter> where a write tool fixes the finding,
/// <parameter>FIXLINK</parameter> where none does yet, and <parameter>FIXREFUSED</parameter> with
/// <code>refused: {code, reason}</code> where the prohibited set refuses it, the reason being
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ReasonFor</method>'s own sentence (AD-10, AD-53).</p>
Class OcuPilot.Kernel.Shell.Findings Extends OcuPilot.Kernel.Shell.FieldRead
{

Parameter LOGSUBSYSTEM = "uifindings";

Parameter LOGMESSAGE = "A findings check could not be read";

Parameter GROUPSECURITY = "security";

Parameter GROUPOPERATIONS = "operations";

Parameter STATUSCHECKED = "checked";

Parameter STATUSUNCHECKED = "unchecked";

Parameter STATUSTRUNCATED = "truncated";

Parameter STATUSFAILED = "failed";

Parameter FIXAGENT = "agent";

Parameter FIXLINK = "link";

Parameter FIXREFUSED = "refused";

/// <p>Every finding's scope: each object checked is instance configuration (AD-13).</p>
Parameter SCOPE = "instance";

/// <p>A mounted database at or above this percent of its maximum size is a finding: the warning
/// bound of the client's <code>meter-state.ts</code>.</p>
Parameter FULLPERCENT As INTEGER = 85;

/// <p>A certificate expiring within this many days of now is a finding.</p>
Parameter EXPIRYDAYS As INTEGER = 30;

/// <p>The <code>AutheEnabled</code> bit that lets a web application answer without signing in.</p>
Parameter UNAUTHENTICATEDBIT As INTEGER = 64;

/// <p>The dispatch class of the monitoring API's application, which is reported by its own check
/// and never by the general one.</p>
Parameter MONITORDISPATCH = "%Api.Monitor";

Parameter ALLROLE = "%All";

/// <p>The <code>Error</code> the vendor records for a task whose last run succeeded.</p>
Parameter TASKSUCCESS = "Success";

/// <p>The prefix every mounted database's <code>Status</code> carries (<code>Mounted/RW</code>,
/// <code>Mounted/R</code>).</p>
Parameter MOUNTEDPREFIX = "Mounted";

/// <p>The two Task schedule banner keys that say the Task Manager is not running tasks.</p>
Parameter SUSPENDEDBANNER = "taskManagerSuspendedBanner";

Parameter STOPPEDBANNER = "taskManagerStoppedBanner";

Parameter WEBAPPDESCRIPTOR = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter USERDESCRIPTOR = "OcuPilot.Screen.Descriptor.UserList";

Parameter X509DESCRIPTOR = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter AUDITINGDESCRIPTOR = "OcuPilot.Screen.Descriptor.AuditingConfig";

Parameter DATABASEDESCRIPTOR = "OcuPilot.Screen.Descriptor.DatabaseList";

Parameter DATABASEDETAILSDESCRIPTOR = "OcuPilot.Screen.Descriptor.DatabaseDetails";

Parameter TASKDESCRIPTOR = "OcuPilot.Screen.Descriptor.TaskScheduleList";

Parameter TASKDETAILSDESCRIPTOR = "OcuPilot.Screen.Descriptor.TaskDetails";

Parameter WEBAPPENDPOINT = "WebApp.App";

Parameter WEBAPPIDPARAM = "name";

Parameter TASKENDPOINT = "Task.CRUD";

Parameter TASKINFOTYPE = "INFO";

Parameter TASKIDPARAM = "id";

/// <p>The write tool whose <code>remove-role</code> action a <code>%All</code> holder's refusal is
/// asked over.</p>
Parameter USERTOOLCLASS = "OcuPilot.Screen.Tool.UserUpdate";

Parameter REMOVEROLEACTION = "remove-role";

/// <p>The nine checks, in the order the answer lists them.</p>
ClassMethod Members() As %List
{
    Quit $ListBuild("webapp-open", "monitor-open", "all-holder", "certificate", "auditing-off", "database-dismounted", "database-full", "task-manager", "task-error")
}

/// <p>The group <var>pCheck</var> belongs to.</p>
ClassMethod GroupOf(pCheck As %String) As %String
{
    If $ListFind($ListBuild("webapp-open", "monitor-open", "all-holder", "certificate", "auditing-off"), pCheck) Quit ..#GROUPSECURITY
    Quit ..#GROUPOPERATIONS
}

/// <p>The port every per-row detail call and the refusal's fresh read go through.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>AD-10's prohibited set, the one the write path asks.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>Run the nine checks, writing nothing, into <var>pAnswer</var>. A check whose source raised
/// is <parameter>STATUSFAILED</parameter> and the other checks still answer; the status reports
/// only whether the answer could be built.</p>
ClassMethod Read(Output pAnswer As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Try {
        Set tChecks = []
        Set tFindings = []
        Kill tContext
        Set tMembers = ..Members()
        For tI = 1:1:$ListLength(tMembers) {
            Set tCheck = $List(tMembers, tI)
            Set tOne = ..Parsed(..Field(tCheck, .tContext))
            Set tRow = {}
            Do tRow.%Set("check", tCheck, "string")
            Do tRow.%Set("group", ..GroupOf(tCheck), "string")
            If '$IsObject(tOne) {
                Do tRow.%Set("status", ..#STATUSFAILED, "string")
                Do tChecks.%Push(tRow)
                Continue
            }
            Do tRow.%Set("status", tOne.%Get("status"), "string")
            If tOne.%Get("pair") '= "" Do tRow.%Set("pair", tOne.%Get("pair"), "string")
            Do tChecks.%Push(tRow)
            If tOne.%GetTypeOf("findings") '= "array" Continue
            Set tIterator = tOne.%Get("findings").%GetIterator()
            While tIterator.%GetNext(.tIndex, .tFinding) {
                If $IsObject(tFinding) Do tFindings.%Push(tFinding)
            }
        }
        Set pAnswer = {}
        Do pAnswer.%Set("checks", tChecks)
        Do pAnswer.%Set("findings", tFindings)
    } Catch ex {
        Set pAnswer = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One check's <code>{status, pair?, findings}</code> as JSON text, or <code>""</code> for an
/// unknown check. A source that answers an error status raises it, so <method>Field</method> logs
/// it and the check reads <parameter>STATUSFAILED</parameter>. <var>pContext</var> holds the reads
/// two checks share, so each is made once.</p>
ClassMethod ReadSource(pField As %String, ByRef pContext) As %String
{
    Set tOut = {"status": (..#STATUSCHECKED), "pair": "", "findings": []}
    If pField = "webapp-open" {
        $$$ThrowOnError(..OpenApplications(tOut, .pContext))
    } ElseIf pField = "monitor-open" {
        $$$ThrowOnError(..MonitorOpen(tOut, .pContext))
    } ElseIf pField = "all-holder" {
        $$$ThrowOnError(..AllHolders(tOut, .pContext))
    } ElseIf pField = "certificate" {
        $$$ThrowOnError(..Certificates(tOut, .pContext))
    } ElseIf pField = "auditing-off" {
        $$$ThrowOnError(..AuditingOff(tOut, .pContext))
    } ElseIf (pField = "database-dismounted") || (pField = "database-full") {
        $$$ThrowOnError(..Databases(pField, tOut, .pContext))
    } ElseIf pField = "task-manager" {
        $$$ThrowOnError(..TaskManager(tOut, .pContext))
    } ElseIf pField = "task-error" {
        $$$ThrowOnError(..TaskErrors(tOut, .pContext))
    } Else {
        Quit ""
    }
    Quit tOut.%ToJSON()
}

/// <p><code>webapp-open</code>: an enabled application whose own <code>AutheEnabled</code> carries
/// <parameter>UNAUTHENTICATEDBIT</parameter> and whose application roles compose
/// (<method>OcuPilot.Kernel.Shell.Effective.Compose</method>) to <code>%All</code>, or to a letter a
/// role grants that <method>Privileged</method> names. The monitoring API is left to
/// <method>MonitorOpen</method>.</p>
ClassMethod OpenApplications(pOut As %DynamicObject, ByRef pContext) As %Status
{
    Set tSC = ..Applications(pOut, .pContext, .tApps)
    If $$$ISERR(tSC) || (pOut.%Get("status") '= ..#STATUSCHECKED) Quit tSC
    Set tOpen = []
    Set tRoots = []
    Set tIterator = tApps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tApp) {
        If 'tApp.%Get("unauthenticated") Continue
        If tApp.%Get("monitor") Continue
        If tApp.%Get("roles").%Size() = 0 Continue
        Do tOpen.%Push(tApp)
        Set tRoles = tApp.%Get("roles").%GetIterator()
        While tRoles.%GetNext(.tRoleIndex, .tRole) {
            Do tRoots.%Push(tRole)
        }
    }
    If tOpen.%Size() = 0 Quit $$$OK
    Set tSC = ..EffectiveRead(tRoots, .tRows, .tPublic, .tUnchecked)
    If $$$ISERR(tSC) Quit tSC
    If ..MarkUnread(pOut, tUnchecked) Quit $$$OK
    Set tIterator = tOpen.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tApp) {
        Set tComposed = ##class(OcuPilot.Kernel.Shell.Effective).Compose(tApp.%Get("roles"), tRows, tPublic)
        If '..Privileged(tComposed) Continue
        Set tName = tApp.%Get("name")
        Do ..Add(pOut, "webapp-open", tName, tName, $ClassMethod(..#WEBAPPDESCRIPTOR, "Route"), ..#FIXAGENT)
    }
    Quit $$$OK
}

/// <p><code>monitor-open</code>: the monitoring API's application (its dispatch class is
/// <parameter>MONITORDISPATCH</parameter>) enabled with <parameter>UNAUTHENTICATEDBIT</parameter>.</p>
ClassMethod MonitorOpen(pOut As %DynamicObject, ByRef pContext) As %Status
{
    Set tSC = ..Applications(pOut, .pContext, .tApps)
    If $$$ISERR(tSC) || (pOut.%Get("status") '= ..#STATUSCHECKED) Quit tSC
    Set tIterator = tApps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tApp) {
        If 'tApp.%Get("monitor") || 'tApp.%Get("unauthenticated") Continue
        Do ..Add(pOut, "monitor-open", tApp.%Get("name"), tApp.%Get("name"), $ClassMethod(..#WEBAPPDESCRIPTOR, "Route"), ..#FIXAGENT)
    }
    Quit $$$OK
}

/// <p>Whether <var>pComposed</var> holds <code>%All</code>, or a letter a role grants (never one
/// held only publicly) that is <code>U</code> on an <code>%Admin_*</code> or
/// <code>%Development</code> resource or <code>W</code> on a <code>%DB_*</code> resource.</p>
ClassMethod Privileged(pComposed As %DynamicObject) As %Boolean
{
    If '$IsObject(pComposed) Quit 0
    If pComposed.%Get("all") Quit 1
    Set tResources = pComposed.%Get("resources")
    If '$IsObject(tResources) Quit 0
    Set tPrivileged = 0
    Set tIterator = tResources.%GetIterator()
    While tIterator.%GetNext(.tResource, .tLetters) {
        If '$IsObject(tLetters) Continue
        Set tUpper = $ZConvert(tResource, "U")
        Set tAdministrative = ($Extract(tUpper, 1, 7) = "%ADMIN_") || (tUpper = "%DEVELOPMENT")
        Set tDatabase = ($Extract(tUpper, 1, 4) = "%DB_")
        If tAdministrative && (tLetters.%Get("U") '= "") Set tPrivileged = 1 Quit
        If tDatabase && (tLetters.%Get("W") '= "") Set tPrivileged = 1 Quit
    }
    Quit tPrivileged
}

/// <p><code>all-holder</code>: every enabled account whose <code>Roles</code> compose to
/// <code>%All</code>, with <method>RemovalVerdict</method>'s refusal where the prohibited set
/// refuses taking <code>%All</code> off it.</p>
ClassMethod AllHolders(pOut As %DynamicObject, ByRef pContext) As %Status
{
    Set tSC = ..Rows(..#USERDESCRIPTOR, pOut, .pContext, .tResult)
    If $$$ISERR(tSC) || (pOut.%Get("status") '= ..#STATUSCHECKED) Quit tSC
    Set tEnabled = []
    Set tRoots = []
    Set tIterator = tResult.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%Get("Enabled") Continue
        If tRow.%GetTypeOf("Roles") '= "array" Continue
        Do tEnabled.%Push(tRow)
        Set tRoles = tRow.%Get("Roles").%GetIterator()
        While tRoles.%GetNext(.tRoleIndex, .tRole) {
            Do tRoots.%Push(tRole)
        }
    }
    If tEnabled.%Size() = 0 Quit $$$OK
    Set tSC = ..EffectiveRead(tRoots, .tRows, .tPublic, .tUnchecked)
    If $$$ISERR(tSC) Quit tSC
    If ..MarkUnread(pOut, tUnchecked) Quit $$$OK
    Set tRoute = $ClassMethod(..#USERDESCRIPTOR, "Route")
    Set tIterator = tEnabled.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '##class(OcuPilot.Kernel.Shell.Effective).Compose(tRow.%Get("Roles"), tRows, tPublic).%Get("all") Continue
        Set tName = tRow.%Get("Name")
        Set tSC = ..RemovalVerdict(tName, .tProhibits, .tCode)
        If $$$ISERR(tSC) Quit
        Set tFinding = ..Add(pOut, "all-holder", tName, tName, tRoute, $Select(tProhibits: ..#FIXREFUSED, 1: ..#FIXAGENT))
        If tProhibits {
            Set tRefused = {}
            Do tRefused.%Set("code", tCode, "string")
            Do tRefused.%Set("reason", $ClassMethod(..ProhibitedClass(), "ReasonFor", tCode), "string")
            Do tFinding.%Set("refused", tRefused)
        }
    }
    Quit tSC
}

/// <p>Whether the prohibited set refuses the Users list's <code>remove-role</code> of
/// <parameter>ALLROLE</parameter> on <var>pUser</var>, in <var>pProhibits</var> with the code in
/// <var>pCode</var>. The target, payload and diff come from the entry points the action route's
/// preview uses (<method>OcuPilot.Kernel.Proposal.Operation.Read</method>, the tool's
/// <method>ScreenActionDelta</method>, <method>OcuPilot.Kernel.Proposal.Mint.Merge</method>); an
/// account holding <code>%All</code> only through another role has no such removal and is not
/// refused.</p>
ClassMethod RemovalVerdict(pUser As %String, Output pProhibits As %Boolean, Output pCode As %String) As %Status
{
    Set pProhibits = 0
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        Set tTool = ..#USERTOOLCLASS
        Set tDescriptor = $Parameter(tTool, "DESCRIPTORCLASS")
        Set tType = $ClassMethod(tDescriptor, "PrimaryEntityType")
        Set tId = ##class(OcuPilot.Kernel.EntityRef).NormalizedId(tType, pUser)
        Set tScope = ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(tDescriptor, "Scope"))
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key(tType, tScope, tId, .tTargetRef)
        If $$$ISERR(tSC) Quit
        Set tIdArgument = $ClassMethod(tTool, "IdArgument")
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).Read(tTool, ..PortClass(), $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), tId, "", .tFresh, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit
        Set tValues = {}
        Do tValues.%Set($List($ClassMethod(tTool, "ScreenActionValueNames", ..#REMOVEROLEACTION), 1), ..#ALLROLE, "string")
        Do tValues.%Set(tIdArgument, tId, "string")
        Set tSC = $ClassMethod(tTool, "ScreenActionDelta", ..#REMOVEROLEACTION, tValues, tFresh, .tArgs, .tProblem)
        If $$$ISERR(tSC) || (tProblem '= "") Quit
        Do tArgs.%Set(tIdArgument, tId, "string")
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(tFresh, tArgs, tIdArgument, $ClassMethod(tTool, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) || (tProblem '= "") Quit
        Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(tTool, "TOOLNAME"), tTargetRef, tPayload.%ToJSON(), tDiff.%ToJSON(), .pProhibits, .pCode)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        Set pProhibits = 0
        Set pCode = ""
    }
    Quit tSC
}

/// <p><code>certificate</code>: a credential whose <code>ValidityNotAfter</code> (UTC
/// <code>YYYY-MM-DD HH:MM:SS</code>) is earlier than <method>Now</method> (<code>expired</code>) or
/// within <parameter>EXPIRYDAYS</parameter> days of it. <code>detail</code> is its date.</p>
ClassMethod Certificates(pOut As %DynamicObject, ByRef pContext) As %Status
{
    Set tSC = ..Rows(..#X509DESCRIPTOR, pOut, .pContext, .tResult)
    If $$$ISERR(tSC) || (pOut.%Get("status") '= ..#STATUSCHECKED) Quit tSC
    Set tNow = ..Seconds(..Now())
    Set tRoute = $ClassMethod(..#X509DESCRIPTOR, "Route")
    Set tIterator = tResult.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tNotAfter = tRow.%Get("ValidityNotAfter")
        If '$Match(tNotAfter, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$") Continue
        Set tLeft = ..Seconds($ZDateTimeH(tNotAfter, 3)) - tNow
        If tLeft > (..#EXPIRYDAYS * 86400) Continue
        Set tFinding = ..Add(pOut, "certificate", tRow.%Get("Alias"), tRow.%Get("Alias"), tRoute, ..#FIXLINK)
        Do tFinding.%Set("detail", $Extract(tNotAfter, 1, 10), "string")
        Do tFinding.%Set("expired", (tLeft < 0), "boolean")
    }
    Quit $$$OK
}

/// <p><code>auditing-off</code>: the instance's auditing <code>Enabled</code> reads false.</p>
ClassMethod AuditingOff(pOut As %DynamicObject, ByRef pContext) As %Status
{
    Set tSC = ..Rows(..#AUDITINGDESCRIPTOR, pOut, .pContext, .tResult)
    If $$$ISERR(tSC) || (pOut.%Get("status") '= ..#STATUSCHECKED) Quit tSC
    Set tRows = tResult.%Get("rows")
    If tRows.%Size() = 0 Quit $$$OK
    Set tRow = tRows.%Get(0)
    If '$IsObject(tRow) || (tRow.%GetTypeOf("Enabled") = "unassigned") || tRow.%Get("Enabled") Quit $$$OK
    Do ..Add(pOut, "auditing-off", "", "", $ClassMethod(..#AUDITINGDESCRIPTOR, "Route"), ..#FIXAGENT)
    Quit $$$OK
}

/// <p><code>database-dismounted</code>: a database whose <code>Status</code> does not begin with
/// <parameter>MOUNTEDPREFIX</parameter>. <code>database-full</code>: a mounted database whose
/// numeric <code>MaxSize</code> is above 0 and whose <code>Size</code> is at least
/// <parameter>FULLPERCENT</parameter> percent of it, <code>detail</code> being the whole
/// percent.</p>
ClassMethod Databases(pCheck As %String, pOut As %DynamicObject, ByRef pContext) As %Status
{
    Set tSC = ..Rows(..#DATABASEDESCRIPTOR, pOut, .pContext, .tResult)
    If $$$ISERR(tSC) || (pOut.%Get("status") '= ..#STATUSCHECKED) Quit tSC
    Set tRoute = $ClassMethod(..#DATABASEDETAILSDESCRIPTOR, "Route")
    Set tIterator = tResult.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set tDirectory = tRow.%Get("Directory")
        Set tMounted = ($Extract(tRow.%Get("Status"), 1, $Length(..#MOUNTEDPREFIX)) = ..#MOUNTEDPREFIX)
        If pCheck = "database-dismounted" {
            If 'tMounted Do ..Add(pOut, pCheck, tDirectory, tDirectory, tRoute, ..#FIXLINK)
            Continue
        }
        If 'tMounted Continue
        Set tMax = tRow.%Get("MaxSize")
        If '$IsValidNum(tMax) || (+tMax <= 0) Continue
        Set tSize = +tRow.%Get("Size")
        If (tSize * 100) < (+tMax * ..#FULLPERCENT) Continue
        Set tFinding = ..Add(pOut, pCheck, tDirectory, tDirectory, tRoute, ..#FIXLINK)
        Do tFinding.%Set("detail", (tSize * 100) \ +tMax, "string")
    }
    Quit $$$OK
}

/// <p><code>task-manager</code>: the Task schedule read's declared banner reads
/// <parameter>SUSPENDEDBANNER</parameter> or <parameter>STOPPEDBANNER</parameter>, which
/// <code>detail</code> carries. The banner does not depend on the row cap, so a cut read is still
/// checked.</p>
ClassMethod TaskManager(pOut As %DynamicObject, ByRef pContext) As %Status
{
    Set tSC = ..Rows(..#TASKDESCRIPTOR, pOut, .pContext, .tResult)
    If $$$ISERR(tSC) || (pOut.%Get("status") = ..#STATUSUNCHECKED) Quit tSC
    Do pOut.%Set("status", ..#STATUSCHECKED, "string")
    Set tBanner = tResult.%Get("banner")
    If (tBanner '= ..#SUSPENDEDBANNER) && (tBanner '= ..#STOPPEDBANNER) Quit $$$OK
    Set tFinding = ..Add(pOut, "task-manager", "", "", $ClassMethod(..#TASKDESCRIPTOR, "Route"), ..#FIXLINK)
    Do tFinding.%Set("detail", tBanner, "string")
    Quit $$$OK
}

/// <p><code>task-error</code>: a suspended task whose <code>Task.CRUD</code> <code>INFO</code>
/// reads a non-empty <code>Error</code> other than <parameter>TASKSUCCESS</parameter> and records a
/// run: <code>LastStarted</code> is set, or <code>Status</code> is below 0, a code the Task Manager
/// records for a job it started or tried to start (<class>%SYS.TaskSuper</class>'s
/// <code>Status</code>). A task that never ran is not a finding whatever its <code>Error</code>
/// reads, because the Task Manager also writes a missed-schedule notice there ("Task Has Expired
/// for ...", <code>Status</code> 1) on a task it did not run, the stock tasks an instance ships
/// suspended among them. A task gone between the two reads is skipped.</p>
ClassMethod TaskErrors(pOut As %DynamicObject, ByRef pContext) As %Status
{
    Set tSC = ..Rows(..#TASKDESCRIPTOR, pOut, .pContext, .tResult)
    If $$$ISERR(tSC) || (pOut.%Get("status") '= ..#STATUSCHECKED) Quit tSC
    Set tRoute = $ClassMethod(..#TASKDETAILSDESCRIPTOR, "Route")
    Set tIterator = tResult.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%Get("Suspended") Continue
        Set tId = tRow.%Get("Id")
        Set tSC = ..Detail(..#TASKENDPOINT, ..#TASKINFOTYPE, ..#TASKIDPARAM, tId, .tInfo, .tHttp)
        If $$$ISERR(tSC) {
            If +$Get(tHttp) '= 404 Quit
            Set tSC = $$$OK
            Continue
        }
        If '$IsObject($Get(tInfo)) Continue
        Set tError = tInfo.%Get("Error")
        If (tError = "") || (tError = ..#TASKSUCCESS) Continue
        If (tInfo.%Get("LastStarted") = "") && (+tInfo.%Get("Status") >= 0) Continue
        Do ..Add(pOut, "task-error", tRow.%Get("Name"), tId, tRoute, ..#FIXAGENT)
    }
    Quit tSC
}

/// <p>The enabled web applications, each <code>{name, monitor, unauthenticated, roles}</code> from its own
/// <parameter>WEBAPPENDPOINT</parameter> <code>GET</code>, <code>roles</code> being the
/// <code>TargetRoles</code> of the <code>MatchRoles</code> entries whose <code>MatchRole</code> is
/// empty. Read once per answer; an application gone between the list and its GET is skipped.</p>
ClassMethod Applications(pOut As %DynamicObject, ByRef pContext, Output pApps As %DynamicArray) As %Status
{
    Set pApps = []
    Set tSC = ..Rows(..#WEBAPPDESCRIPTOR, pOut, .pContext, .tResult)
    If $$$ISERR(tSC) || (pOut.%Get("status") '= ..#STATUSCHECKED) Quit tSC
    If $Data(pContext("applications")) {
        Set pApps = pContext("applications")
        Quit $$$OK
    }
    Set tIterator = tResult.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%Get("Enabled") || (tRow.%Get("Name") = "") Continue
        Set tSC = ..Detail(..#WEBAPPENDPOINT, "GET", ..#WEBAPPIDPARAM, tRow.%Get("Name"), .tApp, .tHttp)
        If $$$ISERR(tSC) {
            If +$Get(tHttp) '= 404 Quit
            Set tSC = $$$OK
            Continue
        }
        If '$IsObject($Get(tApp)) Continue
        Set tRoles = []
        If tApp.%GetTypeOf("MatchRoles") = "array" {
            Set tMatches = tApp.%Get("MatchRoles").%GetIterator()
            While tMatches.%GetNext(.tMatchIndex, .tMatch) {
                If '$IsObject(tMatch) || (tMatch.%Get("MatchRole") '= "") || (tMatch.%GetTypeOf("TargetRoles") '= "array") Continue
                Set tTargets = tMatch.%Get("TargetRoles").%GetIterator()
                While tTargets.%GetNext(.tTargetIndex, .tTarget) {
                    If '$IsObject(tTarget) && (tTarget '= "") Do tRoles.%Push(tTarget)
                }
            }
        }
        Set tApplication = {}
        Do tApplication.%Set("name", tRow.%Get("Name"), "string")
        Do tApplication.%Set("monitor", ($ZConvert(tRow.%Get("DispatchClass"), "U") = $ZConvert(..#MONITORDISPATCH, "U")), "boolean")
        Do tApplication.%Set("unauthenticated", ((+tApp.%Get("AutheEnabled") \ ..#UNAUTHENTICATEDBIT) # 2), "boolean")
        Do tApplication.%Set("roles", tRoles)
        Do pApps.%Push(tApplication)
    }
    If $$$ISERR(tSC) Quit tSC
    Set pContext("applications") = pApps
    Quit $$$OK
}

/// <p><var>pDescriptor</var>'s pair gate and then its declared read, each made once per answer
/// and kept in <var>pContext</var>. <var>pOut</var>'s status becomes
/// <parameter>STATUSUNCHECKED</parameter> with the pair the caller lacks, or
/// <parameter>STATUSTRUNCATED</parameter> when the read hit its cap; <var>pResult</var> is the
/// read's <code>{rows, truncated, banner}</code> when it was made.</p>
ClassMethod Rows(pDescriptor As %String, pOut As %DynamicObject, ByRef pContext, Output pResult As %DynamicObject) As %Status
{
    Set pResult = ""
    If '$Data(pContext("gate", pDescriptor)) {
        Set tSC = ..Gate(pDescriptor, .tPair)
        If $$$ISERR(tSC) Quit tSC
        Set pContext("gate", pDescriptor) = tPair
    }
    If ..MarkUnread(pOut, pContext("gate", pDescriptor)) Quit $$$OK
    If '$Data(pContext("read", pDescriptor)) {
        Set tSC = ..ListRead(pDescriptor, .tResult)
        If $$$ISERR(tSC) Quit tSC
        Set pContext("read", pDescriptor) = tResult
    }
    Set pResult = pContext("read", pDescriptor)
    If pResult.%Get("truncated") Do pOut.%Set("status", ..#STATUSTRUNCATED, "string")
    Quit $$$OK
}

/// <p>Mark <var>pOut</var> for <var>pUnchecked</var> and answer whether it was marked:
/// <parameter>OcuPilot.Kernel.Shell.Effective.TRUNCATED</parameter> is
/// <parameter>STATUSTRUNCATED</parameter>, any other non-empty value is the pair the caller lacks,
/// and <code>""</code> marks nothing.</p>
ClassMethod MarkUnread(pOut As %DynamicObject, pUnchecked As %String) As %Boolean
{
    If pUnchecked = "" Quit 0
    If pUnchecked = ##class(OcuPilot.Kernel.Shell.Effective).#TRUNCATED {
        Do pOut.%Set("status", ..#STATUSTRUNCATED, "string")
        Quit 1
    }
    Do pOut.%Set("status", ..#STATUSUNCHECKED, "string")
    Do pOut.%Set("pair", pUnchecked, "string")
    Quit 1
}

/// <p>Append one finding to <var>pOut</var> and answer it.</p>
ClassMethod Add(pOut As %DynamicObject, pCheck As %String, pName As %String, pId As %String, pRoute As %String, pFix As %String) As %DynamicObject
{
    Set tFinding = {}
    Do tFinding.%Set("check", pCheck, "string")
    Do tFinding.%Set("group", ..GroupOf(pCheck), "string")
    Do tFinding.%Set("name", pName, "string")
    Do tFinding.%Set("id", pId, "string")
    Do tFinding.%Set("route", pRoute, "string")
    Do tFinding.%Set("scope", ..#SCOPE, "string")
    Do tFinding.%Set("fix", pFix, "string")
    Do pOut.%Get("findings").%Push(tFinding)
    Quit tFinding
}

/// <p>Whether the caller holds <var>pDescriptor</var>'s pair set; <var>pPair</var> names the first
/// pair it lacks, or <code>""</code>. A seam, so a fixture can refuse a screen.</p>
ClassMethod Gate(pDescriptor As %String, Output pPair As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.Shell.Effective).Gate(pDescriptor, .pPair)
}

/// <p><var>pDescriptor</var>'s declared read at its default cap, as the caller. A seam, so a
/// fixture can answer rows.</p>
ClassMethod ListRead(pDescriptor As %String, Output pResult As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Screen.Read).Execute(pDescriptor, "", .pResult, .tHttp, .tFault)
}

/// <p>One detail call through <method>PortClass</method>: <var>pType</var> on
/// <var>pEndpoint</var> for <var>pId</var> under <var>pParam</var>. A seam, so a fixture can
/// answer objects.</p>
ClassMethod Detail(pEndpoint As %String, pType As %String, pParam As %String, pId As %String, Output pObject, Output pHttpStatus As %Integer) As %Status
{
    Kill tQuery
    Set tQuery(pParam) = pId
    Quit $ClassMethod(..PortClass(), "Invoke", pEndpoint, pType, .tQuery, "", .pObject, .pHttpStatus, .tFault)
}

/// <p><method>OcuPilot.Kernel.Shell.Effective.Read</method> for <var>pRoots</var>. A seam, so a
/// fixture can answer role rows and public permissions.</p>
ClassMethod EffectiveRead(pRoots As %DynamicArray, Output pRoleRows As %DynamicObject, Output pPublic As %DynamicObject, Output pUnchecked As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.Shell.Effective).Read(pRoots, .pRoleRows, .pPublic, .pUnchecked)
}

/// <p>Now, as <code>$ZTimeStamp</code> answers it (UTC). A seam, so a fixture can fix the
/// clock.</p>
ClassMethod Now() As %String
{
    Quit $ZTimeStamp
}

/// <p>A <code>$Horolog</code>-shaped <var>pMoment</var> as whole seconds.</p>
ClassMethod Seconds(pMoment As %String) As %Integer
{
    Quit ($Piece(pMoment, ",", 1) * 86400) + ($Piece(pMoment, ",", 2) \ 1)
}

/// <p><var>pJson</var> as an object, or <code>""</code>.</p>
ClassMethod Parsed(pJson As %String) As %DynamicObject
{
    Set tObject = ""
    Try {
        If pJson = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pJson)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicObject") Set tObject = tParsed
    } Catch {
        Set tObject = ""
    }
    Quit tObject
}

}
