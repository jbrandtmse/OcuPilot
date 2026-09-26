/// <p>The copy-out draft (AD-59): a live proposal answered with the REST or ObjectScript script that
/// would make its change, in place of the change. The script is rendered on the instance from the
/// stored row, through the <code>Snippet</code> of the port the tool declares (AD-52), and the
/// proposal closes <code>canceled</code> with reason <code>draft</code> through the same
/// conditional live-to-terminal update Cancel uses (AD-34).</p>
/// <p><b>It sends nothing.</b> No port write, no mint, no token, no ledger row, no agent marker
/// (AD-15 binds only an executed write) and no change event. The only reads are the proposal's own
/// row and the prohibited set's own read of its target (AD-10), which refuses a prohibited effect
/// with the row left live.</p>
/// <p><b>No secret is rendered.</b> Every name the tool declares secret, every <code>secret</code>
/// row of its field list and every name the credential pattern matches
/// (<method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>) reads as the placeholder
/// <code>&lt;Name&gt;</code> in the body and the query before any port renders them.</p>
/// <p><b>It is not a tool.</b> Nothing in the registry reaches it, and <method>Take</method> refuses
/// a process carrying <method>OcuPilot.Kernel.Proposal.Caller.IsTurn</method> first (AD-40).</p>
/// <p>Seams a test subclass overrides: <method>StoreClass</method>, <method>PortClass</method>,
/// <method>ProhibitedClassName</method> and <method>ToolRegistryClass</method>. Production
/// overrides none of them.</p>
Class OcuPilot.Kernel.Proposal.Draft Extends %RegisteredObject
{

/// <p>The proposal store.</p>
ClassMethod StoreClass() As %String
{
    Quit "OcuPilot.Kernel.State.Propose"
}

/// <p>The port a tool that declares the base's own default renders through (AD-52).</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>AD-10's prohibited set, as <method>OcuPilot.Kernel.Proposal.Write.ProhibitedClass</method>
/// answers it.</p>
ClassMethod ProhibitedClassName() As %String
{
    Quit ##class(OcuPilot.Kernel.Proposal.Write).ProhibitedClass()
}

/// <p>The tool registry a proposal's tool is resolved through.</p>
ClassMethod ToolRegistryClass() As %String
{
    Quit "OcuPilot.Screen.Tool.Registry"
}

/// <p>Take the draft of proposal <var>pProposalId</var> for <var>pUser</var>, addressing every
/// <code>rest</code> step at <var>pOrigin</var>.</p>
/// <p>On success the status is OK, <var>pHttpStatus</var> 200 and <var>pAnswer</var>
/// <code>{proposalId, state, closedReason, confirmedAt, draft: {steps: [{kind, text}],
/// placeholders}}</code>, read back from the closed row. On a refusal the status is an error,
/// <var>pCode</var> the machine code and <var>pHttpStatus</var> its HTTP status: 403
/// <code>PROPOSAL.FROMTURN</code> from a turn; 404 <code>PROPOSAL.UNKNOWN</code> for a row that is
/// not this caller's and live, or that another request closed first; the prohibited set's own code
/// at 403; 409 <code>PROPOSAL.NODRAFT</code> for a tool whose port or request type has no script
/// form. Every refusal but the lost race leaves the row as it was.</p>
/// <p><b>Caller contract:</b> <var>pUser</var> is the authenticated caller and
/// <var>pOrigin</var> the request's own scheme and host, neither taken from a body.</p>
ClassMethod Take(pProposalId As %String, pUser As %String, pOrigin As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pCode As %String) As %Status
{
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pCode = ""
    Set tSC = $$$OK
    Try {
        If ##class(OcuPilot.Kernel.Proposal.Caller).IsTurn() {
            Set tSC = ..Refuse(403, ##class(OcuPilot.Kernel.Proposal.Write).#FROMTURN, .pHttpStatus, .pCode)
            Quit
        }
        Set tStore = ..StoreClass()
        Set tSC = $ClassMethod(tStore, "GuardedExpireStale", pUser)
        If $$$ISERR(tSC) Quit
        Set tSC = $ClassMethod(tStore, "GuardedByKey", pProposalId, .tFound, .tRow)
        If $$$ISERR(tSC) Quit
        If 'tFound || ($Get(tRow("user")) '= pUser) || ($Get(tRow("state")) '= $Parameter(tStore, "STATELIVE")) {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN, .pHttpStatus, .pCode)
            Quit
        }
        Set tSC = $ClassMethod(..ToolRegistryClass(), "Resolve", $Get(tRow("toolName")), .tTool)
        If $$$ISERR(tSC) || '$IsObject($Get(tTool)) {
            Set tSC = ..Internal("the proposal names a tool this instance does not carry", .pHttpStatus, .pCode)
            Quit
        }

        ; AD-10: the effect the write would have is refused here as the write would refuse it, and
        ; the row stays live. No privilege pair is checked: whoever runs the script is checked by
        ; the instance.
        Set tProhibitSC = $ClassMethod(..ProhibitedClassName(), "Prohibits", $Get(tRow("toolName")), $Get(tRow("targetRef")), $Get(tRow("payload")), $Get(tRow("diff")), .tProhibits, .tProhibitCode)
        If $$$ISERR(tProhibitSC) {
            Set tSC = ..Internal("the prohibited set could not be read: " _ $System.Status.GetErrorText(tProhibitSC), .pHttpStatus, .pCode)
            Quit
        }
        If tProhibits {
            Set tSC = ..Refuse(403, tProhibitCode, .pHttpStatus, .pCode)
            Quit
        }

        Set tSC = ..Render(tTool, .tRow, pOrigin, pUser, .tDraft)
        If $$$ISERR(tSC) {
            Set tSC = ..Internal("the draft could not be rendered: " _ $System.Status.GetErrorText(tSC), .pHttpStatus, .pCode)
            Quit
        }
        If '$IsObject(tDraft) || (tDraft.%Get("steps").%Size() = 0) {
            Set tSC = ..Refuse(409, ##class(OcuPilot.Kernel.Proposal.Write).#NODRAFT, .pHttpStatus, .pCode)
            Quit
        }

        ; AD-34: the one conditional live-to-terminal update Cancel makes. A caller that loses it
        ; to a confirm or another draft discards its script.
        Set tSC = $ClassMethod(tStore, "GuardedClose", pProposalId, pUser, $Parameter(tStore, "REASONDRAFT"), .tClosed)
        If $$$ISERR(tSC) Quit
        If 'tClosed {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN, .pHttpStatus, .pCode)
            Quit
        }
        Set tSC = ..Answer(pProposalId, tDraft, .pAnswer, .pHttpStatus, .pCode)
    } Catch ex {
        Set pAnswer = ""
        Set tSC = ..Internal("the draft failed: " _ ex.DisplayString(), .pHttpStatus, .pCode)
    }
    Quit tSC
}

