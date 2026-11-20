/// <p>Locale definitions' Delete (Story 21.14, AD-6, AD-10, AD-51, AD-53, AD-58): remove one custom locale, a locale whose name starts with
/// <code>y</code>, through <class>OcuPilot.Port.LocalePort</class>. The agent reaches it through a proposal the user confirms; Locale
/// definitions reaches it through its <code>delete</code> row action. A locale InterSystems ships and the current locale are refused before
/// any vendor call (<class>OcuPilot.Area.OsMgmt.LocaleRules</class>).</p>
/// <p><b>It is destructive</b>: a deleted locale cannot be restored from OcuPilot, so its card draws the destructive treatment, its row
/// action types the locale's name, and its governance key ships disabled (AD-22). It sends no body; its fingerprint covers the locale's
/// name and description, and its read-back reads the locale gone on the port's 404.</p>
Class OcuPilot.Screen.Tool.LocaleDelete Extends OcuPilot.Screen.Tool.LocaleAction
{

Parameter TOOLNAME = "osmgmt.locales.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocaleList";

Parameter DESCRIPTION = "Propose deleting one custom locale of this instance, a locale whose name starts with y, which cannot be restored from OcuPilot. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the locale exactly as the Locale definitions list reports it. A locale InterSystems ships, the current locale, and a name the list does not report are refused.";

Parameter WRITETYPE = "DELETE";

Parameter SCREENACTIONS = "delete";

/// <p>Declared: a deleted locale cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

Parameter READANSWERS = "Name,Description,Current,Custom";

Parameter PRECONDITIONFIELD = "Description";

Parameter FINGERPRINTSUBJECT = "Name,Description";

/// <p>The removal rows the card shows: what the removed locale held.</p>
Parameter REMOVALROWS = "Name,Description";

Parameter IDDESCRIPTION = "The custom locale to delete, named exactly as the Locale definitions list reports it in its Name column. A locale InterSystems ships, the current locale, and a locale the list does not report are refused.";

/// <p>The client maps it to the delete consequence, pinned equal to <parameter>OcuPilot.Api.LocaleError.DELETE</parameter>.</p>
Parameter CONSEQUENCECODE = "LOCALE.DELETE";

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: the name and the description the locale holds. A
/// read that answered no <code>Description</code> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Description") '= "string") {
            Set pProblem = "this instance did not report the locale, and a locale whose state is unknown is not one to delete"
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

/// <p><parameter>CONSEQUENCECODE</parameter>, the note the card states.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

}
