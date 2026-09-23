/// <p>The System events list's reset tool (AD-51, AD-53, FR-47): set one audit event's counters back
/// to zero. Two callers reach it: the list's Reset counters row action through
/// <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. Both read
/// the event fresh through <code>Security.Audit.Event</code>'s <code>GET</code> and issue the
/// vendor's <code>CLEARCOUNT</code>.</p>
/// <p><b>It is an action-style write whose vendor type needs a body it ignores.</b>
/// <code>CLEARCOUNT</code>'s <code>NeedsRequestBody()</code> is true and its
/// <code>RunClearCount</code> reads nothing from the body, so the port sends <code>{}</code>
/// (<parameter>OcuPilot.Port.AdminPort.CONSTANTBODIES</parameter>) and the tool sends none.</p>
/// <p><b>Its diff comes from the read</b>: one <code>Total</code> row moving to <code>0</code>. The
/// <code>GET</code> answers no counter, so the row's before-state is empty; the counters move with
/// every audited event, so they are no part of the fingerprint subject, which is the event's
/// <code>Enabled</code> flag.</p>
/// <p><class>OcuPilot.Screen.Tool.AuditUserEventReset</class> is the same tool for the User events
/// list.</p>
Class OcuPilot.Screen.Tool.AuditEventReset Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.auditsystemevents.reset";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuditSystemEventList";

Parameter DESCRIPTION = "Propose resetting one system audit event's Total, Written and Lost counters to zero. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the event exactly as the system events list reports it, as Source/Type/Name. The audit records already written are not touched.";

/// <p>The screen's own Reset counters row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "reset";

/// <p>The vendor's own counter reset, <code>TYPECLEARCOUNT</code> 10.</p>
Parameter WRITETYPE = "CLEARCOUNT";

/// <p>No body from the tool: the vendor's required, ignored body is the port's constant.</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The event is still there, with its counters moved.</p>
Parameter CHANGEACTION = "updated";

/// <p>The field the reset's precondition reads: an event whose own record the read did not answer
/// is not one to reset.</p>
Parameter PRECONDITIONFIELD = "Enabled";

/// <p>What the user reviewed: this event, in this enabled state.</p>
Parameter FINGERPRINTSUBJECT = "Enabled";

/// <p>What this tool's own <code>GET</code> answers.</p>
Parameter READANSWERS = "Description,Enabled";

/// <p>The state row's label: the counter the list shows first.</p>
Parameter STATEFIELD = "Total";

/// <p>The value the state row reads after the write.</p>
Parameter STATEAFTER = "0";

/// <p><code>%Admin_Secure:USE</code>, the endpoint's <code>ResourcesOR()</code> resource and one of
/// the screen's own pairs (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.Audit.Event"
}

/// <p>The list's row key, <code>Source/Type/Name</code>.</p>
ClassMethod IdArgument() As %String
{
    Quit "EventName"
}

/// <p>The port's composite key for an event
/// (<parameter>OcuPilot.Port.AdminPort.SPLITQUERIES</parameter>).</p>
ClassMethod IdParam() As %String
{
    Quit "event"
}

/// <p>None: the tool sends no body (AD-51).</p>
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
    Do tProperties.%Get(..IdArgument()).%Set("description", "The audit event whose counters to reset, as Source/Type/Name exactly as this instance's own events list reports it. An event the list does not report is refused.", "string")
    Quit tSchema
}

/// <p>The screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The one row this proposal's card shows, from the fresh <code>GET</code> <var>pFresh</var>:
/// <code>Total</code> moving to <code>0</code>. A read that did not answer
/// <parameter>PRECONDITIONFIELD</parameter> as a boolean is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "boolean") {
            Set pProblem = "this instance did not report that event's own record, so its counters cannot be reset"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", "", "string")
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
