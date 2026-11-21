/// <p>The mint every system default setting tool declares as its <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story
/// 24.15): the kernel's own mint, handed the setting's composite id <code>[Production, Item, HostClass, Setting]</code> built from the agent's
/// <code>Production</code>, <code>Item</code>, <code>HostClass</code> and <code>Setting</code>, the id the System default settings list's rows
/// carry, so both callers hand <class>OcuPilot.Port.InteropPort</class> one target grammar. It is
/// <class>OcuPilot.Screen.Tool.InteropSettingMint</class> with the item setting's three leading parts renamed
/// (<parameter>OcuPilot.Screen.Tool.MappingMint.PARTARGUMENTS</parameter>); everything else is its, and the superclass's. A part may be
/// <code>*</code>, which the vendor reads as any, but never empty.</p>
Class OcuPilot.Screen.Tool.InteropDefaultSettingMint Extends OcuPilot.Screen.Tool.InteropItemMint
{

/// <p>The arguments that name the production, the item and the host class the setting applies to.</p>
Parameter PARTARGUMENTS = "Production,Item,HostClass";

Parameter CHILDDESCRIPTION = "the setting";

Parameter SEPARATORNOUNS = "production, item, host class or setting name";

/// <p>What each leading part names, as the refusal for an empty one says it.</p>
ClassMethod PartDescription(pIndex As %Integer) As %String
{
    Quit $Case(pIndex, 1: "the production the setting applies to, or * for any", 2: "the item the setting applies to, or * for any", : "the host class the setting applies to, or * for any")
}

}
