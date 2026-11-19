/// <p>The mint every quality measure documentation tool declares as its <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 24.12): the kernel's own mint, handed the
/// item's composite id <code>[QualityMeasure, Name]</code> built from the agent's <code>QualityMeasure</code> and <code>Name</code>, the id the Documentation screen's rows carry, so both callers
/// hand <class>OcuPilot.Port.AnalyticsPort</class> one target grammar. It is <class>OcuPilot.Screen.Tool.InteropItemMint</class> with the measure as its first part.</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaMint Extends OcuPilot.Screen.Tool.InteropItemMint
{

/// <p>The argument naming the quality measure the item belongs to.</p>
Parameter NAMESPACEARGUMENT = "QualityMeasure";

Parameter PARENTDESCRIPTION = "the quality measure the documentation item belongs to";

Parameter CHILDDESCRIPTION = "the documentation item";

Parameter SEPARATORNOUNS = "quality measure name or documentation item name";

}
