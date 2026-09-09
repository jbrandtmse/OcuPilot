/// <p>Shared utility methods used tree-wide: namespace switching, input validation,
/// error sanitization, output truncation and request-body decoding.</p>
/// <p>Harvested with call sites and behavior intact; only the package name changed.
/// This class carries no coupling to any vendor REST-introspection package — a
/// dependency on one is exactly what <code>scripts/check-objectscript.py</code>'s
/// forbidden-token rule exists to catch if a later harvest ever reintroduces it.</p>
/// <p><b>No consumer in this story</b> — like <class>OcuPilot.Test.Http</class>, this
/// class is delivered ready to call but has no call site and no dedicated test of its own
/// yet; every method here compiles and is harvested faithfully, but none of its logic
/// (the UTF-8 chunk-boundary carryover, the surrogate-pair-safe truncation, the
/// bracket-depth scan in <method>SanitizeError</method>) has actually run. The first
/// consumer story should add a test host alongside its first call site rather than
/// inheriting this gap silently.</p>
Class OcuPilot.Kernel.Utils Extends %RegisteredObject
{

/// <p>The documented response-payload ceiling used by <method>ApplyOutputCeiling</method>,
/// measured in raw characters via <code>$Length</code> <b>before</b> JSON escaping — not
/// raw UTF-8 bytes and not the serialized size of a JSON response body, which escaping
/// can inflate well past this figure for content heavy in quotes, backslashes, tabs or
/// control characters.</p>
Parameter OUTPUTCEILING As %Integer = 32768;

/// <p>The size, in raw bytes, of each chunk <method>DecodeUtf8Stream</method> reads from
/// a request-body stream before decoding it. Chosen well under the platform's practical
/// string ceiling while staying large enough that an ordinary request body decodes in a
/// single chunk.</p>
Parameter UTF8CHUNKSIZE As %Integer = 1000000;

/// <p>Save the current namespace and switch to <var>pNamespace</var>.</p>
/// <p>The original namespace is returned via <var>pOriginal</var> so callers can restore
/// it later with <method>RestoreNamespace</method>. Never use <code>New $NAMESPACE</code>
/// in a dispatch handler (AD-16) — this bounded save/restore pair is the one sanctioned
/// way to reach <code>%SYS</code> or another namespace.</p>
ClassMethod SwitchNamespace(pNamespace As %String, Output pOriginal As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set pOriginal = $NAMESPACE
        Set $NAMESPACE = pNamespace
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Restore <code>$NAMESPACE</code> to the previously saved value. Call this as the
/// first line of every <code>Catch</code> in a method that switched namespace (AD-16),
/// as well as on the normal exit path.</p>
ClassMethod RestoreNamespace(pOriginal As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = pOriginal
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Validate that <var>pValue</var> is not empty, naming <var>pName</var> in the error.</p>
ClassMethod ValidateRequired(pValue As %String, pName As %String) As %Status
{
    If pValue = "" {
        Quit $$$ERROR($$$GeneralError, "Required parameter '" _ pName _ "' is missing or empty")
    }
    Quit $$$OK
}

/// <p>Validate a string parameter: not empty, and no longer than <var>pMaxLen</var>
/// characters when <var>pMaxLen</var> is greater than zero.</p>
ClassMethod ValidateString(pValue As %String, pName As %String, pMaxLen As %Integer = 0) As %Status
{
    If pValue = "" {
        Quit $$$ERROR($$$GeneralError, "Parameter '" _ pName _ "' must be a non-empty string")
    }
    If (pMaxLen > 0) && ($Length(pValue) > pMaxLen) {
        Quit $$$ERROR($$$GeneralError, "Parameter '" _ pName _ "' exceeds maximum length of " _ pMaxLen)
    }
    Quit $$$OK
}

/// <p>Validate that <var>pValue</var> is a valid integer, optionally negative. Accepts a
/// leading <code>-</code> only — there is no accepted positive-sign (<code>+</code>)
/// form.</p>
ClassMethod ValidateInteger(pValue As %String, pName As %String) As %Status
{
    If pValue = "" {
        Quit $$$ERROR($$$GeneralError, "Parameter '" _ pName _ "' must be a valid integer")
    }
    If pValue '? 1.N && (pValue '? 1"-"1.N) {
        Quit $$$ERROR($$$GeneralError, "Parameter '" _ pName _ "' must be a valid integer")
    }
    Quit $$$OK
}

/// <p>Validate that <var>pValue</var> is a valid boolean (0, 1, true, false).</p>
ClassMethod ValidateBoolean(pValue As %String, pName As %String) As %Status
{
    Set tLower = $ZConvert(pValue, "L")
    If (tLower '= "0") && (tLower '= "1") && (tLower '= "true") && (tLower '= "false") {
        Quit $$$ERROR($$$GeneralError, "Parameter '" _ pName _ "' must be a boolean (0, 1, true, false)")
    }
    Quit $$$OK
}

/// <p>Strip internal IRIS detail — <code>$ZERROR</code> content, stack traces, global and
/// routine references — from an error status, returning a status safe to surface to an
/// external caller. A status that is already OK is returned unchanged.</p>
ClassMethod SanitizeError(pStatus As %Status) As %Status
{
    If $$$ISOK(pStatus) Quit pStatus
    Set tText = $System.Status.GetErrorText(pStatus)
    Set tSafe = $ZStrip(tText, "*C")
    Set tSafe = $Replace(tSafe, $Char(13), "")
    Set tSafe = $Replace(tSafe, $Char(10), " ")
    Set tOffset = 1
    For {
        Set tPos = $Find(tSafe, "^", tOffset)
        If tPos = 0 Quit
        Set tBefore = $Extract(tSafe, 1, tPos - 2)
        Set tAfter = $Extract(tSafe, tPos)
        If (tAfter ? 1A.AN) || (tAfter ? 1"%".AN) {
            Set tStart = tPos - 1
            While (tStart > 1) && ($Extract(tSafe, tStart - 1) ? 1AN) {
                Set tStart = tStart - 1
            }
            If (tStart > 1) && ($Extract(tSafe, tStart - 1) = "+") {
                Set tStart = tStart - 1
            }
            Set tEnd = tPos
            Set tLen = $Length(tSafe)
            While (tEnd <= tLen) && (($Extract(tSafe, tEnd) ? 1AN) || ($Extract(tSafe, tEnd) = ".") || ($Extract(tSafe, tEnd) = "%")) {
                Set tEnd = tEnd + 1
            }
            If (tEnd <= tLen) && ($Extract(tSafe, tEnd) = "(") {
                Set tDepth = 1
                Set tEnd = tEnd + 1
                While (tEnd <= tLen) && (tDepth > 0) {
                    If $Extract(tSafe, tEnd) = "(" Set tDepth = tDepth + 1
                    If $Extract(tSafe, tEnd) = ")" Set tDepth = tDepth - 1
                    Set tEnd = tEnd + 1
                }
            }
            Set tSafe = $Extract(tSafe, 1, tStart - 1) _ $Extract(tSafe, tEnd, *)
            Set tOffset = tStart
        } Else {
            Set tOffset = tPos
        }
    }
    If $ZStrip(tSafe, "<>W") = "" {
        Set tSafe = "An internal error occurred"
    }
    For tPrefix = "ERROR #" {
        If $Extract(tSafe, 1, $Length(tPrefix)) = tPrefix {
            Set tRest = $Extract(tSafe, $Length(tPrefix) + 1, *)
            Set tColon = $Find(tRest, ": ")
            If tColon > 0 {
                Set tCodeChunk = $Extract(tRest, 1, tColon - 3)
                If tCodeChunk ? 1.N {
                    Set tSafe = $Extract(tRest, tColon, *)
                    Quit
                }
            }
        }
    }
    Quit $$$ERROR($$$GeneralError, tSafe)
}

/// <p>Truncate <var>pOutput</var> to <var>pCeiling</var> characters (default
/// <parameter>OUTPUTCEILING</parameter>), appending a structured, machine-detectable
/// elision marker in place of the elided tail. Only sets <var>pTruncated</var> to true
/// when truncation happens here — an already-true value the caller passed in ByRef is
/// left untouched, so a caller ORs this in for free.</p>
/// <p>The result never exceeds <var>pCeiling</var> characters and is never longer than
/// <var>pOutput</var> itself. When the marker itself would not fit inside a very small
/// <var>pCeiling</var>, this falls back to a plain hard cut with no marker, so a small
/// value is never replaced by something larger. Every cut is passed through
/// <method>SurrogateSafeCutLength</method> so it never lands between the two halves of a
/// UTF-16 surrogate pair (see that method's own note).</p>
ClassMethod ApplyOutputCeiling(pOutput As %String, ByRef pTruncated As %Boolean, pCeiling As %Integer = -1) As %String
{
    Set tCeiling = pCeiling
    If tCeiling < 0 { Set tCeiling = ..#OUTPUTCEILING }
    Set tLen = $Length(pOutput)
    If tLen <= tCeiling {
        Quit pOutput
    }
    Set pTruncated = 1
    Set tMarker = $Char(10) _ "[OCUPILOT-TRUNCATED ceiling=" _ tCeiling _ "chars]" _ $Char(10)
    If $Length(tMarker) > tCeiling {
        Set tKeep = ..SurrogateSafeCutLength(pOutput, tCeiling)
        Quit $Extract(pOutput, 1, tKeep)
    }
    Set tKeep = tCeiling - $Length(tMarker)
    Set tKeep = ..SurrogateSafeCutLength(pOutput, tKeep)
    Quit $Extract(pOutput, 1, tKeep) _ tMarker
}

/// <p>Back a truncation cut length off by one UTF-16 code unit when the code unit at
/// <var>pLen</var> is a high-surrogate half (range 55296-56319). IRIS represents an
/// astral character as a UTF-16 surrogate pair, and <code>$Extract</code> counts each
/// half as one character — cutting immediately after the high half strands its low-half
/// partner on the elided side, which IRIS then emits on the wire as invalid UTF-8. A
/// no-op when the code unit at <var>pLen</var> is anything else, including when
/// <var>pLen</var> is 0; never backs off below 0.</p>
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

/// <p>Decode a raw (untranslated) request-body stream as UTF-8, returning a new
/// character stream ready for <method>%DynamicObject.%FromJSON</method>.</p>
/// <p><b>Why this exists.</b> <property>%request.Content</property> is a raw, untranslated
/// byte stream, and <property>%request.CharSet</property> is typically empty because a
/// JSON client's <code>Content-Type: application/json</code> header carries no charset
/// parameter — so no CSP-level charset negotiation applies, and handing the raw stream
/// straight to <method>%FromJSON</method> does not itself assume UTF-8.</p>
/// <p>Reads <parameter>UTF8CHUNKSIZE</parameter> raw bytes at a time rather than the whole
/// stream in one call — a single large read can silently return less than the stream's
/// full size with no exception of any kind. A naive per-chunk decode would also corrupt any
/// multi-byte UTF-8 sequence straddling a chunk boundary, so this holds back the last 0-3
/// bytes of a chunk when they are the unfinished start of a multi-byte sequence (see
/// <method>IncompleteUtf8TailLength</method>) and prepends them to the next chunk before
/// decoding. Each decoded chunk is passed through <method>SanitizeUnpairedSurrogates</method>
/// before being written, since a malformed input byte sequence can otherwise decode to a
/// raw, unpaired UTF-16 surrogate that re-emerges as invalid UTF-8 on a later response.</p>
ClassMethod DecodeUtf8Stream(pRawStream As %Stream.Object, pChunkSize As %Integer = -1) As %Stream.Object
{
    Set tChunkSize = pChunkSize
    If tChunkSize <= 0 { Set tChunkSize = ..#UTF8CHUNKSIZE }
    Set tOut = ##class(%Stream.TmpCharacter).%New()
    Set tCarry = ""
    Do pRawStream.Rewind()
    While 'pRawStream.AtEnd {
        Set tRawChunk = tCarry _ pRawStream.Read(tChunkSize)
        Set tTail = ..IncompleteUtf8TailLength(tRawChunk)
        If tTail > 0 {
            Set tCarry = $Extract(tRawChunk, *-tTail+1, *)
            Set tDecodeNow = $Extract(tRawChunk, 1, *-tTail)
        } Else {
            Set tCarry = ""
            Set tDecodeNow = tRawChunk
        }
        If tDecodeNow '= "" {
            Do ..WriteDecoded(tOut, tDecodeNow)
        }
    }
    ; Whatever remains in tCarry at end-of-stream is genuinely truncated or malformed
    ; at this point (every earlier boundary was proven complete) — decode it as-is
    ; rather than silently dropping it.
    If tCarry '= "" {
        Do ..WriteDecoded(tOut, tCarry)
    }
    Do tOut.Rewind()
    Quit tOut
}

/// <p>Decode one raw-byte chunk and append it to <var>pOut</var>, throwing if the stream
/// write fails — a discarded write-failure status would otherwise hand
/// <method>%FromJSON</method> a silently truncated document.</p>
ClassMethod WriteDecoded(pOut As %Stream.Object, pRawChunk As %String) As %Status
{
    Set tSC = pOut.Write(..SanitizeUnpairedSurrogates($ZConvert(pRawChunk, "I", "UTF8")))
    If $$$ISERR(tSC) {
        Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
    }
    Quit tSC
}

/// <p><code>$ZConvert(...,"I","UTF8")</code> is lenient enough to decode a malformed
/// byte sequence into a raw, unpaired UTF-16 surrogate code unit rather than rejecting
/// it, and an unpaired surrogate that reaches a JSON response is re-emitted on the wire
/// as genuinely invalid UTF-8. This replaces each unpaired surrogate half with
/// <code>?</code> — matching <code>$ZConvert</code>'s own observed substitution for
/// other invalid byte sequences. A genuine, correctly-paired surrogate (any valid astral
/// character) is left completely untouched.</p>
ClassMethod SanitizeUnpairedSurrogates(pStr As %String) As %String
{
    Set tLen = $Length(pStr)
    Set tOut = ""
    Set tRunStart = 1
    Set i = 1
    While i <= tLen {
        Set tCode = $Ascii(pStr, i)
        Set tUnpaired = 0
        If (tCode >= 55296) && (tCode <= 56319) {
            Set tNext = $Select(i < tLen: $Ascii(pStr, i + 1), 1: 0)
            If (tNext >= 56320) && (tNext <= 57343) {
                Set i = i + 2 ; a genuine pair — both code units stay in the pending clean run
            } Else {
                Set tUnpaired = 1
            }
        } ElseIf (tCode >= 56320) && (tCode <= 57343) {
            Set tUnpaired = 1
        } Else {
            Set i = i + 1
        }
        If tUnpaired {
            If i > tRunStart {
                Set tOut = tOut _ $Extract(pStr, tRunStart, i - 1)
            }
            Set tOut = tOut _ "?"
            Set i = i + 1
            Set tRunStart = i
        }
    }
    If tRunStart <= tLen {
        Set tOut = tOut _ $Extract(pStr, tRunStart, tLen)
    }
    Quit tOut
}

/// <p>How many trailing bytes of <var>pChunk</var> (0-3) are the unfinished start of a
/// multi-byte UTF-8 sequence. Checking only the last 3 bytes is sufficient — no UTF-8
/// sequence is longer than 4 bytes, so if all 3 are continuation bytes the only
/// well-formed reading is a complete 4-byte sequence whose lead byte is one position
/// further back, entirely inside the caller's "decode now" portion.</p>
ClassMethod IncompleteUtf8TailLength(pChunk As %String) As %Integer
{
    Set tLen = $Length(pChunk)
    If tLen = 0 Quit 0
    Set tB1 = $Ascii(pChunk, tLen)
    If tB1 >= 192 Quit 1
    If tB1 < 128 Quit 0
    If tLen < 2 Quit 0
    Set tB2 = $Ascii(pChunk, tLen - 1)
    If tB2 >= 224 Quit 2
    If tB2 < 128 Quit 0
    If tB2 >= 192 Quit 0
    If tLen < 3 Quit 0
    Set tB3 = $Ascii(pChunk, tLen - 2)
    If tB3 >= 240 Quit 3
    Quit 0
}

/// <p>Read the HTTP request body and parse it as JSON, returning a
/// <class>%DynamicObject</class> via <var>pBody</var>.</p>
/// <p>Tries <code>%request.GetMimeData("BODY")</code> first, falling back to
/// <property>%request.Content</property>; either stream is decoded through
/// <method>DecodeUtf8Stream</method> before being parsed, so the request body is
/// UTF-8-correct regardless of which branch supplies it. Distinguishes a server-side
/// read/decode fault from a genuine client JSON parse error in the returned status text,
/// so an operator is not sent to debug a payload that was actually fine.</p>
ClassMethod ReadRequestBody(Output pBody As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pBody = ""
    Set tStage = "decode"
    Try {
        Set tStream = %request.GetMimeData("BODY")
        If '$IsObject(tStream) {
            Try {
                Set tStream = %request.Content
            } Catch {
                Set tStream = ""
            }
        }
        If '$IsObject($Get(tStream)) Quit
        Do tStream.Rewind()
        If 'tStream.Size Quit
        Set tUtf8Stream = ..DecodeUtf8Stream(tStream)
        Set tStage = "parse"
        Set pBody = ##class(%DynamicObject).%FromJSON(tUtf8Stream)
    } Catch ex {
        If tStage = "parse" {
            Set tSC = $$$ERROR($$$GeneralError, "Invalid JSON in request body: " _ ex.DisplayString())
        } Else {
            Set tSC = $$$ERROR($$$GeneralError, "Failed to read and UTF-8-decode the request body before parsing it; this is a server-side read/decode fault, not malformed JSON from the client: " _ ex.DisplayString())
        }
    }
    Quit tSC
}

}
