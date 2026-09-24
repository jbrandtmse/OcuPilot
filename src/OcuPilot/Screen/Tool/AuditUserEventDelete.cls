/// <p>The User events list's delete tool (AD-6, AD-51, AD-53, FR-47): remove one event an
/// application registered. Two callers reach it: the list's Delete row action, behind the typed-name
/// dialog, and the agent's proposal and confirmation. Both read the event fresh through
/// <code>Security.Audit.Event</code>'s <code>GET</code> and issue the vendor's bodyless
/// <code>DELETE</code>.</p>
/// <p><b>It is offered on user events only.</b> The vendor refuses a system-defined event 409
/// (error #854), so the System events list declares no delete.</p>
/// <p><b>Deleting OcuPilot's own marker event stops agent writes being marked</b>
/// (<method>ClosesMarking</method>, AD-15): the write declares <parameter>MOVESMARKING</parameter>,
/// the agent's card carries the audit warning, and the typed-name dialog states it as an advisory.</p>
/// <p><b>It is destructive</b>: a deleted event is gone with its registration.</p>
Class OcuPilot.Screen.Tool.AuditUserEventDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.audituserevents.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuditUserEventList";

Parameter DESCRIPTION = "Propose deleting one user audit event from this instance, removing its registration. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the event exactly as the user events list reports it, as Source/Type/Name. Deleting OcuPilot/Security/AgentWrite stops the agent's own writes being marked, so say so plainly in the rationale.";

/// <p>The row action this tool carries out (AD-5, AD-53). It sends no argument, because it sends no
/// body.</p>
Parameter SCREENACTIONS = "delete";

/// <p>The vendor's own delete request type.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The event is removed, so a screen showing it drops the row (AD-14).</p>
Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted event is gone and no proposal puts it back.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>Deleting OcuPilot's own marker event closes the channel AD-15 marks through, so the screen's
/// caller records the observed marking fact after the write (AD-53 as amended 2026-09-23).</p>
Parameter MOVESMARKING As BOOLEAN = 1;

/// <p>The field the delete's precondition reads: an event whose own record the read did not answer
/// is not one to delete.</p>
Parameter PRECONDITIONFIELD = "Enabled";

/// <p>What the user reviewed: the event's description and whether it is enabled.</p>
Parameter FINGERPRINTSUBJECT = "Description,Enabled";

/// <p>What this tool's own <code>GET</code> answers; the list does not carry
/// <code>Description</code>.</p>
Parameter READANSWERS = "Description,Enabled";

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
    Do tProperties.%Get(..IdArgument()).%Set("description", "The user audit event to delete, as Source/Type/Name exactly as this instance's own user events list reports it. An event the list does not report is refused.", "string")
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

/// <p>The removal rows this proposal's card shows, from the fresh <code>GET</code>
/// <var>pFresh</var>: one per subject field, carrying the value the instance holds and no
/// after-state. A read that did not answer <parameter>PRECONDITIONFIELD</parameter> as a boolean is
/// <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "boolean") {
            Set pProblem = "this instance did not report that event's own record, and an event whose configuration is unknown is not one to delete"
            Quit
        }
        Set tSubject = ..FingerprintSubject()
        For tI = 1:1:$ListLength(tSubject) {
            Set tField = $List(tSubject, tI)
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField)), "string")
            Do tRow.%Set("after", "", "string")
            Do tRow.%Set("removed", 1, "boolean")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether deleting the event <var>pId</var> stops agent writes being marked: it is OcuPilot's
/// own marker event. <var>pArgs</var> carries nothing a delete reads.</p>
ClassMethod ClosesMarking(pId As %String, pArgs As %DynamicObject) As %Boolean
{
    Quit ##class(OcuPilot.Screen.Tool.AuditEventUpdate).IsMarkerEvent(pId)
}

}
