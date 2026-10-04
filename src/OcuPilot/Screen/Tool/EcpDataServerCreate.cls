/// <p>ECP data servers' create tool (AD-54, AD-55, Story 18.20): propose a new data server. It reads the
/// intended name fresh through the vendor's own <code>ECP.DataServer</code> <code>GET</code>, which
/// resolves any case, requires that read to answer <b>nothing</b>, composes
/// <code>{Address, Port, MirrorConnection, SSLConfig, BatchMode}</code> from its arguments, the last
/// three defaulting to 0, 0 and false, and mints a proposal the user confirms. It writes nothing.</p>
/// <p>The vendor's <code>PUT</code> is an upsert that stores the name upper-cased, so the absence
/// fingerprint under AD-13's <code>foldcase</code> spelling is what stops a confirmed create rewriting a
/// server somebody else created since the mint (AD-54). The rules of
/// <method>OcuPilot.Area.OsMgmt.EcpRules.Validate</method> refuse the arguments at the mint, the same
/// rules the screen's Save applies; <class>OcuPilot.Port.EcpPort</class> refuses a create past the
/// instance's data server limit at the write. A configuration write contacts no data server beyond the
/// vendor's own activation (inference).</p>
Class OcuPilot.Screen.Tool.EcpDataServerCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.ecpdataservers.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EcpDataServerList";

Parameter DESCRIPTION = "Propose a new ECP data server this instance connects to as an application server. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the server, and give its host name or IP address and its port; mirror connection, SSL/TLS and batch mode default to off. The instance allows only as many data servers as its ECP settings' limit.";

/// <p>The port that refuses a create past the limit and answers the vendor's SSL/TLS refusal on its
/// field (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.EcpPort";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

/// <p>The vendor's only write that takes a body.</p>
Parameter WRITETYPE = "PUT";

/// <p>The derived top-level fields this tool admits
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same five).</p>
Parameter PERMITTEDFIELDS = "Address,Port,MirrorConnection,SSLConfig,BatchMode";

/// <p>The fields the vendor's create refuses a body without.</p>
Parameter REQUIREDFIELDS = "Address,Port";

/// <p>The value each optional field takes when the arguments omit it, as
/// <code>field:value:type</code> entries: the classic dialog's defaults.</p>
Parameter DEFAULTS = "MirrorConnection:0:number,SSLConfig:0:number,BatchMode:0:boolean";

/// <p>The pair the write needs beyond the list's own: <code>Config.ECPServers</code> saves into the
/// system database, and a principal holding only the list's <code>%Admin_Manage:USE</code> and
/// <code>%DB_IRISSYS:READ</code> was refused <code>&lt;PROTECT&gt;</code> there (AD-8, measured at
/// Story 18.20's Task 0).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The classic dialog whose operation this tool performs beyond the list's own (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.ECPDataServer";

ClassMethod Endpoint() As %String
{
    Quit "ECP.DataServer"
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

/// <p><var>pSchema</var> with each field described, for a create when <var>pCreates</var> is 1 and for
/// an edit otherwise.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Set tDescriptions("Address") = "The data server's host name or IP address, at most 255 characters."
    Set tDescriptions("Port") = "The data server's superserver port, a whole number from 1 to 65535."
    Set tDescriptions("SSLConfig") = "1 to connect with SSL/TLS through the %ECPClient SSL/TLS configuration, which must exist and be enabled; 0 for none."
    Set tDescriptions("BatchMode") = "Whether the connection runs in batch mode."
    If pCreates {
        Set tDescriptions("Name") = "The name the new data server will take: a letter or digit, then up to 63 letters, digits, hyphens and underscores. The instance stores it upper case, and a name it already holds in any case is refused."
        Set tDescriptions("MirrorConnection") = "1 when the data server is a mirror, connecting to its primary; 0 for an ordinary data server. Once set it cannot be turned off here."
    } Else {
        Set tDescriptions("Name") = "The data server to change, as this instance's ECP data servers list reports it."
        Set tDescriptions("MirrorConnection") = "0 or 1. A data server whose mirror connection is already set keeps it, and a change to it is refused."
    }
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    Quit pSchema
}

/// <p>The kernel's composition of the supplied fields, then each <parameter>DEFAULTS</parameter> field
/// the arguments omit, at its default and counted unchanged, so the body is the complete set (AD-54's
/// complete-body exception).</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    For tI = 1:1:$Length(..#DEFAULTS, ",") {
        Set tEntry = $Piece(..#DEFAULTS, ",", tI)
        Set tField = $Piece(tEntry, ":", 1)
        If '$ListFind(pSettable, tField) || (pPayload.%GetTypeOf(tField) '= "unassigned") Continue
        Do pPayload.%Set(tField, +$Piece(tEntry, ":", 2), $Piece(tEntry, ":", 3))
        Set pUnchanged = pUnchanged + 1
    }
    Quit tSC
}

/// <p>The create rules of <method>OcuPilot.Area.OsMgmt.EcpRules.Problem</method> over the agent's
/// arguments (AD-55); the look-up is skipped, the mint's absence read having answered it.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Area.OsMgmt.EcpRules).Problem(pIdValue, pArgs, "create", .pProblem)
}

/// <p>The port as a number, as the vendor's own read answers it.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do ##class(OcuPilot.Area.OsMgmt.EcpRules).Shape(pPayload)
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, then the custom
/// resource of the <parameter>CLASSICPAGES</parameter> dialog, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
