/// <p>The percent-class access create Save (AD-55, Story 18.10): <code>POST /web-app/pct-access</code> adds one class
/// access entry to a web application through <class>OcuPilot.Screen.Tool.WebAppPctAccessCreate</class>, the tool the
/// agent's confirm resolves. The editor's Add dialog posts here.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request type, the port and
/// the pairs the write needs beyond the screen's. It mints no proposal and takes no confirm token. It runs, in order: the
/// screen's pairs and the tool's (AD-8), a body naming only <code>Name</code>, <code>AllowType</code>, <code>Class</code>
/// and <code>AllowAccess</code>, the target's hold (AD-34), a read of the entry, whose shape checks run before the vendor
/// and which refuses one already held (<code>PCTACCESS.EXISTS</code>), AD-10's prohibited set, and only then the port's
/// write; then the read-back (AD-58).</p>
Class OcuPilot.Area.WebApp.PctAccessSave Extends %RegisteredObject
{

/// <p>The tool class the route resolves the create through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.WebAppPctAccessCreate";

/// <p>The screen whose declared pairs gate this route, and whose entity type and scope the prohibited set's reference
/// carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WebAppPctAccessList";

/// <p>The body keys the route reads.</p>
Parameter NAMEKEY = "Name";

Parameter ALLOWTYPEKEY = "AllowType";

Parameter CLASSKEY = "Class";

Parameter ACCESSKEY = "AllowAccess";

/// <p>The port the write goes through, which is the tool's own declaration (AD-52).</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#CREATETOOL, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>Answer <code>POST /web-app/pct-access</code>: add the entry and answer <code>{name, allowType, class, readBack}</code>
/// with 201 (AD-58).</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tUnexpected = ..UnexpectedKey(tBody)
        If tUnexpected '= "" {
            Set tDetail = {"violations": []}
            Do tDetail.%Get("violations").%Push({"field": (tUnexpected), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)})
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, tDetail)
            Quit
        }
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..Text(tBody, ..#NAMEKEY), ..Text(tBody, ..#ALLOWTYPEKEY), ..Text(tBody, ..#CLASSKEY)))
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(..#CREATETOOL, tId, .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }
        Set tPerformSC = ..Create(tId, tBody, .tHttp, .tFault, .tReadBack)
        Set tSC = ..Answer(tPerformSC, $Get(tHttp), $Get(tFault), tBody, $Get(tReadBack))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release($Get(tHoldKey))
    Quit tSC
}

/// <p>Add the entry <var>pId</var> names, with <var>pBody</var>'s <code>AllowAccess</code>.</p>
/// <p><b>Caller contract:</b> an error status carries <var>pHttpStatus</var> and <var>pFault</var>, and nothing was
/// written. On success <var>pReadBack</var> is the write's read-back (AD-58).</p>
ClassMethod Create(pId As %String, pBody As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Set tSC = $$$OK
    Try {
        Set tClass = ..#CREATETOOL
        If pBody.%GetTypeOf(..#ACCESSKEY) '= "boolean" {
            Set tSC = ..Refused(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#AGENTBADBODY, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, .pHttpStatus, .pFault)
            Quit
        }
        Set tPayload = {}
        Do tPayload.%Set(..#ACCESSKEY, pBody.%Get(..#ACCESSKEY), "boolean")
        ; The port's shape checks run first, on the id, so a malformed entry is refused before the set is asked.
        ; The entry the create would add must be absent (AD-54).
        Kill tQuery
        Set tQuery("name") = pId
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), "STATE", .tQuery, "", .tState, .tStateHttp, .tStateFault)
        If $$$ISERR(tSC) && (+$Get(tStateHttp) '= 404) {
            Set pHttpStatus = $Get(tStateHttp)
            Set pFault = $Get(tStateFault)
            Quit
        }
        If $$$ISOK(tSC) && (+$Get(tStateHttp) = 200) {
            Set tSC = ..Refused(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.PctAccessError).#EXISTS, ##class(OcuPilot.Api.PctAccessError).#REASONEXISTS, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Prohibited(tClass, pId, tPayload, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Kill tQuery
        Set tQuery("name") = pId
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .tWritten, .pHttpStatus, .pFault)
        ; AD-58: the entry read back through the tool's port and compared with what was sent.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pId, tPayload, "", ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Set the refusal <var>pCode</var> with <var>pReason</var> as a fault and an error status (AD-39).</p>
ClassMethod Refused(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    Quit $$$ERROR($$$GeneralError, pCode)
}

/// <p>Ask AD-10's set about the create tool <var>pToolClass</var> would make of <var>pId</var> carrying
/// <var>pPayload</var>; a <code>PROHIBITED.*</code> verdict is an error status with a 403 fault.</p>
ClassMethod Prohibited(pToolClass As %String, pId As %String, pPayload As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pId, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), "[]", .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Render the outcome of <method>Create</method>: a refusal as its own envelope, and success as
/// <code>{name, allowType, class, readBack}</code> at 201 (AD-58).</p>
ClassMethod Answer(pSC As %Status, pHttp As %Integer, pFault As %DynamicObject, pBody As %DynamicObject, pReadBack As %DynamicObject = "") As %Status [ Private ]
{
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tAnswer = {}
    Do tAnswer.%Set("name", ..Text(pBody, ..#NAMEKEY), "string")
    Do tAnswer.%Set("allowType", ..Text(pBody, ..#ALLOWTYPEKEY), "string")
    Do tAnswer.%Set("class", ..Text(pBody, ..#CLASSKEY), "string")
    If $IsObject(pReadBack) Do tAnswer.%Set("readBack", pReadBack)
    Quit ##class(OcuPilot.Api.Response).JSONStatus(201, tAnswer)
}

/// <p>The first body key other than the four this route reads, or <code>""</code>.</p>
ClassMethod UnexpectedKey(pBody As %DynamicObject) As %String [ Private ]
{
    Set tUnexpected = ""
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If (tKey = ..#NAMEKEY) || (tKey = ..#ALLOWTYPEKEY) || (tKey = ..#CLASSKEY) || (tKey = ..#ACCESSKEY) Continue
        Set tUnexpected = tKey
        Quit
    }
    Quit tUnexpected
}

/// <p>A body's string member <var>pName</var>, or <code>""</code>.</p>
ClassMethod Text(pBody As %DynamicObject, pName As %String) As %String [ Private ]
{
    If pBody.%GetTypeOf(pName) '= "string" Quit ""
    Quit pBody.%Get(pName)
}

/// <p>Read the request body into <var>pBody</var>; 0 when it is not a JSON object.</p>
ClassMethod Body(Output pBody As %DynamicObject) As %Boolean [ Private ]
{
    Set pBody = ""
    Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.pBody, .tStage)
    If $$$ISERR(tReadSC) || '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Quit 1
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs, or every pair the create
/// tool's write declares (AD-8), before anything is read or sent.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    Set tPairs = $ClassMethod(..#CREATETOOL, "PrivilegePairs", "", .tResolved)
    If 'tResolved {
        Set pRefused = 1
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the privilege pairs of " _ ..#CREATETOOL _ " could not be read")))
    }
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs(tPairs, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
