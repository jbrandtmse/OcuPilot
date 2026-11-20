/// <p>Pins Story 24.14 Batch 2's two reads (AD-11, AD-29, AD-36, AD-60, AD-65) against <code>USER</code>, with analytics on and the PMML definition of <class>OcuPilot.Test.PmmlProbe</class> compiled there: the
/// <code>PmmlModels</code> and <code>PmmlModel</code> endpoints of <class>OcuPilot.Port.AnalyticsPort</class> answer the models the vendor's own calls report for the definition (<code>%GetModels</code>, the
/// model class's <code>%GetPredictedFieldInfo</code> and <code>%GetDefinition</code>, the definition's <code>%GetDefinition</code>), as the port's rows, the two screens' reads over HTTP and the agent's two
/// derived read tools; a model or class that is absent reads no row; no read makes a journaled write or touches the vendor's result rows; and the pairs and a namespace without analytics are refused before any vendor
/// call.</p>
/// <p>This class runs as the unit-test process, which holds <code>%All</code>; the pair refusal of the two endpoints is also pinned by <class>OcuPilot.Test.PortGate</class>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot serving over HTTP as <class>OcuPilot.Test.Http</class>'s account and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the probes
/// turn analytics on for <code>USER</code> and write cubes and classes there, all of which it removes after the last test.</p>
Class OcuPilot.Test.AnalyticsPmmlModels Extends %UnitTest.TestCase [ DependsOn = (OcuPilot.Test.AnalyticsProbe, OcuPilot.Test.PmmlProbe) ]
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PMML = "OcuPilot.Test.PmmlProbe";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter SEAM = "OcuPilot.Test.AnalyticsGateSeam";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter NAMESPACE = "USER";

Parameter MODELS = "analytics.pmmlmodels";

Parameter MODEL = "analytics.pmmlmodel";

