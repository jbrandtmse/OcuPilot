/// <p>Test-only fixture for Story 24.14 Batch 2's PMML model tester suites: a source table and one PMML definition class in <code>USER</code>, in the package
/// <parameter>PACKAGE</parameter>. The definition holds a categorical model (<parameter>CATEGORICAL</parameter>, a tree over <code>X</code> predicting <code>Color</code>) and a
/// continuous model (<parameter>CONTINUOUS</parameter>, a regression of <code>Y</code> on <code>X</code>), each with verification records, and a third (<parameter>PLAIN</parameter>) with none; the SQL data
/// sources <parameter>DATASET</parameter>, <parameter>CHANGESOURCE</parameter> and <parameter>STATESOURCE</parameter>; and a cube data source (<parameter>CUBESOURCE</parameter>) over a cube a plain principal may not read.</p>
/// <p><method>Create</method> saves and compiles the classes and fills the table; <method>Remove</method> deletes the package and the vendor's result rows of its models;
/// <method>Gone</method> says whether nothing is left and <method>Left</method> what is. Analytics must be on in <code>USER</code>
/// (<method>OcuPilot.Test.AnalyticsProbe.Enable</method>) for the screens and routes that read it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions. Every entry point acts on <code>USER</code> by explicit save and restore of the namespace, and a run needs a
/// throwaway instance.</p>
Class OcuPilot.Test.PmmlProbe Extends %RegisteredObject [ DependsOn = OcuPilot.Test.AnalyticsProbe ]
{

Parameter NAMESPACE = "USER";

Parameter PACKAGE = "OcuPilotProbe.Pmml";

/// <p>The source table's class and package. They carry no <code>OcuPilot</code> in their names, because SQL query's self-protection check refuses any statement whose text holds that word.</p>
Parameter SOURCECLASS = "ProbePmml.Source";

Parameter SOURCEPACKAGE = "ProbePmml";

Parameter DEFINITIONCLASS = "OcuPilotProbe.Pmml.Definition";

/// <p>The categorical model: a tree that calls <code>X</code> up to 4.5 <code>low</code> and above it <code>high</code>, so source rows 5 and 6 are misclassified.</p>
Parameter CATEGORICAL = "Colors";

/// <p>The continuous model: <code>Y = 2X + 1</code>, which the source rows meet at odd <code>X</code> and miss by one at even <code>X</code>.</p>
Parameter CONTINUOUS = "Heights";

/// <p>The definition's SQL data source, over every source row.</p>
Parameter DATASET = "Rows";

/// <p>Two more SQL data sources the definition declares: one whose statement changes the source rows (a no-op, were it ever run) and one that queries OcuPilot's own state. A test is refused both.</p>
Parameter CHANGESOURCE = "Changes";

Parameter STATESOURCE = "Self";

/// <p>A third model, a regression with no verification records.</p>
Parameter PLAIN = "Plain";

/// <p>The definition's cube data source, which names <class>OcuPilot.Test.AnalyticsProbe</class>'s guarded cube: the definition does not compile when the cube is absent, so
/// <method>OcuPilot.Test.AnalyticsProbe.Create</method> runs first, and a principal without the cube's resource is refused it.</p>
Parameter CUBESOURCE = "Guarded";

/// <p>The source table's row count.</p>
Parameter ROWS = 12;

/// <p>The text of class <var>pName</var> of the package, in the class definition language.</p>
/// <p>The definition's cube source names the guarded cube of the analytics probe, which must already be compiled.</p>
ClassMethod ClassText(pName As %String) As %String [ Private ]
{
    Set tNL = $Char(13, 10)
    Set tHead = "Class " _ $Select(pName = "Source": ..#SOURCECLASS, 1: ..#PACKAGE _ "." _ pName) _ " Extends "
    If pName = "Source" {
        Quit tHead _ "%Persistent" _ tNL _ "{" _ tNL _ "Property X As %Double;" _ tNL _ "Property Color As %String;" _ tNL _ "Property Y As %Double;" _ tNL _ "}" _ tNL
    }
    Quit tHead _ "%DeepSee.PMML.Definition" _ tNL _ "{" _ tNL _
        "XData PMML [ XMLNamespace = ""http://www.intersystems.com/deepsee/pmml"" ]" _ tNL _ "{" _ tNL _ ..PmmlText() _ tNL _ "}" _ tNL _ "}" _ tNL
}

/// <p>The definition's PMML document.</p>
ClassMethod PmmlText() As %String [ Private ]
{
    Set tSource = $Translate($Piece(..#SOURCECLASS, ".", 1, *-1), ".", "_") _ "." _ $Piece(..#SOURCECLASS, ".", *)
    Quit "<PMML version='4.1' xmlns='http://www.intersystems.com/deepsee/pmml'>" _
        "<Header description='OcuPilot probe'/>" _
        "<DataDictionary>" _
        "<Extension name='isc:datasource'>" _
        "<X-SQLDataSource name='" _ ..#DATASET _ "' description='every source row' idField='ID'><X-SQL>SELECT ID, X, Color, Y FROM " _ tSource _ "</X-SQL></X-SQLDataSource>" _
        "<X-SQLDataSource name='" _ ..#CHANGESOURCE _ "' description='a statement that changes the source rows' idField='ID'><X-SQL>UPDATE " _ tSource _ " SET X = X</X-SQL></X-SQLDataSource>" _
        "<X-SQLDataSource name='" _ ..#STATESOURCE _ "' description='a query over OcuPilot state' idField='ID'><X-SQL>SELECT ID FROM OcuPilot_Kernel_State.SqlRun</X-SQL></X-SQLDataSource>" _
        "<X-DeepSeeDataSource name='" _ ..#CUBESOURCE _ "' cubeName='" _ ##class(OcuPilot.Test.AnalyticsProbe).#GUARDED _ "'/>" _
        "</Extension>" _
        "<DataField name='X' optype='continuous' dataType='double'/>" _
        "<DataField name='Color' optype='categorical' dataType='string'><Value value='low'/><Value value='high'/></DataField>" _
        "<DataField name='Y' optype='continuous' dataType='double'/>" _
        "</DataDictionary>" _
        "<TreeModel modelName='" _ ..#CATEGORICAL _ "' functionName='classification' splitCharacteristic='binarySplit'>" _
        "<MiningSchema><MiningField name='X' usageType='active'/><MiningField name='Color' usageType='predicted'/></MiningSchema>" _
        "<Node score='low'><True/>" _
        "<Node score='low'><SimplePredicate field='X' operator='lessOrEqual' value='4.5'/></Node>" _
        "<Node score='high'><True/></Node>" _
        "</Node>" _
        "<ModelVerification recordCount='4' fieldCount='2'>" _
        "<VerificationFields><VerificationField field='X' column='x'/><VerificationField field='Color' column='color'/></VerificationFields>" _
        "<InlineTable><row><x>2</x><color>low</color></row><row><x>5</x><color>low</color></row><row><x>7</x><color>high</color></row><row><x>9</x><color>high</color></row></InlineTable>" _
        "</ModelVerification>" _
        "</TreeModel>" _
        "<RegressionModel modelName='" _ ..#CONTINUOUS _ "' functionName='regression'>" _
        "<MiningSchema><MiningField name='X' usageType='active'/><MiningField name='Y' usageType='predicted'/></MiningSchema>" _
        "<RegressionTable intercept='1'><NumericPredictor name='X' coefficient='2'/></RegressionTable>" _
        "<ModelVerification recordCount='4' fieldCount='2'>" _
        "<VerificationFields><VerificationField field='X' column='x'/><VerificationField field='Y' column='y'/></VerificationFields>" _
        "<InlineTable><row><x>1</x><y>3</y></row><row><x>2</x><y>5</y></row><row><x>3</x><y>7</y></row><row><x>4</x><y>10</y></row></InlineTable>" _
        "</ModelVerification>" _
        "</RegressionModel>" _
        "<RegressionModel modelName='" _ ..#PLAIN _ "' functionName='regression'>" _
        "<MiningSchema><MiningField name='X' usageType='active'/><MiningField name='Y' usageType='predicted'/></MiningSchema>" _
        "<RegressionTable intercept='0'><NumericPredictor name='X' coefficient='3'/></RegressionTable>" _
        "</RegressionModel>" _
        "</PMML>"
}

/// <p>Save and compile the source table and the definition in <code>USER</code>, and write the source rows. A suite that died leaves its classes behind, so an existing
/// package is removed first.</p>
ClassMethod Create() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ..Remove()
        If $$$ISERR(tSC) Quit
        For tName = "Source", "Definition" {
            Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString(..#NAMESPACE, $Select(tName = "Source": ..#SOURCECLASS, 1: ..#PACKAGE _ "." _ tName), ..ClassText(tName))
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $System.OBJ.CompilePackage(..#SOURCEPACKAGE, "ck-d")
        If $$$ISOK(tSC) Set tSC = $System.OBJ.CompilePackage(..#PACKAGE, "ck-d")
        If $$$ISERR(tSC) Quit
        For tI = 1:1:..#ROWS {
            Set tRow = $ClassMethod(..#SOURCECLASS, "%New")
            Set tRow.X = tI
            Set tRow.Color = $Select(tI <= 6: "low", 1: "high")
            Set tRow.Y = (2 * tI) + 1 + ((tI # 2) = 0)
            Set tSC = tRow.%Save()
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete the package and the vendor's result rows whose model class is the probe's, in <code>USER</code>.</p>
ClassMethod Remove() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If ##class(%Dictionary.CompiledClass).%ExistsId(..#SOURCECLASS) Do $ClassMethod(..#SOURCECLASS, "%KillExtent")
        Set tSC = $System.OBJ.DeletePackage(..#PACKAGE, "-d")
        Set tSC = $$$ADDSC(tSC, $System.OBJ.DeletePackage(..#SOURCEPACKAGE, "-d"))
        Do ..DropRows()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete the vendor's result rows whose model class is the probe's, whichever test id they carry.</p>
ClassMethod DropRows()
{
    Set tPrefix = ..#PACKAGE _ ".%"
    &sql(DELETE FROM %DeepSee_PMML_Utils.TempResult WHERE ModelClass LIKE :tPrefix)
}

/// <p>The vendor's result rows of the probe's models now in the shared table, whichever test id they carry.</p>
ClassMethod Rows() As %Integer
{
    Set tPrefix = ..#PACKAGE _ ".%"
    &sql(SELECT COUNT(*) INTO :tCount FROM %DeepSee_PMML_Utils.TempResult WHERE ModelClass LIKE :tPrefix)
    Quit +$Get(tCount)
}

/// <p>The vendor's result rows of test id <var>pTestId</var>, of any model.</p>
ClassMethod RowsOf(pTestId As %Integer) As %Integer
{
    &sql(SELECT COUNT(*) INTO :tCount FROM %DeepSee_PMML_Utils.TempResult WHERE TestId = :pTestId)
    Quit +$Get(tCount)
}

/// <p>1 when <code>USER</code> holds nothing of the probe: no class under the package and no result row of its models.</p>
ClassMethod Gone() As %Boolean
{
    Quit ..Left() = ""
}

/// <p>What the probe left, as a comma-separated list; <code>""</code> for nothing.</p>
ClassMethod Left() As %String
{
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tPrefix = ..#PACKAGE _ ".%"
        Set tSourcePrefix = ..#SOURCEPACKAGE _ ".%"
        &sql(SELECT COUNT(*) INTO :tClasses FROM %Dictionary.ClassDefinition WHERE Name LIKE :tPrefix OR Name LIKE :tSourcePrefix)
        If +$Get(tClasses) Set tLeft = tLeft _ ",classes:" _ tClasses
        Set tRows = ..Rows()
        If tRows Set tLeft = tLeft _ ",results:" _ tRows
    } Catch ex {
        Set tLeft = tLeft _ ",error:" _ ex.Name
    }
    Set $NAMESPACE = tOrigNS
    Quit $Extract(tLeft, 2, *)
}

}
