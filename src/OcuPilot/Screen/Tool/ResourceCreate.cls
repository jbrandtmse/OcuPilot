/// <p>The Resources list's create tool (AD-54, AD-55): propose a new resource on this instance. It
/// reads the intended name fresh through the vendor's own <code>Security.Resource</code>
/// <code>GET</code>, requires that read to answer <b>nothing</b>, composes the payload from its
/// arguments and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>It admits the resource editor's two fields</b>, <code>Description</code> and
/// <code>PublicPermission</code> (<parameter>PERMITTEDFIELDS</parameter>), exactly the ones
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> has reviewed for a
/// resource create, and requires both, because the vendor's create does. A public permission on an
/// administrative resource is permitted and confirmed as a delete is: the mint marks the proposal
/// destructive and names the privilege (AD-10).</p>
/// <p>The name travels only as the vendor's <code>name</code> query parameter; the vendor's body
/// validator refuses it as a field.</p>
Class OcuPilot.Screen.Tool.ResourceCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.resources.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ResourceList";

Parameter DESCRIPTION = "Propose a new resource on this instance. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the resource, and give its description and its public permission.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

/// <p>The AD-14 action a confirmed create performs.</p>
Parameter CHANGEACTION = "created";

/// <p>The vendor request type a create is issued with: <code>Security.Resource</code>'s
/// <code>PUT</code>, the endpoint's only create. It is an <b>upsert</b> -- it modifies a resource
/// that already exists and answers 200 -- so the absence fingerprint is what stops a confirmed
/// create rewriting somebody else's resource (AD-54).</p>
Parameter WRITETYPE = "PUT";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same two).
/// A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "Description,PublicPermission";

/// <p>The field whose description this tool writes: the letters every user holds.</p>
Parameter PUBLICPERMISSIONARGUMENT = "PublicPermission";

/// <p>The pair a create requires: <code>%Admin_Secure:USE</code>, the vendor endpoint's own
/// <code>ResourcesOR()</code> resource and one the Resources list already declares (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.Resource"
}

/// <p>The field names the composed payload may set: the <code>ordinary</code> top-level fields this
/// tool admits, derived rather than transcribed (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a field the prohibited set has not reviewed for a
/// create is absent from the schema and from <method>SettableFields</method>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with the public permission described and both fields required, because
/// the vendor's create refuses a body that omits either.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ##class(OcuPilot.Screen.Tool.ResourceUpdate).Described(tSchema, 1)
}

/// <p>The editor's own field rules (<method>OcuPilot.Area.Permissions.ResourceRules.Validate</method>)
/// over the agent's arguments, each broken rule as its field and published sentence (AD-55). The
/// name look-up is skipped: the mint's absence read has answered it.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Screen.Tool.ResourceUpdate).RuleProblem(pIdValue, pArgs, 1, .pProblem)
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
