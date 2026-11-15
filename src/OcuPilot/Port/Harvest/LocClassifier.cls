/// <p>The line counter's classifier: a pure function of one document's lines and its facts, with no
/// access to the instance. Every line lands in exactly one of five buckets: blank, source code, source
/// comment, test code and test comment. Comments are lines opening with <code>//</code> (which covers
/// <code>///</code>), <code>;</code>, <code>#;</code> or <code>##;</code>, the lines of a
/// <code>/* ... */</code> block, and, inside an embedded-Python method, lines opening with
/// <code>#</code>. Preprocessor directives, XData and storage lines are code. String literals are
/// masked before any marker is looked for. A document that is a test class is test code and comment
/// throughout; otherwise only the methods named <code>Test*</code> or a unit-test lifecycle method are,
/// scoped by brace depth. A harvested handler body's library, inherited by
/// <class>OcuPilot.Port.Harvest.Loc</class>.</p>
Class OcuPilot.Port.Harvest.LocClassifier Extends OcuPilot.Kernel.Utils [ Abstract ]
{

/// <p>Classify one document's lines into the five buckets.</p>
/// <p><var>pLines</var> is the line array <method>OcuPilot.Kernel.Utils.DocumentLines</method> answers:
/// the count at <code>pLines(0)</code> and the lines at <code>pLines(1..n)</code>. <var>pIsTest</var>
/// makes the whole document test-scoped. <var>pPyMethods</var> names the embedded-Python methods.
/// <var>pCounts</var> answers <code>blank</code>, <code>sourceCode</code>, <code>sourceComment</code>,
/// <code>testCode</code>, <code>testComment</code> and <code>total</code>.</p>
ClassMethod ClassifyDoc(ByRef pLines, pIsTest As %Boolean = 0, ByRef pPyMethods, Output pCounts) As %Status
{
    Set tSC = $$$OK
    Try {
        Kill pCounts
        Set pCounts("blank") = 0
        Set pCounts("sourceCode") = 0
        Set pCounts("sourceComment") = 0
        Set pCounts("testCode") = 0
        Set pCounts("testComment") = 0
        Set pCounts("total") = 0

        ; per-document state (mirrors the reference AWK FNR==1 reset)
        Set tInBlock = 0    ; inside a /* ... */ block comment spanning lines
        Set tMActive = 0    ; inside a method-scoped state (test method or python)
        Set tMTest = 0      ; ...that method is a Test*/lifecycle method
        Set tMPy = 0        ; ...that method is an embedded-Python method
        Set tMStarted = 0   ; method opening brace has been seen
        Set tMDepth = 0     ; current brace depth within the tracked method

        Set tTab = $Char(9)
        Set tTotal = +$Get(pLines(0))
        For tI = 1:1:tTotal {
            Set pCounts("total") = pCounts("total") + 1
            Set tLine = $Get(pLines(tI))
            ; tolerate CRLF line endings (strip one trailing CR)
            If $Extract(tLine, *) = $Char(13) Set tLine = $Extract(tLine, 1, *-1)

            ; -- 1. Blank line: empty or whitespace-only ------------------------
            If $Translate(tLine, " "_tTab) = "" {
                Set pCounts("blank") = pCounts("blank") + 1
                Continue
            }

            ; -- 2. Continuation of a multi-line /* ... */ block comment --------
            If tInBlock {
                Set tP = $Find(tLine, "*/")
                If tP = 0 {
                    ; still inside the block
                    Do ..AddComment(.pCounts, pIsTest || tMTest)
                    Continue
                }
                Set tInBlock = 0
                Set tLine = $Extract(tLine, tP, *)
                If $Translate(tLine, " "_tTab) = "" {
                    Do ..AddComment(.pCounts, pIsTest || tMTest)
                    Continue
                }
                ; non-blank remainder after */ — fall through and classify it as a
                ; fresh line (it may be code, another comment, or open a new block)
            }

            ; -- 3. Neutralize string literals ----------------------------------
            Set tS = ..MaskStrings(tLine)

            ; -- 4. Leading single-line comment check ---------------------------
            ; // (covers ///), ; (legacy MUMPS), #; and ##; (preprocessor comments
            ; — but NOT #Define/#Dim/...), # only inside a python method body
            Set tT = ..StripLeading(tS)
            If ($Extract(tT, 1, 2) = "//") || ($Extract(tT, 1) = ";") || ($Extract(tT, 1, 2) = "#;") || ($Extract(tT, 1, 3) = "##;") || (tMPy && ($Extract(tT, 1) = "#")) {
                Do ..AddComment(.pCounts, pIsTest || tMTest)
                Continue
            }

            ; -- 5. Method-scoped state detection (only outside an active method)
            ; The signature line itself is classified under the NEW state, so a
            ; "Method TestFoo()" line counts as test code.
            If 'tMActive {
                Set tName = ..MethodSignatureName(tS, .tAfterName)
                If tName '= "" {
                    Set tIsTm = 0
                    If 'pIsTest && ..IsTestMethodName(tName) {
                        ; the name must be followed by optional spaces/tabs then "("
                        If $Extract(..StripLeading(tAfterName), 1) = "(" Set tIsTm = 1
                    }
                    ; decision D3: python resolved via the dictionary-built map, not
                    ; a signature regex — the signature line still triggers scope entry
                    Set tIsPm = ($Get(pPyMethods(tName)) = 1)
                    If tIsTm || tIsPm {
                        Set tMActive = 1
                        Set tMTest = tIsTm
                        Set tMPy = tIsPm
                        Set tMStarted = 0
                        Set tMDepth = 0
                    }
                }
            }

            ; -- 6. Strip inline comments, scanning left-to-right ---------------
            ; A // encountered first comments out any /* after it (and vice versa:
            ; a /* ... */ pair may hide a //), so the scan must respect order.
            Set tEntering = 0
            While 1 {
                Set tPs = $Find(tS, "//")
                Set tPb = $Find(tS, "/*")
                If (tPb > 0) && ((tPs = 0) || (tPb < tPs)) {
                    Set tRest = $Extract(tS, tPb, *)
                    Set tQ = $Find(tRest, "*/")
                    If tQ > 0 {
                        ; complete inline /* ... */ — excise and keep scanning
                        Set tS = $Extract(tS, 1, tPb - 3)_" "_$Extract(tRest, tQ, *)
                        Continue
                    }
                    ; unterminated /* — block comment begins on this line
                    Set tS = $Extract(tS, 1, tPb - 3)
                    Set tEntering = 1
                    Quit
                } ElseIf tPs > 0 {
                    ; trailing // comment — everything after it is dead
                    Set tS = $Extract(tS, 1, tPs - 3)
                    Quit
                } Else {
                    Quit
                }
            }
            Set tInBlock = tEntering

            ; -- 7. Final classification ----------------------------------------
            If $Translate(tS, " "_tTab) = "" {
                ; nothing but comment text remained (e.g. a line that is only
                ; "/* opening" or "/* a */ // b") — comment line
                Do ..AddComment(.pCounts, pIsTest || tMTest)
            } Else {
                Do ..AddCode(.pCounts, pIsTest || tMTest)
            }

            ; -- 8. Update method-scope brace depth (comments/strings already gone)
            If tMActive {
                Set tOpen = $Length(tS) - $Length($Translate(tS, "{"))
                If tOpen > 0 {
                    Set tMDepth = tMDepth + tOpen
                    Set tMStarted = 1
                }
                Set tClose = $Length(tS) - $Length($Translate(tS, "}"))
                Set tMDepth = tMDepth - tClose
                ; Method ends when we have seen the opening brace and depth returns
                ; to 0. The closing-brace line itself was already classified (as
                ; test/python), which is the desired behavior: the brace belongs to
                ; the method.
                If tMStarted && (tMDepth <= 0) {
                    Set tMActive = 0
                    Set tMTest = 0
                    Set tMPy = 0
                }
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Count one code line toward the test or the source bucket.</p>
ClassMethod AddCode(ByRef pCounts, pIsTestScope As %Boolean) [ Internal ]
{
    Set tKey = $Select(pIsTestScope: "testCode", 1: "sourceCode")
    Set pCounts(tKey) = pCounts(tKey) + 1
}

/// <p>Count one comment line toward the test or the source bucket.</p>
ClassMethod AddComment(ByRef pCounts, pIsTestScope As %Boolean) [ Internal ]
{
    Set tKey = $Select(pIsTestScope: "testComment", 1: "sourceComment")
    Set pCounts(tKey) = pCounts(tKey) + 1
}

/// <p>Replace every complete string literal in <var>pLine</var>, <code>""</code> standing for a quote
/// inside one, with an empty literal, so a comment marker or a brace inside a literal never matches. A
/// literal whose greedy scan runs off the line closes at the last quote that gives a valid parse; a
/// literal with no valid close is left as it is.</p>
ClassMethod MaskStrings(pLine As %String) As %String
{
    Set tOut = ""
    Set tLen = $Length(pLine)
    Set tI = 1
    While tI <= tLen {
        Set tCh = $Extract(pLine, tI)
        If tCh '= """" {
            Set tOut = tOut_tCh
            Set tI = tI + 1
            Continue
        }
        ; opening quote — find the literal's end, honoring "" escapes; remember
        ; the last quote where a "" pair could instead CLOSE the literal
        Set tJ = tI + 1
        Set tClosed = 0
        Set tLastPairClose = 0
        While tJ <= tLen {
            If $Extract(pLine, tJ) = """" {
                If $Extract(pLine, tJ + 1) = """" {
                    Set tLastPairClose = tJ
                    Set tJ = tJ + 2
                } Else {
                    Set tClosed = 1
                    Quit
                }
            } Else {
                Set tJ = tJ + 1
            }
        }
        If 'tClosed && (tLastPairClose > 0) {
            ; greedy scan ran off the line — backtrack: the regex's longest
            ; valid match closes at the last pair-start quote
            Set tClosed = 1
            Set tJ = tLastPairClose
        }
        If tClosed {
            Set tOut = tOut_""""""
            Set tI = tJ + 1
        } Else {
            ; no valid close anywhere — leave the remainder untouched (regex
            ; no-match parity)
            Set tOut = tOut_$Extract(pLine, tI, *)
            Set tI = tLen + 1
        }
    }
    Quit tOut
}

