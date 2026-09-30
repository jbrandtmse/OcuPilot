/// <p>External language servers' create tool (AD-54, AD-55, Story 16.25): propose a new external
/// language server. Two callers reach it: the editor's create Save through
/// <class>OcuPilot.Area.OsMgmt.LanguageServerSave</class>, and the agent's proposal and confirmation.
/// It reads the intended name fresh through <class>OcuPilot.Port.LanguageServerPort</class>'s
/// <code>GET</code>, requires that read to answer <b>nothing</b>, composes the payload from its
/// arguments and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>Its arguments are the type, the port, the settings every type shares and
/// <code>Custom</code></b>, one object argument holding only the members the chosen type takes
/// (<method>OcuPilot.Area.OsMgmt.LanguageServerRules.Members</method>). The file locations are never
/// arguments (AD-21). A create that names no resource sends the classic editor's default for its
/// type (<method>ComposeCreate</method>), which the card shows as a row.</p>
/// <p>The vendor's <code>PUT</code> is an upsert, so the absence fingerprint is what stops a confirmed
/// create rewriting a server somebody else created since the mint (AD-54). The name travels only as
/// the vendor's <code>name</code> query parameter.</p>
Class OcuPilot.Screen.Tool.LanguageServerCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.languageservers.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LanguageServerList";

Parameter DESCRIPTION = "Propose a new external language server on this instance: a Java, .NET, Python or other gateway. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name it, choose its type and give its port; the type's own settings go in Custom, only the ones the type takes. File locations such as the log file, class path, Java home, file path and Python executable are set on the classic portal and are never arguments. A server with no resource named takes its type's default.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

/// <p>The vendor request type a create is issued with: <code>LanguageServer</code>'s
/// <code>PUT</code>, an upsert answering 201.</p>
Parameter WRITETYPE = "PUT";

/// <p>The port that completes the read with the running state and gates a Python delete
/// (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.LanguageServerPort";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names these and
/// <parameter>CUSTOMFIELD</parameter>).</p>
Parameter PERMITTEDFIELDS = "Type,Port,BindToIPAddress,ConnectionTimeout,InitializationTimeout,Resource,UseSharedMemory,SSLConfigurationServer,SSLConfigurationClient,VerifySSLHostName";

/// <p>The object argument the tool adds back beside the derived literals, classified
/// <code>opaque</code>: the type's own settings.</p>
Parameter CUSTOMFIELD = "Custom";

/// <p>The fields the vendor's create refuses a body without, beside the name.</p>
Parameter REQUIREDFIELDS = "Type,Port";

/// <p>The pairs every language server write needs beyond the list's own:
/// <code>%Admin_Manage:USE</code>, without which the vendor answered #921, and
/// <code>%DB_IRISSYS:WRITE</code>, without which it raised <code>&lt;PROTECT&gt;</code> in
/// <code>Config.Gateways</code> (AD-8, measured on <code>ocupilot-ci</code>).</p>
Parameter MANAGERESOURCE = "%Admin_Manage";

Parameter MANAGEPERMISSION = "USE";

Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The classic page whose operation this tool performs beyond the list's own (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.ExternalLanguageServer";

/// <p>The whole-number fields a create composes as numbers, as the instance answers them.</p>
Parameter NUMBERFIELDS = "Port,ConnectionTimeout,InitializationTimeout";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.OsMgmt.LanguageServerRules";

ClassMethod Endpoint() As %String
{
    Quit "LanguageServer"
}

/// <p>The server's name, which the list's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

/// <p>The query parameter <code>LanguageServer</code> identifies a server by.</p>
ClassMethod IdParam() As %String
{
    Quit "name"
}

/// <p>The derived <code>ordinary</code> fields this tool admits, and <parameter>CUSTOMFIELD</parameter>.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#CUSTOMFIELD)
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema, described, with <parameter>CUSTOMFIELD</parameter> added and
/// <parameter>REQUIREDFIELDS</parameter> required.</p>
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

