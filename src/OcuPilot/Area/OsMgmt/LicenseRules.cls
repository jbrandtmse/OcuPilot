Include %syINET

/// <p>The licensing screens' rules (AD-39, AD-55, Story 18.6): the one rule set every caller of
/// <class>OcuPilot.Screen.Tool.LicenseServerCreate</class> and
/// <class>OcuPilot.Screen.Tool.LicenseServerUpdate</class> applies before the port is touched
/// (<method>Validate</method>, <method>Problem</method>); the license server form's read
/// (<method>HandleForm</method>) and name look-up (<method>HandleName</method>); and License key's
/// screen-only check (<method>HandleValidate</method>).</p>
/// <p><b>The rules close the vendor's gaps</b>: the instance accepts a name with a space or a dot and
/// any port, 0 and 70000 included (measured at Story 18.6's Task 0), and each is refused here, on both
/// callers. An address is held to <class>Config.Host</class>'s own check
/// (<method>IsAddress</method>), so one the vendor would refuse is refused on its field instead.
/// Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s, and every read is made
/// as the caller through the tools' own port.</p>
Class OcuPilot.Area.OsMgmt.LicenseRules Extends %RegisteredObject
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.LicenseServerCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.LicenseServerUpdate";

/// <p>The screen whose declared pairs gate the license server routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LicenseServerForm";

/// <p>The screen whose declared pairs gate the key check (AD-8).</p>
Parameter KEYDESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LicenseKey";

/// <p>The key check's port.</p>
Parameter KEYPORT = "OcuPilot.Port.LicensePort";

/// <p>A license server name: a letter or digit, then up to 63 letters, digits, hyphens and
/// underscores. <class>Config.LicenseServers</class> stores at most 64 characters.</p>
Parameter NAMEPATTERN = "[A-Za-z0-9][A-Za-z0-9_-]{0,63}";

/// <p>The longest host name <class>Config.Host</class> accepts: fewer than 256 characters.</p>
Parameter ADDRESSMAXLENGTH As INTEGER = 255;

Parameter NAMEMAXLENGTH As INTEGER = 64;

/// <p>The highest port.</p>
Parameter PORTMAXIMUM As INTEGER = 65535;

/// <p>The fields a create must carry, comma-separated.</p>
Parameter REQUIREDFIELDS = "Name,Address,Port";

/// <p>The two settable fields, in the classic page's order.</p>
Parameter FIELDS = "Address,Port";

Parameter FIELDNAME = "Name";

Parameter FIELDADDRESS = "Address";

Parameter FIELDPORT = "Port";

/// <p>The field the form shows and never sends (AD-21).</p>
Parameter FIELDKEYDIRECTORY = "KeyDirectory";

