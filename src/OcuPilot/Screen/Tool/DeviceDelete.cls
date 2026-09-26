/// <p>The devices list's delete tool (AD-6, AD-51): propose removing one device. It reads the device
/// fresh through the vendor's own <code>Device.Standard</code> <code>GET</code> and mints a proposal
/// whose card lists what would go. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>NeedsRequestBody()</code> is
/// <code>..IsTypePut()</code>, so <code>DELETE</code> reads no body, the tool admits no settable
/// field, and its field list is empty by derivation (AD-3).</p>
/// <p><b>Its fingerprint covers all eight fields the read answers</b>: configuration does not move by
/// itself, so any change since the mint is somebody's edit and refuses the confirm. The physical
/// device name is the precondition. The identity is outside the subject (AD-13, AD-51).</p>
/// <p>A device the instance does not hold is refused at the mint, and the vendor's answer to the
/// delete is re-read before it is believed (<parameter>OcuPilot.Port.AdminPort.VERIFIEDDELETES</parameter>).
/// Deleting a stock device is permitted, as on the classic page, behind the destructive
/// treatment.</p>
Class OcuPilot.Screen.Tool.DeviceDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.devices.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DeviceList";

Parameter DESCRIPTION = "Propose deleting one device from this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the device exactly as the devices list reports it, case included. A device this instance does not hold is refused.";

Parameter READTYPE = "GET";

/// <p>The vendor's own delete request type, which answers 404 for an absent device.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted device is gone from the instance's configuration, and OcuPilot keeps no
/// copy to restore it from.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The top-level names <parameter>READTYPE</parameter> answers, read off the vendor's
/// <code>ObjToJson</code> on this build.</p>
Parameter READANSWERS = "PhysicalDevice,Type,SubType,OpenParameters,Description,Alias,AlternateDevice,Prompt";

Parameter PRECONDITIONFIELD = "PhysicalDevice";

Parameter FINGERPRINTSUBJECT = "PhysicalDevice,Type,SubType,OpenParameters,Description,Alias,AlternateDevice,Prompt";

/// <p>The rows the card lists, in the classic page's order: the device as the fresh read describes
/// it.</p>
Parameter REMOVALROWS = "PhysicalDevice,Type,SubType,OpenParameters,Description,Alias,AlternateDevice,Prompt";

/// <p>The pair the write needs beyond the devices list's own
/// (<parameter>OcuPilot.Screen.Tool.DeviceCreate.WRITERESOURCE</parameter>).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

ClassMethod Endpoint() As %String
{
    Quit "Device.Standard"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The device to delete, exactly as this instance's own devices list reports its name, case included.", "string")
    Quit tSchema
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

/// <p>The removal rows this proposal's card shows, from the fresh <code>GET</code>
/// <var>pFresh</var>: one per <parameter>REMOVALROWS</parameter> name, carrying the value the
/// instance holds and no after-state. A read that answered no <parameter>PRECONDITIONFIELD</parameter>
/// is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report that device's physical device name, and a device whose settings are unknown is not one to delete"
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
