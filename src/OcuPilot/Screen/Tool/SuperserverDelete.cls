/// <p>The superservers' delete tool (AD-6, AD-8, AD-10, AD-51, Story 18.25): propose removing one superserver
/// from this instance. It reads the superserver fresh through the vendor's own <code>Security.Superserver</code>
/// <code>GET</code> and mints a proposal whose card lists the settings it removes. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>DELETE</code> reads no body, so the tool admits no
/// settable field, and <class>OcuPilot.Port.SuperserverPort</class> splits its composite id into the vendor's
/// query. Its fingerprint covers <code>SystemDefault</code>, which decides whether the prohibited set refuses it;
/// the system default superserver and the one the web gateway connects through are refused as
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.SERVINGSUPERSERVER</parameter> from either caller. It declares no replaced classic page: the
/// classic delete is performed on <code>%CSP.UI.Portal.Servers</code> itself, which the list's descriptor already
/// unions (AD-44).</p>
Class OcuPilot.Screen.Tool.SuperserverDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.superservers.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SuperserverList";

Parameter DESCRIPTION = "Propose deleting one superserver of this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the superserver by its port and bind address as the Superservers list reports them. Clients can no longer connect through that port, and it stops listening at once. The superserver the web gateway connects through cannot be deleted.";

Parameter PORTCLASS = "OcuPilot.Port.SuperserverPort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted superserver is gone from the configuration, and its listener is closed.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the superservers list's Delete carries out (AD-53).</p>
Parameter SCREENACTIONS = "delete";

/// <p>What <parameter>READTYPE</parameter> answers that the card lists.</p>
Parameter READANSWERS = "Description,Enabled,SystemDefault";

Parameter PRECONDITIONFIELD = "SystemDefault";

Parameter FINGERPRINTSUBJECT = "SystemDefault";

/// <p>The pair this tool requires beyond Superservers' own: none, and the declaration keeps the idiom of every
/// tool of the area (AD-8). Security's set is what the write needs, measured at Story 18.25's plan.</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.Superserver"
}

ClassMethod IdArgument() As %String
{
    Quit "Port"
}

ClassMethod IdParam() As %String
{
    Quit "port"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><class>OcuPilot.Screen.Tool.SuperserverMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.SuperserverMint"
}

/// <p>The derived schema with the port and the bind address described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.SuperserverCreate).Described(##super(pDescriptor), 0)
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>READANSWERS</parameter> name the read answers, carrying the value the instance holds and no
/// after-state. A read that answered no <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report whether that superserver is its system default, and a superserver whose role is unknown is not one to delete"
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

/// <p>What the caller must hold: Superservers' own pairs, each once (AD-8). The delete runs on the classic list
/// page itself, so it declares no <code>CLASSICPAGES</code> (AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
