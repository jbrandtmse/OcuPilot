/// <p>The Roles list's create tool (AD-54, AD-55): propose a new role on this instance. It reads the
/// intended name fresh through the vendor's own <code>Security.Role</code> <code>GET</code>,
/// requires that read to answer <b>nothing</b>, composes the payload from its arguments and mints a
/// proposal the user confirms. It writes nothing.</p>
/// <p><b>It admits the fields the create form captures</b>: the derived <code>Description</code>
/// and <code>GrantedRoles</code> <parameter>PERMITTEDFIELDS</parameter> names, and the authored
/// <code>Resources</code> array of <code>{Name, Permissions}</code> grants -- exactly the ones
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> has reviewed for a
/// role create. A granted role or a resource grant that grants <code>%All</code> or an
/// administrative privilege is permitted and confirmed as a delete is: the mint marks the proposal
/// destructive and names the privilege (AD-10). <code>EscalationOnly</code> is not admitted.</p>
/// <p>The name travels only as the vendor's <code>name</code> query parameter; the vendor's body
/// validator refuses it as a field.</p>
Class OcuPilot.Screen.Tool.RoleCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.roles.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoleList";

Parameter DESCRIPTION = "Propose a new role on this instance. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the role, and optionally its description, its resource grants and the roles it grants.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

/// <p>The AD-14 action a confirmed create performs.</p>
Parameter CHANGEACTION = "created";

/// <p>The vendor request type a create is issued with: <code>Security.Role</code>'s
/// <code>PUT</code>, the endpoint's only create. It is an <b>upsert</b> -- it modifies a role that
/// already exists and answers 200 -- so the absence fingerprint is what stops a confirmed create
/// rewriting somebody else's role (AD-54).</p>
Parameter WRITETYPE = "PUT";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names these and
/// <parameter>RESOURCESARGUMENT</parameter>). A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "Description,GrantedRoles";

/// <p>The one authored argument: the role's resource grants, each <code>{Name, Permissions}</code>,
/// the vendor's own shape.</p>
Parameter RESOURCESARGUMENT = "Resources";

/// <p>The derived argument whose description this tool replaces: the roles the new role grants.</p>
Parameter GRANTEDROLESARGUMENT = "GrantedRoles";

/// <p>The pair a create requires: <code>%Admin_Secure:USE</code>, the vendor endpoint's own
/// <code>ResourcesOR()</code> resource and one the Roles list already declares (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.Role"
}

/// <p>The field names the composed payload may set: the <code>ordinary</code> top-level fields this
/// tool admits, derived rather than transcribed (AD-3), plus
/// <parameter>RESOURCESARGUMENT</parameter>.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#RESOURCESARGUMENT)
}

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a field the prohibited set has not reviewed for a
/// create is absent from the schema and from <method>SettableFields</method>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with <parameter>RESOURCESARGUMENT</parameter> added as an array of
/// <code>{Name, Permissions}</code> grant objects, and the granted roles described, closed with
/// <code>additionalProperties: false</code>. A grant's own shape is
/// <method>ArgumentProblem</method>'s to refuse, because the schema subset a provider is sent
/// describes no member below a property.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    ; The emitted subset admits no keyword below a property but its type and description, so a
    ; grant's two members are described here and their shape is refused by ArgumentProblem.
    Set tGrantText = "One grant, an object with exactly two members: Name, the resource as this instance's own resources list reports it, and Permissions, the letters granted from R (read), W (write) and U (use) -- a database resource (%DB_) takes R and W, and W only with R; a resource beginning with one of " _ $Replace($Parameter("OcuPilot.Area.Permissions.RoleCreateRules", "USEONLYPREFIXES"), ",", ", ") _ " takes U alone; and any other resource takes any of the three."
    Set tGrant = {"type": "object", "description": (tGrantText)}
    Set tResources = {"type": "array", "description": "The role's resource grants, one per resource. A grant of %All or of any %Admin_ resource is proposable and is confirmed as a delete is."}
    Do tResources.%Set("items", tGrant)
    Do tProperties.%Set(..#RESOURCESARGUMENT, tResources)
    If tProperties.%GetTypeOf(..#GRANTEDROLESARGUMENT) = "object" {
        Do tProperties.%Get(..#GRANTEDROLESARGUMENT).%Set("description", "The roles the new role grants, each named exactly as this instance's own roles list reports it. A role that grants %All or an administrative privilege -- by name, through another role, or as a resource it carries, as %Manager, %Operator and %SecurityAdministrator do -- is proposable and is confirmed as a delete is.", "string")
    }
    Quit tSchema
}

/// <p>The screen's own field rules (<method>OcuPilot.Area.Permissions.RoleCreateRules.Validate</method>)
/// over the agent's arguments, each broken rule as its field and published sentence (AD-55). The
/// name look-up is skipped: the mint's absence read has answered it.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.Permissions.RoleCreateRules).Validate(pIdValue, pArgs, .tViolations, 1, 0)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tField = $List(tViolations(tI), 1)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ tField _ "': " _ tReason
    }
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
