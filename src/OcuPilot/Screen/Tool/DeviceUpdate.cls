/// <p>The devices list's edit tool (AD-4, AD-6, AD-10, AD-55): propose a change to one device's
/// settings. It reads the device fresh through the vendor's own <code>Device.Standard</code>
/// <code>GET</code>, merges the arguments over that object, and mints a proposal the user confirms.
/// It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read's eight fields with the changed ones applied,
/// so a field the arguments omit keeps the instance's value (AD-4) even though the vendor merges too.
/// The fingerprint covers every field the body sends. The name is the device's id and never
/// changes.</p>
/// <p><b>The rules check only the fields the arguments change</b>, against the fresh read, so a
/// stored value outside them does not block an unrelated edit.</p>
Class OcuPilot.Screen.Tool.DeviceUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.devices.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DeviceList";

Parameter DESCRIPTION = "Propose a change to one device on this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the device exactly as the devices list reports it, case included, and send only the fields to change. Its name cannot be changed.";

/// <p>The fresh read and the write: the vendor's single-object read, and its <code>PUT</code>. The
/// <code>PUT</code> would re-create a device deleted since the read, so the confirm's fingerprint
/// re-read is what refuses that (AD-4, AD-6).</p>
Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names the same eight).
/// A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "PhysicalDevice,Type,SubType,OpenParameters,Description,Alias,AlternateDevice,Prompt";

/// <p>The pair the write needs beyond the devices list's own
/// (<parameter>OcuPilot.Screen.Tool.DeviceCreate.WRITERESOURCE</parameter>).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

ClassMethod Endpoint() As %String
{
    Quit "Device.Standard"
}

/// <p>The field names the merge may set: the <code>ordinary</code> top-level fields this tool
/// admits, derived rather than transcribed (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with the name and the eight fields described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ##class(OcuPilot.Screen.Tool.DeviceCreate).Described(tSchema, 0)
}

/// <p>The device editor's own rules over the fields the agent's arguments change, read against this
/// tool's own fresh read of <var>pIdValue</var> (AD-55). A device the read no longer finds has every
/// supplied field checked; the mint has already refused one that was absent when it read.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) && (+$Get(tHttp) '= 404) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") Set tFresh = ""
    Quit ##class(OcuPilot.Screen.Tool.DeviceCreate).RuleProblem(pIdValue, ##class(OcuPilot.Area.OsMgmt.DeviceRules).Changed(pArgs, tFresh), "update", tFresh, .pProblem)
}

/// <p>Shape the body as the vendor's own read answers a device
/// (<method>OcuPilot.Screen.Tool.DeviceCreate.DerivedFields</method>).</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do ##class(OcuPilot.Area.OsMgmt.DeviceRules).Shape(pPayload)
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