/// <p><var>pS</var> without its leading spaces and tabs.</p>
ClassMethod StripLeading(pS As %String) As %String
{
    Set tI = 1
    Set tTab = $Char(9)
    While ($Extract(pS, tI) = " ") || ($Extract(pS, tI) = tTab) {
        Set tI = tI + 1
    }
    Quit $Extract(pS, tI, *)
}

/// <p>The method name when the masked line <var>pS</var> opens a <code>Method</code> or
/// <code>ClassMethod</code> signature, <code>""</code> otherwise. <var>pAfterName</var> is the text that
/// follows the name.</p>
ClassMethod MethodSignatureName(pS As %String, Output pAfterName As %String) As %String
{
    Set pAfterName = ""
    Set tT = ..StripLeading(pS)
    Set tTab = $Char(9)
    Set tRest = ""
    If ($Extract(tT, 1, 11) = "ClassMethod") && (($Extract(tT, 12) = " ") || ($Extract(tT, 12) = tTab)) {
        Set tRest = $Extract(tT, 12, *)
    } ElseIf ($Extract(tT, 1, 6) = "Method") && (($Extract(tT, 7) = " ") || ($Extract(tT, 7) = tTab)) {
        Set tRest = $Extract(tT, 7, *)
    } Else {
        Quit ""
    }
    Set tRest = ..StripLeading(tRest)
    ; extract the maximal run of name characters ([A-Za-z0-9_%])
    Set tName = ""
    Set tI = 1
    While tI <= $Length(tRest) {
        Set tC = $Ascii(tRest, tI)
        If ((tC >= 48) && (tC <= 57)) || ((tC >= 65) && (tC <= 90)) || ((tC >= 97) && (tC <= 122)) || (tC = 95) || (tC = 37) {
            Set tName = tName_$Char(tC)
            Set tI = tI + 1
        } Else {
            Quit
        }
    }
    If tName = "" Quit ""
    Set pAfterName = $Extract(tRest, $Length(tName) + 1, *)
    Quit tName
}

/// <p>Whether <var>pName</var> is a test method name: <code>Test</code> followed by letters, digits and
/// underscores, or a unit-test lifecycle method name.</p>
ClassMethod IsTestMethodName(pName As %String) As %Boolean
{
    If (pName = "OnBeforeAllTests") || (pName = "OnAfterAllTests") || (pName = "OnBeforeOneTest") || (pName = "OnAfterOneTest") Quit 1
    If $Extract(pName, 1, 4) '= "Test" Quit 0
    ; the tail must be [A-Za-z0-9_]* (no % — parity with the reference regex)
    Set tTail = $Extract(pName, 5, *)
    Set tOk = 1
    For tI = 1:1:$Length(tTail) {
        Set tC = $Ascii(tTail, tI)
        If ((tC >= 48) && (tC <= 57)) || ((tC >= 65) && (tC <= 90)) || ((tC >= 97) && (tC <= 122)) || (tC = 95) {
            Continue
        }
        Set tOk = 0
        Quit
    }
    Quit tOk
}

}
