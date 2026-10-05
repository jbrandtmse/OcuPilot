/// <p>The encryption key file create form's Save (AD-55, Story 18.7): <code>POST /encryption-key-file</code>
/// creates one key file through <class>OcuPilot.Screen.Tool.EncryptionKeyFileCreate</class>, on
/// <class>OcuPilot.Area.OsMgmt.LicenseServerSave</class>'s model: the caller's pairs asked before
/// anything is read or sent, the key-file rules, the new file checked as the write checks it, AD-10's set
/// before the port, and no proposal minted.</p>
/// <p>The body's top-level keys are <code>root</code>, <code>path</code>, <code>AdminName</code>,
/// <code>KeyLen</code>, <code>Description</code> and <code>AdminPassword</code>; any other is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>. The password travels as
/// <class>OcuPilot.Screen.Descriptor.EncryptionKeyFile</class>'s declared secret, held in this request's
/// locals and cleared after the write; it is never answered, stored or logged (AD-35). A refusal on a
/// field, the rules' or the port's, is one 422
/// <parameter>OcuPilot.Api.EncryptionError.KEYFILEVALIDATION</parameter> envelope.</p>
/// <p>It answers <code>{keyId, readBack}</code> with 201, the new key's id read from the file again,
/// marked <code>Cache-Control: no-store</code>. Seams a subclass may override:
/// <method>PortClass</method> and <method>ProhibitedClass</method>.</p>
Class OcuPilot.Area.Security.EncryptionKeyFileSave Extends %RegisteredObject
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.EncryptionKeyFileCreate";

/// <p>The screen whose declared pairs gate this route, and whose entity type, scope and declared
/// secret the write carries (AD-8, AD-13, AD-56).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EncryptionKeyFile";

/// <p>The body keys the form sends, the secret among them.</p>
Parameter FIELDS = "root,path,AdminName,KeyLen,Description,AdminPassword";

Parameter SECRET = "AdminPassword";

/// <p>The port the write and the re-read go through, the tool's own declaration (AD-52). Overridable
/// so a fixture can observe what was sent.</p>
ClassMethod PortClass() As %String
{
    Quit $ClassMethod(..#CREATETOOL, "PortClass")
}

/// <p>AD-10's set, asked before the port is touched.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Prohibited"
}

