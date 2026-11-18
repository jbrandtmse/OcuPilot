/// <p>Pins Story 24.12's read surface (AD-29, AD-36, AD-65) against <code>USER</code>, with analytics on and the probe's quality measures saved and compiled through
/// <class>OcuPilot.Test.AnalyticsProbe</class>: the Quality measures, Groups and elements and Documentation endpoints of <class>OcuPilot.Port.AnalyticsPort</class> answer what the
/// vendor's <code>%GetModel</code> reads from each measure's class (a compiled measure, one whose compile is refused, a linked one and a twin class; a disabled measure is no row);
/// an unknown or empty measure answers no rows; a cap truncates; the screens and the agent's read tools answer the same rows; no read makes a journaled write; a namespace
/// without analytics is refused before any vendor call; and removing the probe leaves no class and no registry node.</p>
/// <p>This class runs as the unit-test process, which holds <code>%All</code>; the pair refusals are pinned by <class>OcuPilot.Test.PortGate</class>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot serving over HTTP as <class>OcuPilot.Test.Http</class>'s account and <parameter>ARMINGVARIABLE</parameter>
/// reading <code>1</code>, because the probe turns analytics on for <code>USER</code> and compiles classes there. It removes everything after the last test.
/// One class per run.</p>
Class OcuPilot.Test.AnalyticsQualityMeasureRead Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PORT = "OcuPilot.Port.AnalyticsPort";

Parameter SEAM = "OcuPilot.Test.AnalyticsGateSeam";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter NAMESPACE = "USER";

/// <p>The row fields of each endpoint, in the order the port answers them.</p>
Parameter MEASUREFIELDS = "Name,Catalog,Set,Id,Caption,Description,SubjectArea,Expression,LinkedTo,Published,Format,Href,Class,Compiled,Groups";

Parameter ELEMENTFIELDS = "QualityMeasure,Group,GroupCaption,GroupDescription,GroupDisabled,Name,Caption,MDX,Disabled";

Parameter METAFIELDS = "QualityMeasure,Name,Caption,Section,Content,Disabled";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsQualityMeasureRead turns analytics on in USER and compiles classes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "CreateQualityMeasures")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the probe and restore USER's flags; a failing status when anything of it, a quality measure included, is left.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsQualityMeasureRead left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>Remove any twin class a test left, and the gate seam's holds and arming.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#PROBE, "RemoveTwinQualityMeasure")
}

/// <p>One read of <var>pEndpoint</var> in <code>USER</code> through the port: the rows in <var>pRows</var>, the HTTP status and the fault.
/// <var>pMeasure</var> names the quality measure of an elements or documentation read.</p>
ClassMethod Read(pEndpoint As %String, pMeasure As %String = "", pMax As %String = 100, Output pRows, Output pHttp As %Integer, Output pFault) As %Status
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    If pMax '= "" Set tQuery("maxRows") = pMax
    If pMeasure '= "" Set tQuery($Parameter(..#PORT, "QUALITYMEASUREKEY")) = pMeasure
    Set pRows = ""
    Set pFault = ""
    Quit $ClassMethod(..#PORT, "Invoke", pEndpoint, "LIST", .tQuery, "", .pRows, .pHttp, .pFault)
}

/// <p>The number of rows of <var>pRows</var>; -1 when it is no array.</p>
ClassMethod RowCount(pRows As %DynamicArray) As %Integer
{
    Quit $Select($IsObject(pRows): pRows.%Size(), 1: -1)
}

/// <p>The <code>Name</code>s of <var>pRows</var>, comma-separated; <code>"unreadable"</code> for no array.</p>
ClassMethod Names(pRows As %DynamicArray) As %String
{
    If '$IsObject(pRows) Quit "unreadable"
    Set tNames = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.%Get("Name")
    }
    Quit tNames
}

/// <p>The <code>Name</code>s of the rows of <var>pRows</var> that are probe measures (their catalog is the probe's), comma-separated, so a measures read is judged on
/// the probe's own rows whatever else <code>USER</code> holds; <code>"unreadable"</code> for no array.</p>
ClassMethod ProbeNames(pRows As %DynamicArray) As %String
{
    If '$IsObject(pRows) Quit "unreadable"
    Set tPrefix = $Parameter(..#PROBE, "QMCATALOG") _ "/"
    Set tNames = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Extract(tRow.%Get("Name"), 1, $Length(tPrefix)) = tPrefix Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.%Get("Name")
    }
    Quit tNames
}

