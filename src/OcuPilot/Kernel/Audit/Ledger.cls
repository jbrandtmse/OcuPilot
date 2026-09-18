/// <p>The agent ledger's one public face (AD-3, AD-9, AD-15, AD-24, AD-37, AD-41, AD-46): what a
/// turn writes for each provider call and each tool answer, and the one route those rows are read
/// back through.</p>
/// <p><b>The ledger never fails a turn.</b> Every writer here returns a <class>%Status</class> that
/// no caller propagates: a failure is logged under <parameter>LOGSUBSYSTEM</parameter> and the turn
/// carries on (AD-15's failure posture).</p>
/// <p><b>Redaction runs in one order and only ever adds</b> (AD-3): first the tool's own
/// <method>OcuPilot.Screen.Tool.Base.SecretArguments</method> declaration, then
/// <method>OcuPilot.Kernel.Audit.Log.Redact</method>'s name pattern over that result. The pattern is
/// a backstop; it can add a <code>[redacted]</code> and can never restore one, and
/// <method>RedactArguments</method> refuses to store anything at all if that stops being true.</p>
/// <p><b>The cross-user gate lives here rather than in <class>OcuPilot.Kernel.State.Ledger</class>
/// or in any screen</b> (AD-46). The store cannot evaluate it: a state class may not reference
/// <package>OcuPilot.Screen</package> (AD-9's re-entry rule, enforced by
/// <file>scripts/check-objectscript.py</file>), and AD-9 forbids re-entry from inside an escalated
/// frame either way. So the store answers rows as data, including each row's own pair string, and
/// <method>ViewForUser</method> evaluates them in the caller's own process, at read time, never
/// cached -- and no screen can bypass it, because there is no other route to a row.</p>
Class OcuPilot.Kernel.Audit.Ledger Extends %RegisteredObject
{

/// <p>The subsystem a ledger failure is logged under.</p>
Parameter LOGSUBSYSTEM = "ledger";

/// <p>The permission the OcuPilot administrative resource is required at for a cross-user read.</p>
Parameter ADMINPERMISSION = "USE";

/// <p>The verb a cross-user read's audit row carries.</p>
Parameter READVERB = "read";

/// <p>The entity type a cross-user read's audit row names -- the subject of the read, whose name is
/// the row's id (AD-13).</p>
Parameter READENTITYTYPE = "user";

/// <p>The store every row is written to and read from.</p>
ClassMethod StoreClass() As %String
{
    Quit "OcuPilot.Kernel.State.Ledger"
}

/// <p>The privilege gate <method>ViewForUser</method> evaluates through. Overridable so a test can
/// drive the set semantics against a declared answer -- <code>%UnitTest</code> runs as an account
/// holding <code>%All</code>, for which the real check answers yes to every resource name.
/// Production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Screen.Gate"
}

/// <p>The audit emitter a cross-user read is recorded through. Overridable for the same reason
/// <class>OcuPilot.Test.EventProbe</class> exists; production never overrides it.</p>
ClassMethod EventClass() As %String
{
    Quit "OcuPilot.Kernel.Audit.Event"
}

/// <p>The resource a cross-user read requires, at <parameter>ADMINPERMISSION</parameter>.</p>
ClassMethod AdminResource() As %String
{
    Quit ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE
}

/// <p>The pair a cross-user read requires, spelled <code>resource:permission</code>.</p>
ClassMethod AdminPair() As %String
{
    Quit ..AdminResource() _ ":" _ ..#ADMINPERMISSION
}

