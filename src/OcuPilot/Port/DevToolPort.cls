/// <p>The port to the developer-tool bodies that count a namespace's lines, hash its documents and compare two
/// namespaces' documents (AD-23, AD-29): the only caller of <class>OcuPilot.Port.Harvest.Loc</class> and
/// <class>OcuPilot.Port.Harvest.EnvSync</class>, through <class>OcuPilot.Port.HarvestPort</class>.
/// Nothing here issues an HTTP request, and nothing here names a class of the source code API.</p>
/// <p>The bodies refuse a bad request in a way the harvest port answers as an internal fault, and
/// neither caps what it scans, so <b>the order of every call is fixed</b> and nothing reaches a body
/// before all of it has passed:</p>
/// <ol>
/// <li><method>OcuPilot.Port.AtelierPort.Pairs</method>, through <method>GateClass</method>'s
/// <code>EvaluateRequired</code>; a refusal is 403 naming the failed pair.</li>
/// <li>The namespace: the query's <parameter>NAMESPACEKEY</parameter>, or the request's scope, its shape
/// checked.</li>
/// <li><method>OcuPilot.Port.AtelierPort.NamespacePairs</method>, refused 400 <code>PORT.VALIDATION</code>
/// when it answers <code>""</code> and evaluated like step 1 otherwise.</li>
/// <li>The endpoint and the request type.</li>
/// <li>For <parameter>ENDPOINTNAMESPACEDIFF</parameter> only, the other namespace the query's
/// <parameter>TARGETKEY</parameter> names: its shape, then that it is not the first namespace (compared in
/// upper case), then its <method>OcuPilot.Port.AtelierPort.NamespacePairs</method>, refused 400
/// <code>PORT.VALIDATION</code> when they answer <code>""</code> and evaluated like step 3 otherwise.</li>
/// <li>The row cap, and the generated choice.</li>
/// <li>The spec's shape: each comma-separated part is one name with <code>*</code> and <code>?</code>
/// wildcards, and spaces around a part are dropped.</li>
/// <li>The wide-spec rule: a part that is a bare <code>*</code> is 400 <parameter>OcuPilot.Api.AtelierError.SPECWIDE</parameter>.</li>
/// <li>The document count: the documents the spec matches in the namespace, counted with the query the
/// bodies list with, above <method>MaxDocuments</method> is 400
/// <parameter>OcuPilot.Api.AtelierError.SPECTOOMANY</parameter> with <code>detail.count</code> and
/// <code>detail.max</code>. A namespace diff counts each namespace and adds <code>detail.namespace</code>,
/// the one that exceeded the cap.</li>
/// </ol>
/// <p>Only then does it call the harvest port with the pair set of steps 1 and 3 together, and for a namespace
/// diff a second time with steps 1 and 4. It sends a body only the query keys it built itself:
/// <code>spec</code>, <code>namespace</code>, <code>includeGenerated</code> and, for code metrics,
/// <code>topN</code>; it never sends <code>allowWide</code>. No <code>OcuPilot.*</code> class is called while
/// the namespace is switched.</p>
/// <p><b>Its answers</b> are lists of rows: <parameter>ENDPOINTCODEMETRICS</parameter> one row of totals,
/// <parameter>ENDPOINTDOCUMENTHASHES</parameter> one row for each document, in the body's order, and
/// <parameter>ENDPOINTNAMESPACEDIFF</parameter> one row for each document that is not the same in both namespaces.</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>HarvestPortClass</method>,
/// <method>MaxDocuments</method> and <method>LogFault</method>. Production overrides none.</p>
Class OcuPilot.Port.DevToolPort Extends %RegisteredObject
{

/// <p>Empty: this port declares no pair set of its own. Its gate is
/// <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter> and the namespace's database pairs
/// (<method>OcuPilot.Port.AtelierPort.NamespacePairs</method>).</p>
Parameter PAIRS = "";

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The subsystem raw failure text is logged under.</p>
Parameter LOGSUBSYSTEM = "devtoolport";

/// <p>The most documents one call reads: the largest multiple of 500, at most 5,000, for which the slower
/// of the two bodies is projected to finish within 20 seconds at its measured average cost a document. A
/// set of larger documents takes longer.</p>
Parameter MAXDOCUMENTS As INTEGER = 1000;

/// <p>The endpoint answering the totals of a namespace's lines.</p>
Parameter ENDPOINTCODEMETRICS = "CodeMetrics";

/// <p>The endpoint answering a content hash for each of a namespace's documents.</p>
Parameter ENDPOINTDOCUMENTHASHES = "DocumentHashes";

/// <p>The endpoint answering a row for each document that differs between two namespaces of this instance.</p>
Parameter ENDPOINTNAMESPACEDIFF = "NamespaceDiff";

/// <p>The one request type this port serves: a list.</p>
Parameter TYPELIST = "LIST";

/// <p>The query key naming the namespace a call runs in.</p>
Parameter NAMESPACEKEY = "namespace";

/// <p>The query key naming the namespace a namespace diff compares the first one with.</p>
Parameter TARGETKEY = "target";

/// <p>The query key naming the documents.</p>
Parameter SPECKEY = "spec";

/// <p>The query key choosing whether generated routines are counted: <code>yes</code> or <code>no</code>.</p>
Parameter GENERATEDKEY = "generated";

/// <p>The query key bounding a list's rows.</p>
Parameter MAXROWSKEY = "maxRows";

/// <p>The longest spec this port reads.</p>
Parameter SPECMAXLENGTH As INTEGER = 256;

/// <p>The shape one part of a spec takes.</p>
Parameter SPECPARTPATTERN = "^[A-Za-z0-9%.*?]+$";

/// <p>The body that counts lines, and its method.</p>
Parameter HANDLERLOC = "OcuPilot.Port.Harvest.Loc";

Parameter METHODLOC = "LocCount";

/// <p>The body that hashes documents, and its method.</p>
Parameter HANDLERHASH = "OcuPilot.Port.Harvest.EnvSync";

Parameter METHODHASH = "DocHashes";

/// <p>The reasons this port's own argument refusals carry. Its endpoint, namespace and row-cap refusals carry
/// <class>OcuPilot.Port.AtelierPort</class>'s.</p>
Parameter REASONSPECLENGTH = "Name the documents: 1 to 256 characters.";

Parameter REASONSPECSHAPE = "Name documents with letters, digits, %, dots, * and ?, separated by commas.";

Parameter REASONGENERATED = "generated must be yes or no.";

Parameter REASONTARGETSHAPE = "Name the namespace to compare with.";

Parameter REASONTARGETSAME = "Choose a namespace other than this one to compare with.";

/// <p>What a namespace diff's <code>Change</code> reads for a document in the first namespace alone, in the other
/// alone, and in both with different content.</p>
Parameter CHANGEONLYHERE = "Only in this namespace";

Parameter CHANGEONLYTHERE = "Only in the other namespace";

Parameter CHANGEDIFFERS = "Content differs";

/// <p>The class the pair sets are evaluated through. Overridable so a fixture can drive a denial in
/// process; production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>The class every body is run through. Overridable so a fixture can record each call; production
/// never overrides it.</p>
ClassMethod HarvestPortClass() As %String
{
    Quit "OcuPilot.Port.HarvestPort"
}

/// <p>The most documents one call reads. Overridable so a fixture can lower it; production never
/// overrides it.</p>
ClassMethod MaxDocuments() As %Integer
{
    Quit ..#MAXDOCUMENTS
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture
/// the line; production never overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>The endpoints this port serves, as a list.</p>
ClassMethod Endpoints() As %List
{
    Quit $ListBuild(..#ENDPOINTCODEMETRICS, ..#ENDPOINTDOCUMENTHASHES, ..#ENDPOINTNAMESPACEDIFF)
}

/// <p>Serve <var>pEndpoint</var> for request type <parameter>TYPELIST</parameter>, after this class's
/// header's gate.</p>
/// <p><var>pQuery</var> carries <parameter>SPECKEY</parameter>, <parameter>GENERATEDKEY</parameter>
/// (optional, <code>no</code> when absent), <parameter>NAMESPACEKEY</parameter> (optional: the request's
/// scope when absent), <parameter>MAXROWSKEY</parameter> (optional, a whole number above zero, the
/// most rows a hash or diff list answers) and, for <parameter>ENDPOINTNAMESPACEDIFF</parameter>,
/// <parameter>TARGETKEY</parameter>. <var>pBody</var> is not read.</p>
/// <p>On success, at 200, <var>pResult</var> is an array of rows: for
/// <parameter>ENDPOINTCODEMETRICS</parameter> one <code>{Documents, Lines, Code, CodePercent, SourceCode,
/// TestCode, Comments, CommentPercent, Blank, BlankPercent}</code>, and for
/// <parameter>ENDPOINTDOCUMENTHASHES</parameter> <code>{Document, Hash, Modified}</code> for each document,
/// <code>Hash</code> the SHA-256 of its text in hex, and for <parameter>ENDPOINTNAMESPACEDIFF</parameter>
/// <code>{Document, Change, Hash, OtherHash, Modified, OtherModified}</code> for each document that is in one
/// namespace only or whose hashes differ (the other namespace's fields <code>""</code> for a document it lacks),
/// in <code>Document</code> order, at most the row cap of them.</p>
/// <p>Otherwise an error status is returned, <var>pHttpStatus</var> is the status to answer with and
/// <var>pFault</var> the wire fault: 403 <code>AUTH.NOPRIVILEGE</code> with
/// <code>detail.failedPair</code>; 400 <code>PORT.VALIDATION</code> for a namespace, a target, a cap, a spec or a
/// generated value of the wrong shape, or a namespace whose databases cannot be resolved; 400
/// <parameter>OcuPilot.Api.AtelierError.SPECWIDE</parameter> and
/// <parameter>OcuPilot.Api.AtelierError.SPECTOOMANY</parameter>; 501 <code>PORT.NOTIMPLEMENTED</code> for
/// another endpoint or type; and whatever the harvest port answers for a body's failure, 500
/// <code>INTERNAL</code> for anything else, logged.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is
/// unchanged on return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tFailedPair = ""
        Set tPairs = ##class(OcuPilot.Port.AtelierPort).Pairs()
        ; EvaluateRequired, not EvaluatePairs: a pair set that parses to nothing fails closed.
        If '$ClassMethod(..GateClass(), "EvaluateRequired", tPairs, .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
        If tNamespace = "" Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        If '$Match(tNamespace, ##class(OcuPilot.Port.AtelierPort).#NAMESPACEPATTERN) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.AtelierPort).#REASONNAMESPACESHAPE, .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespacePairs = ##class(OcuPilot.Port.AtelierPort).NamespacePairs(tNamespace)
        If tNamespacePairs = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.AtelierPort).#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
            Quit
        }
        If '$ClassMethod(..GateClass(), "EvaluateRequired", tNamespacePairs, .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }

        If ('$ListFind(..Endpoints(), pEndpoint)) || (pType '= ..#TYPELIST) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ##class(OcuPilot.Port.AtelierPort).#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tDiff = (pEndpoint = ..#ENDPOINTNAMESPACEDIFF)
        Set tTarget = ""
        Set tTargetPairs = ""
        If tDiff {
            Set tTarget = $Get(pQuery(..#TARGETKEY))
            If '$Match(tTarget, ##class(OcuPilot.Port.AtelierPort).#NAMESPACEPATTERN) {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONTARGETSHAPE, .pHttpStatus, .pFault)
                Quit
            }
            If $ZConvert(tTarget, "U") = $ZConvert(tNamespace, "U") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONTARGETSAME, .pHttpStatus, .pFault)
                Quit
            }
            Set tTargetPairs = ##class(OcuPilot.Port.AtelierPort).NamespacePairs(tTarget)
            If tTargetPairs = "" {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.AtelierPort).#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
                Quit
            }
            If '$ClassMethod(..GateClass(), "EvaluateRequired", tTargetPairs, .tFailedPair) {
                Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
                Quit
            }
        }
        Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
        If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.AtelierPort).#REASONMAXROWS, .pHttpStatus, .pFault)
            Quit
        }
        Set tMax = +tMaxText

        Set tGenerated = $Get(pQuery(..#GENERATEDKEY))
        If (tGenerated '= "") && (tGenerated '= "yes") && (tGenerated '= "no") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONGENERATED, .pHttpStatus, .pFault)
            Quit
        }
        Set tIncludeGenerated = (tGenerated = "yes")

        Set tProblem = ..SpecProblem($Get(pQuery(..#SPECKEY)), .tSpec)
        If tProblem = "wide" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AtelierError).#SPECWIDE, ##class(OcuPilot.Api.AtelierError).#REASONSPECWIDE, .pHttpStatus, .pFault)
            Quit
        }
        If tProblem '= "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, tProblem, .pHttpStatus, .pFault)
            Quit
        }

        Set tCountSC = ..CountDocuments(tNamespace, tSpec, tIncludeGenerated, .tCount)
        If $$$ISERR(tCountSC) {
            Set tSC = ..Fail(pEndpoint _ " could not count the documents it reads", tCountSC, .pHttpStatus, .pFault)
            Quit
        }
        Set tLimit = ..MaxDocuments()
        If tCount > tLimit {
            Set tSC = ..RefuseTooMany(tCount, tLimit, $Select(tDiff: tNamespace, 1: ""), .pHttpStatus, .pFault)
            Quit
        }
        If tDiff {
            Set tCountSC = ..CountDocuments(tTarget, tSpec, tIncludeGenerated, .tTargetCount)
            If $$$ISERR(tCountSC) {
                Set tSC = ..Fail(pEndpoint _ " could not count the documents it reads", tCountSC, .pHttpStatus, .pFault)
                Quit
            }
            If tTargetCount > tLimit {
                Set tSC = ..RefuseTooMany(tTargetCount, tLimit, tTarget, .pHttpStatus, .pFault)
                Quit
            }
        }

        Set tMetrics = (pEndpoint = ..#ENDPOINTCODEMETRICS)
        Set tSC = ..RunBody(tMetrics, tSpec, tNamespace, tIncludeGenerated, tPairs _ tNamespacePairs, .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If tDiff {
            Set tSC = ..RunBody(0, tSpec, tTarget, tIncludeGenerated, tPairs _ tTargetPairs, .tOtherAnswer, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            Set pResult = ..DiffRows(tAnswer, tOtherAnswer, tMax)
        } Else {
            Set pResult = $Select(tMetrics: ..MetricsRows(tAnswer), 1: ..HashRows(tAnswer, tMax))
        }
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Run the line-count body when <var>pMetrics</var>, the hash body otherwise, in <var>pNamespace</var> over
/// <var>pSpec</var> through the harvest port with <var>pPairs</var>, sending only the keys this port builds.
/// <var>pAnswer</var> is the body's result; on failure <var>pHttpStatus</var> and <var>pFault</var> are the
/// harvest port's.</p>
ClassMethod RunBody(pMetrics As %Boolean, pSpec As %String, pNamespace As %String, pIncludeGenerated As %Boolean, pPairs As %List, Output pAnswer, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill tQuery
    Set tQuery("spec") = pSpec
    Set tQuery("namespace") = pNamespace
    Set tQuery("includeGenerated") = pIncludeGenerated
    If pMetrics Set tQuery("topN") = 1
    Set tSC = $ClassMethod(..HarvestPortClass(), "Invoke", $Select(pMetrics: ..#HANDLERLOC, 1: ..#HANDLERHASH), $Select(pMetrics: ..#METHODLOC, 1: ..#METHODHASH), pPairs, .tQuery, "", .pAnswer, .tHttp, .tFault, .tConsole)
    Set pHttpStatus = 0
    Set pFault = ""
    If $$$ISERR(tSC) {
        Set pHttpStatus = tHttp
        Set pFault = tFault
    }
    Quit tSC
}

/// <p>The too-many-documents refusal for <var>pCount</var> documents over <var>pLimit</var>, with
/// <code>detail.namespace</code> naming <var>pNamespace</var> when that is not <code>""</code>.</p>
ClassMethod RefuseTooMany(pCount As %Integer, pLimit As %Integer, pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("count", pCount, "number")
    Do tDetail.%Set("max", pLimit, "number")
    If pNamespace '= "" Do tDetail.%Set("namespace", pNamespace, "string")
    Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AtelierError).#SPECTOOMANY, ##class(OcuPilot.Api.AtelierError).#REASONSPECTOOMANY, .pHttpStatus, .pFault, tDetail)
}

/// <p>The reason <var>pSpec</var> is refused, or <code>""</code> when it is read: <code>"wide"</code> for a
/// part that is a bare <code>*</code>, otherwise the written sentence. <var>pClean</var> is the spec
/// the bodies are sent: the parts without the spaces around them, joined by commas. A control character
/// anywhere, a part with a character outside <parameter>SPECPARTPATTERN</parameter> or with two dots in a row,
/// and an empty part are refused on shape. Pure.</p>
ClassMethod SpecProblem(pSpec As %String, Output pClean As %String) As %String
{
    Set pClean = ""
    If $IsObject(pSpec) || (pSpec = "") || ($Length(pSpec) > ..#SPECMAXLENGTH) Quit ..#REASONSPECLENGTH
    If $ZStrip(pSpec, "*C") '= pSpec Quit ..#REASONSPECSHAPE
    Set tWide = 0
    Set tShaped = 1
    Set tClean = ""
    For tI = 1:1:$Length(pSpec, ",") {
        Set tPart = $ZStrip($Piece(pSpec, ",", tI), "<>", " ")
        If '$Match(tPart, ..#SPECPARTPATTERN) || (tPart [ "..") {
            Set tShaped = 0
            Quit
        }
        If tPart = "*" Set tWide = 1
        Set tClean = tClean _ $Select(tI = 1: "", 1: ",") _ tPart
    }
    If 'tShaped Quit ..#REASONSPECSHAPE
    If tWide Quit "wide"
    Set pClean = tClean
    Quit ""
}

/// <p>How many classes, routines, generated routines and include files in <var>pNamespace</var> match
/// <var>pSpec</var>, counted with the <code>%RoutineMgr:StudioOpenDialog</code> query and arguments the
/// bodies list with, so the count is the number of documents a body would read. Only system classes run
/// while the namespace is switched, and it is restored first in the <code>Catch</code>.</p>
ClassMethod CountDocuments(pNamespace As %String, pSpec As %String, pIncludeGenerated As %Boolean, Output pCount As %Integer) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%ResultSet).%New("%RoutineMgr:StudioOpenDialog")
        Set tSC = tRS.Execute(pSpec, 1, 1, 0, 1, 0, +pIncludeGenerated)
        If $$$ISOK(tSC) {
            Set tNextSC = $$$OK
            While tRS.Next(.tNextSC) {
                Set tExt = $ZConvert($Piece(tRS.Get("Name"), ".", *), "L")
                If (tExt = "cls") || (tExt = "mac") || (tExt = "int") || (tExt = "inc") Set pCount = pCount + 1
            }
            If $$$ISERR(tNextSC) Set tSC = tNextSC
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The one row of totals <var>pAnswer</var>, the line-count body's result, makes, as an array:
/// <code>Code</code> and <code>Comments</code> add the source and the test lines, and the percentages
/// are the body's own.</p>
ClassMethod MetricsRows(pAnswer As %DynamicObject) As %DynamicArray [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Documents", pAnswer.%Get("filesParsed"), "number")
    Do tRow.%Set("Lines", pAnswer.%Get("totalLines"), "number")
    Do tRow.%Set("Code", pAnswer.%Get("sourceCodeLoc") + pAnswer.%Get("testCodeLoc"), "number")
    Do tRow.%Set("CodePercent", pAnswer.%Get("codePct"), "number")
    Do tRow.%Set("SourceCode", pAnswer.%Get("sourceCodeLoc"), "number")
    Do tRow.%Set("TestCode", pAnswer.%Get("testCodeLoc"), "number")
    Do tRow.%Set("Comments", pAnswer.%Get("sourceCommentLoc") + pAnswer.%Get("testCommentLoc"), "number")
    Do tRow.%Set("CommentPercent", pAnswer.%Get("commentPct"), "number")
    Do tRow.%Set("Blank", pAnswer.%Get("blankLines"), "number")
    Do tRow.%Set("BlankPercent", pAnswer.%Get("whitespacePct"), "number")
    Quit [(tRow)]
}

/// <p>One <code>{Document, Hash, Modified}</code> row for each document of <var>pAnswer</var>, the hash
/// body's result, in its order, at most <var>pMax</var> of them when that is above zero.</p>
ClassMethod HashRows(pAnswer As %DynamicObject, pMax As %Integer) As %DynamicArray [ Private ]
{
    Set tRows = []
    Set tIterator = pAnswer.%Get("documents").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tDocument) {
        If (pMax > 0) && (tRows.%Size() >= pMax) Quit
        Set tRow = {}
        Do tRow.%Set("Document", tDocument.%Get("name"), "string")
        Do tRow.%Set("Hash", tDocument.%Get("hash"), "string")
        Do tRow.%Set("Modified", tDocument.%Get("timestamp"), "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>One <code>{Document, Change, Hash, OtherHash, Modified, OtherModified}</code> row for each document that
/// <var>pHere</var> and <var>pThere</var>, two hash bodies' results, do not hold alike: a document is keyed by its
/// name, equal hashes are the same whatever their times, and the rows are in <code>Document</code> order, at most
/// <var>pMax</var> of them when that is above zero. A document only in <var>pThere</var> is reported, never a
/// deletion signal.</p>
ClassMethod DiffRows(pHere As %DynamicObject, pThere As %DynamicObject, pMax As %Integer) As %DynamicArray [ Private ]
{
    Kill tHere, tThere, tNames
    For tSide = 1, 2 {
        Set tIterator = $Select(tSide = 1: pHere, 1: pThere).%Get("documents").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tDocument) {
            Set tName = tDocument.%Get("name")
            Set tNames(tName) = ""
            If tSide = 1 Set tHere(tName) = $ListBuild(tDocument.%Get("hash"), tDocument.%Get("timestamp"))
            If tSide = 2 Set tThere(tName) = $ListBuild(tDocument.%Get("hash"), tDocument.%Get("timestamp"))
        }
    }
    Set tRows = []
    Set tName = ""
    For {
        Set tName = $Order(tNames(tName))
        If tName = "" Quit
        If (pMax > 0) && (tRows.%Size() >= pMax) Quit
        Set tHas = $Data(tHere(tName))
        Set tOther = $Data(tThere(tName))
        If tHas && tOther {
            If $List(tHere(tName), 1) = $List(tThere(tName), 1) Continue
            Set tChange = ..#CHANGEDIFFERS
        } Else {
            Set tChange = $Select(tHas: ..#CHANGEONLYHERE, 1: ..#CHANGEONLYTHERE)
        }
        Set tRow = {}
        Do tRow.%Set("Document", tName, "string")
        Do tRow.%Set("Change", tChange, "string")
        Do tRow.%Set("Hash", $Select(tHas: $List(tHere(tName), 1), 1: ""), "string")
        Do tRow.%Set("OtherHash", $Select(tOther: $List(tThere(tName), 1), 1: ""), "string")
        Do tRow.%Set("Modified", $Select(tHas: $List(tHere(tName), 2), 1: ""), "string")
        Do tRow.%Set("OtherModified", $Select(tOther: $List(tThere(tName), 2), 1: ""), "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p><code>""</code>: no request this port serves is a write, so none has a script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ""
}

/// <p>No step: no request this port serves is a write (AD-59).</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    Quit []
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

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

}