/// <p>How many rows of <var>pRows</var> are probe measures; -1 when it is no array.</p>
ClassMethod ProbeCount(pRows As %DynamicArray) As %Integer
{
    If '$IsObject(pRows) Quit -1
    Set tNames = ..ProbeNames(pRows)
    Quit $Select(tNames = "": 0, 1: $Length(tNames, ","))
}

/// <p>How many entries of the vendor's <code>%GetQualityMeasureList</code> in <code>USER</code> carry the name <var>pName</var>; -1 when the list cannot be read.</p>
ClassMethod Listed(pName As %String) As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If $$$ISOK(##class(%DeepSee.QualityMeasure.Utils).%GetQualityMeasureList(.tList)) {
            Set tCount = 0
            Set tAt = ""
            For {
                Set tAt = $Order(tList(tAt))
                If tAt = "" Quit
                If $List(tList(tAt), 1) = pName Set tCount = tCount + 1
            }
        }
    } Catch ex {
        Set tCount = -1
    }
    Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p>The row of <var>pRows</var> whose <code>Name</code> is <var>pName</var>, or <code>""</code>.</p>
ClassMethod RowNamed(pRows As %DynamicArray, pName As %String) As %DynamicObject
{
    If '$IsObject(pRows) Quit ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Name") = pName Quit
        Set tRow = ""
    }
    Quit $Get(tRow)
}

/// <p>What the vendor reads for the measure <var>pName</var> in <code>USER</code>, as the three endpoints' rows should carry it: <code>{measure, elements, metas}</code>.
/// The model is read through <code>%GetModel</code> with the link followed, the class through the registry and <code>Compiled</code> through <code>IsUpToDate</code>.</p>
ClassMethod Facts(pName As %String) As %DynamicObject
{
    Set tFacts = {"measure": {}, "elements": [], "metas": []}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tClass = ##class(%DeepSee.QualityMeasure.Utils).%GetQualityMeasureClass(pName)
        Set tModel = ##class(%DeepSee.QualityMeasure.Utils).%GetModel(pName, , 1)
        Set tMeasure = tFacts.measure
        Do tMeasure.%Set("Name", pName, "string")
        Do tMeasure.%Set("Catalog", tModel.catalog, "string")
        Do tMeasure.%Set("Set", tModel.set, "string")
        Do tMeasure.%Set("Id", tModel.id, "string")
        Do tMeasure.%Set("Caption", tModel.caption, "string")
        Do tMeasure.%Set("Description", tModel.description, "string")
        Do tMeasure.%Set("SubjectArea", tModel.subjectArea, "string")
        Do tMeasure.%Set("Expression", tModel.expression, "string")
        Do tMeasure.%Set("LinkedTo", tModel.linkedTo, "string")
        Do tMeasure.%Set("Published", ''tModel.published, "boolean")
        Do tMeasure.%Set("Format", tModel.format, "string")
        Do tMeasure.%Set("Href", tModel.href, "string")
        Do tMeasure.%Set("Class", tClass, "string")
        Do tMeasure.%Set("Compiled", ''$System.OBJ.IsUpToDate(tClass), "boolean")
        Do tMeasure.%Set("Groups", tModel.groups.Count(), "number")
        For tGroupAt = 1:1:tModel.groups.Count() {
            Set tGroup = tModel.groups.GetAt(tGroupAt)
            Set tBase = {}
            Do tBase.%Set("QualityMeasure", tModel.name, "string")
            Do tBase.%Set("Group", tGroup.name, "string")
            Do tBase.%Set("GroupCaption", tGroup.caption, "string")
            Do tBase.%Set("GroupDescription", tGroup.description, "string")
            Do tBase.%Set("GroupDisabled", ''tGroup.disabled, "boolean")
            If tGroup.elements.Count() = 0 {
                Do tBase.%Set("Name", "", "string")
                Do tBase.%Set("Caption", "", "string")
                Do tBase.%Set("MDX", "", "string")
                Do tBase.%Set("Disabled", 0, "boolean")
                Do tFacts.elements.%Push(tBase)
            }
            For tElementAt = 1:1:tGroup.elements.Count() {
                Set tElement = tGroup.elements.GetAt(tElementAt)
                Set tRow = {}.%FromJSON(tBase.%ToJSON())
                Do tRow.%Set("Name", tElement.name, "string")
                Do tRow.%Set("Caption", tElement.caption, "string")
                Do tRow.%Set("MDX", tElement.mdx, "string")
                Do tRow.%Set("Disabled", ''tElement.disabled, "boolean")
                Do tFacts.elements.%Push(tRow)
            }
        }
        For tMetaAt = 1:1:tModel.metas.Count() {
            Set tMeta = tModel.metas.GetAt(tMetaAt)
            Set tRow = {}
            Do tRow.%Set("QualityMeasure", tModel.name, "string")
            Do tRow.%Set("Name", tMeta.name, "string")
            Do tRow.%Set("Caption", tMeta.caption, "string")
            Do tRow.%Set("Section", tMeta.section, "string")
            Do tRow.%Set("Content", tMeta.content, "string")
            Do tRow.%Set("Disabled", ''tMeta.disabled, "boolean")
            Do tFacts.metas.%Push(tRow)
        }
    } Catch ex {
        Do tFacts.%Set("error", ex.DisplayString())
    }
    Set $NAMESPACE = tOrigNS
    Quit tFacts
}

