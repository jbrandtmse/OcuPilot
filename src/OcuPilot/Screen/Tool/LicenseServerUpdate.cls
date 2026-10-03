/// <p>License servers' edit tool (AD-4, AD-6, AD-55, Story 18.6): propose a change to one license
/// server's address or port. It reads the server fresh through the vendor's own
/// <code>License.Server</code> <code>GET</code>, merges the arguments over it, and mints a proposal the
/// user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the complete <code>{Address, Port}</code> read fresh with the
/// changed field applied. <code>KeyDirectory</code> is shown and never set (AD-21): the vendor's
/// <code>PUT</code> keeps a key its body omits (measured at Story 18.6's Task 0), so the body never
/// carries it. The name is the server's id and never changes; the classic page's rename, a delete
/// then a create, is not offered.</p>
Class OcuPilot.Screen.Tool.LicenseServerUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.licenseservers.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LicenseServerList";

Parameter DESCRIPTION = "Propose a change to one license server on this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the server as the license servers list reports it and send only what changes: its host name or IP address, or its port. Its name cannot be changed.";

Parameter READTYPE = "GET";

/// <p>An upsert, so the confirm's fingerprint re-read is what refuses a server deleted since the read
/// (AD-4, AD-6).</p>
Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The derived top-level fields this tool admits
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names the same two).</p>
Parameter PERMITTEDFIELDS = "Address,Port";

/// <p>The read's names the body never sends.</p>
Parameter READONLYNAMES = "KeyDirectory";

/// <p>The pair the write needs beyond the list's own
/// (<parameter>OcuPilot.Screen.Tool.LicenseServerCreate.WRITERESOURCE</parameter>).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

ClassMethod Endpoint() As %String
{
    Quit "License.Server"
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

/// <p>The derived schema with the name, the address and the port described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.LicenseServerCreate).Described(##super(pDescriptor), 0)
}

/// <p>The kernel's merge over the fresh read less <parameter>READONLYNAMES</parameter>, so the body
/// and the card's unchanged rows are exactly <code>{Address, Port}</code>.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Quit ##super(..Sendable(pFresh), pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p><var>pFresh</var> without <parameter>READONLYNAMES</parameter>, as a copy.</p>
ClassMethod Sendable(pFresh As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pFresh) || 'pFresh.%IsA("%Library.DynamicObject") Quit pFresh
    Set tCopy = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
    Set tNames = $ListFromString(..#READONLYNAMES)
    For tI = 1:1:$ListLength(tNames) Do tCopy.%Remove($List(tNames, tI))
    Quit tCopy
}

/// <p>The update rules of <method>OcuPilot.Area.OsMgmt.LicenseRules.Problem</method> over the agent's
/// arguments (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Area.OsMgmt.LicenseRules).Problem(pIdValue, pArgs, "update", .pProblem)
}

/// <p>The port as a number, as the vendor's own read answers it.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do ##class(OcuPilot.Area.OsMgmt.LicenseRules).Shape(pPayload)
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
