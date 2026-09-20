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

/// <p>The descriptor registry a provider row's screen route is resolved through. Overridable for
/// the same reason <method>GateClass</method> is; production never overrides it.</p>
ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Screen.Registry"
}

/// <p>What the screen route <var>pRoute</var> requires, as the gate's pair list, and
/// <code>""</code> when the turn carried no screen context, when no descriptor declares that
/// route, or when the requirement could not be read.</p>
/// <p><var>pResolved</var> is 1 only when the requirement was actually read -- a route that names
/// a descriptor whose declared set is empty answers an empty list with <var>pResolved</var> 1,
/// which is what lets <method>RecordProviderCall</method> record
/// <parameter>OcuPilot.Kernel.State.Ledger.SENSENONE</parameter> rather than a requirement nobody
/// read (DW-1305).</p>
/// <p><b>An unreadable requirement answers empty with <var>pResolved</var> 0</b>: such a row is
/// withheld from every cross-user reader (<method>ViewForUser</method>), so a route this cannot
/// resolve fails closed rather than releasing the row.</p>
/// <p><b><code>""</code> is a route, not the absence of one</b>, and it is asked of the registry
/// like any other. <class>OcuPilot.Screen.Descriptor.Home</class> declares <code>Route()</code> as
/// the empty string -- Home is the root -- and
/// <method>OcuPilot.Screen.Registry.DescriptorForRoute</method> matches a descriptor's declared
/// route exactly, so <code>""</code> answers Home and an unknown route answers nothing (verified on
/// <code>ocupilot-ci</code>: <code>"no/such/route"</code> and <code>"/"</code> both answer
/// <code>""</code>). Accepted consequence, stated rather than hidden: a turn that carried no
/// screen context records the same route value as a turn started from Home, so its row records
/// <code>none</code> too. Both are true in the same sense -- neither turn's screen required a
/// privilege -- and a cross-user reader still has to hold the ledger's own administrative pair
/// (AD-46).</p>
ClassMethod RoutePairs(pRoute As %String, Output pResolved As %Boolean) As %List [ Private ]
{
    Set tPairs = ""
    Set pResolved = 0
    Try {
        Set tDescriptor = $ClassMethod(..RegistryClass(), "DescriptorForRoute", pRoute)
        If tDescriptor = "" Quit
        Set tPairs = $ClassMethod(..GateClass(), "RequiredPairs", tDescriptor, .tResolved)
        If 'tResolved {
            Set tPairs = ""
            Quit
        }
        Set pResolved = 1
    } Catch ex {
        Set tPairs = ""
        Set pResolved = 0
    }
    Quit tPairs
}

/// <p>The four senses <property>OcuPilot.Kernel.State.Ledger.PairsSense</property> holds, each read
/// from the store's own declaration so no caller spells one.</p>
ClassMethod SenseChecked() As %String
{
    Quit $Parameter(..StoreClass(), "SENSECHECKED")
}

ClassMethod SenseDeclared() As %String
{
    Quit $Parameter(..StoreClass(), "SENSEDECLARED")
}

ClassMethod SenseRoute() As %String
{
    Quit $Parameter(..StoreClass(), "SENSEROUTE")
}

ClassMethod SenseNone() As %String
{
    Quit $Parameter(..StoreClass(), "SENSENONE")
}

/// <p>The sense a writer records: <var>pSense</var> ordinarily, and
/// <method>SenseNone</method> when the writer <b>resolved</b> its pairs (<var>pResolved</var>) and
/// there were none (DW-1305).</p>
/// <p><b>A writer that could not read its requirement keeps its own sense</b>, so its empty set
/// stays the withheld one: the distinction this method draws is between "there is no requirement"
/// and "nobody read the requirement", and only the first is safe to release.</p>
ClassMethod SenseFor(pSense As %String, pPairs As %List, pResolved As %Boolean) As %String
{
    If ''pResolved && ($ListLength(pPairs) = 0) Quit ..SenseNone()
    Quit pSense
}