/// <p>The draft of the stored proposal <var>pRow</var> (<method>OcuPilot.Kernel.State.Propose.GuardedByKey</method>'s
/// values) for the resolved tool <var>pTool</var>, as <code>{steps, placeholders}</code> in
/// <var>pDraft</var>, or <code>""</code> when the tool's port has no script form for its request
/// type. <var>pBody</var> and <var>pQuery</var> are the body and query the port was asked to render,
/// with every secret a placeholder.</p>
/// <p>The body is composed as <class>OcuPilot.Kernel.Proposal.Confirm</class> composes the one it
/// sends, with a placeholder standing for each declared secret the card asks for -- the tool's
/// secret-only body, and each declared secret the stored payload carries. It reads nothing but
/// <var>pRow</var> and the tool's own declarations, and writes nothing.</p>
ClassMethod Render(pTool As %DynamicObject, ByRef pRow, pOrigin As %String, pUser As %String, Output pDraft As %DynamicObject, Output pBody As %DynamicAbstractObject, Output pQuery) As %Status
{
    Set pDraft = ""
    Set pBody = ""
    Kill pQuery
    Set tSC = $$$OK
    Try {
        Set tClass = pTool.%Get("class")
        Set tEndpoint = $ClassMethod(tClass, "Endpoint")
        Set tIdParam = $ClassMethod(tClass, "IdParam")
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Parse($Get(pRow("targetRef")), .tType, .tScope, .tIdValue)
        If $$$ISERR(tSC) Quit
        Set tCreates = ##class(OcuPilot.Kernel.Proposal.Mint).CreatesOf(tClass)
        If tCreates {
            ; AD-54: a create names its target as the caller typed it, as the confirm sends it.
            Set tTyped = ..ParsedObject($Get(pRow("arguments"))).%Get($ClassMethod(tClass, "IdArgument"))
            If (tTyped '= "") && '$IsObject(tTyped) && (##class(OcuPilot.Kernel.EntityRef).NormalizedId(tType, tTyped) = ##class(OcuPilot.Kernel.EntityRef).NormalizedId(tType, tIdValue)) Set tIdValue = tTyped
        }
        Set tPort = ##class(OcuPilot.Kernel.Proposal.Operation).PortClassOf(tClass, ..PortClass())
        Set tWriteType = ##class(OcuPilot.Kernel.Proposal.Operation).WriteType(tClass)
        If $ClassMethod(tPort, "SnippetForm", tEndpoint, tWriteType) = "" Quit

        Set tSecretNames = $ClassMethod(..ToolRegistryClass(), "SecretArguments", pTool, .tDeclared)
        Set tPayloadJson = $Get(pRow("payload"))
        Set tPayload = ..ParsedObject(tPayloadJson)
        Set tSupplied = {}
        Set tBodyNames = ""
        Try {
            Set tBodyNames = $ClassMethod(tClass, "SecretBodyNames")
        } Catch {
            Set tBodyNames = ""
        }
        For tI = 1:1:$ListLength(tSecretNames) {
            Set tName = $List(tSecretNames, tI)
            If '$ListFind(tBodyNames, tName) && (tPayload.%GetTypeOf(tName) = "unassigned") Continue
            Do tSupplied.%Set(tName, ..Placeholder(tName), "string")
        }

        ; Confirm.cls's body composition, step for step.
        Set tSendsBody = ##class(OcuPilot.Kernel.Proposal.Operation).SendsBody(tClass)
        Set tBody = ##class(OcuPilot.Kernel.Proposal.Operation).SecretBody(tClass, tSupplied, tSecretNames)
        If tSendsBody Set tBody = ..WithSecrets(tPayloadJson, tSupplied, tSecretNames)
        If tSendsBody Do ..ToolDerivedFields(tClass, tBody)
        Do ##class(OcuPilot.Kernel.Proposal.Operation).Query(tClass, tIdParam, tIdValue, tPayloadJson, .tQuery)

        Set tSecrets = ..SecretNamesOf(pTool, tSecretNames)
        Set tPlaceholders = []
        Kill tSeen
        If $IsObject(tBody) Do ..Mask(tBody, tSecrets, tPlaceholders, .tSeen)
        Set tName = ""
        For {
            Set tName = $Order(tQuery(tName), 1, tValue)
            If tName = "" Quit
            If (tValue = "") || '..IsSecretName(tName, tSecrets) Continue
            Set tQuery(tName) = ..Placeholder(tName)
            Do ..Note(tName, tPlaceholders, .tSeen)
        }
        Set tStored = ##class(%DynamicAbstractObject).%FromJSON(tPayload.%ToJSON())
        Kill tStoredSeen
        Do ..Mask(tStored, tSecrets, [], .tStoredSeen)

        Set tChanged = []
        Set tDiff = ..ParsedArray($Get(pRow("diff")))
        Set tIterator = tDiff.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tDiffRow) {
            If $IsObject(tDiffRow) && (tDiffRow.%Get("field") '= "") Do tChanged.%Push(tDiffRow.%Get("field"))
        }
        Set tContext = {}
        Do tContext.%Set("origin", pOrigin, "string")
        Do tContext.%Set("user", pUser, "string")
        Do tContext.%Set("creates", ''tCreates, "boolean")
        Do tContext.%Set("payload", tStored)
        Do tContext.%Set("diff", tChanged)

        Kill tPortQuery
        Merge tPortQuery = tQuery
        Set tSteps = $ClassMethod(tPort, "Snippet", tEndpoint, tWriteType, .tPortQuery, tBody, tContext)
        If '$IsObject(tSteps) Set tSteps = []
        If (tSteps.%Size() > 0) && ##class(%Dictionary.CompiledMethod).%ExistsId(tClass _ "||SnippetAfter") {
            Set tAfter = $ClassMethod(tClass, "SnippetAfter", tEndpoint, tIdParam, tIdValue, tStored, tContext)
            If $IsObject(tAfter) {
                Set tIterator = tAfter.%GetIterator()
                While tIterator.%GetNext(.tIndex, .tStep) {
                    Do tSteps.%Push(tStep)
                }
            }
        }
        Set pDraft = {}
        Do pDraft.%Set("steps", tSteps)
        Do pDraft.%Set("placeholders", tPlaceholders)
        Set pBody = tBody
        Merge pQuery = tQuery
    } Catch ex {
        Set pDraft = ""
        Set pBody = ""
        Kill pQuery
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The placeholder a secret named <var>pName</var> is rendered as.</p>
ClassMethod Placeholder(pName As %String) As %String
{
    Quit "<" _ pName _ ">"
}

/// <p>Every name <var>pTool</var> treats as secret, as a <class>%List</class>: its declared secret
/// arguments <var>pDeclared</var> and every field its generated field list classifies
/// <code>secret</code>, by its last path segment. The credential pattern is applied beside it
/// (<method>IsSecretName</method>).</p>
ClassMethod SecretNamesOf(pTool As %DynamicObject, pDeclared As %List) As %List
{
    Set tNames = pDeclared
    Try {
        Set tFieldsClass = $Parameter(pTool.%Get("class"), "TOOLFIELDSCLASS")
        If tFieldsClass = "" Quit
        Set tXData = ##class(%Dictionary.CompiledXData).%OpenId(tFieldsClass _ "||Tools")
        If '$IsObject(tXData) Quit
        Do tXData.Data.Rewind()
        Set tTools = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        Set tXData = ""
        Set tEntry = tTools.%Get(pTool.%Get("name"))
        If '$IsObject(tEntry) || (tEntry.%GetTypeOf("fields") '= "array") Quit
        Set tIterator = tEntry.%Get("fields").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            If '$IsObject(tField) || (tField.%Get("class") '= "secret") Continue
            Set tPath = tField.%Get("path")
            Set tName = $Piece($Piece(tPath, ".", $Length(tPath, ".")), "[", 1)
            If (tName '= "") && '$ListFind(tNames, tName) Set tNames = tNames _ $ListBuild(tName)
        }
    } Catch {
        ; A field list that cannot be read adds no name; the declared names and the pattern still
        ; apply.
    }
    Quit tNames
}

/// <p>Whether <var>pName</var> is one of <var>pSecrets</var> or a name the credential pattern
/// matches.</p>
ClassMethod IsSecretName(pName As %String, pSecrets As %List) As %Boolean
{
    If $ListFind(pSecrets, pName) Quit 1
    Quit ''##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(pName)
}

/// <p>Replace, throughout <var>pValue</var>, the value of every key <var>pSecrets</var> names, and
/// the string value of every key the credential pattern matches, with its placeholder when that
/// value is not empty, and note each such key in <var>pPlaceholders</var>. A flag or a number under
/// a matching name is not a credential (Conventions &gt; Secrets) and is left as it is.</p>
ClassMethod Mask(pValue As %DynamicAbstractObject, pSecrets As %List, pPlaceholders As %DynamicArray, ByRef pSeen)
{
    If '$IsObject(pValue) Quit
    If pValue.%IsA("%Library.DynamicArray") {
        Set tIterator = pValue.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tItem) {
            If $IsObject(tItem) Do ..Mask(tItem, pSecrets, pPlaceholders, .pSeen)
        }
        Quit
    }
    Set tKeys = ""
    Set tIterator = pValue.%GetIterator()
    While tIterator.%GetNext(.tKey, .tItem) {
        Set tKeys = tKeys _ $ListBuild(tKey)
    }
    For tI = 1:1:$ListLength(tKeys) {
        Set tKey = $List(tKeys, tI)
        Set tType = pValue.%GetTypeOf(tKey)
        If $ListFind(pSecrets, tKey) || ((tType = "string") && ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tKey)) {
            If (tType = "null") || (tType = "unassigned") Continue
            If (tType '= "object") && (tType '= "array") && (pValue.%Get(tKey) = "") Continue
            Do pValue.%Set(tKey, ..Placeholder(tKey), "string")
            Do ..Note(tKey, pPlaceholders, .pSeen)
            Continue
        }
        If (tType = "object") || (tType = "array") Do ..Mask(pValue.%Get(tKey), pSecrets, pPlaceholders, .pSeen)
    }
}

