/// <p>The processes list's terminate tool (AD-6, AD-51, AD-53, FR-55): end one process at once. Two
/// callers reach it: the Terminate row action on Processes and Process details through
/// <class>OcuPilot.Api.ScreenAction</class>, behind the typed-name dialog, and the agent's proposal
/// and confirmation. Both read the process fresh through the vendor's own <code>Process</code>
/// <code>GET</code> and issue the vendor's <code>TERMINATE</code>.</p>
/// <p><b>It is action-style</b> (AD-51): <code>TERMINATE</code> reads no body, so the tool admits
/// no settable field and sends none. The vendor's terminate never logs an error in the process;
/// <class>OcuPilot.Screen.Tool.ProcessTerminateWithError</class> is the one that does.</p>
/// <p><b>Its fingerprint covers <code>Pid</code> and <code>StartTimeUTC</code></b>: the start time
/// is what tells a process from a later one that reuses its pid, while <code>State</code> moves on
/// exactly the busy processes a terminate is for, so it is left out (AD-51).</p>
/// <p><b>OcuPilot's own processes and IRIS system processes are refused on the instance</b>, by
/// <class>OcuPilot.Kernel.Proposal.Prohibited</class>'s <code>process</code> arm, whoever calls
/// (AD-10). The vendor's own <code>CanBeTerminated</code> guard answers 409 after it.</p>
/// <p><b>It is destructive</b>: a terminated process cannot be proposed back.</p>
Class OcuPilot.Screen.Tool.ProcessTerminate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.processes.terminate";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ProcessList";

Parameter DESCRIPTION = "Propose terminating one process this instance is running. It changes nothing by itself: it answers a proposal the user reviews and confirms. A terminated process stops at once without finishing its work, and this cannot be undone. Name the process by the numeric process id the processes list reports for it. A process OcuPilot is itself running in -- this request, or an agent turn -- and an IRIS system process are both refused.";

/// <p>The screen's own Terminate row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "terminate";

/// <p>The state read: <code>Process</code>'s <code>GET</code>, the one read that answers
/// <code>StartTimeUTC</code> (AD-36, AD-51).</p>
Parameter READTYPE = "GET";

/// <p>The vendor's own terminate request type: <code>Process</code>'s <code>TYPETERMINATE</code>
/// is 13, its <code>RunTerminate</code> answers 404 for an unknown pid and 409 when
/// <code>CanBeTerminated</code> is 0, and its <code>ValidateQueryParams</code> requires the
/// <code>id</code> query parameter (read on this build).</p>
Parameter WRITETYPE = "TERMINATE";

Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The target is removed, so a screen showing it drops the row (AD-14).</p>
Parameter CHANGEACTION = "deleted";

Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p><code>%Admin_Operate:USE</code>, the vendor's own <code>ResourcesOR()</code> resource and one
/// of the three pairs <class>OcuPilot.Screen.Descriptor.ProcessList</class> declares (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Operate";

Parameter WRITEPERMISSION = "USE";

/// <p>The read field the precondition reads: the process the user reviewed is the one that
/// started at this time.</p>
Parameter PRECONDITIONFIELD = "StartTimeUTC";

/// <p>What the user reviewed: this pid, started at this time.</p>
Parameter FINGERPRINTSUBJECT = "Pid,StartTimeUTC";

/// <p>What this tool's <code>GET</code> answers of the subject and the state row. The list's
/// <code>LIST</code> row carries no <code>StartTimeUTC</code>, so the subject is validated against
/// this read's own names.</p>
Parameter READANSWERS = "Pid,StartTimeUTC,State";

/// <p>The state row's label and its after-value. The before-value is the state the instance
/// reports.</p>
Parameter STATEFIELD = "State";

Parameter STATEAFTER = "Terminated";

ClassMethod Endpoint() As %String
{
    Quit "Process"
}

/// <p>The numeric process id, which is the property the processes list's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Pid"
}

/// <p>The query parameter <code>Process</code> identifies a process by, for the read and the
/// terminate.</p>
ClassMethod IdParam() As %String
{
    Quit "id"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The process to terminate, named by the numeric process id this instance's own processes list reports for it. A process the list does not report is refused.", "string")
    Quit tSchema
}

/// <p>The screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, appended only when
/// the screen does not already declare it.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The one row this proposal's card shows, from the fresh <code>GET</code> read
/// <var>pFresh</var>: <code>State</code> moving from the state the instance reports to
/// <parameter>STATEAFTER</parameter>.</p>
/// <p>A read that answered no <code>State</code>, or no <code>StartTimeUTC</code>, is
/// <var>pProblem</var>: a process whose state or start nobody established is not one to
/// terminate. Nothing else refuses here; a process that has already ended answers 404 at the
/// read.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tState = ""
        Set tStarted = ""
        If $IsObject(pFresh) {
            Set tState = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(..#STATEFIELD), pFresh.%GetTypeOf(..#STATEFIELD))
            Set tStarted = ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(..#PRECONDITIONFIELD), pFresh.%GetTypeOf(..#PRECONDITIONFIELD))
        }
        If tState = "" {
            Set pProblem = "this instance did not report that process's state, and a process whose state is unknown is not one to terminate"
            Quit
        }
        If tStarted = "" {
            Set pProblem = "this instance did not report when that process started, so it cannot be told from a later process with the same id"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", tState, "string")
        Do tRow.%Set("after", ..#STATEAFTER, "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