/// <p>Record one provider call of turn <var>pTurnKey</var>.</p>
/// <p><b>A provider row stores the call's own parameters, never the prompt.</b> The model and the
/// token figures are columns of their own, the screen-context route is another, and the row's
/// <code>arguments</code> carries the two remaining figures,
/// <code>{"iteration": n, "httpStatus": s}</code> -- the position of the call within its turn, and
/// the HTTP status the last attempt read (<code>0</code> when no call was made at all, which is what
/// an unresolved credential answers). Message
/// bodies and tool-result bodies are transcripts -- Story 14.4's -- and storing them here would both
/// duplicate that store and defeat <code>LEDGERROWMAXLENGTH</code>.</p>
ClassMethod RecordProviderCall(pTurnKey As %String, pUser As %String, pRoute As %String, pProvider As %String, pModel As %String, pIteration As %Integer, pRequestTokens As %Integer, pResponseTokens As %Integer, pStatus As %String, pCode As %String, pHttpStatus As %Integer, pLimitsClass As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tArguments = {}
        Do tArguments.%Set("iteration", +pIteration, "number")
        Do tArguments.%Set("httpStatus", +pHttpStatus, "number")
        Set tSC = $ClassMethod(..StoreClass(), "GuardedAppend", pTurnKey, pUser, pRoute, $Parameter(..StoreClass(), "KINDLLM"), pProvider, pModel, "", tArguments.%ToJSON(), 0, pStatus, pCode, +pRequestTokens, +pResponseTokens, "", pLimitsClass, .tSeq, .tStored)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Do ..LogFailure("a provider call could not be recorded in the agent ledger", tSC)
    Quit tSC
}

/// <p>Record one tool answer of turn <var>pTurnKey</var>: the canonical name, the target, the
/// redacted arguments, the outcome, and the union of the pairs the tool declared
/// (<var>pDeclaredPairs</var>) with those its arguments added (<var>pArgumentPairs</var>).</p>
/// <p><b>The union is what makes the recorded requirement real</b> (AC2). A tool such as
/// <class>OcuPilot.Screen.Tool.Navigate</class> declares no static pair at all and resolves
/// everything per call, so a row recording only the declared half would record nothing for
/// <code>shell.screen.open</code> -- and a later cross-user read gated on that row would release it
/// to an administrator holding nothing.</p>
/// <p><var>pSecretNames</var> is the tool's own declaration
/// (<method>OcuPilot.Screen.Tool.Base.SecretArguments</method>); <var>pInput</var> is the model's
/// raw input, which this method redacts and which no caller redacts for it.</p>
ClassMethod RecordToolCall(pTurnKey As %String, pUser As %String, pRoute As %String, pName As %String, pTarget As %String, pInput As %DynamicAbstractObject, pDeclaredPairs As %List, pArgumentPairs As %List, pSecretNames As %List, pStatus As %String, pCode As %String, pLimitsClass As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tArguments = ..RedactArguments(pInput, pSecretNames, +$Parameter(pLimitsClass, "LEDGERROWMAXLENGTH"), .tTruncated, .tRedactedNames)
        Set tPairs = ..PairsToString(pDeclaredPairs _ pArgumentPairs)
        Set tSC = $ClassMethod(..StoreClass(), "GuardedAppend", pTurnKey, pUser, pRoute, $Parameter(..StoreClass(), "KINDTOOL"), pName, "", pTarget, tArguments, tTruncated, pStatus, pCode, 0, 0, tPairs, pLimitsClass, .tSeq, .tStored)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Do ..LogFailure("a tool answer could not be recorded in the agent ledger", tSC)
    Quit tSC
}

