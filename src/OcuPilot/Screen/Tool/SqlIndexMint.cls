/// <p>The mint the index rebuild declares as its <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 21.25): the kernel's own
/// mint, handed the index's composite id <code>[Table, Map]</code> built from the agent's <code>Table</code> and <code>Map</code> with
/// <method>OcuPilot.Kernel.EntityId.JoinComposite</method>, the id the table's indices rows carry, so both callers hand
/// <class>OcuPilot.Port.SqlPort</class> one target grammar. Everything else is <class>OcuPilot.Screen.Tool.MappingMint</class>'s.</p>
Class OcuPilot.Screen.Tool.SqlIndexMint Extends OcuPilot.Screen.Tool.MappingMint
{

/// <p>The argument naming the table the index belongs to.</p>
Parameter NAMESPACEARGUMENT = "Table";

Parameter PARENTDESCRIPTION = "the table the index belongs to";

Parameter CHILDDESCRIPTION = "the index's SQL map";

Parameter SEPARATORNOUNS = "table name or SQL map name";

}
