/// <p>Global nodes' Delete (Story 21.5, AD-6, AD-10, AD-51, AD-53, AD-58): remove one node and every node below it through
/// <class>OcuPilot.Port.GlobalPort</class>. It is the node page's <code>delete</code> row action, after its typed-name dialog, and a
/// person's alone: it is unadvertised (<parameter>ADVERTISED</parameter> 0, AD-53's named case) because a node's reference and value never
/// reach the model (AD-36), so the provider's tool list, the dispatch lookup and the screen context's <code>tools</code> never carry it, and
/// its key ships disabled. A person's own delete is never asked governance (AD-22).</p>
/// <p><b>It is destructive</b>: a deleted node cannot be restored from OcuPilot. Its fingerprint covers the node's reference, whether it
/// is defined and the namespace; its read-back reads the node gone on the port's 404.</p>
Class OcuPilot.Screen.Tool.ExplorerGlobalNodeDelete Extends OcuPilot.Screen.Tool.ExplorerGlobalNodeWrite
{

Parameter TOOLNAME = "explorer.globalnodes.delete";

Parameter DESCRIPTION = "Delete one node of a global, and every node below it, as the global node page's Delete does once confirmed. A person's own confirmed delete reaches this tool; it is never offered to the agent.";

Parameter WRITETYPE = "DELETE";

/// <p>Declared: a deleted node cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

Parameter SCREENACTIONS = "delete";

Parameter PRECONDITIONFIELD = "Defined";

Parameter FINGERPRINTSUBJECT = "Reference,Defined,Namespace";

Parameter REMOVALROWS = "Reference";

Parameter IDDESCRIPTION = "The node to delete, as its canonical reference.";

/// <p>The client maps it to the node delete consequence, pinned equal to <parameter>OcuPilot.Api.GlobalError.NODEDELETE</parameter>.</p>
Parameter CONSEQUENCECODE = "GLOBAL.NODE.DELETE";

/// <p>None: the tool admits no argument beyond the reference.</p>
ClassMethod SettableFields() As %List
{
    Quit ""
}

/// <p>The removal row this proposal's card shows, from the fresh read <var>pFresh</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = ..RemovalRows(pFresh)
    Set pProblem = ""
    Quit $$$OK
}

}