/// <p>Assert that <var>pRow</var> carries, for each of <var>pFields</var>, the value of <var>pExpected</var>.</p>
Method AssertSameFields(pRow As %DynamicObject, pExpected As %DynamicObject, pFields As %String, pLabel As %String)
{
    If '$IsObject(pRow) {
        Do $$$AssertTrue(0, pLabel _ ": the row is present")
        Quit
    }
    For tI = 1:1:$Length(pFields, ",") {
        Set tField = $Piece(pFields, ",", tI)
        Do $$$AssertEquals(pRow.%Get(tField), pExpected.%Get(tField), pLabel _ ": " _ tField _ " equals the model's")
    }
}

/// <p>Assert that the rows <var>pRows</var> are the facts' rows <var>pExpected</var>, one for one, on <var>pFields</var>.</p>
Method AssertSameRows(pRows As %DynamicArray, pExpected As %DynamicArray, pFields As %String, pLabel As %String)
{
    Do $$$AssertEquals(..RowCount(pRows), ..RowCount(pExpected), pLabel _ ": one row for each the model holds")
    If '$IsObject(pRows) || (pRows.%Size() '= pExpected.%Size()) Quit
    For tAt = 0:1:pRows.%Size() - 1 {
        Do ..AssertSameFields(pRows.%Get(tAt), pExpected.%Get(tAt), pFields, pLabel _ " row " _ (tAt + 1))
    }
}

