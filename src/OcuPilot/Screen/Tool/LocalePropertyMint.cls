/// <p>The mint every locale property tool declares as its <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, AD-13, Story 21.16):
/// the kernel's own mint, handed the property row's composite id <code>[Locale, Name]</code> built from the agent's <code>Locale</code> and
/// <code>Name</code>, the id the properties screen's rows carry, so both callers hand <class>OcuPilot.Port.LocalePort</class> one target
/// grammar. <code>Name</code> is the property's own name, or <code>&lt;list&gt;:&lt;table&gt;</code> for a table; everything else is
/// <class>OcuPilot.Screen.Tool.MappingMint</class>'s.</p>
Class OcuPilot.Screen.Tool.LocalePropertyMint Extends OcuPilot.Screen.Tool.MappingMint
{

/// <p>The argument naming the locale the property belongs to.</p>
Parameter NAMESPACEARGUMENT = "Locale";

Parameter PARENTDESCRIPTION = "the locale the property belongs to";

Parameter CHILDDESCRIPTION = "the property or table";

Parameter SEPARATORNOUNS = "locale or property name";

}
