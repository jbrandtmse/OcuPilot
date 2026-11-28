/// <p>Interoperability's schedule spec add (AD-3, AD-6, AD-54, AD-55, AD-62, Story 24.15): add one schedule spec to the request's namespace, with its
/// spec and, optionally, its description and deployable flag. Two callers reach it: the Schedule specs list's New schedule spec dialog through
/// <class>OcuPilot.Area.Interop.ScheduleSave</class>, and the agent's proposal and confirmation. The schedule spec is stored at once; no running
/// production is notified of an add.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no schedule spec of that name in any letter case, because the vendor decides which items to
/// notify of an edit ignoring case, and a name added since the mint reads present at the confirm's re-read and closes the proposal target-changed.
/// A namespace under source control refuses it.</p>
/// <p><b>Its payload</b> is the name and the fields the caller supplies and the namespace the add was composed in (<method>ComposeCreate</method>);
/// its read-back compares the spec, the description and the flag (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.InteropScheduleAdd Extends OcuPilot.Screen.Tool.InteropScheduleAction
{

Parameter TOOLNAME = "interop.schedules.add";

Parameter DESCRIPTION = "Propose adding one schedule spec to the namespace the user is working in. A schedule spec starts and stops the production items whose schedule names it, written @ and its name. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give the schedule spec's name, which cannot be changed afterwards, and its schedule: parts separated by commas, each START or STOP, a colon and a date and time, for example START:*-*-*T08:00:00,STOP:*-*-*T17:00:00, where * matches any; and optionally a description and whether the schedule spec is deployable. A name the namespace already holds, in any letter case, a name over 50 characters, a schedule the instance does not accept, a description over 256 characters and a namespace under source control are refused.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADDSCHEDULE";

/// <p>The add sends a body: the composed payload (AD-4 has no subject for a create).</p>
Parameter SENDSBODY As BOOLEAN = 1;

/// <p>What the read-back compares, the fields a create sends that a read answers (AD-58).</p>
Parameter READBACKFIELDS = "ScheduleSpec,Description,Deployable";

/// <p>The read-back re-reads the created schedule spec through the update's single-object read, because the add's own read asks for the add and
/// answers a held name as <code>TAKEN</code> (AD-58).</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.InteropScheduleUpdate";

Parameter PRECONDITIONCODES = "INTEROP.SCHEDULE.TAKEN,INTEROP.SCHEDULE.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The fields an add may set, in the order the card lists them.</p>
Parameter FIELDS = "Name,ScheduleSpec,Description,Deployable";

/// <p>An add judges the name it is given and requires a spec.</p>
Parameter JUDGESNAME As BOOLEAN = 1;

/// <p>The name and the three fields an add sets.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The four fields as the field rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Quit ..ScheduleFieldRows(1, .pRows)
}

/// <p>What the schema says of the new schedule spec's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The new schedule spec's name: 1 to 50 characters with no control character. It cannot be changed afterwards. A name the namespace already holds, in any letter case, is refused, so check the Schedule specs list first."
}

/// <p>The derived schema with each field described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ..DescribeFields(##super(pDescriptor))
}

/// <p>The composed payload and diff of the create (AD-54): the name and the fields the caller supplied, as the kernel's
/// <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> composes them, and the namespace the request is scoped to, which the port query and the
/// prohibited set read. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The name of the schedule spec the confirmed add <var>pWritten</var> created, or <code>""</code>: the id its read-back re-reads it by.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("Name") '= "string" Quit ""
    Quit pWritten.%Get("Name")
}

/// <p>The add always asks its read for the add (<method>OcuPilot.Screen.Tool.InteropScheduleAction.PortQuery</method>): present, in any letter
/// case, is <code>TAKEN</code> and absent is the 404 a create expects (AD-54), at the mint and at the confirm alike.</p>
Parameter READASKSACTION As BOOLEAN = 1;

}
