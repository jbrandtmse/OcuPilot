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

/// <p>Whether <var>pValue</var> is one the limits <var>pLimits</var> accept, as <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class> judges it, except that a
/// description keeps its line breaks, as the classic page's text area does: a carriage return and a line feed are accepted in text, and every other control
/// character is refused. Pure.</p>
ClassMethod ValueHolds(pLimits As %List, pValue As %String) As %Boolean
{
    If $ListGet(pLimits, 1) '= "text" Quit ##super(pLimits, pValue)
    If $Length(pValue) > $ListGet(pLimits, 5) Quit 0
    Quit ##super(pLimits, $Translate(pValue, $Char(13, 10)))
}

/// <p>The limits of the setting <var>pName</var>.</p>
ClassMethod Limits(pEndpoint As %String, pName As %String, pRow As %DynamicObject = "") As %List
{
    Quit ##class(OcuPilot.Port.InteropPort).PurgeSettingLimits(pName)
}

}
