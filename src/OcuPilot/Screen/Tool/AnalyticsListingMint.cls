/// <p>The mint every listing tool declares as its <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 24.11): the kernel's own mint, handed the listing's
/// composite id <code>[ListingGroup, Name]</code> built from the agent's <code>ListingGroup</code> and <code>Name</code>, the id the Listings screen's rows carry, so both callers hand
/// <class>OcuPilot.Port.AnalyticsPort</class> one target grammar. It is <class>OcuPilot.Screen.Tool.InteropItemMint</class> with the group as its first part.</p>
Class OcuPilot.Screen.Tool.AnalyticsListingMint Extends OcuPilot.Screen.Tool.InteropItemMint
{

/// <p>The argument naming the listing group the listing belongs to.</p>
Parameter NAMESPACEARGUMENT = "ListingGroup";

Parameter PARENTDESCRIPTION = "the listing group the listing belongs to";

Parameter CHILDDESCRIPTION = "the listing";

Parameter SEPARATORNOUNS = "listing group name or listing name";

}