/// <p>Add <var>pName</var> to <var>pPlaceholders</var> once.</p>
ClassMethod Note(pName As %String, pPlaceholders As %DynamicArray, ByRef pSeen) [ Private ]
{
    If $Data(pSeen(pName)) Quit
    Set pSeen(pName) = ""
    Do pPlaceholders.%Push(pName)
}

/// <p>The stored payload <var>pPayloadJson</var> with the values <var>pBody</var> supplies for the
/// declared secret names <var>pNames</var> merged in: the merge
/// <class>OcuPilot.Kernel.Proposal.Confirm</class> makes before its port call.</p>
ClassMethod WithSecrets(pPayloadJson As %String, pBody As %DynamicObject, pNames As %List) As %DynamicObject [ Private ]
{
    Set tPayload = ..ParsedObject(pPayloadJson)
    If '$IsObject(pBody) Quit tPayload
    If 'pBody.%IsA("%Library.DynamicObject") Quit tPayload
    For tI = 1:1:$ListLength(pNames) {
        Set tName = $List(pNames, tI)
        If pBody.%GetTypeOf(tName) = "unassigned" Continue
        Do tPayload.%Set(tName, pBody.%Get(tName), pBody.%GetTypeOf(tName))
    }
    Quit tPayload
}

/// <p><var>pToolClass</var>'s own server-derived fields applied to <var>pBody</var>
/// (<method>OcuPilot.Screen.Tool.Write.DerivedFields</method>), as the confirm applies them.</p>
ClassMethod ToolDerivedFields(pToolClass As %String, pBody As %DynamicObject) [ Private ]
{
    Try {
        If pToolClass = "" Quit
        If '$IsObject(pBody) Quit
        Do $ClassMethod(pToolClass, "DerivedFields", pBody)
    } Catch {
        ; A tool that cannot answer derives nothing, as at the confirm.
    }
}

