/// <p>The wallet secret form's Save for an RSA or symmetric key (AD-55, Story 18.24):
/// <method>Create</method> stores one key through
/// <class>OcuPilot.Screen.Tool.WalletKeyCreateRsa</class> or
/// <class>OcuPilot.Screen.Tool.WalletKeyCreateSymmetric</class>, and <method>Replace</method> replaces
/// one existing key's material through <class>OcuPilot.Screen.Tool.WalletKeyReplaceRsa</class> or
/// <class>OcuPilot.Screen.Tool.WalletKeyReplaceSymmetric</class>. The agent's half is the same tool
/// classes read by <class>OcuPilot.Kernel.Proposal.Mint</class> and
/// <class>OcuPilot.Kernel.Proposal.Confirm</class>.</p>
/// <p><b>Both are called from <class>OcuPilot.Area.Security.WalletSave</class>'s handlers</b>, which have
/// taken the caller's pairs and the target's hold (AD-8, AD-34) and hand over the seams
/// <code>PortClass</code> and <code>ProhibitedClass</code> they were called with. Each runs, in order: the
/// type check (a replace), the body's allowed members, the name's own rules (a create), AD-10's prohibited
/// set over the caller's non-secret fields, the key rules
/// (<class>OcuPilot.Area.Security.WalletKeyRules</class>), the body, and only then the port. A person's
/// replace is confirmed by the typed name on the page, not by a proposal, and is not governed (AD-53).</p>
/// <p><b>Key material is a secret end to end</b> (AD-35, AD-56): it joins the body after the verdict and the
/// rules, the body is cleared once the port has answered, and nothing here logs, echoes or returns it. The
/// answer is <code>{name, readBack}</code> and the read-back names written members only.</p>
Class OcuPilot.Area.Security.WalletKeySave Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55), by key type.</p>
Parameter CREATERSATOOL = "OcuPilot.Screen.Tool.WalletKeyCreateRsa";

Parameter CREATESYMMETRICTOOL = "OcuPilot.Screen.Tool.WalletKeyCreateSymmetric";

Parameter REPLACERSATOOL = "OcuPilot.Screen.Tool.WalletKeyReplaceRsa";

Parameter REPLACESYMMETRICTOOL = "OcuPilot.Screen.Tool.WalletKeyReplaceSymmetric";

/// <p>The screen whose entity type and scope the prohibited set's reference carries (AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WalletSecretForm";

Parameter IDARGUMENT = "Name";

Parameter TYPEFIELD = "Type";

Parameter RSATYPE = "%Wallet.RSA";

Parameter SYMMETRICTYPE = "%Wallet.SymmetricKey";

/// <p>The rules class both routes apply.</p>
Parameter RULES = "OcuPilot.Area.Security.WalletKeyRules";

