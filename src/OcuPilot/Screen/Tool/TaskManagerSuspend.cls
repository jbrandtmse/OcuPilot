/// <p>The Task schedule's Task Manager suspend tool (AD-6, AD-51, AD-53, Story 16.11): suspend the
/// instance's Task Manager, so no scheduled task runs until it is resumed. Two callers reach it: the
/// command bar's Suspend Task Manager through <class>OcuPilot.Api.ScreenAction</class>, behind the
/// warning dialog, and the agent's proposal and confirmation.
/// <class>OcuPilot.Screen.Tool.TaskManagerResume</class> and
/// <class>OcuPilot.Screen.Tool.TaskManagerStart</class> are this tool with their own request type and
/// the state each acts from.</p>
/// <p><b>It is action-style</b> (AD-51). <code>Task.Manager</code> publishes no body template and its
/// <code>SUSPEND</code>, <code>RESUME</code> and <code>RUN</code> read no body, so the tool admits no
/// settable field and sends none. Its fresh read is the endpoint's <code>GET</code>, whose one field
/// <code>Status</code> is the precondition, the fingerprint subject and the state row.</p>
/// <p><b>The target is the literal <parameter>MANAGERID</parameter></b> on the <code>task</code>
/// type (AD-13), compared without regard to case: the Task Manager is one per instance and the vendor
/// ignores the <code>id</code> query parameter. Any other id is refused by
/// <method>ArgumentProblem</method> for the agent and <method>ScreenActionDelta</method> for the
/// screen, before anything is sent.</p>
/// <p><b>Each tool acts only from <parameter>FROMSTATUS</parameter></b>. The vendor answers 200 for a
/// suspend or resume that changes nothing, so the refusal is OcuPilot's: <method>StateDiff</method>
/// answers one of the four published sentences for the other two states, and an unpublished problem
/// for a status it cannot read.</p>
/// <p>A suspend that changes the state leaves <code>%System/%System/ConfigurationChange</code>
/// ("Modify Task Config.Suspend"). It is not destructive, and its proposal carries
/// <parameter>CONSEQUENCESUSPEND</parameter>.</p>
Class OcuPilot.Screen.Tool.TaskManagerSuspend Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "tasks.schedule.suspendmanager";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.TaskScheduleList";

Parameter DESCRIPTION = "Propose suspending this instance's Task Manager, so no scheduled task runs until it is resumed. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal 'manager' as the id. A Task Manager that is already suspended, or not running, is refused.";

/// <p>The screen's own action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "suspendmanager";

/// <p>The state read: <code>Task.Manager</code>'s <code>GET</code>, which answers
/// <code>Status</code> from <code>%SYS.Task.TASKMGRStatus()</code>.</p>
Parameter READTYPE = "GET";

/// <p>The vendor's suspend, <code>SuspendSet(1)</code>.</p>
Parameter WRITETYPE = "SUSPEND";

/// <p>No body: the vendor's three types read none
/// (<parameter>OcuPilot.Port.AdminPort.BODYLESSTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p><code>%Admin_Task:USE</code>, one of the vendor's <code>ResourcesOR()</code> resources and one
/// of the screen's own two pairs (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Task";

Parameter WRITEPERMISSION = "USE";

/// <p>The <code>GET</code> field this tool's precondition reads.</p>
Parameter PRECONDITIONFIELD = "Status";

Parameter FINGERPRINTSUBJECT = "Status";

Parameter STATEFIELD = "Status";

/// <p>What <parameter>READTYPE</parameter> answers. The screen's declared read is the task list, which
/// carries no <code>Status</code> of the Task Manager's.</p>
Parameter READANSWERS = "Status";

/// <p>The one id every caller names the Task Manager by.</p>
Parameter MANAGERID = "manager";

/// <p>The three values the vendor's <code>GET</code> answers.</p>
Parameter RUNNINGSTATUS = "Running";

Parameter SUSPENDEDSTATUS = "Suspended";

Parameter STOPPEDSTATUS = "Not running";

/// <p>The status this tool acts from, and the one its state row says it leaves.</p>
Parameter FROMSTATUS = "Running";

Parameter TOSTATUS = "Suspended";