/// <p>Every rule a license server write applies to <var>pArgs</var> for <var>pName</var>, in
/// <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pMode</var> <code>create</code> applies the name's shape, the look-up when
/// <var>pCheckTaken</var> is 1, and requires the address and the port; <code>update</code> applies the
/// address and port rules to whichever of them <var>pArgs</var> carries. A look-up that cannot be made
/// is an error status, never a pass.</p>
ClassMethod Validate(pName As %String, pArgs As %DynamicObject, Output pViolations, pMode As %String = "create", pCheckTaken As %Boolean = 1) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pArgs) Set pArgs = {}
        Set tCreates = (pMode = "create")
        If tCreates {
            Do ..NameViolation(pName, .pViolations)
            If (pViolations = 0) && pCheckTaken {
                Set tSC = ..Taken(pName, .tTaken)
                If $$$ISERR(tSC) Quit
                If tTaken Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.LicenseError).#SERVERNAMETAKEN)
            }
        }
        If tCreates || (pArgs.%GetTypeOf(..#FIELDADDRESS) '= "unassigned") {
            If (pArgs.%GetTypeOf(..#FIELDADDRESS) '= "string") || '..IsAddress(pArgs.%Get(..#FIELDADDRESS)) Do ..Add(.pViolations, ..#FIELDADDRESS, ##class(OcuPilot.Api.LicenseError).#SERVERADDRESS)
        }
        If tCreates || (pArgs.%GetTypeOf(..#FIELDPORT) '= "unassigned") {
            If '..IsPort(pArgs) Do ..Add(.pViolations, ..#FIELDPORT, ##class(OcuPilot.Api.LicenseError).#SERVERPORT)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The name's own violation, or none: <parameter>NAMEPATTERN</parameter>.</p>
ClassMethod NameViolation(pName As %String, Output pViolations)
{
    If '$Match(pName, ..#NAMEPATTERN) Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.LicenseError).#SERVERNAMESHAPE)
}

/// <p>Whether <var>pAddress</var> is one <class>Config.Host</class> stores: an IP address, or a host
/// name of letters, digits, hyphens and underscores in dot-separated labels, each beginning and ending
/// with a letter or digit, not all digits, and at most <parameter>ADDRESSMAXLENGTH</parameter>
/// characters. The vendor refuses any other non-empty value with a datatype error.</p>
ClassMethod IsAddress(pAddress As %String) As %Boolean
{
    If $ZStrip(pAddress, "<>W") = "" Quit 0
    If $$$ISIP(pAddress) Quit 1
    If $Length(pAddress) > ..#ADDRESSMAXLENGTH Quit 0
    If $Translate(pAddress, ".", "") ? .N Quit 0
    Quit pAddress ? 1AN.(1AN,1"-",1"_").(1"."1.(1AN,1"-",1"_")).AN
}

/// <p>Whether <var>pArgs</var>'s <code>Port</code> is a whole number from 1 to
/// <parameter>PORTMAXIMUM</parameter>, sent as a number or as its plain decimal spelling.</p>
ClassMethod IsPort(pArgs As %DynamicObject) As %Boolean
{
    Set tType = pArgs.%GetTypeOf(..#FIELDPORT)
    If (tType '= "number") && (tType '= "string") Quit 0
    Set tPort = pArgs.%Get(..#FIELDPORT) _ ""
    If '$Match(tPort, "[1-9][0-9]{0,4}") Quit 0
    Quit (+tPort <= ..#PORTMAXIMUM)
}

/// <p><method>Validate</method> over the agent's arguments for <var>pIdValue</var> in mode
/// <var>pMode</var>, the look-up never (the mint's absence read answers it), as one
/// <var>pProblem</var> naming each field and its published sentence (AD-55).</p>
ClassMethod Problem(pIdValue As %String, pArgs As %DynamicObject, pMode As %String, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ..Validate(pIdValue, pArgs, .tViolations, pMode, 0)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tField = $List(tViolations(tI), 1)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ tField _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>The body <var>pPayload</var> sends, with <code>Port</code> a number, as the vendor's own read
/// answers it. Only the type changes.</p>
ClassMethod Shape(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#FIELDPORT) = "string") && $Match(pPayload.%Get(..#FIELDPORT), "[1-9][0-9]{0,4}") Do pPayload.%Set(..#FIELDPORT, +pPayload.%Get(..#FIELDPORT), "number")
}

/// <p>Whether a license server is named <var>pName</var> in any case, in <var>pTaken</var>, read
/// through the create tool's own port, endpoint and read type (AD-52); only a 404 is free.</p>
ClassMethod Taken(pName As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Set tSC = ..Read(..#CREATETOOL, pName, .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    Set pTaken = ($IsObject(tFresh) && tFresh.%IsA("%Library.DynamicObject"))
    Quit $$$OK
}

/// <p>The present license server <var>pName</var>, read through the edit tool's own port, in
/// <var>pFresh</var>; an absent one is an error status with <var>pHttpStatus</var> 404.</p>
ClassMethod Present(pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ..Read(..#UPDATETOOL, pName, .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
    }
    Quit tSC
}

/// <p>Read <var>pName</var> through tool <var>pToolClass</var>'s own port, endpoint and read type.</p>
ClassMethod Read(pToolClass As %String, pName As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "IdParam")) = pName
        Set tSC = $ClassMethod($ClassMethod(pToolClass, "PortClass"), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    } Catch ex {
        Set pFresh = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Answer <code>POST /license/key/validate</code> with body <code>{Key}</code>: License key's
/// screen-only check (AD-39, AD-53), under that screen's pairs and with no port call for a caller
/// short of one. A valid key answers <code>{valid, requiresRestart, reductions, features}</code>
/// (<method>OcuPilot.Port.LicensePort.Validate</method>), marked <code>Cache-Control: no-store</code>;
/// an empty or invalid one is 422 on <code>Key</code>. The body is never logged, echoed or kept.</p>
ClassMethod HandleValidate() As %Status
{
    Set tSC = $$$OK
    Set tKey = ""
    Try {
        Set tFailedPair = ""
        If '##class(OcuPilot.Screen.Gate).Evaluate(..#KEYDESCRIPTORCLASS, .tFailedPair) {
            Set tSC = ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
            Quit
        }
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) || '$IsObject($Get(tBody)) || 'tBody.%IsA("%Library.DynamicObject") || (tBody.%Size() '= 1) || (tBody.%GetTypeOf("Key") '= "string") {
            Set tBody = ""
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tKey = tBody.%Get("Key")
        Set tBody = ""
        Set %response.Headers("Cache-Control") = "no-store"
        Set tCheckSC = $ClassMethod(..KeyPortClass(), "Validate", tKey, .tAnswer, .tHttp, .tFault)
        Set tKey = ""
        If $$$ISERR(tCheckSC) {
            If '$IsObject($Get(tFault)) || (tFault.%Get("code") = ##class(OcuPilot.Api.Error).#INTERNAL) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the license key check failed")))
                Quit
            }
            Set tSC = ##class(OcuPilot.Api.Error).Render($Select(+$Get(tHttp): +tHttp, 1: 500), tFault.error, tFault.reason, tFault.code, tFault.%Get("detail"))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the license key check route failed")))
    }
    Set tKey = ""
    Quit tSC
}

/// <p>The port the key check goes through. Overridable so a fixture can answer it; production never
/// overrides it.</p>
ClassMethod KeyPortClass() As %String
{
    Quit ..#KEYPORT
}

/// <p>Answer <code>GET /license-server/form[?name=&lt;n&gt;]</code>: <code>{requiredFields,
/// maxLengths, rules}</code>, and with a name <code>server: {Name, Address, Port, KeyDirectory}</code>
/// from the edit tool's fresh read, <code>Name</code> as the instance stores it; a name the instance
/// does not define is 404 <code>PORT.NOTFOUND</code>.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tBody = {}
        Set tRequired = []
        For tI = 1:1:$Length(..#REQUIREDFIELDS, ",") Do tRequired.%Push($Piece(..#REQUIREDFIELDS, ",", tI))
        Do tBody.%Set("requiredFields", tRequired)
        Set tLengths = {}
        Do tLengths.%Set(..#FIELDNAME, ..#NAMEMAXLENGTH, "number")
        Do tLengths.%Set(..#FIELDADDRESS, ..#ADDRESSMAXLENGTH, "number")
        Do tBody.%Set("maxLengths", tLengths)
        Do tBody.%Set("rules", ..Rules())
        Set tName = $Get(%request.Data("name", 1))
        If tName '= "" {
            Set tReadSC = ..Present(tName, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, $Get(tHttp), $Get(tFault))
                Quit
            }
            Set tServer = {}
            Do tServer.%Set(..#FIELDNAME, $ZConvert(tName, "U"), "string")
            For tField = ..#FIELDADDRESS, ..#FIELDKEYDIRECTORY {
                Do tServer.%Set(tField, ..Text(tFresh, tField), "string")
            }
            If tFresh.%GetTypeOf(..#FIELDPORT) = "number" {
                Do tServer.%Set(..#FIELDPORT, tFresh.%Get(..#FIELDPORT), "number")
            } Else {
                Do tServer.%Set(..#FIELDPORT, ..Text(tFresh, ..#FIELDPORT), "string")
            }
            Do tBody.%Set("server", tServer)
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /license-server/name?name=&lt;n&gt;</code>: whether that name is taken in any
/// case, in <code>{name, taken, reason}</code>. A name of the wrong shape is its 422; a look-up that
/// cannot be made is a refusal envelope, never an assertion that the name is free.</p>
ClassMethod HandleName() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tName = $Get(%request.Data("name", 1))
        Kill tViolations
        Set tViolations = 0
        Do ..NameViolation(tName, .tViolations)
        If tViolations > 0 {
            Set tSC = ..RenderViolations(.tViolations)
            Quit
        }
        Set tTakenSC = ..Taken(tName, .tTaken)
        If $$$ISERR(tTakenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tTakenSC))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("name", tName, "string")
        Do tBody.%Set("taken", tTaken, "boolean")
        Do tBody.%Set("reason", $Select(tTaken: ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.LicenseError).#SERVERNAMETAKEN), 1: ""), "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Every rule the license server form applies, as <code>[{field, code, reason}]</code>.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = $ListBuild(##class(OcuPilot.Api.LicenseError).#SERVERNAMESHAPE, ##class(OcuPilot.Api.LicenseError).#SERVERNAMETAKEN, ##class(OcuPilot.Api.LicenseError).#SERVERADDRESS, ##class(OcuPilot.Api.LicenseError).#SERVERPORT)
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tRow = {}
        Do tRow.%Set("field", ##class(OcuPilot.Api.LicenseError).FieldOf(tCode), "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForViolation(tCode), "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>Render <var>pViolations</var> as one 422
/// <parameter>OcuPilot.Api.LicenseError.SERVERVALIDATION</parameter> envelope carrying every broken
/// rule in <code>detail.violations</code> (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.LicenseError).#REASONSERVERVALIDATION, ##class(OcuPilot.Api.LicenseError).#SERVERVALIDATION, tDetail)
}

/// <p>Render a failed read: a 404 as <code>PORT.NOTFOUND</code>, an internal failure generically, and
/// any other refusal as the port's own envelope.</p>
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

/// <p>Refuse a caller who does not hold the form's declared pairs (AD-8): <var>pRefused</var> 1
/// means the envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p><var>pObject</var>'s <var>pField</var> as text: absent, null, an object or an array as
/// <code>""</code>.</p>
ClassMethod Text(pObject As %DynamicObject, pField As %String) As %String
{
    If '$IsObject(pObject) Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pObject.%Get(pField) _ ""
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
