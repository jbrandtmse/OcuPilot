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
/// <code>PORT.VALIDATION</code> when they answer <code>""</code> and evaluated like step 1 otherwise.</li>
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
/// diff a second time with steps 1 and 5. It sends a body only the query keys it built itself:
/// <code>spec</code>, <code>namespace</code>, <code>includeGenerated</code> and, for code metrics,
/// <code>topN</code>; it never sends <code>allowWide</code>. No <code>OcuPilot.*</code> class is called while
/// the namespace is switched.</p>
/// <p><b>Its answers</b> are lists of rows: <parameter>ENDPOINTCODEMETRICS</parameter> one row of totals,
/// <parameter>ENDPOINTDOCUMENTHASHES</parameter> one row for each document, in the body's order, and
/// <parameter>ENDPOINTNAMESPACEDIFF</parameter> one row for each document that is not the same in both namespaces; the
/// composed types answer one object each (<method>Invoke</method>).</p>
/// <p><b>Promote.</b> The <parameter>ENDPOINTNAMESPACEDIFF</parameter> endpoint also serves two composed types.
/// <parameter>TYPEPLAN</parameter> derives the promote plan (<method>Plan</method>) from the same two body answers
/// and checks the documents the caller names against it. <parameter>TYPEPROMOTE</parameter> does that and then writes
/// them into the other namespace through <class>OcuPilot.Port.AtelierPort</class> alone, source first and nothing ever
/// written to the first namespace. After steps 1 to 9 above, in this order and before any write:</p>
/// <ol>
/// <li>The first namespace, the other namespace or a document the caller names being <code>%SYS</code> or beginning
/// with <code>%</code> is 400 <parameter>CODESYSTEM</parameter>.</li>
/// <li>The documents (<parameter>DOCUMENTSKEY</parameter>, 1 to <parameter>OcuPilot.Port.AtelierPort.MAXDOCUMENTS</parameter>
/// names) are held to the plan's steps: a name that is not an <code>Only in this namespace</code> or
/// <code>Content differs</code> step refuses the whole request, 400 <parameter>CODENOTASTEP</parameter> with
/// <code>detail.document</code>. A count outside the bounds is 400 <code>PORT.VALIDATION</code>.</li>
/// <li>For <parameter>TYPEPROMOTE</parameter> only: WRITE on the other namespace's routines database
/// (<method>OcuPilot.Port.AtelierPort.WritePairs</method>), evaluated like step 1 of the read; then the reviewed plan
/// hash (<parameter>REVIEWEDKEY</parameter>, else <parameter>PLANHASHKEY</parameter>) compared with the plan hash derived
/// now, 409 <parameter>CODESTALE</parameter> when it differs or is absent; then a preflight that reads the text of every
/// chosen document, and the other namespace's text and version for each that is saved, refusing a text longer than one
/// save takes or whose first line does not name its document; then the storage guard, 409
/// <parameter>CODESTORAGE</parameter> with <code>detail.document</code> for a class whose copy in the other namespace
/// has a storage definition its source lacks.</li>
/// </ol>
/// <p>Only then are documents written, in <code>Document</code> order and stopping at the first failure: a save with the
/// version the preflight read and never over a newer one, a create, each sent without compiling, then one compile of the
/// classes and one of the routines. Nothing is deleted and nothing is undone. The answer is 200
/// <code>{documents: [{Document, Outcome, Reason}], lines, errors, stopped}</code>; the write is audited as OcuPilot's own
/// <code>ConfigChange</code>.</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>HarvestPortClass</method>,
/// <method>AtelierPortClass</method>, <method>MaxDocuments</method> and <method>LogFault</method>. Production overrides none.</p>
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

/// <p>The request type every endpoint serves: a list.</p>
Parameter TYPELIST = "LIST";

/// <p>The two request types <parameter>ENDPOINTNAMESPACEDIFF</parameter> also serves: the plan of a promote, and the
/// promote itself.</p>
Parameter TYPEPLAN = "PLAN";

Parameter TYPEPROMOTE = "PROMOTE";

/// <p>The <code>endpoint/type</code> pairs whose writes this port composes from the query it is given, and sends no caller
/// body for.</p>
Parameter COMPOSEDTYPES = "NamespaceDiff/PROMOTE";

/// <p>The query keys a plan or a promote reads beyond a diff's: the documents, comma-separated; the plan hash the
/// caller reviewed; and the plan hash a proposal was made at.</p>
Parameter DOCUMENTSKEY = "documents";

Parameter REVIEWEDKEY = "reviewed";

Parameter PLANHASHKEY = "planHash";

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

/// <p>The codes and sentences a plan's or a promote's own refusals carry.</p>
Parameter CODENOTASTEP = "EXPLORER.PROMOTE.NOTASTEP";

Parameter REASONNOTASTEP = "Choose documents the plan lists as only in this namespace or as differing.";

Parameter CODESTALE = "EXPLORER.PROMOTE.STALE";

Parameter REASONSTALE = "The namespaces changed after this plan was shown, so nothing was written. Compare them again and review the new plan.";

Parameter CODESYSTEM = "EXPLORER.PROMOTE.SYSTEM";

Parameter REASONSYSTEM = "Promote works between two namespaces other than %SYS and never writes a document whose name begins with %.";

Parameter CODESTORAGE = "EXPLORER.PROMOTE.STORAGE";

Parameter REASONSTORAGE = "A class here lacks a storage definition its copy in the other namespace has, so nothing was written: compiling it there would change how its stored data is read.";

Parameter REASONDOCUMENTS = "Choose 1 to 100 documents to promote.";

/// <p>What a promote's answer reads for each document: written over the other namespace's copy, written as a new
/// document, refused by the write that stopped the promote, and left unwritten after it.</p>
Parameter OUTCOMEREPLACED = "Replaced";