/// <p>AC1: every probe measure the vendor lists with a name is one row whose fields equal what <code>%GetModel(name, , 1)</code> reads: the compiled measure (two groups),
/// the measure whose compile is refused (listed, not compiled, its groups read from its XData) and the linked measure (its own caption and <code>LinkedTo</code>, the
/// master's groups). The disabled measure is listed with no name and is no row, and its presence breaks no other.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.Collect</method> read <code>Compiled</code> as 1 for every row -- the refused leg goes red; read the model with the link
/// not followed -- the linked legs here and in <method>TestAMeasuresElementsAndDocumentationAreTheModels</method> go red.</p>
Method TestTheMeasuresAreTheModelsOfTheirClasses()
{
    Set tSC = ..Read("QualityMeasures", "", 100, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the measures read answers")
    Set tCompiled = $Parameter(..#PROBE, "QMCOMPILED")
    Set tRefused = $Parameter(..#PROBE, "QMREFUSED")
    Set tLinked = $Parameter(..#PROBE, "QMLINKED")
    Do $$$AssertEquals(..ProbeNames(tRows), tCompiled _ "," _ tLinked _ "," _ tRefused, "the three probe measures the vendor names are rows, in the vendor's order, and the disabled one is not")
    For tCase = $ListBuild(tCompiled, 1, 2), $ListBuild(tRefused, 0, 2), $ListBuild(tLinked, 1, 2) {
        Set tFacts = ..Facts($List(tCase, 1))
        Do $$$AssertEquals(tFacts.%Get("error"), "", $List(tCase, 1) _ ": the model reads")
        Set tRow = ..RowNamed(tRows, $List(tCase, 1))
        Do ..AssertSameFields(tRow, tFacts.measure, ..#MEASUREFIELDS, $List(tCase, 1))
        If $IsObject(tRow) Do $$$AssertEquals(tRow.Compiled _ "|" _ tRow.Groups, $List(tCase, 2) _ "|" _ $List(tCase, 3), $List(tCase, 1) _ ": compiled, and its group count")
    }
    Set tRow = ..RowNamed(tRows, tCompiled)
    If $IsObject(tRow) Do $$$AssertEquals(tRow.Caption _ "|" _ tRow.Catalog _ "|" _ tRow.Set _ "|" _ tRow.Id _ "|" _ tRow.Published _ "|" _ tRow.Class, "OcuPilot probe measure|" _ $Parameter(..#PROBE, "QMCATALOG") _ "|" _ $Parameter(..#PROBE, "QMSET") _ "|Compiled|1|" _ $Parameter(..#PROBE, "QMCOMPILEDCLASS"), "the compiled measure's caption, catalog, set, id, publication and class")
    Set tRow = ..RowNamed(tRows, tLinked)
    If $IsObject(tRow) Do $$$AssertEquals(tRow.LinkedTo _ "|" _ tRow.Caption _ "|" _ tRow.Class, tCompiled _ "|Follows the compiled measure|" _ $Parameter(..#PROBE, "QMLINKEDCLASS"), "the linked measure names its master, keeps its own caption and is its own class")
    Set tOff = $Parameter(..#PROBE, "QMOFF")
    Do $$$AssertEquals(..RowNamed(tRows, tOff), "", "the disabled measure is no row")
    Do $$$AssertEquals(..RowNamed(tRows, ""), "", "and no row is nameless")
}

/// <p>AC1: a measure's Groups and elements and its Documentation are the model's, one row per element (the group's fields repeated, a disabled element included) and per
/// documentation item; a group with no element is one row with empty element fields; a linked measure answers its master's rows under its own name; the criterion
/// is read without regard to case; and a criterion that names no measure, names a longer path, or is empty answers no rows.</p>
/// <p>Mutation (Rule 19): make the elements branch of <method>OcuPilot.Port.AnalyticsPort.Collect</method> skip a group that holds no element -- the refused measure's leg goes red.</p>
Method TestAMeasuresElementsAndDocumentationAreTheModels()
{
    For tName = $Parameter(..#PROBE, "QMCOMPILED"), $Parameter(..#PROBE, "QMREFUSED"), $Parameter(..#PROBE, "QMLINKED") {
        Set tFacts = ..Facts(tName)
        Do $$$AssertEquals(tFacts.%Get("error"), "", tName _ ": the model reads, so the comparison below is never of two failed reads")
        Set tSC = ..Read("QualityMeasureElements", tName, 100, .tElements, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, tName _ ": the elements read answers")
        Do ..AssertSameRows(tElements, tFacts.elements, ..#ELEMENTFIELDS, tName _ " elements")
        Set tSC = ..Read("QualityMeasureMetas", tName, 100, .tMetas, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, tName _ ": the documentation read answers")
        Do ..AssertSameRows(tMetas, tFacts.metas, ..#METAFIELDS, tName _ " documentation")
    }
    Set tCompiled = $Parameter(..#PROBE, "QMCOMPILED")
    Set tSC = ..Read("QualityMeasureElements", tCompiled, 100, .tElements, .tHttp, .tFault)
    Do $$$AssertEquals(..Names(tElements), "Over30,Retired,AllVisits", "the compiled measure's three elements, in model order")
    Set tRow = ..RowNamed(tElements, "Retired")
    If $IsObject(tRow) Do $$$AssertEquals(tRow.Disabled _ "|" _ tRow.Group _ "|" _ tRow.GroupCaption _ "|" _ tRow.MDX, "1|Long|Long stays|{[Minutes].&[99]}", "the disabled element reads disabled, with its group's fields and its MDX as text")
    Set tSC = ..Read("QualityMeasureMetas", tCompiled, 100, .tMetas, .tHttp, .tFault)
    Do $$$AssertEquals(..Names(tMetas), "Purpose", "the compiled measure's one documentation item")
    Set tRow = ..RowNamed(tMetas, "Purpose")
    If $IsObject(tRow) Do $$$AssertEquals(tRow.Section _ "|" _ tRow.Content, "Overview|Counts the long visits &amp; their share.", "its section, and its content as the stored markup, shown as text")
    Set tSC = ..Read("QualityMeasureElements", $Parameter(..#PROBE, "QMREFUSED"), 100, .tRefused, .tHttp, .tFault)
    Set tSpare = $Select($IsObject(tRefused) && (tRefused.%Size() = 2): tRefused.%Get(1), 1: "")
    If $IsObject(tSpare) Do $$$AssertEquals(tSpare.Group _ "|" _ tSpare.Name _ "|" _ tSpare.MDX _ "|" _ tSpare.Disabled, "Spare|||0", "a group with no element is one row with empty element fields")
    Set tSC = ..Read("QualityMeasureMetas", $Parameter(..#PROBE, "QMLINKED"), 100, .tLinkedMetas, .tHttp, .tFault)
    Do $$$AssertEquals(..Names(tLinkedMetas), "Purpose", "the linked measure answers its master's documentation")
    Set tSC = ..Read("QualityMeasureElements", $Parameter(..#PROBE, "QMLINKED"), 100, .tLinked, .tHttp, .tFault)
    Do $$$AssertEquals(..Names(tLinked), "Over30,Retired,AllVisits", "the linked measure answers its master's elements")
    If $IsObject(tLinked) && (tLinked.%Size() > 0) Do $$$AssertEquals(tLinked.%Get(0).QualityMeasure, $Parameter(..#PROBE, "QMLINKED"), "under its own name")
    Set tSC = ..Read("QualityMeasureElements", $ZConvert(tCompiled, "U"), 100, .tUpper, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..RowCount(tUpper), "200|3", "the criterion is read without regard to case")
    For tCriterion = "OcuPilotProbe/Quality/NoSuchMeasure", "", tCompiled _ "/Long", tCompiled _ "/Long/Over30", $Parameter(..#PROBE, "QMOFF") {
        For tEndpoint = "QualityMeasureElements", "QualityMeasureMetas" {
            Set tSC = ..Read(tEndpoint, tCriterion, 100, .tNone, .tHttp, .tFault)
            Do $$$AssertEquals(tHttp _ "|" _ ..RowCount(tNone), "200|0", tEndpoint _ ": the criterion '" _ tCriterion _ "' names no measure and answers no rows")
        }
    }
}

/// <p>AC1: when a second class declares the compiled measure's name, the measure is still one row, and it is the registered class's, with that class's elements, whichever way the two
/// class names sort, so the answer does not depend on the order the vendor lists the classes in.</p>
/// <p>Mutation (Rule 19): stop skipping a name <method>OcuPilot.Port.AnalyticsPort.Collect</method> has already listed -- the one-row legs go red.</p>
Method TestTheRegisteredClassAnswersWhenTwoClassesDeclareOneName()
{
    Set tName = $Parameter(..#PROBE, "QMCOMPILED")
    For tLate = 0, 1 {
        Set tLabel = $Select(tLate: "the late twin", 1: "the early twin")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateTwinQualityMeasure", tLate), tLabel _ " is saved and compiled")
        Do $$$AssertEquals(..Listed(tName), 2, tLabel _ ": the vendor lists the name twice, once per class, so the reads below meet two classes")
        Set tSC = ..Read("QualityMeasures", "", 100, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ ..ProbeCount(tRows), "200|3", tLabel _ ": the measures read still answers three probe rows")
        Set tRow = ..RowNamed(tRows, tName)
        If $IsObject(tRow) Do $$$AssertEquals(tRow.Class _ "|" _ tRow.Caption _ "|" _ tRow.Groups, $Parameter(..#PROBE, "QMCOMPILEDCLASS") _ "|OcuPilot probe measure|2", tLabel _ ": the compiled measure's row is the registered class's")
        Set tSC = ..Read("QualityMeasureElements", tName, 100, .tElements, .tHttp, .tFault)
        Do $$$AssertEquals(..Names(tElements), "Over30,Retired,AllVisits", tLabel _ ": and its elements are the registered class's, none the twin's")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveTwinQualityMeasure"), tLabel _ " is removed again")
    }
}

/// <p>The cap: a maxRows below the count answers that many rows through the port, and the screens report the read truncated (AD-36); a cap equal to the count reports nothing cut.</p>
/// <p>Mutation (Rule 19): drop the <code>pMax</code> stop of the elements branch in <method>OcuPilot.Port.AnalyticsPort.Collect</method> -- the one-element cap leg goes red.</p>
Method TestACapBoundsTheListsAndTheScreensSaySo()
{
    Set tSC = ..Read("QualityMeasures", "", 2, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..RowCount(tRows), "200|2", "a cap of two answers two measures")
    Set tName = $Parameter(..#PROBE, "QMCOMPILED")
    Set tSC = ..Read("QualityMeasureElements", tName, 1, .tElements, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..RowCount(tElements), "200|1", "and a cap of one answers one element")
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.qualitymeasures/read?maxRows=2", "", .tStatus, .tScreen)
    Do $$$AssertEquals(tStatus, 200, "the Quality measures screen reads")
    If $IsObject(tScreen) Do $$$AssertEquals(tScreen.%Get("truncated") _ "|" _ $Select($IsObject(tScreen.%Get("rows")): tScreen.rows.%Size(), 1: -1), "1|2", "two rows, and the read says it was cut")
    Set tElementsPath = "/screens/analytics.qualitymeasureelements/read?qualitymeasure=" _ $ZConvert(tName, "O", "URL") _ "&maxRows="
    Do $ClassMethod(..#CONTROL, "Call", "GET", tElementsPath _ "1", "", .tStatus, .tCut)
    Do $$$AssertEquals(tStatus, 200, "the Groups and elements screen reads under a cap of one")
    If $IsObject(tCut) Do $$$AssertEquals(tCut.%Get("truncated") _ "|" _ $Select($IsObject(tCut.%Get("rows")): tCut.rows.%Size(), 1: -1), "1|1", "one element, and the read says it was cut")
    Do $ClassMethod(..#CONTROL, "Call", "GET", tElementsPath _ "3", "", .tStatus, .tFit)
    Do $$$AssertEquals(tStatus, 200, "the Groups and elements screen reads under a cap equal to the count")
    If $IsObject(tFit) Do $$$AssertEquals(tFit.%Get("truncated") _ "|" _ $Select($IsObject(tFit.%Get("rows")): tFit.rows.%Size(), 1: -1), "0|3", "all three elements, and the read says nothing was cut")
}

/// <p>AC2 (Integration, Rule 1): each screen's read over HTTP and the agent's read tool answer the same rows, for the compiled measure's name, which holds slashes, and the rows
/// carry the measure the way the model does.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.Read.View</method> drop the criteria it was given -- the elements tool is refused 400 and this goes red.</p>
Method TestTheScreensAndTheAgentsToolsAnswerTheSameRows()
{
    Set tName = $Parameter(..#PROBE, "QMCOMPILED")
    Set tCap = $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    For tCase = $ListBuild("analytics.qualitymeasures", "", 3), $ListBuild("analytics.qualitymeasureelements", "qualitymeasure", 3), $ListBuild("analytics.qualitymeasuremetas", "qualitymeasure", 1) {
        Set tId = $List(tCase, 1)
        Set tPath = "/screens/" _ tId _ "/read?maxRows=100" _ $Select($List(tCase, 2) = "": "", 1: "&" _ $List(tCase, 2) _ "=" _ $ZConvert(tName, "O", "URL"))
        Do $ClassMethod(..#CONTROL, "Call", "GET", tPath, "", .tStatus, .tScreen)
        Do $$$AssertEquals(tStatus, 200, tId _ ": the screen reads")
        Set tArgs = $Select($List(tCase, 2) = "": {}, 1: {"qualitymeasure": (tName)})
        Set tLeg = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg(tId _ ".read", tArgs, tCap)
        Do $$$AssertEquals(tLeg.%Get("http") _ "|" _ tLeg.%Get("error"), "200|", tId _ ": the agent's read tool answers: " _ tLeg.%ToJSON())
        Do $$$AssertTrue($IsObject(tScreen) && $IsObject(tLeg.%Get("rows")) && $IsObject(tScreen.%Get("rows")), tId _ ": both reads carry rows")
        If $IsObject(tScreen) && $IsObject(tLeg.%Get("rows")) && $IsObject(tScreen.%Get("rows")) {
            Do $$$AssertEquals($Select($List(tCase, 2) = "": ..ProbeCount(tLeg.rows), 1: tLeg.rows.%Size()), $List(tCase, 3), tId _ ": with the rows the probe holds, so the comparison is never of two empty reads")
            Do $$$AssertEquals(..Canonical(tLeg.rows), ..Canonical(tScreen.rows), tId _ ": the tool's rows are the screen's, the tool's in its descriptor's sort order and the screen's in the port's")
        }
    }
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tRefused = $Parameter(..#PROBE, "QMREFUSED")
    Do $ClassMethod(..#CONTROL, "Call", "GET", "/screens/analytics.qualitymeasureelements/read?maxRows=100&qualitymeasure=" _ $ZConvert(tRefused, "O", "URL"), "", .tStatus, .tSpare)
    Do $$$AssertEquals(tStatus, 200, "the Groups and elements screen reads a measure with an empty group")
    Do $$$AssertTrue($IsObject(tSpare) && $IsObject(tSpare.%Get("rows")), "and carries rows")
    If $IsObject(tSpare) && $IsObject(tSpare.%Get("rows")) Do $$$AssertEquals(tSpare.rows.%Size() _ "|" _ ..Names(tSpare.rows), "2|One,", "the group with no element is a row of the screen, with an empty element name")
}

/// <p>The JSON of each row of <var>pRows</var>, sorted and joined by a newline, so two reads that answer the same rows in different orders compare equal.</p>
ClassMethod Canonical(pRows As %DynamicArray) As %String
{
    Kill tSort
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSort(tRow.%ToJSON()) = ""
    }
    Set tText = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSort(tKey))
        If tKey = "" Quit
        Set tText = tText _ tKey _ $Char(10)
    }
    Quit tText
}

/// <p>The gate: a namespace that does not report analytics is refused 409 <code>ANALYTICS.NAMESPACE</code> by each endpoint, before any vendor call. Each refusal is answered while a vendor
/// failure is armed on the gate seam, so a vendor call before the gate would answer 500 and not the refusal; with the namespace that reports analytics the armed failure is reached, which
/// proves the arming. The pair refusals of the three endpoints are pinned by <class>OcuPilot.Test.PortGate</class>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AnalyticsPort.AdmitNamespace</method> skip its analytics check -- the 409 legs go red.</p>
Method TestANamespaceWithoutAnalyticsIsRefusedBeforeAnyVendorCall()
{
    Do $ClassMethod(..#SEAM, "Arm", "collect", "status")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_Portal", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DeepSee_PortalEdit", "USE")
    For tEndpoint = "QualityMeasures", "QualityMeasureElements", "QualityMeasureMetas" {
        Kill tQuery
        Set tQuery("namespace") = "HSCUSTOM"
        Set tQuery("qualitymeasure") = "any"
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.%Get("code"), 1: ""), "409|ANALYTICS.NAMESPACE", tEndpoint _ ": a namespace without analytics is refused")
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("qualitymeasure") = "any"
        Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_USER", "READ")
        Set tSC = $ClassMethod(..#SEAM, "Invoke", tEndpoint, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 500, tEndpoint _ ": in a namespace that reports analytics the armed vendor failure is reached, so the refusal above came first")
    }
}

/// <p>AC4: no read of the matrix makes a journaled write in the calling process. The journal window covers every read, their first calls included. The
/// records it does not charge to them are the SQL engine's own: its statement index (<code>^rINDEXSQL</code>) and its <code>^%SYS("sql")</code> bookkeeping,
/// which a statement's first run on a fresh instance writes. The scan is proved able to see a write: a control write made inside the same window is found by name among its
/// records, and the reads before it found none. It covers the process's journaled databases; a write to a database that is not journaled is not seen.</p>
/// <p>Mutation (Rule 19): make the measures branch of <method>OcuPilot.Port.AnalyticsPort.Collect</method> set a global node in <code>USER</code> -- the no-write leg goes red.</p>
Method TestAAReadsMakeNoJournaledWrite()
{
    ; The framework journals each assertion it records, so nothing is asserted until both scans are done.
    Set tMark = $ClassMethod(..#PROBE, "JournalMark")
    Set tAnswers = ..ReadEverything()
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
    Set tControl = ""
    For tI = 1:1:tTotal {
        If $Get(tAllWrites(tI)) [ "OcuPilotProbeAnalyticsScan" Set tSeen = tSeen + 1, tControl = tAllWrites(tI)
    }
    Do $$$AssertEquals(tAnswers, "200|200,200,200,200,200|200,200,200,200,200|200,200,200|200,200", "the measures read, the elements and documentation reads of five names, the agent's three reads and the two capped reads answer")
    Do $$$AssertEquals(tReads, 0, "the reads made no journaled write" _ $Select(tReads > 0: ": " _ tFirst, tReads < 0: " (the journal rolled to another file)", 1: ""))
    Do $$$AssertEquals(tSeen, 1, "while the scan finds the control write made after them" _ $Select(tTotal < 0: " (the journal rolled to another file)", tSeen '= 1: " (records: " _ tTotal _ ")", 1: ": " _ tControl))
}

/// <p>Every read the AC4 scan covers: the measures read, the elements and documentation reads of each probe measure, the disabled one and one that does not exist, the agent's three
/// read tools, and a measures and an elements read cut by a cap of one. Answers the HTTP statuses as <code>measures|elements...|documentation...|tools...|capped...</code>.</p>
Method ReadEverything() As %String
{
    Set tSC = ..Read("QualityMeasures", "", 100, .tRows, .tMeasuresHttp, .tFault)
    Set tNames = $ListBuild($Parameter(..#PROBE, "QMCOMPILED"), $Parameter(..#PROBE, "QMREFUSED"), $Parameter(..#PROBE, "QMLINKED"), $Parameter(..#PROBE, "QMOFF"), "OcuPilotProbe/Quality/NoSuchMeasure")
    Set tElementsHttp = ""
    Set tMetasHttp = ""
    For tI = 1:1:$ListLength(tNames) {
        Set tSC = ..Read("QualityMeasureElements", $List(tNames, tI), 100, .tElements, .tHttp, .tFault)
        Set tElementsHttp = tElementsHttp _ $Select(tElementsHttp = "": "", 1: ",") _ tHttp
        Set tSC = ..Read("QualityMeasureMetas", $List(tNames, tI), 100, .tMetas, .tHttp, .tFault)
        Set tMetasHttp = tMetasHttp _ $Select(tMetasHttp = "": "", 1: ",") _ tHttp
    }
    Set tCap = $Parameter("OcuPilot.Kernel.Agent.Limits", "TOOLROWS")
    Set tName = $Parameter(..#PROBE, "QMCOMPILED")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tToolsHttp = ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.qualitymeasures.read", {}, tCap).%Get("http")
    Set tToolsHttp = tToolsHttp _ "," _ ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.qualitymeasureelements.read", {"qualitymeasure": (tName)}, tCap).%Get("http")
    Set tToolsHttp = tToolsHttp _ "," _ ##class(OcuPilot.Test.AnalyticsGate).ToolLeg("analytics.qualitymeasuremetas.read", {"qualitymeasure": (tName)}, tCap).%Get("http")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tSC = ..Read("QualityMeasures", "", 1, .tRows, .tCapHttp, .tFault)
    Set tSC = ..Read("QualityMeasureElements", tName, 1, .tElements, .tHttp, .tFault)
    Quit tMeasuresHttp _ "|" _ tElementsHttp _ "|" _ tMetasHttp _ "|" _ tToolsHttp _ "|" _ tCapHttp _ "," _ tHttp
}

/// <p>AC6: removing the probe's quality measures deletes every class and every registry node of a probe measure, so <method>OcuPilot.Test.AnalyticsProbe.Left</method> names none; creating
/// them again restores them. The registry nodes are read directly, not through the probe. It sorts last, so no other test of the class runs on what it re-creates.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Test.AnalyticsProbe.RemoveQualityMeasures</method> delete no class -- this goes red.</p>
Method TestZRemovingTheQualityMeasuresLeavesNothing()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveQualityMeasures"), "the measures are removed")
    Do $$$AssertEquals(..Left(), "", "no class and no registry node of a probe measure remains: " _ ..Left())
    Set tSC = ..Read("QualityMeasures", "", 100, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..ProbeCount(tRows), "200|0", "and the measures read answers none of them")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateQualityMeasures"), "the measures are made again")
    Set tSC = ..Read("QualityMeasures", "", 100, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(..ProbeCount(tRows), 3, "and the read answers them again")
}

/// <p>What the probe's quality measures leave in <code>USER</code>: a measure class, or a registry node of a probe name, class or subject area, read directly.</p>
ClassMethod Left() As %String
{
    Set tLeft = ""
    ; The probe's class is not visible in USER, so its names are read first.
    Set tClasses = ""
    For tParameter = "QMCOMPILEDCLASS", "QMREFUSEDCLASS", "QMLINKEDCLASS", "QMOFFCLASS", "QMTWINCLASS", "QMTWINLATECLASS" {
        Set tClasses = tClasses _ $ListBuild($Parameter(..#PROBE, tParameter))
    }
    Set tPrefix = $ZConvert($Parameter(..#PROBE, "QMCATALOG") _ "/", "U")
    Set tCube = $ZConvert($Parameter(..#PROBE, "VISITS"), "U")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        For tI = 1:1:$ListLength(tClasses) {
            Set tClass = $List(tClasses, tI)
            If ##class(%Dictionary.ClassDefinition).%ExistsId(tClass) Set tLeft = tLeft _ ",class " _ tClass
            If $Data(^DeepSee.QMsrs("qmsrClasses", tClass)) Set tLeft = tLeft _ ",class node " _ tClass
        }
        Set tName = $Order(^DeepSee.QMsrs("qmsrNames", tPrefix), -1)
        For {
            Set tName = $Order(^DeepSee.QMsrs("qmsrNames", tName))
            If $Extract(tName, 1, $Length(tPrefix)) '= tPrefix Quit
            Set tLeft = tLeft _ ",name node " _ tName
        }
        Set tName = $Order(^DeepSee.QMsrs("cubes", tCube, tPrefix), -1)
        For {
            Set tName = $Order(^DeepSee.QMsrs("cubes", tCube, tName))
            If $Extract(tName, 1, $Length(tPrefix)) '= tPrefix Quit
            Set tLeft = tLeft _ ",cube node " _ tName
        }
    } Catch ex {
        Set tLeft = tLeft _ ",unreadable: " _ ex.DisplayString()
    }
    Set $NAMESPACE = tOrigNS
    Quit $Extract(tLeft, 2, *)
}

}
