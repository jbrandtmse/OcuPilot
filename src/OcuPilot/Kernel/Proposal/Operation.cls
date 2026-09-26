/// <p>The executed write, as one operation two callers reach (AD-53). The agent's caller is
/// <class>OcuPilot.Kernel.Proposal.Confirm</class>, which claims a proposal around it; the screen's
/// is <class>OcuPilot.Api.ScreenAction</class>, which is user-originated by construction and claims
/// nothing.</p>
/// <p><b>Three halves, in this order, and the caller's own gates go between them.</b>
/// <method>Read</method> takes the target fresh through the port the tool declares (AD-52);
/// <method>Gate</method> decides whether the write may happen -- the caller's own privileges
/// (AD-8) and then AD-10's prohibited set against that target; <method>Apply</method> issues the
/// request. What sits between <method>Gate</method> and <method>Apply</method> is the caller's:
/// for the agent, the restraint verdict, the conversation, the definition, the fingerprint
/// re-match, the atomic claim and the ledger row (AD-6, AD-30, AD-34, AD-41); for the screen,
/// nothing at all.</p>
/// <p><b>Why the difference is principled rather than convenient</b> (AD-53). AD-6's proposal
/// exists because a <i>model</i> asked for the write and a human must review a server-computed
/// diff first; a person pressing a row action has expressed the intent directly, which is AD-49's
/// reasoning for a self-service action and AD-40's for confirm itself. AD-15's marker distinguishes
/// an agent write from a human one, so a screen action -- which is the human write -- emits none.
/// And FR-20 publishes "all screens continue to work with the agent disabled", so the kill switch
/// and enforced read-only are the agent caller's gates alone.</p>
/// <p><b>What both callers share is here, and nowhere else</b>: AD-10's set is refused "whatever
/// the caller", so a screen action cannot reach a prohibited effect by not being a tool.</p>
/// <p>Every method takes the port default and the prohibited class as arguments rather than
/// reading a seam of its own, so a caller's overridable seams keep deciding what a fixture arms
/// (<method>OcuPilot.Kernel.Proposal.Confirm.PortClass</method>,
/// <method>OcuPilot.Kernel.Proposal.Confirm.ProhibitedClassName</method>,
/// <method>OcuPilot.Kernel.Proposal.Confirm.HoldsPair</method>). This class holds no seam and no
/// state.</p>
Class OcuPilot.Kernel.Proposal.Operation Extends %RegisteredObject
{

/// <p>The class a write tool's port declaration lives on, whose own value is the default every
/// shipped tool carries (AD-52).</p>
Parameter WRITETOOLBASE = "OcuPilot.Screen.Tool.Write";

/// <p>The admin request type the fresh read is made with when the tool declares none (AD-36's
/// single-object <code>GET</code>).</p>
Parameter READTYPE = "GET";

/// <p>The admin request type the write is issued with when the tool declares none: the merge
/// write every body-taking tool makes (AD-51).</p>
Parameter WRITETYPE = "PUT";

/// <p>The port <var>pToolClass</var> declares its target lives behind (AD-52), or
/// <var>pDefaultPort</var> where it declares the base's own default, names no class, or cannot be
/// asked.</p>
/// <p><b>Caller contract:</b> <var>pDefaultPort</var> is the caller's own seam value, never a
/// literal read here, so a fixture that points its caller at an armed port keeps answering for
/// every tool that declares the shipped default.</p>
ClassMethod PortClassOf(pToolClass As %String, pDefaultPort As %String) As %String
{
    Set tPort = ""
    Try {
        If pToolClass '= "" Set tPort = $ClassMethod(pToolClass, "PortClass")
    } Catch {
        Set tPort = ""
    }
    If (tPort = "") || (tPort = $Parameter(..#WRITETOOLBASE, "PORTCLASS")) Quit pDefaultPort
    Quit tPort
}

/// <p>The admin request type <var>pToolClass</var>'s fresh read is made with (AD-51), or
/// <parameter>READTYPE</parameter> for a class that declares none or cannot be asked.</p>
ClassMethod ReadType(pToolClass As %String) As %String
{
    Set tType = ""
    Try {
        If pToolClass '= "" Set tType = $ClassMethod(pToolClass, "ReadType")
    } Catch {
        Set tType = ""
    }
    If tType = "" Quit ..#READTYPE
    Quit tType
}

/// <p>The admin request type <var>pToolClass</var>'s write is issued with (AD-51), or
/// <parameter>WRITETYPE</parameter> for a class that declares none or cannot be asked.</p>
ClassMethod WriteType(pToolClass As %String) As %String
{
    Set tType = ""
    Try {
        If pToolClass '= "" Set tType = $ClassMethod(pToolClass, "WriteType")
    } Catch {
        Set tType = ""
    }
    If tType = "" Quit ..#WRITETYPE
    Quit tType
}

/// <p>Whether <var>pToolClass</var>'s write carries a body (AD-51). A class that cannot be asked
/// sends one, which is every write that shipped before the declaration existed.</p>
ClassMethod SendsBody(pToolClass As %String) As %Boolean
{
    Set tSends = 1
    Try {
        If pToolClass '= "" Set tSends = ''$ClassMethod(pToolClass, "SendsBody")
    } Catch {
        Set tSends = 1
    }
    Quit tSends
}

/// <p>The body an action-style write made only of its declared secrets sends (AD-56 (i)), or
/// <code>""</code> for every tool that declares no
/// <parameter>OcuPilot.Screen.Tool.Write.SECRETBODY</parameter>.</p>
/// <p>The answer holds each <code>SECRETBODY</code> name that is also in <var>pSecretNames</var> --
/// the descriptor's declared secrets, which is the one list the confirm channel and the screen's
/// value channel are closed to -- and that <var>pSupplied</var> carries as a scalar, under that
/// name and with that value exactly as supplied, and nothing else. A name either list lacks, and an
/// empty value, is not sent.</p>
/// <p><b>Caller contract:</b> called at the write and nowhere earlier, so the secret exists as this
/// request's local alone: it is never stored, digested, diffed or logged (AD-6, AD-35). A class that
/// cannot be asked sends none.</p>
ClassMethod SecretBody(pToolClass As %String, pSupplied As %DynamicObject, pSecretNames As %List) As %DynamicObject
{
    Set tBody = ""
    Try {
        If pToolClass = "" Quit
        Set tNames = $ClassMethod(pToolClass, "SecretBodyNames")
        If tNames = "" Quit
        Set tBody = {}
        If '$IsObject(pSupplied) || 'pSupplied.%IsA("%Library.DynamicObject") Quit
        For tI = 1:1:$ListLength(tNames) {
            Set tName = $List(tNames, tI)
            If '$ListFind(pSecretNames, tName) Continue
            Set tType = pSupplied.%GetTypeOf(tName)
            If (tType = "unassigned") || (tType = "object") || (tType = "array") Continue
            ; An empty secret is not a secret supplied: it is left out, so the vendor's own
            ; required-field refusal answers rather than a blank password being set.
            If pSupplied.%Get(tName) = "" Continue
            Do tBody.%Set(tName, pSupplied.%Get(tName), tType)
        }
    } Catch {
        Set tBody = ""
    }
    Quit tBody
}

/// <p>Whether <var>pToolClass</var>'s write opens or closes the audit channel AD-15 marks through,
/// so its caller records the observed marking fact after it (AD-53). Read from the tool's own
/// <code>MOVESMARKING</code> parameter; <code>""</code>, an undeclared parameter and a class that
/// cannot be asked all answer 0.</p>
ClassMethod MovesMarking(pToolClass As %String) As %Boolean
{
    Set tMoves = 0
    Try {
        If pToolClass '= "" Set tMoves = ''$Parameter(pToolClass, "MOVESMARKING")
    } Catch {
        Set tMoves = 0
    }
    Quit tMoves
}

/// <p>The AD-14 action <var>pToolClass</var>'s write performs, or <code>""</code> for a class that
/// cannot be asked -- which leaves the answer carrying no action and the client publishing its own
/// default.</p>
ClassMethod ChangeAction(pToolClass As %String) As %String
{
    Set tAction = ""
    Try {
        If pToolClass '= "" Set tAction = $ClassMethod(pToolClass, "ChangeAction")
    } Catch {
        Set tAction = ""
    }
    Quit tAction
}

/// <p>The query <var>pToolClass</var>'s port is asked its question with: the identifying parameter
/// <var>pIdParam</var> set to <var>pIdValue</var>, plus whatever the tool's own
/// <method>OcuPilot.Screen.Tool.Write.PortQuery</method> adds from the payload
/// <var>pPayloadJson</var> (AD-52).</p>
/// <p>A class that cannot be asked adds nothing, which is the answer every shipped tool against an
/// admin endpoint gives: the vendor identifies a target by the one parameter already set.</p>
ClassMethod Query(pToolClass As %String, pIdParam As %String, pIdValue As %String, pPayloadJson As %String, Output pQuery)
{
    Kill pQuery
    Set pQuery(pIdParam) = pIdValue
    Try {
        If pToolClass = "" Quit
        Do $ClassMethod(pToolClass, "PortQuery", ..ParsedObject(pPayloadJson), .pQuery)
    } Catch {
        ; Deliberately empty: a tool that cannot answer adds no parameter, and the port refuses the
        ; call it then receives rather than issuing a write with no subject.
    }
}

/// <p>The target at <var>pIdValue</var> as <var>pToolClass</var>'s own read type answers it now, in
/// <var>pFresh</var>.</p>
/// <p><b>Caller contract:</b> the read goes through the port the tool declares and carries the
/// tool's own port query, so the mint's read, the confirm's fingerprint re-read and a screen
/// action's read are one read of one target through one port (AD-36, AD-52). An error status is a
/// target that could not be read -- gone, or refused -- and no caller writes after one.</p>
ClassMethod Read(pToolClass As %String, pDefaultPort As %String, pEndpoint As %String, pIdParam As %String, pIdValue As %String, pPayloadJson As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..ReadAt(pToolClass, ..PortClassOf(pToolClass, pDefaultPort), pEndpoint, pIdParam, pIdValue, pPayloadJson, .pFresh, .pHttpStatus, .pFault)
}

/// <p>Read through <var>pPort</var>, a port the caller has already resolved. A caller that
/// resolves the port through a seam of its own -- the confirm, whose <method>PortClassOf</method>
/// a test overrides to record what reaches the port -- calls this form, so the read and the write
/// both reach the port it resolved; <method>Read</method> resolves the tool's declared port and
/// calls this.</p>
ClassMethod ReadAt(pToolClass As %String, pPort As %String, pEndpoint As %String, pIdParam As %String, pIdValue As %String, pPayloadJson As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Do ..Query(pToolClass, pIdParam, pIdValue, pPayloadJson, .tQuery)
    Set tReadParam = ..ReadIdParamOf(pToolClass, pIdParam)
    If tReadParam '= pIdParam {
        Kill tQuery(pIdParam)
        Set tQuery(tReadParam) = pIdValue
    }
    Quit ..ReadTarget(pToolClass, pPort, pEndpoint, .tQuery, pIdValue, .pFresh, .pHttpStatus, .pFault)
}

/// <p>The query parameter <var>pToolClass</var>'s fresh read sends the id under
/// (<method>OcuPilot.Screen.Tool.Write.ReadIdParam</method>), or <var>pIdParam</var> for a class
/// that declares none or cannot be asked.</p>
ClassMethod ReadIdParamOf(pToolClass As %String, pIdParam As %String) As %String
{
    Set tParam = ""
    Try {
        If (pToolClass '= "") && ##class(%Dictionary.CompiledMethod).%ExistsId(pToolClass _ "||ReadIdParam") Set tParam = $ClassMethod(pToolClass, "ReadIdParam")
    } Catch {
        Set tParam = ""
    }
    If tParam = "" Quit pIdParam
    Quit tParam
}

/// <p>The row key <var>pToolClass</var>'s list-type fresh read is filtered by, or <code>""</code>
/// for a one-object read and for a class that cannot be asked.</p>
ClassMethod ReadRowKeyOf(pToolClass As %String) As %String
{
    Set tKey = ""
    Try {
        If (pToolClass '= "") && ##class(%Dictionary.CompiledMethod).%ExistsId(pToolClass _ "||ReadRowKey") Set tKey = $ClassMethod(pToolClass, "ReadRowKey")
    } Catch {
        Set tKey = ""
    }
    Quit tKey
}

/// <p>The one fresh read the operation's callers make -- the mint, the confirm's re-read, the
/// prohibited set and a screen action (AD-51, AD-52): <var>pToolClass</var>'s read type against
/// <var>pEndpoint</var> through <var>pPort</var> with the query <var>pQuery</var>, answering the
/// target in <var>pFresh</var>.</p>
/// <p>For a tool that declares a row key the read answers an array, and <var>pFresh</var> is the
/// one row whose key equals <var>pIdValue</var> without regard to case; an array holding no such
/// row, and an answer that is not an array, are 404 <code>PORT.NOTFOUND</code>, so every caller
/// reads absence exactly as a one-object read's 404.</p>
ClassMethod ReadTarget(pToolClass As %String, pPort As %String, pEndpoint As %String, ByRef pQuery, pIdValue As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $ClassMethod(pPort, "Invoke", pEndpoint, ..ReadType(pToolClass), .pQuery, "", .tAnswer, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tRowKey = ..ReadRowKeyOf(pToolClass)
    If tRowKey = "" {
        Set pFresh = $Get(tAnswer)
        Quit tSC
    }
    Set tWanted = $ZConvert(pIdValue, "U")
    If $IsObject($Get(tAnswer)) && tAnswer.%IsA("%Library.DynamicArray") {
        Set tIterator = tAnswer.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") Continue
            If $ZConvert(tRow.%Get(tRowKey), "U") '= tWanted Continue
            Set pFresh = tRow
            Quit
        }
    }
    If $IsObject(pFresh) Quit $$$OK
    Set pHttpStatus = 404
    Do ##class(OcuPilot.Kernel.Fault).Outcome(pHttpStatus, $$$OK, .pFault, .tDetail)
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
}

/// <p>Whether the write <var>pTool</var> would make against <var>pTargetRef</var> may happen, for
/// <var>pUser</var>, with <var>pRefused</var> 0 when it may.</p>
/// <p><b>Two gates, in this order, and the order is load-bearing</b> (AD-8, AD-10, DW-1208). The
/// declared pair set is checked first, because the prohibited set below reads live state through
/// the port and the port's own gate requires the very pair this check names -- so a caller who has
/// lost it would otherwise reach that read and be answered a generic internal failure, where AD-8
/// requires the denial to name the pair that failed. The prohibited set is then asked about the
/// resolved target, inside whatever transition the caller is running, and never at the call that
/// produced the write (AD-40).</p>
/// <p><b>Caller contract:</b> <var>pPayloadJson</var>, <var>pDiffJson</var> and
/// <var>pArgumentsJson</var> are the write's own, never the request's -- for the agent the stored
/// proposal row's, for a screen action the ones the route just computed from the fresh read.
/// <var>pProhibitedClass</var> and <var>pHolderClass</var> are the caller's seams: the prohibited
/// set to ask, and the class whose <code>HoldsPair</code> answers what the user holds.
/// <var>pPairs</var> is the resolved set, which the caller records on its own ledger row where it
/// keeps one. An error status means the question could not be answered and the caller must not
/// write.</p>
ClassMethod Gate(pTool As %DynamicObject, pTargetRef As %String, pPayloadJson As %String, pDiffJson As %String, pArgumentsJson As %String, pUser As %String, pProhibitedClass As %String, pHolderClass As %String, Output pPairs As %List, Output pRefused As %Boolean, Output pHttpStatus As %Integer, Output pCode As %String, Output pDetail As %DynamicObject) As %Status
{
    Set pPairs = ""
    Set pRefused = 0
    Set pHttpStatus = 0
    Set pCode = ""
    Set pDetail = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pTool) {
            Set tSC = $$$ERROR($$$GeneralError, "the operation was gated with no resolved tool")
            Quit
        }
        Set tToolName = pTool.%Get("name")
        Set tSC = ..RequiredPairsOf(pTool, pArgumentsJson, .pPairs)
        If $$$ISERR(tSC) Quit
        Set tFailedPair = ..MissingPair(pUser, pPairs, pHolderClass)
        If tFailedPair '= "" {
            Set pRefused = 1
            Set pHttpStatus = 403
            Set pCode = ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE
            Set pDetail = {}
            Do pDetail.%Set("failedPair", tFailedPair, "string")
            Quit
        }

        ; AD-10's call site for every write; the copy-out draft (Kernel.Proposal.Draft.Take) is the
        ; only other. The set is handed the write's own tool, target, payload and diff, and nothing
        ; of the request's.
        If pProhibitedClass = "" Quit
        Set tProhibitSC = $ClassMethod(pProhibitedClass, "Prohibits", tToolName, pTargetRef, pPayloadJson, pDiffJson, .tProhibits, .tProhibitCode)
        If $$$ISERR(tProhibitSC) {
            ; The underlying text, not just "could not be read": the set reads live state, so the
            ; cause is a property of the instance at this moment and is the only thing a reader of
            ; the log can act on. The caller renders a generic reason (AD-12).
            Set tSC = $$$ERROR($$$GeneralError, "the prohibited set could not be read: " _ $System.Status.GetErrorText(tProhibitSC))
            Quit
        }
        If tProhibits {
            Set pRefused = 1
            Set pHttpStatus = 403
            Set pCode = tProhibitCode
        }
    } Catch ex {
        Set pRefused = 0
        Set pHttpStatus = 0
        Set pCode = ""
        Set pDetail = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Issue the write: <var>pToolClass</var>'s declared request type against <var>pEndpoint</var>,
/// through the port it declares, identified by <var>pIdParam</var>/<var>pIdValue</var> and
/// carrying <var>pBody</var> (<code>""</code> for an action-style write, which sends none).</p>
/// <p><b>Caller contract:</b> every gate has already answered. There is no automatic re-attempt
/// here and none anywhere else: for the agent caller the claim has committed and the token is
/// spent by the time this runs (AD-34).</p>
ClassMethod Apply(pToolClass As %String, pDefaultPort As %String, pEndpoint As %String, pIdParam As %String, pIdValue As %String, pPayloadJson As %String, pBody As %DynamicObject, Output pWritten As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pFresh As %DynamicObject = "") As %Status
{
    Quit ..ApplyAt(pToolClass, ..PortClassOf(pToolClass, pDefaultPort), pEndpoint, pIdParam, pIdValue, pPayloadJson, pBody, .pWritten, .pHttpStatus, .pFault, pFresh)
}

/// <p>Apply through <var>pPort</var>, a port the caller has already resolved. A caller that
/// resolves the port through a seam of its own -- the confirm, whose <method>PortClassOf</method>
/// a test overrides to record what reaches the port -- calls this form, so the read and the write
/// both reach the port it resolved; <method>Apply</method> resolves the tool's declared port and
/// calls this.</p>
/// <p><var>pFresh</var> is the target as this operation's fresh read answered it before the write.
/// Once the write reads OK the tool's own <method>OcuPilot.Screen.Tool.Write.AfterWrite</method> is
/// run with it, through the same port; its failure is this call's failure, with its own
/// <var>pHttpStatus</var> and <var>pFault</var>, though the write has been applied.
/// <var>pApplied</var> is 1 once the write itself has read OK, whatever <code>AfterWrite</code>
/// answers, so a caller that marks applied writes (AD-15) marks this one too.</p>
ClassMethod ApplyAt(pToolClass As %String, pPort As %String, pEndpoint As %String, pIdParam As %String, pIdValue As %String, pPayloadJson As %String, pBody As %DynamicObject, Output pWritten As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pFresh As %DynamicObject = "", Output pApplied As %Boolean) As %Status
{
    Set pWritten = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pApplied = 0
    Do ..Query(pToolClass, pIdParam, pIdValue, pPayloadJson, .tQuery)
    Set tSC = $ClassMethod(pPort, "Invoke", pEndpoint, ..WriteType(pToolClass), .tQuery, pBody, .pWritten, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pApplied = 1
    If (pToolClass = "") || '##class(%Dictionary.CompiledMethod).%ExistsId(pToolClass _ "||AfterWrite") Quit tSC
    Set tAfterSC = $ClassMethod(pToolClass, "AfterWrite", pPort, pEndpoint, pIdParam, pIdValue, pFresh, .tAfterHttp, .tAfterFault)
    If $$$ISOK(tAfterSC) Quit tSC
    Set pHttpStatus = $Select(+$Get(tAfterHttp): +tAfterHttp, 1: 500)
    Set pFault = $Get(tAfterFault)
    Quit tAfterSC
}

/// <p>The pairs the write of <var>pTool</var> with the stored arguments <var>pArgumentsJson</var>
/// requires (AD-8): the tool's declared pairs, then the pairs its arguments add (AD-48), in that
/// order. This is the set <method>Gate</method> checks and the one a mint records.</p>
/// <p>An error status means either half could not be read; <var>pPairs</var> is then
/// <code>""</code> and a caller must not read it as "requires nothing".</p>
ClassMethod RequiredPairsOf(pTool As %DynamicObject, pArgumentsJson As %String, Output pPairs As %List) As %Status
{
    Set pPairs = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pTool) {
            Set tSC = $$$ERROR($$$GeneralError, "the privilege pairs were asked for with no resolved tool")
            Quit
        }
        Set tToolName = pTool.%Get("name")
        Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(pTool, .tPairsResolved)
        If 'tPairsResolved {
            Set tSC = $$$ERROR($$$GeneralError, "the privilege pairs of " _ tToolName _ " could not be read")
            Quit
        }
        ; AD-8, AD-48. A tool whose requirement depends on its own argument -- the namespace a
        ; delete names -- declares that half through ArgumentPairs, resolved here from the write's
        ; own arguments. Empty for every tool whose requirement is its screen's alone.
        Set tArgumentPairs = ##class(OcuPilot.Screen.Tool.Registry).ArgumentPairs(pTool, ..ParsedObject(pArgumentsJson), .tArgumentsResolved)
        If 'tArgumentsResolved {
            Set tSC = $$$ERROR($$$GeneralError, "the argument privilege pairs of " _ tToolName _ " could not be read")
            Quit
        }
        Set pPairs = tPairs _ tArgumentPairs
    } Catch ex {
        Set pPairs = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The first pair of <var>pPairs</var> that <var>pUser</var> does not hold, as
/// <code>resource:permission</code>, or <code>""</code> (AD-8). <var>pHolderClass</var>'s own
/// <code>HoldsPair</code> answers each one, so a caller's seam decides.</p>
ClassMethod MissingPair(pUser As %String, pPairs As %List, pHolderClass As %String) As %String
{
    Set tFailed = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tPair = $List(pPairs, tI)
        If '..Holds(pUser, $List(tPair, 1), $List(tPair, 2), pHolderClass) {
            Set tFailed = $List(tPair, 1) _ ":" _ $List(tPair, 2)
            Quit
        }
    }
    Quit tFailed
}

/// <p>Whether <var>pUser</var> holds <var>pPermission</var> on <var>pResource</var> right now, as
/// <var>pHolderClass</var> answers it, or as this class does when the caller names none.</p>
ClassMethod Holds(pUser As %String, pResource As %String, pPermission As %String, pHolderClass As %String) As %Boolean
{
    Set tHolds = 0
    Try {
        If pHolderClass '= "" Quit
        Set tHolds = ($SYSTEM.Security.CheckUserPermission(pUser, pResource, pPermission) = 1)
    } Catch {
        Set tHolds = 0
    }
    If pHolderClass = "" Quit tHolds
    Try {
        Set tHolds = ''$ClassMethod(pHolderClass, "HoldsPair", pUser, pResource, pPermission)
    } Catch {
        Set tHolds = 0
    }
    Quit tHolds
}

/// <p><var>pText</var> parsed as a JSON object, or <code>{}</code> when it is empty or
/// unreadable.</p>
ClassMethod ParsedObject(pText As %String) As %DynamicObject
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

}
