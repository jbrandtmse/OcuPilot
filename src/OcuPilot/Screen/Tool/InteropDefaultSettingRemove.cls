/// <p>Interoperability's system default setting remove (AD-6, AD-10, AD-51, AD-53, AD-62, Story 24.15): remove one system default setting of
/// the request's namespace. Items that took its value use their own setting or the class default again
/// (<code>INTEROP.DEFAULTSETTING.REMOVE</code>), once the production is updated.</p>
/// <p><b>It is destructive</b>: a removed setting cannot be restored from OcuPilot, so its card draws the destructive treatment, its row
/// action types the setting's name, and its governance key ships disabled (AD-22). Its read-back reads the setting gone on the port's 404.</p>
/// <p>Two callers reach it: the list's row action Remove through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and
/// confirmation. Its state, fingerprint and refusals are <class>OcuPilot.Screen.Tool.InteropDefaultSettingAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropDefaultSettingRemove Extends OcuPilot.Screen.Tool.InteropDefaultSettingAction
{

Parameter TOOLNAME = "interop.defaultsettings.remove";

Parameter DESCRIPTION = "Propose removing one system default setting of the namespace the user is working in, which cannot be restored. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production, the item, the host class and the setting exactly as the System default settings list reports them. Items that took the setting's value use their own setting or the class default again. A setting whose name holds a credential, a setting the namespace does not hold and a namespace under source control are refused.";

Parameter SCREENACTIONS = "remove";

Parameter WRITETYPE = "REMOVEDEFAULT";

/// <p>Declared: a removed setting cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>One static sentence.</p>
Parameter CONSEQUENCECODE = "INTEROP.DEFAULTSETTING.REMOVE";

/// <p>The setting's name, value, description and flag: what the removal reviewed, so a setting edited since the review closes the proposal
/// target-changed; and its namespace, which the stored payload keeps so the confirm and the script form act where the proposal read.</p>
Parameter FINGERPRINTSUBJECT = "Setting,Value,Description,Deployable,Namespace";

Parameter PRECONDITIONFIELD = "Value";

/// <p>The removal rows the card shows: what the removed setting held.</p>
Parameter REMOVALROWS = "Setting,Value,Description";

Parameter PRECONDITIONCODES = "INTEROP.DEFAULTSETTING.SECRET,INTEROP.DEFAULTSETTING.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per <parameter>REMOVALROWS</parameter> name,
/// carrying the value the instance holds and no after-state. A read that answered no <code>Value</code> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Value") '= "string") {
            Set pProblem = "this instance did not report the default setting, and a setting whose state is unknown is not one to remove"
            Quit
        }
        Set pRows = ..RemovalRows(pFresh)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