/// <p><var>pSchema</var> with the name, the fields and <parameter>CUSTOMFIELD</parameter> described,
/// for a create when <var>pCreates</var> is 1 and for an edit otherwise.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) Quit pSchema
    If pSchema.%GetTypeOf("properties") '= "object" Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Set tRules = ..#RULES
    Set tDescriptions("Type") = "The server's type, spelled exactly: one of " _ $ListToString($ListFromString($Parameter(tRules, "TYPES")), ", ") _ ". It cannot be changed afterwards."
    Set tDescriptions("Port") = "The TCP port the server listens on: a whole number from 1 to 65535."
    Set tDescriptions("ConnectionTimeout") = "Seconds to wait for a connection to the server: a whole number from 2 to 300."
    Set tDescriptions("InitializationTimeout") = "Seconds to wait for the server to start: a whole number from 2 to 300."
    Set tDescriptions("BindToIPAddress") = "The address the server binds to."
    Set tDescriptions("Resource") = "The resource that guards the server, at most 64 characters. On a create, omit it to take the type's default."
    Set tDescriptions("UseSharedMemory") = "Whether the server uses shared memory where it can."
    Set tDescriptions("SSLConfigurationServer") = "The SSL/TLS configuration the server uses, at most 64 characters."
    Set tDescriptions("SSLConfigurationClient") = "The SSL/TLS configuration clients use, at most 64 characters."
    Set tDescriptions("VerifySSLHostName") = "Whether a client verifies the server's host name."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    Do tProperties.%Set(..#CUSTOMFIELD, {"type": "object", "description": "The type's own settings, only the ones to set: JVMArgs for Java, XSLT, JDBC, ML and R; DotNetVersion (N8.0, N9.0 or N10.0) and Exec32 (true or false) for .NET; PythonOptions for Python; Address for Remote; none for ODBC. Each is text but Exec32. File locations are never among them."})
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        If pCreates {
            Do tProperties.%Get(..IdArgument()).%Set("description", "The name the new server will take: 1 to 50 characters, compared with their case. A name this instance already holds is refused, so check the external language servers list first.", "string")
        } Else {
            Do tProperties.%Get(..IdArgument()).%Set("description", "The server, named exactly as this instance's own external language servers list reports it, case included. A server the list does not report is refused.", "string")
        }
    }
    Quit pSchema
}

/// <p>The editor's own rules over the agent's arguments, create mode, each broken rule as its field
/// and published sentence (AD-55). The name look-up is skipped: the mint's absence read has answered
/// it.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $ClassMethod(..#RULES, "Validate", pIdValue, pArgs, .tViolations, "create", 0)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = $ClassMethod(..#RULES, "Problem", .tViolations)
    Quit $$$OK
}

