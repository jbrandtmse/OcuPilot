/// <p>The remote database form's rules (AD-39, AD-55): the one rule set every caller of
/// <class>OcuPilot.Screen.Tool.RemoteDatabaseCreate</class> and
/// <class>OcuPilot.Screen.Tool.RemoteDatabaseUpdate</class> applies before the port is touched
/// (<method>Validate</method>, <method>Problem</method>), the form's read (<method>HandleForm</method>)
/// and the data server's listing (<method>HandleDirectories</method>).</p>
/// <p><b>The rules never list.</b> A name's shape and whether it is taken, whether the data server is
/// defined, and whether a directory is named are asked here; whether the directory is one the data
/// server lists is asked by <class>OcuPilot.Port.RemoteDatabasePort</class> at the write, through its
/// bounded listing (AD-21's seventh case), and so never at a mint or in a turn (AD-7). Every sentence
/// is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s, and every read goes through the
/// create tool's port as the caller.</p>
Class OcuPilot.Area.OsMgmt.RemoteDatabaseRules Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.RemoteDatabaseCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.RemoteDatabaseUpdate";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RemoteDatabaseForm";

/// <p>The local database rules, whose name rules a remote name shares (one
/// <code>Config.Databases</code> name space).</p>
Parameter DATABASERULES = "OcuPilot.Area.OsMgmt.DatabaseRules";

/// <p>The fields a create must carry, comma-separated.</p>
Parameter REQUIREDFIELDS = "Name,Server,Directory";

/// <p>The data servers' endpoint, whose <code>LIST</code> the form offers.</p>
Parameter SERVERENDPOINT = "ECP.DataServer";

Parameter FIELDNAME = "Name";

Parameter FIELDSERVER = "Server";

Parameter FIELDDIRECTORY = "Directory";

/// <p>The query parameter the listing route names its data server under.</p>
Parameter SERVERPARAM = "server";

