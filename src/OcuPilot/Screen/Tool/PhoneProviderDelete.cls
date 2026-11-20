/// <p>The mobile phone providers' delete tool (AD-6, AD-8, AD-22, AD-51, Story 21.10): propose removing one provider from
/// this instance. It reads the provider fresh through <class>OcuPilot.Port.PhoneProviderPort</class>'s <code>GET</code> and
/// mints a proposal whose card lists the SMS gateway it removes. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the port's <code>DELETE</code> reads no body, so the tool admits no settable
/// field. Its fingerprint covers the SMS gateway. <b>The port refuses a provider that users name</b>, before any vendor
/// call, with <code>PHONEPROVIDER.INUSE</code>, so the same refusal reaches the agent's confirm and the person's action.
/// The delete runs on the classic list page itself, so it declares no replaced page.</p>
Class OcuPilot.Screen.Tool.PhoneProviderDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.phoneproviders.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.PhoneProviderList";

Parameter DESCRIPTION = "Propose deleting one mobile phone provider. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the provider exactly as the Mobile phone providers list reports it. A provider that one or more users name for two-factor text messages is refused, and those users' provider must be changed first.";

Parameter PORTCLASS = "OcuPilot.Port.PhoneProviderPort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "DELETE";

/// <p>No body: the port reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted provider is gone.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the list's Delete carries out (AD-53).</p>
Parameter SCREENACTIONS = "delete";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "SMSGateway";

Parameter PRECONDITIONFIELD = "SMSGateway";

Parameter FINGERPRINTSUBJECT = "SMSGateway";

/// <p>The client maps it to <code>phoneProviderDeleteConsequence</code>.</p>
Parameter CONSEQUENCECODE = "PHONEPROVIDER.DELETE";

/// <p>The pair this tool requires beyond the list's own: none, and the declaration keeps the idiom of every tool of the
/// area (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "PhoneProviders"
}

/// <p><class>OcuPilot.Screen.Tool.PhoneProviderMint</class>, which refuses an empty name in the published sentence.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.PhoneProviderMint"
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

/// <p>The derived schema with the name described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.PhoneProviderCreate).Described(##super(pDescriptor), 0)
}

/// <p><parameter>CONSEQUENCECODE</parameter>, for every payload.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>READANSWERS</parameter> name the read answers, carrying the value the instance holds and no after-state. A
/// read that answered no <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report that provider's SMS gateway, and a provider whose settings are unknown is not one to delete"
            Quit
        }
        Set pRows = ..RemovalRows(pFresh, 1, ..ReadAnswers())
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