/// <p>The closed row as the caller is answered it, with <var>pDraft</var> beside it.</p>
ClassMethod Answer(pProposalId As %String, pDraft As %DynamicObject, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pCode As %String) As %Status [ Private ]
{
    Set pAnswer = ""
    Set tSC = $ClassMethod(..StoreClass(), "GuardedByKey", pProposalId, .tFound, .tValues)
    If $$$ISERR(tSC) Quit tSC
    If 'tFound Quit ..Internal("the proposal could not be read back after its draft", .pHttpStatus, .pCode)
    Set pAnswer = {}
    Do pAnswer.%Set("proposalId", pProposalId, "string")
    Do pAnswer.%Set("state", $Get(tValues("state")), "string")
    Do pAnswer.%Set("closedReason", $Get(tValues("closedReason")), "string")
    Do pAnswer.%Set("confirmedAt", $Get(tValues("confirmedAt")), "string")
    Do pAnswer.%Set("draft", pDraft)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p><var>pText</var> parsed as a JSON object, or <code>{}</code>.</p>
ClassMethod ParsedObject(pText As %String) As %DynamicObject [ Private ]
{
    Set tObject = {}
    Try {
        If pText = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pText)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicObject") Set tObject = tParsed
    } Catch {
        Set tObject = {}
    }
    Quit tObject
}

/// <p><var>pText</var> parsed as a JSON array, or <code>[]</code>.</p>
ClassMethod ParsedArray(pText As %String) As %DynamicArray [ Private ]
{
    Set tArray = []
    Try {
        If pText = "" Quit
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(pText)
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicArray") Set tArray = tParsed
    } Catch {
        Set tArray = []
    }
    Quit tArray
}

/// <p>A refusal as a status, with <var>pCode</var> and its HTTP status for the handler.</p>
ClassMethod Refuse(pStatus As %Integer, pCode As %String, Output pHttpStatus As %Integer, Output pOutCode As %String) As %Status [ Private ]
{
    Set pHttpStatus = pStatus
    Set pOutCode = pCode
    Quit $$$ERROR($$$GeneralError, pCode)
}

/// <p>An internal failure: 500 with the generic code on the wire and <var>pDetail</var> in the
/// status alone.</p>
ClassMethod Internal(pDetail As %String, Output pHttpStatus As %Integer, Output pCode As %String) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pCode = ##class(OcuPilot.Api.Error).#INTERNAL
    Quit $$$ERROR($$$GeneralError, pDetail)
}

}