/// <p>Whether <var>pType</var> is one of the two key types.</p>
ClassMethod IsKeyType(pType As %String) As %Boolean
{
    Quit (pType = ..#RSATYPE) || (pType = ..#SYMMETRICTYPE)
}

/// <p>The create tool of key type <var>pType</var>, or <code>""</code>.</p>
ClassMethod CreateTool(pType As %String) As %String
{
    If pType = ..#RSATYPE Quit ..#CREATERSATOOL
    If pType = ..#SYMMETRICTYPE Quit ..#CREATESYMMETRICTOOL
    Quit ""
}

/// <p>The replace tool of key type <var>pType</var>, or <code>""</code>.</p>
ClassMethod ReplaceTool(pType As %String) As %String
{
    If pType = ..#RSATYPE Quit ..#REPLACERSATOOL
    If pType = ..#SYMMETRICTYPE Quit ..#REPLACESYMMETRICTOOL
    Quit ""
}

/// <p>Store the key secret <var>pName</var> of the type <var>pArgs</var> names, generated from its length
/// or imported from its content, through the port <var>pPort</var>.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array
/// (<code>pViolations(n) = $ListBuild(field, code)</code>, count in <code>pViolations</code>); a non-zero
/// count means nothing was written and the other outputs say nothing. Otherwise an error status carries
/// <var>pHttpStatus</var> and <var>pFault</var>. On success <var>pReadBack</var> is the write's read-back
/// (AD-58); it is <code>""</code> otherwise.</p>
ClassMethod Create(pName As %String, pArgs As %DynamicObject, pPort As %String, pProhibited As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tBody = ""
    Set tCanonical = ""
    Try {
        Set tType = ..TypeOf(pArgs)
        Set tTool = ..CreateTool(tType)
        If tTool = "" {
            Set tSC = $$$ERROR($$$GeneralError, "a key create was handed a type that is not a key type")
            Quit
        }
        Set tSC = ..Unexpected(pArgs, ..AllowedFields(tType, 1), .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        ; The name's own rules, its collection and whether it is taken. The value rules are the form
        ; rules' own, so an empty body is judged here and no value is asked for.
        Set tSC = ##class(OcuPilot.Area.Security.WalletRules).Validate(pName, {}, .pViolations, 1, 1, 0)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        ; AD-10, AD-55: the set the confirm asks, before the port and before the rules, over the caller's
        ; own non-secret fields.
        Set tSC = ..Prohibited(tTool, pName, ..CallerFields(pArgs, $ClassMethod(tTool, "SecretArguments")), [], pProhibited, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tSC = $ClassMethod(..#RULES, "Validate", tType, $Parameter(..#RULES, "MODECREATE"), pArgs, .pViolations, 0, .tCanonical)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        ; AD-35: the material joins the body here, after the verdict and the rules, and nowhere else.
        Set tBody = tCanonical
        Set tCanonical = ""
        Do $ClassMethod(tTool, "DerivedFields", tBody)
        Set tSC = ..Send(tTool, pName, tBody, pPort, .pHttpStatus, .pFault, .tWritten)
        ; AD-58: the secret read back through the tool's port and compared with what was sent.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tTool, pName, tBody, "", pPort, $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set tBody = ""
    Set tCanonical = ""
    Quit tSC
}

/// <p>Replace the key material of the existing secret <var>pName</var>, whose fresh read is
/// <var>pFresh</var>, from <var>pArgs</var>: a newly generated RSA pair, or an import of either type.</p>
/// <p><b>Caller contract:</b> as <method>Create</method>'s. A body that names another type than the
/// secret holds is a violation on <code>Type</code>
/// (<parameter>OcuPilot.Api.WalletKeyError.TYPEMISMATCH</parameter>); a key outside the type's allowed
/// members is an error status with <var>pHttpStatus</var> 400.</p>
ClassMethod Replace(pName As %String, pArgs As %DynamicObject, pFresh As %DynamicObject, pPort As %String, pProhibited As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tBody = ""
    Set tCanonical = ""
    Try {
        Set tType = pFresh.%Get(..#TYPEFIELD)
        Set tTool = ..ReplaceTool(tType)
        If tTool = "" {
            Set tSC = $$$ERROR($$$GeneralError, "a key replace was handed a type that is not a key type")
            Quit
        }
        If (pArgs.%GetTypeOf(..#TYPEFIELD) '= "unassigned") && (pArgs.%Get(..#TYPEFIELD) '= tType) {
            Set pViolations($Increment(pViolations)) = $ListBuild(..#TYPEFIELD, ##class(OcuPilot.Api.WalletKeyError).#TYPEMISMATCH)
            Quit
        }
        Set tSC = ..Unexpected(pArgs, ..AllowedFields(tType, 0), .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tSC = ..Prohibited(tTool, pName, ..CallerFields(pArgs, $ClassMethod(tTool, "SecretArguments")), [], pProhibited, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tSC = $ClassMethod(..#RULES, "Validate", tType, $Parameter(..#RULES, "MODEREPLACE"), pArgs, .pViolations, 0, .tCanonical)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        Set tBody = tCanonical
        Set tCanonical = ""
        Do tBody.%Set(..#TYPEFIELD, tType, "string")
        Set tSC = ..Send(tTool, pName, tBody, pPort, .pHttpStatus, .pFault, .tWritten)
        ; AD-58: the create tool of the type reads back the same secret over the same rows, so a
        ; generated length is compared and imported members are reported written.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(..CreateTool(tType), pName, tBody, "", pPort, $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set tBody = ""
    Set tCanonical = ""
    Quit tSC
}

/// <p>The body's <code>Type</code>, or <code>""</code>.</p>
ClassMethod TypeOf(pArgs As %DynamicObject) As %String
{
    If '$IsObject(pArgs) || (pArgs.%GetTypeOf(..#TYPEFIELD) '= "string") Quit ""
    Quit pArgs.%Get(..#TYPEFIELD)
}

/// <p>The only keys a key write's body may carry: the members of type <var>pType</var>
/// (<method>OcuPilot.Area.Security.WalletKeyRules.KeyFields</method>) and, on a create, its
/// <code>Name</code> and <code>Type</code>; a replace's <code>Type</code> is accepted too and checked
/// against the stored one. <var>pCreates</var> is 1 for a create.</p>
ClassMethod AllowedFields(pType As %String, pCreates As %Boolean) As %List
{
    Quit $ClassMethod(..#RULES, "KeyFields", pType, pCreates) _ $ListBuild(..#TYPEFIELD) _ $Select(pCreates: $ListBuild(..#IDARGUMENT), 1: "")
}

/// <p>An error status with <var>pHttpStatus</var> 400 and the fault
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter> for the first key of <var>pArgs</var>
/// outside <var>pAllowed</var>; otherwise <code>$$$OK</code>.</p>
ClassMethod Unexpected(pArgs As %DynamicObject, pAllowed As %List, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $ListFind(pAllowed, tKey) Continue
        Set pHttpStatus = 400
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)
        Set tDetail = {"violations": []}
        Do tDetail.%Get("violations").%Push({"field": (tKey), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)})
        Do pFault.%Set("detail", tDetail)
        Quit
    }
    If $IsObject($Get(pFault)) Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
    Quit $$$OK
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make to <var>pName</var> carrying
/// <var>pPayload</var> and <var>pDiff</var>, through the class <var>pProhibited</var>; a
/// <code>PROHIBITED.*</code> verdict is an error status with a 403 fault.</p>
ClassMethod Prohibited(pToolClass As %String, pName As %String, pPayload As %DynamicObject, pDiff As %DynamicArray, pProhibited As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(..#DESCRIPTORCLASS, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(..#DESCRIPTORCLASS, "Scope")), pName, .tTargetRef)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(pProhibited, "Prohibits", $Parameter(pToolClass, "TOOLNAME"), tTargetRef, pPayload.%ToJSON(), pDiff.%ToJSON(), .tProhibits, .tCode)
    If $$$ISERR(tSC) Quit tSC
    If 'tProhibits Quit $$$OK
    Set pHttpStatus = 403
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode))
    Quit $$$ERROR($$$GeneralError, tCode)
}

/// <p>Issue tool <var>pToolClass</var>'s own write for <var>pName</var> with <var>pBody</var>, through
/// <var>pPort</var>; <var>pWritten</var> is the port's answer.</p>
ClassMethod Send(pToolClass As %String, pName As %String, pBody As %DynamicObject, pPort As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pWritten) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery($ClassMethod(pToolClass, "IdParam")) = pName
    Quit $ClassMethod(pPort, "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "WriteType"), .tQuery, pBody, .pWritten, .pHttpStatus, .pFault)
}

/// <p>The caller's own body fields, minus the identifying argument, <code>Type</code> and every name in
/// <var>pSecrets</var>, as one <class>%DynamicObject</class>: what AD-10's set is asked about. It is not
/// the composed body, so a field the tool does not admit reaches the set rather than being silently
/// dropped.</p>
ClassMethod CallerFields(pArgs As %DynamicObject, pSecrets As %List = "") As %DynamicObject
{
    Set tFields = {}
    If '$IsObject(pArgs) Quit tFields
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If (tKey = ..#IDARGUMENT) || (tKey = ..#TYPEFIELD) Continue
        If $ListFind(pSecrets, tKey) Continue
        Set tType = pArgs.%GetTypeOf(tKey)
        If (tType = "object") || (tType = "array") {
            Do tFields.%Set(tKey, pArgs.%Get(tKey))
        } Else {
            Do tFields.%Set(tKey, pArgs.%Get(tKey), tType)
        }
    }
    Set tValue = ""
    Quit tFields
}

/// <p>Render <var>pViolations</var> as one 422 envelope carrying every broken rule in
/// <code>detail.violations</code>, each a <code>{field, code, reason}</code> object (AD-39).</p>
ClassMethod RenderViolations(ByRef pViolations) As %Status
{
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.pViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.WalletKeyError).#REASONVALIDATION, ##class(OcuPilot.Api.WalletKeyError).#VALIDATION, tDetail)
}

}
