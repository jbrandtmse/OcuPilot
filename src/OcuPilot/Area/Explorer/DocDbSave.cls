/// <p>Document databases' create Save (AD-55, Story 19.17): <code>POST /explorer/docdb</code> creates one
/// document database in the request's namespace through
/// <class>OcuPilot.Screen.Tool.ExplorerDocDbCreate</class>, the tool the agent's confirm resolves.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request type,
/// the port, the payload composition and the pairs the write needs beyond the screen's. It mints no
/// proposal and takes no confirm token. It runs, in order: the screen's pairs and the tool's (AD-8), a
/// body naming nothing but <code>Name</code>, the name's rules, AD-10's prohibited set, the composed
/// payload, and only then the port's create, whose own gate repeats the pairs and adds the package
/// mapping and the DocDB service before any vendor call; then the read-back (AD-58).</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and <method>ProhibitedClass</method>.
/// Production overrides neither.</p>
Class OcuPilot.Area.Explorer.DocDbSave Extends %RegisteredObject
{

/// <p>The tool class both callers resolve the create through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.ExplorerDocDbCreate";

/// <p>The screen whose declared pairs gate this route, and whose entity type and scope the prohibited
/// set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerDocDbList";

/// <p>The one body key the route reads: the new database's name.</p>
Parameter IDARGUMENT = "Name";

/// <p>The port the write goes through, which is the tool's own declaration (AD-52). Overridable so a
/// fixture can observe what was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#CREATETOOL, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched. Overridable for the reason
/// <method>PortClass</method> is; production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>Answer <code>POST /explorer/docdb</code>: create the database the body's <code>Name</code> names
/// and answer <code>{name, readBack}</code> with 201 (AD-58). A body key other than <code>Name</code> is
/// 400 <code>PORT.FIELD.UNEXPECTED</code>; a name its rules refuse is 422
/// <parameter>OcuPilot.Api.DocDbError.NAMEINVALID</parameter> on <code>Name</code>; any other refusal is
/// the prohibited set's or the port's own envelope.</p>
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
        Set tName = ""
        If tBody.%GetTypeOf(..#IDARGUMENT) = "string" Set tName = tBody.%Get(..#IDARGUMENT)
        Set tPerformSC = ..Create(tName, .tHttp, .tFault, .tReadBack)
        Set tSC = ..Answer(tPerformSC, $Get(tHttp), $Get(tFault), tName, $Get(tReadBack))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Create the database <var>pName</var> in the request's namespace.</p>
/// <p><b>Caller contract:</b> an error status carries <var>pHttpStatus</var> and <var>pFault</var>, and
/// nothing was created. On success <var>pReadBack</var> is the write's read-back (AD-58).</p>
ClassMethod Create(pName As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Set tSC = $$$OK
    Try {
        Set tClass = ..#CREATETOOL
        If ##class(OcuPilot.Port.DocDbPort).NameProblem(pName) '= "" {
            Set tSC = ..NameRefusal(##class(OcuPilot.Api.DocDbError).#NAMEINVALID, .pHttpStatus, .pFault)
            Quit
        }
        Set tArgs = {}
        Do tArgs.%Set(..#IDARGUMENT, pName, "string")
        ; AD-10, AD-55. The set the confirm asks, before the payload and the port, over the name.
        Set tSC = ..Prohibited(tClass, pName, tArgs, [], .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tSC = $ClassMethod(tClass, "ComposeCreate", tArgs, ..#IDARGUMENT, $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the database's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Do ##class(OcuPilot.Kernel.Proposal.Operation).Query(tClass, $ClassMethod(tClass, "IdParam"), pName, tPayload.%ToJSON(), .tQuery)
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .tWritten, .pHttpStatus, .pFault)
        ; AD-58: the database read back through the tool's port and compared with what was sent.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pName, tPayload, "", ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ask AD-10's set about the create tool <var>pToolClass</var> would make of <var>pName</var>
/// carrying <var>pPayload</var> and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an error
/// status with a 403 fault.</p>
ClassMethod Prohibited(pToolClass As %String, pName As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pName, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>The 422 refusal <var>pCode</var> on <code>Name</code>, as the port words it: the envelope carries
/// the code and its sentence, and <code>detail.violations</code> the one violation (AD-39).</p>
ClassMethod NameRefusal(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tReason = ##class(OcuPilot.Api.DocDbError).ReasonFor(pCode)
    Set pHttpStatus = 422
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pCode, tReason)
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push({"field": (..#IDARGUMENT), "code": (pCode), "reason": (tReason)})
    Do pFault.%Set("detail", tDetail)
    Quit $$$ERROR($$$GeneralError, pCode)
}

/// <p>Render the outcome of <method>Create</method>: a refusal as its own envelope, and success as
/// <code>{name, readBack}</code> at 201 (AD-58).</p>
ClassMethod Answer(pSC As %Status, pHttp As %Integer, pFault As %DynamicObject, pName As %String, pReadBack As %DynamicObject = "") As %Status [ Private ]
{
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tAnswer = {}
    Do tAnswer.%Set("name", pName, "string")
    If $IsObject(pReadBack) Do tAnswer.%Set("readBack", pReadBack)
    Quit ##class(OcuPilot.Api.Response).JSONStatus(201, tAnswer)
}

/// <p>The first key of <var>pBody</var> other than <parameter>IDARGUMENT</parameter>, or
/// <code>""</code>: a create takes the name alone, never a document type or a resource.</p>
ClassMethod UnexpectedKey(pBody As %DynamicObject) As %String [ Private ]
{
    Set tUnexpected = ""
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If tKey = ..#IDARGUMENT Continue
        Set tUnexpected = tKey
        Quit
    }
    Quit tUnexpected
}

/// <p>Read the request body into <var>pBody</var>; 0 when it is not a JSON object.</p>
ClassMethod Body(Output pBody As %DynamicObject) As %Boolean [ Private ]
{
    Set pBody = ""
    Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.pBody, .tStage)
    If $$$ISERR(tReadSC) || '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Quit 1
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs, or
/// every pair the create tool's write declares (AD-8), before anything is read or sent:
/// <var>pRefused</var> 1 means the envelope is written and the handler writes nothing else.</p>
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
