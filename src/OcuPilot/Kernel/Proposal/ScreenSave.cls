/// <p>The shared shape of a screen editor's Save against one instance object (AD-55, AD-53): <code>POST</code> creates
/// through the create tool and <code>PUT</code> changes through the update tool, the tools the agent's mint and confirm
/// read. A concrete Save names its two tools, its screen and its rules in <parameter>CREATETOOL</parameter>,
/// <parameter>UPDATETOOL</parameter>, <parameter>DESCRIPTORCLASS</parameter> and <parameter>RULES</parameter>, and
/// answers its identity, its rules' argument lists and its answer body in the hooks below; every step the two callers
/// share is this class's.</p>
/// <p>Each Save runs, in this order: the caller's pairs (AD-8); the body; the target's identity; the per-target lock
/// (AD-34); the rules over the arguments (<method>RulesCheck</method>); for a create, whether the target is taken
/// (<method>RulesTaken</method>), and for an edit the fresh read, the merge and the rules over what it would send;
/// AD-10's prohibited set, after the state read and before the port write; the write; and the read-back (AD-58), with
/// the lock kept through the answer. A merge whose diff has no row sends nothing. A body key the tool does not admit is
/// 400 <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>. No proposal is minted, and neither the enforced
/// read-only state nor the kill switch is read (AD-53).</p>
/// <p>Every port call goes through <method>PortClass</method> and every rule through <parameter>RULES</parameter>, whose
/// class extends <class>OcuPilot.Kernel.Proposal.ScreenSaveRules</class>. Seams a subclass may override:
/// <method>PortClass</method> and <method>ProhibitedClass</method>; production overrides neither.</p>
Class OcuPilot.Kernel.Proposal.ScreenSave Extends %RegisteredObject [ Abstract ]
{

/// <p>The write tools the create and the update resolve their endpoint, request types, settable fields and port from.</p>
Parameter CREATETOOL;

Parameter UPDATETOOL;

/// <p>The screen whose declared pairs gate these routes, and whose entity type and scope the prohibited set's
/// reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS;

/// <p>The rules class: a subclass of <class>OcuPilot.Kernel.Proposal.ScreenSaveRules</class> whose
/// <code>Check</code> and <code>Taken</code> the adapters <method>RulesCheck</method> and <method>RulesTaken</method>
/// call, and whose <parameter>OcuPilot.Kernel.Proposal.ScreenSaveRules.ERRORCLASS</parameter> names the violation
/// codes.</p>
Parameter RULES;

/// <p>The port the writes and the edit's fresh read go through, the tools' own declaration (AD-52).
/// Overridable so a fixture can observe what was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#UPDATETOOL, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched. Overridable for the reason <method>PortClass</method>
/// is; production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>The body members that identify a create's target and are not settings, as a <class>%List</class>:
/// <method>CallerFields</method> removes each.</p>
ClassMethod IdentityMembers() As %List
{
    Quit ""
}

/// <p>Read a create's identity from <var>pBody</var>: its target's id, the one the mint names, in
/// <var>pId</var>, and the parts the rules' adapters take, as a <class>%List</class>, in <var>pParts</var>. An
/// identifying member that is neither absent nor of the type it must have is added to <var>pShape</var> as a
/// <code>PORT.FIELDSHAPE</code> violation (<method>Add</method>), and the handler answers it before taking the lock.</p>
ClassMethod CreateIdentity(pBody As %DynamicObject, Output pId As %String, Output pParts As %List, ByRef pShape)
{
    Set pId = ""
    Set pParts = ""
}

/// <p>Read an edit's identity from the decoded path segment <var>pDecoded</var>: the target's id in
/// <var>pId</var> and its parts in <var>pParts</var>. Answers 0 when the segment names no whole target, which the
/// handler answers 404 <code>PORT.NOTFOUND</code> before taking the lock. The default takes the segment as the id.</p>
ClassMethod UpdateIdentity(pDecoded As %String, Output pId As %String, Output pParts As %List) As %Boolean
{
    Set pId = pDecoded
    Set pParts = $ListBuild(pDecoded)
    Quit 1
}

/// <p>The arguments an edit passes on: the body without its identifying members, which an edit never changes. A
/// subclass whose edit refuses an identifying member as an unexpected key passes the body as it is.</p>
ClassMethod UpdateArguments(pBody As %DynamicObject) As %DynamicObject
{
    Quit ..CallerFields(pBody)
}

/// <p>The body keys this Save admits for the tool <var>pToolClass</var>, as a <class>%List</class>: the tool's
/// <method>OcuPilot.Screen.Tool.Write.SettableFields</method> by default. A subclass whose tool settles more than its
/// form edits answers the narrower list.</p>
ClassMethod SaveFields(pToolClass As %String) As %List
{
    Quit $ClassMethod(pToolClass, "SettableFields")
}

/// <p>The rules' <code>Check</code> over <var>pBody</var>, in <var>pViolations</var> (the violation array,
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in <code>pViolations</code>). <var>pMode</var> is
/// <code>create</code>, with the identity's <var>pParts</var>, or <code>update</code>, where <var>pParts</var> is empty;
/// <var>pFresh</var> is the read an edit merged over, and <code>""</code> before it; <var>pFull</var> 0 judges only what
/// needs no read.</p>
ClassMethod RulesCheck(pMode As %String, pParts As %List, pBody As %DynamicObject, pFresh As %DynamicObject, pFull As %Boolean, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Quit $$$OK
}

