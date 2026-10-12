/// <p>Interoperability's lookup table delete (AD-6, AD-10, AD-51, AD-53, AD-62, Story 20.5): remove one lookup table and every
/// entry in it. A rule or transformation that reads the table then gets its default value, which the card says
/// (<code>INTEROP.LOOKUP.DELETE</code>).</p>
/// <p><b>It is destructive</b>: a deleted table cannot be restored from OcuPilot, so its card draws the destructive treatment and
/// shows how many entries go, its row action types the table's name, and its governance key ships disabled (AD-22). The
/// fingerprint covers the entry count and the table's stamp, so a table changed after the mint closes the proposal
/// target-changed. Its read-back reads the table gone on the port's 404.</p>
/// <p>Two callers reach it: the tables list's row action Delete through <class>OcuPilot.Api.ScreenAction</class> and the agent's
/// proposal and confirmation. It declares <code>%Ens_LookupTables:WRITE</code> and WRITE on the namespace's globals database
/// beyond the screen's pairs (AD-8, AD-62), and no <code>CLASSICPAGES</code>: the operation is the classic page's own (AD-44).</p>
Class OcuPilot.Screen.Tool.InteropLookupTableDelete Extends OcuPilot.Screen.Tool.InteropAction
{

Parameter TOOLNAME = "interop.lookuptables.delete";

Parameter DESCRIPTION = "Propose deleting one lookup table of the namespace the user is working in, with every entry in it, which cannot be restored. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the table exactly as the Lookup tables list reports it in its Name column, letter case included. Rules and transformations that read the table then get their default value. A table the namespace does not hold and a namespace under source control are refused. If the table changes before the proposal is confirmed, nothing is deleted.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropLookupTableList";

/// <p>The fresh read: one table with its entry count and stamp.</p>
Parameter READTYPE = "LOOKUPTABLE";

Parameter READANSWERS = "Name,Entries,Modified,Namespace";

Parameter WRITERESOURCE = "%Ens_LookupTables";

Parameter SCREENACTIONS = "delete";

Parameter WRITETYPE = "DELETETABLE";

/// <p>Declared: a deleted table and its entries cannot be restored from OcuPilot.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

/// <p>The table read the confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Modified";

Parameter FINGERPRINTSUBJECT = "Name,Entries,Modified";

Parameter PRECONDITIONFIELD = "Entries";

Parameter CONSEQUENCECODE = "INTEROP.LOOKUP.DELETE";

Parameter PRECONDITIONCODES = "INTEROP.LOOKUP.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The removal rows the card shows: the table and how many entries it holds.</p>
Parameter REMOVALROWS = "Name,Entries";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTLOOKUPTABLES
}

/// <p>The table's name, which the card titles it by: the fresh read's <code>Name</code>, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

/// <p>The derived schema with the table's name described: the target is one table, named as the Lookup tables list reports it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The lookup table, named exactly as this namespace's Lookup tables list reports it in its Name column, letter case included. A table the list does not report is refused.", "string")
    }
    Quit tSchema
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no after-state. A read that answered no
/// entry count is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Entries") '= "number") {
            Set pProblem = "this instance did not report the table's entries, and a table whose state is unknown is not one to delete"
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

}
