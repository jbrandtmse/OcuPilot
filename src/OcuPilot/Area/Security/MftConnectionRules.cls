/// <p>The managed file transfer connections' rules (AD-39, AD-55, Story 18.26): the one rule set
/// <class>OcuPilot.Screen.Tool.MftConnectionCreate</class> and <class>OcuPilot.Screen.Tool.MftConnectionUpdate</class>
/// apply at the mint and the confirm and <class>OcuPilot.Area.Security.MftConnectionSave</class> applies at the
/// Save, every condition before any <code>PUT</code> (<method>Check</method>, <method>Problem</method>), and the
/// editor's form read (<method>HandleForm</method>).</p>
/// <p><b>The rules are OcuPilot's own.</b> The vendor checks only each value's length (measured at Story 18.26's
/// plan): an empty value, a URL that is not one, an SSL/TLS configuration that does not exist and a service it
/// cannot open are all stored or answered 500. Every sentence is
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s, from <class>OcuPilot.Api.MftConnectionError</class>.</p>
/// <p><b>A create requires all five fields.</b> An update judges only the fields it changes, so a stored value is
/// never refused for being as it is.</p>
Class OcuPilot.Area.Security.MftConnectionRules Extends %RegisteredObject
{

/// <p>The screen whose declared pairs gate the form read (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.MftConnectionForm";

/// <p>The tool whose port the form read asks (AD-52).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.MftConnectionUpdate";

/// <p>The five fields a connection carries, in the order they are judged.</p>
Parameter FIELDS = "Service,URL,SSLConfiguration,Username,ApplicationName";

/// <p>The services the instance opens.</p>
Parameter SERVICES = "Box,Dropbox,Kiteworks";

/// <p>The SSL/TLS configuration endpoint, and the member of its read that says the configuration is a client
/// configuration, 0, as against a server one, 1 (the vendor's <code>Security.Datatype.SSLType</code>).</p>
Parameter SSLENDPOINT = "Security.SSLConfig";

Parameter SSLTYPEFIELD = "Type";

Parameter SSLCLIENTTYPE = 0;

/// <p>Every rule over <var>pBody</var>, in <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field,
/// code)</code> with the count in <code>pViolations</code>.</p>
/// <p>A value that is not text is a shape violation on its field. When <var>pMode</var> is <code>create</code>,
/// <var>pName</var> must be a valid name (<method>IsName</method>) and each of the five fields must be present
/// and valid. When it is <code>update</code> and <var>pFull</var> is 1, a field is judged only where it differs from
/// <var>pFresh</var>'s; with <var>pFull</var> 0 only its shape is. With <var>pFull</var> 1 the rule that reads the
/// instance applies too: an SSL/TLS configuration that is sent and changed, or any one on a create, must exist and
/// be a client configuration, read through <var>pPortClass</var> as the caller. A look-up that cannot be made is
/// an error status, never a pass. <var>pFresh</var> is <code>""</code> for a create.</p>
ClassMethod Check(pName As %String, pBody As %DynamicObject, pFresh As %DynamicObject, pMode As %String, pPortClass As %String, Output pViolations, pFull As %Boolean = 1) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pBody) Set pBody = {}
        Set tCreate = (pMode = "create")
        Set tFresh = $Select($IsObject(pFresh): pFresh, 1: {})
        If tCreate && '..IsName(pName) Do ..Add(.pViolations, "Name", ##class(OcuPilot.Api.MftConnectionError).#NAME)
        Set tFields = $ListFromString(..#FIELDS)
        For tI = 1:1:$ListLength(tFields) {
            Set tField = $List(tFields, tI)
            Set tType = pBody.%GetTypeOf(tField)
            If tType = "unassigned" {
                If tCreate Do ..Add(.pViolations, tField, ..CodeFor(tField))
                Continue
            }
            If tType '= "string" {
                Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Continue
            }
            Set tValue = pBody.%Get(tField)
            If 'tCreate && ('pFull || (tValue = ..Text(tFresh, tField))) Continue
            If '..Valid(tField, tValue) Do ..Add(.pViolations, tField, ..CodeFor(tField))
        }
        If 'pFull Quit
        Set tSslSent = (pBody.%GetTypeOf("SSLConfiguration") = "string")
        If tSslSent && (tCreate || (pBody.%Get("SSLConfiguration") '= ..Text(tFresh, "SSLConfiguration"))) && ..Valid("SSLConfiguration", pBody.%Get("SSLConfiguration")) {
            Set tSC = ..ClientConfiguration(pPortClass, pBody.%Get("SSLConfiguration"), .tValid)
            If $$$ISERR(tSC) Quit
            If 'tValid Do ..Add(.pViolations, "SSLConfiguration", ##class(OcuPilot.Api.MftConnectionError).#SSLCONFIG)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The violation code of the field <var>pField</var>.</p>
ClassMethod CodeFor(pField As %String) As %String
{
    If pField = "Service" Quit ##class(OcuPilot.Api.MftConnectionError).#SERVICE
    If pField = "URL" Quit ##class(OcuPilot.Api.MftConnectionError).#URL
    If pField = "SSLConfiguration" Quit ##class(OcuPilot.Api.MftConnectionError).#SSLCONFIG
    If pField = "Username" Quit ##class(OcuPilot.Api.MftConnectionError).#USERNAME
    Quit ##class(OcuPilot.Api.MftConnectionError).#APPLICATIONNAME
}

/// <p>Whether the text <var>pValue</var> is acceptable for the field <var>pField</var> by shape and length alone;
/// the SSL/TLS configuration's existence is <method>ClientConfiguration</method>'s.</p>
ClassMethod Valid(pField As %String, pValue As %String) As %Boolean
{
    If pField = "Service" Quit $ListFind($ListFromString(..#SERVICES), pValue) > 0
    If pField = "URL" Quit ..IsUrl(pValue)
    If pField = "SSLConfiguration" Quit ..IsBounded(pValue, ##class(OcuPilot.Api.MftConnectionError).#NAMEMAX)
    If pField = "Username" Quit ..IsBounded(pValue, ##class(OcuPilot.Api.MftConnectionError).#USERNAMEMAX)
    Quit ..IsBounded(pValue, ##class(OcuPilot.Api.MftConnectionError).#APPLICATIONNAMEMAX)
}

/// <p>Whether <var>pValue</var> is 1 to <var>pMax</var> characters.</p>
ClassMethod IsBounded(pValue As %String, pMax As %Integer) As %Boolean
{
    Quit ($Length(pValue) >= 1) && ($Length(pValue) <= pMax)
}

/// <p>Whether <var>pName</var> is a connection name: 1 to 64 characters with no control character.</p>
ClassMethod IsName(pName As %String) As %Boolean
{
    If '..IsBounded(pName, ##class(OcuPilot.Api.MftConnectionError).#NAMEMAX) Quit 0
    Quit $ZStrip(pName, "*C") = pName
}

/// <p>Whether <var>pUrl</var> is an absolute <code>http</code> or <code>https</code> URL that ends in
/// <code>/</code>, holds no white space or control character and is at most 1024 characters.</p>
ClassMethod IsUrl(pUrl As %String) As %Boolean
{
    If '..IsBounded(pUrl, ##class(OcuPilot.Api.MftConnectionError).#URLMAX) Quit 0
    Quit $Match(pUrl, "(?i)https?://[^/\s?#]+/([^\s?#]*/)?") && ($ZStrip(pUrl, "*C") = pUrl)
}

/// <p>Whether the SSL/TLS configuration <var>pName</var> exists and is a client configuration, in
/// <var>pValid</var>, read through <var>pPortClass</var> as the caller. A 404 is a configuration that does not
/// exist; any other failed read is an error status.</p>
ClassMethod ClientConfiguration(pPortClass As %String, pName As %String, Output pValid As %Boolean) As %Status
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
    Set pValid = (tType = "0") || (tType = "client")
    Quit $$$OK
}

/// <p>Whether a connection exists under the name <var>pName</var>, in <var>pTaken</var>, read through
/// <var>pPortClass</var> as the caller with the update tool's own endpoint and read type (AD-52); only a 404 is
/// free, and any other failed read is an error status.</p>
ClassMethod Taken(pPortClass As %String, pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Kill tQuery
    Set tQuery($ClassMethod(..#UPDATETOOL, "IdParam")) = pName
    Set tSC = $ClassMethod(pPortClass, "Invoke", $ClassMethod(..#UPDATETOOL, "Endpoint"), $ClassMethod(..#UPDATETOOL, "ReadType"), .tQuery, "", .tRead, .tHttp, .tFault)
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
ClassMethod Problem(pName As %String, pBody As %DynamicObject, pFresh As %DynamicObject, pMode As %String, pPortClass As %String, Output pProblem As %String, pFull As %Boolean = 1) As %Status
{
    Set pProblem = ""
    Set tSC = ..Check(pName, pBody, pFresh, pMode, pPortClass, .tViolations, pFull)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>Render <var>pViolations</var> as one 422 <parameter>OcuPilot.Api.MftConnectionError.VALIDATION</parameter>
/// envelope carrying every broken rule in <code>detail.violations</code> (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.MftConnectionError).#REASONVALIDATION, ##class(OcuPilot.Api.MftConnectionError).#VALIDATION, tDetail)
}

/// <p>Render a failed read of a connection: 404 <code>PORT.NOTFOUND</code>, the fault the port answered, or an
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

/// <p>Answer <code>GET /mft-connection/form[?id=&lt;name&gt;]</code>: <code>{row}</code>. With an id, <code>row</code>
/// is <code>Name</code> and the five fields from the update tool's fresh <code>GET</code>; an id the instance does
/// not hold is 404 <code>PORT.NOTFOUND</code>. Without one it is a new connection's, every field empty.</p>
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
            Do tRow.%Set("Name", tId, "string")
            Set tFields = $ListFromString(..#FIELDS)
            For tI = 1:1:$ListLength(tFields) {
                Set tField = $List(tFields, tI)
                Do tRow.%Set(tField, ..Text(tFresh, tField), "string")
            }
        }
        Set tBody = {}
        Do tBody.%Set("row", tRow)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Set into <var>pRow</var> a new connection's fields: every one empty.</p>
ClassMethod DefaultRow(pRow As %DynamicObject)
{
    Do pRow.%Set("Name", "", "string")
    Set tFields = $ListFromString(..#FIELDS)
    For tI = 1:1:$ListLength(tFields) Do pRow.%Set($List(tFields, tI), "", "string")
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

/// <p><var>pBody</var>'s <var>pName</var> as text, <code>""</code> when it carries none.</p>
ClassMethod Text(pBody As %DynamicObject, pName As %String) As %String
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
