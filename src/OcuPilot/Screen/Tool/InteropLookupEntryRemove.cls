/// <p>Interoperability's lookup entry remove (AD-6, AD-10, AD-51, AD-53, AD-62, Story 20.5): remove one entry from a lookup
/// table. Removing a table's last entry removes the table too (measured), which the card says
/// (<code>INTEROP.LOOKUP.REMOVE</code>). A rule or transformation that reads the key then gets its default value.</p>
/// <p><b>It is destructive</b>: a removed entry cannot be restored from OcuPilot, so its card draws the destructive treatment, its
/// row action types the entry's key, and its governance key ships disabled (AD-22). Its read-back reads the entry gone on the
/// port's 404.</p>
/// <p>Two callers reach it: the entries list's row action Remove through <class>OcuPilot.Api.ScreenAction</class> and the agent's
/// proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropLookupEntryAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropLookupEntryRemove Extends OcuPilot.Screen.Tool.InteropLookupEntryAction
{

Parameter TOOLNAME = "interop.lookupentries.remove";

Parameter DESCRIPTION = "Propose removing one entry from a lookup table of the namespace the user is working in, which cannot be restored. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the table and the entry's key as the Lookup tables and entries lists report them. Removing a table's last entry removes the table too. Rules and transformations that read the key then get their default value. An entry the table does not hold and a namespace under source control are refused.";

Parameter SCREENACTIONS = "remove";

Parameter WRITETYPE = "REMOVEENTRY";

/// <p>Declared: a removed entry cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>One static sentence: it also covers the table taken with a last entry.</p>
Parameter CONSEQUENCECODE = "INTEROP.LOOKUP.REMOVE";

Parameter FINGERPRINTSUBJECT = "Key,Value";

Parameter PRECONDITIONFIELD = "Value";

/// <p>The removal rows the card shows: what the removed entry held.</p>
Parameter REMOVALROWS = "Key,Value";

Parameter PRECONDITIONCODES = "INTEROP.LOOKUP.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>A remove carries no value, so the key's secret rule is not asked of it.</p>
Parameter REFUSESSECRET As BOOLEAN = 0;

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no after-state. A read that answered no
/// <code>Value</code> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Value") '= "string") {
            Set pProblem = "this instance did not report the entry, and an entry whose state is unknown is not one to remove"
            Quit
        }
        Set tNames = $ListFromString(..#REMOVALROWS)
        For tI = 1:1:$ListLength(tNames) {
            Set tField = $List(tNames, tI)
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField)), "string")
            Do tRow.%Set("after", "", "string")
            Do tRow.%Set("removed", 1, "boolean")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>What the schema says of the entry's key.</p>
ClassMethod NameDescription() As %String
{
    Quit "The entry to remove, named exactly as the table's entries list reports it in its Key column. An entry the list does not report is refused."
}

}