Parameter DEFINITION = {##class(OcuPilot.Test.PmmlProbe).#DEFINITIONCLASS};

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPmmlModels turns analytics on in USER and compiles classes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set tSC = $ClassMethod(..#PMML, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $Username)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PMML, "Create")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PMML, "Remove")
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove"))
    If $$$ISOK(tSC) && ('$ClassMethod(..#PMML, "Gone") || '$ClassMethod(..#PROBE, "Gone")) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPmmlModels left probe state in USER: " _ $ClassMethod(..#PMML, "Left") _ " " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>The rows the vendor's own calls report for the probe's definition, read in <code>USER</code> by walking the definition's parsed models: the name, the model's type from <code>%GetModels</code>, the
/// target and its operational type from the model class, the data sources' names from the data dictionary's <code>isc:datasource</code> extensions, one per line, and whether the model's definition holds a
/// <code>ModelVerification</code>. A <code>%DynamicArray</code> of the port's row shape.</p>
ClassMethod Expected() As %DynamicArray
{
    Set tRows = []
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $ClassMethod(..#DEFINITION, "%GetModels", .tModels)
        Set tSC = $ClassMethod(..#DEFINITION, "%GetDefinition", .tPMML)
        Set tSources = ""
        For tI = 1:1:tPMML.DataDictionary.Extension.Count() {
            Set tExtension = tPMML.DataDictionary.Extension.GetAt(tI)
            If tExtension.name '= "isc:datasource" Continue
            For tJ = 1:1:tExtension.iscExtensions.Count() Set tSources = tSources _ $Select(tSources = "": "", 1: $Char(10)) _ tExtension.iscExtensions.GetAt(tJ).name
        }
        For tI = 1:1:tModels {
            Set tName = $List(tModels(tI), 1)
            Do $ClassMethod($List(tModels(tI), 2), "%GetPredictedFieldInfo", .tField, .tDataType, .tOpType)
            Set tVerification = 0
            For tK = 1:1:tPMML.Models.Count() {
                If tPMML.Models.GetAt(tK).modelName = tName Set tVerification = $IsObject(tPMML.Models.GetAt(tK).ModelVerification)
            }
            Set tRow = {}
            Do tRow.%Set("Class", ..#DEFINITION, "string")
            Do tRow.%Set("Model", tName, "string")
            Do tRow.%Set("Type", $List(tModels(tI), 3), "string")
            Do tRow.%Set("Target", tField, "string")
            Do tRow.%Set("TargetType", tOpType, "string")
            Do tRow.%Set("DataSources", tSources, "string")
            Do tRow.%Set("Verification", ''tVerification, "boolean")
            Do tRows.%Push(tRow)
        }
    } Catch ex {
        Set tRows = [(ex.DisplayString())]
    }
    Set $NAMESPACE = tOrigNS
    Quit tRows
}

/// <p>The rows of <var>pRows</var> that belong to the probe's definition, as one JSON array (the namespace may hold other definitions).</p>
ClassMethod Mine(pRows) As %String
{
    If '$IsObject(pRows) Quit "none"
    Set tMine = []
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tKey, .tRow) {
        If tRow.%Get("Class") = ..#DEFINITION Do tMine.%Push(tRow)
    }
    Quit tMine.%ToJSON()
}

/// <p>One read of <var>pEndpoint</var> through <var>pPort</var> in <var>pNamespace</var>, narrowed to the model <var>pModel</var> when that is given: the rows in <var>pRows</var>, the HTTP status and the fault.</p>
ClassMethod Read(pEndpoint As %String, pModel As %String, Output pRows, Output pHttp As %Integer, Output pFault, pPort As %String = {..#PORT}, pNamespace As %String = {..#NAMESPACE}) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("maxRows") = 100
    If pModel '= "" Set tQuery("model") = pModel
    Set pRows = ""
    Set pFault = ""
    Quit $ClassMethod(pPort, "Invoke", pEndpoint, "LIST", .tQuery, "", .pRows, .pHttp, .pFault)
}

/// <p>The model <var>pModel</var> of the probe's definition as the Test screen's criterion spells it: the vendor's <code>Class||Model</code>.</p>
ClassMethod IdOf(pModel As %String) As %String
{
    Quit ..#DEFINITION _ "||" _ pModel
}

/// <p>The same read as the screen at <code>GET /screens/&lt;screen&gt;/read</code> answers it (the rows), and as the agent's derived tool <code>&lt;screen&gt;.read</code> answers it, in
/// <var>pScreenRows</var> and <var>pToolRows</var>; <var>pModel</var> narrows the Test screen's read. <var>pStatus</var> is the screen's HTTP status and <var>pToolHttp</var> the tool's.</p>
ClassMethod Surfaces(pScreen As %String, pModel As %String, Output pScreenRows, Output pToolRows, Output pStatus As %Integer, Output pToolHttp As %Integer)
{
    Set pScreenRows = ""
    Set pToolRows = ""
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tCriterion = $Select(pModel = "": "", 1: "&model=" _ $ZConvert(pModel, "O", "URL"))
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/" _ pScreen _ "/read?maxRows=100" _ tCriterion, "", .pStatus, .tAnswer)
    If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("rows")) Set pScreenRows = tAnswer.rows
    Set tArgs = $Select(pModel = "": {}, 1: {"model": (pModel)})
    Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg(pScreen _ ".read", tArgs, $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
    Set pToolHttp = tLeg.%Get("http")
    If $IsObject(tLeg.%Get("rows")) Set pToolRows = tLeg.rows
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>AC1 (Integration, Rule 1): the person's list and Test screen and the agent's two derived tools read each model of the definition as the vendor's own calls report it. The fixture is pinned by name
/// (the tree is a <code>Tree</code> over <code>Color</code>, the regression a <code>Regression</code> over <code>Y</code>, the third carries no verification), the list is every row the vendor reports, and the Test
/// screen's one row is the list's row, by the port, the screen and the tool, in the vendor's <code>Class||Model</code> spelling and in the composite id the list's name cell sends.</p>
/// <p>Mutation (Rule 19): read <code>Target</code> from the model's <code>Type</code> in <method>OcuPilot.Port.AnalyticsPort.PmmlClassRowsHere</method> -- the Target field of every leg goes red.</p>
Method TestTheListAndTheTestRowAreWhatTheVendorHolds()
{
    Set tExpected = ..Expected()
    Do $$$AssertEquals(tExpected.%Size(), 3, "the fixture's definition holds three models: " _ tExpected.%ToJSON())
    Do $$$AssertEquals(tExpected.%Get(0).Model _ "|" _ tExpected.%Get(0).Type _ "|" _ tExpected.%Get(0).Target _ "|" _ tExpected.%Get(0).TargetType _ "|" _ tExpected.%Get(0).Verification, "Colors|Tree|Color|categorical|1", "the tree is a categorical model with verification records")
    Do $$$AssertEquals(tExpected.%Get(1).Model _ "|" _ tExpected.%Get(1).Type _ "|" _ tExpected.%Get(1).Target _ "|" _ tExpected.%Get(1).TargetType _ "|" _ tExpected.%Get(1).Verification, "Heights|Regression|Y|continuous|1", "the regression is a continuous model with verification records")
    Do $$$AssertEquals(tExpected.%Get(2).Model _ "|" _ tExpected.%Get(2).Verification _ "|" _ tExpected.%Get(2).DataSources, "Plain|0|Rows" _ $Char(10) _ "Changes" _ $Char(10) _ "Self" _ $Char(10) _ "Guarded", "the third has none, and the definition declares four data sources, one per line")
    Set tSC = ..Read("PmmlModels", "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..Mine(tRows), "200|" _ tExpected.%ToJSON(), "the port's list is every model the vendor reports")
    Do ..Surfaces(..#MODELS, "", .tScreen, .tTool, .tStatus, .tToolHttp)
    Do $$$AssertEquals(tStatus _ "|" _ ..Mine(tScreen), "200|" _ tExpected.%ToJSON(), "the screen reads the same rows")
    Do $$$AssertEquals(tToolHttp _ "|" _ ..Mine(tTool), "200|" _ tExpected.%ToJSON(), "and so does the agent's tool")
    For tI = 0:1:2 {
        Set tModel = tExpected.%Get(tI).Model
        For tId = ..IdOf(tModel), ..#DEFINITION _ $Char(1) _ tModel {
            Set tSC = ..Read("PmmlModel", tId, .tOne, .tOneHttp, .tFault)
            Do $$$AssertEquals(tOneHttp _ "|" _ $Select($IsObject(tOne): tOne.%ToJSON(), 1: "none"), "200|[" _ tExpected.%Get(tI).%ToJSON() _ "]", tModel _ ": the Test row is the list's row, as " _ $Select(tId [ "||": "Class||Model", 1: "the composite id") _ ": " _ tOneHttp _ " " _ $Select($IsObject(tOne): tOne.%ToJSON(), 1: "none") _ " " _ $Select($IsObject(tFault): tFault.%ToJSON(), 1: ""))
        }
        Do ..Surfaces(..#MODEL, ..IdOf(tModel), .tScreenOne, .tToolOne, .tStatusOne, .tToolHttpOne)
        Do $$$AssertEquals(tStatusOne _ "|" _ $Select($IsObject(tScreenOne): tScreenOne.%ToJSON(), 1: "none"), "200|[" _ tExpected.%Get(tI).%ToJSON() _ "]", tModel _ ": the Test screen reads that row")
        Do $$$AssertEquals(tToolHttpOne _ "|" _ $Select($IsObject(tToolOne): tToolOne.%ToJSON(), 1: "none"), "200|[" _ tExpected.%Get(tI).%ToJSON() _ "]", tModel _ ": and the agent's Test tool repeats it, executing nothing")
    }
}

/// <p>AC1: no read of the two endpoints writes. Every read, through the port and through the two derived tools, makes no journaled write in the calling process (the SQL engine's own statement bookkeeping is not
/// charged to them), and neither the vendor's test-id counter nor its result rows change. The scan is proved able to see a write: a control write made inside the same window is found by name.</p>
/// <p>Mutation (Rule 19): call <code>%GetNewTestId</code> from <method>OcuPilot.Port.AnalyticsPort.PmmlRowsHere</method> -- this goes red on the vendor's test-id counter.</p>
Method TestAAReadsWriteNothingAndStartNoTest()
{
    Set tCounter = $Get(^IRIS.Temp.DeepSee.PMML.ResultI("TestIdx"))
    Set tMark = $ClassMethod(..#PROBE, "JournalMark")
    Set tAnswers = ""
    Set tSC = ..Read("PmmlModels", "", .tRows, .tHttp, .tFault)
    Set tAnswers = tAnswers _ tHttp
    Set tSC = ..Read("PmmlModel", ..IdOf("Colors"), .tRows, .tHttp, .tFault)
    Set tAnswers = tAnswers _ tHttp
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    For tTool = ..#MODELS, ..#MODEL {
        Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg(tTool _ ".read", $Select(tTool = ..#MODEL: {"model": (..IdOf("Heights"))}, 1: {}), $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS"))
        Set tAnswers = tAnswers _ tLeg.%Get("http")
    }
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tTotal = $ClassMethod(..#PROBE, "JournalWrites", tMark, .tReadWrites)
    Set tReads = $Select(tTotal < 0: tTotal, 1: 0)
    Set tFirst = ""
    For tI = 1:1:tTotal {
        Set tRecord = tReadWrites(tI)
        If (tRecord '[ "]rINDEXSQL(") && (tRecord '[ "]%SYS(""sql"",") Set tReads = tReads + 1, tFirst = tFirst _ $Select(tFirst = "": "", 1: "; ") _ tRecord
    }
    Set ^|"USER"|OcuPilotProbeAnalyticsScan = 1
    Set tTotal = $ClassMethod(..#PROBE, "JournalWrites", tMark, .tAllWrites)
    Kill ^|"USER"|OcuPilotProbeAnalyticsScan
    Set tSeen = 0
    For tI = 1:1:tTotal {
        If $Get(tAllWrites(tI)) [ "OcuPilotProbeAnalyticsScan" Set tSeen = tSeen + 1
    }
    Do $$$AssertEquals(tAnswers, "200200200200", "every read answers 200")
    Do $$$AssertEquals(tReads, 0, "the reads made no journaled write" _ $Select(tReads > 0: ": " _ tFirst, tReads < 0: " (the journal rolled to another file)", 1: ""))
    Do $$$AssertEquals(tSeen, 1, "while the scan finds the control write made after them")
    Do $$$AssertEquals($Get(^IRIS.Temp.DeepSee.PMML.ResultI("TestIdx")), tCounter, "no read allocated a test id")
    Do $$$AssertEquals($ClassMethod(..#PMML, "Rows"), 0, "and none left a result row")
}

/// <p>A class that defines no model, a model the class does not hold, a model id of no usable shape and an empty criterion each read no row, without a refusal; and a model whose name differs only in case is another
/// model, which the vendor keys exactly.</p>
/// <p>Mutation (Rule 19): compare the model's name without regard to case in <method>OcuPilot.Port.AnalyticsPort.PmmlClassRowsHere</method> -- the case leg goes red.</p>
Method TestAnAbsentClassOrModelReadsNoRow()
{
    For tCase = $ListBuild("a model the class does not hold", ..IdOf("Nope")), $ListBuild("a class that is not a definition", "ProbePmml.Source||Colors"), $ListBuild("a class that does not exist", "OcuPilotProbe.Pmml.Gone||Colors"), $ListBuild("an id with no separator", "Colors"), $ListBuild("a class of no shape", "Not A Class||Colors"), $ListBuild("an empty model", ..#DEFINITION _ "||"), $ListBuild("a model whose case differs", ..IdOf("colors")) {
        Set tSC = ..Read("PmmlModel", $List(tCase, 2), .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tRows): tRows.%Size(), 1: "none"), "200|0", $List(tCase, 1) _ " reads no row")
    }
    Set tSC = ..Read("PmmlModel", "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tRows): tRows.%Size(), 1: "none"), "200|0", "an empty criterion names no model")
}

/// <p>The gate: with only the portal's pair held a read of each endpoint is refused 403, naming <code>%Development:USE</code>, and a namespace that does not report analytics is refused 409
/// <code>ANALYTICS.NAMESPACE</code>, each before any vendor call. The run's own gate, <method>OcuPilot.Port.AnalyticsPort.PmmlResolve</method>, refuses the same two ways. The pair refusal of the endpoints is also
/// pinned by <class>OcuPilot.Test.PortGate</class>.</p>
/// <p>Mutation (Rule 19): list <code>%DeepSee_PortalEdit:USE</code> in place of <code>%Development:USE</code> in <parameter>OcuPilot.Port.AnalyticsPort.PMMLPAIRS</parameter> -- the 403 legs go red.</p>
Method TestTheGateRefusesBeforeAnyLookup()
{
    For tEndpoint = "PmmlModels", "PmmlModel" {
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_Portal", "USE")
        Set tSC = ..Read(tEndpoint, ..IdOf("Colors"), .tRows, .tHttp, .tFault, ..#SEAM, ..#NAMESPACE)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "403|AUTH.NOPRIVILEGE", tEndpoint _ ": without the developer pair the read is refused")
        Do $$$AssertEquals($Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: ""), "%Development:USE", tEndpoint _ ": and the refusal names the pair")
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
        Set tSC = ..Read(tEndpoint, ..IdOf("Colors"), .tRows, .tHttp, .tFault, ..#SEAM, "HSCUSTOM")
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "409|ANALYTICS.NAMESPACE", tEndpoint _ ": a namespace without analytics is refused")
    }
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_Portal", "USE")
    Set tSC = $ClassMethod(..#SEAM, "PmmlResolve", ..#NAMESPACE, ..#DEFINITION, "Colors", "verification", "", "", .tSQL, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "403|AUTH.NOPRIVILEGE", "resolving a test is refused without the developer pair")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Set tSC = $ClassMethod(..#SEAM, "PmmlResolve", "HSCUSTOM", ..#DEFINITION, "Colors", "verification", "", "", .tSQL, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "409|ANALYTICS.NAMESPACE", "and in a namespace without analytics")
}

}
