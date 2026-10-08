/// <p>The port to the adjusted permission sets of screens (AD-64, AD-29, AD-51, AD-52, Story 20.15): the
/// only product class that writes <class>OcuPilot.Kernel.State.Access</class>, reached by the Screen
/// permissions row actions and the agent's three tools alike. It reads a screen's base set through
/// <method>OcuPilot.Screen.Gate.BasePairs</method> and names neither the registry nor any descriptor.</p>
/// <p><b>Its gate is fixed</b>: <parameter>PAIRS</parameter>, <code>%Development:USE</code> or
/// <code>%Admin_Secure:USE</code>, either one (<method>OcuPilot.Screen.Gate.AdjusterPairs</method>). A caller
/// holding neither is refused naming both, before the store is touched.</p>
/// <p>One endpoint, <parameter>ENDPOINT</parameter>, addressed by the screen's <code>toolIdentifier</code> under
/// <parameter>SCREENKEY</parameter>, and three types:</p>
/// <ul>
/// <li><code>GET</code> answers <code>{Screen, Pairs, Adjusted, Pair, Result}</code>: the pairs the screen
/// requires before the classic page's resource, whether they are an adjustment, and, when the query carries
/// <parameter>ADDKEY</parameter>, <parameter>REMOVEKEY</parameter> or <parameter>RESETKEY</parameter>, the
/// set that change would leave in <code>Result</code> (<code>Pair</code> echoes the pair named). A change the
/// rules refuse is refused here, so the mint, a screen action and a confirm's re-read all read one verdict.
/// A screen that cannot be adjusted (<method>OcuPilot.Screen.Gate.Adjustable</method>) is composed with no
/// check, so the prohibited set decides it.</li>
/// <li><code>PUT</code> applies <parameter>ADDKEY</parameter> or <parameter>REMOVEKEY</parameter> over the
/// stored set read now (<method>Apply</method>), writes the store while its row still carries the version
/// that read saw, and records <code>SecurityChange</code> with the pairs before and after (AD-15).</li>
/// <li><code>DELETE</code> removes the adjustment, refused 409 <code>ACCESS.NOTADJUSTED</code> when there is
/// none, and records <code>SecurityChange</code>.</li>
/// </ul>
/// <p>The rules: a set holds 1 to <parameter>OcuPilot.Api.AccessError.MAXPAIRS</parameter> pairs, each
/// <code>resource:permission</code> with the permission READ, WRITE or USE and a resource the instance
/// defines (<method>ResourceDefined</method>). Every refusal is a written reason (AD-39).</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>ResourceDefined</method> and
/// <method>LogFault</method>. Production overrides none.</p>
Class OcuPilot.Port.ScreenAccessPort Extends %RegisteredObject [ DependsOn = OcuPilot.Screen.Gate ]
{

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The port's own gate, <code>resource:permission</code> (AD-29).</p>
Parameter PAIRS = {##class(OcuPilot.Screen.Gate).AdjusterSpec()};

/// <p>The one endpoint.</p>
Parameter ENDPOINT = "Screen";

Parameter TYPEGET = "GET";

Parameter TYPEPUT = "PUT";

Parameter TYPEDELETE = "DELETE";

/// <p>The pair whose write this port composes rather than takes from its caller (AD-51): the set a change
/// stores is built from the tool's declared <code>Pair</code> over the stored set, never sent as a body.</p>
Parameter COMPOSEDTYPES = "Screen/PUT";

/// <p>The query key naming the screen, by its <code>toolIdentifier</code>.</p>
Parameter SCREENKEY = "Screen";

/// <p>The query key naming the pair a change adds.</p>
Parameter ADDKEY = "addpair";

/// <p>The query key naming the pair a change removes.</p>
Parameter REMOVEKEY = "removepair";

/// <p>The query key marking a read composed for a reset.</p>
Parameter RESETKEY = "reset";

/// <p>The field a violation names.</p>
Parameter PAIRFIELD = "Pair";

/// <p>The permissions a pair may carry, comma-separated.</p>
Parameter PERMISSIONS = "READ,WRITE,USE";

/// <p>The shape of a resource name: an optional <code>%</code>, a letter, then letters, digits and
/// <code>_ . -</code>.</p>
Parameter RESOURCEPATTERN = "^%?[A-Za-z][A-Za-z0-9_.-]{0,127}$";

Parameter LOGSUBSYSTEM = "screenaccessport";

Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

Parameter REASONSCREEN = "Name the screen.";

Parameter REASONCHANGE = "Name one pair to add or one pair to remove.";

/// <p>The entity type and verbs the audit row carries.</p>
Parameter ENTITYTYPE = "screen-permission";

Parameter VERBUPDATED = "updated";

Parameter VERBRESET = "reset";

/// <p>The class the pair sets are evaluated through. Overridable so a fixture can drive a denial in
/// process; production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>Whether this instance defines a resource named <var>pName</var>, case-insensitively
/// (<code>$System.Security.ResourceExists</code>, which is <code>[Internal]</code>:
/// <class>OcuPilot.Test.ScreenAccessDescriptor</class> pins its signature). Overridable so the rules can
/// be driven in process against a declared answer; production never overrides it.</p>
ClassMethod ResourceDefined(pName As %String) As %Boolean
{
    Quit ''$System.Security.ResourceExists(pName)
}

/// <p>Whether <var>pEndpoint</var> serves <var>pType</var>.</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    If pEndpoint '= ..#ENDPOINT Quit 0
    Quit (pType = ..#TYPEGET) || (pType = ..#TYPEPUT) || (pType = ..#TYPEDELETE)
}

/// <p>The codes a write's fresh read refuses with when the change no longer fits the stored set: the
/// tools' <method>OcuPilot.Screen.Tool.Write.PreconditionCodes</method>, which may not name
/// <class>OcuPilot.Api.AccessError</class> themselves.</p>
ClassMethod PreconditionCodes() As %List
{
    Quit ##class(OcuPilot.Api.AccessError).PreconditionCodes()
}

/// <p>The published sentence of <var>pCode</var>, <code>""</code> for a code this port does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    Quit ##class(OcuPilot.Api.AccessError).ReasonFor(pCode)
}

/// <p>The canonical spelling of the pair text <var>pText</var>, <code>resource:PERMISSION</code>, or
/// <code>""</code> when it is not a resource of the right shape and one of
/// <parameter>PERMISSIONS</parameter>. The resource keeps the spelling it was typed with.</p>
ClassMethod Canonical(pText As %String) As %String
{
    Set tText = $ZStrip(pText, "<>W")
    If $Length(tText, ":") '= 2 Quit ""
    Set tResource = $Piece(tText, ":", 1)
    Set tPermission = $ZConvert($Piece(tText, ":", 2), "U")
    If '$Match(tResource, ..#RESOURCEPATTERN) Quit ""
    If '$ListFind($ListFromString(..#PERMISSIONS), tPermission) Quit ""
    Quit tResource _ ":" _ tPermission
}

/// <p>The position of the pair spelled <var>pSpec</var> in the list <var>pList</var> of
/// <code>resource:PERMISSION</code> texts, compared without regard to the resource's case, or 0.</p>
ClassMethod IndexOf(pList As %List, pSpec As %String) As %Integer
{
    Set tWanted = $ZConvert(pSpec, "U")
    Set tAt = 0
    For tI = 1:1:$ListLength(pList) {
        If $ZConvert($List(pList, tI), "U") = tWanted {
            Set tAt = tI
            Quit
        }
    }
    Quit tAt
}

/// <p>The change of one pair over the current set (AD-56 (ii)): <var>pCurrent</var> is a list of
/// <code>resource:PERMISSION</code> texts and exactly one of <var>pAddPair</var> and <var>pRemovePair</var>
/// is non-empty. <var>pNew</var> is the set the change leaves, and <var>pViolation</var> the
/// <class>OcuPilot.Api.AccessError</class> code that refuses it, <code>""</code> when it holds. Adding
/// refuses, in this order, a malformed pair, a resource the instance does not define, a pair already
/// held and a ninth pair; removing refuses a malformed pair, a pair not held and the last pair.</p>
ClassMethod Apply(pCurrent As %List, pAddPair As %String, pRemovePair As %String, Output pNew As %List, Output pViolation As %String)
{
    Set pNew = pCurrent
    Set pViolation = ""
    If pAddPair '= "" {
        Set tSpec = ..Canonical(pAddPair)
        If tSpec = "" {
            Set pViolation = ##class(OcuPilot.Api.AccessError).#PAIRMALFORMED
            Quit
        }
        If '..ResourceDefined($Piece(tSpec, ":", 1)) {
            Set pViolation = ##class(OcuPilot.Api.AccessError).#RESOURCEUNKNOWN
            Quit
        }
        If ..IndexOf(pCurrent, tSpec) {
            Set pViolation = ##class(OcuPilot.Api.AccessError).#PAIRPRESENT
            Quit
        }
        If $ListLength(pCurrent) >= ##class(OcuPilot.Api.AccessError).#MAXPAIRS {
            Set pViolation = ##class(OcuPilot.Api.AccessError).#PAIRSTOOMANY
            Quit
        }
        Set pNew = pCurrent _ $ListBuild(tSpec)
        Quit
    }
    Set tSpec = ..Canonical(pRemovePair)
    If tSpec = "" {
        Set pViolation = ##class(OcuPilot.Api.AccessError).#PAIRMALFORMED
        Quit
    }
    Set tAt = ..IndexOf(pCurrent, tSpec)
    If 'tAt {
        Set pViolation = ##class(OcuPilot.Api.AccessError).#PAIRABSENT
        Quit
    }
    If $ListLength(pCurrent) = 1 {
        Set pViolation = ##class(OcuPilot.Api.AccessError).#PAIRSEMPTY
        Quit
    }
    Set pNew = ""
    For tI = 1:1:$ListLength(pCurrent) {
        If tI '= tAt Set pNew = pNew _ $ListBuild($List(pCurrent, tI))
    }
}

