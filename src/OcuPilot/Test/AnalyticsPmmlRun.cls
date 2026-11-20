/// <p>Pins Story 24.14 Batch 2's PMML test (AD-7, AD-41, AD-42, AD-65), against <code>USER</code> and the definition of <class>OcuPilot.Test.PmmlProbe</class>: the three routes
/// <code>/analytics/pmml/background</code> (start, poll, cancel) run a model against each of its three sources, a declared SQL data source, its verification records and one custom SQL query, and the answer is the
/// one the vendor's own run computes for the same source (the record count, the metrics, the per-value counts and each record's actual and predicted value, or sigma, RSE and R squared for a continuous model); and
/// after every run, whatever its end, the vendor's shared result table holds no row for its test id. The expected answer is computed here from the rows the vendor's own call wrote, by arithmetic of its own, and
/// the vendor's call is made in <code>USER</code> by this class, not by the port.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the probes turn analytics on for <code>USER</code> and write cubes and classes there. Every run a
/// test starts has ended, and every run row and result row it made is removed, before the test returns.</p>
Class OcuPilot.Test.AnalyticsPmmlRun Extends %UnitTest.TestCase [ DependsOn = (OcuPilot.Test.AnalyticsProbe, OcuPilot.Test.PmmlProbe) ]
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PMML = "OcuPilot.Test.PmmlProbe";

Parameter STORE = "OcuPilot.Kernel.State.SqlRun";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter START = "/api/ocupilot/analytics/pmml/background";

Parameter POLL = "/api/ocupilot/analytics/pmml/background/:id";

Parameter NAMESPACE = "USER";

