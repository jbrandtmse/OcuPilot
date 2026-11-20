/// <p>The analytics General settings' value rules (AD-55, Story 24.13): which value a set may not send for the setting a row describes, as one code from
/// <class>OcuPilot.Api.ConfigError</class>, before any vendor call. It is <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class> with the limits of
/// <class>OcuPilot.Port.AnalyticsPort</class>'s own settings (<method>OcuPilot.Port.AnalyticsPort.SettingLimits</method>) in place of the configuration
/// classes', read in the namespace the row names. The Google Maps key, a secret, is refused by the port's own read (<code>ANALYTICS.SETTING.SECRET</code>), which
/// the mint and the write both pass through before these rules are asked.</p>
Class OcuPilot.Area.Analytics.SettingRules Extends OcuPilot.Area.OsMgmt.ConfigSettingRules
{

/// <p>The limits of the setting <var>pName</var>, in the namespace <var>pRow</var> names (the request's scope when it names none).</p>
ClassMethod Limits(pEndpoint As %String, pName As %String, pRow As %DynamicObject = "") As %List
{
    Set tNamespace = $Select($IsObject(pRow) && (pRow.%GetTypeOf("Namespace") = "string"): pRow.%Get("Namespace"), 1: "")
    Quit ##class(OcuPilot.Port.AnalyticsPort).SettingLimits(pName, tNamespace)
}

}
