/// <p>The Users list's create tool (AD-54, AD-55): propose a new user account on this instance. It
/// reads the intended name fresh through the vendor's own <code>Security.User</code>
/// <code>GET</code>, requires that read to answer <b>nothing</b>, composes the payload from its
/// arguments and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>The password is a secret end to end</b> (AD-3, AD-6, AD-35). It is the create's one
/// authored wrapper field (<class>OcuPilot.Screen.Tool.Classification</class>), declared in
/// <class>OcuPilot.Screen.Descriptor.UserList</class>'s <code>secretArguments</code>, so it is
/// absent from this schema, refused from the model at the mint, never stored, and supplied only at
/// confirm on the card beside the one masked row <method>ComposedSecrets</method> names.</p>
/// <p><b>The vendor body is a wrapper</b>, <code>{User:{...}, Password}</code>; the port builds it
/// (<parameter>OcuPilot.Port.AdminPort.WRAPPEDTYPES</parameter>), so this tool and the screen send
/// the flat field set.</p>
/// <p><b>It admits the fields the create form captures</b>: the four derived literals
/// <parameter>PERMITTEDFIELDS</parameter> names and the authored <code>Roles</code> array, which are
/// exactly the ones <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> has
/// reviewed for a user create. A role that grants <code>%All</code> or an administrative privilege
/// is refused at the write, whatever the caller. <code>EscalationRoles</code> is excluded by
/// name.</p>
Class OcuPilot.Screen.Tool.UserCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.users.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.UserList";

Parameter DESCRIPTION = "Propose a new user account on this instance. It creates nothing by itself: it answers a proposal the user reviews and confirms, and the user types the account's password on the card at that point -- never send a password. Name the account, and optionally its full name, expiration date, startup namespace and routine, and roles.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

/// <p>The AD-14 action a confirmed create performs.</p>
Parameter CHANGEACTION = "created";

/// <p>The vendor request type a create is issued with: <code>Security.User</code>'s
/// <code>POST</code>. Its <code>PUT</code> refuses an absent account with 404, so it is not an
/// upsert and cannot create.</p>
Parameter WRITETYPE = "POST";

/// <p>The derived top-level fields this tool admits, comma-separated: the account settings whose
/// creation AD-10's prohibited set has reviewed
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names these and
/// <parameter>ROLESARGUMENT</parameter>). A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "ExpirationDate,FullName,NameSpace,Routine";

/// <p>The one authored argument: the complete list of roles the new account holds.</p>
Parameter ROLESARGUMENT = "Roles";

/// <p>The subtree AD-10 forbids on every path: an account's escalation roles.</p>
Parameter EXCLUDEDFIELD = "EscalationRoles";

/// <p>The secret the confirm supplies and the payload never carries.</p>
Parameter PASSWORDFIELD = "Password";

/// <p>The pair a create requires: <code>%Admin_Secure:USE</code>, the vendor endpoint's own
/// <code>ResourcesOR()</code> resource and the pair the Users list already declares (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.User"
}

/// <p>The field names the composed payload may set: the <code>ordinary</code> top-level literals
/// this tool admits, derived rather than transcribed (AD-3), plus
/// <parameter>ROLESARGUMENT</parameter>.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#ROLESARGUMENT)
}

/// <p><parameter>EXCLUDEDFIELD</parameter>, so no path of this tool admits an escalation-role
/// grant.</p>
ClassMethod ExcludedFields() As %List
{
    Quit $ListBuild(..#EXCLUDEDFIELD)
}

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a field the prohibited set has not reviewed for a
/// create is absent from the schema and from <method>SettableFields</method>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The declared secrets a create's body carries and its payload does not, for the mint's masked
/// diff rows (AD-6): <parameter>PASSWORDFIELD</parameter>.</p>
ClassMethod ComposedSecrets() As %List
{
    Quit $ListBuild(..#PASSWORDFIELD)
}

/// <p>The derived schema with <parameter>ROLESARGUMENT</parameter> added as an array of role
/// names, closed with <code>additionalProperties: false</code>.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tRoles = {"type": "array", "description": "The roles the new account holds, each named exactly as this instance's own roles list reports it. A role that would grant an administrative privilege is refused, whether it grants it by name, through another role, or as a resource it carries -- %All, %Manager, %Operator and %SecurityAdministrator are all refused."}
    Do tRoles.%Set("items", {"type": "string"})
    Do tSchema.%Get("properties").%Set(..#ROLESARGUMENT, tRoles)
    Quit tSchema
}

/// <p>The screen's own field rules (<method>OcuPilot.Area.Permissions.UserCreateRules.Validate</method>)
/// over the agent's arguments, each broken rule as its field and published sentence (AD-55). The
/// name look-up and the password rules are skipped: the mint's absence read has answered the first,
/// and the password is supplied at confirm.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.Permissions.UserCreateRules).Validate(pIdValue, pArgs, .tViolations, 0, 0)
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