Parameter DEFINITION = {##class(OcuPilot.Test.PmmlProbe).#DEFINITIONCLASS};

/// <p>The custom query: the source rows below 8, so the run differs from the data source's, which reads all twelve.</p>
Parameter CUSTOM = "SELECT ID, X, Color, Y FROM ProbePmml.Source WHERE X < 8";

Parameter CANCEL = "/api/ocupilot/analytics/pmml/background/:id/cancel";

/// <p>The content type of the last response <method>Send</method> read.</p>
Property PreparedType As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedType = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPmmlRun turns analytics on in USER and compiles classes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set tSC = $ClassMethod(..#PMML, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $Username)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PMML, "Create")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit ..Settle()
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ..Settle()
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PMML, "Remove"))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove"))
    If $$$ISOK(tSC) && ('$ClassMethod(..#PMML, "Gone") || '$ClassMethod(..#PROBE, "Gone")) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPmmlRun left probe state in USER: " _ $ClassMethod(..#PMML, "Left") _ " " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>Stop every live PMML run of the suite's account, wait up to 20 seconds for each to end, then remove every row of the account's; an error when a run is still live.</p>
Method Settle() As %Status
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tDeadline = $ZHorolog + 20
    For {
        Set tLive = 0
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(UserName), RunKey FROM OcuPilot_Kernel_State.SqlRun WHERE State IN ('queued', 'running') AND COALESCE(Kind, 'sql') = 'pmml'")
        While tResult.%Next() {
            If tResult.%GetData(1) '= tUser Continue
            Set tLive = tLive + 1
            Do ##class(OcuPilot.Area.Analytics.PmmlTest).Cancel(tResult.%GetData(2), tResult.%GetData(1), .tFound)
        }
        If (tLive = 0) || ($ZHorolog > tDeadline) Quit
        Hang 0.5
        Do $ClassMethod(..#STORE, "GuardedSweep", ..#LIMITS)
    }
    Do $ClassMethod(..#STORE, "GuardedForgetUser", tUser)
    If tLive Quit $$$ERROR($$$GeneralError, "a PMML run of this class was still live after 20 seconds")
    Quit $$$OK
}

/// <p>Send <var>pMethod</var> <var>pPath</var> (an absolute path, in <code>USER</code>) as the suite's account, with <var>pBody</var> when it is given; the status, the parsed answer.</p>
Method Send(pMethod As %String, pPath As %String, Output pStatus As %Integer, Output pAnswer, pBody = "")
{
    Set tText = $Select($IsObject(pBody): pBody.%ToJSON(), 1: pBody)
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ ..#NAMESPACE, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders, tText, "application/json")
    Set ..PreparedType = $Piece($Get(tHeaders("CONTENT-TYPE")), ";", 1)
    Set pAnswer = ""
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    } Catch {
        Set pAnswer = $Get(tRaw)
    }
}

/// <p>Start <var>pBody</var>, expect 202 and poll the run until it no longer reads running (or for <var>pSeconds</var>); the last answer, or the start's own when it was not accepted.</p>
Method RunToEnd(pBody As %DynamicObject, Output pStatus As %Integer, pSeconds As %Numeric = 60) As %DynamicObject
{
    Do ..Send("POST", ..#START, .pStatus, .tAnswer, pBody)
    If pStatus '= 202 Quit $Select($IsObject(tAnswer): tAnswer, 1: {"error": (tAnswer)})
    Set tKey = tAnswer.%Get("id")
    Set tDeadline = $ZHorolog + pSeconds
    For {
        Do ..Send("GET", $Replace(..#POLL, ":id", tKey), .tStatus, .tAnswer)
        If '$IsObject(tAnswer) || (tAnswer.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Quit tAnswer
}

/// <p>The vendor's test-id counter, which each run advances by one.</p>
ClassMethod Counter() As %Integer
{
    Quit +$Get(^IRIS.Temp.DeepSee.PMML.ResultI("TestIdx"))
}

/// <p>The answer the vendor's own run computes for the model <var>pModel</var> of the probe's definition against <var>pSource</var> (<code>dataset</code>, <code>verification</code> or <code>custom</code> with
/// <var>pSQL</var>), in <code>USER</code>: this class calls the vendor's run, reads the (actual, predicted) pairs it wrote, computes the metrics by arithmetic of its own, and drops the rows. A
/// <code>%DynamicObject</code> in the port's answer shape, or <code>{error}</code>.</p>
ClassMethod Oracle(pModel As %String, pSource As %String, pSQL As %String = "") As %DynamicObject
{
    Set tOrigNS = $NAMESPACE
    Set tAnswer = {}
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tId = ""
        If pSource = "verification" {
            Set tSC = ##class(%DeepSee.PMML.Utils).%RunModelFromPMMLRows(.tId, ..#DEFINITION, pModel, , 0)
        } ElseIf pSource = "custom" {
            Set tSC = ##class(%DeepSee.PMML.Utils).%RunModelFromSQL(.tId, ..#DEFINITION, pModel, pSQL, , , , 0)
        } Else {
            Set tSC = ##class(%DeepSee.PMML.Utils).%RunModel(.tId, ..#DEFINITION, pModel, "Rows", , 0)
        }
        If $$$ISERR(tSC) Set tAnswer = {"error": ($System.Status.GetErrorText(tSC))}
        If $$$ISOK(tSC) {
            Set tModelClass = $ClassMethod(..#DEFINITION, "%GetModelClassName", pModel)
            Do $ClassMethod(tModelClass, "%GetPredictedFieldInfo", .tField, .tDataType, .tOpType)
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TestRecordId, ActualValue, PredictedValue FROM %DeepSee_PMML_Utils.TempResult WHERE TestId = ? ORDER BY %ID", tId)
            Kill tActual, tPredicted, tRecord
            Set tN = 0
            While tRS.%Next() {
                Set tN = tN + 1
                Set tRecord(tN) = tRS.%GetData(1)
                Set tActual(tN) = tRS.%GetData(2)
                Set tPredicted(tN) = tRS.%GetData(3)
            }
            Set tAnswer = ..Arithmetic(tOpType, tN, .tRecord, .tActual, .tPredicted)
        }
        Do ##class(%DeepSee.PMML.Utils).%DropResults(tId)
    } Catch ex {
        Set tAnswer = {"error": (ex.DisplayString())}
    }
    Set $NAMESPACE = tOrigNS
    Quit tAnswer
}

/// <p>The answer for <var>pN</var> records of operational type <var>pMode</var>: counts, metrics and rows from the actual and predicted values alone.</p>
ClassMethod Arithmetic(pMode As %String, pN As %Integer, ByRef pRecord, ByRef pActual, ByRef pPredicted) As %DynamicObject
{
    Set tAnswer = {}
    Do tAnswer.%Set("outcome", "ran", "string")
    Do tAnswer.%Set("mode", pMode, "string")
    Do tAnswer.%Set("records", pN, "number")
    Set tValues = []
    If pMode = "continuous" {
        Set tSum = 0
        For tI = 1:1:pN Set tSum = tSum + pActual(tI)
        Set tMean = $Select(pN: tSum / pN, 1: 0)
        Set (tSquares, tSpread) = 0
        For tI = 1:1:pN {
            Set tSquares = tSquares + ((pActual(tI) - pPredicted(tI)) ** 2)
            Set tSpread = tSpread + ((tMean - pActual(tI)) ** 2)
        }
        Set tRSE = $Select(tSpread: tSquares / tSpread, 1: 0)
        Do tAnswer.%Set("sigma", +$FNumber($ZSqr($Select(pN: tSquares / pN, 1: 0)), "", 2), "number")
        Do tAnswer.%Set("rse", +$FNumber(tRSE, "", 4), "number")
        Do tAnswer.%Set("rSquared", +$FNumber(1 - tRSE, "", 4), "number")
    } Else {
        Kill tSize, tTP, tFP, tFN
        For tI = 1:1:pN {
            Set tSize(pActual(tI)) = $Get(tSize(pActual(tI))) + 1
            If pPredicted(tI) = pActual(tI) {
                Set tTP(pActual(tI)) = $Get(tTP(pActual(tI))) + 1
            } Else {
                Set tFN(pActual(tI)) = $Get(tFN(pActual(tI))) + 1
                If pPredicted(tI) '= "" Set tFP(pPredicted(tI)) = $Get(tFP(pPredicted(tI))) + 1
            }
        }
        Set (tMacroP, tMacroR, tMicroP, tMicroR, tClasses) = 0
        Set tClass = ""
        For {
            Set tClass = $Order(tSize(tClass))
            If tClass = "" Quit
            Set tPrecision = 100 * $Get(tTP(tClass)) / $Select(($Get(tTP(tClass)) + $Get(tFP(tClass))) > 1: $Get(tTP(tClass)) + $Get(tFP(tClass)), 1: 1)
            Set tRecall = 100 * $Get(tTP(tClass)) / $Select(($Get(tTP(tClass)) + $Get(tFN(tClass))) > 1: $Get(tTP(tClass)) + $Get(tFN(tClass)), 1: 1)
            Set tClasses = tClasses + 1
            Set tMacroP = tMacroP + tPrecision
            Set tMacroR = tMacroR + tRecall
            Set tMicroP = tMicroP + (tPrecision * tSize(tClass))
            Set tMicroR = tMicroR + (tRecall * tSize(tClass))
            Set tValue = {}
            Do tValue.%Set("actual", tClass, "string")
            Do tValue.%Set("records", tSize(tClass), "number")
            Do tValue.%Set("correct", +$Get(tTP(tClass)), "number")
            Do tValue.%Set("incorrect", +$Get(tFN(tClass)), "number")
            Do tValues.%Push(tValue)
        }
        If tClasses {
            Set tMacroP = tMacroP / tClasses
            Set tMacroR = tMacroR / tClasses
            Set tMicroP = tMicroP / pN
            Set tMicroR = tMicroR / pN
        }
        Do tAnswer.%Set("precision", {"micro": (+$FNumber(tMicroP, "", 2)), "macro": (+$FNumber(tMacroP, "", 2))})
        Do tAnswer.%Set("recall", {"micro": (+$FNumber(tMicroR, "", 2)), "macro": (+$FNumber(tMacroR, "", 2))})
        Set tMicroF = $Select((tMicroP + tMicroR): 2 * tMicroP * tMicroR / (tMicroP + tMicroR), 1: 0)
        Set tMacroF = $Select((tMacroP + tMacroR): 2 * tMacroP * tMacroR / (tMacroP + tMacroR), 1: 0)
        Do tAnswer.%Set("fMeasure", {"micro": (+$FNumber(tMicroF, "", 2)), "macro": (+$FNumber(tMacroF, "", 2))})
    }
    Do tAnswer.%Set("values", tValues)
    Set tRows = []
    For tI = 1:1:pN {
        Set tRow = {}
        Do tRow.%Set("record", pRecord(tI), "string")
        Do tRow.%Set("actual", pActual(tI), "string")
        Do tRow.%Set("predicted", pPredicted(tI), "string")
        Do tRow.%Set("probability", "", "null")
        Do tRows.%Push(tRow)
    }
    Do tAnswer.%Set("rows", tRows)
    Do tAnswer.%Set("truncated", 0, "boolean")
    Quit tAnswer
}

/// <p>AC2 and AC3 (Integration, Rule 1): a person runs each model against each of its three sources and the answer is the one the vendor's own run computes for the same source: the same count, metrics,
/// per-value counts and records. The first run's numbers are pinned as well: the tree misclassifies two of the twelve rows, so against them its micro precision is 87.5 and its micro recall 83.33. Every
/// run advances the vendor's test-id counter by one, and neither that id nor any other holds a result row afterwards.</p>
/// <p>Mutation (Rule 19): read <code>ActualValue</code> in place of <code>PredictedValue</code> for the <code>rows</code> in <method>OcuPilot.Port.AnalyticsPort.PmmlAnswer</method> -- the rows of every leg go red.</p>
Method TestEachModelRunsEachSourceToTheVendorsOwnAnswer()
{
    Set tPinned = 0
    For tCase = $ListBuild("Colors", "dataset"), $ListBuild("Colors", "verification"), $ListBuild("Colors", "custom"), $ListBuild("Heights", "dataset"), $ListBuild("Heights", "verification"), $ListBuild("Heights", "custom"), $ListBuild("Plain", "dataset") {
        Set tModel = $List(tCase, 1)
        Set tSource = $List(tCase, 2)
        Set tBody = {"model": (..#DEFINITION _ "||" _ tModel), "source": (tSource)}
        If tSource = "dataset" Do tBody.%Set("dataSource", "Rows")
        If tSource = "custom" Do tBody.%Set("sql", ..#CUSTOM)
        Set tBefore = ..Counter()
        Set tView = ..RunToEnd(tBody, .tStart)
        Set tAfter = ..Counter()
        Set tLabel = tModel _ " over " _ tSource
        Do $$$AssertEquals(tStart, 202, tLabel _ ": the start is accepted")
        Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status"), 1: ""), "ended", tLabel _ ": the run ends: " _ $Select($IsObject(tView): $Extract(tView.%ToJSON(), 1, 300), 1: tView))
        If '$IsObject(tView) || '$IsObject(tView.%Get("result")) Continue
        Set tExpected = ..Oracle(tModel, tSource, ..#CUSTOM)
        Do $$$AssertEquals(tView.result.%ToJSON(), tExpected.%ToJSON(), tLabel _ ": the answer is the vendor's own")
        Do $$$AssertEquals(tAfter - tBefore, 1, tLabel _ ": the run allocated one test id")
        Do $$$AssertEquals($ClassMethod(..#PMML, "RowsOf", tAfter) _ "|" _ $ClassMethod(..#PMML, "Rows"), "0|0", tLabel _ ": and no result row is left for it or for any model of the probe")
        If (tModel = "Colors") && (tSource = "dataset") {
            Set tPinned = 1
            Do $$$AssertEquals(tView.result.records _ "|" _ tView.result.precision.micro _ "|" _ tView.result.recall.micro _ "|" _ tView.result.fMeasure.micro, "12|87.5|83.33|85.37", "the tree's numbers over its twelve rows: two are misclassified")
        }
    }
    Do $$$AssertTrue(tPinned, "the pinned run ran")
}

/// <p>The three routes each answer one JSON envelope: the start 202 with the run's id and status, the poll 200 with the run, the cancel 200 with the run as it then reads (an ended run is answered as it
/// is), and an id no run holds is answered 404 <code>ANALYTICS.PMML.NOTFOUND</code> by the poll and the cancel alike, as JSON.</p>
/// <p>Mutation (Rule 19): drop the cancel route's delegation in <method>OcuPilot.Api.Router.AnalyticsPmmlBackgroundCancel</method> -- the cancel legs go red.</p>
Method TestTheThreeRoutesEachAnswerOneJsonEnvelope()
{
    Do ..Send("POST", ..#START, .tStatus, .tAnswer, {"model": (..#DEFINITION _ "||Colors"), "source": "verification"})
    Do $$$AssertEquals(tStatus _ " " _ ..PreparedType _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: ""), "202 application/json running", "the start answers 202 with the run's id and status as JSON")
    Set tKey = $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: "")
    Do $$$AssertTrue($Match(tKey, "^[0-9a-f]{32}$"), "the id is 32 hexadecimal characters: " _ tKey)
    Set tDeadline = $ZHorolog + 30
    For {
        Do ..Send("GET", $Replace(..#POLL, ":id", tKey), .tStatus, .tAnswer)
        If '$IsObject(tAnswer) || (tAnswer.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Do $$$AssertEquals(tStatus _ " " _ ..PreparedType _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: ""), "200 application/json ended", "the poll answers 200 with the ended run as JSON")
    Do ..Send("POST", $Replace(..#CANCEL, ":id", tKey), .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..PreparedType _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: ""), "200 application/json ended", "the cancel of an ended run answers it as it is, as JSON")
    Set tAbsent = "0123456789abcdef0123456789abcdef"
    Do ..Send("GET", $Replace(..#POLL, ":id", tAbsent), .tStatus, .tAnswer)
    Do $$$AssertEquals(..PreparedType _ " " _ tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "application/json 404 ANALYTICS.PMML.NOTFOUND", "a poll of an id no run holds is the 404 envelope")
    Do ..Send("POST", $Replace(..#CANCEL, ":id", tAbsent), .tStatus, .tAnswer)
    Do $$$AssertEquals(..PreparedType _ " " _ tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "application/json 404 ANALYTICS.PMML.NOTFOUND", "and so is a cancel of one")
}

/// <p>AC3: a run whose source the vendor refuses answers its error and leaves no result row either: a custom query that does not select the target field is the vendor's own error answer, with the vendor's text, cut at
/// <parameter>OcuPilot.Port.AnalyticsPort.MDXMAXCELL</parameter> characters, and the test id it allocated holds no row.</p>
/// <p>Mutation (Rule 19): skip the <method>OcuPilot.Port.AnalyticsPort.PmmlDrop</method> call in <method>OcuPilot.Port.AnalyticsPort.PmmlRun</method> -- the stopped and canceled legs of <class>OcuPilot.Test.AnalyticsPmmlRunEdge</class> go red; this leg, which wrote no row, stays green.</p>
Method TestARunTheVendorRefusesAnswersItsErrorAndLeavesNothing()
{
    Set tBefore = ..Counter()
    Set tView = ..RunToEnd({"model": (..#DEFINITION _ "||Colors"), "source": "custom", "sql": "SELECT ID, X FROM ProbePmml.Source"}, .tStart)
    Do $$$AssertEquals(tStart, 202, "the start is accepted: the vendor's error is the run's answer")
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status") _ " " _ tView.result.outcome, 1: ""), "ended error", "the run ends with an error answer")
    If '$IsObject(tView) || '$IsObject(tView.%Get("result")) Quit
    Do $$$AssertTrue($Length(tView.result.message) && ($Length(tView.result.message) <= ##class(OcuPilot.Port.AnalyticsPort).#MDXMAXCELL), "the vendor's text is the message, within the cut: " _ tView.result.message)
    Do $$$AssertEquals(..Counter() - tBefore _ "|" _ $ClassMethod(..#PMML, "RowsOf", ..Counter()) _ "|" _ $ClassMethod(..#PMML, "Rows"), "1|0|0", "the run allocated its id and left no row")
}

}
