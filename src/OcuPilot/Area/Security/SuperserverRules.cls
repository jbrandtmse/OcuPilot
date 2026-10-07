Include %syINET

/// <p>The superservers' rules (AD-39, AD-55, Story 18.25): the one rule set
/// <class>OcuPilot.Screen.Tool.SuperserverCreate</class> and <class>OcuPilot.Screen.Tool.SuperserverUpdate</class>
/// apply at the mint and the confirm and <class>OcuPilot.Area.Security.SuperserverSave</class> applies at the
/// Save, every condition before any <code>PUT</code> (<method>Check</method>, <method>Problem</method>), and the
/// editor's form read (<method>HandleForm</method>).</p>
/// <p><b>The rules are the instance's own, decided here so a refusal costs no vendor write.</b> The vendor
/// refuses each of them with a 500 and an empty body, logged at severity 2 (AD-2), and one thing it does not
/// refuse at all: a configuration naming no SSL/TLS configuration is stored while the level is 0. Every sentence
/// is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s, from
/// <class>OcuPilot.Api.SuperserverError</class>.</p>
Class OcuPilot.Area.Security.SuperserverRules Extends %RegisteredObject
{

/// <p>The screen whose declared pairs gate the form read (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SuperserverForm";

/// <p>The tool whose port the form read asks (AD-52).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.SuperserverUpdate";

/// <p>The twelve flags, each a JSON boolean.</p>
Parameter BOOLEANS = "Enabled,EnableCacheDirect,EnableClients,EnableCSP,EnableDataCheck,EnableECP,EnableMirror,EnableNodeJS,EnableShadows,EnableSharding,EnableSNMP,EnableWebLink";

/// <p>The three flags only the system default superserver may turn on.</p>
Parameter SYSTEMONLYFLAGS = "EnableECP,EnableMirror,EnableSharding";

/// <p>The SSL/TLS configuration endpoint and the member of its read that says the configuration is a server
/// configuration, 1, as against a client one, 0 (the vendor's <code>Security.Datatype.SSLType</code>, whose
/// display is <code>Server</code> and <code>Client</code>; the demo configuration reads 0).</p>
Parameter SSLENDPOINT = "Security.SSLConfig";

Parameter SSLTYPEFIELD = "Type";

Parameter SSLSERVERTYPE = 1;

/// <p>The vendor's create defaults, measured at Story 18.25's plan: a minimal create stores these. The form
/// starts a new superserver from them.</p>
Parameter DEFAULTFLAGSON = "Enabled,EnableClients";

/// <p>Whether this instance runs on Windows, which SNMP needs. The seam a test overrides.</p>
ClassMethod Windows() As %Boolean
{
    Quit ($System.Version.GetOS() = "Windows")
}

/// <p>Every rule over <var>pBody</var>, in <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field,
/// code)</code> with the count in <code>pViolations</code>.</p>
/// <p>The shape rules always apply to the fields <var>pBody</var> carries: a flag that is not a JSON boolean,
/// a description that is not text or is over 256 characters, an SSL/TLS configuration that is not text, a
/// support level other than 0, 1 or 2, and SNMP turned on off Windows. When <var>pMode</var> is
/// <code>create</code>, <var>pPortValue</var> must be a whole number from 100 to 65535 and <var>pBindValue</var>
/// an address the instance accepts (<method>IsBindAddress</method>).</p>
/// <p>With <var>pFull</var> 1 the rules that read the superserver apply too: ECP, mirroring or sharding turned
/// on where <var>pFresh</var> is not the system default, and an SSL/TLS change -- a level or a configuration
/// differing from <var>pFresh</var>'s -- whose level is 1 or 2 with no configuration, or whose configuration,
/// at level 1 or 2 or when it is the one changed, <var>pPortClass</var>'s <code>Security.SSLConfig</code>
/// <code>GET</code> does not find or does not read as a server configuration; so level 0 keeps a stored
/// configuration unread. A look-up that cannot be made is an error status, never a pass.
/// <var>pFresh</var> is <code>""</code> for a create.</p>
ClassMethod Check(pPortValue As %String, pBody As %DynamicObject, pFresh As %DynamicObject, pMode As %String, pPortClass As %String, Output pViolations, pFull As %Boolean = 1, pBindValue As %String = "") As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pBody) Set pBody = {}
        If pMode = "create" {
            If '..IsPort(pPortValue) Do ..Add(.pViolations, "Port", ##class(OcuPilot.Api.SuperserverError).#PORT)
            If '..IsBindAddress(pBindValue) Do ..Add(.pViolations, "BindAddress", ##class(OcuPilot.Api.SuperserverError).#BINDADDRESS)
        }
        Set tFlags = $ListFromString(..#BOOLEANS)
        For tI = 1:1:$ListLength(tFlags) {
            Set tName = $List(tFlags, tI)
            If (pBody.%GetTypeOf(tName) '= "unassigned") && (pBody.%GetTypeOf(tName) '= "boolean") Do ..Add(.pViolations, tName, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        If pBody.%GetTypeOf("Description") '= "unassigned" {
            If pBody.%GetTypeOf("Description") '= "string" {
                Do ..Add(.pViolations, "Description", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            } ElseIf $Length(pBody.%Get("Description")) > ##class(OcuPilot.Api.SuperserverError).#DESCRIPTIONMAX {
                Do ..Add(.pViolations, "Description", ##class(OcuPilot.Api.SuperserverError).#DESCRIPTION)
            }
        }
        If (pBody.%GetTypeOf("SSLConfig") '= "unassigned") && (pBody.%GetTypeOf("SSLConfig") '= "string") Do ..Add(.pViolations, "SSLConfig", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        If (pBody.%GetTypeOf("SSLSupportLevel") '= "unassigned") && (..Level(pBody) = "") Do ..Add(.pViolations, "SSLSupportLevel", ##class(OcuPilot.Api.SuperserverError).#SSLLEVEL)
        If ..On(pBody, "EnableSNMP") && '..Windows() Do ..Add(.pViolations, "EnableSNMP", ##class(OcuPilot.Api.SuperserverError).#SNMP)
        If 'pFull Quit
        Set tDefault = $IsObject(pFresh) && (..On(pFresh, "SystemDefault"))
        Set tSystemOnly = $ListFromString(..#SYSTEMONLYFLAGS)
        For tI = 1:1:$ListLength(tSystemOnly) {
            Set tName = $List(tSystemOnly, tI)
            If ..On(pBody, tName) && 'tDefault Do ..Add(.pViolations, tName, ##class(OcuPilot.Api.SuperserverError).#SYSTEMONLY)
        }
        Set tSC = ..SslRules(pBody, pFresh, pPortClass, .pViolations)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The SSL/TLS rules over <var>pBody</var> against <var>pFresh</var> (<method>Check</method>).</p>
ClassMethod SslRules(pBody As %DynamicObject, pFresh As %DynamicObject, pPortClass As %String, ByRef pViolations) As %Status [ Private ]
{
    Set tFresh = $Select($IsObject(pFresh): pFresh, 1: {})
    Set tBodyLevel = ..Level(pBody)
    Set tBodyConfig = $Select(pBody.%GetTypeOf("SSLConfig") = "string": pBody.%Get("SSLConfig"), 1: "")
    Set tLevelSent = (pBody.%GetTypeOf("SSLSupportLevel") '= "unassigned")
    Set tConfigSent = (pBody.%GetTypeOf("SSLConfig") = "string")
    Set tConfigChanged = tConfigSent && (tBodyConfig '= ..Text(tFresh, "SSLConfig"))
    Set tChanged = (tLevelSent && (tBodyLevel '= ..Level(tFresh))) || tConfigChanged
    If 'tChanged Quit $$$OK
    Set tLevel = $Select(tLevelSent: tBodyLevel, 1: ..Level(tFresh))
    Set tConfig = $Select(tConfigSent: tBodyConfig, 1: ..Text(tFresh, "SSLConfig"))
    If ((tLevel = 1) || (tLevel = 2)) || ((tConfig '= "") && tConfigChanged) {
        If tConfig = "" {
            If (tLevel = 1) || (tLevel = 2) Do ..Add(.pViolations, "SSLConfig", ##class(OcuPilot.Api.SuperserverError).#SSLCONFIG)
            Quit $$$OK
        }
        Set tSC = ..ServerConfiguration(pPortClass, tConfig, .tValid)
        If $$$ISERR(tSC) Quit tSC
        If 'tValid Do ..Add(.pViolations, "SSLConfig", ##class(OcuPilot.Api.SuperserverError).#SSLCONFIG)
    }
    Quit $$$OK
}

/// <p>Whether the SSL/TLS configuration <var>pName</var> exists and is a server configuration, in
/// <var>pValid</var>, read through <var>pPortClass</var> as the caller. A 404 is a configuration that does not
/// exist; any other failed read is an error status.</p>
ClassMethod ServerConfiguration(pPortClass As %String, pName As %String, Output pValid As %Boolean) As %Status
{
    Set pValid = 0
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(pPortClass, "Invoke", ..#SSLENDPOINT, "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    If '$IsObject($Get(tRead)) || 'tRead.%IsA("%Library.DynamicObject") Quit $$$OK
    Set tType = $ZConvert(..Text(tRead, ..#SSLTYPEFIELD), "L")
    Set pValid = (tType = ..#SSLSERVERTYPE) || (tType = "server")
    Quit $$$OK
}

/// <p>Whether a superserver exists at the composite id <var>pId</var>, in <var>pTaken</var>, read through
/// <var>pPortClass</var> as the caller with the create tool's own endpoint and read type (AD-52); only a 404 is
/// free, and any other failed read is an error status.</p>
ClassMethod Taken(pPortClass As %String, pId As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Kill tQuery
    Set tQuery("port") = pId
    Set tSC = $ClassMethod(pPortClass, "Invoke", "Security.Superserver", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    Set pTaken = ($IsObject($Get(tRead)) && tRead.%IsA("%Library.DynamicObject"))
    Quit $$$OK
}

/// <p><method>Check</method> as one problem sentence naming each field and its published sentence, or
/// <code>""</code>, in <var>pProblem</var>: what the tools' <code>ArgumentProblem</code> and
/// <code>MergeUpdate</code> answer.</p>
ClassMethod Problem(pPortValue As %String, pBody As %DynamicObject, pFresh As %DynamicObject, pMode As %String, pPortClass As %String, Output pProblem As %String, pFull As %Boolean = 1, pBindValue As %String = "") As %Status
{
    Set pProblem = ""
    Set tSC = ..Check(pPortValue, pBody, pFresh, pMode, pPortClass, .tViolations, pFull, pBindValue)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>Render <var>pViolations</var> as one 422 <parameter>OcuPilot.Api.SuperserverError.VALIDATION</parameter>
/// envelope carrying every broken rule in <code>detail.violations</code> (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.SuperserverError).#REASONVALIDATION, ##class(OcuPilot.Api.SuperserverError).#VALIDATION, tDetail)
}

/// <p>Whether <var>pPortValue</var> is a whole number from 100 to 65535.</p>
ClassMethod IsPort(pPortValue As %String) As %Boolean
{
    If '$Match(pPortValue, "[0-9]{1,5}") Quit 0
    Quit (+pPortValue >= ##class(OcuPilot.Api.SuperserverError).#PORTMIN) && (+pPortValue <= ##class(OcuPilot.Api.SuperserverError).#PORTMAX)
}

/// <p>Whether <var>pBind</var> is an address the instance stores for a superserver to bind to, decided as its
/// own <code>Config.Host</code> datatype decides it (read in <file>irissys/Config/Host.cls</file>): empty, an IP
/// address, or a host name of at most 255 characters that is not digits and dots alone. The vendor refuses any
/// other with a logged 500 (AD-2).</p>
ClassMethod IsBindAddress(pBind As %String) As %Boolean
{
    If pBind = "" Quit 1
    If $$$ISIP(pBind) Quit 1
    Quit (pBind?1AN.(1AN,1"-",1"_").(1"."1.(1AN,1"-",1"_")).AN) && ($Length(pBind) < 256) && ($Translate(pBind, ".", "")'?.N)
}

/// <p>Render a failed read of a superserver: 404 <code>PORT.NOTFOUND</code>, the fault the port answered, or an
/// internal error when it answered none.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Set tMapSC = ##class(OcuPilot.Kernel.Fault).Outcome(404, $$$OK, .tAbsent, .tVendorText)
        Quit ##class(OcuPilot.Api.Error).Render(404, tAbsent.error, tAbsent.reason, tAbsent.code)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Answer <code>GET /superserver/form[?id=&lt;id&gt;]</code>: <code>{row, serving, locked, windows}</code>.
/// With an id, <code>row</code> is the fifteen settings and <code>SystemDefault</code> from the update tool's
/// fresh <code>GET</code>, with <code>Port</code> and <code>BindAddress</code> from the id; an id the instance does
/// not hold is 404 <code>PORT.NOTFOUND</code>. Without one it is a new superserver's, on the vendor's own create
/// defaults. <code>serving</code> is whether the web gateway connects through the superserver
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.IsServingSuperserver</method>), <code>locked</code> the fields
/// whose change is then refused <parameter>OcuPilot.Kernel.Proposal.Prohibited.SERVINGSUPERSERVER</parameter>,
/// each as <code>{field, code, reason}</code>, and <code>windows</code> whether SNMP is available.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tId = $Get(%request.Data("id", 1))
        Set tRow = {}
        Set tLocked = []
        Set tServing = 0
        If tId = "" {
            Do ..DefaultRow(tRow)
        } Else {
            Set tPort = $ClassMethod(..#UPDATETOOL, "PortClass")
            Kill tQuery
            Set tQuery($ClassMethod(..#UPDATETOOL, "IdParam")) = tId
            Set tReadSC = $ClassMethod(tPort, "Invoke", $ClassMethod(..#UPDATETOOL, "Endpoint"), $ClassMethod(..#UPDATETOOL, "ReadType"), .tQuery, "", .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, $Get(tHttp), $Get(tFault))
                Quit
            }
            If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") {
                Set tSC = ..RenderRead($$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND), 404, "")
                Quit
            }
            Set tRow = ##class(%DynamicAbstractObject).%FromJSON(tFresh.%ToJSON())
            Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(tId)
            Do tRow.%Set("Port", +$ListGet(tParts, 1), "number")
            Set tBind = $ListGet(tParts, 2)
            Do tRow.%Set("BindAddress", $Select(tBind = "": ##class(OcuPilot.Kernel.EntityRef).#RULEPORTBINDANY, 1: tBind), "string")
            Set tServing = ##class(OcuPilot.Kernel.Proposal.Prohibited).IsServingSuperserver(tId, tFresh, ##class(OcuPilot.Kernel.Proposal.Prohibited).ServingSuperserverPort())
            Do ##class(OcuPilot.Kernel.Proposal.Prohibited).SuperserverLocks(tId, tFresh, .tFields)
            Set tCode = ##class(OcuPilot.Kernel.Proposal.Prohibited).#SERVINGSUPERSERVER
            Set tIterator = tFields.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tField) {
                Do tLocked.%Push({"field": (tField), "code": (tCode), "reason": (##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))})
            }
        }
        Set tBody = {}
        Do tBody.%Set("row", tRow)
        Do tBody.%Set("serving", ''tServing, "boolean")
        Do tBody.%Set("locked", tLocked)
        Do tBody.%Set("windows", ''..Windows(), "boolean")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Set into <var>pRow</var> a new superserver's fields: the vendor's own create defaults, measured at
/// Story 18.25's plan (<parameter>DEFAULTFLAGSON</parameter> on, every other flag off, level 0), and no port.</p>
ClassMethod DefaultRow(pRow As %DynamicObject)
{
    Do pRow.%Set("Port", "", "string")
    Do pRow.%Set("BindAddress", "", "string")
    Do pRow.%Set("Description", "", "string")
    Set tFlags = $ListFromString(..#BOOLEANS)
    For tI = 1:1:$ListLength(tFlags) {
        Set tName = $List(tFlags, tI)
        Do pRow.%Set(tName, ''$ListFind($ListFromString(..#DEFAULTFLAGSON), tName), "boolean")
    }
    Do pRow.%Set("SSLConfig", "", "string")
    Do pRow.%Set("SSLSupportLevel", 0, "number")
    Do pRow.%Set("SystemDefault", 0, "boolean")
}

/// <p>Refuse a caller who does not hold the form's declared pairs (AD-8): <var>pRefused</var> 1 means the
/// envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p><var>pBody</var>'s SSL/TLS support level as 0, 1 or 2, or <code>""</code> when it carries none or one
/// that is not exactly one of the three, as a number or its plain spelling.</p>
ClassMethod Level(pBody As %DynamicObject) As %String
{
    Set tType = pBody.%GetTypeOf("SSLSupportLevel")
    If (tType '= "string") && (tType '= "number") Quit ""
    Set tValue = pBody.%Get("SSLSupportLevel") _ ""
    If (tValue = "0") || (tValue = "1") || (tValue = "2") Quit +tValue
    Quit ""
}

/// <p>Whether <var>pBody</var> carries <var>pName</var> as the JSON boolean true.</p>
ClassMethod On(pBody As %DynamicObject, pName As %String) As %Boolean [ Private ]
{
    If pBody.%GetTypeOf(pName) '= "boolean" Quit 0
    Quit ''pBody.%Get(pName)
}

/// <p><var>pBody</var>'s <var>pName</var> as text, <code>""</code> when it carries none.</p>
ClassMethod Text(pBody As %DynamicObject, pName As %String) As %String [ Private ]
{
    Set tType = pBody.%GetTypeOf(pName)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pBody.%Get(pName) _ ""
}

/// <p>Append one violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
