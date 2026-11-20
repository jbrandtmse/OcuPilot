/// <p>The mint every mobile phone provider tool declares as its
/// <method>OcuPilot.Screen.Tool.Write.MintClass</method> (AD-6, Story 21.10): the managed file transfer connection
/// mint, whose empty-name refusal answers this class's <parameter>NAMECODE</parameter>. Everything else is the
/// superclass's, unchanged.</p>
Class OcuPilot.Screen.Tool.PhoneProviderMint Extends OcuPilot.Screen.Tool.MftConnectionMint
{

/// <p>The violation code of an empty name, whose sentence <method>OcuPilot.Api.Error.ReasonForViolation</method>
/// answers.</p>
Parameter NAMECODE = "PHONEPROVIDER.NAME";

}