/// <p>The gate's two-element pair lists <var>pPairs</var> as a list of <code>resource:PERMISSION</code>
/// texts.</p>
ClassMethod Texts(pPairs As %List) As %List
{
    Set tTexts = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tPair = $List(pPairs, tI)
        Set tTexts = tTexts _ $ListBuild($List(tPair, 1) _ ":" _ $ZConvert($List(tPair, 2), "U"))
    }
    Quit tTexts
}

/// <p>The comma-separated storage spelling of the list <var>pTexts</var>.</p>
ClassMethod SpecOf(pTexts As %List) As %String
{
    Quit $ListToString(pTexts, ",")
}

/// <p>The list <var>pTexts</var> as a JSON array of strings.</p>
ClassMethod ArrayOf(pTexts As %List) As %DynamicArray
{
    Set tArray = []
    For tI = 1:1:$ListLength(pTexts) Do tArray.%Push($List(pTexts, tI), "string")
    Quit tArray
}

/// <p>Serve <var>pEndpoint</var> for request type <var>pType</var> (the header above).
/// <var>pQuery</var> carries <parameter>SCREENKEY</parameter> and, for a change,
/// <parameter>ADDKEY</parameter> or <parameter>REMOVEKEY</parameter>, or <parameter>RESETKEY</parameter>
/// for a read composed for a reset. <var>pBody</var> is not read.</p>
/// <p>On success, at 200, <var>pResult</var> is <code>{Screen, Pairs, Adjusted, Pair, Result}</code>
/// (after a write, <code>Pairs</code> and <code>Result</code> are the set it left). Otherwise an error
/// status is returned, <var>pHttpStatus</var> is the status to answer with and <var>pFault</var> the wire
/// fault: 403 <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>; 400
/// <code>PORT.VALIDATION</code>; 501 <code>PORT.NOTIMPLEMENTED</code>; 404 <code>ACCESS.SCREEN.UNKNOWN</code>;
/// 403 <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTSCREEN</parameter> for a write to a screen that cannot be adjusted; 409
/// <code>ACCESS.NOTADJUSTED</code>; 422 with one violation on <code>Pair</code>; 409
/// <code>STATE.CONFLICT</code> for a stored set that moved under the write; and 500 <code>INTERNAL</code>,
/// logged, for anything else.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9).</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '..Serves(pEndpoint, pType) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tFailedPair = ""
        ; EvaluateRequired, not EvaluatePairs: a pair list mis-edited to empty fails closed.
        If '$ClassMethod(..GateClass(), "EvaluateRequired", $ClassMethod(..GateClass(), "ParsePairSpec", ..#PAIRS), .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        Set tScreen = $Get(pQuery(..#SCREENKEY))
        If tScreen = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONSCREEN, .pHttpStatus, .pFault)
            Quit
        }
        Set tBase = $ClassMethod(..GateClass(), "BasePairs", tScreen, .tDescriptor, .tResolved)
        If tDescriptor = "" {
            Set tSC = ..Absent(.pHttpStatus, .pFault)
            Quit
        }
        If 'tResolved {
            Set tSC = ..Fail("the screen's required pairs could not be read", $$$ERROR($$$GeneralError, "unresolved"), .pHttpStatus, .pFault)
            Quit
        }
        Set tAdjustable = ''$ClassMethod(..GateClass(), "Adjustable", tDescriptor)
        Set tStoreSC = ##class(OcuPilot.Kernel.State.Access).GuardedGet(tScreen, .tStored, .tVersion, .tFound)
        If $$$ISERR(tStoreSC) {
            Set tSC = ..Fail("the screen's adjustment could not be read", tStoreSC, .pHttpStatus, .pFault)
            Quit
        }
        Set tAdjusted = (tFound && tAdjustable)
        Set tCurrent = ..Texts(tBase)
        ; An adjustable screen's current set comes from the read that gave the version, so a write that
        ; lands after that read is refused stale rather than overwritten.
        If tAdjusted {
            Set tCurrent = ..Texts($ClassMethod(..GateClass(), "ParsePairSpec", tStored))
            If tCurrent = "" {
                Set tSC = ..Fail("the screen's adjustment could not be read", $$$ERROR($$$GeneralError, "unparsed"), .pHttpStatus, .pFault)
                Quit
            }
        } ElseIf tAdjustable {
            Set tCurrent = ..Texts($ClassMethod(tDescriptor, "PrivilegePairs"))
        }
        Set tAdd = $Get(pQuery(..#ADDKEY))
        Set tRemove = $Get(pQuery(..#REMOVEKEY))
        Set tReset = ''$Get(pQuery(..#RESETKEY))
        ; A change key that is present names a change even when its pair is empty, which Apply refuses.
        Set tChange = ($Data(pQuery(..#ADDKEY)) # 2) || ($Data(pQuery(..#REMOVEKEY)) # 2)

        If pType = ..#TYPEGET {
            Set tNew = tCurrent
            Set tPair = $Select(tAdd '= "": tAdd, 1: tRemove)
            If tAdjustable {
                If tChange {
                    Do ..Apply(tCurrent, tAdd, tRemove, .tNew, .tViolation)
                    If tViolation '= "" {
                        Set tSC = ..Violate(tViolation, .pHttpStatus, .pFault)
                        Quit
                    }
                } ElseIf tReset {
                    If 'tAdjusted {
                        Set tSC = ..Conflict(##class(OcuPilot.Api.AccessError).#NOTADJUSTED, .pHttpStatus, .pFault)
                        Quit
                    }
                    Set tNew = ..Texts($ClassMethod(tDescriptor, "PrivilegePairs"))
                }
            }
            Set pResult = ..Row(tScreen, tCurrent, tAdjusted, tPair, tNew)
            Set pHttpStatus = 200
            Quit
        }

        If 'tAdjustable {
            Set tSC = ..Prohibit(.pHttpStatus, .pFault)
            Quit
        }

        If pType = ..#TYPEDELETE {
            If 'tAdjusted {
                Set tSC = ..Conflict(##class(OcuPilot.Api.AccessError).#NOTADJUSTED, .pHttpStatus, .pFault)
                Quit
            }
            Set tDeclared = $ClassMethod(tDescriptor, "PrivilegePairs")
            Set tRemoveSC = ##class(OcuPilot.Kernel.State.Access).GuardedRemove(tScreen, tVersion)
            If $$$ISERR(tRemoveSC) {
                Set tSC = ..Stored(tRemoveSC, .pHttpStatus, .pFault)
                Quit
            }
            Set tAfter = ..Texts(tDeclared)
            Do ..Audit(..#VERBRESET, tScreen, tCurrent, tAfter)
            Set pResult = ..Row(tScreen, tAfter, 0, "", tAfter)
            Set pHttpStatus = 200
            Quit
        }

        If (tAdd = "") = (tRemove = "") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONCHANGE, .pHttpStatus, .pFault)
            Quit
        }
        Do ..Apply(tCurrent, tAdd, tRemove, .tNew, .tViolation)
        If tViolation '= "" {
            Set tSC = ..Violate(tViolation, .pHttpStatus, .pFault)
            Quit
        }
        Set tPutSC = ##class(OcuPilot.Kernel.State.Access).GuardedPut(tScreen, ..SpecOf(tNew), $Select(tFound: tVersion, 1: 0), $Username)
        If $$$ISERR(tPutSC) {
            Set tSC = ..Stored(tPutSC, .pHttpStatus, .pFault)
            Quit
        }
        Do ..Audit(..#VERBUPDATED, tScreen, tCurrent, tNew)
        Set pResult = ..Row(tScreen, tNew, 1, $Select(tAdd '= "": tAdd, 1: tRemove), tNew)
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the screen permission call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The answer row: <var>pScreen</var>, the set it requires <var>pPairs</var>, whether that set is an
/// adjustment, the pair a change named and the set the change leaves.</p>
ClassMethod Row(pScreen As %String, pPairs As %List, pAdjusted As %Boolean, pPair As %String, pResult As %List) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Screen", pScreen, "string")
    Do tRow.%Set("Pairs", ..ArrayOf(pPairs))
    Do tRow.%Set("Adjusted", $Select(pAdjusted: 1, 1: 0), "boolean")
    Do tRow.%Set("Pair", pPair, "string")
    Do tRow.%Set("Result", ..ArrayOf(pResult))
    Quit tRow
}

/// <p>Record <code>SecurityChange</code> for one accepted write: the pairs before and after, as
/// comma-separated texts. It never fails the write (AD-15).</p>
ClassMethod Audit(pVerb As %String, pScreen As %String, pOld As %List, pNew As %List) [ Private ]
{
    Try {
        Set tPairs = {}
        Do tPairs.%Set("old", ..SpecOf(pOld), "string")
        Do tPairs.%Set("new", ..SpecOf(pNew), "string")
        Set tChanges = {}
        Do tChanges.%Set("pairs", tPairs)
        Do ##class(OcuPilot.Kernel.Audit.Event).Record(pVerb, ..#ENTITYTYPE, pScreen, tChanges, 1)
    } Catch ex {
        Do ..LogFault("the screen permission change could not be audited", ex.AsStatus())
    }
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture
/// the line; production never overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>The privilege refusal naming <var>pFailedPair</var> (AD-8, AD-39).</p>
ClassMethod Deny(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDenial = ##class(OcuPilot.Kernel.Denial).Detail(pFailedPair)
    Quit ..Refuse(##class(OcuPilot.Kernel.Denial).#STATUS, ##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason(), .pHttpStatus, .pFault, tDenial)
}

/// <p>A refusal this port decided, with a written reason. <var>pDetail</var>, when supplied, becomes
/// the fault's <code>detail</code> (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pDetail As %DynamicObject = "") As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    If $IsObject(pDetail) Do pFault.%Set("detail", pDetail)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>The 409 refusal <var>pCode</var>, with its published sentence.</p>
ClassMethod Conflict(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, pCode, ..ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>404 <code>ACCESS.SCREEN.UNKNOWN</code>: no built screen carries the identifier. Unlogged.</p>
ClassMethod Absent(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tCode = ##class(OcuPilot.Api.AccessError).#SCREENUNKNOWN
    Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, tCode, ..ReasonFor(tCode), .pHttpStatus, .pFault)
}

/// <p>403 <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTSCREEN</parameter>: the screen is OcuPilot's own and cannot be adjusted
/// (AD-10).</p>
ClassMethod Prohibit(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tCode = ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTSCREEN
    Quit ..Refuse(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode), .pHttpStatus, .pFault)
}

/// <p>The refusal <var>pCode</var> of a change: 409 for a reset with nothing to reset, 422 with one
/// violation on <parameter>PAIRFIELD</parameter> for every other (AD-39).</p>
ClassMethod Violate(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    If pCode = ##class(OcuPilot.Api.AccessError).#NOTADJUSTED Quit ..Conflict(pCode, .pHttpStatus, .pFault)
    Set tReason = ..ReasonFor(pCode)
    Set tViolation = {}
    Do tViolation.%Set("field", ..#PAIRFIELD, "string")
    Do tViolation.%Set("code", pCode, "string")
    Do tViolation.%Set("reason", tReason, "string")
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push(tViolation)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pCode, tReason, .pHttpStatus, .pFault, tDetail)
}

/// <p>The answer to a failed store write <var>pStatus</var>: 409 <code>STATE.CONFLICT</code> when the
/// row moved under it, else 500 <code>INTERNAL</code>.</p>
ClassMethod Stored(pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    If ##class(OcuPilot.Kernel.State.Access).IsStaleSave(pStatus) {
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#STATECONFLICT, ##class(OcuPilot.Api.Error).#REASONSTATECONFLICT, .pHttpStatus, .pFault)
    }
    Quit ..Fail("the screen permission store write failed", pStatus, .pHttpStatus, .pFault)
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p><code>objectscript</code> for the two writes this port carries; <code>""</code> for
/// <parameter>TYPEGET</parameter>, which has no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If pEndpoint '= ..#ENDPOINT Quit ""
    If (pType = ..#TYPEPUT) || (pType = ..#TYPEDELETE) Quit "objectscript"
    Quit ""
}

/// <p><method>Invoke</method>'s write branches as a script (AD-59): the port's own public call with the
/// query the write carries. Every value is rendered as a string literal, so nothing the query carries
/// runs as code. Whoever runs the script is checked by the port's own gate. A read writes nothing and
/// answers no step.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tText = " Kill tQuery"
    Set tText = tText _ $Char(10) _ " Set tQuery(" _ ..Literal(..#SCREENKEY) _ ") = " _ ..Literal($Get(pQuery(..#SCREENKEY)))
    If (pType = ..#TYPEPUT) && ($Get(pQuery(..#ADDKEY)) '= "") Set tText = tText _ $Char(10) _ " Set tQuery(" _ ..Literal(..#ADDKEY) _ ") = " _ ..Literal(pQuery(..#ADDKEY))
    If (pType = ..#TYPEPUT) && ($Get(pQuery(..#REMOVEKEY)) '= "") Set tText = tText _ $Char(10) _ " Set tQuery(" _ ..Literal(..#REMOVEKEY) _ ") = " _ ..Literal(pQuery(..#REMOVEKEY))
    Set tText = tText _ $Char(10) _ " Set tSC = ##class(OcuPilot.Port.ScreenAccessPort).Invoke(" _ ..Literal(..#ENDPOINT) _ ", " _ ..Literal(pType) _ ", .tQuery, """", .tResult, .tHttp, .tFault)"
    Set tStep = {}
    Do tStep.%Set("kind", "objectscript", "string")
    Do tStep.%Set("text", tText, "string")
    Quit [(tStep)]
}

/// <p><var>pValue</var> as an ObjectScript string literal, a control character spelled as a
/// <code>$Char</code>.</p>
ClassMethod Literal(pValue As %String) As %String [ Private ]
{
    Set tText = """" _ $Replace(pValue, """", """""") _ """"
    For tCode = 0:1:31 {
        If tText [ $Char(tCode) Set tText = $Replace(tText, $Char(tCode), """_$Char(" _ tCode _ ")_""")
    }
    Quit tText
}

}
