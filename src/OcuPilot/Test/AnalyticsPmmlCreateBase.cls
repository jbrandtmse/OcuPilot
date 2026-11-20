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

/// <p>Every class under <code>ProbePmml.</code> with the length and a SHA-1 checksum of its text, as one string, so two calls compare equal when nothing was saved, changed or deleted between them.</p>
ClassMethod Snapshot() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tOut = ""
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE UPPER(Name) %STARTSWITH ? ORDER BY Name", "PROBEPMML.")
        While tRS.%Next() {
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

}
