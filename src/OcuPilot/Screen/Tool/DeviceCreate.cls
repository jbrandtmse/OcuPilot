/// <p>The devices list's create tool (AD-54, AD-55): propose a new device on this instance. It reads
/// the intended name fresh through the vendor's own <code>Device.Standard</code> <code>GET</code>,
/// requires that read to answer <b>nothing</b>, composes the payload from its arguments and mints a
/// proposal the user confirms. It writes nothing.</p>
/// <p><b>It admits the classic device page's eight fields</b> (<parameter>PERMITTEDFIELDS</parameter>),
/// the ones <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> has reviewed
/// for a device create, and requires the three the vendor's create requires. The device editor's own
/// rules (<method>OcuPilot.Area.OsMgmt.DeviceRules.Validate</method>) refuse the arguments at the
/// mint, so the agent cannot propose what the screen would refuse.</p>
/// <p>The name travels only as the vendor's <code>name</code> query parameter. The vendor's
/// <code>PUT</code> is an upsert, so the absence fingerprint is what stops a confirmed create
/// rewriting a device somebody else created since the mint (AD-54).</p>
Class OcuPilot.Screen.Tool.DeviceCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.devices.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DeviceList";

Parameter DESCRIPTION = "Propose a new device on this instance. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the device, and give at least its physical device name, its type and its subtype.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

/// <p>The vendor request type a create is issued with: <code>Device.Standard</code>'s
/// <code>PUT</code>, the endpoint's only write that takes a body. <code>POST</code> answers 405.</p>
Parameter WRITETYPE = "PUT";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same eight).
/// A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "PhysicalDevice,Type,SubType,OpenParameters,Description,Alias,AlternateDevice,Prompt";

/// <p>The fields the vendor's create refuses a body without.</p>
Parameter REQUIREDFIELDS = "PhysicalDevice,Type,SubType";

/// <p>The pair the write needs beyond the devices list's own: <code>%DB_IRISSYS:WRITE</code>.
/// <code>Config.Devices</code> saves a device into the system database, and a real principal holding
/// the list's <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code> alone is refused
/// there with <code>&lt;PROTECT&gt;</code> (measured on slot B's throwaway, AD-29). The endpoint's
/// own <code>%Admin_Manage</code> is the list's first pair.</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

ClassMethod Endpoint() As %String
{
    Quit "Device.Standard"
}

/// <p>The field names the composed payload may set: the <code>ordinary</code> top-level fields this
/// tool admits, derived rather than transcribed (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a field the prohibited set has not reviewed for a
/// create is absent from the schema and from <method>SettableFields</method>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with every field described and <parameter>REQUIREDFIELDS</parameter>
/// required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Set tSchema = ..Described(tSchema, 1)
    If $IsObject(tSchema) && (tSchema.%GetTypeOf("required") = "array") && (tSchema.%GetTypeOf("properties") = "object") {
        For tI = 1:1:$Length(..#REQUIREDFIELDS, ",") {
            Set tField = $Piece(..#REQUIREDFIELDS, ",", tI)
            If tSchema.%Get("properties").%GetTypeOf(tField) = "object" Do tSchema.%Get("required").%Push(tField)
        }
    }
    Quit tSchema
}

/// <p><var>pSchema</var> with the name and the eight fields described, for a create when
/// <var>pCreates</var> is 1 and for an edit otherwise. <code>Type</code> carries its six values as an
/// <code>enum</code>.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) Quit pSchema
    If pSchema.%GetTypeOf("properties") '= "object" Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Set tDescriptions("PhysicalDevice") = "The physical device name the device opens, at most 128 characters, with no ^ and no control character."
    Set tDescriptions("Type") = "The device's type: TRM (terminal), SPL (spooling device), MT (magnetic tape drive), BT (cartridge tape drive), IPC (interprocess communication) or OTH (any other device, printers and sequential files included)."
    Set tDescriptions("SubType") = "The device's subtype, exactly as this instance names one, such as P-DEC or C-IRIS Terminal."
    Set tDescriptions("OpenParameters") = "The parameters an OPEN of this device passes, written as the OPEN command takes them, at most 128 characters. An empty string clears them."
    Set tDescriptions("Description") = "What the device is, at most 256 characters, with no ^ and no control character."
    Set tDescriptions("Alias") = "A whole number of at least 1 that no other device uses and that differs from the physical device name, written as a string such as ""210"", or an empty string for none."
    Set tDescriptions("AlternateDevice") = "Another device's name that %IS offers as the alternate, at most 128 characters, or an empty string for none."
    Set tDescriptions("Prompt") = "The prompt option: an empty string shows the device prompt, ""1"" uses this device automatically when it is the current device, and ""2"" does so with its predefined settings."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    If tProperties.%GetTypeOf("Type") = "object" {
        Set tValues = []
        Set tList = $Parameter("OcuPilot.Area.OsMgmt.DeviceRules", "TYPEVALUES")
        For tI = 1:1:$Length(tList, ",") Do tValues.%Push($Piece(tList, ",", tI))
        Do tProperties.%Get("Type").%Set("enum", tValues)
    }
    If tProperties.%GetTypeOf("Name") = "object" {
        If pCreates {
            Do tProperties.%Get("Name").%Set("description", "The name the new device will take, compared exactly, case included: at most 64 characters, with no ^, no = and no control character. A name this instance already holds is refused, so check the devices list first.", "string")
        } Else {
            Do tProperties.%Get("Name").%Set("description", "The device to change, exactly as this instance's own devices list reports its name, case included.", "string")
        }
    }
    Quit pSchema
}

/// <p>The device editor's own rules (<method>OcuPilot.Area.OsMgmt.DeviceRules.Validate</method>) over
/// the agent's arguments, create mode, each broken rule as its field and published sentence (AD-55).
/// The name look-up is skipped: the mint's absence read has answered it.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..RuleProblem(pIdValue, pArgs, "create", "", .pProblem)
}

/// <p><method>OcuPilot.Area.OsMgmt.DeviceRules.Validate</method> over <var>pArgs</var> for
/// <var>pIdValue</var> in mode <var>pMode</var>, against the fresh read <var>pFresh</var> where an
/// edit has one, the look-up never, as one <var>pProblem</var> naming each field and its published
/// sentence.</p>
ClassMethod RuleProblem(pIdValue As %String, pArgs As %DynamicObject, pMode As %String, pFresh As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.OsMgmt.DeviceRules).Validate(pIdValue, pArgs, .tViolations, pMode, 0, pFresh)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tField = $List(tViolations(tI), 1)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ tField _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>Shape <var>pPayload</var> as the vendor's own read answers a device, just before the port is
/// invoked: <code>Alias</code> and <code>Prompt</code> as integers, or <code>""</code> when empty,
/// and every other field as a string. The values are the ones the user reviewed; only their JSON type
/// is set, so the screen's Save and the agent's confirm send one body.</p>
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
