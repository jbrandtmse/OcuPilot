/// <p>Interoperability's schedule spec update (AD-4, AD-6, AD-51, AD-53, AD-56, AD-62, Story 24.15): change the spec, the description or the deployable
/// flag of one schedule spec of the request's namespace. The change is stored at once, and a running production whose items name the schedule spec
/// follows a changed spec at once (<code>INTEROP.SCHEDULE.CHANGE</code>). <b>The name cannot be changed</b>: to rename a schedule spec, add one
/// under the new name, change what names the old one, then remove it.</p>
/// <p>Two callers reach it: the Schedule specs list's row action Edit through <class>OcuPilot.Api.ScreenAction</class>, whose dialog sends the fields
/// it changed, and the agent's proposal and confirmation. It is a merge over the schedule spec's fresh read, so its card shows one row for each field
/// it moves and its read-back compares the three fields (<parameter>READBACKFIELDS</parameter>).</p>
Class OcuPilot.Screen.Tool.InteropScheduleUpdate Extends OcuPilot.Screen.Tool.InteropScheduleAction
{

Parameter TOOLNAME = "interop.schedules.update";

Parameter DESCRIPTION = "Propose changing the schedule, the description or the deployable flag of one schedule spec of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the schedule spec exactly as the Schedule specs list reports it, and give only the fields to change; a description sent as an empty string is cleared and a field left out is kept. The schedule is parts separated by commas, each START or STOP, a colon and a date and time, for example START:*-*-*T08:00:00,STOP:*-*-*T17:00:00. A running production that uses the schedule spec follows a changed schedule at once. The name cannot be changed by this tool. A schedule the instance does not accept, an empty schedule, a description over 256 characters, a schedule spec the namespace does not hold and a namespace under source control are refused.";

Parameter WRITETYPE = "SETSCHEDULE";

/// <p>The update sends a body: the schedule spec's row with the new values (AD-4).</p>
Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter CONSEQUENCECODE = "INTEROP.SCHEDULE.CHANGE";

Parameter SCREENACTIONS = "edit";

/// <p>The dialog's values are the three fields (AD-56 (ii)); the name is the target. A flag is sent as <code>true</code> or <code>false</code>.</p>
Parameter SCREENVALUES = "edit=ScheduleSpec:Description:Deployable";

/// <p>The description may be empty: clearing it is the request. The spec may be sent empty too, so the port refuses it with the published sentence
/// rather than the screen with a generic one.</p>
Parameter SCREENEMPTY = "edit=ScheduleSpec:Description";

/// <p>The dialog sends the fields it changed and no other: a value left out keeps what the schedule spec holds, so a change made elsewhere to
/// another field since the list was read is kept (AD-4, AD-56).</p>
Parameter SCREENOPTIONAL = "edit=ScheduleSpec:Description:Deployable";

/// <p>What the read-back compares (AD-58).</p>
Parameter READBACKFIELDS = "ScheduleSpec,Description,Deployable";

Parameter PRECONDITIONCODES = "INTEROP.SCHEDULE.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The edit always asks its read for the edit, so a namespace under source control is refused before anything is claimed.</p>
Parameter READASKSACTION As BOOLEAN = 1;

/// <p><parameter>CONSEQUENCECODE</parameter> when the payload's <code>ScheduleSpec</code> differs from the spec the schedule spec holds now, read as
/// the caller through this tool's port in the payload's namespace, and <code>""</code> otherwise, since the vendor notifies a running production of a
/// changed spec alone. A read that answers no spec keeps the code.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If '$IsObject(pPayload) || (pPayload.%GetTypeOf("ScheduleSpec") '= "string") Quit ""
    If pPayload.%GetTypeOf("Name") '= "string" Quit ..#CONSEQUENCECODE
    Kill tQuery
    Set tQuery(##class(OcuPilot.Port.InteropPort).#IDKEY) = pPayload.%Get("Name")
    If pPayload.%GetTypeOf("Namespace") = "string" Set tQuery(##class(OcuPilot.Port.InteropPort).#NAMESPACEKEY) = pPayload.%Get("Namespace")
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tHeld, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tHeld)) || (tHeld.%GetTypeOf("ScheduleSpec") '= "string") Quit ..#CONSEQUENCECODE
    If tHeld.%Get("ScheduleSpec") = pPayload.%Get("ScheduleSpec") Quit ""
    Quit ..#CONSEQUENCECODE
}

/// <p>The three fields an update may set.</p>
Parameter FIELDS = "ScheduleSpec,Description,Deployable";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The three fields as the field rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Quit ..ScheduleFieldRows(0, .pRows)
}

/// <p>The derived schema with each field described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ..DescribeFields(##super(pDescriptor))
}

/// <p>No state rows: a merge's card shows the values it moves (<method>OcuPilot.Kernel.Proposal.Mint.Merge</method>), and a schedule spec nobody
/// established is refused by the fresh read.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The dialog's values as this tool's arguments: the spec and the description as sent, an empty one included, and the flag as the boolean its
/// <code>true</code> or <code>false</code> text names; any other flag text is <var>pProblem</var>. The port judges the rest.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    For tName = "ScheduleSpec", "Description" {
        If pValues.%GetTypeOf(tName) = "string" Do pArgs.%Set(tName, pValues.%Get(tName), "string")
    }
    If pValues.%GetTypeOf("Deployable") = "string" {
        If '$ListFind($ListBuild("true", "false"), pValues.%Get("Deployable")) {
            Set pProblem = "'Deployable' is true or false"
        } Else {
            Do pArgs.%Set("Deployable", (pValues.%Get("Deployable") = "true"), "boolean")
        }
    }
    Quit $$$OK
}

}
