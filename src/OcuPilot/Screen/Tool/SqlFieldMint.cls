/// <p>The mint the field selectivity setter declares as its <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 21.31): the kernel's
/// own mint, handed the field's composite id <code>[Table, Field]</code> built from the agent's <code>Table</code> and <code>Field</code> with
/// <method>OcuPilot.Kernel.EntityId.JoinComposite</method>, the id the table's Field statistics rows carry, so both callers hand
/// <class>OcuPilot.Port.SqlPort</class> one target grammar. Everything else is <class>OcuPilot.Screen.Tool.MappingMint</class>'s.</p>
Class OcuPilot.Screen.Tool.SqlFieldMint Extends OcuPilot.Screen.Tool.MappingMint
{

/// <p>The argument naming the table the field belongs to.</p>
Parameter NAMESPACEARGUMENT = "Table";

Parameter PARENTDESCRIPTION = "the table the field belongs to";

Parameter CHILDDESCRIPTION = "the field";

Parameter SEPARATORNOUNS = "table name or field name";

}
