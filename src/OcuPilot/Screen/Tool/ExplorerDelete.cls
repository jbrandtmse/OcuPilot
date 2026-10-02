/// <p>System Explorer's delete of a set of documents (AD-6, AD-51, AD-53, Story 19.2): what the
/// Classes and Routines lists' delete tools share. Both callers send the whole set in one call. The
/// vendor removes each document's source and compiled code and keeps a persistent class's data
/// (measured, as the classic page does), and answers each document's own result, which the port maps
/// to a port-owned reason (<method>OcuPilot.Port.AtelierPort.DeleteReason</method>).</p>
/// <p><b>It is destructive</b>: a deleted document cannot be restored from OcuPilot. Its fingerprint
/// subject is each held document's modified time, the missing ones and the namespace, so a document
/// changed since the proposal refuses the confirm. Its read-back reads <code>DOCS</code> again and is
/// gone only once no document of the set is held (<method>ReadBackGone</method>). The classic lists
/// delete on their own pages, so it declares no further classic page (AD-44).</p>
Class OcuPilot.Screen.Tool.ExplorerDelete Extends OcuPilot.Screen.Tool.ExplorerWrite [ Abstract ]
{

/// <p>The list's delete, which admits no value.</p>
Parameter SCREENACTIONS = "delete";

Parameter WRITETYPE = "DELETE";

/// <p>Declared: a deleted document cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>A delete acts on the documents as they were reviewed, each at its modified time.</p>
Parameter PRECONDITIONFIELD = "Modified";

Parameter FINGERPRINTSUBJECT = "Modified,Absent,Namespace";

/// <p>None: the tool admits no argument beyond the set.</p>
ClassMethod SettableFields() As %List
{
    Quit ""
}

/// <p>The one state row this proposal's card shows: <code>Documents</code>, removed, whose
/// before-value names the documents the fresh read <var>pFresh</var> holds.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tRow = {}
    Do tRow.%Set("field", ..#STATEFIELD, "string")
    Do tRow.%Set("before", ..NamesShown(pFresh, "Present"), "string")
    Do tRow.%Set("after", "", "string")
    Do tRow.%Set("removed", 1, "boolean")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

/// <p>Whether the set is gone although the read-back's <code>DOCS</code> <var>pAfter</var> answered:
/// it holds none of the set's documents (AD-58). A set any of whose documents survives reads back
/// present.</p>
ClassMethod ReadBackGone(pAfter As %DynamicObject, pPayload As %DynamicObject) As %Boolean
{
    If '$IsObject(pAfter) Quit 0
    Quit (pAfter.%GetTypeOf("Present") = "string") && (pAfter.%Get("Present") = "")
}

}
