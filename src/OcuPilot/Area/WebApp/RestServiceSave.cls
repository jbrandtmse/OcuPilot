/// <p>The REST API explorer's create Save (AD-55, Story 18.34): <code>POST /rest-service</code> builds one spec-based
/// REST service in the request's namespace from an OpenAPI 2.0 document through
/// <class>OcuPilot.Screen.Tool.RestServiceCreate</class>, the tool the agent's confirm resolves, and through
/// <class>OcuPilot.Port.MgmntPort</class>'s <code>Service</code> endpoint.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request types, the port, the
/// payload composition and the pairs the write needs beyond the screen's. It mints no proposal and takes no confirm
/// token. It meets the port's rules and never the agent's: the agent's routines-database check
/// (<method>OcuPilot.Screen.Tool.RestServiceCreate.AgentProblems</method>) and the card's width are the agent's alone
/// (AD-53), so a person may build where the agent may not.</p>
/// <p>It runs, in order: the screen's pairs and the tool's (AD-8); a body naming nothing but <code>Name</code> and
/// <code>Document</code>; the per-target hold (AD-34); the document text parsed on the instance into an object, which is
/// all the port and the vendor ever receive (AD-21); the port's name and document rules; the taken-name check; AD-10's
/// prohibited set; the port's create; and the read-back (AD-58).</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and <method>ProhibitedClass</method>. Production
/// overrides neither.</p>
Class OcuPilot.Area.WebApp.RestServiceSave Extends %RegisteredObject
{

/// <p>The tool class both callers resolve the create through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.RestServiceCreate";

/// <p>The screen whose declared pairs gate this route, and whose entity type and scope the prohibited set's reference
/// carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RestApiList";

/// <p>The port the write goes through, which is the tool's own declaration (AD-52). Overridable so a fixture can observe
/// what was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#CREATETOOL, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched. Overridable for the reason <method>PortClass</method> is;
/// production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>Answer <code>POST /rest-service</code>: build the service the body's <code>Name</code> names from the text its
/// <code>Document</code> carries, and answer <code>{name, readBack}</code> with 201 (AD-58). A body that is no JSON object
/// is 400 <code>AGENT.BADBODY</code>; a key other than <code>Name</code> and <code>Document</code> is 400
/// <code>PORT.FIELD.UNEXPECTED</code>; a rule the port states, a taken name or a document the management API cannot
/// build is 422 with its <code>RESTSERVICE.*</code> code on the field; any other refusal is the prohibited set's or the
/// port's own envelope.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Set tHoldKey = ""
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
        If tBody.%GetTypeOf(..IdArgument()) = "string" Set tName = tBody.%Get(..IdArgument())
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(..#CREATETOOL, tName, .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }
        Set tPerformSC = ..Create(tName, tBody, .tHttp, .tFault, .tReadBack)
        Set tSC = ..Answer(tPerformSC, $Get(tHttp), $Get(tFault), tName, $Get(tReadBack))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release(tHoldKey)
    Quit tSC
}

/// <p>Build the service <var>pName</var> in the request's namespace from the document text <var>pBody</var> carries.</p>
/// <p><b>Caller contract:</b> an error status carries <var>pHttpStatus</var> and <var>pFault</var>, and nothing was built
/// except by a build the management API refused, which leaves no class. On success <var>pReadBack</var> is the write's
/// read-back (AD-58). The caller holds the target (AD-34).</p>
ClassMethod Create(pName As %String, pBody As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Set tSC = $$$OK
    Try {
        Set tClass = ..#CREATETOOL
        Set tDocumentField = $Parameter(tClass, "DOCUMENTFIELD")
        Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tDocument = ..ParsedDocument(pBody)
        Set tCarrier = {}
        If $IsObject(tDocument) Do tCarrier.%Set(tDocumentField, tDocument)
        If ##class(OcuPilot.Port.MgmntPort).NameProblem(pName) '= "" {
            Set tSC = ..Violation(##class(OcuPilot.Api.RestServiceError).#NAME, .pHttpStatus, .pFault)
            Quit
        }
        If ##class(OcuPilot.Port.MgmntPort).DocumentProblem(tCarrier) '= "" {
            Set tSC = ..Violation(##class(OcuPilot.Api.RestServiceError).#DOCUMENT, .pHttpStatus, .pFault)
            Quit
        }

        ; The fresh read of a create: the name is free only where the state read finds nothing (AD-54).
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tQuery(##class(OcuPilot.Port.MgmntPort).#NAMESPACEKEY) = tNamespace
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tState, .pHttpStatus, .pFault)
        If $$$ISOK(tSC) {
            Set pHttpStatus = 0
            Set pFault = ""
            Set tSC = ..Violation(##class(OcuPilot.Api.RestServiceError).#TAKEN, .pHttpStatus, .pFault)
            Quit
        }
        If +$Get(pHttpStatus) '= 404 Quit
        Set pHttpStatus = 0
        Set pFault = ""

        Set tArgs = {}
        Do tArgs.%Set($ClassMethod(tClass, "IdArgument"), pName, "string")
        Do tArgs.%Set(tDocumentField, tDocument)
        Do tArgs.%Set($Parameter(tClass, "NAMESPACEFIELD"), tNamespace, "string")
        Set tSC = $ClassMethod(tClass, "ComposeCreate", tArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the service's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        ; AD-10, AD-55. The set the confirm asks, before the port, over the package.
        Set tSC = ..Prohibited(tClass, pName, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do ##class(OcuPilot.Kernel.Proposal.Operation).Query(tClass, $ClassMethod(tClass, "IdParam"), pName, tPayload.%ToJSON(), .tQuery)
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .tWritten, .pHttpStatus, .pFault)
        ; AD-58: the service read back through the tool's port and compared with what was sent.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pName, tPayload, "", ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The document <var>pBody</var> carries as an object, or <code>""</code> when its <code>Document</code> is not a
/// string, is not JSON, or does not parse to an object. The text is parsed here and nowhere else (AD-21).</p>
ClassMethod ParsedDocument(pBody As %DynamicObject) As %DynamicObject [ Private ]
{
    Set tDocument = ""
    Try {
        Set tField = $Parameter(..#CREATETOOL, "DOCUMENTFIELD")
        If pBody.%GetTypeOf(tField) '= "string" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pBody.%Get(tField))
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicObject") Set tDocument = tParsed
    } Catch {
        Set tDocument = ""
    }
    Quit tDocument
}

/// <p>Ask AD-10's set about the create tool <var>pToolClass</var> would make of <var>pName</var> carrying
/// <var>pPayload</var> and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an error status with a 403
/// fault.</p>
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

/// <p>The 422 refusal <var>pCode</var> on its field, as the port words it: the envelope carries the code and its
/// sentence, and <code>detail.violations</code> the one violation (AD-39).</p>
ClassMethod Violation(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tReason = ##class(OcuPilot.Api.RestServiceError).ReasonFor(pCode)
    Set pHttpStatus = 422
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pCode, tReason)
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push({"field": (##class(OcuPilot.Api.RestServiceError).FieldOf(pCode)), "code": (pCode), "reason": (tReason)})
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

/// <p>The body key that names the service: the tool's identifying argument.</p>
ClassMethod IdArgument() As %String [ Private ]
{
    Quit $ClassMethod(..#CREATETOOL, "IdArgument")
}

/// <p>The first key of <var>pBody</var> other than the name and the document, or <code>""</code>: a create takes those
/// two alone, never a namespace, a URL or a server path.</p>
ClassMethod UnexpectedKey(pBody As %DynamicObject) As %String [ Private ]
{
    Set tUnexpected = ""
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If (tKey = ..IdArgument()) || (tKey = $Parameter(..#CREATETOOL, "DOCUMENTFIELD")) Continue
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

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs, or every pair the create
/// tool's write declares -- its <code>PrivilegePairs</code> and its <code>ArgumentPairs</code> for the request's
/// namespace (AD-8) -- before anything is read or sent: <var>pRefused</var> 1 means the envelope is written and the
/// handler writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    Set tPairs = $ClassMethod(..#CREATETOOL, "PrivilegePairs", "", .tResolved)
    Set tArgumentPairs = $ClassMethod(..#CREATETOOL, "ArgumentPairs", "", {}, .tArgumentsResolved)
    If 'tResolved || 'tArgumentsResolved {
        Set pRefused = 1
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the privilege pairs of " _ ..#CREATETOOL _ " could not be read")))
    }
    For tI = 1:1:$ListLength(tArgumentPairs) {
        If '$ListFind(tPairs, $List(tArgumentPairs, tI)) Set tPairs = tPairs _ $ListBuild($List(tArgumentPairs, tI))
    }
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs(tPairs, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