/// <p>The argument string a ledger row stores for <var>pInput</var>, in the two layers AD-3 fixes,
/// on a copy -- the caller still holds <var>pInput</var> unchanged.</p>
/// <ol>
/// <li><b>Drop by declaration.</b> Every top-level name in <var>pSecretNames</var> that the input
/// carries has its value replaced with <method>OcuPilot.Kernel.Audit.Log</method>'s own redaction
/// mark. This is the layer that can see a wallet secret stored in a field called
/// <code>Value</code>, which no name pattern can.</li>
/// <li><b>The name-pattern backstop</b>, through
/// <method>OcuPilot.Kernel.Agent.Dispatch.RedactedArguments</method> -- which is
/// <method>OcuPilot.Kernel.Audit.Log.Redact</method> plus the cut at <var>pMaxLength</var> ending in
/// U+2026. Reused verbatim rather than re-implemented, so a ledger row's argument string and the
/// tool step's reconcile.</li>
/// </ol>
/// <p><var>pRedactedNames</var> comes back as the top-level names that read as redacted after both
/// layers. <b>The declared set must be a subset of it and no declared value may survive into the
/// answer</b>; if either stops being true this answers <code>""</code> and logs rather than storing
/// a string that may carry a secret. The value scan is a substring test, so a declared value that
/// also appears under another key trips it and costs that row its argument string. Fail-closed is
/// the right direction here: a missing argument string costs a reader context, and a leaked one
/// reaches OcuPilot's own screens (AD-35, AD-46).</p>
ClassMethod RedactArguments(pInput As %DynamicAbstractObject, pSecretNames As %List, pMaxLength As %Integer, Output pTruncated As %Boolean, Output pRedactedNames As %List) As %String
{
    Set pTruncated = 0
    Set pRedactedNames = ""
    Set tOut = ""
    Try {
        If '$IsObject(pInput) || 'pInput.%IsA("%Library.DynamicObject") Quit
        Set tCopy = ##class(%DynamicAbstractObject).%FromJSON(pInput.%ToJSON())
        Set tDeclared = ""
        Set tValues = ""
        For tI = 1:1:$ListLength(pSecretNames) {
            Set tName = $List(pSecretNames, tI)
            If tName = "" Continue
            If tCopy.%GetTypeOf(tName) = "unassigned" Continue
            If tCopy.%GetTypeOf(tName) = "string" {
                Set tValue = tCopy.%Get(tName)
                If tValue '= "" Set tValues = tValues _ $ListBuild(tValue)
            }
            Do tCopy.%Set(tName, ##class(OcuPilot.Kernel.Audit.Log).#REDACTED, "string")
            Set tDeclared = tDeclared _ $ListBuild(tName)
        }
        Set tCandidate = ##class(OcuPilot.Kernel.Agent.Dispatch).RedactedArguments(tCopy, pMaxLength, .tTruncated)
        Set tNames = ..RedactedKeys(##class(OcuPilot.Kernel.Audit.Log).Redact(tCopy))
        Set tSound = 1
        For tI = 1:1:$ListLength(tDeclared) {
            If '$ListFind(tNames, $List(tDeclared, tI)) Set tSound = 0
        }
        For tI = 1:1:$ListLength(tValues) {
            If tCandidate [ $List(tValues, tI) Set tSound = 0
        }
        If 'tSound {
            Do ..LogFailure("a declared secret argument did not survive the ledger's redaction layers, so nothing was stored", $$$ERROR($$$GeneralError, "the declared redaction set is not a subset of the redacted set, or a declared value reached the answer"))
            Quit
        }
        Set pRedactedNames = tNames
        Set pTruncated = ''tTruncated
        Set tOut = tCandidate
    } Catch ex {
        Set tOut = ""
        Set pTruncated = 0
        Set pRedactedNames = ""
    }
    Quit tOut
}

/// <p>The top-level names of <var>pObject</var> whose value is
/// <parameter>OcuPilot.Kernel.Audit.Log.REDACTED</parameter>, as a <class>%List</class>.</p>
ClassMethod RedactedKeys(pObject As %DynamicAbstractObject) As %List [ Private ]
{
    Set tNames = ""
    Try {
        If '$IsObject(pObject) Quit
        Set tIterator = pObject.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue, .tType) {
            If (tType = "string") && (tValue = ##class(OcuPilot.Kernel.Audit.Log).#REDACTED) Set tNames = tNames _ $ListBuild(tKey)
        }
    } Catch ex {
        Set tNames = ""
    }
    Quit tNames
}

/// <p><var>pPairs</var> -- a <class>%List</class> of <code>$ListBuild(resource, permission)</code>
/// -- as the canonical column value: each pair spelled <code>resource:permission</code>, sorted,
/// de-duplicated and comma-joined. A malformed member is dropped.</p>
ClassMethod PairsToString(pPairs As %List) As %String
{
    Set tOut = ""
    Kill tSeen
    Try {
        For tI = 1:1:$ListLength(pPairs) {
            Set tPair = $List(pPairs, tI)
            If '$ListValid(tPair) || ($ListLength(tPair) < 2) Continue
            Set tResource = $List(tPair, 1)
            Set tPermission = $List(tPair, 2)
            If (tResource = "") || (tPermission = "") Continue
            Set tSeen(tResource _ ":" _ tPermission) = ""
        }
        Set tKey = ""
        For {
            Set tKey = $Order(tSeen(tKey))
            If tKey = "" Quit
            Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
        }
    } Catch ex {
        Set tOut = ""
    }
    Quit tOut
}

/// <p><method>PairsToString</method>'s inverse: the pair list <var>pText</var> spells. A member
/// without both halves is dropped, which is why <method>ViewForUser</method> treats a non-empty
/// string that yields no pair as a row it cannot gate rather than as a row requiring nothing.</p>
ClassMethod StringToPairs(pText As %String) As %List
{
    Set tPairs = ""
    Try {
        For tI = 1:1:$Length(pText, ",") {
            Set tMember = $Piece(pText, ",", tI)
            If tMember = "" Continue
            Set tResource = $Piece(tMember, ":", 1)
            Set tPermission = $Piece(tMember, ":", 2)
            If (tResource = "") || (tPermission = "") Continue
            Set tPairs = tPairs _ $ListBuild($ListBuild(tResource, tPermission))
        }
    } Catch ex {
        Set tPairs = ""
    }
    Quit tPairs
}

/// <p>Read <var>pSubject</var>'s ledger rows for <var>pCaller</var>:
/// <code>{rows, rowsSent, truncated, rowsWithheld, rowsDropped, windowHours}</code>, newest first
/// and bounded by <var>pMaxRows</var>.</p>
/// <p><var>pSubject</var> <code>""</code> means the caller's own rows. Another subject requires
/// <method>AdminPair</method>, evaluated in the calling process at the moment of the call (AD-8);
/// a caller without it gets <var>pFault</var> <code>AUTH.NOPRIVILEGE</code> carrying
/// <code>detail.failedPair</code> and no rows at all.</p>
/// <p><b>The per-row gate is the cross-user view's</b> (AD-46: "a user sees their own ledger rows;
/// an OcuPilot administrator's view of another user's rows is gated by the resources recorded on the
/// row itself"). A self read answers every row it finds and <code>rowsWithheld</code> 0.</p>
/// <p><b>It is evaluated outside every escalated frame</b> (AD-9). Every guarded read returns first
/// -- the ids, then each row as data, then the dropped count -- and only then is each row's own
/// <code>requiredPairs</code> evaluated through <method>OcuPilot.Screen.Gate.EvaluatePairs</method>.
/// A row the caller cannot hold is absent from <code>rows</code> and counted in
/// <code>rowsWithheld</code>; it is never returned with fields removed, because a row's identity is
/// itself the thing withheld. A non-empty requirement that yields no pair is withheld too: a
/// requirement that will not parse is not an absent one.</p>
/// <p>A cross-user read emits one <parameter>OcuPilot.Kernel.Audit.Event.EVENTLEDGERREAD</parameter>
/// row after the read has resolved, and its status is ignored -- registration is what makes it land
/// and emission never fails the read (AD-15).</p>
ClassMethod ViewForUser(pCaller As %String, pSubject As %String, pWindowHours As %String, pTurnKey As %String, pMaxRows As %Integer, Output pView As %DynamicObject, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pView = ""
    Set pFault = ""
    Try {
        Set tSubject = $Select(pSubject '= "": pSubject, 1: pCaller)
        ; An account name is case-insensitive on this instance while the column is matched %EXACT
        ; (AD-37), so a caller who typed their own name in another case is resolved to the name they
        ; authenticated as rather than refused for asking about "somebody else".
        If $ZConvert(tSubject, "U") = $ZConvert(pCaller, "U") Set tSubject = pCaller
        Set tCrossUser = (tSubject '= pCaller)
        If tCrossUser && '$ClassMethod(..GateClass(), "HoldsPrivilege", ..AdminResource(), ..#ADMINPERMISSION) {
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#FORBIDDEN, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, ##class(OcuPilot.Api.Error).#REASONAUTHNOPRIVILEGE)
            Set tDetail = {}
            Do tDetail.%Set("failedPair", ..AdminPair(), "string")
            Do pFault.%Set("detail", tDetail)
            Quit
        }

        Set tStore = ..StoreClass()
        Set tCap = +pMaxRows
        Set tIdsSC = $ClassMethod(tStore, "GuardedIdsForWindow", tSubject, pWindowHours, pTurnKey, tCap + 1, .tIds, .tProblem)
        If $$$ISERR(tIdsSC) {
            Set pFault = ..Unavailable(tIdsSC, "the agent ledger's rows could not be read")
            Quit
        }
        Set tFound = +$Get(tIds)
        Set tTruncated = (tFound > tCap)
        Set tKept = $Select(tTruncated: tCap, 1: tFound)

        ; Every guarded read first, so nothing below runs inside an escalated frame (AD-9).
        Kill tValues
        Set tReadSC = $$$OK
        Set tRead = 0
        For tI = 1:1:tKept {
            Set tRowSC = $ClassMethod(tStore, "GuardedRow", tIds(tI), .tRow)
            If $$$ISERR(tRowSC) {
                Set tReadSC = tRowSC
                Quit
            }
            ; A row deleted between the id read and this one answers no values and no error. Skip
            ; it: an all-empty row would be counted as sent, and its empty requirement would be
            ; released to a cross-user reader as though the call had required nothing.
            If '$Data(tRow) Continue
            Set tRead = tRead + 1
            Merge tValues(tRead) = tRow
        }
        Set tKept = tRead
        If $$$ISERR(tReadSC) {
            Set pFault = ..Unavailable(tReadSC, "an agent ledger row could not be read")
            Quit
        }
        Set tDroppedSC = $ClassMethod(tStore, "GuardedDroppedFor", tSubject, pWindowHours, pTurnKey, .tDropped)
        If $$$ISERR(tDroppedSC) {
            Set pFault = ..Unavailable(tDroppedSC, "the agent ledger's dropped count could not be read")
            Quit
        }

        Set tRows = []
        Set tWithheld = 0
        For tI = 1:1:tKept {
            If 'tCrossUser {
                ; A user sees their own rows (AD-46). The per-row requirement records what that
                ; user's own call needed, so gating it would hide a person's history from them the
                ; moment a privilege was revoked, and would protect nothing.
                Set tOwnRow = ..RowObject(.tValues, tI)
                Do tRows.%Push(tOwnRow)
                Continue
            }
            Set tPairsText = $Get(tValues(tI, "requiredPairs"))
            Set tPairs = ..StringToPairs(tPairsText)
            If (tPairsText '= "") && (tPairs = "") {
                Set tWithheld = tWithheld + 1
                Continue
            }
            If '$ClassMethod(..GateClass(), "EvaluatePairs", tPairs, .tFailedPair) {
                Set tWithheld = tWithheld + 1
                Continue
            }
            Set tRowObject = ..RowObject(.tValues, tI)
            Do tRows.%Push(tRowObject)
        }

        Set tView = {}
        Do tView.%Set("rows", tRows)
        Do tView.%Set("rowsSent", tRows.%Size(), "number")
        Do tView.%Set("truncated", ''tTruncated, "boolean")
        Do tView.%Set("rowsWithheld", tWithheld, "number")
        Do tView.%Set("rowsDropped", +tDropped, "number")
        Do tView.%Set("windowHours", ..AppliedWindow(pWindowHours, pTurnKey), "number")
        Set pView = tView

        If tCrossUser Do ..RecordRead(tSubject, tRows.%Size(), tWithheld)
    } Catch ex {
        Set pView = ""
        Set pFault = ..Unavailable(ex.AsStatus(), "the agent ledger read failed")
    }
    Quit tSC
}

/// <p>The window the read actually ran over, in hours: <code>0</code> for a keyed read, which is
/// bounded by its turn key and emits no time predicate at all, and otherwise
/// <method>OcuPilot.Kernel.State.Base.BoundedWhere</method>'s own answer -- which turns a requested
/// <code>0</code> into <parameter>OcuPilot.Kernel.State.Base.BOUNDEDDEFAULTHOURS</parameter>. A view
/// that echoed the request would report <code>0</code> for a read that covered a day.</p>
ClassMethod AppliedWindow(pWindowHours As %String, pTurnKey As %String) As %Integer [ Private ]
{
    If pTurnKey '= "" Quit 0
    If +pWindowHours > 0 Quit +pWindowHours
    Quit +$Parameter("OcuPilot.Kernel.State.Base", "BOUNDEDDEFAULTHOURS")
}

/// <p>One row of <var>pValues</var> as the wire object a view carries. <code>requiredPairs</code>
/// travels as the canonical string the row stores, so a reader sees what the row was gated on.</p>
ClassMethod RowObject(ByRef pValues, pIndex As %Integer) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("ledgerId", $Get(pValues(pIndex, "ledgerId")), "string")
    Do tRow.%Set("user", $Get(pValues(pIndex, "user")), "string")
    Do tRow.%Set("loggedAt", $Get(pValues(pIndex, "loggedAt")), "string")
    Do tRow.%Set("turnKey", $Get(pValues(pIndex, "turnKey")), "string")
    Do tRow.%Set("seq", +$Get(pValues(pIndex, "seq")), "number")
    Do tRow.%Set("kind", $Get(pValues(pIndex, "kind")), "string")
    Do tRow.%Set("name", $Get(pValues(pIndex, "name")), "string")
    Do tRow.%Set("model", $Get(pValues(pIndex, "model")), "string")
    Do tRow.%Set("route", $Get(pValues(pIndex, "route")), "string")
    Do tRow.%Set("target", $Get(pValues(pIndex, "target")), "string")
    Do tRow.%Set("arguments", $Get(pValues(pIndex, "arguments")), "string")
    Do tRow.%Set("argumentsTruncated", ''$Get(pValues(pIndex, "argumentsTruncated")), "boolean")
    Do tRow.%Set("status", $Get(pValues(pIndex, "status")), "string")
    Do tRow.%Set("code", $Get(pValues(pIndex, "code")), "string")
    Do tRow.%Set("requestTokens", +$Get(pValues(pIndex, "requestTokens")), "number")
    Do tRow.%Set("responseTokens", +$Get(pValues(pIndex, "responseTokens")), "number")
    Do tRow.%Set("requiredPairs", $Get(pValues(pIndex, "requiredPairs")), "string")
    Quit tRow
}

