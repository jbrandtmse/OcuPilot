/// <p>The archive settings' value rules (AD-55, Story 24.16 Batch 4): which value a set may not send for the setting a row describes, as one code from
/// <class>OcuPilot.Api.ConfigError</class>, before any vendor call. It is <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class> with the limits of
/// <class>OcuPilot.Port.InteropPort</class>'s own three settings (<method>OcuPilot.Port.InteropPort.ArchiveSettingLimits</method>) in place of the configuration classes'.
/// Archive to namespace is a choice of the namespaces the classic page lists other than the one the row names, so a row names its namespace (<code>Namespace</code>); a row that
/// names none is judged against the namespace the request is scoped to. The archive class is read-only: its row's <code>ReadOnly</code> makes it
/// <code>CONFIG.SETTING.READONLY</code>.</p>
Class OcuPilot.Area.Interop.ArchiveSettingRules Extends OcuPilot.Area.OsMgmt.ConfigSettingRules
{

/// <p>The published sentence of the refusal <method>Code</method> answers for <var>pValue</var> and the setting <var>pRow</var> names, or <code>""</code> when the value may be set.</p>
ClassMethod SentenceFor(pEndpoint As %String, pRow As %DynamicObject, pValue As %String) As %String
{
    Set tCode = ..Code(pEndpoint, pRow, pValue)
    If tCode = "" Quit ""
    Quit ##class(OcuPilot.Api.ConfigError).ReasonFor(tCode)
}

/// <p>The limits of the setting <var>pName</var>, for the namespace <var>pRow</var> names or, when it names none, the one the request is scoped to.</p>
ClassMethod Limits(pEndpoint As %String, pName As %String, pRow As %DynamicObject = "") As %List
{
    Set tNamespace = $Select($IsObject(pRow) && (pRow.%GetTypeOf("Namespace") = "string") && (pRow.%Get("Namespace") '= ""): pRow.%Get("Namespace"), 1: ##class(OcuPilot.Kernel.Scope).Current())
    Quit ##class(OcuPilot.Port.InteropPort).ArchiveSettingLimits(pName, tNamespace)
}

}
