/// <p>The line counter's entry point: the totals of a document set, by line kind. A harvested
/// handler body's library, inherited by <class>OcuPilot.Port.Harvest.Loc</class> so that it
/// resolves while the body has switched namespace. Every document's lines fall in exactly one of
/// five buckets, and the buckets must sum to the document's total, in each document and in the
/// aggregate, or the count fails.</p>
/// <p>The count is all or nothing: a document that cannot be read or classified fails the whole count,
/// naming it, rather than being skipped.</p>
Class OcuPilot.Port.Harvest.LocGenerate Extends OcuPilot.Kernel.Utils [ Abstract ]
{

/// <p>Count the lines of the classes, routines and include files in <var>pNamespace</var> whose names match
/// <var>pSpec</var>.</p>
/// <p><var>pNamespace</var> is the target namespace, <code>""</code> for the current one; it is switched
/// by save and restore. <var>pSpec</var> is required: comma-separated names with <code>*</code> and
/// <code>?</code> wildcards. <var>pOptions</var> may carry <code>includeGenerated</code> (default false)
/// and <code>topN</code>, the length of the largest-documents list (default 20; a number is clamped to 1
/// through 100, anything else keeps the default).</p>
/// <p><var>pResult</var> is <code>{filesParsed, totalLines, blankLines, sourceCodeLoc, sourceCommentLoc,
/// testCodeLoc, testCommentLoc, codePct, sourceCodePct, testCodePct, commentPct, whitespacePct,
/// topDocuments: [{name, type, totalLines, codeLoc, commentLoc, isTest}], truncatedTopN}</code>.</p>
ClassMethod Count(pNamespace As %String = "", pSpec As %String = "", pOptions As %DynamicObject = "", Output pResult As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ..ValidateRequired(pSpec, "spec")
        If $$$ISERR(tSC) Quit

        ; resolve options (Rule #15: no $Get() around method calls — %IsDefined + %Get)
        Set tIncludeGenerated = 0
        Set tTopN = 20
        If $IsObject(pOptions) {
            If pOptions.%IsDefined("includeGenerated") {
                ; boolean coercion pattern (CR 21.1-A): booleans/numbers coerce; the
                ; "true"/"false"/"0"/"1" strings are accepted; junk keeps the default
                Set tVal = pOptions.%Get("includeGenerated")
                Set tType = pOptions.%GetTypeOf("includeGenerated")
                If (tType = "boolean") || (tType = "number") {
                    Set tIncludeGenerated = ''tVal
                } ElseIf $ZConvert(tVal, "L") = "true" {
                    Set tIncludeGenerated = 1
                } ElseIf $ZConvert(tVal, "L") = "false" {
                    Set tIncludeGenerated = 0
                } ElseIf (tVal = "0") || (tVal = "1") {
                    Set tIncludeGenerated = +tVal
                }
            }
            If pOptions.%IsDefined("topN") {
                ; CR 22.0-2: a present NUMERIC value clamps into 1..100 (matching
                ; the documented contract and the REST layer's 0->1 clamp);
                ; non-numeric junk keeps the default 20
                Set tRawN = pOptions.%Get("topN")
                If (pOptions.%GetTypeOf("topN") = "number") || (tRawN ? 1.N) {
                    Set tN = +tRawN \ 1
                    If tN < 1 Set tN = 1
                    Set tTopN = tN
                }
            }
        }
        If tTopN > 100 Set tTopN = 100

        ; switch to the target namespace (restored below and in the catch path)
        If (pNamespace '= "") && (pNamespace '= tOrigNS) {
            Set $NAMESPACE = pNamespace
        }

        Set tSC = ..EnumerateDocs(pSpec, tIncludeGenerated, .tDocs)
        If $$$ISERR(tSC) {
            Set $NAMESPACE = tOrigNS
            Quit
        }

        Set tFiles = 0
        Set tTotal = 0
        Set tBlank = 0
        Set tSrcCode = 0
        Set tSrcComment = 0
        Set tTestCode = 0
        Set tTestComment = 0
        For tI = 1:1:+$Get(tDocs) {
            Set tDocName = tDocs(tI)
            Set tSC = ..ScanDoc(tDocName, .tCounts, .tIsTest)
            If $$$ISERR(tSC) Quit
            Set tFiles = tFiles + 1
            Set tDocTotal = tCounts("total")
            Set tDocCode = tCounts("sourceCode") + tCounts("testCode")
            Set tDocComment = tCounts("sourceComment") + tCounts("testComment")
            ; per-document bucket-sum invariant (hard error, not a warning)
            Set tDocSum = tCounts("blank") + tDocCode + tDocComment
            If tDocSum '= tDocTotal {
                Set tSC = $$$ERROR($$$GeneralError, "LOC bucket sum ("_tDocSum_") does not equal total lines ("_tDocTotal_") for document '"_tDocName_"'")
                Quit
            }
            Set tTotal = tTotal + tDocTotal
            Set tBlank = tBlank + tCounts("blank")
            Set tSrcCode = tSrcCode + tCounts("sourceCode")
            Set tSrcComment = tSrcComment + tCounts("sourceComment")
            Set tTestCode = tTestCode + tCounts("testCode")
            Set tTestComment = tTestComment + tCounts("testComment")
            ; track per-document data for the top-N list (decision D5): negative
            ; totalLines subscript sorts largest-first; insertion sequence breaks ties
            Set tDocData(tI) = $ListBuild(tDocName, $ZConvert($Piece(tDocName, ".", *), "L"), tDocTotal, tDocCode, tDocComment, +tIsTest)
            Set tSort(-tDocTotal, tI) = ""
        }
        If $$$ISERR(tSC) {
            Set $NAMESPACE = tOrigNS
            Quit
        }

        ; aggregate bucket-sum invariant
        Set tSum = tBlank + tSrcCode + tSrcComment + tTestCode + tTestComment
        If tSum '= tTotal {
            Set tSC = $$$ERROR($$$GeneralError, "LOC aggregate bucket sum ("_tSum_") does not equal total lines ("_tTotal_")")
            Set $NAMESPACE = tOrigNS
            Quit
        }

        ; top-N largest documents (decision D5)
        Set tTopDocs = []
        Set tEmitted = 0
        Set tNegTotal = ""
        For {
            Set tNegTotal = $Order(tSort(tNegTotal))
            Quit:tNegTotal=""
            Set tSeq = ""
            For {
                Set tSeq = $Order(tSort(tNegTotal, tSeq))
                Quit:tSeq=""
                If tEmitted < tTopN {
                    Set tData = tDocData(tSeq)
                    Set tDoc = {}
                    Do tDoc.%Set("name", $List(tData, 1))
                    Do tDoc.%Set("type", $List(tData, 2))
                    Do tDoc.%Set("totalLines", $List(tData, 3), "number")
                    Do tDoc.%Set("codeLoc", $List(tData, 4), "number")
                    Do tDoc.%Set("commentLoc", $List(tData, 5), "number")
                    Do tDoc.%Set("isTest", $List(tData, 6), "boolean")
                    Do tTopDocs.%Push(tDoc)
                    Set tEmitted = tEmitted + 1
                }
            }
            Quit:tEmitted>=tTopN
        }

        Set pResult = {}
        Do pResult.%Set("filesParsed", tFiles, "number")
        Do pResult.%Set("totalLines", tTotal, "number")
        Do pResult.%Set("blankLines", tBlank, "number")
        Do pResult.%Set("sourceCodeLoc", tSrcCode, "number")
        Do pResult.%Set("sourceCommentLoc", tSrcComment, "number")
        Do pResult.%Set("testCodeLoc", tTestCode, "number")
        Do pResult.%Set("testCommentLoc", tTestComment, "number")
        ; percentages (decision D4 — reference CSV keys in camelCase, one decimal)
        Do pResult.%Set("codePct", ..Pct(tSrcCode + tTestCode, tTotal), "number")
        Do pResult.%Set("sourceCodePct", ..Pct(tSrcCode, tTotal), "number")
        Do pResult.%Set("testCodePct", ..Pct(tTestCode, tTotal), "number")
        Do pResult.%Set("commentPct", ..Pct(tSrcComment + tTestComment, tTotal), "number")
        Do pResult.%Set("whitespacePct", ..Pct(tBlank, tTotal), "number")
        Do pResult.%Set("topDocuments", tTopDocs)
        Do pResult.%Set("truncatedTopN", (tFiles > tTopN), "boolean")

        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>One-decimal percentage, <code>100 * pNum / pDen</code>; 0 when <var>pDen</var> is 0.</p>
ClassMethod Pct(pNum As %Integer, pDen As %Integer) As %Numeric [ Internal ]
{
    If pDen = 0 Quit 0
    Quit +$Justify(100 * pNum / pDen, 0, 1)
}

}
