/// <p>The LDAP and Kerberos editor's Saves (AD-55): <code>PUT /ldap/:id</code> changes one LDAP
/// configuration through <class>OcuPilot.Screen.Tool.LdapUpdate</class> and <code>POST /ldap</code>
/// creates one through <class>OcuPilot.Screen.Tool.LdapCreate</class>, the tools the agent's
/// <code>security.ldap.update</code> and <code>security.ldap.create</code> proposals are confirmed
/// through. A search password the body carries is written afterwards, by
/// <class>OcuPilot.Screen.Tool.LdapPassword</class>'s own operation (AD-56 (i)).</p>
/// <p><b>It resolves everything about each write from the tool class</b>: the endpoint, the request
/// types, the port, the settable fields, the merge or the composed body. It mints no proposal and
/// takes no confirm token. It runs, in <class>OcuPilot.Area.Security.SslSave</class>'s order: the
/// caller's pairs, the tool's included (AD-8, AD-44), the password taken out of the body, the fresh
/// read, a check that the body carries only the tool's settable keys, the rules, the merge (AD-4)
/// or the complete set (AD-54), AD-10's prohibited set, the port, then the password write, and the
/// read-back (AD-58), which reports the password written and never reads it.</p>
/// <p>Seams a subclass may override: <method>PortClass</method> and
/// <method>ProhibitedClass</method>. Production overrides neither.</p>
Class OcuPilot.Area.Security.LdapSave Extends %RegisteredObject
{

/// <p>The tool class the edit Save resolves the write through (AD-55).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.LdapUpdate";

/// <p>The tool class the create Save resolves the write through (AD-54, AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.LdapCreate";

/// <p>The tool class whose operation writes the search password (AD-56 (i)).</p>
Parameter PASSWORDTOOL = "OcuPilot.Screen.Tool.LdapPassword";

/// <p>The screen whose declared pairs gate the routes, and whose entity type and scope the
/// prohibited set's reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LdapConfigForm";

/// <p>The input property that names the target.</p>
Parameter IDARGUMENT = "Name";

/// <p>The body key the search password travels under; it is taken out before any rule reads the
/// body.</p>
Parameter PASSWORDFIELD = "LDAPSearchPassword";

/// <p>The rules class the Save applies.</p>
Parameter RULES = "OcuPilot.Area.Security.LdapRules";

/// <p>The port the fresh read and the write go through, which is the tool's own declaration
/// (AD-52). Overridable so a fixture can hold the write; production never overrides it.</p>
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

/// <p>Answer <code>PUT /ldap/:id</code>: change the LDAP configuration <var>pId</var> -- one path
/// segment, decoded once here (AD-13) -- from the body, and answer <code>{name, readBack}</code>
/// with 200 (AD-58), plus <code>secretsRefused</code> when the password write was refused. A broken
/// rule is one 422 <parameter>OcuPilot.Api.Error.LDAPVALIDATION</parameter> envelope; a key outside
/// the tool's settable fields and the password is 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter>; a configuration the instance does
/// not hold is 404 <parameter>OcuPilot.Api.Error.LDAPABSENT</parameter>; a prohibited change is 403
/// with its <code>PROHIBITED.*</code> code.</p>
/// <p>The body's <code>LDAPSearchPassword</code> is the password to set, or <code>""</code> to clear
/// it; a body without it leaves the password as it is.</p>
ClassMethod HandleUpdate(pId As %String) As %Status
{
    Set tSC = $$$OK
    Set (tPassword, tBody) = ""
    Try {
        Set tGateSC = ..Gate(..#UPDATETOOL, .tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tHasPassword = ..TakePassword(tBody, .tPassword, .tShaped)
        Set tName = ##class(OcuPilot.Kernel.EntityId).Decode(pId)
        Set tPerformSC = ..Update(tName, tBody, .tHttp, .tFault, .tViolations, .tWrite, tShaped)
        Set tBody = ""
        If $$$ISERR(tPerformSC) && (+$Get(tHttp) = 404) && ($Get(tViolations) = 0) {
            Set tPassword = ""
            Set tSC = ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONLDAPABSENT, ##class(OcuPilot.Api.Error).#LDAPABSENT)
            Quit
        }
        Set (tSecretsReason, tReadBack) = ""
        If $$$ISOK(tPerformSC) && '$Get(tViolations) {
            If tHasPassword Set tSecretsReason = ..StorePassword(tName, tPassword)
            Set tPassword = ""
            Set tStored = $Select(tHasPassword && (tSecretsReason = ""): $ListBuild(..#PASSWORDFIELD), 1: "")
            ; AD-58: the configuration read back after the Save's last write, over what its own write
            ; sent; a Save that sent only the password reports it written, as a secret-only write is.
            If $Data(tWrite("sent")) {
                Set tReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(..#UPDATETOOL, tName, tWrite("sent"), $Get(tWrite("fresh")), ..PortClass(), $Get(tWrite("answer")), $Get(tWrite("http")), tStored)
            } ElseIf tStored '= "" {
                Set tReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(..#PASSWORDTOOL, tName, {}, "", ..PortClass(), "", 0, tStored)
            }
        }
        Set tPassword = ""
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 200, tName, tSecretsReason, tReadBack)
    } Catch ex {
        Set (tPassword, tBody) = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>POST /ldap</code>: create one configuration from the body, named by its
/// <code>Name</code>, and answer <code>{name, readBack}</code> with 201 (AD-58), plus
/// <code>secretsRefused</code> when the password write was refused. <code>name</code> is the name
/// the instance stores. Refusals are <method>HandleUpdate</method>'s, with
/// <parameter>OcuPilot.Api.LdapError.NAMETAKEN</parameter> for a name already held.</p>
ClassMethod HandleCreate() As %Status
{
    Set tSC = $$$OK
    Set (tPassword, tBody) = ""
    Try {
        Set tGateSC = ..Gate(..#CREATETOOL, .tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        If '..Body(.tBody) {
            Set tSC = ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#REASONAGENTBADBODY, ##class(OcuPilot.Api.Error).#AGENTBADBODY)
            Quit
        }
        Set tHasPassword = ..TakePassword(tBody, .tPassword, .tShaped)
        Set tName = ""
        If tBody.%GetTypeOf(..#IDARGUMENT) = "string" Set tName = tBody.%Get(..#IDARGUMENT)
        Do tBody.%Remove(..#IDARGUMENT)
        Set tPerformSC = ..Create(tName, tBody, .tHttp, .tFault, .tViolations, .tWrite, tShaped)
        Set tBody = ""
        Set (tSecretsReason, tReadBack) = ""
        If $$$ISOK(tPerformSC) && '$Get(tViolations) {
            ; A new configuration holds no password, so only a value entered is written.
            If tHasPassword && (tPassword '= "") Set tSecretsReason = ..StorePassword(tName, tPassword)
            Set tStored = $Select(tHasPassword && (tPassword '= "") && (tSecretsReason = ""): $ListBuild(..#PASSWORDFIELD), 1: "")
            Set tPassword = ""
            ; AD-58: the configuration read back after the Save's last write, over what its own write sent.
            Set tReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(..#CREATETOOL, tName, $Get(tWrite("sent"), {}), "", ..PortClass(), $Get(tWrite("answer")), $Get(tWrite("http")), tStored)
        }
        Set tPassword = ""
        Set tSC = ..Answer(tPerformSC, .tViolations, $Get(tHttp), $Get(tFault), 201, tName, tSecretsReason, tReadBack)
    } Catch ex {
        Set (tPassword, tBody) = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Change the LDAP configuration <var>pName</var> by the fields <var>pArgs</var> sends, merged over
/// a fresh read by the tool's own <code>MergeUpdate</code>, so a field the caller did not send keeps
/// the instance's value and the body is the complete set (AD-4). Nothing is sent when no field
/// changed. <var>pPasswordShaped</var> 0 adds the password's shape violation.</p>
/// <p><b>Caller contract:</b> <var>pViolations</var> is the violation array (<code>pViolations(n) =
/// $ListBuild(field, code)</code>, count in <code>pViolations</code>); a non-zero count means
/// nothing was written. Otherwise an error status carries <var>pHttpStatus</var> and
/// <var>pFault</var>: 404 for an absent configuration, 400 for an undeclared key, 403 for a
/// prohibited change, and the port's own for a vendor refusal. Nothing is sent on any of them but
/// the last. On success <var>pWrite</var> carries <code>("fresh")</code>, the fresh read, and, when a
/// body was sent, <code>("sent")</code>, <code>("answer")</code> and <code>("http")</code>, for the
/// caller's read-back after its own password write (AD-58).</p>
ClassMethod Update(pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pWrite, pPasswordShaped As %Boolean = 1) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pWrite
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#UPDATETOOL
        Set tSC = $ClassMethod(..#RULES, "NameViolation", pName, .pViolations)
        If $$$ISERR(tSC) || (pViolations > 0) Quit
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "ReadType"), .tQuery, "", .tFresh, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") {
            Set pHttpStatus = 404
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#LDAPABSENT)
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""
        Set pWrite("fresh") = tFresh

        Set tSettable = $ClassMethod(tClass, "SettableFields")
        Set tSC = ..Undeclared(pArgs, tSettable, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tChanged = $ClassMethod(..#RULES, "KerberosFilled", $ClassMethod(..#RULES, "Changed", pArgs, tFresh), tFresh)
        Set tChanged = $ClassMethod(..#RULES, "Changed", tChanged, tFresh)
        Set tSC = $ClassMethod(..#RULES, "Validate", pName, tChanged, tFresh, .pViolations)
        If $$$ISERR(tSC) Quit
        If 'pPasswordShaped Do ..Add(.pViolations, ..#PASSWORDFIELD, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        If pViolations > 0 Quit
        ; Only the password moves: the merge has nothing to send.
        If tChanged.%Size() = 0 Quit

        Set tSC = $ClassMethod(tClass, "MergeUpdate", tFresh, tChanged, ..#IDARGUMENT, tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
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
        If $$$ISERR(tSC) Quit
        Set pWrite("sent") = tPayload
        Set pWrite("answer") = $Get(tAnswer)
        Set pWrite("http") = pHttpStatus
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the LDAP configuration <var>pName</var> from <var>pArgs</var>, whose password and name
/// have been taken out: the fresh read must find the name free (AD-54), and the body is the
/// complete set the tool composes (<method>OcuPilot.Area.Security.LdapRules.Compose</method>).
/// <var>pPasswordShaped</var> 0 adds the password's shape violation.</p>
/// <p><b>Caller contract:</b> as <method>Update</method>'s, with
/// <parameter>OcuPilot.Api.LdapError.NAMETAKEN</parameter> for a name already held and no 404. On
/// success <var>pWrite</var> carries <code>("sent")</code>, <code>("answer")</code> and
/// <code>("http")</code>.</p>
ClassMethod Create(pName As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pWrite, pPasswordShaped As %Boolean = 1) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Kill pWrite
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        Set tClass = ..#CREATETOOL
        Set tSC = $ClassMethod(..#RULES, "NameViolation", pName, .pViolations)
        If $$$ISERR(tSC) || (pViolations > 0) Quit

        ; AD-54: the fresh read must find the name free.
        Set tSC = $ClassMethod(..#RULES, "Taken", pName, .tTaken)
        If $$$ISERR(tSC) Quit
        If tTaken {
            Do ..Add(.pViolations, ..#IDARGUMENT, ##class(OcuPilot.Api.LdapError).#NAMETAKEN)
            Quit
        }

        Set tSettable = $ClassMethod(tClass, "SettableFields")
        Set tSC = ..Undeclared(pArgs, tSettable, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tSC = $ClassMethod(tClass, "ComposeCreate", pArgs, ..#IDARGUMENT, tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the create's payload could not be composed: " _ tProblem)
            Quit
        }
        Set tSC = $ClassMethod(..#RULES, "Validate", pName, tPayload, "", .pViolations)
        If $$$ISERR(tSC) Quit
        If 'pPasswordShaped Do ..Add(.pViolations, ..#PASSWORDFIELD, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        If pViolations > 0 Quit

        Set tSC = ..Prohibited(tClass, pName, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Kill tQuery
        Set tQuery($ClassMethod(tClass, "IdParam")) = pName
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tPayload, .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set pWrite("sent") = tPayload
        Set pWrite("answer") = $Get(tAnswer)
        Set pWrite("http") = pHttpStatus
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Write <var>pPassword</var> -- a new search password, or <code>""</code> to clear it -- for
/// configuration <var>pName</var> through the password tool's own operation: its pairs, AD-10's set
/// and its port, with a body of that secret alone (AD-56 (i)). Answer <code>""</code>, or the
/// refusal's sentence. The password is cleared from this method's locals before it returns, and
/// nothing here stores or logs it (AD-35).</p>
ClassMethod StorePassword(pName As %String, pPassword As %String) As %String
{
    Set tReason = ""
    Set (tBody, tSupplied) = ""
    Try {
        Set tClass = ..#PASSWORDTOOL
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($Parameter(tClass, "TOOLNAME"), .tTool)
        If $$$ISERR(tSC) || '$IsObject(tTool) {
            Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
            Quit
        }
        Set tDescriptor = $Parameter(tClass, "DESCRIPTORCLASS")
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(tDescriptor, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(tDescriptor, "Scope")), pName, .tTargetRef)
        If $$$ISERR(tSC) {
            Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
            Quit
        }
        Set tArgs = {}
        Do tArgs.%Set($ClassMethod(tClass, "IdArgument"), pName, "string")
        Set tGateSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, tTargetRef, "{}", "[]", tArgs.%ToJSON(), $Username, ..ProhibitedClass(), "", .tPairs, .tRefused, .tGateHttp, .tGateCode, .tGateDetail)
        If $$$ISERR(tGateSC) {
            Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
            Quit
        }
        If tRefused {
            Set tReason = ##class(OcuPilot.Kernel.Proposal.Write).ReasonFor(tGateCode)
            If tReason = "" Set tReason = ##class(OcuPilot.Api.Error).ReasonForToolCode(tGateCode)
            Quit
        }
        Set tSupplied = {}
        Do tSupplied.%Set(..#PASSWORDFIELD, pPassword, "string")
        Set tBody = ##class(OcuPilot.Kernel.Proposal.Operation).SecretBody(tClass, tSupplied, $ClassMethod(tDescriptor, "SecretArguments"))
        Set tSupplied = ""
        Set tWriteSC = ##class(OcuPilot.Kernel.Proposal.Operation).ApplyAt(tClass, ..PortClass(), $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), pName, "", tBody, .tWritten, .tHttp, .tFault)
        Set tBody = ""
        If $$$ISERR(tWriteSC) {
            Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
            If $IsObject($Get(tFault)) && (tFault.%Get("reason") '= "") Set tReason = tFault.%Get("reason")
        }
    } Catch ex {
        Set tReason = ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON
    }
    Set (tBody, tSupplied) = ""
    Quit tReason
}

/// <p>Remove <parameter>PASSWORDFIELD</parameter> from <var>pBody</var>: answer 1 when the body
/// carried it, with its value in <var>pPassword</var> (<code>""</code> clears the password), and 0
/// when it did not. <var>pShaped</var> is 0 when it carried something other than a string, which is
/// refused.</p>
ClassMethod TakePassword(pBody As %DynamicObject, Output pPassword As %String, Output pShaped As %Boolean) As %Boolean [ Private ]
{
    Set pPassword = ""
    Set pShaped = 1
    Set tType = pBody.%GetTypeOf(..#PASSWORDFIELD)
    If tType = "unassigned" Quit 0
    If tType = "string" {
        Set pPassword = pBody.%Get(..#PASSWORDFIELD)
    } Else {
        Set pShaped = 0
    }
    Do pBody.%Remove(..#PASSWORDFIELD)
    Quit pShaped
}

/// <p>Refuse every key of <var>pArgs</var> outside <var>pAllowed</var>: an error status with a 400
/// <parameter>OcuPilot.Api.Error.PORTFIELDUNEXPECTED</parameter> fault naming each key in
/// <code>detail.violations</code>, or <code>$$$OK</code>.</p>
ClassMethod Undeclared(pArgs As %DynamicObject, pAllowed As %List, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tRows = []
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $ListFind(pAllowed, tKey) Continue
        Do tRows.%Push({"field": (tKey), "code": (##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED), "reason": (##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)})
    }
    If tRows.%Size() = 0 Quit $$$OK
    Set pHttpStatus = 400
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, ##class(OcuPilot.Api.Error).#REASONPORTFIELDUNEXPECTED)
    Do pFault.%Set("detail", {"violations": (tRows)})
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
}

/// <p>Ask AD-10's set about the write tool <var>pToolClass</var> would make to <var>pName</var>
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

/// <p>Render the outcome of <method>Update</method> or <method>Create</method>: the violations as one
/// 422 envelope, a refusal as its own envelope, and success as <code>{name}</code> at
/// <var>pSuccess</var>, with <var>pSecretsReason</var> as <code>secretsRefused</code> when the
/// password write was refused and <var>pReadBack</var> as <code>readBack</code> when there is one
/// (AD-58).</p>
ClassMethod Answer(pSC As %Status, ByRef pViolations, pHttp As %Integer, pFault As %DynamicObject, pSuccess As %Integer, pName As %String, pSecretsReason As %String = "", pReadBack As %DynamicObject = "") As %Status [ Private ]
{
    If $Get(pViolations) > 0 Quit $ClassMethod(..#RULES, "RenderViolations", .pViolations)
    If $$$ISERR(pSC) {
        If '$IsObject(pFault) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
            Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
        }
        Quit ##class(OcuPilot.Api.Error).Render($Select(+pHttp: +pHttp, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
    }
    Set tAnswer = {}
    Do tAnswer.%Set("name", $ZConvert(pName, "L"), "string")
    If pSecretsReason '= "" Do tAnswer.%Set("secretsRefused", pSecretsReason, "string")
    If $IsObject(pReadBack) Do tAnswer.%Set("readBack", pReadBack)
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

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

/// <p>Refuse a caller who does not hold <parameter>DESCRIPTORCLASS</parameter>'s declared pairs, or
/// the pairs tool <var>pToolClass</var> declares beyond them -- its write's resource and the custom
/// resource of each classic page its <code>CLASSICPAGES</code> names (AD-8, AD-44) -- and the
/// password tool's, before anything is read or sent: <var>pRefused</var> 1 means the envelope is
/// written.</p>
ClassMethod Gate(pToolClass As %String, Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
        Set pRefused = 1
        Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
    }
    For tClass = pToolClass, ..#PASSWORDTOOL {
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
        If 'tResolved {
            Set pRefused = 1
            Quit
        }
        If '##class(OcuPilot.Screen.Gate).EvaluatePairs(tPairs, .tFailedPair) {
            Set pRefused = 1
            Quit
        }
    }
    If 'pRefused Quit $$$OK
    If tFailedPair = "" Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the privilege pairs of the LDAP tools could not be read")))
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

}