/// <p>The wire fault a read that could not resolve answers, with <var>pStatus</var>'s raw text going
/// to the log alone (AD-39).</p>
ClassMethod Unavailable(pStatus As %Status, pMessage As %String) As %DynamicObject [ Private ]
{
    Do ..LogFailure(pMessage, pStatus)
    Quit ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#LEDGERUNAVAILABLE, ##class(OcuPilot.Api.Error).#REASONLEDGERUNAVAILABLE)
}

/// <p>Record one cross-user read of <var>pSubject</var>'s rows. The status is returned so a test can
/// observe the drop an unregistered triple produces, and every caller ignores it (AD-15).</p>
ClassMethod RecordRead(pSubject As %String, pRowsSent As %Integer, pRowsWithheld As %Integer) As %Status
{
    Set tEffects = {}
    Do tEffects.%Set("rowsSent", +pRowsSent, "number")
    Do tEffects.%Set("rowsWithheld", +pRowsWithheld, "number")
    Quit $ClassMethod(..EventClass(), "Record", ..#READVERB, ..#READENTITYTYPE, pSubject, {}, 0, tEffects, $Parameter(..EventClass(), "EVENTLEDGERREAD"))
}

/// <p>Send a ledger failure's raw text to the log and nowhere else
/// (<method>OcuPilot.Kernel.Fault.LogRaw</method>). The one reporting seam, so a test can capture
/// what a failed write reported; production never overrides it.</p>
ClassMethod LogFailure(pMessage As %String, pStatus As %Status)
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, ##class(OcuPilot.Api.Error).#LEDGERUNAVAILABLE)
}

}
