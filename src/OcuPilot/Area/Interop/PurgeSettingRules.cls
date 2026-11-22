/// <p>The purge data settings' value rules (AD-55, Story 24.16): which value a set may not send for the setting a row describes, as one code from
/// <class>OcuPilot.Api.ConfigError</class>, before any vendor call. It is <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class> with the limits of
/// <class>OcuPilot.Port.InteropPort</class>'s own four settings (<method>OcuPilot.Port.InteropPort.PurgeSettingLimits</method>) in place of the configuration
/// classes'. The limits do not depend on the namespace, so the rules judge a value the same wherever a confirm is sent from.</p>
Class OcuPilot.Area.Interop.PurgeSettingRules Extends OcuPilot.Area.OsMgmt.ConfigSettingRules
{

/// <p>The published sentence of the refusal <method>Code</method> answers for <var>pValue</var> and the setting <var>pRow</var> names, or <code>""</code> when the value may be set.</p>
ClassMethod SentenceFor(pEndpoint As %String, pRow As %DynamicObject, pValue As %String) As %String
{
    Set tCode = ..Code(pEndpoint, pRow, pValue)
    If tCode = "" Quit ""
    Quit ##class(OcuPilot.Api.ConfigError).ReasonFor(tCode)
}

/// <p>The limits of the setting <var>pName</var>.</p>
ClassMethod Limits(pEndpoint As %String, pName As %String, pRow As %DynamicObject = "") As %List
{
    Quit ##class(OcuPilot.Port.InteropPort).PurgeSettingLimits(pName)
}

}
