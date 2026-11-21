/// <p>What Story 24.14 Batch 3's PMML definition create tests share: <class>OcuPilot.Test.AnalyticsListingGroupBase</class>'s routes, mint and confirm, audit and ledger counts, gate seam and script
/// runner, with the create's own fixtures: classes named <code>ProbePmml.New</code> and a marker, the probe's two-model text, a snapshot of every class under <code>ProbePmml.</code> and the
/// checks that a class and its package are free. <class>OcuPilot.Test.AnalyticsPmmlCreate</class> and <class>OcuPilot.Test.AnalyticsPmmlCreateEdge</class> extend it.</p>
/// <p><b>What it needs from the environment:</b> the base class's. It turns analytics on in <code>USER</code>, saves and compiles definition classes there, and removes every class under
/// <code>ProbePmml.</code> before and after each test.</p>
Class OcuPilot.Test.AnalyticsPmmlCreateBase Extends OcuPilot.Test.AnalyticsListingGroupBase [ Abstract, DependsOn = (OcuPilot.Test.AnalyticsProbe, OcuPilot.Test.PmmlProbe) ]
{

Parameter PMML = "OcuPilot.Test.PmmlProbe";

Parameter WRITEENDPOINT = "PmmlModels";

Parameter ADDTOOL = "OcuPilot.Screen.Tool.AnalyticsPmmlModelAdd";

Parameter SCREENROUTE = "/analytics/pmml-models";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, $CLASSNAME() _ " turns analytics on in USER and saves, compiles and deletes classes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Set tSC = $ClassMethod(..#PMML, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PMML, "Remove")
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove"))
    If $$$ISOK(tSC) && ('$ClassMethod(..#PMML, "Gone") || '$ClassMethod(..#PROBE, "Gone")) Set tSC = $$$ERROR($$$GeneralError, $CLASSNAME() _ " left probe state in USER: " _ $ClassMethod(..#PMML, "Left") _ " " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>Remove every class under <code>ProbePmml.</code>, which holds the classes a test made and the classes their compiles generated.</p>
Method RemoveFixtures() As %Status
{
    Quit $ClassMethod(..#PMML, "Remove")
}

/// <p>The new class a test names with <var>pMarker</var>.</p>
ClassMethod Name(pMarker As %String) As %String
{
    Quit $Parameter(..#PMML, "NEWPREFIX") _ pMarker
}

/// <p>The probe's two-model PMML text.</p>
ClassMethod Text() As %String
{
    Quit $ClassMethod(..#PMML, "CreatedText")
}

/// <p>The write port's add of <var>pClass</var> with the PMML text <var>pText</var>: the HTTP status and the fault's code in one string, the answer in <var>pResult</var>.</p>
ClassMethod Add(pClass As %String, pText As %String, Output pResult) As %String
{
    Quit ..Port(..#WRITEENDPOINT, "ADD", pClass, {"Class": (pClass), "PMML": (pText)}, "", .pResult)
}

/// <p>1 when the class <var>pClass</var> exists in <code>USER</code>, without regard to case; 0 when it does not; -1 when the lookup failed.</p>
ClassMethod ClassHeld(pClass As %String) As %Integer
{
    Quit ..CountOf("UPPER(Name) = ?", $ZConvert(pClass, "U"))
}

/// <p>1 when any class of the package <code>pClass.</code> exists in <code>USER</code>, without regard to case; 0 when none does; -1 when the lookup failed.</p>
ClassMethod PackageHeld(pClass As %String) As %Integer
{
    Quit ..CountOf("UPPER(Name) %STARTSWITH ?", $ZConvert(pClass, "U") _ ".")
}

/// <p>1 when the lookups read that the class <var>pClass</var> and its package are both free, the state every refusal before a save leaves; a lookup that failed is not free.</p>
ClassMethod Free(pClass As %String) As %Boolean
{
    Quit (..ClassHeld(pClass) = 0) && (..PackageHeld(pClass) = 0)
}

/// <p>1 when a class of <code>USER</code> matches <var>pWhere</var> with <var>pValue</var> bound, 0 when none does and -1 when the query fails, so a failed lookup never reads as an empty one.</p>
ClassMethod CountOf(pWhere As %String, pValue As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tHeld = -1
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %Dictionary.ClassDefinition WHERE " _ pWhere, pValue)
        If (tRS.%SQLCODE >= 0) && tRS.%Next() Set tHeld = (tRS.%GetData(1) > 0)
    } Catch {
        Set tHeld = -1
    }
    Set $NAMESPACE = tOrigNS
    Quit tHeld
}

/// <p>The <code>PMML</code> XData of the class <var>pClass</var>, read through the port, with its carriage returns removed; <code>"absent"</code> when the port answers none.</p>
ClassMethod StoredText(pClass As %String) As %String
{
    If ..Port(..#WRITEENDPOINT, "PMMLDEFINITION", pClass, "", "", .tRow) '= "200 " Quit "absent"
    Quit tRow.%Get("PMML")
}

/// <p>The models of <var>pClass</var> the PMML models list reports, as <code>Name</code> joined by <code>,</code>, in the list's order.</p>
ClassMethod ListedModels(pClass As %String) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#WRITEENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject(tRows) Quit "unreadable " _ $Get(tHttp)
    Set tNames = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tKey, .tRow) {
        If tRow.%Get("Class") = pClass Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tRow.%Get("Model")
    }
    Quit tNames
}

/// <p>Every class under <code>ProbePmml.</code> with the length and a SHA-1 checksum of its text, as one string, so two calls compare equal when nothing was saved, changed or deleted between them; a lookup that fails answers a value that differs per call.</p>
ClassMethod Snapshot() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tOut = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE UPPER(Name) %STARTSWITH ? ORDER BY Name", "PROBEPMML.")
        If tRS.%SQLCODE < 0 Set tOut = "unreadable " _ $ZHorolog
        While (tRS.%SQLCODE >= 0) && tRS.%Next() {
            Set tText = ..TextOf(tRS.%GetData(1))
            Set tOut = tOut _ tRS.%GetData(1) _ "=" _ $Length(tText) _ ":" _ $System.Encryption.Base64Encode($System.Encryption.SHA1Hash($ZConvert(tText, "O", "UTF8"))) _ ";"
        }
    } Catch {
        Set tOut = "unreadable " _ $ZHorolog
    }
    Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p>1 when the <code>ConfigChange</code> row of the verb <var>pVerb</var> on the entity of type <var>pType</var> and id <var>pId</var> since <var>pSince</var> records the outcome <var>pOutcome</var>.</p>
ClassMethod Recorded(pSince As %String, pId As %String, pVerb As %String, pOutcome As %String, pType As %String = "pmml-definition") As %Boolean
{
    Do $ClassMethod(..#QUEUES, "AuditRows", pSince, pType, $Replace(pId, $Char(1), "\u0001"), pVerb, .tData)
    Quit ''(tData [ ("""outcome"":""" _ pOutcome _ """"))
}

/// <p>The pair spec of the screen pairs the create needs.</p>
ClassMethod HeldPairSpec() As %String
{
    Quit $Parameter(..#PORT, "PMMLPAIRS")
}

/// <p>Set the governance key <var>pKey</var> to <var>pValue</var> (<code>enabled</code> or <code>disabled</code>) for this test; the policy found is restored by <method>OnAfterOneTest</method>.</p>
Method SetKey(pKey As %String, pValue As %String)
{
    If '..PreparedPolicyTaken {
        Kill tPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy), "the governance policy is read")
        Merge ..PreparedPolicy = tPolicy
        Set ..PreparedPolicyTaken = 1
    }
    Kill tSettings
    Set tSettings(pKey) = pValue
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), pKey _ " is set " _ pValue)
}

/// <p>The export to a cube's tool (Story 24.14, Batch 4), the endpoint its write is made at, the screen path the person's Export to cube is sent to, the port seam that fails a step of it
/// (<class>OcuPilot.Test.PmmlPortExport</class>) and the custom query the export tests use as their third source.</p>
Parameter EXPORTTOOL = "OcuPilot.Screen.Tool.AnalyticsPmmlModelExport";

Parameter EXPORTENDPOINT = "PmmlModel";

Parameter EXPORTSCREEN = "/screens/analytics.pmmlmodel/action";

Parameter EXPORTSEAM = "OcuPilot.Test.PmmlPortExport";

Parameter EXPORTCUSTOM = "SELECT ID, X, Color, Y FROM ProbePmml.Source WHERE X < 8";

/// <p>The probe's categorical model, <code>Colors</code>, as the screen sends its composite id.</p>
ClassMethod ModelId() As %String
{
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild($Parameter(..#PMML, "DEFINITIONCLASS"), $Parameter(..#PMML, "CATEGORICAL")))
}

/// <p>The same model as the agent spells it: its class, two vertical bars and its name.</p>
ClassMethod ModelSpelled() As %String
{
    Quit $Parameter(..#PMML, "DEFINITIONCLASS") _ "||" _ $Parameter(..#PMML, "CATEGORICAL")
}

/// <p>The result class, the cube class and the cube of the export a test names with <var>pMarker</var>, outside the <code>OcuPilot</code> names.</p>
ClassMethod ExportClass(pMarker As %String) As %String
{
    Quit $Parameter(..#PMML, "EXPORTPREFIX") _ pMarker _ ".Result"
}

ClassMethod ExportCubeClass(pMarker As %String) As %String
{
    Quit $Parameter(..#PMML, "EXPORTPREFIX") _ pMarker _ ".ResultCube"
}

ClassMethod ExportCube(pMarker As %String) As %String
{
    Quit "ProbePmmlExport" _ pMarker
}

/// <p>The values of the export of the marker <var>pMarker</var> against <var>pSource</var> (<code>dataset</code>, which names the probe's own data source, <code>verification</code> or
/// <code>custom</code>, which carries <parameter>EXPORTCUSTOM</parameter>): what the screen's action and the port's write take.</p>
ClassMethod ExportValues(pMarker As %String, pSource As %String = "dataset") As %DynamicObject
{
    Set tValues = {"Source": (pSource), "ResultClass": (..ExportClass(pMarker)), "CubeClass": (..ExportCubeClass(pMarker)), "Cube": (..ExportCube(pMarker))}
    If pSource = "dataset" Do tValues.%Set("DataSource", $Parameter(..#PMML, "DATASET"), "string")
    If pSource = "custom" Do tValues.%Set("SQL", ..#EXPORTCUSTOM, "string")
    Quit tValues
}

/// <p>The agent's arguments for the same export: the values and the model.</p>
ClassMethod ExportArgs(pMarker As %String, pSource As %String = "dataset") As %DynamicObject
{
    Set tArgs = ..ExportValues(pMarker, pSource)
    Do tArgs.%Set("Model", ..ModelSpelled(), "string")
    Quit tArgs
}

/// <p>The write port's <code>TOCUBE</code> of <var>pBody</var> over the probe's model: the HTTP status and the fault's code in one string, the answer in <var>pResult</var>.</p>
ClassMethod Export(pBody As %DynamicObject, Output pResult) As %String
{
    Quit ..Port(..#EXPORTENDPOINT, "TOCUBE", ..ModelId(), pBody, "", .pResult)
}

/// <p>The person's Export to cube of <var>pValues</var> over the probe's model: the status, the answer in <var>pAnswer</var>.</p>
ClassMethod ExportAct(pValues As %DynamicObject, Output pAnswer) As %Integer
{
    Quit ..Act(..#EXPORTSCREEN, "export", ..ModelId(), pValues, .pAnswer)
}

/// <p>1 when the namespace holds a cube named <var>pCube</var>, 0 when it does not and -1 when the lookup failed.</p>
ClassMethod CubeHeld(pCube As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tHeld = -1
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tHeld = ''##class(%DeepSee.Utils).%CubeExists(pCube)
    } Catch {
        Set tHeld = -1
    }
    Set $NAMESPACE = tOrigNS
    Quit tHeld
}

/// <p>The rows of the result class <var>pClass</var>, <code>-1</code> when the class does not exist or the count fails.</p>
ClassMethod ResultRows(pClass As %String) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = -1
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If ##class(%Dictionary.CompiledClass).%ExistsId(pClass) {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM " _ ##class(%DeepSee.Utils).%GetSQLTableName(pClass))
            If (tRS.%SQLCODE >= 0) && tRS.%Next() Set tCount = tRS.%GetData(1)
        }
    } Catch {
        Set tCount = -1
    }
    Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p>The result class's rows as <code>value=count;</code> for each actual value, in value order, and, after a <code>|</code>, the test ids the rows carry; <code>"absent"</code> for a class that does not exist.</p>
ClassMethod ResultValues(pClass As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tOut = "absent"
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If ##class(%Dictionary.CompiledClass).%ExistsId(pClass) {
            Set tTable = ##class(%DeepSee.Utils).%GetSQLTableName(pClass)
            Set tOut = ""
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(ActualValue), COUNT(*) FROM " _ tTable _ " GROUP BY %EXACT(ActualValue) ORDER BY %EXACT(ActualValue)")
            While tRS.%Next() {
                Set tOut = tOut _ tRS.%GetData(1) _ "=" _ tRS.%GetData(2) _ ";"
            }
            Set tIds = ""
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT DISTINCT TestId FROM " _ tTable _ " ORDER BY TestId")
            While tRS.%Next() {
                Set tIds = tIds _ $Select(tIds = "": "", 1: ",") _ tRS.%GetData(1)
            }
            Set tOut = tOut _ "|" _ tIds
        }
    } Catch {
        Set tOut = "unreadable"
    }
    Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p>The per-value counts of a test's <code>ran</code> answer <var>pAnswer</var> as <method>ResultValues</method> reads the result class's, without the test ids.</p>
ClassMethod AnswerValues(pAnswer As %DynamicObject) As %String
{
    Set tOut = ""
    For tAt = 0:1:pAnswer.values.%Size() - 1 {
        Set tOut = tOut _ pAnswer.values.%Get(tAt).actual _ "=" _ pAnswer.values.%Get(tAt).records _ ";"
    }
    Quit tOut
}

/// <p>The answer the port's own test of the probe's model against <var>pSource</var> gives, the oracle an export's rows are compared with: <code>ran</code> with its records and values.</p>
ClassMethod OracleAnswer(pSource As %String = "dataset") As %DynamicObject
{
    Set tSC = $ClassMethod(..#PORT, "PmmlRun", ..#NAMESPACE, $Parameter(..#PMML, "DEFINITIONCLASS"), $Parameter(..#PMML, "CATEGORICAL"), pSource, $Select(pSource = "dataset": $Parameter(..#PMML, "DATASET"), 1: ""), $Select(pSource = "custom": ..#EXPORTCUSTOM, 1: ""), 120, "", "", .tAnswer, .tStopped)
    Quit $Get(tAnswer)
}

/// <p>The text of the <code>Cube</code> XData of the cube class <var>pClass</var>, <code>""</code> for none.</p>
ClassMethod CubeXData(pClass As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tText = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tXData = ##class(%Dictionary.XDataDefinition).%OpenId(pClass _ "||Cube")
        If $IsObject(tXData) && $IsObject(tXData.Data) {
            Do tXData.Data.Rewind()
            While 'tXData.Data.AtEnd {
                Set tText = tText _ tXData.Data.Read(32000)
            }
        }
    } Catch {
        Set tText = ""
    }
    Set $NAMESPACE = tOrigNS
    Quit tText
}

/// <p>1 when the data global of the persistent class <var>pClass</var> holds anything in <code>USER</code>. It reads <code>^</code><var>pClass</var><code>D</code>, which is the class's data global only for a name of at most 29 characters:
/// the compiler hashes a longer name's global (measured), and this then reads a global nothing writes. A test whose data check matters uses a marker of at most six characters.</p>
ClassMethod DataLeft(pClass As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tLeft = 0
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tGlobal = "^" _ pClass _ "D"
        Set tLeft = ''$Data(@tGlobal)
    } Catch {
        Set tLeft = 1
    }
    Set $NAMESPACE = tOrigNS
    Quit tLeft
}

/// <p>What the export of the marker <var>pMarker</var> left, as text: <code>""</code> when neither of its classes, nor a class of either package, nor its cube, nor the result class's data, nor a vendor result row of the probe's models remains.
/// The cube is the marker's own unless the export asked for another, which <var>pCube</var> names.</p>
ClassMethod ExportLeft(pMarker As %String, pCube As %String = "") As %String
{
    Set tLeft = ""
    If ..Free(..ExportClass(pMarker)) '= 1 Set tLeft = tLeft _ " result class"
    If ..Free(..ExportCubeClass(pMarker)) '= 1 Set tLeft = tLeft _ " cube class"
    If ..CubeHeld($Select(pCube '= "": pCube, 1: ..ExportCube(pMarker))) '= 0 Set tLeft = tLeft _ " cube"
    If ..DataLeft(..ExportClass(pMarker)) Set tLeft = tLeft _ " data"
    If $ClassMethod(..#PMML, "Rows") Set tLeft = tLeft _ " test rows"
    Quit $ZStrip(tLeft, "<>W")
}

}