Parameter OUTCOMEADDED = "Added";

Parameter OUTCOMEFAILED = "Failed";

Parameter OUTCOMENOTATTEMPTED = "Not attempted";

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

/// <p>The class every plan's and promote's document read, save, create and compile is run through. Overridable so a
/// fixture can fail a chosen save; production never overrides it.</p>
ClassMethod AtelierPortClass() As %String
{
    Quit "OcuPilot.Port.AtelierPort"
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

/// <p>Serve <var>pEndpoint</var> for request type <parameter>TYPELIST</parameter>, or, for
/// <parameter>ENDPOINTNAMESPACEDIFF</parameter> only, <parameter>TYPEPLAN</parameter> or
/// <parameter>TYPEPROMOTE</parameter>, after this class's header's gate.</p>
/// <p><var>pQuery</var> carries <parameter>SPECKEY</parameter>, <parameter>GENERATEDKEY</parameter>
/// (optional, <code>no</code> when absent), <parameter>NAMESPACEKEY</parameter> (optional: the request's
/// scope when absent), <parameter>MAXROWSKEY</parameter> (optional, a whole number above zero, the
/// most rows a hash or diff list answers) and, for <parameter>ENDPOINTNAMESPACEDIFF</parameter>,
/// <parameter>TARGETKEY</parameter>. A plan or a promote also reads <parameter>DOCUMENTSKEY</parameter>,
/// <parameter>REVIEWEDKEY</parameter> and <parameter>PLANHASHKEY</parameter>. <var>pBody</var> is not read.</p>
/// <p>On success, at 200, <var>pResult</var> for a plan is <code>{Namespace, Target, Spec, Generated, Steps, Warnings,
/// PlanHash, Reviewed}</code>: the namespaces, the cleaned spec and <code>yes</code> or <code>no</code>, the chosen
/// documents as <code>[{Document, Change}]</code> in <code>Document</code> order, how many documents only the other
/// namespace holds, the plan hash (<method>Plan</method>) and <code>""</code>; for a promote it is
/// <method>Promote</method>'s answer. Otherwise <var>pResult</var> is an array of rows: for
/// <parameter>ENDPOINTCODEMETRICS</parameter> one <code>{Documents, Lines, Code, CodePercent, SourceCode,
/// TestCode, Comments, CommentPercent, Blank, BlankPercent}</code>, and for
/// <parameter>ENDPOINTDOCUMENTHASHES</parameter> <code>{Document, Hash, Modified}</code> for each document,
/// <code>Hash</code> the SHA-256 of its text in hex, and for <parameter>ENDPOINTNAMESPACEDIFF</parameter>
/// <code>{Document, Change, Hash, OtherHash, Modified, OtherModified, Promotable}</code> for each document that is in one
/// namespace only or whose hashes differ (the other namespace's fields <code>""</code> for a document it lacks),
/// in <code>Document</code> order, at most the row cap of them.</p>
/// <p>Otherwise an error status is returned, <var>pHttpStatus</var> is the status to answer with and
/// <var>pFault</var> the wire fault: 403 <code>AUTH.NOPRIVILEGE</code> with
/// <code>detail.failedPair</code>; 400 <code>PORT.VALIDATION</code> for a namespace, a target, a cap, a spec or a
/// generated value of the wrong shape, or a namespace whose databases cannot be resolved; 400
/// <parameter>OcuPilot.Api.AtelierError.SPECWIDE</parameter> and
/// <parameter>OcuPilot.Api.AtelierError.SPECTOOMANY</parameter>; for a plan or a promote, 400
/// <parameter>CODESYSTEM</parameter> and <parameter>CODENOTASTEP</parameter>, 409 <parameter>CODESTALE</parameter> and
/// <parameter>CODESTORAGE</parameter> and a document's own refusals (<method>Preflight</method>); 501
/// <code>PORT.NOTIMPLEMENTED</code> for another endpoint or type; and whatever the harvest port answers for a body's failure, 500
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

        Set tPlanType = (pType = ..#TYPEPLAN) || (pType = ..#TYPEPROMOTE)
        If ('$ListFind(..Endpoints(), pEndpoint)) || ((pType '= ..#TYPELIST) && '(tPlanType && (pEndpoint = ..#ENDPOINTNAMESPACEDIFF))) {
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

        If tPlanType {
            Set tSC = ..PlanProblem(tNamespace, tTarget, $Get(pQuery(..#DOCUMENTSKEY)), .tNames, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
        }

        Set tMetrics = (pEndpoint = ..#ENDPOINTCODEMETRICS)
        Set tSC = ..RunBody(tMetrics, tSpec, tNamespace, tIncludeGenerated, tPairs _ tNamespacePairs, .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If tDiff {
            Set tSC = ..RunBody(0, tSpec, tTarget, tIncludeGenerated, tPairs _ tTargetPairs, .tOtherAnswer, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            If tPlanType {
                Set tSC = ..Compose(pType = ..#TYPEPROMOTE, tNamespace, tTarget, tSpec, tIncludeGenerated, tNames, ..Plan(tAnswer, tOtherAnswer), $Get(pQuery(..#REVIEWEDKEY)), $Get(pQuery(..#PLANHASHKEY)), .pResult, .pHttpStatus, .pFault)
                If $$$ISERR(tSC) Quit
            } Else {
                Set pResult = ..DiffRows(tAnswer, tOtherAnswer, tMax)
            }
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

/// <p>One <code>{Document, Change, Hash, OtherHash, Modified, OtherModified, Promotable}</code> row for each document that
/// <var>pHere</var> and <var>pThere</var>, two hash bodies' results, do not hold alike: a document is keyed by its
/// name, equal hashes are the same whatever their times, and the rows are in <code>Document</code> order, at most
/// <var>pMax</var> of them when that is above zero. A document only in <var>pThere</var> is reported, never a
/// deletion signal, and is the one row that is not <code>Promotable</code>.</p>
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
        Do tRow.%Set("Promotable", (tChange '= ..#CHANGEONLYTHERE), "boolean")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>The hash of the plan the two body answers <var>pHere</var> and <var>pThere</var> make, and its parts, as
/// <code>{steps, warnings, planHash}</code>. Pure: it reads <method>DiffRows</method> over every document, with no row
/// cap. <code>steps</code> is each <code>Only in this namespace</code> and <code>Content differs</code> row as
/// <code>{Document, Change, Hash, OtherHash}</code>, in <code>Document</code> order; <code>warnings</code> is each
/// <code>Only in the other namespace</code> row as <code>{Document}</code>, which is never a step.
/// <code>planHash</code> is the SHA-256 in lower case hex of every row, steps and warnings together, each as
/// <code>Document|Change|Hash|OtherHash</code> on its own line in <code>Document</code> order; the times are left out,
/// so a document saved again with the same text changes nothing.</p>
ClassMethod Plan(pHere As %DynamicObject, pThere As %DynamicObject) As %DynamicObject
{
    Set tRows = ..DiffRows(pHere, pThere, 0)
    Set tSteps = []
    Set tWarnings = []
    Set tText = ""
    Set tFirst = 1
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tChange = tRow.%Get("Change")
        Set tText = tText _ $Select(tFirst: "", 1: $Char(10)) _ tRow.%Get("Document") _ "|" _ tChange _ "|" _ tRow.%Get("Hash") _ "|" _ tRow.%Get("OtherHash")
        Set tFirst = 0
        If tChange = ..#CHANGEONLYTHERE {
            Set tWarning = {}
            Do tWarning.%Set("Document", tRow.%Get("Document"), "string")
            Do tWarnings.%Push(tWarning)
            Continue
        }
        Set tStep = {}
        Do tStep.%Set("Document", tRow.%Get("Document"), "string")
        Do tStep.%Set("Change", tChange, "string")
        Do tStep.%Set("Hash", tRow.%Get("Hash"), "string")
        Do tStep.%Set("OtherHash", tRow.%Get("OtherHash"), "string")
        Do tSteps.%Push(tStep)
    }
    Set tPlan = {}
    Do tPlan.%Set("steps", tSteps)
    Do tPlan.%Set("warnings", tWarnings)
    Do tPlan.%Set("planHash", ..Sha256Hex(tText), "string")
    Quit tPlan
}

/// <p>The SHA-256 of <var>pText</var> as UTF-8, in lower case hex.</p>
ClassMethod Sha256Hex(pText As %String) As %String [ Private ]
{
    Quit $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.SHAHash(256, $ZConvert(pText, "O", "UTF8"))), "L")
}

/// <p>The refusals of a plan's or a promote's arguments that need no body, after the read's own: the first namespace, the
/// other one or a document being <code>%SYS</code> or beginning with <code>%</code> is
/// <parameter>CODESYSTEM</parameter>; a name over 256 characters is <parameter>CODENOTASTEP</parameter>; and a count of
/// documents outside 1 to <parameter>OcuPilot.Port.AtelierPort.MAXDOCUMENTS</parameter> is
/// <code>PORT.VALIDATION</code>. <var>pNames</var> is <var>pDocuments</var>, comma-separated, as a <class>%List</class>
/// of each name once, sorted by character code.</p>
ClassMethod PlanProblem(pNamespace As %String, pTarget As %String, pDocuments As %String, Output pNames As %List, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pNames = ""
    Kill tSorted
    Set tSystem = ($ZConvert(pNamespace, "U") = "%SYS") || ($ZConvert(pTarget, "U") = "%SYS")
    Set tLong = ""
    For tI = 1:1:$Length(pDocuments, ",") {
        Set tName = $Piece(pDocuments, ",", tI)
        If tName = "" Continue
        If $Extract(tName) = "%" Set tSystem = 1
        If $Length(tName) > 256 {
            If tLong = "" Set tLong = tName
            Continue
        }
        Set tSorted("n" _ tName) = tName
    }
    If tSystem Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ..#CODESYSTEM, ..#REASONSYSTEM, .pHttpStatus, .pFault)
    If tLong '= "" Quit ..NotAStep(tLong, .pHttpStatus, .pFault)
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey), 1, tName)
        If tKey = "" Quit
        Set pNames = pNames _ $ListBuild(tName)
    }
    If ($ListLength(pNames) = 0) || ($ListLength(pNames) > ##class(OcuPilot.Port.AtelierPort).#MAXDOCUMENTS) {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONDOCUMENTS, .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p>The refusal of the document <var>pName</var> as no step of the plan, naming at most its first 256
/// characters.</p>
ClassMethod NotAStep(pName As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("document", $Extract(pName, 1, 256), "string")
    Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ..#CODENOTASTEP, ..#REASONNOTASTEP, .pHttpStatus, .pFault, tDetail)
}

/// <p>The answer of a plan, or of a promote when <var>pPromote</var>, for the documents <var>pNames</var> against the plan
/// <var>pPlan</var> (<method>Plan</method>): every name must be one of its steps, else the whole request is refused
/// (<method>NotAStep</method>). A plan answers <code>{Namespace, Target, Spec, Generated, Steps, Warnings, PlanHash,
/// Reviewed}</code>, <code>Steps</code> only the chosen steps. <var>pReviewed</var>, else <var>pPlanHash</var>, is the
/// plan hash the promote was reviewed at.</p>
ClassMethod Compose(pPromote As %Boolean, pNamespace As %String, pTarget As %String, pSpec As %String, pIncludeGenerated As %Boolean, pNames As %List, pPlan As %DynamicObject, pReviewed As %String, pPlanHash As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Kill tChange
        Set tIterator = pPlan.%Get("steps").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            Set tChange(tStep.%Get("Document")) = tStep.%Get("Change")
        }
        Set tMissing = ""
        For tI = 1:1:$ListLength(pNames) {
            If '$Data(tChange($List(pNames, tI))) {
                Set tMissing = $List(pNames, tI)
                Quit
            }
        }
        If tMissing '= "" {
            Set tSC = ..NotAStep(tMissing, .pHttpStatus, .pFault)
            Quit
        }
        Set tChosen = []
        Set tShown = []
        Set tIterator = pPlan.%Get("steps").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            If '$ListFind(pNames, tStep.%Get("Document")) Continue
            Do tChosen.%Push(tStep)
            Set tRow = {}
            Do tRow.%Set("Document", tStep.%Get("Document"), "string")
            Do tRow.%Set("Change", tStep.%Get("Change"), "string")
            Do tShown.%Push(tRow)
        }
        If pPromote {
            Set tExpected = $Select(pReviewed '= "": pReviewed, 1: pPlanHash)
            Set tSC = ..Promote(pNamespace, pTarget, tChosen, pPlan.%Get("planHash"), tExpected, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set pResult = {}
        Do pResult.%Set("Namespace", pNamespace, "string")
        Do pResult.%Set("Target", pTarget, "string")
        Do pResult.%Set("Spec", pSpec, "string")
        Do pResult.%Set("Generated", $Select(pIncludeGenerated: "yes", 1: "no"), "string")
        Do pResult.%Set("Steps", tShown)
        Do pResult.%Set("Warnings", pPlan.%Get("warnings").%Size(), "number")
        Do pResult.%Set("PlanHash", pPlan.%Get("planHash"), "string")
        Do pResult.%Set("Reviewed", "", "string")
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the plan failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Write the steps <var>pChosen</var>, the plan's <code>{Document, Change, Hash, OtherHash}</code> in <code>Document</code> order, from
/// <var>pNamespace</var> into <var>pTarget</var> (this class's header, the promote's third step on), answering
/// <code>{documents, lines, errors, stopped}</code> at 200 in <var>pResult</var>. <var>pPlanHash</var> is the plan hash
/// derived now and <var>pReviewed</var> the one the caller reviewed.</p>
ClassMethod Promote(pNamespace As %String, pTarget As %String, pChosen As %DynamicArray, pPlanHash As %String, pReviewed As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Kill ^||OcuPilotDevToolPromote
    Try {
        Set tWritePairs = ##class(OcuPilot.Port.AtelierPort).WritePairs(pTarget)
        If tWritePairs = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.AtelierPort).#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
            Quit
        }
        Set tFailedPair = ""
        If '$ClassMethod(..GateClass(), "EvaluateRequired", tWritePairs, .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        If (pReviewed = "") || (pReviewed '= pPlanHash) {
            Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ..#CODESTALE, ..#REASONSTALE, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Preflight(pNamespace, pTarget, pChosen, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        Set tDocuments = []
        Set tLines = []
        Set tErrors = 0
        Set tStopped = 0
        Set tReplaced = 0
        Set tAdded = 0
        Set tWritten = []
        Set tClasses = ""
        Set tRoutines = ""
        For tI = 1:1:pChosen.%Size() {
            Set tStep = pChosen.%Get(tI - 1)
            Set tName = tStep.%Get("Document")
            Set tReplaces = (tStep.%Get("Change") = ..#CHANGEDIFFERS)
            Set tDocument = {}
            Do tDocument.%Set("Document", tName, "string")
            Do tDocument.%Set("Reason", "", "string")
            If tStopped {
                Do tDocument.%Set("Outcome", ..#OUTCOMENOTATTEMPTED, "string")
                Do tDocuments.%Push(tDocument)
                Continue
            }
            Kill tQuery
            Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMESPACEKEY) = pTarget
            Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMESKEY) = tName
            Set tQuery(##class(OcuPilot.Port.AtelierPort).#CONTENTKEY) = ^||OcuPilotDevToolPromote(tI, "text")
            Set tQuery(##class(OcuPilot.Port.AtelierPort).#COMPILEKEY) = 0
            If tReplaces Set tQuery(##class(OcuPilot.Port.AtelierPort).#VERSIONKEY) = ^||OcuPilotDevToolPromote(tI, "version")
            Set tWriteSC = $ClassMethod(..AtelierPortClass(), "Invoke", ..EndpointOf(tName), $Select(tReplaces: ##class(OcuPilot.Port.AtelierPort).#TYPESAVE, 1: ##class(OcuPilot.Port.AtelierPort).#TYPECREATE), .tQuery, "", .tWriteResult, .tWriteHttp, .tWriteFault)
            Kill tQuery
            If $$$ISERR(tWriteSC) {
                Set tStopped = 1
                Do tDocument.%Set("Outcome", ..#OUTCOMEFAILED, "string")
                Do tDocument.%Set("Reason", $Select($IsObject($Get(tWriteFault)) && (tWriteFault.%Get("reason") '= ""): tWriteFault.%Get("reason"), 1: ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON), "string")
                Do tDocuments.%Push(tDocument)
                Continue
            }
            Do tDocument.%Set("Outcome", $Select(tReplaces: ..#OUTCOMEREPLACED, 1: ..#OUTCOMEADDED), "string")
            Do tDocuments.%Push(tDocument)
            Do tWritten.%Push(tName, "string")
            If tReplaces {
                Set tReplaced = tReplaced + 1
            } Else {
                Set tAdded = tAdded + 1
            }
            If ..Extension(tName) = "cls" {
                Set tClasses = tClasses _ $Select(tClasses = "": "", 1: ",") _ tName
            } ElseIf ..Extension(tName) '= "inc" {
                Set tRoutines = tRoutines _ $Select(tRoutines = "": "", 1: ",") _ tName
            }
        }
        Kill ^||OcuPilotDevToolPromote

        If 'tStopped {
            For tKind = 1, 2 {
                Set tNames = $Select(tKind = 1: tClasses, 1: tRoutines)
                If tNames = "" Continue
                Kill tQuery
                Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMESPACEKEY) = pTarget
                Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMESKEY) = tNames
                Set tQuery(##class(OcuPilot.Port.AtelierPort).#KEEPSOURCEKEY) = 1
                Set tQuery(##class(OcuPilot.Port.AtelierPort).#COMPILEDEPENDENTSKEY) = 0
                Set tQuery(##class(OcuPilot.Port.AtelierPort).#SKIPUPTODATEKEY) = 1
                Set tCompileSC = $ClassMethod(..AtelierPortClass(), "Invoke", $Select(tKind = 1: ##class(OcuPilot.Port.AtelierPort).#ENDPOINTCLASSES, 1: ##class(OcuPilot.Port.AtelierPort).#ENDPOINTROUTINES), ##class(OcuPilot.Port.AtelierPort).#TYPECOMPILE, .tQuery, "", .tCompiled, .tCompileHttp, .tCompileFault)
                Kill tQuery
                If $$$ISERR(tCompileSC) {
                    Set tErrors = 1
                    Do tLines.%Push($Select($IsObject($Get(tCompileFault)) && (tCompileFault.%Get("reason") '= ""): tCompileFault.%Get("reason"), 1: ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON), "string")
                    Continue
                }
                If $IsObject(tCompiled) {
                    Set tCompiledIterator = tCompiled.%Get("lines").%GetIterator()
                    While tCompiledIterator.%GetNext(.tLineIndex, .tLine) {
                        Do tLines.%Push(tLine, "string")
                    }
                    If tCompiled.%Get("errors") Set tErrors = 1
                }
            }
        }

        If (tReplaced + tAdded) > 0 Do ..Audit(pNamespace, pTarget, tReplaced, tAdded, tStopped, tWritten)
        Set pResult = {}
        Do pResult.%Set("documents", tDocuments)
        Do pResult.%Set("lines", tLines)
        Do pResult.%Set("errors", ''tErrors, "boolean")
        Do pResult.%Set("stopped", ''tStopped, "boolean")
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the promote failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Kill ^||OcuPilotDevToolPromote
    Quit tSC
}

/// <p>Read every chosen step's text before anything is written, into <code>^||OcuPilotDevToolPromote</code>: the
/// document's text in <var>pNamespace</var> and, for a step that replaces a document, the version of its copy in
/// <var>pTarget</var>. Each text is read as the plan's hash read it (<method>ReadSource</method>) and must hash to the
/// plan's, the source's to <code>Hash</code> and the other copy's to <code>OtherHash</code>, and the other copy's version
/// must be read, else the promote is 409 <parameter>CODESTALE</parameter>, so what is written is what the plan showed and
/// no save is sent without its version. A text that cannot be read is 500 <code>INTERNAL</code>, logged. A document the instance keeps no source
/// for is 404 <code>PORT.NOTFOUND</code>; a text longer than one save takes is 400
/// <parameter>OcuPilot.Api.AtelierError.SAVETOOLARGE</parameter>; a text whose first line does not name its document is 422
/// <parameter>OcuPilot.Api.AtelierError.SAVEHEADER</parameter>; each with <code>detail.document</code>. Then the storage
/// guard: a class whose copy in <var>pTarget</var> has a <code>Storage</code> definition its text in
/// <var>pNamespace</var> lacks is 409 <parameter>CODESTORAGE</parameter>.</p>
ClassMethod Preflight(pNamespace As %String, pTarget As %String, pChosen As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    For tI = 1:1:pChosen.%Size() {
        Set tStep = pChosen.%Get(tI - 1)
        Set tName = tStep.%Get("Document")
        Set tDetail = {}
        Do tDetail.%Set("document", tName, "string")
        Set tSC = ..ReadSource(pNamespace, tName, .tText, .tHash, .tAvailable)
        If $$$ISERR(tSC) {
            Set tSC = ..Fail("the promote could not read a document's text", tSC, .pHttpStatus, .pFault)
            Quit
        }
        If 'tAvailable {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ##class(OcuPilot.Port.AtelierPort).#REASONNOSOURCE, .pHttpStatus, .pFault, tDetail)
            Quit
        }
        If tHash '= tStep.%Get("Hash") {
            Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ..#CODESTALE, ..#REASONSTALE, .pHttpStatus, .pFault, tDetail)
            Quit
        }
        If $Length(tText) > ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AtelierError).#SAVETOOLARGE, ##class(OcuPilot.Api.AtelierError).#REASONSAVETOOLARGE, .pHttpStatus, .pFault, tDetail)
            Quit
        }
        If ##class(OcuPilot.Port.AtelierPort).Header(##class(OcuPilot.Port.AtelierPort).SavedLines(tText)) '= tName {
            Set tSC = ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AtelierError).#SAVEHEADER, ##class(OcuPilot.Api.AtelierError).#REASONSAVEHEADER, .pHttpStatus, .pFault, tDetail)
            Quit
        }
        Set ^||OcuPilotDevToolPromote(tI, "text") = tText
        Set ^||OcuPilotDevToolPromote(tI, "storage") = ..StorageNames(tText)
        If tStep.%Get("Change") '= ..#CHANGEDIFFERS Continue
        Set tSC = ..ReadSource(pTarget, tName, .tOtherText, .tOtherHash, .tOtherAvailable)
        If $$$ISERR(tSC) {
            Set tSC = ..Fail("the promote could not read a document's text", tSC, .pHttpStatus, .pFault)
            Quit
        }
        If 'tOtherAvailable {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ##class(OcuPilot.Port.AtelierPort).#REASONNOSOURCE, .pHttpStatus, .pFault, tDetail)
            Quit
        }
        If tOtherHash '= tStep.%Get("OtherHash") {
            Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ..#CODESTALE, ..#REASONSTALE, .pHttpStatus, .pFault, tDetail)
            Quit
        }
        Set tSC = ..ReadVersion(pTarget, tName, .tVersion, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If tVersion = "" {
            Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ..#CODESTALE, ..#REASONSTALE, .pHttpStatus, .pFault, tDetail)
            Quit
        }
        Set ^||OcuPilotDevToolPromote(tI, "version") = tVersion
        Set ^||OcuPilotDevToolPromote(tI, "otherStorage") = ..StorageNames(tOtherText)
    }
    If $$$ISERR(tSC) Quit tSC
    Set tLost = ""
    For tI = 1:1:pChosen.%Size() {
        Set tOther = $Get(^||OcuPilotDevToolPromote(tI, "otherStorage"))
        Set tOwn = $Get(^||OcuPilotDevToolPromote(tI, "storage"))
        For tJ = 1:1:$ListLength(tOther) {
            If '$ListFind(tOwn, $List(tOther, tJ)) Set tLost = pChosen.%Get(tI - 1).%Get("Document")
            If tLost '= "" Quit
        }
        If tLost '= "" Quit
    }
    If tLost = "" Quit tSC
    Set tDetail = {}
    Do tDetail.%Set("document", tLost, "string")
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ..#CODESTORAGE, ..#REASONSTORAGE, .pHttpStatus, .pFault, tDetail)
}

/// <p>The text of the document <var>pName</var> in <var>pNamespace</var> exactly as the hash body reads it for a plan:
/// a class through <code>%Compiler.UDL.TextServices</code>, a routine, include file or generated routine through
/// <code>%Routine</code> with the header line the source code API writes
/// (<method>OcuPilot.Kernel.Utils.DocumentLines</method>). <var>pText</var> is its lines joined by line feeds,
/// <var>pHash</var> the SHA-256 in upper case hex of the lines each followed by a line feed, which is the plan's
/// <code>Hash</code>, and <var>pAvailable</var> 0 for a document the instance does not hold or keeps no source for.
/// The source code API's own document read is not used: after the hash bodies have run in two namespaces its first read
/// of the first namespace can answer the other namespace's text. Only system classes run while the namespace is
/// switched, and it is restored first in the <code>Catch</code>.</p>
ClassMethod ReadSource(pNamespace As %String, pName As %String, Output pText As %String, Output pHash As %String, Output pAvailable As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pText = ""
    Set pHash = ""
    Set pAvailable = 0
    Kill tLines
    Set tLines(0) = 0
    Set tIsClass = (..Extension(pName) = "cls")
    Set tExt = ..Extension(pName)
    Set tHeader = "ROUTINE " _ $Piece(pName, ".", 1, $Length(pName, ".") - 1)
    Set tOrigNS = $NAMESPACE
    Try {
        If tIsClass {
            Kill tLines
            Set tReadSC = ##class(%Compiler.UDL.TextServices).GetTextAsArray(pNamespace, pName, .tLines)
            If $$$ISERR(tReadSC) Quit
            Set pAvailable = 1
        } Else {
            Set $NAMESPACE = pNamespace
            Set tRoutine = $Select(##class(%Routine).Exists(pName): ##class(%Routine).%OpenId(pName), 1: "")
            If $IsObject(tRoutine) {
                Set tAttributes = $Select(tExt = "mac": "", 1: "Type=" _ $ZConvert(tExt, "U"))
                If tRoutine.Generated Set tAttributes = tAttributes _ $Select(tAttributes = "": "", 1: ",") _ "Generated"
                Set tLines(1) = tHeader _ $Select(tAttributes = "": "", 1: " [" _ tAttributes _ "]")
                Set tLines(0) = 1
                Do tRoutine.Rewind()
                While 'tRoutine.AtEnd {
                    Set tLength = 3641144
                    Set tLine = tRoutine.ReadLine(.tLength, .tLineSC)
                    If $$$ISERR(tLineSC) {
                        Set tSC = tLineSC
                        Quit
                    }
                    Set tLines(0) = tLines(0) + 1
                    Set tLines(tLines(0)) = tLine
                }
                Set pAvailable = $$$ISOK(tSC)
            }
            Set tRoutine = ""
            Set $NAMESPACE = tOrigNS
        }
        If 'pAvailable Quit
        Set tHashText = ""
        For tI = 1:1:+$Get(tLines(0)) {
            Set pText = pText _ $Select(tI > 1: $Char(10), 1: "") _ $Get(tLines(tI))
            Set tHashText = tHashText _ $Get(tLines(tI)) _ $Char(10)
        }
        Set pHash = $System.Encryption.ToHex($System.Encryption.SHAHash(256, tHashText))
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The version a save of the document <var>pName</var> in <var>pNamespace</var> is made against: the
/// <code>modified</code> the source code API's document read answers.</p>
ClassMethod ReadVersion(pNamespace As %String, pName As %String, Output pVersion As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pVersion = ""
    Kill tQuery
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMESPACEKEY) = pNamespace
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#NAMEKEY) = pName
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#FORMKEY) = "udl"
    Set tQuery(##class(OcuPilot.Port.AtelierPort).#MAXROWSKEY) = 1
    Set tSC = $ClassMethod(..AtelierPortClass(), "Invoke", $Select(..Extension(pName) = "cls": ##class(OcuPilot.Port.AtelierPort).#ENDPOINTCLASS, 1: ##class(OcuPilot.Port.AtelierPort).#ENDPOINTROUTINE), ..#TYPELIST, .tQuery, "", .tRows, .pHttpStatus, .pFault, .tDocument)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject($Get(tDocument)) Set pVersion = tDocument.%Get("modified")
    Quit tSC
}

/// <p>The names of the <code>Storage</code> definitions the UDL text <var>pText</var> holds, as a <class>%List</class>: the
/// word after <code>Storage</code> on each line that begins with it.</p>
ClassMethod StorageNames(pText As %String) As %List [ Private ]
{
    Set tNames = ""
    For tI = 1:1:$Length(pText, $Char(10)) {
        Set tLine = $Piece(pText, $Char(10), tI)
        If $Extract(tLine, 1, 8) '= "Storage " Continue
        Set tName = $ZStrip($Piece($ZStrip($Extract(tLine, 9, *), "<>W"), "{", 1), "<>W")
        If (tName '= "") && '$ListFind(tNames, tName) Set tNames = tNames _ $ListBuild(tName)
    }
    Quit tNames
}

/// <p>The extension of the document <var>pName</var>, in lower case.</p>
ClassMethod Extension(pName As %String) As %String [ Private ]
{
    Quit $ZConvert($Piece(pName, ".", $Length(pName, ".")), "L")
}

/// <p>The endpoint of <class>OcuPilot.Port.AtelierPort</class> that serves the document <var>pName</var>'s kind in a set:
/// the classes' for a class, the routines' for any other.</p>
ClassMethod EndpointOf(pName As %String) As %String [ Private ]
{
    Quit $Select(..Extension(pName) = "cls": ##class(OcuPilot.Port.AtelierPort).#ENDPOINTCLASSES, 1: ##class(OcuPilot.Port.AtelierPort).#ENDPOINTROUTINES)
}

/// <p>Record OcuPilot's own <code>ConfigChange</code> row for a promote that wrote at least one document (AD-15), from
/// whichever caller made it: the instance audits neither a document save nor a compile. The row names the other
/// namespace as its target and, as effects, the first namespace, the counts and the documents written, never a text. It
/// never fails the write: a row that cannot be recorded is logged.</p>
ClassMethod Audit(pNamespace As %String, pTarget As %String, pReplaced As %Integer, pAdded As %Integer, pStopped As %Boolean, pWritten As %DynamicArray) [ Private ]
{
    Try {
        Set tEffects = {}
        Do tEffects.%Set("source", pNamespace, "string")
        Do tEffects.%Set("replaced", pReplaced, "number")
        Do tEffects.%Set("added", pAdded, "number")
        Do tEffects.%Set("stopped", ''pStopped, "boolean")
        Do tEffects.%Set("documents", pWritten)
        Set tSC = ##class(OcuPilot.Kernel.Audit.Event).Record("promote", "namespace", pTarget, {}, 0, tEffects)
        If $$$ISERR(tSC) Do ..LogFault("the promote could not be audited", tSC)
    } Catch ex {
        Do ..LogFault("the promote could not be audited", ex.AsStatus())
    }
}

/// <p><code>objectscript</code> for a namespace diff's <parameter>TYPEPROMOTE</parameter>; <code>""</code> for every
/// other request, which has no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint = ..#ENDPOINTNAMESPACEDIFF) && (pType = ..#TYPEPROMOTE) Quit "objectscript"
    Quit ""
}

/// <p>A promote as a script (AD-59), mirroring <method>Promote</method>'s writes: a first line that starts the script as
/// succeeding, then one line for each document of <parameter>DOCUMENTSKEY</parameter>, in the order its names sort in, that
/// copies the document's text from the namespace <parameter>NAMESPACEKEY</parameter> names to the one
/// <parameter>TARGETKEY</parameter> names, then one <code>$System.OBJ.CompileList</code> with
/// <parameter>OcuPilot.Port.AtelierPort.IMPORTCOMPILEFLAGS</parameter> for the classes and one for the routines, in the
/// other namespace. A class is copied with <code>%Compiler.UDL.TextServices</code>, a routine line by line with
/// <code>%Routine</code>; a routine the first namespace does not hold is reported and nothing is written over its copy.
/// A document the stored payload's <code>Steps</code> (<var>pContext</var><code>.payload</code>) lists as only in the
/// first namespace is a create, written only while its name is free in the other namespace (<method>FreeCheck</method>).
/// As the write does, the script stops at the first copy that fails or is refused, and compiles only when every copy
/// succeeded. Every value is rendered as a string literal, so nothing the query carries runs as code, and no line opens a
/// block it does not close, so the script runs the same as a method body and pasted line by line into a terminal. It
/// copies what the namespace holds when it runs, and it does not check the plan. A script longer than
/// <parameter>OcuPilot.Port.AtelierPort.SNIPPETMAXCHARACTERS</parameter> answers no step.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tSource = $Get(pQuery(..#NAMESPACEKEY))
    Set tTarget = $Get(pQuery(..#TARGETKEY))
    Kill tCreate
    If $IsObject(pContext) && (pContext.%GetTypeOf("payload") = "object") && (pContext.%Get("payload").%GetTypeOf("Steps") = "array") {
        Set tIterator = pContext.%Get("payload").%Get("Steps").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tPlanned) {
            If $IsObject(tPlanned) && (tPlanned.%Get("Change") = ..#CHANGEONLYHERE) Set tCreate("n" _ tPlanned.%Get("Document")) = ""
        }
    }
    Kill tSorted
    For tI = 1:1:$Length($Get(pQuery(..#DOCUMENTSKEY)), ",") {
        Set tName = $Piece($Get(pQuery(..#DOCUMENTSKEY)), ",", tI)
        If tName '= "" Set tSorted("n" _ tName) = tName
    }
    Set tText = ""
    Set tClasses = ""
    Set tRoutines = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey), 1, tName)
        If tKey = "" Quit
        Set tTaken = " Set tOK = 0 Do $System.Status.DisplayError($System.Status.Error(5001, " _ ..Literal(tName _ " is taken: this namespace holds it or another document of its name, so nothing was created.") _ "))"
        If ..Extension(tName) = "cls" {
            Set tBase = $Extract(tName, 1, *-4)
            Set tCopy = "Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString(" _ ..Literal(tSource) _ ", " _ ..Literal(tBase) _ ", .tText) Set:$System.Status.IsOK(tSC) tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(" _ ..Literal(tTarget) _ ", " _ ..Literal(tBase) _ ", tText) Set tOK = $System.Status.IsOK(tSC) Do $System.Status.DisplayError(tSC)"
            If $Data(tCreate(tKey)) {
                Set tText = tText _ $Char(10) _ " If tOK { Set $NAMESPACE = " _ ..Literal(tTarget) _ " If '(" _ ..FreeCheck(tName) _ ") {" _ tTaken _ " } Else { " _ tCopy _ " } }"
            } Else {
                Set tText = tText _ $Char(10) _ " If tOK { " _ tCopy _ " }"
            }
            Set tClasses = tClasses _ $Select(tClasses = "": "", 1: ",") _ tName
        } Else {
            Set tStepLine = " If tOK { Set $NAMESPACE = " _ ..Literal(tSource) _ " Kill tLine Set tFound = ##class(%Routine).Exists(" _ ..Literal(tName) _ ") Set tRead = $Select(tFound: ##class(%Routine).%OpenId(" _ ..Literal(tName) _ "), 1: """") If tFound { Do tRead.Rewind() While 'tRead.AtEnd { Set tLength = 3641144 Set tRow = tRead.ReadLine(.tLength) Set tLine($Increment(tLine)) = tRow } } Set tRead = """" Set $NAMESPACE = " _ ..Literal(tTarget)
            Set tStepLine = tStepLine _ " If 'tFound { Set tOK = 0 Do $System.Status.DisplayError($System.Status.Error(5001, " _ ..Literal(tName _ ": " _ ##class(OcuPilot.Port.AtelierPort).#REASONNOSOURCE) _ ")) }"
            If $Data(tCreate(tKey)) Set tStepLine = tStepLine _ " If tFound, '(" _ ..FreeCheck(tName) _ ") {" _ tTaken _ " }"
            Set tStepLine = tStepLine _ " If tOK { Set tWrite = ##class(%Routine).%New(" _ ..Literal(tName) _ ") Do tWrite.Clear() For tI = 1:1:$Get(tLine) { Do tWrite.WriteLine(tLine(tI)) } Set tSC = tWrite.Save() Set tOK = $System.Status.IsOK(tSC) Do $System.Status.DisplayError(tSC) } }"
            Set tText = tText _ $Char(10) _ tStepLine
            If ..Extension(tName) '= "inc" Set tRoutines = tRoutines _ $Select(tRoutines = "": "", 1: ",") _ tName
        }
        If $Length(tText) > ##class(OcuPilot.Port.AtelierPort).#SNIPPETMAXCHARACTERS Quit
    }
    If tText = "" Quit []
    Set tText = " Set tOK = 1" _ tText
    For tNames = tClasses, tRoutines {
        If tNames = "" Continue
        Set tText = tText _ $Char(10) _ " If tOK { Set $NAMESPACE = " _ ..Literal(tTarget) _ " Set tSC = $System.OBJ.CompileList(" _ ..Literal(tNames) _ ", " _ ..Literal(##class(OcuPilot.Port.AtelierPort).#IMPORTCOMPILEFLAGS) _ ") Do $System.Status.DisplayError(tSC) }"
    }
    If $Length(tText) > ##class(OcuPilot.Port.AtelierPort).#SNIPPETMAXCHARACTERS Quit []
    Set tStep = {}
    Do tStep.%Set("kind", "objectscript", "string")
    Do tStep.%Set("text", tText, "string")
    Quit [(tStep)]
}

/// <p>The expression a create's script line reads as true while nothing in the current namespace holds a document that
/// takes <var>pName</var>: the taken-name rule <class>OcuPilot.Port.AtelierPort</class>'s create applies, rendered as its
/// own create script renders it. For a class, no class of that name in any letter case; for an include file, no document
/// of exactly that name; for a routine or intermediate routine, no routine of its base name of a type in
/// <parameter>OcuPilot.Port.AtelierPort.TAKINGROUTINETYPES</parameter>.</p>
ClassMethod FreeCheck(pName As %String) As %String [ Private ]
{
    Set tBase = $Piece(pName, ".", 1, $Length(pName, ".") - 1)
    If ..Extension(pName) = "cls" Quit "'$Data(^rINDEXCLASS(" _ ..Literal($ZConvert(tBase, "U")) _ "))"
    If ..Extension(pName) = "inc" Quit "'##class(%RoutineMgr).Exists(" _ ..Literal(pName) _ ")"
    Set tTypes = ##class(OcuPilot.Port.AtelierPort).#TAKINGROUTINETYPES
    Set tCheck = ""
    For tI = 1:1:$Length(tTypes, ",") {
        Set tCheck = tCheck _ $Select(tCheck = "": "", 1: " || ") _ "##class(%RoutineMgr).Exists(" _ ..Literal(tBase _ "." _ $Piece(tTypes, ",", tI)) _ ")"
    }
    Quit "'(" _ tCheck _ ")"
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
