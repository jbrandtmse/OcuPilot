/// <p>NLS configured defaults' Set value (Story 21.14, AD-4, AD-6, AD-51, AD-53, AD-58): set the locale-format switch, <code>LocaleFormat</code>,
/// the one NLS configured default a person or the agent may change. The agent reaches it through a proposal the user confirms; NLS configured
/// defaults reaches it through its <code>set</code> row action. Every table row is shown and never changed, which
/// <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class> refuses before any vendor call. Its rules, pairs and read-back are
/// <class>OcuPilot.Screen.Tool.ConfigSettingSet</class>'s.</p>
/// <p><b>The current locale is reloaded</b> once the write has read OK, through the same port for both callers
/// (<method>OcuPilot.Port.ConfigPort.ReloadAfterSet</method>): a reload that fails is the failure of an applied write. Its card carries the
/// reload consequence (<parameter>CONSEQUENCECODE</parameter>).</p>
Class OcuPilot.Screen.Tool.NlsDefaultSet Extends OcuPilot.Screen.Tool.ConfigSettingSet
{

Parameter TOOLNAME = "osmgmt.nlsdefaults.set";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.NlsDefaultList";

Parameter DESCRIPTION = "Propose changing the locale-format switch on this instance, LocaleFormat: 1 makes new processes take the current locale's date, time and number formats, 0 the standard ones. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the setting exactly as the NLS configured defaults list reports it; every other row of the list is shown and never changed, and is refused. Changing it reloads the current locale.";

Parameter ENDPOINTNAME = "NLSDefaults";

Parameter CLASSICPAGES = "%CSP.UI.Portal.NLS";

/// <p>The names this tool's own read answers: the setting row and its <code>Source</code>.</p>
Parameter READANSWERS = "Name,Value,Kind,Accepts,Restart,ReadOnly,Purges,Source";

/// <p>The consequence code of a set of the locale-format switch, pinned equal to
/// <parameter>OcuPilot.Api.ConfigError.NLSRELOAD</parameter>.</p>
Parameter RELOADCODE = "CONFIG.NLS.RELOAD";

ClassMethod NameDescription() As %String
{
    Quit "The setting, named exactly as the NLS configured defaults list reports it: only LocaleFormat is changed. A table row the list shows, and a setting the list does not report, are refused."
}

ClassMethod ValueDescription() As %String
{
    Quit "The new value, as text: 1 to use the current locale's date, time and number formats, or 0 for the standard ones. Any other value is refused."
}

/// <p><parameter>RELOADCODE</parameter>: a set of <code>LocaleFormat</code> reloads the current locale.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#RELOADCODE
}

/// <p>The reload of the current locale a change of <code>LocaleFormat</code> owes, once the write has read OK, through the same port
/// <var>pPort</var> (<method>OcuPilot.Port.ConfigPort.ReloadAfterSet</method>), for the setting <var>pIdValue</var> whose fresh read before the
/// write was <var>pFresh</var>. Both callers reach it through <method>OcuPilot.Kernel.Proposal.Operation.ApplyAt</method>.</p>
ClassMethod AfterWrite(pPort As %String, pEndpoint As %String, pIdParam As %String, pIdValue As %String, pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tKnown = $IsObject(pFresh) && (pFresh.%GetTypeOf(..#ARGUMENT) = "string")
    Quit $ClassMethod(pPort, "ReloadAfterSet", pEndpoint, pIdValue, $Select(tKnown: pFresh.%Get(..#ARGUMENT), 1: ""), tKnown, .pHttpStatus, .pFault)
}

/// <p><method>AfterWrite</method> as a copy-out script step (AD-59): the reload of the current locale
/// (<method>OcuPilot.Port.ConfigPort.ReloadSteps</method>), unless the draft's diff <var>pContext</var> shows the value unchanged.</p>
ClassMethod SnippetAfter(pEndpoint As %String, pIdParam As %String, pIdValue As %String, pStoredPayload As %DynamicObject, pContext As %DynamicObject = "") As %DynamicArray
{
    If $IsObject(pContext) && (pContext.%GetTypeOf("diff") = "array") {
        Set tChanged = 0
        Set tIterator = pContext.%Get("diff").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            If tField = ..#ARGUMENT Set tChanged = 1
        }
        If 'tChanged Quit []
    }
    Quit $ClassMethod(..PortClass(), "ReloadSteps", pEndpoint, pIdValue)
}

}