/// <p>The composed payload and diff of a create (AD-54): one payload property per supplied settable
/// field, a whole number composed as a number and <parameter>CUSTOMFIELD</parameter> with only its
/// supplied members, one diff row per field and one <code>Custom.&lt;member&gt;</code> row per member,
/// and the type's default resource added with its own row when the arguments name none. A
/// <code>Custom</code> member the type does not take, or one that is a file location, is
/// <var>pProblem</var>.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ""
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tPayload = {}
        Set tType = ""
        If pArgs.%GetTypeOf("Type") = "string" Set tType = pArgs.%Get("Type")
        For tI = 1:1:$ListLength(pSettable) {
            Set tField = $List(pSettable, tI)
            If (tField = pIdArgument) || (tField = ..#CUSTOMFIELD) Continue
            Set tKind = pArgs.%GetTypeOf(tField)
            If tKind = "unassigned" Continue
            If (tKind = "object") || (tKind = "array") {
                Set pProblem = "'" _ tField _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Quit
            }
            Set tValue = pArgs.%Get(tField)
            If $ListFind($ListFromString(..#NUMBERFIELDS), tField) && $IsValidNum(tValue) {
                Do tPayload.%Set(tField, +tValue, "number")
            } Else {
                Do tPayload.%Set(tField, tValue, tKind)
            }
            Do pDiff.%Push(..Row(tField, "", ##class(OcuPilot.Kernel.Proposal.Mint).Display(tValue, tKind)))
        }
        If pProblem '= "" Quit
        ; A type the rules refuse leaves Custom uncomposed, so the refusal the mint answers names the
        ; type (ArgumentProblem) rather than the members it would have judged.
        If $ListFind(pSettable, ..#CUSTOMFIELD) && (pArgs.%GetTypeOf(..#CUSTOMFIELD) '= "unassigned") && $ClassMethod(..#RULES, "IsType", tType) {
            Set tCustom = ..ComposedCustom(tType, pArgs.%Get(..#CUSTOMFIELD), pDiff, .pProblem)
            If pProblem '= "" Quit
            If $IsObject(tCustom) Do tPayload.%Set(..#CUSTOMFIELD, tCustom)
        }
        If (tPayload.%GetTypeOf("Resource") = "unassigned") && $ClassMethod(..#RULES, "IsType", tType) {
            Set tDefault = $ClassMethod(..#RULES, "ResourceDefault", tType)
            Do tPayload.%Set("Resource", tDefault, "string")
            Do pDiff.%Push(..Row("Resource", "", tDefault))
        }
        Set pPayload = tPayload
    } Catch ex {
        Set pPayload = ""
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) || (pProblem '= "") {
        Set pPayload = ""
        Set pDiff = []
    }
    Quit tSC
}

/// <p>The <parameter>CUSTOMFIELD</parameter> a create sends for type <var>pType</var> from the argument
/// <var>pSupplied</var>, one diff row per member appended to <var>pDiff</var>, or <code>""</code> for
/// an argument naming no member. A flag member is composed as the 0 or 1 the instance answers it as.
/// A member the type does not take, or a file location, is <var>pProblem</var>.</p>
ClassMethod ComposedCustom(pType As %String, pSupplied, pDiff As %DynamicArray, Output pProblem As %String) As %DynamicObject
{
    Set pProblem = ""
    If '$IsObject(pSupplied) || 'pSupplied.%IsA("%Library.DynamicObject") {
        Set pProblem = "'" _ ..#CUSTOMFIELD _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        Quit ""
    }
    Set tSC = $ClassMethod(..#RULES, "Members", pType, .tSettable, .tPaths)
    If $$$ISERR(tSC) {
        Set pProblem = $ClassMethod(..#RULES, "MemberProblem", ..#CUSTOMFIELD, 0)
        Quit ""
    }
    Set tCustom = {}
    Set tIterator = pSupplied.%GetIterator()
    While tIterator.%GetNext(.tMember, .tValue) {
        If '$ListFind(tSettable, tMember) {
            Set pProblem = $ClassMethod(..#RULES, "MemberProblem", ..#CUSTOMFIELD _ "." _ tMember, ''$ListFind(tPaths, tMember))
            Quit
        }
        Set tKind = pSupplied.%GetTypeOf(tMember)
        If $ListFind($ListFromString($Parameter(..#RULES, "FLAGMEMBERS")), tMember) {
            Do tCustom.%Set(tMember, ''tValue, "number")
            Set tShown = $Select(tValue: "1", 1: "0")
        } Else {
            Do tCustom.%Set(tMember, tValue, tKind)
            Set tShown = ##class(OcuPilot.Kernel.Proposal.Mint).Display(tValue, tKind)
        }
        Do pDiff.%Push(..Row(..#CUSTOMFIELD _ "." _ tMember, "", tShown))
    }
    If pProblem '= "" Quit ""
    Set tAny = 0
    Set tIterator = tCustom.%GetIterator()
    While tIterator.%GetNext(.tMember, .tValue) {
        Set tAny = 1
    }
    Quit $Select(tAny: tCustom, 1: "")
}

/// <p>One diff row.</p>
ClassMethod Row(pField As %String, pBefore As %String, pAfter As %String) As %DynamicObject
{
    Set tRow = {}
    Do tRow.%Set("field", pField, "string")
    Do tRow.%Set("before", pBefore, "string")
    Do tRow.%Set("after", pAfter, "string")
    Quit tRow
}

/// <p>What the caller must hold: the screen's own pairs, then
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter> and
/// <parameter>MANAGERESOURCE</parameter>:<parameter>MANAGEPERMISSION</parameter>, then the custom
/// resource of each <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    For tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION), $ListBuild(..#MANAGERESOURCE, ..#MANAGEPERMISSION) {
        If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    }
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
