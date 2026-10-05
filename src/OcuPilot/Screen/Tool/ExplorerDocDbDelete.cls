/// <p>Document databases' drop (AD-6, AD-51, AD-53, Story 19.17): drop one document database of the
/// request's namespace, its class and every document it holds. Two callers reach it: the list's Drop row
/// action through <class>OcuPilot.Api.ScreenAction</class>, after its typed-name dialog, and the agent's
/// proposal and confirmation.</p>
/// <p><b>It is action-style</b> (AD-51): the tool sends no body, and
/// <class>OcuPilot.Port.DocDbPort</class> drops the database its query names in the namespace the
/// proposal read. Its fingerprint covers the database's name, its class and that namespace, so a
/// database re-created since the mint under another class refuses the confirm.</p>
/// <p><b>It is destructive</b>: a dropped database's documents cannot be restored from OcuPilot. Its
/// governance key ships disabled (AD-22), so the agent's proposal is refused at dispatch until an
/// administrator enables it, while the screen's Drop works. Its read-back reads the database gone on the
/// port's 404. No vendor event records a drop (AD-15's sixteenth named case); the drop is performed on
/// the list's own page, which no classic page offers, so it declares no classic page (AD-44).</p>
Class OcuPilot.Screen.Tool.ExplorerDocDbDelete Extends OcuPilot.Screen.Tool.ExplorerDocDbWrite
{

Parameter TOOLNAME = "explorer.docdb.delete";

Parameter DESCRIPTION = "Propose dropping one document database from this namespace: its class and every document it holds, which cannot be restored. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database as this namespace's Document databases list reports it; letter case does not matter. A database whose class begins with OcuPilot is refused, and nothing is dropped while the DocDB service is disabled.";

Parameter WRITETYPE = "DROP";

/// <p>No body: the port drops the database the query names (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>Declared: a dropped database's documents cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>The list's Drop, which admits no value.</p>
Parameter SCREENACTIONS = "delete";

/// <p>A drop acts on the database as it was reviewed, under the class it names.</p>
Parameter PRECONDITIONFIELD = "Class";

Parameter FINGERPRINTSUBJECT = "Name,Class,Namespace";

/// <p>The card's removal rows: what the dropped database held.</p>
Parameter REMOVALROWS = "Name,Class";

/// <p>None: the tool admits no argument beyond the name.</p>
ClassMethod SettableFields() As %List
{
    Quit ""
}

/// <p>What the schema says of the name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The document database to drop, named as this namespace's Document databases list reports it; letter case does not matter. A database the list does not report is refused."
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no
/// after-state.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tNames = $ListFromString(..#REMOVALROWS)
    For tI = 1:1:$ListLength(tNames) {
        Set tField = $List(tNames, tI)
        Set tRow = {}
        Do tRow.%Set("field", tField, "string")
        Do tRow.%Set("before", $Select($IsObject(pFresh): pFresh.%Get(tField) _ "", 1: ""), "string")
        Do tRow.%Set("after", "", "string")
        Do tRow.%Set("removed", 1, "boolean")
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

}
