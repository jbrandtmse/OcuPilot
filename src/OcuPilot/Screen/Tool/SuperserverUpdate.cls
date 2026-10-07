/// <p>The superservers' edit tool (AD-4, AD-6, AD-10, AD-55, Story 18.25): propose a change to one
/// superserver's settings. It reads the superserver fresh through the vendor's own
/// <code>Security.Superserver</code> <code>GET</code>, merges the arguments over that object and mints a proposal
/// the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read's complete set <b>less <code>SystemDefault</code></b>
/// with the changed settings applied (AD-4); <code>SystemDefault</code> is shown and never set, and no body
/// carries it. The port and bind address are the id and never change. The vendor's <code>PUT</code> is an
/// upsert, so the confirm's fingerprint re-read is what refuses a superserver deleted since the mint.</p>
/// <p><b>Every rule is decided before the write</b> (<class>OcuPilot.Area.Security.SuperserverRules</class>), on
/// both callers. On the superserver the web gateway connects through, turning off <code>Enabled</code> or
/// <code>EnableCSP</code> and requiring SSL/TLS are refused by the prohibited set; any other SSL/TLS change is
/// permitted and carries <parameter>OcuPilot.Kernel.Proposal.Prohibited.EFFECTSERVINGSUPERSERVER</parameter>.</p>
Class OcuPilot.Screen.Tool.SuperserverUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.superservers.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SuperserverList";

Parameter DESCRIPTION = "Propose a change to one superserver of this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the superserver by its port and bind address as the Superservers list reports them, and send only the settings to change. Its port and address cannot be changed. On the superserver the web gateway connects through, turning off Enabled or the web connections and requiring SSL/TLS are refused, and any other SSL/TLS change is a destructive proposal.";

Parameter PORTCLASS = "OcuPilot.Port.SuperserverPort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The fifteen settings this tool admits
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names the same).</p>
Parameter PERMITTEDFIELDS = "Description,EnableCacheDirect,EnableClients,EnableCSP,EnableDataCheck,EnableECP,EnableMirror,EnableNodeJS,EnableShadows,EnableSharding,EnableSNMP,EnableWebLink,Enabled,SSLConfig,SSLSupportLevel";

/// <p>The members of the fresh read the body never carries: <code>SystemDefault</code>, and the two the id
/// supplies.</p>
Parameter UNSENTFIELDS = "SystemDefault,Port,BindAddress";

/// <p>The pair this tool requires beyond Superservers' own: none, and the declaration keeps the idiom of every
/// tool of the area (AD-8). Security's set is what the write needs, measured at Story 18.25's plan.</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

/// <p>The classic editor whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Server";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.Security.SuperserverRules";

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

/// <p><class>OcuPilot.Screen.Tool.SuperserverMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.SuperserverMint"
}

/// <p>The derived schema with the port, the bind address and the settings described
/// (<method>OcuPilot.Screen.Tool.SuperserverCreate.Described</method>).</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.SuperserverCreate).Described(##super(pDescriptor), 0)
}

/// <p>The kernel's merge over the fresh read without <parameter>UNSENTFIELDS</parameter>, so the payload, the
/// diff and the body agree for the mint, the confirm and the Save and none carries <code>SystemDefault</code>.</p>
ClassMethod MergeRaw(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tFresh = pFresh
    If $IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject") {
        Set tFresh = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
        For tI = 1:1:$Length(..#UNSENTFIELDS, ",") {
            Set tName = $Piece(..#UNSENTFIELDS, ",", tI)
            If tFresh.%GetTypeOf(tName) '= "unassigned" Do tFresh.%Remove(tName)
        }
    }
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Merge(tFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p><method>MergeRaw</method>, then every rule over the payload it would send, against the fresh read, whose
/// first refusal is <var>pProblem</var>: so the mint, the confirm's fingerprint re-merge and the Save take one
/// payload and one refusal, before the port is written to.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ..MergeRaw(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tSC = $ClassMethod(..#RULES, "Problem", "", pPayload, pFresh, "update", ..PortClass(), .pProblem, 1)
    If $$$ISERR(tSC) || (pProblem '= "") {
        Set pPayload = ""
        Set pDiff = []
        Set pUnchanged = 0
    }
    Quit tSC
}

/// <p>The rules that need no fresh read, over the agent's arguments, so a refusal costs no port call
/// (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit $ClassMethod(..#RULES, "Problem", "", pArgs, "", "update", ..PortClass(), .pProblem, 0)
}

/// <p>The same rules asked again at the confirm (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

/// <p>The effect the prohibited set names for this payload, which is the proposal's consequence code.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit pEffect
}

/// <p>What the caller must hold: Superservers' own pairs, then <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>
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
