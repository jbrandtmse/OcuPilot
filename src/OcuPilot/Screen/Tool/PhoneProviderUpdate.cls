/// <p>The mobile phone providers' edit tool (AD-4, AD-6, AD-55, Story 21.10): propose a change to one provider's SMS
/// gateway. It reads the provider fresh through <class>OcuPilot.Port.PhoneProviderPort</class>'s <code>GET</code>, merges
/// the arguments over that object and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read's settable member with the change applied (AD-4). The name is the id
/// and never changes. <b>Every rule is decided before the write</b>
/// (<class>OcuPilot.Area.Security.PhoneProviderRules</class>), on both callers, and judges the gateway only when the change
/// moves it.</p>
Class OcuPilot.Screen.Tool.PhoneProviderUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.phoneproviders.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.PhoneProviderList";

Parameter DESCRIPTION = "Propose a change to one mobile phone provider's SMS gateway. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the provider exactly as the Mobile phone providers list reports it and give the new SMS gateway, 1 to 50 characters. The provider's name cannot be changed.";

Parameter PORTCLASS = "OcuPilot.Port.PhoneProviderPort";

Parameter READTYPE = "GET";

/// <p>The port's set of the SMS gateway.</p>
Parameter WRITETYPE = "SET";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The one setting this tool admits
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names the same).</p>
Parameter PERMITTEDFIELDS = "SMSGateway";

/// <p>The member the read-back compares: the port is not an admin endpoint, so no generated field list names it (AD-58).</p>
Parameter READBACKFIELDS = "SMSGateway";

/// <p>The pair this tool requires beyond the list's own: none (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

/// <p>The classic editor whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.PhoneProvider";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.Security.PhoneProviderRules";

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

/// <p>The <code>ordinary</code> derived fields this tool admits (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The one field an edit sends, a string (AD-3): the port is not an admin endpoint, so no generated field list
/// holds it.</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 1
    Set pRows(1) = $ListBuild("SMSGateway", "string", 0)
    Quit $$$OK
}

/// <p>The derived schema with the name and the SMS gateway described
/// (<method>OcuPilot.Screen.Tool.PhoneProviderCreate.Described</method>).</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.PhoneProviderCreate).Described(##super(pDescriptor), 0)
}

/// <p>The kernel's merge over the fresh read, then every rule over the payload it would send, against the fresh read, whose
/// first refusal is <var>pProblem</var>: so the mint, the confirm's fingerprint re-merge and the Save take one payload and
/// one refusal, before the port is written to.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tSC = $ClassMethod(..#RULES, "Problem", "", pPayload, pFresh, "update", ..PortClass(), .pProblem, 1)
    If $$$ISERR(tSC) || (pProblem '= "") {
        Set pPayload = ""
        Set pDiff = []
        Set pUnchanged = 0
    }
    Quit tSC
}

/// <p>The rules that need no fresh read, over the agent's arguments, so a refusal costs no port call (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit $ClassMethod(..#RULES, "Problem", "", pArgs, "", "update", ..PortClass(), .pProblem, 0)
}

/// <p>The same rules asked again at the confirm (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

/// <p>What the caller must hold: the list's own pairs, then <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>
/// and the custom resource of the <parameter>CLASSICPAGES</parameter> editor, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
