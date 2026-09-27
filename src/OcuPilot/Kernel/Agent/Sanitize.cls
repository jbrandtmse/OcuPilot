/// <p>The model-bound sanitizer (AD-60). <method>OcuPilot.Kernel.Agent.Loop</method> passes every
/// block array that carries a <code>tool_result</code> through <method>Results</method> immediately
/// before the array is serialized into the turn's history, so every producer -- instance reads,
/// refusals, navigation settles, budget refusals and screen context -- reaches the model through
/// here and nowhere else.</p>
/// <p>Each string is stripped of control and invisible characters, redacted of five secret shapes,
/// and has its own delimiter's name neutralized; the content is then wrapped in
/// <parameter>OPENTAG</parameter> ... <parameter>CLOSETAG</parameter>. A content that parses as a
/// JSON object or array is cleaned value by value and member name by member name and re-serialized;
/// any other content is cleaned as one string.</p>
/// <p><b>AD-24's bound is the one marked cut.</b> A cleaned string is never longer than it was, so
/// every mark the bound set survives. Only a body still above AD-24's total after cleaning is cut
/// here, as a backstop, ending in U+2026 and opened with <parameter>CUTOPENTAG</parameter>.</p>
/// <p><b>It fails closed</b>: a fault on a block replaces its content with the wrapped
/// <code>{"code":"TOOL.UNAVAILABLE"}</code>, marks it an error and logs the fault. It is additional
/// to AD-11's five rules; nothing reads its output as the defense.</p>
/// <p>Only the model's copy passes here: the step card, citations and screens keep the bounded
/// instance data. No storage.</p>
Class OcuPilot.Kernel.Agent.Sanitize Extends %RegisteredObject
{

/// <p>The delimiter's name. Every case-insensitive occurrence inside the data has its hyphen
/// replaced by <code>_</code>.</p>
Parameter TAGNAME = "ocupilot-data";

/// <p>The line that opens every wrapped content.</p>
Parameter OPENTAG = "<ocupilot-data>";

/// <p>The line that closes every wrapped content.</p>
Parameter CLOSETAG = "</ocupilot-data>";

/// <p>The opening line of a body the backstop cut.</p>
Parameter CUTOPENTAG = "<ocupilot-data truncated=""true"">";

/// <p>Sanitize, in place, the <code>content</code> of every <code>tool_result</code> block in
/// <var>pBlocks</var>, skipping every other block. A block whose sanitizing faulted also gains
/// <code>is_error</code> true.</p>
ClassMethod Results(pBlocks As %DynamicArray)
{
    If '$IsObject(pBlocks) || 'pBlocks.%IsA("%Library.DynamicArray") Quit
    For tI = 0:1:pBlocks.%Size() - 1 {
        Set tBlock = pBlocks.%Get(tI)
        If '$IsObject(tBlock) || 'tBlock.%IsA("%Library.DynamicObject") Continue
        If tBlock.%Get("type") '= "tool_result" Continue
        Set tClean = ..Content(tBlock.%Get("content"), .tFaulted)
        Do tBlock.%Set("content", tClean, "string")
        If tFaulted Do tBlock.%Set("is_error", 1, "boolean")
    }
}

/// <p>The wrapped, sanitized form of <var>pContent</var> (a string, or a dynamic object or array,
/// which is serialized first). <var>pFaulted</var> is 1 when sanitizing faulted, in which case the
/// answer is the wrapped <code>{"code":"TOOL.UNAVAILABLE"}</code> and the fault is logged.</p>
ClassMethod Content(pContent, Output pFaulted As %Boolean) As %String
{
    Set pFaulted = 0
    Set tWrapped = ""
    Try {
        Set tText = $Select($IsObject(pContent): pContent.%ToJSON(), 1: pContent)
        Kill tMatchers
        Do ..Matchers(.tMatchers)
        Set tParsed = ""
        If $Case($Extract($ZStrip(tText, "<W")), "{": 1, "[": 1, : 0) {
            Try {
                Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(tText)
            } Catch {
                Set tParsed = ""
            }
        }
        If $IsObject(tParsed) {
            Set tBody = ..CleanTree(tParsed, .tMatchers).%ToJSON()
        } Else {
            Set tBody = ..Clean(tText, .tMatchers)
        }
        Set tCut = 0
        Set tMax = ..MaxLength()
        If $Length(tBody) > tMax {
            Set tKeep = tMax - 1
            ; Never leave half of a surrogate pair behind the mark.
            Set tLast = $Ascii(tBody, tKeep)
            If (tLast >= 55296) && (tLast <= 56319) Set tKeep = tKeep - 1
            Set tBody = $Extract(tBody, 1, tKeep) _ $Char(8230)
            Set tCut = 1
        }
        Set tWrapped = ..Wrap(tBody, tCut)
    } Catch ex {
        Set pFaulted = 1
        Do ..LogFault(ex.AsStatus())
        Set tError = {}
        Do tError.%Set("code", ##class(OcuPilot.Api.Error).#TOOLUNAVAILABLE, "string")
        Set tWrapped = ..Wrap(tError.%ToJSON(), 0)
    }
    Quit tWrapped
}

/// <p>Log a sanitizing fault under <code>TOOL.UNAVAILABLE</code>. A seam a test overrides to observe
/// the call; production never overrides it.</p>
ClassMethod LogFault(pStatus As %Status)
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw("turn", "a tool result could not be sanitized and was replaced", pStatus, ##class(OcuPilot.Api.Error).#TOOLUNAVAILABLE)
}

/// <p><var>pBody</var> between the two delimiter lines; <var>pCut</var> opens it with
/// <parameter>CUTOPENTAG</parameter>.</p>
ClassMethod Wrap(pBody As %String, pCut As %Boolean = 0) As %String
{
    Quit $Select(pCut: ..#CUTOPENTAG, 1: ..#OPENTAG) _ $Char(10) _ pBody _ $Char(10) _ ..#CLOSETAG
}

/// <p>The total a cleaned body may reach before the backstop cuts it: AD-24's total bound.</p>
ClassMethod MaxLength() As %Integer [ CodeMode = expression ]
{
+$Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLRESULTMAXLENGTH")
}

/// <p>Strip, redact and neutralize <var>pText</var>, in that order. The answer is never longer than
/// <var>pText</var>, and cleaning it again changes nothing. <var>pMatchers</var> is what
/// <method>Matchers</method> builds; it is built here when the caller passes none.</p>
ClassMethod Clean(pText As %String, ByRef pMatchers) As %String
{
    If '$Data(pMatchers) Do ..Matchers(.pMatchers)
    Quit ..Neutralize(..Redact(..Strip(pText, .pMatchers), .pMatchers))
}

/// <p>The strip set and the compiled secret shapes, built once per <method>Content</method>
/// call.</p>
ClassMethod Matchers(Output pMatchers)
{
    Kill pMatchers
    Set tStrip = ""
    For tCode = 0:1:8, 11, 12, 14:1:31, 127:1:159, 8203:1:8207, 8234:1:8238, 8288:1:8292, 8294:1:8297, 65279 {
        Set tStrip = tStrip _ $Char(tCode)
    }
    Set pMatchers("strip") = tStrip
    Set pMatchers("pem") = ##class(%Regex.Matcher).%New("-----BEGIN (?:(?:RSA|EC|ENCRYPTED|OPENSSH) )?PRIVATE KEY-----(?:[\s\S]*?(-----END [A-Z ]*PRIVATE KEY-----)|[\s\S]*)")
    Set pMatchers("shape", 1) = ##class(%Regex.Matcher).%New("eyJ[A-Za-z0-9_-]{7,}\.eyJ[A-Za-z0-9_-]{7,}\.[A-Za-z0-9_-]*")
    Set pMatchers("shape", 2) = ##class(%Regex.Matcher).%New("(?i:bearer)\s+[A-Za-z0-9._~+/-]{20,}=*")
    Set pMatchers("shape", 3) = ##class(%Regex.Matcher).%New("(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}")
    Set pMatchers("shape", 4) = ##class(%Regex.Matcher).%New("AIza[A-Za-z0-9_-]{35}")
}

/// <p><var>pText</var> without C0 controls other than TAB, LF and CR, DEL, C1, U+200B-U+200F,
/// U+202A-U+202E, U+2060-U+2064, U+2066-U+2069, U+FEFF, and the tag characters U+E0000-U+E007F
/// (the surrogate pairs whose high half is 56128 and whose low half is 56320-56447).</p>
ClassMethod Strip(pText As %String, ByRef pMatchers) As %String
{
    Set tText = $Translate(pText, pMatchers("strip"))
    Set tHigh = $Char(56128)
    If tText '[ tHigh Quit tText
    Set tOut = ""
    Set tFrom = 1
    For {
        Set tAfter = $Find(tText, tHigh, tFrom)
        If tAfter = 0 {
            Set tOut = tOut _ $Extract(tText, tFrom, *)
            Quit
        }
        Set tLow = $Ascii(tText, tAfter)
        If (tLow >= 56320) && (tLow <= 56447) {
            Set tOut = tOut _ $Extract(tText, tFrom, tAfter - 2)
            Set tFrom = tAfter + 1
        } Else {
            Set tOut = tOut _ $Extract(tText, tFrom, tAfter - 1)
            Set tFrom = tAfter
        }
    }
    Quit tOut
}

/// <p><var>pText</var> with every match of the five secret shapes replaced by
/// <parameter>OcuPilot.Kernel.Audit.Log.REDACTED</parameter>, repeated until nothing more matches.
/// Every shape matches at least 20 characters and the mark is 10, so each pass that changes the
/// text shortens it.</p>
ClassMethod Redact(pText As %String, ByRef pMatchers) As %String
{
    ; No shape matches fewer than 20 characters.
    If $Length(pText) < 20 Quit pText
    Set tMark = ##class(OcuPilot.Kernel.Audit.Log).#REDACTED
    Set tText = pText
    For {
        Set tBefore = tText
        Set tText = ..RedactPem(tText, tMark, pMatchers("pem"))
        For tI = 1:1:4 {
            Set tMatcher = pMatchers("shape", tI)
            Set tMatcher.Text = tText
            Set tText = tMatcher.ReplaceAll(tMark)
        }
        If tText = tBefore Quit
    }
    Quit tText
}

/// <p><var>pText</var> with each PEM private-key block replaced by <var>pMark</var>. A block with no
/// END runs to the end of the text; when that text ends in U+2026, the mark keeps it.</p>
ClassMethod RedactPem(pText As %String, pMark As %String, pMatcher As %Regex.Matcher) As %String
{
    Set tText = pText
    Set tFrom = 1
    For {
        Set pMatcher.Text = tText
        If 'pMatcher.Locate(tFrom) Quit
        Set tStart = pMatcher.Start
        Set tEnd = pMatcher.End
        Set tMarked = pMark
        If (pMatcher.Start(1) < 0) && ($Extract(tText, *) = $Char(8230)) Set tMarked = tMarked _ $Char(8230)
        Set tText = $Extract(tText, 1, tStart - 1) _ tMarked _ $Extract(tText, tEnd, *)
        Set tFrom = tStart + $Length(tMarked)
    }
    Quit tText
}

/// <p><var>pText</var> with the hyphen of every ASCII case-insensitive occurrence of
/// <parameter>TAGNAME</parameter> replaced by <code>_</code>.</p>
ClassMethod Neutralize(pText As %String) As %String
{
    Set tUpper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    Set tLower = "abcdefghijklmnopqrstuvwxyz"
    Set tFolded = $Translate(pText, tUpper, tLower)
    Set tName = ..#TAGNAME
    If tFolded '[ tName Quit pText
    Set tText = pText
    Set tHyphen = $Find(tName, "-") - 1
    Set tFrom = 1
    For {
        Set tAfter = $Find(tFolded, tName, tFrom)
        If tAfter = 0 Quit
        Set $Extract(tText, tAfter - $Length(tName) + tHyphen - 1) = "_"
        Set tFrom = tAfter
    }
    Quit tText
}

/// <p><var>pNode</var>, a dynamic object or array, with every string value and member name cleaned.
/// Values are replaced in place; an object whose member names change is rebuilt in the same order.
/// The answer is the node to use, which is <var>pNode</var> unless it was rebuilt.</p>
ClassMethod CleanTree(pNode As %DynamicAbstractObject, ByRef pMatchers) As %DynamicAbstractObject
{
    If pNode.%IsA("%Library.DynamicArray") {
        For tI = 0:1:pNode.%Size() - 1 {
            Set tType = pNode.%GetTypeOf(tI)
            If tType = "string" {
                Set tValue = pNode.%Get(tI)
                Set tClean = ..Clean(tValue, .pMatchers)
                If tClean '= tValue Do pNode.%Set(tI, tClean, "string")
            } ElseIf (tType = "object") || (tType = "array") {
                Set tChild = pNode.%Get(tI)
                Set tCleanChild = ..CleanTree(tChild, .pMatchers)
                If tCleanChild '= tChild Do pNode.%Set(tI, tCleanChild)
            }
        }
        Quit pNode
    }
    ; An object: collect the members before changing any of them.
    Kill tKeys
    Set tIterator = pNode.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys($Increment(tKeys)) = tKey
    }
    Set tRenamed = 0
    For tI = 1:1:$Get(tKeys) {
        Set tKey = tKeys(tI)
        Set tType = pNode.%GetTypeOf(tKey)
        If tType = "string" {
            Set tValue = pNode.%Get(tKey)
            Set tClean = ..Clean(tValue, .pMatchers)
            If tClean '= tValue Do pNode.%Set(tKey, tClean, "string")
        } ElseIf (tType = "object") || (tType = "array") {
            Set tChild = pNode.%Get(tKey)
            Set tCleanChild = ..CleanTree(tChild, .pMatchers)
            If tCleanChild '= tChild Do pNode.%Set(tKey, tCleanChild)
        }
        Set tKeys(tI, "clean") = ..Clean(tKey, .pMatchers)
        If tKeys(tI, "clean") '= tKey Set tRenamed = 1
    }
    If 'tRenamed Quit pNode
    Set tOut = {}
    For tI = 1:1:$Get(tKeys) {
        Set tKey = tKeys(tI)
        Set tType = pNode.%GetTypeOf(tKey)
        If (tType = "object") || (tType = "array") {
            Do tOut.%Set(tKeys(tI, "clean"), pNode.%Get(tKey))
        } ElseIf tType = "null" {
            Do tOut.%Set(tKeys(tI, "clean"), "", "null")
        } ElseIf $Case(tType, "string": 1, "number": 1, "boolean": 1, : 0) {
            Do tOut.%Set(tKeys(tI, "clean"), pNode.%Get(tKey), tType)
        } Else {
            Do tOut.%Set(tKeys(tI, "clean"), pNode.%Get(tKey))
        }
    }
    Quit tOut
}

}
