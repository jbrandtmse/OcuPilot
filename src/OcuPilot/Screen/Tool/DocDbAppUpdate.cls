/// <p>The Doc DB applications' edit tool (AD-4, AD-6, AD-55, Story 18.30): propose a change to one record's description,
/// enabled flag or resource. It reads the record fresh through the vendor's own <code>DocDB</code> <code>GET</code>,
/// merges the arguments over that object and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read's complete set of three settings with the changed ones applied
/// (AD-4). The namespace and the name are the id and never change. The vendor's <code>PUT</code> is an upsert that
/// keeps a key its body omits, so the confirm's fingerprint re-read is what refuses a record deleted since the mint.</p>
/// <p><b>Every rule is decided before the write</b> (<class>OcuPilot.Area.WebApp.DocDbAppRules</class>), on both
/// callers, and judges only the settings the change moves.</p>
Class OcuPilot.Screen.Tool.DocDbAppUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "webapp.docdbapps.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DocDbAppList";

Parameter DESCRIPTION = "Propose a change to one Doc DB application record. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the namespace and the record exactly as the Doc DB applications list reports them and send only the settings to change: the description, whether it is enabled, or the service or application resource that controls it. The record's namespace and name cannot be changed.";

Parameter PORTCLASS = "OcuPilot.Port.DocDbAppPort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The three settings this tool admits
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names the same).</p>
Parameter PERMITTEDFIELDS = "Description,Enabled,Resource";

/// <p>The pair this tool requires beyond the list's own: none (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

/// <p>The classic editor whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Applications.DocDB";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.WebApp.DocDbAppRules";

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

/// <p>The derived schema with the namespace, the name and the settings described
/// (<method>OcuPilot.Screen.Tool.DocDbAppCreate.Described</method>).</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.DocDbAppCreate).Described(##super(pDescriptor), 0)
}

/// <p>The rules over the arguments, then the kernel's merge over the fresh read, then every rule over the payload it
/// would send, against the fresh read, whose first refusal is <var>pProblem</var>: so the mint, the confirm's
/// fingerprint re-merge and the Save take one payload and one refusal, before the port is written to.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ""
    Set pDiff = []
    Set pUnchanged = 0
    Set tSC = $ClassMethod(..#RULES, "Problem", "", "", pArgs, "", "update", ..PortClass(), .pProblem, 0)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tSC = ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tSC = $ClassMethod(..#RULES, "Problem", "", "", pPayload, pFresh, "update", ..PortClass(), .pProblem, 1)
    If $$$ISERR(tSC) || (pProblem '= "") {
        Set pPayload = ""
        Set pDiff = []
        Set pUnchanged = 0
    }
    Quit tSC
}

/// <p>The rules that need no read, over the agent's arguments, so a refusal costs no port call (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit $ClassMethod(..#RULES, "Problem", "", "", pArgs, "", "update", ..PortClass(), .pProblem, 0)
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
