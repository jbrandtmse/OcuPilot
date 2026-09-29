/// <p>The Background tasks list's cancel tool (AD-6, AD-51, AD-52, AD-53): cancel one background
/// task. Two callers reach it: the list's Cancel task row action through
/// <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation.
/// <class>OcuPilot.Screen.Tool.BackgroundTaskPause</class> and
/// <class>OcuPilot.Screen.Tool.BackgroundTaskResume</class> are this tool with another request
/// type and another after-state.</p>
/// <p><b>Its port is <class>OcuPilot.Port.BackgroundTaskPort</class></b> (AD-52), which carries an
/// admin API row out through <code>AsyncResult</code> and a portal row through its background task,
/// read fresh at the write. The fresh read is that port's <code>LIST</code> row whose
/// <code>Source</code> and <code>Id</code> equal the arguments exactly.</p>
/// <p><b>It is action-style</b> (AD-51): no settable field, no body, and a card whose one row is
/// <code>Status</code> moving to the state the action leaves, in the spelling each half answers.
/// Its fingerprint subject is <code>Status</code>, the field its precondition reads, so a confirm
/// after the task moved is refused. Whether the state allows the action is the instance's answer:
/// the port refuses <code>TASK.BACKGROUND.STATE</code>.</p>
/// <p><b>The target is composite</b> (AD-13): the agent names <parameter>SOURCEARGUMENT</parameter>
/// and <code>id</code>, which <class>OcuPilot.Screen.Tool.BackgroundTaskMint</class> joins, and the
/// screen sends the row's own composite id.</p>
Class OcuPilot.Screen.Tool.BackgroundTaskCancel Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "tasks.background.cancel";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.BackgroundTaskList";

Parameter DESCRIPTION = "Propose canceling one background task: a Management Portal job such as a database compact, or an admin API task you queued. It changes nothing by itself: it answers a proposal the user reviews and confirms. Canceling stops the task where it is; what it has done stays done, and it cannot be resumed. Name the task by its source and its id exactly as the background tasks list reports them. A task whose current state does not allow it is refused.";

/// <p>The screen's own row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "cancel";

/// <p>The port this tool's target lives behind (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.BackgroundTaskPort";

/// <p>The fresh read: the port's list, answering the one row the composite id names.</p>
Parameter READTYPE = "LIST";

Parameter WRITETYPE = "CANCEL";

/// <p>No body: neither half's control reads one (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p><code>%Admin_Operate:USE</code>, the resource both halves' control checks and the pair
/// <class>OcuPilot.Screen.Descriptor.BackgroundTaskList</class> declares as its own (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Operate";

Parameter WRITEPERMISSION = "USE";

Parameter PRECONDITIONFIELD = "Status";

Parameter FINGERPRINTSUBJECT = "Status";

Parameter STATEFIELD = "Status";

/// <p>The state an admin API row reads once the action has been carried out.</p>
Parameter ADMINAFTER = "Canceled";

/// <p>The state a portal row reads once the action has been carried out.</p>
Parameter PORTALAFTER = "Cancelled";

/// <p>The argument naming the row's source, one of the port's two words.</p>
Parameter SOURCEARGUMENT = "source";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.BackgroundTaskPort).#ENDPOINT
}

/// <p>The row's own id: the job number or the GUID.</p>
ClassMethod IdArgument() As %String
{
    Quit "id"
}

/// <p>The query parameter the port reads the composite id from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.BackgroundTaskPort).#IDPARAM
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The class the agent's proposal is minted by: the kernel's own mint, after the source and the
/// id are joined into the composite id (AD-13).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.BackgroundTaskMint"
}

/// <p>The derived schema with the identifying property's description replaced and the source
/// added, required, as an enum of the port's two words.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The task's id, copied as a string exactly as the background tasks list reports it, leading zeros included: a Management Portal job's number, or an admin API task's GUID. A task the list does not report is refused.", "string")
    Set tSource = {"type": "string", "description": "Where the task comes from, exactly as the background tasks list's Source column reads."}
    Do tSource.%Set("enum", [(##class(OcuPilot.Port.BackgroundTaskPort).#SOURCEPORTAL), (##class(OcuPilot.Port.BackgroundTaskPort).#SOURCEADMIN)])
    Do tProperties.%Set(..#SOURCEARGUMENT, tSource)
    Do tSchema.%Get("required").%Push(..#SOURCEARGUMENT)
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs, and nothing more (AD-8).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit tPairs
}

/// <p>The one row this proposal's card shows, from the fresh row <var>pFresh</var>:
/// <code>Status</code> moving from what the row reads to <parameter>ADMINAFTER</parameter> for an
/// admin API row or <parameter>PORTALAFTER</parameter> for a portal row. A row that names no source
/// or reads no status is <var>pProblem</var>; the state itself is the port's to judge.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tSource = ""
        Set tStatus = ""
        If $IsObject(pFresh) {
            Set tSource = pFresh.%Get("Source")
            Set tStatus = pFresh.%Get(..#PRECONDITIONFIELD)
        }
        If (tSource '= ##class(OcuPilot.Port.BackgroundTaskPort).#SOURCEPORTAL) && (tSource '= ##class(OcuPilot.Port.BackgroundTaskPort).#SOURCEADMIN) {
            Set pProblem = "this instance did not report where that background task comes from"
            Quit
        }
        If tStatus = "" {
            Set pProblem = "this instance did not report that background task's status"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", tStatus, "string")
        Do tRow.%Set("after", $Select(tSource = ##class(OcuPilot.Port.BackgroundTaskPort).#SOURCEADMIN: ..#ADMINAFTER, 1: ..#PORTALAFTER), "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
