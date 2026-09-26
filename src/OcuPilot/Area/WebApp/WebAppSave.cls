/// <p>The web application editor's Save (AD-55): <code>PUT /web-applications/:id</code> changes one
/// application through <class>OcuPilot.Screen.Tool.WebAppUpdate</class>, the tool the agent's
/// <code>webapp.list.update</code> proposal is confirmed through.</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request
/// types, the port and the settable fields. It mints no proposal and takes no confirm token. In
/// order: the caller's pairs (AD-8), the fresh read (an absent application answers 404 and nothing
/// is sent), a check that the body carries only the tool's twenty-five settings, the edit's rules
/// over the fields the body changes, the merge over the fresh read (AD-4), AD-10's prohibited set
/// over the merged payload, and only then the port.</p>
/// <p><b>It carries no role</b> (AD-56 (ii)): <code>MatchRoles</code>, <code>Path</code>,
/// <code>WSGIAppLocation</code> and every other key outside the twenty-five are refused 400; roles
/// change only through the role actions' delta.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.WebApp.WebAppSave Extends %RegisteredObject
{

/// <p>The tool class both callers resolve the write through (AD-55).</p>
Parameter TOOLCLASS = "OcuPilot.Screen.Tool.WebAppUpdate";

/// <p>The screen whose declared pairs gate this route, and whose entity type and scope the
/// prohibited set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WebAppForm";

/// <p>The input property that names the target.</p>
Parameter IDARGUMENT = "Name";

/// <p>The rules class the Save applies.</p>
Parameter RULES = "OcuPilot.Area.WebApp.Create";

/// <p>The port the fresh read and the write go through, which is the tool's own declaration
/// (AD-52). Overridable so a fixture can observe what was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#TOOLCLASS, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched. Overridable for the reason
/// <method>PortClass</method> is; production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>Answer <code>PUT /web-applications/:id</code>: change the application <var>pId</var> -- one
/// path segment, decoded once here (AD-13) -- from the body's fields, and answer
/// <code>{name, readBack}</code> with 200, <code>readBack</code> the application read back and
/// compared with what was sent (AD-58). A key outside the twenty-five is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter> naming every such key; a broken rule
/// is one 422 <parameter>OcuPilot.Api.Error.WEBAPPVALIDATION</parameter> envelope; an application the
/// instance does not hold is 404 <parameter>OcuPilot.Api.Error.WEBAPPNAMEABSENT</parameter>.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) || '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tName = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tPerformSC = ..Update(tName, tBody, .tHttp, .tFault, .tViolations, .tReadBack)
        Set tBody = ""
        If $Get(tViolations) > 0 {
            Set tSC = ##class(OcuPilot.Area.WebApp.Create).RenderViolations(.tViolations)
            Quit
        }
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) && '$IsObject($Get(tFault)) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONWEBAPPNAMEABSENT, ##class(OcuPilot.Api.Error).#WEBAPPNAMEABSENT)
            Quit
        }
        If $$$ISERR(tPerformSC) {
            If '$IsObject($Get(tFault)) || (tFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tPerformSC))
                Quit
            }
            Set tSC = ##class(OcuPilot.Api.Error).Render($Select(+$Get(tHttp): +tHttp, 1: 500), tFault.error, tFault.reason, tFault.code, tFault.%Get("detail"))
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("name", tName, "string")
        If $IsObject($Get(tReadBack)) Do tAnswer.%Set("readBack", tReadBack)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Change the application <var>pName</var> by the fields <var>pArgs</var> sends, merged over a
/// fresh read, so a field the caller did not send keeps the instance's value and the body is the
/// complete set (AD-4).</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array
/// (<code>pViolations(n) = $ListBuild(field, code)</code>, count in <code>pViolations</code>); a
/// non-zero count means nothing was written. Otherwise an error status carries
/// <var>pHttpStatus</var> and <var>pFault</var>: 404 with no fault for an application the instance
/// does not hold, 400 for a key outside the twenty-five, 403 for a prohibited change, and the
/// port's own for a vendor refusal. Nothing is sent on any of them but the last. On success
/// <var>pReadBack</var> is the write's read-back (AD-58); it is <code>""</code> otherwise.</p>
ClassMethod Update(pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#TOOLCLASS
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) {
            If +pHttpStatus = 404 Set pFault = ""
            Quit
        }
        If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 404
            Set pFault = ""
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#WEBAPPNAMEABSENT)
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""

        ; AD-56: the Save's fields are the tool's twenty-five settings; MatchRoles and every path
        ; are refused with the rest, each named.
        Set tAllowed = $ClassMethod(tClass, "PermittedFields")
        Set tRows = []
        Set tIterator = pArgs.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If $ListFind(tAllowed, tKey) Continue
            Do tRows.%Push({"field": (tKey), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)})
        }
        Set tValue = ""
        If tRows.%Size() > 0 {
            Set pHttpStatus = 400
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)
            Do pFault.%Set("detail", {"violations": (tRows)})
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
            Quit
        }

        Set tChanged = $ClassMethod(..#RULES, "Changed", pArgs, tFresh, ..#IDARGUMENT)
        Set tSC = $ClassMethod(..#RULES, "Validate", pName, tChanged, .pViolations, 0, "update", tFresh)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(tFresh, tChanged, ..#IDARGUMENT, tAllowed, .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the edit's payload could not be merged after its rules passed: " _ tProblem)
            Quit
        }

        Set tSC = ..Prohibited(tClass, pName, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .tAnswer, .pHttpStatus, .pFault)
        ; AD-58: the application read back through the tool's port and compared with what was sent.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pName, tPayload, tFresh, ..PortClass(), $Get(tAnswer), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Ask AD-10's set about the write <var>pToolClass</var> would make to <var>pName</var> carrying
/// <var>pPayload</var> and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an error status
/// with a 403 fault.</p>
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

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs, or
/// the pair the tool's write declares beyond them (AD-8), before anything is read or sent:
/// <var>pRefused</var> 1 means the envelope is written and the handler writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    Set tPair = $ListBuild($Parameter(..#TOOLCLASS, "WRITERESOURCE"), $Parameter(..#TOOLCLASS, "WRITEPERMISSION"))
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs($ListBuild(tPair), .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
