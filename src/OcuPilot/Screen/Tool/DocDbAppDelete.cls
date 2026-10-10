/// <p>The Doc DB applications' delete tool (AD-6, AD-8, AD-51, Story 18.30): propose removing one record from this
/// instance. It reads the record fresh through the vendor's own <code>DocDB</code> <code>GET</code> and mints a
/// proposal whose card lists the settings it removes. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>DELETE</code> reads no body, so the tool admits no settable
/// field, and the port splits its composite id into the vendor's query. Its fingerprint covers the three settings. The
/// delete removes the record only, as the classic page's does: it declares no consequence, and a document database of
/// the same name is neither read nor changed. It runs on the classic list page itself, so it declares no replaced
/// page.</p>
Class OcuPilot.Screen.Tool.DocDbAppDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "webapp.docdbapps.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DocDbAppList";

Parameter DESCRIPTION = "Propose deleting one Doc DB application record. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace and the record exactly as the Doc DB applications list reports them. Only the record is removed: a document database of that name is left as it is.";

Parameter PORTCLASS = "OcuPilot.Port.DocDbAppPort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted record is gone.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the list's Delete carries out (AD-53).</p>
Parameter SCREENACTIONS = "delete";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Description,Enabled,Resource";

Parameter PRECONDITIONFIELD = "Enabled";

Parameter FINGERPRINTSUBJECT = "Description,Enabled,Resource";

/// <p>The pair this tool requires beyond the list's own: none, and the declaration keeps the idiom of every tool of
/// the area (AD-8). The area's set is what the write needs, measured at Story 18.30's plan.</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "DocDB"
}

/// <p><class>OcuPilot.Screen.Tool.MappingMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.MappingMint"
}

ClassMethod IdParam() As %String
{
    Quit "name"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the namespace and the name described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.DocDbAppCreate).Described(##super(pDescriptor), 0)
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>READANSWERS</parameter> name the read answers, carrying the value the instance holds and no after-state.
/// A read that answered no <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report that record's settings, and a record whose settings are unknown is not one to delete"
            Quit
        }
        Set tNames = ..ReadAnswers()
        For tI = 1:1:$ListLength(tNames) {
            Set tField = $List(tNames, tI)
            If pFresh.%GetTypeOf(tField) = "unassigned" Continue
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

/// <p>What the caller must hold: the list's own pairs, each once (AD-8). The delete runs on the classic list page
/// itself, so it declares no <code>CLASSICPAGES</code> (AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
