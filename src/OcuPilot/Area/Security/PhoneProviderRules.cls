/// <p>The mobile phone providers' rules (AD-39, AD-55, Story 21.10): the one rule set
/// <class>OcuPilot.Screen.Tool.PhoneProviderCreate</class> and <class>OcuPilot.Screen.Tool.PhoneProviderUpdate</class>
/// apply at the mint and the confirm, <class>OcuPilot.Area.Security.PhoneProviderSave</class> applies at the Save and
/// <class>OcuPilot.Port.PhoneProviderPort</class> applies before any vendor call (<method>Check</method>,
/// <method>Problem</method>), and the editor's form read (<method>HandleForm</method>).</p>
/// <p><b>A create requires both fields.</b> Each is 1 to 50 characters with no control character, and the SMS gateway is
/// not checked for any other format, as on the classic page. An update judges the SMS gateway only when it changes it.
/// Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s, from
/// <class>OcuPilot.Api.PhoneProviderError</class>.</p>
Class OcuPilot.Area.Security.PhoneProviderRules Extends OcuPilot.Kernel.Proposal.ScreenSaveRules
{

/// <p>The screen whose declared pairs gate the form read (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.PhoneProviderForm";

/// <p>The class whose parameters carry this rule set's codes and sentences.</p>
Parameter ERRORCLASS = "OcuPilot.Api.PhoneProviderError";

/// <p>The tool whose port the form read asks (AD-52).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.PhoneProviderUpdate";

/// <p>The one setting a provider carries beside its name.</p>
Parameter GATEWAYFIELD = "SMSGateway";

/// <p>Every rule over <var>pBody</var>, in <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field,
/// code)</code> with the count in <code>pViolations</code>.</p>
/// <p>A value that is not text is a shape violation on its field. When <var>pMode</var> is <code>create</code>,
/// <var>pName</var> must be a valid name (<method>IsName</method>) and the SMS gateway must be present and valid. When it
/// is <code>update</code> and <var>pFull</var> is 1, the gateway is judged only where it differs from
/// <var>pFresh</var>'s; with <var>pFull</var> 0 only its shape is. <var>pFresh</var> is <code>""</code> for a create.
/// <var>pPortClass</var> is read by no rule here and is kept for the Save's adapter.</p>
ClassMethod Check(pName As %String, pBody As %DynamicObject, pFresh As %DynamicObject, pMode As %String, pPortClass As %String, Output pViolations, pFull As %Boolean = 1) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pBody) Set pBody = {}
        Set tCreate = (pMode = "create")
        Set tFresh = $Select($IsObject(pFresh): pFresh, 1: {})
        If tCreate && '..IsName(pName) Do ..Add(.pViolations, "Name", ##class(OcuPilot.Api.PhoneProviderError).#NAME)
        Set tType = pBody.%GetTypeOf(..#GATEWAYFIELD)
        If tType = "unassigned" {
            If tCreate Do ..Add(.pViolations, ..#GATEWAYFIELD, ##class(OcuPilot.Api.PhoneProviderError).#GATEWAY)
            Quit
        }
        If tType '= "string" {
            Do ..Add(.pViolations, ..#GATEWAYFIELD, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            Quit
        }
        Set tValue = pBody.%Get(..#GATEWAYFIELD)
        If 'tCreate && ('pFull || (tValue = ..Text(tFresh, ..#GATEWAYFIELD))) Quit
        If '..IsGateway(tValue) Do ..Add(.pViolations, ..#GATEWAYFIELD, ##class(OcuPilot.Api.PhoneProviderError).#GATEWAY)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pValue</var> is 1 to <var>pMax</var> characters with no control character.</p>
ClassMethod IsBounded(pValue As %String, pMax As %Integer) As %Boolean
{
    If ($Length(pValue) < 1) || ($Length(pValue) > pMax) Quit 0
    Quit $ZStrip(pValue, "*C") = pValue
}

/// <p>Whether <var>pName</var> is a provider name: 1 to 50 characters with no control character.</p>
ClassMethod IsName(pName As %String) As %Boolean
{
    Quit ..IsBounded(pName, ##class(OcuPilot.Api.PhoneProviderError).#NAMEMAX)
}

/// <p>Whether <var>pGateway</var> is an SMS gateway: 1 to 50 characters with no control character.</p>
ClassMethod IsGateway(pGateway As %String) As %Boolean
{
    Quit ..IsBounded(pGateway, ##class(OcuPilot.Api.PhoneProviderError).#GATEWAYMAX)
}

/// <p>Whether a provider exists under the name <var>pName</var>, in <var>pTaken</var>, read through
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

/// <p>Answer <code>GET /phone-provider/form[?id=&lt;name&gt;]</code>: <code>{row}</code>. With an id, <code>row</code>
/// is <code>Name</code> and <code>SMSGateway</code> from the update tool's fresh <code>GET</code>; an id the instance
/// does not hold is 404 <code>PORT.NOTFOUND</code>. Without one it is a new provider's, both fields empty.</p>
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
            Do tRow.%Set(..#GATEWAYFIELD, ..Text(tFresh, ..#GATEWAYFIELD), "string")
        }
        Set tBody = {}
        Do tBody.%Set("row", tRow)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Set into <var>pRow</var> a new provider's fields: both empty.</p>
ClassMethod DefaultRow(pRow As %DynamicObject)
{
    Do pRow.%Set("Name", "", "string")
    Do pRow.%Set(..#GATEWAYFIELD, "", "string")
}

}
