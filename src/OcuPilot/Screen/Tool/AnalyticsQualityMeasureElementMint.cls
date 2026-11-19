/// <p>The mint every quality measure group and element tool declares as its <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 24.12): the kernel's own mint, handed the
/// element's composite id <code>[QualityMeasure, Group, Name]</code> built from the agent's <code>QualityMeasure</code>, <code>Group</code> and <code>Name</code>, the id the Groups and elements
/// screen's rows carry, so both callers hand <class>OcuPilot.Port.AnalyticsPort</class> one target grammar. An empty <code>Name</code> names the group itself. It is
/// <class>OcuPilot.Screen.Tool.InteropItemMint</class> with the measure and the group as its two leading parts, as <class>OcuPilot.Screen.Tool.InteropSettingMint</class> has two, and an empty name allowed
/// (<parameter>OcuPilot.Screen.Tool.MappingMint.EMPTYNAMEALLOWED</parameter>).</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementMint Extends OcuPilot.Screen.Tool.InteropItemMint
{

/// <p>The arguments that name the measure and the group the element belongs to.</p>
Parameter PARTARGUMENTS = "QualityMeasure,Group";

Parameter CHILDDESCRIPTION = "the element";

Parameter SEPARATORNOUNS = "quality measure, group or element name";

Parameter EMPTYNAMEALLOWED As BOOLEAN = 1;

/// <p>What each leading part names, as the refusal for an empty one says it.</p>
ClassMethod PartDescription(pIndex As %Integer) As %String
{
    Quit $Case(pIndex, 1: "the quality measure the group belongs to", : "the group the element belongs to")
}

}
