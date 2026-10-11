/// <p>The mint every item setting tool declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 20.22): the kernel's own mint, handed
/// the setting's composite id <code>[Production, Item, Target, Name]</code> built from the agent's
/// <code>Production</code>, <code>Item</code>, <code>Target</code> and <code>Name</code>, the id the Item settings
/// list's rows carry, so both callers hand <class>OcuPilot.Port.InteropPort</class> one target grammar. It is
/// <class>OcuPilot.Screen.Tool.InteropItemMint</class> with three leading parts instead of one
/// (<parameter>OcuPilot.Screen.Tool.MappingMint.PARTARGUMENTS</parameter>); everything else is its, and the
/// superclass's.</p>
Class OcuPilot.Screen.Tool.InteropSettingMint Extends OcuPilot.Screen.Tool.InteropItemMint
{

/// <p>The arguments that name the item and the group of settings the setting belongs to.</p>
Parameter PARTARGUMENTS = "Production,Item,Target";

Parameter CHILDDESCRIPTION = "the setting";

Parameter SEPARATORNOUNS = "production, item, group or setting name";

/// <p>What each leading part names, as the refusal for an empty one says it.</p>
ClassMethod PartDescription(pIndex As %Integer) As %String
{
    Quit $Case(pIndex, 1: "the production the item belongs to", 2: "the item the setting belongs to", : "the group the setting belongs to: Core, Host or Adapter")
}

}