/// <p>Every rule a remote database write applies to <var>pArgs</var> for the configuration
/// <var>pName</var>, in <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field, code)</code>
/// with the count in <code>pViolations</code>, in <method>OcuPilot.Area.OsMgmt.DatabaseRules.Validate</method>'s
/// contract.</p>
/// <p><var>pMode</var> <code>create</code> applies the name's own rules (the look-up only when
/// <var>pCheckTaken</var> is 1) and requires a data server and a directory; <code>update</code> applies
/// the two to whichever of them <var>pArgs</var> carries. An empty directory is
/// <parameter>OcuPilot.Api.DatabaseError.REMOTEDIRECTORYNONE</parameter>, answered before any vendor
/// read; a data server this instance does not define is
/// <parameter>OcuPilot.Api.DatabaseError.SERVERABSENT</parameter>. <var>pFields</var> is
/// accepted for that contract and ignored. A read that cannot be made is an error status, never a
/// pass.</p>
ClassMethod Validate(pName As %String, pArgs As %DynamicObject, Output pViolations, pMode As %String = "create", pCheckTaken As %Boolean = 1, pFields As %List = "", Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pArgs) Set pArgs = {}
        Set tCreates = (pMode = "create")
        If tCreates Do ..NameViolation(pName, .pViolations)
        ; The owner's database-directory rule: an omitted directory is refused before any vendor call.
        If (tCreates || (pArgs.%GetTypeOf(..#FIELDDIRECTORY) '= "unassigned")) && (..Text(pArgs, ..#FIELDDIRECTORY) = "") {
            Do ..Add(.pViolations, ..#FIELDDIRECTORY, ##class(OcuPilot.Api.DatabaseError).#REMOTEDIRECTORYNONE)
            Quit
        }
        If tCreates && (pViolations = 0) && pCheckTaken {
            Set tSC = $ClassMethod(..#DATABASERULES, "Taken", pName, .tTaken)
            If $$$ISERR(tSC) Quit
            If tTaken Do ..Add(.pViolations, ..#FIELDNAME, ##class(OcuPilot.Api.DatabaseError).#NAMETAKEN)
        }
        If tCreates || (pArgs.%GetTypeOf(..#FIELDSERVER) '= "unassigned") {
            Set tServer = ..Text(pArgs, ..#FIELDSERVER)
            Set tSC = $ClassMethod(..PortClass(), "ServerDefined", tServer, .tDefined, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            If 'tDefined Do ..Add(.pViolations, ..#FIELDSERVER, ##class(OcuPilot.Api.DatabaseError).#SERVERABSENT)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><method>Validate</method> over the agent's arguments for <var>pIdValue</var> in mode
/// <var>pMode</var>, the name look-up never (the mint's absence read answers it), as one
/// <var>pProblem</var> naming each field and its published sentence (AD-55). It lists nothing.</p>
ClassMethod Problem(pIdValue As %String, pArgs As %DynamicObject, pMode As %String, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ..Validate(pIdValue, pArgs, .tViolations, pMode, 0, "", .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If $IsObject($Get(tFault)) && (tFault.%Get("reason") '= "") && (tFault.%Get("code") '= ##class(OcuPilot.Api.Error).#INTERNAL) {
            Set pProblem = tFault.%Get("reason")
            Quit $$$OK
        }
        Quit tSC
    }
    For tI = 1:1:$Get(tViolations) {
        Set tField = $List(tViolations(tI), 1)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ tField _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>The name's own violation, or none: <method>OcuPilot.Area.OsMgmt.DatabaseRules.NameViolation</method>,
/// since a remote configuration's name is a <code>Config.Databases</code> name.</p>
ClassMethod NameViolation(pName As %String, Output pViolations)
{
    Do $ClassMethod(..#DATABASERULES, "NameViolation", pName, .pViolations)
}

/// <p>The port every read here goes through: the create tool's own declaration (AD-52).</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#CREATETOOL, "PortClass")
}

/// <p>Answer <code>GET /remote-database/form[?name=&lt;n&gt;]</code>: <code>{requiredFields, rules,
/// servers, listSeconds}</code>, <code>servers</code> the data servers <code>ECP.DataServer</code>
/// <code>LIST</code> answers as <code>[{Name, Status}]</code> and <code>listSeconds</code> the
/// listing's bound. With a name it adds <code>Name</code> and <code>configuration</code>, the update
/// tool's fresh read; a name this instance does not hold is 404
/// <parameter>OcuPilot.Api.DatabaseError.NAMEABSENT</parameter>, and a local configuration 409
/// <parameter>OcuPilot.Api.DatabaseError.LOCAL</parameter>. It lists no data server's databases.</p>
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
        Do tBody.%Set("rules", ..Rules())
        Do tBody.%Set("listSeconds", $ClassMethod(..PortClass(), "ListSeconds"), "number")
        Kill tQuery
        Set tListSC = $ClassMethod(..PortClass(), "Invoke", ..#SERVERENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        If $$$ISERR(tListSC) {
            Set tSC = ##class(OcuPilot.Area.OsMgmt.DatabaseRules).RenderRead(tListSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tServers = []
        If $IsObject($Get(tRows)) && tRows.%IsA("%Library.DynamicArray") {
            Set tIterator = tRows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If '$IsObject(tRow) || (..Text(tRow, "Name") = "") Continue
                Set tServer = {}
                Do tServer.%Set("Name", ..Text(tRow, "Name"), "string")
                Do tServer.%Set("Status", ..Text(tRow, "Status"), "string")
                Do tServers.%Push(tServer)
            }
        }
        Do tBody.%Set("servers", tServers)
        Set tName = $Get(%request.Data("name", 1))
        If tName '= "" {
            Set tReadSC = ##class(OcuPilot.Area.OsMgmt.DatabaseRules).Read(..#UPDATETOOL, tName, .tConfiguration, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ##class(OcuPilot.Area.OsMgmt.DatabaseRules).RenderRead(tReadSC, $Get(tHttp), $Get(tFault))
                Quit
            }
            If ..Text(tConfiguration, ..#FIELDSERVER) = "" {
                Set tSC = ##class(OcuPilot.Api.Error).Render(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.DatabaseError).#REASONLOCAL, ##class(OcuPilot.Api.DatabaseError).#LOCAL)
                Quit
            }
            Do tBody.%Set(..#FIELDNAME, $ZConvert(tName, "U"), "string")
            Do tBody.%Set("configuration", ##class(OcuPilot.Port.DatabasePort).Without(tConfiguration, $ListBuild("DeleteFile")))
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /remote-database/directories?server=&lt;s&gt;</code>: the bounded listing of
/// that data server (<method>OcuPilot.Port.RemoteDatabasePort.Directories</method>), under the form's
/// pairs, as <code>{server, rows: [{Name, Directory}], truncated}</code>. A data server the instance
/// does not define, or one that cannot be listed, is the port's 422 on <code>Server</code>.</p>
ClassMethod HandleDirectories() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tServer = $Get(%request.Data(..#SERVERPARAM, 1))
        Set tPort = ..PortClass()
        Set tReadSC = $ClassMethod(tPort, "ServerDefined", tServer, .tDefined, .tHttp, .tFault)
        If $$$ISOK(tReadSC) && 'tDefined {
            Set tSC = ..RenderViolation(..#FIELDSERVER, ##class(OcuPilot.Api.DatabaseError).#SERVERABSENT)
            Quit
        }
        If $$$ISOK(tReadSC) Set tReadSC = $ClassMethod(tPort, "Directories", tServer, .tRows, .tTruncated, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            Set tSC = ##class(OcuPilot.Area.OsMgmt.DatabaseRules).RenderRead(tReadSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("server", tServer, "string")
        Do tAnswer.%Set("rows", tRows)
        Do tAnswer.%Set("truncated", ''tTruncated, "boolean")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code>: the remote codes of
/// <method>OcuPilot.Api.DatabaseError.ViolationCodes</method> and the name's.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = $ListBuild(##class(OcuPilot.Api.DatabaseError).#NAMEREQUIRED, ##class(OcuPilot.Api.DatabaseError).#NAMESHAPE, ##class(OcuPilot.Api.DatabaseError).#NAMETAKEN, ##class(OcuPilot.Api.DatabaseError).#SERVERABSENT, ##class(OcuPilot.Api.DatabaseError).#SERVERUNREACHABLE, ##class(OcuPilot.Api.DatabaseError).#REMOTEDIRECTORYNONE, ##class(OcuPilot.Api.DatabaseError).#REMOTEDIRECTORYABSENT, ##class(OcuPilot.Api.DatabaseError).#REMOTEDIRECTORYMANAGER)
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tRow = {}
        Do tRow.%Set("field", ##class(OcuPilot.Area.OsMgmt.DatabaseRules).FieldOf(tCode), "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForViolation(tCode), "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>Render one 422 <parameter>OcuPilot.Api.DatabaseError.VALIDATION</parameter> envelope carrying
/// <var>pCode</var> on <var>pField</var>.</p>
ClassMethod RenderViolation(pField As %String, pCode As %String) As %Status [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("field", pField, "string")
    Do tRow.%Set("code", pCode, "string")
    Do tRow.%Set("reason", ##class(OcuPilot.Api.Error).ReasonForViolation(pCode), "string")
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.DatabaseError).#REASONVALIDATION, ##class(OcuPilot.Api.DatabaseError).#VALIDATION, {"violations": [(tRow)]})
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

/// <p><var>pObject</var>'s <var>pField</var> as text: a null or absent field as <code>""</code>.</p>
ClassMethod Text(pObject As %DynamicObject, pField As %String) As %String [ Private ]
{
    If '$IsObject(pObject) Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pObject.%Get(pField)
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