/// <p>Whether the create's target <var>pId</var>, of identity <var>pParts</var>, already exists, in
/// <var>pTaken</var>: the rules' <code>Taken</code>, read through <method>PortClass</method> as the caller.</p>
ClassMethod RulesTaken(pParts As %List, pId As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Quit $$$OK
}

/// <p>The member a taken target's violation names.</p>
ClassMethod TakenField() As %String
{
    Quit "Name"
}

/// <p>What the target is called in the status of a payload the tool could not compose after the rules passed.</p>
ClassMethod Subject() As %String
{
    Quit "record"
}

/// <p>Merge the edit <var>pArgs</var> over the fresh read <var>pFresh</var> as the tool's own merge does
/// (<method>OcuPilot.Screen.Tool.Write.MergeUpdate</method>), so the payload is the complete set the read answered
/// (AD-4), with the diff and the count of unchanged fields. When the merge reports a problem, the rules' <code>Check</code>
/// over <var>pArgs</var> and <var>pFresh</var> runs, and a broken rule is in <var>pViolations</var> and is what the Save
/// answers; otherwise the problem is a 400.</p>
ClassMethod Merge(pToolClass As %String, pFresh As %DynamicObject, pArgs As %DynamicObject, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set pProblem = ""
    Set tSC = $ClassMethod(pToolClass, "MergeUpdate", pFresh, pArgs, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem = "") Quit tSC
    Quit ..RulesCheck("update", "", pArgs, pFresh, 1, .pViolations)
}

/// <p>Whether the rules judge the merged payload an edit would send, over the fresh read, before AD-10's set.</p>
ClassMethod CheckMerged() As %Boolean
{
    Quit 0
}

/// <p>The effect an edit's change carries over the fresh read <var>pFresh</var>, in <var>pConsequence</var>, asked
/// after AD-10's set and answered beside the write's own answer. None by default.</p>
ClassMethod Consequence(pId As %String, pPayload As %DynamicObject, pFresh As %DynamicObject, Output pConsequence As %String)
{
    Set pConsequence = ""
}

