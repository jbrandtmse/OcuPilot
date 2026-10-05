/// <p>Document databases' create (AD-54, AD-55, Story 19.17): propose a new document database in the
/// request's namespace. Two callers reach it: the screen's create dialog through
/// <class>OcuPilot.Area.Explorer.DocDbSave</class>, and the agent's proposal and confirmation.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no database of that name in any case, and a
/// name taken since the mint reads present at the confirm's re-read and closes the proposal
/// target-changed. The vendor refuses a taken name or class on its own (#25051, #25070); the absence
/// fingerprint is OcuPilot's guarantee all the same.</p>
/// <p><b>Its payload is the name and the namespace</b> (<method>ComposeCreate</method>): the vendor's
/// <code>CreateDatabase</code> takes the name alone, with no document type and no resource, so the port
/// has no body template to derive a field list from and the one value is the name (AD-3 has no subject).
/// The card shows the name; the namespace rides in the payload, where the port query reads it. Its
/// read-back compares <code>Name</code> (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
/// <p>No vendor event records a create (AD-15's sixteenth named case), and no classic page creates a
/// document database, so it declares no further classic page (AD-44).</p>
Class OcuPilot.Screen.Tool.ExplorerDocDbCreate Extends OcuPilot.Screen.Tool.ExplorerDocDbWrite
{

Parameter TOOLNAME = "explorer.docdb.create";

Parameter DESCRIPTION = "Propose creating a document database in this namespace. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name it as a class name: letters and digits in parts separated by dots, each part starting with a letter. An unqualified name creates the class ISC.DM.<name>, and a qualified name is the class itself. A name this namespace already holds in any letter case, a class that already exists, a package this namespace keeps in another database and a name beginning with OcuPilot are refused, and nothing is created while the DocDB service is disabled. The database is created with no document type and no resource.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "CREATE";

/// <p>What the read-back compares, the one value a create sends (AD-58).</p>
Parameter READBACKFIELDS = "Name";

/// <p>The name, the one value a create sends.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..IdArgument())
}

/// <p>The name as the one field row, a string: the port's create takes nothing else.</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 1
    Set pRows(1) = $ListBuild(..IdArgument(), "string", 0)
    Quit $$$OK
}

/// <p>What the schema says of the name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The name the new document database will take: letters and digits in parts separated by dots, each part starting with a letter, at most 213 characters without a package. An unqualified name creates the class ISC.DM.<name>. A name this namespace already holds, in any letter case, is refused, so check the Document databases list first."
}

/// <p>The composed payload and diff of the create (AD-54): <code>{Name, Namespace}</code>, the name as
/// the caller typed it and the namespace the request is scoped to, and one diff row, the name's. The
/// unchanged count is zero.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ""
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tName = ""
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(pIdArgument) = "string") Set tName = pArgs.%Get(pIdArgument)
    If tName = "" {
        Set pProblem = "'" _ pIdArgument _ "' names the database and cannot be empty"
        Quit $$$OK
    }
    Set pPayload = {}
    Do pPayload.%Set(pIdArgument, tName, "string")
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Set tRow = {}
    Do tRow.%Set("field", pIdArgument, "string")
    Do tRow.%Set("before", "", "string")
    Do tRow.%Set("after", tName, "string")
    Do pDiff.%Push(tRow)
    Quit $$$OK
}

}
