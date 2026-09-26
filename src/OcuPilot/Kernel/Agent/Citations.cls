/// <p>The citations a finished turn's reply carries (Story 11.4, AD-11, AD-13, AD-37): each is a row
/// a read tool returned in that turn, named by a backticked span of the final reply. The model's
/// text only selects among the rows the instance returned; it never creates a citation.</p>
/// <p>A citation is <code>{type, scope, id, route, label}</code>: the AD-13 triple of the row, the
/// route of the screen that lists it, and the span text as the reply spells it. It is stored with
/// the turn as data and never replayed to the model (AD-24).</p>
Class OcuPilot.Kernel.Agent.Citations Extends %RegisteredObject
{

/// <p>The most citations one reply carries; later matches are ignored.</p>
Parameter MAXCITATIONS = 20;

/// <p>The longest id a row may carry and still be cited.</p>
Parameter MAXIDLENGTH = 256;

/// <p>Append to <var>pInto</var> one <code>{type, scope, id, route}</code> candidate for each row of
/// the bounded read result <var>pContent</var> (the <code>tool_result</code> content the model was
/// handed) that the screen <var>pDescriptor</var> can select.</p>
/// <p>Nothing is appended unless <method>OcuPilot.Screen.Tool.Registry.CitationSource</method>
/// names the descriptor's citable id field. An id that is empty, longer than
/// <parameter>MAXIDLENGTH</parameter> or ends in U+2026 (cut by the field bound) is skipped. Never
/// throws.</p>
/// <p><b>Caller contract:</b> the caller has dispatched a read-kind, instance-fulfilled,
/// descriptor-backed read tool for <var>pDescriptor</var>, and the call did not answer an error.</p>
ClassMethod Candidates(pDescriptor As %String, pContent As %String, pInto As %DynamicArray)
{
    Try {
        If '$IsObject(pInto) || (pDescriptor = "") || (pContent = "") Quit
        If '##class(OcuPilot.Screen.Tool.Registry).CitationSource(pDescriptor, .tType, .tDeclaredScope, .tRoute, .tField) Quit
        Set tScope = ##class(OcuPilot.Kernel.EntityRef).ScopeFor(tDeclaredScope)
        If tScope = "" Quit
        Set tPayload = ##class(%DynamicAbstractObject).%FromJSON(pContent)
        If '$IsObject(tPayload) || 'tPayload.%IsA("%Library.DynamicObject") Quit
        Set tRows = tPayload.%Get("rows")
        If '$IsObject(tRows) || 'tRows.%IsA("%Library.DynamicArray") Quit
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") Continue
            Set tKind = tRow.%GetTypeOf(tField)
            If (tKind '= "string") && (tKind '= "number") Continue
            Set tId = tRow.%Get(tField) _ ""
            If (tId = "") || ($Length(tId) > ..#MAXIDLENGTH) || ($Extract(tId, *) = $Char(8230)) Continue
            Set tCandidate = {}
            Do tCandidate.%Set("type", tType, "string")
            Do tCandidate.%Set("scope", tScope, "string")
            Do tCandidate.%Set("id", tId, "string")
            Do tCandidate.%Set("route", tRoute, "string")
            Do pInto.%Push(tCandidate)
        }
    } Catch ex {
    }
}

/// <p>The citations <var>pReply</var> carries against <var>pCandidates</var>, in order of first
/// mention: each single-line backticked span outside a fenced block that equals a candidate's id,
/// exactly or after <method>OcuPilot.Kernel.EntityRef.NormalizedId</method> of both, becomes
/// <code>{type, scope, id, route, label}</code> with the candidate's triple and route and the span
/// as <code>label</code>. One citation per distinct <code>(type, scope, id)</code>, at most
/// <parameter>MAXCITATIONS</parameter>. A span that matches nothing adds nothing. Never throws.</p>
ClassMethod Cite(pReply As %String, pCandidates As %DynamicArray) As %DynamicArray
{
    Set tCited = []
    Try {
        If (pReply = "") || '$IsObject(pCandidates) || (pCandidates.%Size() = 0) Quit
        ; Each candidate indexed once by its normalized id, per type; the first one wins.
        Kill tByNorm
        For tI = 0:1:pCandidates.%Size() - 1 {
            Set tCandidate = pCandidates.%Get(tI)
            Set tType = tCandidate.%Get("type")
            Set tNorm = ##class(OcuPilot.Kernel.EntityRef).NormalizedId(tType, tCandidate.%Get("id"))
            If tNorm = "" Continue
            If '$Data(tByNorm(tType, tNorm)) Set tByNorm(tType, tNorm) = tI
        }
        Kill tSeen
        Set tFence = 0
        For tLineNo = 1:1:$Length(pReply, $Char(10)) {
            Set tLine = $Piece(pReply, $Char(10), tLineNo)
            If $Match(tLine, "^ {0,3}(```|~~~).*") {
                Set tFence = 'tFence
                Continue
            }
            If tFence Continue
            Set tPos = 1
            While tPos <= $Length(tLine) {
                If $Extract(tLine, tPos) '= "`" {
                    Set tPos = tPos + 1
                    Continue
                }
                Set tRun = ..RunLength(tLine, tPos)
                Set tClose = ..ClosingRun(tLine, tPos + tRun, tRun)
                If tClose = 0 {
                    Set tPos = tPos + tRun
                    Continue
                }
                Set tSpan = ..SpanText($Extract(tLine, tPos + tRun, tClose - 1))
                Set tPos = tClose + tRun
                If tSpan = "" Continue
                Set tFound = ..Match(tSpan, .tByNorm)
                If tFound = "" Continue
                Set tCandidate = pCandidates.%Get(tFound)
                Set tKey = tCandidate.%Get("type") _ $Char(1) _ tCandidate.%Get("scope") _ $Char(1) _ tCandidate.%Get("id")
                If $Data(tSeen(tKey)) Continue
                Set tSeen(tKey) = ""
                Set tCitation = {}
                Do tCitation.%Set("type", tCandidate.%Get("type"), "string")
                Do tCitation.%Set("scope", tCandidate.%Get("scope"), "string")
                Do tCitation.%Set("id", tCandidate.%Get("id"), "string")
                Do tCitation.%Set("route", tCandidate.%Get("route"), "string")
                Do tCitation.%Set("label", tSpan, "string")
                Do tCited.%Push(tCitation)
                If tCited.%Size() >= ..#MAXCITATIONS Quit
            }
            If tCited.%Size() >= ..#MAXCITATIONS Quit
        }
    } Catch ex {
        Set tCited = []
    }
    Quit tCited
}

