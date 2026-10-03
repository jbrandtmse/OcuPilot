/// <p>License servers' create tool (AD-54, AD-55, Story 18.6): propose a new license server. It reads
/// the intended name fresh through the vendor's own <code>License.Server</code> <code>GET</code>,
/// which resolves any case, requires that read to answer <b>nothing</b>, composes
/// <code>{Address, Port}</code> from its arguments and mints a proposal the user confirms. It writes
/// nothing.</p>
/// <p>The vendor's <code>PUT</code> is an upsert that stores the name upper-cased, so the absence
/// fingerprint under AD-13's <code>foldcase</code> spelling is what stops a confirmed create rewriting
/// a server somebody else created since the mint (AD-54). <code>KeyDirectory</code> is shown and never
/// set (AD-21). The rules of <method>OcuPilot.Area.OsMgmt.LicenseRules.Validate</method> refuse the
/// arguments at the mint, the same rules the screen's Save applies.</p>
Class OcuPilot.Screen.Tool.LicenseServerCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.licenseservers.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LicenseServerList";

Parameter DESCRIPTION = "Propose a new license server on this instance. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the server, and give its host name or IP address and its port.";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

/// <p>The vendor's only write that takes a body.</p>
Parameter WRITETYPE = "PUT";

/// <p>The derived top-level fields this tool admits
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same two).</p>
Parameter PERMITTEDFIELDS = "Address,Port";

/// <p>The fields the vendor's create refuses a body without.</p>
Parameter REQUIREDFIELDS = "Address,Port";

/// <p>The pair the write needs beyond the list's own: <code>Config.LicenseServers</code> saves into
/// the system database, and a principal holding only the list's <code>%Admin_Manage:USE</code> and
/// <code>%DB_IRISSYS:READ</code> was refused <code>&lt;PROTECT&gt;</code> there (AD-8, measured at
/// Story 18.6's Task 0).</p>
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

/// <p>The derived schema with every field described and <parameter>REQUIREDFIELDS</parameter>
/// required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ..Described(##super(pDescriptor), 1)
    If $IsObject(tSchema) && (tSchema.%GetTypeOf("required") = "array") && (tSchema.%GetTypeOf("properties") = "object") {
        For tI = 1:1:$Length(..#REQUIREDFIELDS, ",") {
            Set tField = $Piece(..#REQUIREDFIELDS, ",", tI)
            If tSchema.%Get("properties").%GetTypeOf(tField) = "object" Do tSchema.%Get("required").%Push(tField)
        }
    }
    Quit tSchema
}

/// <p><var>pSchema</var> with the name, the address and the port described, for a create when
/// <var>pCreates</var> is 1 and for an edit otherwise.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Set tDescriptions("Address") = "The license server's host name or IP address, at most 256 characters."
    Set tDescriptions("Port") = "The port the license server answers on, a whole number from 1 to 65535."
    If pCreates {
        Set tDescriptions("Name") = "The name the new license server will take: a letter or digit, then up to 63 letters, digits, hyphens and underscores. The instance stores it upper case, and a name it already holds in any case is refused."
    } Else {
        Set tDescriptions("Name") = "The license server to change, as this instance's license servers list reports it."
    }
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    Quit pSchema
}

/// <p>The create rules of <method>OcuPilot.Area.OsMgmt.LicenseRules.Problem</method> over the agent's
/// arguments (AD-55); the look-up is skipped, the mint's absence read having answered it.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Area.OsMgmt.LicenseRules).Problem(pIdValue, pArgs, "create", .pProblem)
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
