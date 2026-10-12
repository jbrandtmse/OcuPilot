/// <p>Encryption startup settings' Save and form read (AD-55, Story 18.23). <code>PUT
/// /encryption-startup</code> changes the settings through
/// <class>OcuPilot.Screen.Tool.EncryptionStartupUpdate</class>, the tool the agent's mint and confirm read;
/// <code>GET /encryption-startup/form</code> answers <code>{kmipServers, encryptedDatabases}</code>, the
/// configured KMIP servers' names (<method>OcuPilot.Port.EncryptionPort.KmipNames</method>) and which of the
/// audit log's, IRISSECURITY's and IRISTEMP's databases are encrypted on disk
/// (<method>OcuPilot.Port.EncryptionPort.EncryptedOnDisk</method>).</p>
/// <p><b>It resolves everything about the write from the tool class</b>: the endpoint, the request types,
/// the port, the settable fields, the merge, the consequence and the pairs, each asked before anything is
/// sent. It mints no proposal, takes no confirm token and is not governed. The version gate comes first,
/// then the fresh read and the merge, AD-10's set and the port's rules, each before the <code>PUT</code>;
/// a merge whose diff has no row sends nothing.</p>
/// <p>The body's top-level keys are the tool's settable fields and <code>AdminPassword</code>, the
/// descriptor's declared secret, which this request holds in a local, clears after the write and never
/// answers, stores or logs (AD-35). A refusal on a field is one 422 envelope.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and <method>ProhibitedClass</method>.
/// Production overrides neither.</p>
Class OcuPilot.Area.Security.EncryptionStartupSave Extends %RegisteredObject
{

/// <p>The tool both callers resolve the write through (AD-55).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.EncryptionStartupUpdate";

/// <p>The screen whose declared pairs gate both routes, and whose entity type and scope the prohibited
/// set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EncryptionStartup";

/// <p>The declared secret the body may carry.</p>
Parameter SECRET = "AdminPassword";

/// <p>The port the write and the fresh read go through, the tool's own declaration (AD-52). Overridable
/// so a fixture can observe what was sent; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#UPDATETOOL, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched. Overridable for the reason
/// <method>PortClass</method> is; production never overrides it.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>The one id the settings are known by (AD-13).</p>
ClassMethod TargetId() As %String
{
    Quit ##class(OcuPilot.Kernel.EntityRef).#RULESINGLETONID
}

/// <p>Answer <code>GET /encryption-startup/form</code>: <code>{kmipServers, encryptedDatabases}</code>, after
/// the screen's pairs; either read failing fails the answer.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tFailedPair = ""
        If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
            Set tSC = ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
            Quit
        }
        Set tReadSC = $ClassMethod(..PortClass(), "KmipNames", .tNames, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            Set tSC = ..RenderFault(tReadSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tDiskSC = $ClassMethod(..PortClass(), "EncryptedOnDisk", .tEncrypted, .tHttp, .tFault)
        If $$$ISERR(tDiskSC) {
            Set tSC = ..RenderFault(tDiskSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("kmipServers", tNames)
        Do tBody.%Set("encryptedDatabases", tEncrypted)
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>PUT /encryption-startup</code>: change the settings the body carries and answer
/// <code>{readBack}</code> with 200 (AD-58), with <code>consequence</code> when the write carries one, or
/// <code>{}</code> when nothing changes. A top-level key the tool does not admit is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>; a refusal on a field is one 422 envelope
/// carrying every violation; any other refusal is the gate's, the port's or the prohibited set's own
/// envelope.</p>
ClassMethod HandleUpdate() As %Status
{
    Set tSC = $$$OK
    Set tHoldKey = ""
    Set tBody = ""
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) || '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") {
            Set tBody = ""
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tArgPairs = $ClassMethod(..#UPDATETOOL, "ArgumentPairs", "", tBody, .tResolved)
        If '##class(OcuPilot.Screen.Gate).EvaluatePairs(tArgPairs, .tFailedPair) {
            Set tBody = ""
            Set tSC = ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
            Quit
        }
        Set tHoldSC = ##class(OcuPilot.Kernel.Proposal.Operation).HoldTool(..#UPDATETOOL, ..TargetId(), .tHeld, .tHoldKey)
        If $$$ISERR(tHoldSC) || 'tHeld {
            Set tSC = ##class(OcuPilot.Api.Error).RenderTargetBusy(tHoldSC)
            Quit
        }
        Set tPerformSC = ..Update(tBody, .tHttp, .tFault, .tReadBack, .tConsequence)
        Set tBody = ""
        Set tSC = ..Answer(tPerformSC, $Get(tHttp), $Get(tFault), $Get(tReadBack), $Get(tConsequence))
    } Catch ex {
        Set tBody = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Do ##class(OcuPilot.Kernel.Proposal.Operation).Release(tHoldKey)
    Quit tSC
}

/// <p>Change the settings <var>pArgs</var> carries, merged over the tool's fresh read (AD-4).</p>
/// <p><b>Caller contract:</b> an error status carries <var>pHttpStatus</var> and <var>pFault</var>, a
/// refusal on fields carrying <code>detail.violations</code>; a key the tool does not admit is an error
/// status with <var>pHttpStatus</var> 400 and nothing read. On a write, <var>pReadBack</var> is its
/// read-back (AD-58) and <var>pConsequence</var> the tool's consequence code for it, read before the
/// write; a merge that changes nothing sends nothing and leaves both empty. <var>pArgs</var>'
/// <parameter>SECRET</parameter> is taken out before anything else and cleared after the write.</p>
ClassMethod Update(pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pReadBack As %DynamicObject, Output pConsequence As %String) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Set pConsequence = ""
    Set tSC = $$$OK
    Set tSecret = ""
    Try {
        Set tClass = ..#UPDATETOOL
        Set tSecret = ##class(OcuPilot.Area.Security.EncryptionRules).Value(pArgs, ..#SECRET)
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Do tArgs.%Remove(..#SECRET)
        Do pArgs.%Remove(..#SECRET)
        Set tAllowed = $ClassMethod(tClass, "SettableFields")
        Set tIterator = tArgs.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If $ListFind(tAllowed, tKey) Continue
            Set pHttpStatus = 400
            Set pFault = ..Unexpected(tKey)
            Quit
        }
        If pHttpStatus = 400 {
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
            Quit
        }

        ; AD-26: the explicit version gate, before anything is read or sent.
        Set tSC = $ClassMethod(..PortClass(), "SettingsGate", .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = ..TargetId()
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject(tFresh) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set tSC = $$$ERROR($$$GeneralError, "the encryption startup settings read answered no object")
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""

        Set tSC = $ClassMethod(tClass, "MergeUpdate", tFresh, tArgs, $ClassMethod(tClass, "IdArgument"), tAllowed, .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set pHttpStatus = 400
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS)
            Do pFault.%Set("detail", {"problem": (tProblem)})
            Set tSC = $$$ERROR($$$GeneralError, tProblem)
            Quit
        }
        ; Nothing to change sends nothing.
        If tDiff.%Size() = 0 Quit

        Set tSC = ..Prohibited(tClass, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tConsequence = $ClassMethod(tClass, "ConsequenceOver", tPayload, tFresh)
        Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tPayload.%ToJSON())
        If tPayload.%GetTypeOf(..#SECRET) '= "unassigned" Do tBody.%Set(..#SECRET, tSecret, "string")
        Set tSecret = ""
        Set tSC = ..Send(tClass, tPayload, tBody, .pHttpStatus, .pFault, .tWritten)
        Set tBody = ""
        If $$$ISERR(tSC) Quit
        Set pConsequence = tConsequence
        Set tSentNames = ##class(%DynamicAbstractObject).%FromJSON(tPayload.%ToJSON())
        If tSentNames.%GetTypeOf(..#SECRET) '= "unassigned" Do tSentNames.%Set(..#SECRET, "<" _ ..#SECRET _ ">", "string")
        Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, ..TargetId(), tSentNames, tFresh, ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set tSecret = ""
    Quit tSC
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make carrying <var>pPayload</var>
/// and <var>pDiff</var>; a <code>PROHIBITED.*</code> verdict is an error status with a 403 fault.</p>
ClassMethod Prohibited(pToolClass As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), ..TargetId(), .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..ProhibitedClass(), "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Issue tool <var>pToolClass</var>'s own write of <var>pBody</var>, the payload with the declared
/// secret merged in, through <method>PortClass</method>, its query built from the payload
/// <var>pPayload</var>; <var>pWritten</var> is the port's answer.</p>
ClassMethod Send(pToolClass As %String, pPayload As %DynamicObject, pBody As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pWritten) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = ..TargetId()
    Do $ClassMethod(pToolClass, "PortQuery", pPayload, .tQuery)
    Quit $ClassMethod(..PortClass(), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "WriteType"), .tQuery, pBody, .pWritten, .pHttpStatus, .pFault)
}

/// <p>Render the outcome: a refusal as its own envelope, and success as <code>{readBack,
/// consequence}</code>, <code>consequence</code> only when the write carries one, or <code>{}</code> when
/// nothing was sent (AD-58).</p>
ClassMethod Answer(pSC As %Status, pHttp As %Integer, pFault As %DynamicObject, pReadBack As %DynamicObject = "", pConsequence As %String = "") As %Status [ Private ]
{
    If $$$ISERR(pSC) Quit ..RenderFault(pSC, pHttp, pFault)
    Set tAnswer = {}
    If $IsObject(pReadBack) Do tAnswer.%Set("readBack", pReadBack)
    If pConsequence '= "" Do tAnswer.%Set("consequence", pConsequence, "string")
    Quit ##class(OcuPilot.Api.Response).JSONStatus(200, tAnswer)
}

/// <p>A refusal rendered as its own envelope, or the generic internal one when it carries no code of its
/// own.</p>
ClassMethod RenderFault(pSC As %Status, pHttp As %Integer, pFault As %DynamicObject) As %Status [ Private ]
{
    If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>The 400 <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter> fault for key
/// <var>pKey</var>.</p>
ClassMethod Unexpected(pKey As %String) As %DynamicObject [ Private ]
{
    Set tFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)
    Do tFault.%Set("detail", {"violations": [{"field": (pKey), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)}]})
    Quit tFault
}

/// <p>Refuse a caller who does not hold the descriptor's declared pairs or every pair the tool's write
/// declares, before anything is read or sent: <var>pRefused</var> 1 means the envelope is written and the
/// handler writes nothing else (AD-8).</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    Set tPairs = $ClassMethod(..#UPDATETOOL, "PrivilegePairs", "", .tResolved)
    If 'tResolved {
        Set pRefused = 1
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the privilege pairs of " _ ..#UPDATETOOL _ " could not be read")))
    }
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs(tPairs, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
