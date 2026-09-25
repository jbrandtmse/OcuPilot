/// <p>The System events list's enable and disable tool (AD-6, AD-53, FR-47): turn one audit event
/// on or off. Two callers reach it: the list's Enable and Disable row actions through
/// <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. Both read the
/// event fresh through the vendor's own <code>Security.Audit.Event</code> <code>GET</code>, merge
/// <code>Enabled</code> over that object and send the complete <code>{Description, Enabled}</code>
/// (AD-4).</p>
/// <p><b>The vendor's <code>PUT</code> is an upsert</b>: it creates an event it does not hold. The
/// fresh read refuses an absent target at the mint and at a screen action, and the confirm's
/// fingerprint re-read refuses one that vanished since, so no caller's write reaches the vendor
/// for an event the read did not find (AD-4, AD-6).</p>
/// <p><b>It admits one field</b>, <code>Enabled</code>, of the class-derived
/// <code>Security.Audit.Event:Security.Events</code> list (AD-3); <code>Description</code> is
/// classified <code>ordinary</code> and left unpermitted.</p>
/// <p><b>The target is the row key</b>, <code>Source/Type/Name</code>, sent as the port's
/// <code>event</code> parameter, which <parameter>OcuPilot.Port.AdminPort.SPLITQUERIES</parameter>
/// splits into the vendor's three.</p>
/// <p><b>Disabling OcuPilot's own marker event stops agent writes being marked</b>
/// (<method>ClosesMarking</method>, AD-15), so the write declares <parameter>MOVESMARKING</parameter>
/// and the agent's card carries the audit warning.</p>
/// <p><class>OcuPilot.Screen.Tool.AuditUserEventUpdate</class> is the same tool for the User events
/// list.</p>
Class OcuPilot.Screen.Tool.AuditEventUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.auditsystemevents.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuditSystemEventList";

Parameter DESCRIPTION = "Propose turning one system audit event on or off, so the instance does or does not record it in the audit database. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the event exactly as the system events list reports it, as Source/Type/Name, and send Enabled.";

/// <p>The one derived top-level field this tool admits, which is also the one field
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> permits a change to
/// for both audit-event entity types. A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "Enabled";

/// <p>The two row actions this tool carries out (AD-5, AD-53), each the one merge write over
/// <code>Enabled</code>.</p>
Parameter SCREENACTIONS = "enable=Enabled:true,disable=Enabled:false";

/// <p>Disabling or enabling OcuPilot's own marker event closes or opens the channel AD-15 marks
/// through, so the screen's caller records the observed marking fact after the write (AD-53 as
/// amended 2026-09-23).</p>
Parameter MOVESMARKING As BOOLEAN = 1;

/// <p>The event list this tool administers (DW-1575): a system event's Source begins with
/// <code>%</code>, and <method>OcuPilot.Area.Security.AuditEventRules.OwnerProblem</method> refuses
/// the other list's events from both callers.</p>
Parameter EVENTOWNER = "system";

/// <p><code>%Admin_Secure:USE</code>, the vendor endpoint's own <code>ResourcesOR()</code> resource
/// and one of the two pairs the screen declares (AD-8 as amended by DW-1208).</p>
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

/// <p>The <code>ordinary</code> top-level literals of this tool's own field-list entry that
/// <parameter>PERMITTEDFIELDS</parameter> admits (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>, so <code>Description</code> is absent from the
/// schema and from <method>SettableFields</method>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with the identifying property's description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The audit event, as Source/Type/Name exactly as this instance's own events list reports it. An event the list does not report is refused, and none is created.", "string")
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

/// <p>The agent's arguments refused when <var>pIdValue</var> is the other list's event
/// (<method>OcuPilot.Area.Security.AuditEventRules.OwnerProblem</method>).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ##class(OcuPilot.Area.Security.AuditEventRules).OwnerRefusal($ClassName(), pIdValue)
    If pProblem '= "" Quit $$$OK
    Quit ##super(pIdValue, pArgs, .pProblem)
}

/// <p>The screen action's arguments over the fresh read <var>pFresh</var>, with
/// <var>pProblem</var> naming the other list's event, or an event already in the state the action
/// would set: either is refused before anything is sent.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set pArgs = ..ScreenActionArguments(pActionId, .tServes)
    Set tSC = $$$OK
    Try {
        Set pProblem = ##class(OcuPilot.Area.Security.AuditEventRules).OwnerRefusal($ClassName(), $Select($IsObject(pValues): pValues.%Get(..IdArgument()), 1: ""))
        If pProblem '= "" Quit
        If '$IsObject(pFresh) || (pArgs.%GetTypeOf("Enabled") '= "boolean") Quit
        If pFresh.%GetTypeOf("Enabled") '= "boolean" {
            Set pProblem = "this instance did not report whether that event is enabled, so it cannot be changed"
            Quit
        }
        If ''pFresh.%Get("Enabled") '= ''pArgs.%Get("Enabled") Quit
        Set pProblem = "this instance already reports that event as " _ $Select(pArgs.%Get("Enabled"): "enabled", 1: "disabled") _ ", so there is nothing to change"
    } Catch ex {
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether a write of this tool against the event <var>pId</var>, with arguments
/// <var>pArgs</var>, stops agent writes being marked: <var>pId</var> is OcuPilot's own marker event
/// (<method>IsMarkerEvent</method>) and <code>Enabled</code> is not a value that reads as on.</p>
/// <p><b>Caller contract:</b> <method>OcuPilot.Kernel.Proposal.Mint.WarnsAuditingOff</method> asks
/// it for the card's audit warning. It reads no live state and decides nothing about whether the
/// write may happen.</p>
ClassMethod ClosesMarking(pId As %String, pArgs As %DynamicObject) As %Boolean
{
    Set tCloses = 0
    Try {
        If '..IsMarkerEvent(pId) Quit
        If '$IsObject(pArgs) Quit
        Set tType = pArgs.%GetTypeOf("Enabled")
        If tType = "unassigned" Quit
        Set tValue = pArgs.%Get("Enabled")
        If tType = "boolean" {
            Set tCloses = 'tValue
            Quit
        }
        Set tCloses = '((tValue = "true") || (tValue = 1))
    } Catch {
        Set tCloses = 0
    }
    Quit tCloses
}

/// <p>Whether <var>pId</var> names OcuPilot's own marker event, the one
/// <method>OcuPilot.Kernel.Audit.Event.ObserveMarking</method> reads, in any spelling the
/// instance resolves to it (AD-13).</p>
ClassMethod IsMarkerEvent(pId As %String) As %Boolean
{
    Set tMarker = ##class(OcuPilot.Kernel.Audit.Event).Source() _ "/" _ ##class(OcuPilot.Kernel.Audit.Event).Type() _ "/" _ ##class(OcuPilot.Kernel.Audit.Event).#EVENTAGENTWRITE
    Quit $ZConvert(pId, "L") = $ZConvert(tMarker, "L")
}

}
