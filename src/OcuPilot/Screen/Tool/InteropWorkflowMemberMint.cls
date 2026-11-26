/// <p>The mint both workflow member tools declare as their <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 24.17 Batch 3b): the kernel's own mint, handed the
/// membership's composite id <code>[Role, User]</code> built from the agent's <code>Role</code> and <code>User</code> with <method>OcuPilot.Kernel.EntityId.JoinComposite</method>, the id the
/// members list's rows carry, so both callers hand <class>OcuPilot.Port.InteropPort</class> one target grammar. It is <class>OcuPilot.Screen.Tool.InteropItemMint</class> with the role as its
/// first part; the arguments of a tool that creates its target also carry the namespace the proposal read.</p>
Class OcuPilot.Screen.Tool.InteropWorkflowMemberMint Extends OcuPilot.Screen.Tool.InteropItemMint
{

/// <p>The argument naming the workflow role the member belongs to.</p>
Parameter NAMESPACEARGUMENT = "Role";

Parameter PARENTDESCRIPTION = "the workflow role the member belongs to";

Parameter CHILDDESCRIPTION = "the member";

Parameter SEPARATORNOUNS = "role or user name";

}