/// <p>The index of the first candidate <var>pSpan</var> names, across every entity type in
/// <var>pByNorm</var>, or <code>""</code>.</p>
ClassMethod Match(pSpan As %String, ByRef pByNorm) As %String [ Private ]
{
    Set tBest = ""
    Set tType = ""
    For {
        Set tType = $Order(pByNorm(tType))
        If tType = "" Quit
        Set tNorm = ##class(OcuPilot.Kernel.EntityRef).NormalizedId(tType, pSpan)
        If (tNorm = "") || '$Data(pByNorm(tType, tNorm), tIndex) Continue
        If (tBest = "") || (tIndex < tBest) Set tBest = tIndex
    }
    Quit tBest
}

/// <p>How many backticks run from position <var>pStart</var> of <var>pLine</var>.</p>
ClassMethod RunLength(pLine As %String, pStart As %Integer) As %Integer [ Private ]
{
    Set tEnd = pStart
    While $Extract(pLine, tEnd) = "`" {
        Set tEnd = tEnd + 1
    }
    Quit tEnd - pStart
}

/// <p>The position of the next run of exactly <var>pRun</var> backticks at or after
/// <var>pFrom</var>, or 0.</p>
ClassMethod ClosingRun(pLine As %String, pFrom As %Integer, pRun As %Integer) As %Integer [ Private ]
{
    Set tPos = pFrom
    While tPos <= $Length(pLine) {
        If $Extract(pLine, tPos) '= "`" {
            Set tPos = tPos + 1
            Continue
        }
        Set tLength = ..RunLength(pLine, tPos)
        If tLength = pRun Quit
        Set tPos = tPos + tLength
    }
    Quit $Select(tPos <= $Length(pLine): tPos, 1: 0)
}

/// <p>A code span's text as Markdown reads it: one leading and one trailing space are dropped when
/// both are present and the span is not all spaces.</p>
ClassMethod SpanText(pRaw As %String) As %String [ Private ]
{
    If ($Length(pRaw) >= 2) && ($Extract(pRaw) = " ") && ($Extract(pRaw, *) = " ") && ($Translate(pRaw, " ") '= "") {
        Quit $Extract(pRaw, 2, *-1)
    }
    Quit pRaw
}

}
