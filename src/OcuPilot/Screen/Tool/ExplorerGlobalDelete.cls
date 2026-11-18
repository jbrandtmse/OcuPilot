/// <p>Globals' Delete (Story 21.5, AD-6, AD-10, AD-51, AD-53, AD-58): remove one whole global of the request's namespace, every node in it,
/// through <class>OcuPilot.Port.GlobalPort</class>. Two callers reach it: the list's Delete row action through
/// <class>OcuPilot.Api.ScreenAction</class>, after its typed-name dialog, and the agent's proposal and confirmation.</p>
/// <p><b>It is action-style</b> (AD-51): the tool sends no body, and the port kills the global its query names in the namespace the proposal
/// read. Its fingerprint covers the global's name, whether it holds data, every directory its mapping rows resolve to, and that namespace.</p>
/// <p><b>It is destructive</b>: a deleted global cannot be restored from OcuPilot. Its governance key ships disabled (AD-22), so the agent's
/// proposal is refused at dispatch until an administrator enables it, while the screen's Delete works. A global whose name begins with an
/// OcuPilot name stem, one stored in OcuPilot's own or a protected system database, and OcuPilot's own code globals are refused by the
/// kernel on both callers.</p>
Class OcuPilot.Screen.Tool.ExplorerGlobalDelete Extends OcuPilot.Screen.Tool.ExplorerGlobalWrite
{

Parameter TOOLNAME = "explorer.globals.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerGlobalList";

Parameter DESCRIPTION = "Propose deleting one whole global from this namespace: every node in it, which cannot be restored. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the global as this namespace's Globals list reports it, without the ^. A global that holds OcuPilot's own data or the instance's protected system data is refused, and nothing is deleted for a global the list does not report.";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "DELETE";

/// <p>Declared: a deleted global cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>The list's Delete, which admits no value.</p>
Parameter SCREENACTIONS = "delete";

Parameter READANSWERS = "Name,Defined,Locations,Namespace";

/// <p>A delete acts on the global as it was reviewed, holding data.</p>
Parameter PRECONDITIONFIELD = "Defined";

Parameter FINGERPRINTSUBJECT = "Name,Defined,Locations,Namespace";

/// <p>The card's removal rows: what the deleted global is named.</p>
Parameter REMOVALROWS = "Name";

Parameter IDDESCRIPTION = "The global to delete, named as this namespace's Globals list reports it in its Name column, without the ^. A global the list does not report is refused.";

/// <p>The client maps it to the delete consequence (<code>OcuPilot.Api.GlobalError</code>'s <code>DELETE</code>).</p>
Parameter CONSEQUENCECODE = "GLOBAL.DELETE";

/// <p>The endpoint the global is read and killed through.</p>
ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.GlobalPort).#ENDPOINTGLOBALS
}

/// <p>None: the tool admits no argument beyond the name.</p>
ClassMethod SettableFields() As %List
{
    Quit ""
}

/// <p>The query key the port reads the global's name from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.GlobalPort).#NAMEKEY
}

/// <p>A name that is no global name, refused as the port refuses it (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = $Select(##class(OcuPilot.Port.GlobalPort).NameValid(pIdValue): "", 1: ##class(OcuPilot.Port.GlobalPort).#REASONNAME)
    Quit $$$OK
}

/// <p>The removal row this proposal's card shows, from the fresh read <var>pFresh</var>. A global that holds no data is
/// <var>pProblem</var>: there is nothing to delete.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || 'pFresh.%Get("Defined") {
        Set pProblem = ##class(OcuPilot.Port.GlobalPort).ReasonFor("GLOBAL.NOTFOUND")
        Quit $$$OK
    }
    Set pRows = ..RemovalRows(pFresh)
    Quit $$$OK
}

/// <p>Whether the global is gone although the read-back's <code>GET</code> <var>pAfter</var> answered: it holds no data (AD-58).</p>
ClassMethod ReadBackGone(pAfter As %DynamicObject, pPayload As %DynamicObject) As %Boolean
{
    If '$IsObject(pAfter) Quit 0
    Quit (pAfter.%GetTypeOf("Defined") = "boolean") && 'pAfter.%Get("Defined")
}

}