/// <p>A resume's or start's refusal of a running Task Manager, published in EXPERIENCE.md's Fixed
/// strings and pinned equal to <code>taskManagerRefusalRunning</code> by
/// <file>ui/tools/self-protection.test.mjs</file>.</p>
Parameter RUNNINGREASON = "The Task Manager is already running.";

/// <p>A suspend's refusal of a suspended Task Manager, pinned equal to
/// <code>taskManagerRefusalSuspended</code>.</p>
Parameter SUSPENDEDREASON = "The Task Manager is already suspended.";

/// <p>A start's refusal of a suspended Task Manager, which the vendor's start never resumes, pinned
/// equal to <code>taskManagerRefusalSuspendedStart</code>.</p>
Parameter SUSPENDEDSTARTREASON = "The Task Manager is suspended. Resume it instead.";

/// <p>A suspend's or resume's refusal of a stopped Task Manager, pinned equal to
/// <code>taskManagerRefusalStopped</code>.</p>
Parameter STOPPEDREASON = "The Task Manager is not running. Start it first.";

/// <p>The consequence a suspend proposal carries: no scheduled task runs until it is resumed. The
/// client maps it to <code>taskManagerSuspendConsequence</code>.</p>
Parameter CONSEQUENCESUSPEND = "TASK.MANAGER.SUSPEND";

ClassMethod Endpoint() As %String
{
    Quit "Task.Manager"
}

/// <p>The target's id argument, which carries <parameter>MANAGERID</parameter>.</p>
ClassMethod IdArgument() As %String
{
    Quit "Id"
}

/// <p>The query parameter the id travels under, which the vendor ignores.</p>
ClassMethod IdParam() As %String
{
    Quit "id"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property described as the literal
/// <parameter>MANAGERID</parameter>.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "Send the literal 'manager': the Task Manager is one per instance. Any other id is refused.", "string")
    Quit tSchema
}

/// <p>The screen's own pairs, with <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>
/// appended only when the screen does not already declare it (AD-8).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The agent's id refused unless it is <parameter>MANAGERID</parameter> (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..IdProblem(pIdValue)
    Quit $$$OK
}

/// <p>The screen's target refused unless it is <parameter>MANAGERID</parameter>, after the default
/// arguments (AD-56 (ii)). The route passes the target as <method>IdArgument</method> in
/// <var>pValues</var>.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tId = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf(..IdArgument()) = "string") Set tId = pValues.%Get(..IdArgument())
    Set pProblem = ..IdProblem(tId)
    Quit $$$OK
}

/// <p>Why <var>pId</var> is not the Task Manager's id, or <code>""</code>.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If $ZConvert(pId, "L") = ..#MANAGERID Quit ""
    Quit "'" _ ..IdArgument() _ "' must be the literal '" _ ..#MANAGERID _ "': the Task Manager is one per instance"
}

/// <p><parameter>CONSEQUENCESUSPEND</parameter>, for every payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCESUSPEND
}

/// <p>The one row this proposal's card shows, from the fresh <code>GET</code> <var>pFresh</var>:
/// <code>Status</code> moving from <parameter>FROMSTATUS</parameter> to
/// <parameter>TOSTATUS</parameter>. A Task Manager in either other state is <var>pProblem</var>, one
/// of the four published sentences; a <code>Status</code> that is absent, not a string or none of
/// the vendor's three is refused too.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tStatus = ""
        If $IsObject(pFresh) && (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "string") Set tStatus = pFresh.%Get(..#PRECONDITIONFIELD)
        If tStatus = ..#FROMSTATUS {
            Set tRow = {}
            Do tRow.%Set("field", ..#STATEFIELD, "string")
            Do tRow.%Set("before", ..#FROMSTATUS, "string")
            Do tRow.%Set("after", ..#TOSTATUS, "string")
            Do pRows.%Push(tRow)
            Quit
        }
        If tStatus = ..#RUNNINGSTATUS {
            Set pProblem = ..#RUNNINGREASON
        } ElseIf tStatus = ..#SUSPENDEDSTATUS {
            Set pProblem = $Select(..#FROMSTATUS = ..#STOPPEDSTATUS: ..#SUSPENDEDSTARTREASON, 1: ..#SUSPENDEDREASON)
        } ElseIf tStatus = ..#STOPPEDSTATUS {
            Set pProblem = ..#STOPPEDREASON
        } Else {
            Set pProblem = "this instance did not report the Task Manager's status"
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
