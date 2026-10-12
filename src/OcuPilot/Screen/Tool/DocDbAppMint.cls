/// <p>The mint every Doc DB application tool declares as its <method>OcuPilot.Screen.Tool.Write.MintClass</method>
/// (AD-6, AD-13, Story 18.33): <class>OcuPilot.Screen.Tool.MappingMint</class>'s composition of the record's composite id
/// <code>[Namespace, Name]</code>, with the refusal for an empty namespace or name naming a record rather than a
/// mapping. Everything else is the superclass's, unchanged.</p>
Class OcuPilot.Screen.Tool.DocDbAppMint Extends OcuPilot.Screen.Tool.MappingMint
{

Parameter PARENTDESCRIPTION = "the namespace the record belongs to";

Parameter CHILDDESCRIPTION = "the Doc DB application record";

Parameter SEPARATORNOUNS = "namespace or record name";

}
