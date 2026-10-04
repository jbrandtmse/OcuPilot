/// <p>ECP data servers' rules (AD-39, AD-55, Story 18.20): the one rule set every caller of
/// <class>OcuPilot.Screen.Tool.EcpDataServerCreate</class> and
/// <class>OcuPilot.Screen.Tool.EcpDataServerUpdate</class> applies before the port is touched
/// (<method>Validate</method>, <method>Problem</method>), the data server form's read
/// (<method>HandleForm</method>) and its name look-up (<method>HandleName</method>).</p>
/// <p><b>The rules close the vendor's gaps</b>: the instance stores port 0, answers a name with a space
/// or a dot, a 65-character name, a mirror connection of 2 and a port above 65535 with an internal
/// error, and logged a failed connection for port 70000 (measured at Story 18.20's Task 0); each is
/// refused here, on both callers, with zero vendor calls. An address is held to
/// <class>Config.Host</class>'s own check (<method>OcuPilot.Area.OsMgmt.LicenseRules.IsAddress</method>).
/// A stored non-zero mirror connection is kept, as the classic dialog keeps it. Every sentence is
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s, and every read is made as the caller
/// through the tools' own port.</p>
Class OcuPilot.Area.OsMgmt.EcpRules Extends %RegisteredObject
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.EcpDataServerCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.EcpDataServerUpdate";

/// <p>The screen whose declared pairs gate the data server routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EcpDataServerForm";

/// <p>A data server name: a letter or digit, then up to 63 letters, digits, hyphens and underscores.
/// <class>Config.ECPServers</class> stores at most 64 characters, upper-cased.</p>
Parameter NAMEPATTERN = "[A-Za-z0-9][A-Za-z0-9_-]{0,63}";

Parameter NAMEMAXLENGTH As INTEGER = 64;

/// <p>The port a new data server is offered, the classic dialog's.</p>
Parameter DEFAULTPORT As INTEGER = 1972;

/// <p>The fields a create must carry, comma-separated.</p>
Parameter REQUIREDFIELDS = "Name,Address,Port";

Parameter FIELDNAME = "Name";

Parameter FIELDADDRESS = "Address";

Parameter FIELDPORT = "Port";

Parameter FIELDMIRROR = "MirrorConnection";

Parameter FIELDSSL = "SSLConfig";

Parameter FIELDBATCH = "BatchMode";

/// <p>The <code>LIST</code> row's status member, which the form answers beside the
/// <code>GET</code> fields.</p>
Parameter FIELDSTATUS = "Status";

