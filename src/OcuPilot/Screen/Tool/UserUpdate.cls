/// <p>The Users list's write tool (AD-6, AD-10): propose a change to one account on this instance.
/// It reads the account fresh through the vendor's own <code>Security.User</code> <code>GET</code>,
/// merges the arguments over that object, and mints a proposal the user confirms. It writes
/// nothing.</p>
/// <p><b>It registers by being compiled.</b> <class>OcuPilot.Screen.Tool.Registry</class> lists
/// every concrete class under <package>OcuPilot</package> that extends the tool base, so adding
/// this class is the whole registration; the descriptor declares no action and declaring one would
/// make the screen write-capable, which this story does not own.</p>
/// <p><b>It admits two of the sixteen fields its classified field list carries:</b>
/// <code>Enabled</code>, the one derived literal <parameter>PERMITTEDFIELDS</parameter> names, and
/// <code>Roles</code>, which is authored here rather than derived. Every other field is absent from
/// the schema, so the model cannot author it, and a change to one is refused at the write by
/// <class>OcuPilot.Kernel.Proposal.Prohibited</class> whatever the caller.</p>
/// <p><b>Why <code>Roles</code> is authored and not derived</b> (AD-3). The endpoint's template
/// answers <code>[]</code> for both of its arrays, so the derivation types no member and
/// <class>OcuPilot.Screen.Tool.Classification</class> can only call them <code>opaque</code> --
/// AD-3 names this endpoint's empty <code>Roles</code> as its own <code>opaque</code> example, and
/// <method>OcuPilot.Screen.Tool.Write.FieldRows</method> admits literals alone. Teaching the
/// derivation to type an empty array would invent information the template does not carry, so the
/// element type and the description are written here once, reviewed, which is the authored half
/// AD-3 already sanctions for this same endpoint.</p>
/// <p><b><code>EscalationRoles</code> is excluded as well as unadvertised</b>, because every change
/// to it is prohibited by a predicate of its own: escalation roles grant privilege through a path
/// (AD-10). The reviewed classification calls it <code>opaque</code>, so the schema would refuse it
/// on that ground too; the exclusion is stated here because this is where a reader of the tool looks
/// for it.</p>
Class OcuPilot.Screen.Tool.UserUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.users.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.UserList";

Parameter DESCRIPTION = "Propose a change to one user account on this instance: whether it is enabled, and which roles it holds. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the account exactly as the users list reports it, and send only the fields to change.";

/// <p>The one derived top-level field this tool admits, comma-separated: the
/// <code>Security.User</code> setting whose change AD-10's prohibited set has reviewed and which the
/// derivation types (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method>
/// names this and <parameter>ROLESARGUMENT</parameter>). A test asserts the two agree; the kernel is
/// never read from here.</p>
Parameter PERMITTEDFIELDS = "Enabled";

/// <p>The one authored argument, and the other field the prohibited set has reviewed: the complete
/// replacement list of roles the account holds.</p>
Parameter ROLESARGUMENT = "Roles";

/// <p>The subtree AD-10 forbids: an account's escalation roles.</p>
Parameter EXCLUDEDFIELD = "EscalationRoles";

/// <p>The pair a change to an account requires: <code>%Admin_Secure:USE</code>, which is the
/// vendor endpoint's own <code>ResourcesOR()</code> resource and the classic Users page's resource,
/// and exactly the pair <class>OcuPilot.Screen.Descriptor.UserList</class> already declares for its
/// own read. So the resolved set is the screen's two pairs and nothing else, which is what makes
/// "the same 403 the editor would give" true by construction; no permission an IRIS-shipped role
/// does not grant appears on the path (AD-8 as amended 2026-09-21).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.User"
}

/// <p>The field names the merge may set: the <code>ordinary</code> top-level literals of this
/// tool's own field-list entry (AD-3), plus <parameter>ROLESARGUMENT</parameter>, the one array the
/// derivation cannot type and this tool authors.</p>
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

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a derived field the prohibited set has not
/// reviewed is absent from the schema and from <method>SettableFields</method> whether or not anyone
/// has thought to exclude it by name.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with this tool's one authored argument added (AD-3):
/// <parameter>ROLESARGUMENT</parameter> as an array of role names, replacing the whole list.</p>
/// <p>The property is added rather than emitted by <method>OcuPilot.Screen.Tool.Write.FieldRows</method>
/// because its element type is not in the template -- see the class header. The schema stays closed
/// with <code>additionalProperties: false</code>, so <code>EscalationRoles</code> and every other
/// unadvertised key is refused as an unknown argument.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tRoles = {"type": "array", "description": "The complete list of roles this account is to hold after the change, each named exactly as this instance's own roles list reports it. It replaces the account's current roles rather than adding to them, so a role left out is a role removed. Adding a role that would grant an administrative privilege is refused, whether it grants it by name, through another role, or as a resource it carries -- %All, %Manager, %Operator and %SecurityAdministrator are all refused."}
    Do tRoles.%Set("items", {"type": "string"})
    Do tSchema.%Get("properties").%Set(..#ROLESARGUMENT, tRoles)
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs
/// (<method>OcuPilot.Screen.Gate.RequiredPairs</method>, which unions the declared set with the
/// classic page's custom resource) together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>. The pairs are
/// checked against the caller's current grants by the dispatcher before this tool runs, and again
/// at the write (AD-8, AD-40).</p>
/// <p><b>Each pair once.</b> The write's own pair is one the screen already declares, so appending
/// it unconditionally would put <code>%Admin_Secure:USE</code> in the resolved set twice and the
/// ledger row's pair column would record one check as two.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
