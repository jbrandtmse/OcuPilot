/// <p>The mint every production item tool declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 20.3): the kernel's own mint,
/// handed the item's composite id <code>[Production, Name]</code> built from the agent's
/// <code>Production</code> and <code>Name</code> with <method>OcuPilot.Kernel.EntityId.JoinComposite</method>,
/// the id the Production items list's rows carry, so both callers hand
/// <class>OcuPilot.Port.InteropPort</class> one target grammar. It is
/// <class>OcuPilot.Screen.Tool.MappingMint</class>'s composition with the production as its first part;
/// everything else is the superclass's.</p>
Class OcuPilot.Screen.Tool.InteropItemMint Extends OcuPilot.Screen.Tool.MappingMint
{

/// <p>The argument naming the production the item belongs to.</p>
Parameter NAMESPACEARGUMENT = "Production";

Parameter PARENTDESCRIPTION = "the production the item belongs to";

Parameter CHILDDESCRIPTION = "the item";

Parameter SEPARATORNOUNS = "production or item name";

}