/// <p>Every rule a data server write applies to <var>pArgs</var> for <var>pName</var>, in
/// <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pMode</var> <code>create</code> applies the name's shape, the look-up when
/// <var>pCheckTaken</var> is 1, and requires the address and the port; <code>update</code> applies the
/// rules to whichever field <var>pArgs</var> carries, and holds a mirror connection to
/// <var>pStored</var>, the fresh read's own value: a stored non-zero one is kept. A look-up that cannot
/// be made is an error status, never a pass.</p>
ClassMethod Validate(pName As %String, pArgs As %DynamicObject, Output pViolations, pMode As %String = "create", pCheckTaken As %Boolean = 1, pStored As %String = "") As %Status
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
                If tTaken Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.EcpError).#NAMETAKEN)
            }
        }
        If tCreates || (pArgs.%GetTypeOf(..#FIELDADDRESS) '= "unassigned") {
            If (pArgs.%GetTypeOf(..#FIELDADDRESS) '= "string") || '##class(OcuPilot.Area.OsMgmt.LicenseRules).IsAddress(pArgs.%Get(..#FIELDADDRESS)) Do ..Add(.pViolations, ..#FIELDADDRESS, ##class(OcuPilot.Api.EcpError).#ADDRESS)
        }
        If tCreates || (pArgs.%GetTypeOf(..#FIELDPORT) '= "unassigned") {
            If '##class(OcuPilot.Area.OsMgmt.LicenseRules).IsPort(pArgs) Do ..Add(.pViolations, ..#FIELDPORT, ##class(OcuPilot.Api.EcpError).#PORT)
        }
        If pArgs.%GetTypeOf(..#FIELDMIRROR) '= "unassigned" {
            Set tMirror = ..Flag(pArgs, ..#FIELDMIRROR)
            Set tKept = (pStored '= "") && (+pStored '= 0)
            If tKept {
                If tMirror '= +pStored Do ..Add(.pViolations, ..#FIELDMIRROR, ##class(OcuPilot.Api.EcpError).#MIRROR)
            } ElseIf (tMirror '= 0) && (tMirror '= 1) {
                Do ..Add(.pViolations, ..#FIELDMIRROR, ##class(OcuPilot.Api.EcpError).#MIRROR)
            }
        }
        If pArgs.%GetTypeOf(..#FIELDSSL) '= "unassigned" {
            Set tSSL = ..Flag(pArgs, ..#FIELDSSL)
            If (tSSL '= 0) && (tSSL '= 1) Do ..Add(.pViolations, ..#FIELDSSL, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        If pArgs.%GetTypeOf(..#FIELDBATCH) '= "unassigned" {
            If pArgs.%GetTypeOf(..#FIELDBATCH) '= "boolean" Do ..Add(.pViolations, ..#FIELDBATCH, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><var>pArgs</var>'s <var>pField</var> as a whole number: a boolean as 0 or 1, a number or its
/// plain decimal spelling as itself, and anything else as <code>""</code>, which no rule admits.</p>
ClassMethod Flag(pArgs As %DynamicObject, pField As %String) As %String
{
    Set tType = pArgs.%GetTypeOf(pField)
    If tType = "boolean" Quit $Select(pArgs.%Get(pField): 1, 1: 0)
    If (tType '= "number") && (tType '= "string") Quit ""
    Set tValue = pArgs.%Get(pField) _ ""
    If '$Match(tValue, "-?[0-9]{1,5}") Quit ""
    Quit +tValue
}

/// <p>The name's own violation, or none: <parameter>NAMEPATTERN</parameter>.</p>
ClassMethod NameViolation(pName As %String, Output pViolations)
{
    If '$Match(pName, ..#NAMEPATTERN) Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.EcpError).#NAMESHAPE)
}

/// <p><method>Validate</method> over the agent's arguments for <var>pIdValue</var> in mode
/// <var>pMode</var>, the look-up never (the mint's absence read answers it), as one
/// <var>pProblem</var> naming each field and its published sentence (AD-55). <var>pStored</var> is
/// the update's fresh mirror connection.</p>
ClassMethod Problem(pIdValue As %String, pArgs As %DynamicObject, pMode As %String, Output pProblem As %String, pStored As %String = "") As %Status
{
    Set pProblem = ""
    Set tSC = ..Validate(pIdValue, pArgs, .tViolations, pMode, 0, pStored)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tField = $List(tViolations(tI), 1)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ tField _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>The change status tool's refusal at the mint, naming <code>Status</code> and the published
/// sentence: <var>pWhich</var> <code>same</code> for a status equal to the current one
/// (<parameter>OcuPilot.Api.EcpError.STATUSSAME</parameter>), <code>license</code> for Normal on an
/// instance whose license enables no ECP (<parameter>OcuPilot.Api.EcpError.LICENSE</parameter>).</p>
ClassMethod StatusProblem(pWhich As %String) As %String
{
    Set tCode = $Select(pWhich = "license": ##class(OcuPilot.Api.EcpError).#LICENSE, 1: ##class(OcuPilot.Api.EcpError).#STATUSSAME)
    Quit "'" _ ..#FIELDSTATUS _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
}

/// <p>The body <var>pPayload</var> sends, with <code>Port</code> a number, as the vendor's own read
/// answers it. Only the type changes.</p>
ClassMethod Shape(pPayload As %DynamicObject)
{
    Do ##class(OcuPilot.Area.OsMgmt.LicenseRules).Shape(pPayload)
}

/// <p>Whether a data server is named <var>pName</var> in any case, in <var>pTaken</var>, read through
/// the create tool's own port, endpoint and read type (AD-52); only a 404 is free.</p>
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

/// <p>The present data server <var>pName</var>, read through the edit tool's own port, in
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

/// <p>Answer <code>GET /ecp-data-server/form[?name=&lt;n&gt;]</code>: <code>{requiredFields,
/// maxLengths, rules, licensed, server}</code>. With a name, <code>server</code> is
/// <code>{Name, Address, Port, MirrorConnection, SSLConfig, BatchMode, Status}</code> from the edit
/// tool's fresh <code>GET</code>, <code>Name</code> as the instance stores it, and the
/// <code>LIST</code> row's <code>Status</code>; a name the instance does not define is 404
/// <code>PORT.NOTFOUND</code>. Without one it is a new server's: empty, on
/// <parameter>DEFAULTPORT</parameter>. <code>licensed</code> is
/// <method>OcuPilot.Port.EcpPort.NetworkEnabled</method>.</p>
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
        Do tLengths.%Set(..#FIELDADDRESS, ##class(OcuPilot.Area.OsMgmt.LicenseRules).#ADDRESSMAXLENGTH, "number")
        Do tBody.%Set("maxLengths", tLengths)
        Do tBody.%Set("rules", ..Rules())
        Set tPort = $ClassMethod(..#UPDATETOOL, "PortClass")
        Do tBody.%Set("licensed", ''$ClassMethod(tPort, "NetworkEnabled"), "boolean")
        Set tServer = {}
        Set tName = $Get(%request.Data("name", 1))
        If tName = "" {
            Do tServer.%Set(..#FIELDNAME, "", "string")
            Do tServer.%Set(..#FIELDADDRESS, "", "string")
            Do tServer.%Set(..#FIELDPORT, ..#DEFAULTPORT, "number")
            Do tServer.%Set(..#FIELDMIRROR, 0, "number")
            Do tServer.%Set(..#FIELDSSL, 0, "boolean")
            Do tServer.%Set(..#FIELDBATCH, 0, "boolean")
            Do tServer.%Set(..#FIELDSTATUS, "", "string")
        } Else {
            Set tReadSC = ..Present(tName, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ##class(OcuPilot.Area.OsMgmt.LicenseRules).RenderRead(tReadSC, $Get(tHttp), $Get(tFault))
                Quit
            }
            Set tRowSC = $ClassMethod(tPort, "Row", tName, .tRow, .tRowHttp, .tRowFault)
            If $$$ISERR(tRowSC) {
                Set tSC = ##class(OcuPilot.Area.OsMgmt.LicenseRules).RenderRead(tRowSC, $Get(tRowHttp), $Get(tRowFault))
                Quit
            }
            Do tServer.%Set(..#FIELDNAME, $ZConvert(tName, "U"), "string")
            Do tServer.%Set(..#FIELDADDRESS, ##class(OcuPilot.Area.OsMgmt.LicenseRules).Text(tFresh, ..#FIELDADDRESS), "string")
            For tField = ..#FIELDPORT, ..#FIELDMIRROR {
                If tFresh.%GetTypeOf(tField) = "number" {
                    Do tServer.%Set(tField, tFresh.%Get(tField), "number")
                } Else {
                    Do tServer.%Set(tField, ##class(OcuPilot.Area.OsMgmt.LicenseRules).Text(tFresh, tField), "string")
                }
            }
            For tField = ..#FIELDSSL, ..#FIELDBATCH {
                Do tServer.%Set(tField, ..Flag(tFresh, tField) = 1, "boolean")
            }
            Do tServer.%Set(..#FIELDSTATUS, ##class(OcuPilot.Area.OsMgmt.LicenseRules).Text(tRow, ..#FIELDSTATUS), "string")
        }
        Do tBody.%Set("server", tServer)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /ecp-data-server/name?name=&lt;n&gt;</code>: whether that name is taken in any
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
        Do tBody.%Set("reason", $Select(tTaken: ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.EcpError).#NAMETAKEN), 1: ""), "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Every rule the data server form applies, as <code>[{field, code, reason}]</code>.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = $ListBuild(##class(OcuPilot.Api.EcpError).#NAMESHAPE, ##class(OcuPilot.Api.EcpError).#NAMETAKEN, ##class(OcuPilot.Api.EcpError).#ADDRESS, ##class(OcuPilot.Api.EcpError).#PORT, ##class(OcuPilot.Api.EcpError).#MIRROR, ##class(OcuPilot.Api.EcpError).#SSLCLIENT)
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tRow = {}
        Do tRow.%Set("field", ##class(OcuPilot.Api.EcpError).FieldOf(tCode), "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForViolation(tCode), "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>Render <var>pViolations</var> as one 422
/// <parameter>OcuPilot.Api.EcpError.DATASERVERVALIDATION</parameter> envelope carrying every broken
/// rule in <code>detail.violations</code> (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.EcpError).#REASONDATASERVERVALIDATION, ##class(OcuPilot.Api.EcpError).#DATASERVERVALIDATION, tDetail)
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

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
