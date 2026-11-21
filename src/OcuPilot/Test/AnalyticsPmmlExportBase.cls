/// <p>What Story 24.14 Batch 4's PMML export tests share, over <class>OcuPilot.Test.AnalyticsPmmlCreateBase</class>'s helpers: the probe's source table and definition created in <code>USER</code> once for the class, the
/// exports a test made removed before and after each test (each cube class, then each result class with its data, and not the probe's model), and the assertion that an export left what it should.
/// <class>OcuPilot.Test.AnalyticsPmmlExport</class> and <class>OcuPilot.Test.AnalyticsPmmlExportEdge</class> extend it.</p>
/// <p><b>What it needs from the environment:</b> the base class's. It makes and removes classes under <code>ProbePmml.Export</code> and cubes named <code>ProbePmmlExport</code> in <code>USER</code>.</p>
Class OcuPilot.Test.AnalyticsPmmlExportBase Extends OcuPilot.Test.AnalyticsPmmlCreateBase [ Abstract, DependsOn = OcuPilot.Test.PmmlProbe ]
{

Method OnBeforeAllTests() As %Status
{
    Set tSC = ##super()
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $Username)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PMML, "Create")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove every export a test made: each cube class, then each result class with its data. The probe's model stays for the next test.</p>
Method RemoveFixtures() As %Status
{
    Quit $ClassMethod(..#PMML, "RemoveExport")
}

/// <p>The <code>X</code> of the source row that the result class <var>pClass</var>'s <code>Record</code> resolves the record <var>pRecord</var> to; text naming the failure when it cannot be read.</p>
ClassMethod LinkedX(pClass As %String, pRecord As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tX = "unreadable"
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Record->X FROM " _ ##class(%DeepSee.Utils).%GetSQLTableName(pClass) _ " WHERE TestRecordId = ?", pRecord)
        Set tX = $Select((tRS.%SQLCODE >= 0) && tRS.%Next(): tRS.%GetData(1), 1: "unreadable " _ tRS.%SQLCODE)
    } Catch ex {
        Set tX = "unreadable " _ ex.Name
    }
    Set $NAMESPACE = tOrigNS
    Quit tX
}

/// <p>The script steps of the export <var>pValues</var> over the model <var>pId</var> (the probe's own when empty), as the draft's port renders them from the stored proposal's query and body; nothing is run.</p>
ClassMethod ExportScript(pValues As %DynamicObject, pId As %String = "") As %DynamicArray
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = $Select(pId '= "": pId, 1: ..ModelId())
    Quit $ClassMethod(..#PORT, "Snippet", ..#EXPORTENDPOINT, "TOCUBE", .tQuery, pValues)
}

/// <p>The export of the marker <var>pMarker</var> is made: both classes exist and compile, the cube is registered and the Cubes list shows it with no facts, the result class holds <var>pRecords</var> rows
/// whose per-value counts are <var>pExpected</var> (as <method>AnswerValues</method> reads them) under one test id, the cube class reads that class restricted to that id, and no vendor result row is left.
/// <var>pLabel</var> names the export in each message.</p>
Method AssertExported(pMarker As %String, pExpected As %String, pRecords As %Integer, pLabel As %String)
{
    Set tR = ..ExportClass(pMarker)
    Set tK = ..ExportCubeClass(pMarker)
    Set tCube = ..ExportCube(pMarker)
    Do $$$AssertEquals(..ClassHeld(tR) _ "|" _ ..ClassHeld(tK) _ "|" _ ..CubeHeld(tCube), "1|1|1", pLabel _ ": the result class, the cube class and the cube exist")
    Set tValues = ..ResultValues(tR)
    Do $$$AssertEquals($Piece(tValues, "|", 1), pExpected, pLabel _ ": the result class holds the run's records, value for value: " _ tValues)
    Do $$$AssertEquals(..ResultRows(tR), pRecords, pLabel _ ": and its row count equals the run's records")
    Set tId = $Piece(tValues, "|", 2)
    Do $$$AssertTrue((tId '= "") && (tId '[ ","), pLabel _ ": every row carries one test id (" _ tId _ ")")
    Set tXData = ..CubeXData(tK)
    Do $$$AssertTrue((tXData [ ("sourceClass=""" _ tR _ """")) && (tXData [ ("buildRestriction=""TestId = " _ tId _ """")) && (tXData [ ("name=""" _ tCube _ """")), pLabel _ ": the cube reads the result class, restricted to the test's id: " _ $Extract(tXData, 1, 200))
    Do $$$AssertTrue((tXData [ "ActualValueD") && (tXData [ "PredictedValueD"), pLabel _ ": with the two dimensions")
    Do $$$AssertEquals($ClassMethod(..#PMML, "RowsOf", +tId), 0, pLabel _ ": no vendor result row is left for the test id")
    Do $$$AssertEquals($ClassMethod(..#PMML, "Rows"), 0, pLabel _ ": nor for any model of the probe")
    Set tStatus = ..Port("Cubes", "LIST", "", "", "", .tRows)
    Set tListed = "unlisted"
    If $IsObject(tRows) {
        For tAt = 0:1:tRows.%Size() - 1 {
            If tRows.%Get(tAt).Name = tCube Set tListed = tRows.%Get(tAt).Facts
        }
    }
    Do $$$AssertEquals(tListed, 0, pLabel _ ": the Cubes list shows the cube with no facts: " _ tListed)
}

}