/// <p><var>pNames</var> -- a <class>%List</class> of field names -- as the canonical
/// <property>OcuPilot.Kernel.State.Ledger.Fields</property> value: sorted, de-duplicated and
/// comma-joined, bounded at that column's own
/// <parameter>OcuPilot.Kernel.State.Ledger.FIELDSMAXLENGTH</parameter> and cut only on a whole-name
/// boundary, with <var>pTruncated</var> 1 when a name was left out.</p>
/// <p>A name holding <code>,</code> is dropped and reports short, for the reason
/// <method>PairsToString</method> drops a separator-bearing pair: spelled into the column it would
/// read back as two field names, neither of which the write sent. An empty name is dropped the same
/// way.</p>
ClassMethod FieldsToString(pNames As %List, Output pTruncated As %Boolean) As %String
{
    Set pTruncated = 0
    Set tOut = ""
    Kill tSeen
    Try {
        For tI = 1:1:$ListLength(pNames) {
            Set tName = $List(pNames, tI)
            If (tName = "") || (tName [ ",") {
                Set pTruncated = 1
                Continue
            }
            Set tSeen(tName) = ""
        }
        Set tMax = +$Parameter(..StoreClass(), "FIELDSMAXLENGTH")
        Set tKey = ""
        For {
            Set tKey = $Order(tSeen(tKey))
            If tKey = "" Quit
            Set tCandidate = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
            If $Length(tCandidate) > tMax {
                Set pTruncated = 1
                Quit
            }
            Set tOut = tCandidate
        }
    } Catch ex {
        Set tOut = ""
        Set pTruncated = 1
    }
    Quit tOut
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
        ; The requirement the turn actually carries: what the screen route it ran from declares.
        ; Empty where that route declares none -- Home's, whose route is the empty string -- and
        ; empty under a sense that says nobody read it where the route resolves to no descriptor
        ; at all. Only the first is released to a cross-user reader (DW-1120, DW-1305).
        Set tRoutePairs = ..RoutePairs(pRoute, .tRouteResolved)
        Set tPairs = ..PairsToString(tRoutePairs, .tPairsCut)
        ; What claim the set makes (DW-1305, DW-1321). A route this writer resolved that declares
        ; no pair -- every turn started from Home -- records "none" and is readable cross-user; a
        ; route it could not resolve keeps "route" and its empty set stays withheld.
        Set tSense = ..SenseFor(..SenseRoute(), tRoutePairs, tRouteResolved)
        Set tSC = $ClassMethod(..StoreClass(), "GuardedAppend", pTurnKey, pUser, pRoute, $Parameter(..StoreClass(), "KINDLLM"), pProvider, pModel, "", tArguments.%ToJSON(), 0, pStatus, pCode, +pRequestTokens, +pResponseTokens, tPairs, pLimitsClass, .tSeq, .tStored, tPairsCut, tSense)
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
/// <p><b><var>pClassified</var> is the caller's answer to "was a declaration read at all", and it
/// defaults to 0 so a caller who does not answer fails closed.</b> A call whose wire name resolved
/// no tool has no declaration to read, which is indistinguishable from a tool that declared none, so
/// the name pattern would be the row's only layer -- the inversion AD-3 forbids, on a row no
/// retention sweep removes. With <var>pClassified</var> 0 the model's arguments are withheld whole:
/// <code>arguments</code> stores <method>OcuPilot.Kernel.Audit.Log</method>'s redaction mark,
/// <code>argumentsTruncated</code> reads 0, and <method>RedactArguments</method> never runs, so no
/// caller-supplied value reaches the column. A reader tells the three states apart:
/// <code>""</code> means no arguments were sent, the mark alone means they were sent and withheld,
/// and an object means they were recorded field by field.</p>
/// <p><var>pPairsSense</var> is what claim the recorded pair set makes
/// (<property>OcuPilot.Kernel.State.Ledger.PairsSense</property>), resolved by the caller through
/// <method>SenseFor</method>. It is trailing and defaults to <code>""</code>, the legacy sense,
/// so a caller that does not answer leaves its row withheld from every cross-user reader.</p>
ClassMethod RecordToolCall(pTurnKey As %String, pUser As %String, pRoute As %String, pName As %String, pTarget As %String, pInput As %DynamicAbstractObject, pDeclaredPairs As %List, pArgumentPairs As %List, pSecretNames As %List, pStatus As %String, pCode As %String, pLimitsClass As %String, pClassified As %Boolean = 0, pPairsSense As %String = "") As %Status
{
    Set tSC = $$$OK
    Try {
        Set tTruncated = 0
        If pClassified {
            Set tArguments = ..RedactArguments(pInput, pSecretNames, +$Parameter(pLimitsClass, "LEDGERROWMAXLENGTH"), .tTruncated, .tRedactedNames)
        } Else {
            Set tArguments = ""
            If $IsObject(pInput) && pInput.%IsA("%Library.DynamicObject") Set tArguments = ##class(OcuPilot.Kernel.Audit.Log).#REDACTED
        }
        Set tPairs = ..PairsToString(pDeclaredPairs _ pArgumentPairs, .tPairsCut)
        Set tSC = $ClassMethod(..StoreClass(), "GuardedAppend", pTurnKey, pUser, pRoute, $Parameter(..StoreClass(), "KINDTOOL"), pName, "", pTarget, tArguments, tTruncated, pStatus, pCode, 0, 0, tPairs, pLimitsClass, .tSeq, .tStored, tPairsCut, pPairsSense)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Do ..LogFailure("a tool answer could not be recorded in the agent ledger", tSC)
    Quit tSC
}

/// <p>Open the ledger row for one confirmed write, <b>before</b> the port call (AD-41): a
/// <parameter>OcuPilot.Kernel.State.Ledger.KINDWRITE</parameter> row on the proposal's own turn key
/// at the next sequence, <parameter>OcuPilot.Kernel.State.Ledger.STATUSPENDING</parameter>, naming
/// the tool and the canonical target and nothing about the outcome. <var>pLedgerKey</var> is what
/// <method>FinalizeConfirmedWrite</method> takes, and is <code>""</code> when the turn's row cap
/// counted the call instead of storing it.</p>
/// <p><b>Why first.</b> A row that only ever appeared on success could not record a write that
/// raised mid-flight, which is the one case an operator most needs to find; the
/// <code>pending</code> row left behind is that trace.</p>
/// <p><b>Never fails the confirm</b> (AD-15): the status is logged by this class and the caller
/// does not propagate it.</p>
ClassMethod OpenConfirmedWrite(pTurnKey As %String, pUser As %String, pToolName As %String, pTargetRef As %String, pLimitsClass As %String, Output pLedgerKey As %String) As %Status
{
    Set pLedgerKey = ""
    Set tSC = $$$OK
    Try {
        Set tStore = ..StoreClass()
        Set tSC = $ClassMethod(tStore, "GuardedAppend", pTurnKey, pUser, "", $Parameter(tStore, "KINDWRITE"), pToolName, "", pTargetRef, "", 0, $Parameter(tStore, "STATUSPENDING"), "", 0, 0, "", pLimitsClass, .tSeq, .tStored, 0, "", .pLedgerKey)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Do ..LogFailure("a confirmed write could not be opened in the agent ledger", tSC)
    Quit tSC
}

/// <p>Finalize the row <method>OpenConfirmedWrite</method> opened with what was actually executed
/// (AD-41): <var>pStatus</var> and <var>pCode</var> as the port answered them, <var>pTargetRef</var>
/// the canonical reference the write was issued against, <var>pFieldNames</var> the names the body
/// carried, <var>pPairs</var> the <code>(resource, permission)</code> pairs the confirm evaluated,
/// and <var>pAuditMarked</var> the marker's own outcome.</p>
/// <p><b>Secret-declared names never reach <var>pFieldNames</var></b> -- the caller excludes them
/// at write time rather than redacting them here (AD-3, AD-41), so no name a descriptor declared
/// secret is ever stored and then removed.</p>
/// <p>The pair set is recorded with <method>SenseChecked</method>: the confirm evaluates the tool's
/// declared pairs against the caller's live grants before it claims, so the row states a
/// requirement somebody checked -- and <method>SenseFor</method> records
/// <method>SenseNone</method> where that requirement was resolved and empty.</p>
/// <p><b>Never fails the confirm</b> (AD-15), for the reason above.</p>
ClassMethod FinalizeConfirmedWrite(pLedgerKey As %String, pStatus As %String, pCode As %String, pTargetRef As %String, pFieldNames As %List, pPairs As %List, pAuditMarked As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tFields = ..FieldsToString(pFieldNames, .tFieldsCut)
        Set tPairs = ..PairsToString(pPairs, .tPairsCut)
        Set tSense = ..SenseFor(..SenseChecked(), pPairs, 1)
        Set tSC = $ClassMethod(..StoreClass(), "GuardedFinalize", pLedgerKey, pStatus, pCode, pTargetRef, tFields, tFieldsCut, tPairs, tPairsCut, tSense, pAuditMarked)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Do ..LogFailure("a confirmed write could not be finalized in the agent ledger", tSC)
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
/// <p><var>pRedactedNames</var> comes back as the top-level names <b>the layers changed</b> -- a
/// key whose value the caller already sent as the mark is not reported, because it is evidence
/// about what the caller sent and not about what redaction did. <b>Every declared name must read as
/// the mark afterwards and no declared value may survive into the answer</b>; if either stops being
/// true this answers <code>""</code> and logs rather than storing a string that may carry a secret.
/// The value scan is a substring test, so a declared value that also appears under another key
/// trips it and costs that row its argument string -- except a declared value that is itself the
/// mark, which the answer necessarily carries and which reveals nothing. Fail-closed is the right
/// direction here: a missing argument string costs a reader context, and a leaked one reaches
/// OcuPilot's own screens (AD-35, AD-46).</p>
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
                ; The mark itself is skipped: a caller who sent it is not a secret that survived,
                ; and the answer carries the mark for every redacted key by construction.
                If (tValue '= "") && (tValue '= ##class(OcuPilot.Kernel.Audit.Log).#REDACTED) Set tValues = tValues _ $ListBuild(tValue)
            }
            Do tCopy.%Set(tName, ##class(OcuPilot.Kernel.Audit.Log).#REDACTED, "string")
            Set tDeclared = tDeclared _ $ListBuild(tName)
        }
        Set tCandidate = ##class(OcuPilot.Kernel.Agent.Dispatch).RedactedArguments(tCopy, pMaxLength, .tTruncated)
        Set tNames = ..RedactedKeys(pInput, ##class(OcuPilot.Kernel.Audit.Log).Redact(tCopy), .tMarked)
        Set tSound = 1
        For tI = 1:1:$ListLength(tDeclared) {
            ; Soundness is asked of the marked set, not the changed one: a declared name the caller
            ; already sent the mark under is redacted and is simply not this layer's doing.
            If '$ListFind(tMarked, $List(tDeclared, tI)) Set tSound = 0
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

/// <p>The top-level names of <var>pAfter</var> whose value is
/// <parameter>OcuPilot.Kernel.Audit.Log.REDACTED</parameter>, split by provenance against
/// <var>pBefore</var>: the answer is the names redaction <b>changed</b> -- the mark is there now and
/// was not there before -- and <var>pMarked</var> is every name reading as the mark whatever it read
/// before.</p>
/// <p>The two differ only for a caller who sent the mark as a value. Reporting that key as redacted
/// would report the caller's own input as evidence that a secret was masked, which is a claim about
/// a masking that did not happen; it is still in <var>pMarked</var>, because the stored string does
/// read as the mark there.</p>
ClassMethod RedactedKeys(pBefore As %DynamicAbstractObject, pAfter As %DynamicAbstractObject, Output pMarked As %List) As %List [ Private ]
{
    Set pMarked = ""
    Set tNames = ""
    Try {
        If '$IsObject(pAfter) Quit
        Set tMark = ##class(OcuPilot.Kernel.Audit.Log).#REDACTED
        Set tIterator = pAfter.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue, .tType) {
            If (tType '= "string") || (tValue '= tMark) Continue
            Set pMarked = pMarked _ $ListBuild(tKey)
            Set tWas = ""
            If $IsObject(pBefore) && (pBefore.%GetTypeOf(tKey) = "string") Set tWas = pBefore.%Get(tKey)
            If tWas '= tMark Set tNames = tNames _ $ListBuild(tKey)
        }
    } Catch ex {
        Set pMarked = ""
        Set tNames = ""
    }
    Quit tNames
}

/// <p><var>pPairs</var> -- a <class>%List</class> of <code>$ListBuild(resource, permission)</code>
/// -- as the canonical column value: each pair spelled <code>resource:permission</code>, sorted,
/// de-duplicated and comma-joined. A malformed member is dropped.</p>
/// <p><b>Bounded at <parameter>OcuPilot.Kernel.State.Ledger.PAIRSMAXLENGTH</parameter>, cutting
/// only on a whole-pair boundary</b> (AD-24, AD-41), with <var>pTruncated</var> 1 when a pair was
/// left out. A half pair would read back as a pair requiring a permission nobody named, and no
/// U+2026 mark is appended for the same reason: a pair set is not display text, so a mark would
/// itself parse as a bogus pair. An over-long set records the pairs it can and says it is short;
/// <method>ViewForUser</method> is what refuses to gate on it. A malformed member that raises
/// discards every pair, which is the same thing maximally, so it answers <var>pTruncated</var> 1
/// too: an empty set reads back as a call that required nothing, which a cross-user read would
/// release.</p>
/// <p><b>A pair this grammar cannot spell is left out and the set reports
/// <var>pTruncated</var> 1</b> -- a member that is not a two-element list, a member with an empty
/// half, and a member holding <code>,</code> or <code>:</code> in either half. Spelled into the
/// column, a separator-bearing pair would read back through <method>StringToPairs</method> as some
/// other pair, a resource nobody named at a permission nobody named; dropped in silence, any of
/// them leaves the column stating a smaller requirement than the call had. Either way a cross-user
/// read gating on it would release the row, so the set is reported short and the row is withheld
/// instead, by the same signal an over-long set uses.</p>
ClassMethod PairsToString(pPairs As %List, Output pTruncated As %Boolean) As %String
{
    Set pTruncated = 0
    Set tOut = ""
    Kill tSeen
    Try {
        For tI = 1:1:$ListLength(pPairs) {
            Set tPair = $List(pPairs, tI)
            ; Every pair this walk drops reports short, whatever the reason it could not be
            ; spelled: a set silently one pair lighter reads back as a smaller requirement than
            ; the call had, which is the release a cross-user read must not make.
            If '$ListValid(tPair) || ($ListLength(tPair) '= 2) {
                Set pTruncated = 1
                Continue
            }
            Set tResource = $List(tPair, 1)
            Set tPermission = $List(tPair, 2)
            If (tResource = "") || (tPermission = "") {
                Set pTruncated = 1
                Continue
            }
            ; Tested on the halves joined, because a separator in either one is the same defect.
            Set tJoined = tResource _ tPermission
            If (tJoined [ ",") || (tJoined [ ":") {
                Set pTruncated = 1
                Continue
            }
            Set tSeen(tResource _ ":" _ tPermission) = ""
        }
        Set tMax = +$Parameter(..StoreClass(), "PAIRSMAXLENGTH")
        Set tKey = ""
        For {
            Set tKey = $Order(tSeen(tKey))
            If tKey = "" Quit
            Set tCandidate = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
            If $Length(tCandidate) > tMax {
                Set pTruncated = 1
                Quit
            }
            Set tOut = tCandidate
        }
    } Catch ex {
        Set tOut = ""
        Set pTruncated = 1
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
/// <code>requiredPairs</code> evaluated through <method>OcuPilot.Screen.Gate.EvaluateRequired</method>,
/// on which a row that recorded no requirement is never held (DW-1120).
/// A row the caller cannot hold is absent from <code>rows</code> and counted in
/// <code>rowsWithheld</code>; it is never returned with fields removed, because a row's identity is
/// itself the thing withheld. A non-empty requirement that yields no pair is withheld too: a
/// requirement that will not parse is not an absent one.</p>
/// <p><b>One empty set is readable</b> (DW-1305): a row whose
/// <property>OcuPilot.Kernel.State.Ledger.PairsSense</property> is
/// <method>SenseNone</method> recorded that its writer resolved the pairs and found none, so it
/// states a requirement and the requirement is nothing. Every other sense with an empty or
/// unparseable set, and every row stored before that column existed, stays withheld.</p>
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
            If ''$Get(tValues(tI, "requiredPairsTruncated")) {
                ; A cut pair set records fewer pairs than the call required, so evaluating it
                ; would release the row on a requirement nobody named. Fails closed, with the
                ; ledger (AD-46), and is counted like any other withheld row.
                Set tWithheld = tWithheld + 1
                Continue
            }
            Set tPairsText = $Get(tValues(tI, "requiredPairs"))
            Set tPairs = ..StringToPairs(tPairsText)
            If (tPairsText '= "") && (tPairs = "") {
                Set tWithheld = tWithheld + 1
                Continue
            }
            ; An empty set is two different facts, told apart by the sense the writer recorded
            ; (DW-1305, DW-1321). "none" is "the writer resolved the pairs and there were none",
            ; so the row requires nothing and is readable. Every other sense with an empty set --
            ; and every legacy row, whose sense is "" -- is a requirement nobody read, and stays
            ; withheld exactly as it was.
            If (tPairs = "") && ($Get(tValues(tI, "pairsSense")) = ..SenseNone()) {
                Do tRows.%Push(..RowObject(.tValues, tI))
                Continue
            }
            ; EvaluateRequired, not EvaluatePairs: a row whose recorded requirement is empty
            ; names no check anybody made, so releasing on it would release on a requirement
            ; nobody named (DW-1120).
            If '$ClassMethod(..GateClass(), "EvaluateRequired", tPairs, .tFailedPair) {
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
/// travels as the canonical string the row stores, so a reader sees what the row was gated on, and
/// <code>pairsSense</code> beside it says what claim that string makes (DW-1321).
/// <code>auditMarked</code> is a confirmed write's own marker outcome (AD-15) and <code>""</code>
/// on every other kind.</p>
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
    Do tRow.%Set("requiredPairsTruncated", ''$Get(pValues(pIndex, "requiredPairsTruncated")), "boolean")
    Do tRow.%Set("pairsSense", $Get(pValues(pIndex, "pairsSense")), "string")
    Do tRow.%Set("auditMarked", $Get(pValues(pIndex, "auditMarked")), "string")
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
