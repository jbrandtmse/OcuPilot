/// <p>The User events list's create tool (AD-54, AD-55, DW-1573): propose registering a new user
/// audit event on this instance. It reads the intended event fresh through the vendor's own
/// <code>Security.Audit.Event</code> <code>GET</code>, requires that read to answer <b>nothing</b>,
/// composes the payload from its arguments and mints a proposal the user confirms. It writes
/// nothing.</p>
/// <p><b>The vendor's <code>PUT</code> is an upsert</b> that folds case, so the absence
/// fingerprint is what stops a confirmed create rewriting an event somebody registered since the
/// mint (AD-54).</p>
/// <p><b>The target is <code>Source/Type/Name</code></b>, sent as the port's <code>event</code>
/// parameter, which <parameter>OcuPilot.Port.AdminPort.SPLITQUERIES</parameter> splits into the
/// vendor's three. <method>ArgumentProblem</method> holds each part to the editor's rules
/// (<class>OcuPilot.Area.Security.AuditEventRules</class>) before anything is stored, so a system
/// event is never created here.</p>
/// <p>Creating OcuPilot's own marker event reopens marking, so the write declares
/// <parameter>MOVESMARKING</parameter> (AD-53 as amended).</p>
Class OcuPilot.Screen.Tool.AuditUserEventCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.audituserevents.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AuditUserEventList";

Parameter DESCRIPTION = "Propose registering a new user audit event on this instance, so an application can record it. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the event as Source/Type/Name, and give its description and whether it is enabled.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

/// <p>The AD-14 action a confirmed create performs.</p>
Parameter CHANGEACTION = "created";

/// <p>The vendor's <code>PUT</code>, the endpoint's only create.</p>
Parameter WRITETYPE = "PUT";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same two).
/// A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "Description,Enabled";

/// <p>Creating OcuPilot's own marker event opens the channel AD-15 marks through, so the screen's
/// caller records the observed marking fact after the write.</p>
Parameter MOVESMARKING As BOOLEAN = 1;

/// <p>The event list this tool administers (DW-1575).</p>
Parameter EVENTOWNER = "user";

/// <p><code>%Admin_Secure:USE</code>, the vendor endpoint's own <code>ResourcesOR()</code> resource
/// and one the User events list already declares (AD-8).</p>
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

/// <p>The <code>ordinary</code> top-level fields this tool admits, derived rather than transcribed
/// (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with the identifying property's format stated.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The new event's name as Source/Type/Name: three parts joined by slashes, none containing a slash, each at most 64 characters. A Source or Type beginning with % is reserved for the instance's own system events and is refused. An event this instance already holds, in any case, is refused.", "string")
    Quit tSchema
}

/// <p>The editor's rules over the agent's arguments
/// (<method>OcuPilot.Area.Security.AuditEventRules.ArgumentViolations</method>), then the ownership
/// rule; each broken rule is named with its published sentence (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.Security.AuditEventRules).ArgumentViolations(pIdValue, pArgs, 1, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = ##class(OcuPilot.Area.Security.AuditEventRules).ProblemText(.tViolations)
    If pProblem '= "" Quit $$$OK
    Set pProblem = ##class(OcuPilot.Area.Security.AuditEventRules).OwnerRefusal($ClassName(), pIdValue)
    Quit $$$OK
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
