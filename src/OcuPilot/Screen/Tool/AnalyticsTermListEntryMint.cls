/// <p>The mint every term list entry tool declares as its <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 24.2):
/// the kernel's own mint, handed the entry's composite id <code>[TermList, Key]</code> built from the agent's <code>TermList</code> and
/// <code>Key</code>, the id the Entries screen's rows carry, so both callers hand <class>OcuPilot.Port.AnalyticsPort</class> one target
/// grammar. It is <class>OcuPilot.Screen.Tool.InteropItemMint</class> with the list as its first part.</p>
Class OcuPilot.Screen.Tool.AnalyticsTermListEntryMint Extends OcuPilot.Screen.Tool.InteropItemMint
{

/// <p>The argument naming the term list the entry belongs to.</p>
Parameter NAMESPACEARGUMENT = "TermList";

Parameter PARENTDESCRIPTION = "the term list the entry belongs to";

Parameter CHILDDESCRIPTION = "the entry";

Parameter SEPARATORNOUNS = "term list name or key";

}
