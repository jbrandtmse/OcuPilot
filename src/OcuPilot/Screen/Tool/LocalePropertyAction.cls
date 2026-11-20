/// <p>The base of the locale property tools (Story 21.16, AD-6, AD-13, AD-51, AD-52, AD-53, AD-58): a write of one property row, table or
/// input/output table of one custom locale through the <code>Properties</code> endpoint of <class>OcuPilot.Port.LocalePort</class>, reached by
/// two callers, the Locale properties screen's actions and the agent's proposal and confirmation. The target is the composite
/// <code>[Locale, Name]</code> (<class>OcuPilot.Screen.Tool.LocalePropertyMint</class>), each part kept exactly (AD-13).</p>
/// <p><b>The fresh read is the port's <code>Properties</code> <code>GET</code></b>: <code>{Locale, Group, Name, Value, Kind, Accepts, ReadOnly,
/// Refusal, Loadable}</code>. It extends <class>OcuPilot.Screen.Tool.LocaleAction</class>, whose pairs and rules it keeps, and differs by its
/// endpoint, its screen and its classic page.</p>
Class OcuPilot.Screen.Tool.LocalePropertyAction Extends OcuPilot.Screen.Tool.LocaleAction [ Abstract ]
{

Parameter ENDPOINTNAME = "Properties";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocalePropertyList";

Parameter CLASSICPAGES = "%CSP.UI.Portal.NLSEdit";

Parameter READANSWERS = "Locale,Group,Name,Value,Kind,Accepts,ReadOnly,Refusal,Loadable";

/// <p>The argument naming the locale the property belongs to.</p>
Parameter LOCALEARGUMENT = "Locale";

/// <p><class>OcuPilot.Screen.Tool.LocalePropertyMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.LocalePropertyMint"
}

/// <p>The row's name, which the card titles the target by.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

/// <p>The derived schema with the locale added and required, as the Locale definitions list's Name column reports it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#LOCALEARGUMENT, {"type": "string", "description": "The custom locale the property belongs to, named exactly as the Locale definitions list reports it in its Name column. A locale InterSystems ships and the current locale are refused."})
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#LOCALEARGUMENT)
    Quit tSchema
}

}