/// <p>Answer <code>POST /encryption-key-file</code>.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
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
        Set tPerformSC = ..Create(tBody, .tHttp, .tFault, .tViolations, .tKeyId, .tReadBack)
        Set tBody = ""
        If +$Get(tViolations) > 0 {
            Set tSC = ##class(OcuPilot.Area.Security.EncryptionRules).RenderViolations(.tViolations)
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
        Do tAnswer.%Set("keyId", $Get(tKeyId), "string")
        If $IsObject($Get(tReadBack)) Do tAnswer.%Set("readBack", tReadBack)
        Set %response.Headers("Cache-Control") = "no-store"
        Set tSC = ##class(OcuPilot.Api.Response).JSONStatus(201, tAnswer)
    } Catch ex {
        Set tBody = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Create the key file <var>pBody</var> names.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array (<code>pViolations(n) =
/// $ListBuild(field, code)</code>, count in <code>pViolations</code>); a non-zero count means nothing was
/// written. Otherwise an error status carries <var>pHttpStatus</var> and <var>pFault</var>. On success
/// <var>pKeyId</var> is the new key's id and <var>pReadBack</var> the write's read-back (AD-58).</p>
ClassMethod Create(pBody As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pKeyId As %String, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pKeyId = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tSecret = ""
    Try {
        Set tClass = ..#CREATETOOL
        Set tIterator = pBody.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If $ListFind($ListFromString(..#FIELDS), tKey) Continue
            Set pHttpStatus = 400
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)
            Do pFault.%Set("detail", {"violations": [{"field": (tKey), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)}]})
            Quit
        }
        If pHttpStatus = 400 {
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
            Quit
        }
        Set tRoot = ##class(OcuPilot.Area.Security.EncryptionRules).Value(pBody, "root")
        Set tPath = ##class(OcuPilot.Area.Security.EncryptionRules).Value(pBody, "path")
        Set tSecret = ##class(OcuPilot.Area.Security.EncryptionRules).Value(pBody, ..#SECRET)
        Do ##class(OcuPilot.Area.Security.EncryptionRules).Violations(pBody, $ListBuild("AdminName", ..#SECRET, "KeyLen"), .pViolations)
        Set tCheckSC = $ClassMethod(..PortClass(), "CheckCreate", tRoot, tPath, .tResolved, .tCheckHttp, .tCheckFault)
        If $$$ISERR(tCheckSC) {
            If '..AddViolations($Get(tCheckFault), .pViolations) {
                Set pHttpStatus = $Get(tCheckHttp)
                Set pFault = $Get(tCheckFault)
                Set tSC = tCheckSC
                Quit
            }
        }
        If pViolations > 0 Quit
        Set tArgs = {}
        For tName = "AdminName", "KeyLen", "Description" {
            If pBody.%GetTypeOf(tName) '= "unassigned" Do tArgs.%Set(tName, ##class(OcuPilot.Area.Security.EncryptionRules).Value(pBody, tName), "string")
        }
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Compose(tArgs, "path", $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the key file's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tRoot, tPath))
        Set tSC = ..Prohibited(tClass, tId, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = tId
        Do $ClassMethod(tClass, "PortQuery", tPayload, .tQuery)
        Set tSend = {}
        Do tSend.%Set(..#SECRET, tSecret, "string")
        Set tSecret = ""
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tSend, .tWritten, .pHttpStatus, .pFault)
        Set tSend = ""
        If $$$ISERR(tSC) {
            If ..AddViolations($Get(pFault), .pViolations) Set tSC = $$$OK
            Quit
        }
        Set tWriteHttp = pHttpStatus
        Kill tRead
        Set tRead($ClassMethod(tClass, "IdParam")) = tId
        Set tReadSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tRead, "", .tAfter, .tReadHttp, .tReadFault)
        If $$$ISOK(tReadSC) && $IsObject($Get(tAfter)) && (tAfter.%GetTypeOf("Keys") = "array") && (tAfter.%Get("Keys").%Size() > 0) Set pKeyId = tAfter.%Get("Keys").%Get(0).%Get("Id")
        If (pKeyId = "") && $IsObject($Get(tWritten)) Set pKeyId = tWritten.%Get("Id")
        ; AD-58: a create that compares no derived field reports its secret written; the name is handed
        ; over with its placeholder, never the value.
        Set tSentNames = {}
        Do tSentNames.%Set(..#SECRET, "<" _ ..#SECRET _ ">", "string")
        Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, tId, tSentNames, "", ..PortClass(), $Get(tWritten), tWriteHttp)
        Set pHttpStatus = tWriteHttp
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set tSecret = ""
    Quit tSC
}

/// <p>Add <var>pFault</var>'s <code>detail.violations</code> to <var>pViolations</var>; 0 when it
/// carries none.</p>
ClassMethod AddViolations(pFault, ByRef pViolations) As %Boolean [ Private ]
{
    If '$IsObject(pFault) || (pFault.%GetTypeOf("detail") '= "object") || (pFault.%Get("detail").%GetTypeOf("violations") '= "array") Quit 0
    Set tAdded = 0
    Set tIterator = pFault.%Get("detail").%Get("violations").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        Set pViolations($Increment(pViolations)) = $ListBuild(tRow.%Get("field"), tRow.%Get("code"))
        Set tAdded = 1
    }
    Quit tAdded
}

/// <p>Ask AD-10's set about the create of <var>pId</var>; a <code>PROHIBITED.*</code> verdict is an
/// error status with a 403 fault.</p>
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

/// <p>Refuse a caller who does not hold the descriptor's declared pairs or the create tool's own
/// (AD-8, AD-44), before anything is read or sent: <var>pRefused</var> 1 means the envelope is
/// written.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    Set tPairs = $ClassMethod(..#CREATETOOL, "PrivilegePairs", ..#DESCRIPTORCLASS, .tResolved)
    If 'tResolved {
        Set pRefused = 1
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the create tool's pairs could not be read")))
    }
    If ##class(OcuPilot.Screen.Gate).EvaluatePairs(tPairs, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
