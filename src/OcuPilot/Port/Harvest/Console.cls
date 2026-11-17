/// <p>The cut, argument and by-reference methods of the command and class-method consoles (AD-23), harvested from the
/// sibling's utility class at <code>c6aad31</code>: <method>ApplyOutputCeiling</method>, <method>SurrogateSafeCutLength</method>,
/// <method>ParseArgEntry</method>, <method>BuildByRefNode</method>, <method>AddByRefPosition</method> and
/// <method>InvokeWithArgs</method>, whose code is the sibling's after three renames: the process-private flag that marked a
/// capture overflow, the cut marker's text and a sibling file name in a comment. A harvested handler class, called only through
/// <class>OcuPilot.Port.HarvestPort</class>; <class>OcuPilot.Port.Harvest.ConsoleRun</class> extends it so the calls resolve
/// while the namespace is switched. Story 24.6.</p>
Class OcuPilot.Port.Harvest.Console Extends OcuPilot.Port.Harvest.Handler
{

/// <p>The most characters one answer's return value, by-reference values and device output share.</p>
Parameter OUTPUTCEILING As %Integer = 32768;

/// <p>The most nodes the by-reference values of one answer hold.</p>
Parameter BYREFNODECEILING As %Integer = 1000;

/// <p>Cut <var>pOutput</var> to <var>pCeiling</var> characters (<parameter>OUTPUTCEILING</parameter> when omitted),
/// ending a cut text with the marker <code>[cut at &lt;n&gt; characters]</code> between two line feeds, and set
/// <var>pTruncated</var> only when it cuts: a true value the caller passes in is left alone. The result is never longer
/// than <var>pCeiling</var> or than <var>pOutput</var>; where the marker does not fit it is a plain cut. The cut never
/// falls inside a surrogate pair (<method>SurrogateSafeCutLength</method>).</p>
ClassMethod ApplyOutputCeiling(pOutput As %String, ByRef pTruncated As %Boolean, pCeiling As %Integer = -1) As %String
{
    Set tCeiling = pCeiling
    If tCeiling < 0 { Set tCeiling = ..#OUTPUTCEILING }
    Set tLen = $Length(pOutput)
    If tLen <= tCeiling {
        Quit pOutput
    }
    Set pTruncated = 1
    Set tMarker = $Char(10)_"[cut at "_tCeiling_" characters]"_$Char(10)
    ; Story 34.6 CR-6/CR-8/CR-9: the marker does not fit within a small remaining
    ; ceiling — appending it anyway would both exceed the ceiling AND replace a SMALLER
    ; original value with something LARGER. Fall back to a marker-less hard cut so the
    ; result is always bounded by tCeiling and never bigger than pOutput itself.
    If $Length(tMarker) > tCeiling {
        Set tKeep = ..SurrogateSafeCutLength(pOutput, tCeiling)
        Quit $Extract(pOutput, 1, tKeep)
    }
    Set tKeep = tCeiling - $Length(tMarker)
    Set tKeep = ..SurrogateSafeCutLength(pOutput, tKeep)
    Quit $Extract(pOutput, 1, tKeep) _ tMarker
}

/// <p>The cut length <var>pLen</var>, one less when the character at it is the first half of a surrogate pair, so a cut
/// never strands the second half. <var>pLen</var> unchanged otherwise, and never below 0.</p>
ClassMethod SurrogateSafeCutLength(pStr As %String, pLen As %Integer) As %Integer
{
    Set tLen = pLen
    If tLen > 0 {
        Set tLastCode = $Ascii(pStr, tLen)
        If (tLastCode >= 55296) && (tLastCode <= 56319) {
            Set tLen = tLen - 1
        }
    }
    Quit tLen
}

/// <p>Read position <var>pPosition</var> of the argument array <var>pArgs</var>: a text, number or boolean is passed by value;
/// <code>{"byRef": true|false, "value": &lt;scalar&gt;}</code> marks a pass by reference, and
/// <code>{"byRef": true}</code> with no value passes an undefined argument. <var>pIsByRef</var> says which, and
/// <var>pValue</var> is the value, left undefined for the last form. A <code>null</code>, an array, a marker whose
/// <code>byRef</code> is not a boolean, <code>{"byRef": false}</code> with no value, and a marker whose value is
/// <code>null</code> or not a scalar are refused with the position named.</p>
ClassMethod ParseArgEntry(pArgs As %DynamicArray, Output pValue, Output pIsByRef As %Boolean, pPosition As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pIsByRef = 0
    Try {
        ; A bare JSON null element is rejected rather than silently aliased to "" —
        ; the same rule the marker path applies to `value: null` (AC 34.2.6/R6). Without
        ; this, `args:[null]` and `args:[""]` were indistinguishable to the target while
        ; `{"byRef":true,"value":null}` was loudly rejected — an inconsistency found at
        ; code review (Rule #56: the shape was missing from the R7 enumeration).
        If pArgs.%GetTypeOf(pPosition) = "null" {
            Set tSC = $$$ERROR($$$GeneralError, "Argument "_pPosition_" cannot be JSON null; use {""byRef"":true} for an undefined argument, or """" for an empty string")
            Quit
        }
        Set pEntry = pArgs.%Get(pPosition)
        If '$IsObject(pEntry) {
            Set pValue = pEntry
            Quit
        }
        If $ClassName(pEntry) = "%Library.DynamicArray" {
            Set tSC = $$$ERROR($$$GeneralError, "Argument "_pPosition_" is a JSON array; expected a scalar or a {byRef, value} marker object")
            Quit
        }
        Set tByRefType = pEntry.%GetTypeOf("byRef")
        If tByRefType = "unassigned" {
            Set tSC = $$$ERROR($$$GeneralError, "Argument "_pPosition_" is an object without a 'byRef' key; expected a scalar or a {byRef, value} marker object")
            Quit
        }
        If tByRefType '= "boolean" {
            Set tSC = $$$ERROR($$$GeneralError, "Argument "_pPosition_": 'byRef' must be a JSON boolean")
            Quit
        }
        Set pIsByRef = pEntry.%Get("byRef")
        Set tValueType = pEntry.%GetTypeOf("value")
        If tValueType = "unassigned" {
            If 'pIsByRef {
                Set tSC = $$$ERROR($$$GeneralError, "Argument "_pPosition_": marker with byRef:false must include a 'value'")
            } Else {
                ; Output-style undefined-in: leave pValue genuinely undefined.
                Kill pValue
            }
            Quit
        }
        If tValueType = "null" {
            Set tSC = $$$ERROR($$$GeneralError, "Argument "_pPosition_": marker 'value' cannot be JSON null; omit 'value' entirely for an undefined argument")
            Quit
        }
        If (tValueType = "object") || (tValueType = "array") {
            Set tSC = $$$ERROR($$$GeneralError, "Argument "_pPosition_": marker 'value' must be a scalar (string, number, or boolean)")
            Quit
        }
        Set pValue = pEntry.%Get("value")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The after-call value of the by-reference local <var>pLocal</var>: its scalar when it has no subscripts, otherwise
/// <code>{value, subscripts}</code> built subscript by subscript (<code>subscriptsTruncated</code> set when a budget stops
/// it). An object value is shown as <code>&lt;Object:Class&gt;</code>. <var>pNodeBudget</var> and <var>pByteBudget</var> are
/// shared by every call of one answer: a node costs one, and a value and a subscript key cost their length. Either running
/// out sets <var>pByRefTruncated</var>. Call it only for a local that holds something.</p>
ClassMethod BuildByRefNode(ByRef pLocal, ByRef pNodeBudget As %Integer, ByRef pByteBudget As %Integer, ByRef pByRefTruncated As %Boolean)
{
    ; Every call materializes exactly one tree node — charge it against the shared
    ; structural budget regardless of whether it turns out to be a leaf or a container.
    Set pNodeBudget = pNodeBudget - 1
    Set tData = $Data(pLocal)
    ; Guard against an OREF out-value (a target that mutates a by-ref local to hold an
    ; object reference) — mirrors the returnValue $IsObject guard in ClassMethod(), so a
    ; non-JSON-serializable OREF can never reach RenderResponseBody.
    ; The guard is applied to the node's own VALUE at EVERY $Data shape, not just the
    ; leaf case: `Set pOut = obj  Set pOut("k") = 1` is legal ObjectScript ($Data=11), and
    ; code review reproduced live (2026-08-14) that an unguarded OREF there reaches
    ; %ToJSON INSIDE RenderResponseBody — after the response has begun — truncating the
    ; body into an unparseable envelope with HTTP 200. That is the very failure class this
    ; epic exists to fix, so the check must not sit inside the tData=1 arm.
    Set tHasValue = (tData # 10)
    If tHasValue {
        If $IsObject(pLocal) {
            Set tValue = "<Object:"_$ClassName(pLocal)_">"
            ; Story 34.6 code review (cycle 2): the OREF placeholder is EMITTED CONTENT
            ; and must be charged like any other leaf value. Before this it was the one
            ; value shape that consumed payload without ever decrementing the budget, so
            ; a target returning many OREF out-values shipped tens of KB with the byte
            ; budget still reading its full 32768 and byRefTruncated still false.
            Set pByteBudget = pByteBudget - $Length(tValue)
            If pByteBudget < 0 { Set pByteBudget = 0 }
        } Else {
            ; Charge this leaf's value against the shared byte budget (AC 34.6.1) by
            ; truncating it to WHATEVER REMAINS of that budget right now — reuses
            ; ApplyOutputCeiling (same marker format as the output field) with an
            ; EXPLICIT ceiling instead of the default, so a value that is itself under
            ; OUTPUTCEILING but arrives after other leaves have already spent most of
            ; the shared budget is truncated to the remainder in ONE pass (never
            ; double-truncated: OUTPUTCEILING first, then the remaining budget again).
            Set tValue = ..ApplyOutputCeiling(pLocal, .pByRefTruncated, pByteBudget)
            Set pByteBudget = pByteBudget - $Length(tValue)
            If pByteBudget < 0 { Set pByteBudget = 0 }
        }
    }
    If tData = 1 {
        Quit tValue
    }
    Set tResult = {}
    If tHasValue {
        Do tResult.%Set("value", tValue)
    }
    Set tSubs = {}
    Set tKey = ""
    Set tCut = 0
    For {
        Set tKey = $Order(pLocal(tKey))
        Quit:tKey=""
        If (pNodeBudget <= 0) || (pByteBudget <= 0) {
            Set tCut = 1
            Quit
        }
        ; Story 34.6 code review (cycle 2): a subscript KEY is emitted content too, and
        ; was previously never charged — so a long-keyed Output array (file paths, URLs,
        ; composite keys: an entirely idiomatic ObjectScript Output shape) shipped a
        ; byRefValues payload arbitrarily larger than the documented budget while
        ; byRefTruncated still read false. Measured live before this fix: 400 positions
        ; keyed by 900-character strings emitted 363,908 characters against a
        ; 32768-character budget, with 32,368 of that budget still reported unspent.
        ; Charge the key BEFORE descending; if the key alone would consume the rest of
        ; the budget, stop here instead of descending with a zero budget (which would
        ; force the child's value to the ambiguous empty string AddByRefPosition's
        ; banner deliberately avoids). This keeps pByteBudget >= 1 at every recursive
        ; entry, so ApplyOutputCeiling is never called with a zero ceiling.
        If $Length(tKey) >= pByteBudget {
            Set pByteBudget = 0
            Set tCut = 1
            Quit
        }
        Set pByteBudget = pByteBudget - $Length(tKey)
        Kill tChild
        Merge tChild = pLocal(tKey)
        Do tSubs.%Set(tKey, ..BuildByRefNode(.tChild, .pNodeBudget, .pByteBudget, .pByRefTruncated))
    }
    If tCut {
        Set pByRefTruncated = 1
        Do tResult.%Set("subscriptsTruncated", 1, "boolean")
    }
    Do tResult.%Set("subscripts", tSubs)
    Quit tResult
}

/// <p>Add the node of argument position <var>pKey</var> to <var>pByRefValues</var> under the budgets
/// <method>BuildByRefNode</method> shares. A position reached after either budget is spent is left out, and
/// <var>pByRefTruncated</var> is set.</p>
ClassMethod AddByRefPosition(pByRefValues As %DynamicObject, pKey As %Integer, ByRef pLocal, ByRef pNodeBudget As %Integer, ByRef pByteBudget As %Integer, ByRef pByRefTruncated As %Boolean)
{
    If (pNodeBudget <= 0) || (pByteBudget <= 0) {
        Set pByRefTruncated = 1
        Quit
    }
    Do pByRefValues.%Set(pKey, ..BuildByRefNode(.pLocal, .pNodeBudget, .pByteBudget, .pByRefTruncated))
    Quit
}

/// <p>Call the class method <var>pMethodName</var> of <var>pClassName</var> in the current namespace with at most 20
/// positional arguments from the JSON array <var>pArgs</var> (<method>ParseArgEntry</method>'s shapes). Every position is
/// passed by reference, and the ones marked by reference are read back into <var>pByRefValues</var>, keyed by position from 0,
/// when the call ends without an error. <var>pReturn</var> is the method's own return value. <var>pArgCount</var> is the
/// number of arguments. An argument list that is not an array or holds more than 20, and an error the method raises, are
/// returned as an error status.</p>
/// <p>One pool of <parameter>OUTPUTCEILING</parameter> characters is spent on the return value, then the by-reference values,
/// then the device output. <var>pOutputBudget</var> is what is left for the output; <var>pTruncated</var> and
/// <var>pByRefTruncated</var> say that the output and the by-reference values were cut. The caller cuts the return
/// value itself.</p>
ClassMethod InvokeWithArgs(pClassName As %String, pMethodName As %String, pArgs, Output pReturn, Output pByRefValues As %DynamicObject, Output pArgCount As %Integer, Output pTruncated As %Boolean, Output pByRefTruncated As %Boolean, Output pOutputBudget As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pReturn = ""
    Set pByRefValues = {}
    Set pArgCount = 0
    Set pTruncated = 0
    Set pByRefTruncated = 0
    ; Story 34.7 AC 34.7.3: default to the FULL shared budget so a caller that never
    ; reaches the shared-budget computation below (an early validation error, or a
    ; genuine target throw — see the $$$ISERR(tSC) Quit right before that computation)
    ; still gets a well-defined value, matching this method's pre-34.7 behavior exactly
    ; (the command body's own output ceiling was always the full OUTPUTCEILING on those paths).
    Set pOutputBudget = ..#OUTPUTCEILING
    Kill %OcuPilotConsoleTruncated
    Try {
        ; Validate args shape (AC 34.2.6/R12) — must be a JSON array, or absent/empty.
        If $IsObject(pArgs) {
            If $ClassName(pArgs) '= "%Library.DynamicArray" {
                Set tSC = $$$ERROR($$$GeneralError, "'args' must be a JSON array")
                Quit
            }
            Set pArgCount = pArgs.%Size()
        } ElseIf (pArgs '= "") {
            Set tSC = $$$ERROR($$$GeneralError, "'args' must be a JSON array")
            Quit
        }

        If pArgCount > 20 {
            Set tSC = $$$ERROR($$$GeneralError, "Too many arguments: maximum is 20, received "_pArgCount)
            Quit
        }

        ; Materialize each supplied position into its own named local (AC 34.2.2,
        ; 34.2.6/R6, 34.2.6/R7) — explicit per-position ladder, see method banner.
        Set tByRef0=0, tByRef1=0, tByRef2=0, tByRef3=0, tByRef4=0
        Set tByRef5=0, tByRef6=0, tByRef7=0, tByRef8=0, tByRef9=0
        Set tByRef10=0, tByRef11=0, tByRef12=0, tByRef13=0, tByRef14=0
        Set tByRef15=0, tByRef16=0, tByRef17=0, tByRef18=0, tByRef19=0
        If pArgCount > 0  { Set tSC = ..ParseArgEntry(pArgs, .tA0, .tByRef0, 0)     If $$$ISERR(tSC) Quit }
        If pArgCount > 1  { Set tSC = ..ParseArgEntry(pArgs, .tA1, .tByRef1, 1)     If $$$ISERR(tSC) Quit }
        If pArgCount > 2  { Set tSC = ..ParseArgEntry(pArgs, .tA2, .tByRef2, 2)     If $$$ISERR(tSC) Quit }
        If pArgCount > 3  { Set tSC = ..ParseArgEntry(pArgs, .tA3, .tByRef3, 3)     If $$$ISERR(tSC) Quit }
        If pArgCount > 4  { Set tSC = ..ParseArgEntry(pArgs, .tA4, .tByRef4, 4)     If $$$ISERR(tSC) Quit }
        If pArgCount > 5  { Set tSC = ..ParseArgEntry(pArgs, .tA5, .tByRef5, 5)     If $$$ISERR(tSC) Quit }
        If pArgCount > 6  { Set tSC = ..ParseArgEntry(pArgs, .tA6, .tByRef6, 6)     If $$$ISERR(tSC) Quit }
        If pArgCount > 7  { Set tSC = ..ParseArgEntry(pArgs, .tA7, .tByRef7, 7)     If $$$ISERR(tSC) Quit }
        If pArgCount > 8  { Set tSC = ..ParseArgEntry(pArgs, .tA8, .tByRef8, 8)     If $$$ISERR(tSC) Quit }
        If pArgCount > 9  { Set tSC = ..ParseArgEntry(pArgs, .tA9, .tByRef9, 9)     If $$$ISERR(tSC) Quit }
        If pArgCount > 10 { Set tSC = ..ParseArgEntry(pArgs, .tA10, .tByRef10, 10) If $$$ISERR(tSC) Quit }
        If pArgCount > 11 { Set tSC = ..ParseArgEntry(pArgs, .tA11, .tByRef11, 11) If $$$ISERR(tSC) Quit }
        If pArgCount > 12 { Set tSC = ..ParseArgEntry(pArgs, .tA12, .tByRef12, 12) If $$$ISERR(tSC) Quit }
        If pArgCount > 13 { Set tSC = ..ParseArgEntry(pArgs, .tA13, .tByRef13, 13) If $$$ISERR(tSC) Quit }
        If pArgCount > 14 { Set tSC = ..ParseArgEntry(pArgs, .tA14, .tByRef14, 14) If $$$ISERR(tSC) Quit }
        If pArgCount > 15 { Set tSC = ..ParseArgEntry(pArgs, .tA15, .tByRef15, 15) If $$$ISERR(tSC) Quit }
        If pArgCount > 16 { Set tSC = ..ParseArgEntry(pArgs, .tA16, .tByRef16, 16) If $$$ISERR(tSC) Quit }
        If pArgCount > 17 { Set tSC = ..ParseArgEntry(pArgs, .tA17, .tByRef17, 17) If $$$ISERR(tSC) Quit }
        If pArgCount > 18 { Set tSC = ..ParseArgEntry(pArgs, .tA18, .tByRef18, 18) If $$$ISERR(tSC) Quit }
        If pArgCount > 19 { Set tSC = ..ParseArgEntry(pArgs, .tA19, .tByRef19, 19) If $$$ISERR(tSC) Quit }
        If $$$ISERR(tSC) Quit

        ; Dispatch — literal arity-specific ladder (0..20); every position dot-passed
        ; so by-ref binding works regardless of the target's own declared signature
        ; (Story 34.1 Finding 1 / Finding E). Wrapped separately so a capture <MAXSTRING>
        ; — a partial success, not a failure — doesn't skip the by-ref read-back below;
        ; any GENUINE target throw still short-circuits it and returns as a real error.
        Try {
            If pArgCount = 0 {
                Set pReturn = $ClassMethod(pClassName, pMethodName)
            } ElseIf pArgCount = 1 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0)
            } ElseIf pArgCount = 2 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1)
            } ElseIf pArgCount = 3 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2)
            } ElseIf pArgCount = 4 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3)
            } ElseIf pArgCount = 5 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4)
            } ElseIf pArgCount = 6 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5)
            } ElseIf pArgCount = 7 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5, .tA6)
            } ElseIf pArgCount = 8 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5, .tA6, .tA7)
            } ElseIf pArgCount = 9 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5, .tA6, .tA7, .tA8)
            } ElseIf pArgCount = 10 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5, .tA6, .tA7, .tA8, .tA9)
            } ElseIf pArgCount = 11 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5, .tA6, .tA7, .tA8, .tA9, .tA10)
            } ElseIf pArgCount = 12 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5, .tA6, .tA7, .tA8, .tA9, .tA10, .tA11)
            } ElseIf pArgCount = 13 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5, .tA6, .tA7, .tA8, .tA9, .tA10, .tA11, .tA12)
            } ElseIf pArgCount = 14 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5, .tA6, .tA7, .tA8, .tA9, .tA10, .tA11, .tA12, .tA13)
            } ElseIf pArgCount = 15 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5, .tA6, .tA7, .tA8, .tA9, .tA10, .tA11, .tA12, .tA13, .tA14)
            } ElseIf pArgCount = 16 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5, .tA6, .tA7, .tA8, .tA9, .tA10, .tA11, .tA12, .tA13, .tA14, .tA15)
            } ElseIf pArgCount = 17 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5, .tA6, .tA7, .tA8, .tA9, .tA10, .tA11, .tA12, .tA13, .tA14, .tA15, .tA16)
            } ElseIf pArgCount = 18 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5, .tA6, .tA7, .tA8, .tA9, .tA10, .tA11, .tA12, .tA13, .tA14, .tA15, .tA16, .tA17)
            } ElseIf pArgCount = 19 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5, .tA6, .tA7, .tA8, .tA9, .tA10, .tA11, .tA12, .tA13, .tA14, .tA15, .tA16, .tA17, .tA18)
            } ElseIf pArgCount = 20 {
                Set pReturn = $ClassMethod(pClassName, pMethodName, .tA0, .tA1, .tA2, .tA3, .tA4, .tA5, .tA6, .tA7, .tA8, .tA9, .tA10, .tA11, .tA12, .tA13, .tA14, .tA15, .tA16, .tA17, .tA18, .tA19)
            } Else {
                ; Unreachable today (pArgCount comes from %Size() and >20 is rejected
                ; above), but the pre-Story-34.2 ladder carried this defence and losing it
                ; would let a future refactor fall through all 21 branches, never call the
                ; target, and still report success with an empty returnValue.
                Set tSC = $$$ERROR($$$GeneralError, "Internal error: unsupported argument count "_pArgCount)
            }
        } Catch exTarget {
            ; Only a <MAXSTRING> raised INSIDE this request's own capture labels means the
            ; capture buffer overflowed — that is the AC 34.2.6/R2 partial-success case.
            ; A <MAXSTRING> the TARGET itself raised (its own concatenation overflowing),
            ; or any error whose text merely MENTIONS the token, is a genuine failure and
            ; must surface as a real, sanitizable error — never as a success envelope with
            ; truncated:true, which would report a crash as a truncation and mask the real
            ; %Status (Rule #9). Code review reproduced both false positives live.
            ; Discriminator grounded in live-probed reality (2026-08-14, Rule #36): a
            ; capture overflow reports Name="<MAXSTRING>" and Location="wstr^<mnemonic
            ; routine>" — a Redirects() entry point in the command body; a target's own
            ; overflow reports its own label (e.g. "ThrowOwnMaxString+3^SomeRoutine").
            Set tTargetStatus = exTarget.AsStatus()
            Set tThrowLabel = $Piece($Piece(exTarget.Location, "^", 1), "+", 1)
            If (exTarget.Name = "<MAXSTRING>") && ($ListFind($ListBuild("wstr", "wchr", "wnl", "wff", "wtab"), tThrowLabel) > 0) {
                Set pTruncated = 1
            } Else {
                Set tSC = tTargetStatus
            }
        }
        ; 34-2-R1: fold in the label-level capture-overflow flag (see the command body's
        ; Redirects() and this method's banner) regardless of which path set tSC — a
        ; target that swallowed a MAXSTRING via its own Try/Catch never throws here at
        ; all, so this is the only place that observes it for such a target.
        Set pTruncated = pTruncated || $Get(%OcuPilotConsoleTruncated, 0)
        Kill %OcuPilotConsoleTruncated
        ; A genuine target error skips the read-back below and is returned as-is; only the
        ; capture-truncation path (tSC still OK) reaches byRefValues assembly.
        If $$$ISERR(tSC) Quit

        ; Story 34.7 AC 34.7.3: determine how much of the ONE shared response budget
        ; returnValue's own (independently, identically computed) truncation in
        ; the command body WILL consume, so byRefValues — second in priority — starts with
        ; whatever is left rather than always resetting to the full ceiling. See this
        ; method's banner for why pReturn itself is left untouched here.
        Set tRVForBudget = $Select($IsObject(pReturn): "<Object:"_$ClassName(pReturn)_">", 1: pReturn)
        Set tRVTruncatedForBudget = 0
        Set tRVForBudget = ..ApplyOutputCeiling(tRVForBudget, .tRVTruncatedForBudget, ..#OUTPUTCEILING)
        Set pOutputBudget = ..#OUTPUTCEILING - $Length(tRVForBudget)
        If pOutputBudget < 0 { Set pOutputBudget = 0 }

        ; Assemble byRefValues for marked positions only (AC 34.2.2, 34.2.6/R1, R6) —
        ; direct-by-name access; omit the key when the local is still genuinely
        ; undefined after the call (Residual Risk: "undefined out-value").
        ; Story 34.6 AC 34.6.1: tByRefNodeBudget/tByRefByteBudget are initialized ONCE
        ; and threaded (ByRef) through every position below, so the budget spans the
        ; WHOLE byRefValues structure rather than resetting per position.
        ; Story 34.6 code-review finding CR-6: each position is routed through
        ; AddByRefPosition (not BuildByRefNode directly), which OMITS the position once
        ; either budget is already exhausted instead of risking a small value being
        ; replaced by a larger elision marker — see AddByRefPosition's banner.
        ; Story 34.7 AC 34.7.3: the byte budget now STARTS at pOutputBudget (whatever the
        ; shared response budget has left after returnValue's share, computed above)
        ; rather than always resetting to the full ceiling — byRefValues is second in the
        ; shared-budget priority order.
        Set tByRefNodeBudget = ..#BYREFNODECEILING
        Set tByRefByteBudget = pOutputBudget
        If tByRef0, $Data(tA0)   Do ..AddByRefPosition(pByRefValues, 0, .tA0, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef1, $Data(tA1)   Do ..AddByRefPosition(pByRefValues, 1, .tA1, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef2, $Data(tA2)   Do ..AddByRefPosition(pByRefValues, 2, .tA2, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef3, $Data(tA3)   Do ..AddByRefPosition(pByRefValues, 3, .tA3, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef4, $Data(tA4)   Do ..AddByRefPosition(pByRefValues, 4, .tA4, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef5, $Data(tA5)   Do ..AddByRefPosition(pByRefValues, 5, .tA5, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef6, $Data(tA6)   Do ..AddByRefPosition(pByRefValues, 6, .tA6, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef7, $Data(tA7)   Do ..AddByRefPosition(pByRefValues, 7, .tA7, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef8, $Data(tA8)   Do ..AddByRefPosition(pByRefValues, 8, .tA8, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef9, $Data(tA9)   Do ..AddByRefPosition(pByRefValues, 9, .tA9, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef10, $Data(tA10) Do ..AddByRefPosition(pByRefValues, 10, .tA10, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef11, $Data(tA11) Do ..AddByRefPosition(pByRefValues, 11, .tA11, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef12, $Data(tA12) Do ..AddByRefPosition(pByRefValues, 12, .tA12, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef13, $Data(tA13) Do ..AddByRefPosition(pByRefValues, 13, .tA13, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef14, $Data(tA14) Do ..AddByRefPosition(pByRefValues, 14, .tA14, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef15, $Data(tA15) Do ..AddByRefPosition(pByRefValues, 15, .tA15, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef16, $Data(tA16) Do ..AddByRefPosition(pByRefValues, 16, .tA16, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef17, $Data(tA17) Do ..AddByRefPosition(pByRefValues, 17, .tA17, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef18, $Data(tA18) Do ..AddByRefPosition(pByRefValues, 18, .tA18, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)
        If tByRef19, $Data(tA19) Do ..AddByRefPosition(pByRefValues, 19, .tA19, .tByRefNodeBudget, .tByRefByteBudget, .pByRefTruncated)

        ; Story 34.7 AC 34.7.3: whatever remains of the shared budget after both
        ; returnValue and byRefValues have taken their share is what the command body may
        ; spend on `output` — third and last in the shared-budget priority order.
        Set pOutputBudget = tByRefByteBudget
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