/// <p>The members of a successful answer that identify the target, as one <class>%DynamicObject</class>: its
/// <code>id</code> in its canonical spelling by default. <var>pId</var> is the target's id and <var>pParts</var> its
/// identity.</p>
ClassMethod AnswerBody(pId As %String, pParts As %List) As %DynamicObject
{
    Set tAnswer = {}
    Do tAnswer.%Set("id", ##class(OcuPilot.Kernel.EntityRef).NormalizedId($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), pId), "string")
    Quit tAnswer
}

/// <p>Answer <code>POST</code>: create one target from the body and answer its identity and <code>readBack</code> with
/// 201 (AD-58). A broken rule is one 422 envelope carrying every violation.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Set tHoldKey = ""
    Try {
        Set tGateSC = ..Gate(.tRefused, ..#CREATETOOL)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Kill tShape
        Set tShape = 0
        Do ..CreateIdentity(tBody, .tId, .tParts, .tShape)
        If tShape > 0 {
            Set tSC = $ClassMethod(..#RULES, "RenderViolations", .tShape)
            Quit
        }
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(..#CREATETOOL, tId, .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }
        Set tPerformSC = ..Create(tId, tParts, ..CallerFields(tBody), .tHttp, .tFault, .tViolations, .tReadBack)
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, tId, tParts, $Get(tReadBack))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release(tHoldKey)
    Quit tSC
}

/// <p>Answer <code>PUT</code>: change the target <var>pId</var> -- one path segment, decoded once here (AD-13) -- from
/// the body's settings, merged over a fresh read (AD-4), and answer its identity and <code>readBack</code> with 200,
/// with <code>consequence</code> when the change carries one, or its identity alone when nothing changes. A target the
/// instance does not define is 404 <code>PORT.NOTFOUND</code>.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Set tHoldKey = ""
    Try {
        Set tGateSC = ..Gate(.tRefused, ..#UPDATETOOL)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        If '..UpdateIdentity(##class(OcuPilot.Kernel.EntityId).Decode(pId), .tId, .tParts) {
            Set tSC = $ClassMethod(..#RULES, "RenderRead", $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND), 404, "")
            Quit
        }
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(..#UPDATETOOL, tId, .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }
        Set tPerformSC = ..Update(tId, ..UpdateArguments(tBody), .tHttp, .tFault, .tViolations, .tReadBack, .tConsequence)
        If $$$ISERR(tPerformSC) && (+$Get(tViolations) = 0) && (+$Get(tHttp) = 404) {
            Set tSC = $ClassMethod(..#RULES, "RenderRead", tPerformSC, 404, $Get(tFault))
            Quit
        }
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, tId, tParts, $Get(tReadBack), $Get(tConsequence))
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release(tHoldKey)
    Quit tSC
}

/// <p>Create the target <var>pId</var>, of identity <var>pParts</var>, from the settings <var>pArgs</var> supplies,
/// composed as the create tool composes them.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array (<code>pViolations(n) =
/// $ListBuild(field, code)</code>, count in <code>pViolations</code>); a non-zero count means nothing was written.
/// Otherwise an error status carries <var>pHttpStatus</var> and <var>pFault</var>. On success <var>pReadBack</var> is
/// the write's read-back (AD-58).</p>
ClassMethod Create(pId As %String, pParts As %List, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#CREATETOOL
        Set tSC = ..Unexpected(tClass, pArgs, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tSC = ..RulesCheck("create", pParts, pArgs, "", 1, .pViolations)
        If $$$ISERR(tSC) Quit
        If pViolations = 0 {
            Set tSC = ..RulesTaken(pParts, pId, .tTaken)
            If $$$ISERR(tSC) Quit
            If tTaken Do ..Add(.pViolations, ..TakenField(), $Parameter($Parameter(..#RULES, "ERRORCLASS"), "TAKEN"))
        }
        If pViolations > 0 Quit
        Set tSC = $ClassMethod(tClass, "ComposeCreate", pArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the " _ ..Subject() _ "'s payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Set tSC = ..Prohibited(tClass, pId, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, pId, tPayload, .pHttpStatus, .pFault, .tWritten)
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pId, tPayload, "", ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Change the target <var>pId</var> by the settings <var>pArgs</var> sends, merged over a fresh read by
/// <method>Merge</method>. Nothing is sent when no setting changed. <var>pConsequence</var> is the effect the change
/// carries (<method>Consequence</method>).</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s. A target the instance does not define is an error status
/// with <var>pHttpStatus</var> 404 and nothing sent; a key the tool does not admit is an error status with
/// <var>pHttpStatus</var> 400.</p>
ClassMethod Update(pId As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject, Output pConsequence As %String) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Set pConsequence = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        Set tSC = ..Unexpected(tClass, pArgs, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tSC = ..RulesCheck("update", "", pArgs, "", 0, .pViolations)
        If $$$ISERR(tSC) || (pViolations > 0) Quit
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pId
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""
        Set tSC = ..Merge(tClass, tFresh, pArgs, .tPayload, .tDiff, .tUnchanged, .tProblem, .pViolations)
        If $$$ISERR(tSC) || (pViolations > 0) Quit
        If tProblem '= "" {
            Set pHttpStatus = 400
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS)
            Do pFault.%Set("detail", {"problem": (tProblem)})
            Set tSC = $$$ERROR($$$GeneralError, tProblem)
            Quit
        }
        If tDiff.%Size() = 0 Quit
        If ..CheckMerged() {
            Set tSC = ..RulesCheck("update", "", tPayload, tFresh, 1, .pViolations)
            If $$$ISERR(tSC) || (pViolations > 0) Quit
        }
        Set tSC = ..Prohibited(tClass, pId, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do ..Consequence(pId, tPayload, tFresh, .pConsequence)
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tSC = ..Send(tClass, pId, tPayload, .pHttpStatus, .pFault, .tWritten)
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, pId, tPayload, tFresh, ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Refuse 400 <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter> when <var>pArgs</var> carries a
/// key <var>pToolClass</var> does not settle (<method>SaveFields</method>), before anything is read or sent.</p>
ClassMethod Unexpected(pToolClass As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tAllowed = ..SaveFields(pToolClass)
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $ListFind(tAllowed, tKey) Continue
        Set pHttpStatus = 400
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)
        Set tDetail = {"violations": []}
        Do tDetail.%Get("violations").%Push({"field": (tKey), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)})
        Do pFault.%Set("detail", tDetail)
        Quit
    }
    If pHttpStatus = 400 Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
    Quit $$$OK
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make to <var>pId</var>; a
/// <code>PROHIBITED.*</code> verdict is an error status with a 403 fault. A target the set cannot read is an
/// error status carrying no fault, which the answer renders as an internal error: nothing is written.</p>
ClassMethod Prohibited(pToolClass As %String, pId As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pId, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Issue tool <var>pToolClass</var>'s own write for <var>pId</var> with <var>pPayload</var>, through
/// <method>PortClass</method>.</p>
ClassMethod Send(pToolClass As %String, pId As %String, pPayload As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pWritten) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = pId
    Quit $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "WriteType"), .tQuery, pPayload, .pWritten, .pHttpStatus, .pFault)
}

/// <p>Render the outcome of <method>Create</method> or <method>Update</method>: the violations as one 422
/// envelope, a refusal as its own envelope, and success as <method>AnswerBody</method> at <var>pSuccess</var>, with
/// <var>pReadBack</var> as <code>readBack</code> and <var>pConsequence</var> as <code>consequence</code> when
/// there are any.</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pId As %String, pParts As %List, pReadBack As %DynamicObject = "", pConsequence As %String = "") As %Status [ Private ]
{
    If $Get(pViolations) > 0 Quit $ClassMethod(..#RULES, "RenderViolations", .pViolations)
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tAnswer = ..AnswerBody(pId, pParts)
    If $IsObject(pReadBack) Do tAnswer.%Set("readBack", pReadBack)
    If pConsequence '= "" Do tAnswer.%Set("consequence", pConsequence, "string")
    Quit ##class(OcuPilot.Api.Response).JSONStatus(pSuccess, tAnswer)
}

/// <p>Read the request body into <var>pBody</var>; 0 when it is not a JSON object.</p>
ClassMethod Body(Output pBody As %DynamicObject) As %Boolean [ Private ]
{
    Set pBody = ""
    Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.pBody, .tStage)
    If $$$ISERR(tReadSC) || '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Quit 1
}

/// <p>A create's own body fields, minus the identifying members (<method>IdentityMembers</method>), as one
/// <class>%DynamicObject</class>.</p>
ClassMethod CallerFields(pArgs As %DynamicObject) As %DynamicObject
{
    Set tFields = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    Set tMembers = ..IdentityMembers()
    For tI = 1:1:$ListLength(tMembers) {
        Set tMember = $List(tMembers, tI)
        If tFields.%GetTypeOf(tMember) '= "unassigned" Do tFields.%Remove(tMember)
    }
    Quit tFields
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs or every pair
/// the write tool <var>pWriteTool</var> declares (AD-8, AD-44) before anything is read or sent:
/// <var>pRefused</var> 1 means the envelope is written and the handler writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean, pWriteTool As %String = "") As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    If pWriteTool = "" Quit $$$OK
    Set tPairs = $ClassMethod(pWriteTool, "PrivilegePairs", "", .tResolved)
    If 'tResolved {
        Set pRefused = 1
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the privilege pairs of " _ pWriteTool _ " could not be read")))
    }
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs(tPairs, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
