/// <p>The unit-test bodies' shared methods (AD-23), harvested from the sibling's <code>UnitTest</code> handler at
/// <code>c6aad31</code>: <method>BuildTestSpec</method>, <method>ParseTestResults</method> and
/// <method>GetFailureMessage</method>, whose code is the sibling's unchanged. A harvested handler class, called only
/// through <class>OcuPilot.Port.HarvestPort</class>; <class>OcuPilot.Port.Harvest.UnitTestRun</class> extends it so the
/// calls resolve while the namespace is switched.</p>
Class OcuPilot.Port.Harvest.UnitTest Extends OcuPilot.Port.Harvest.Handler
{

/// Build the testspec string for <code>%UnitTest.Manager.RunTest</code> in <code>/noload</code> mode.
/// <p>With /noload, testspec MUST use colon format to specify classes directly.
/// The framework cannot discover classes from directories when the manager's root global is empty.</p>
/// <p>RunTest reads one spec as <code>suite:class[:method];class[:method];...</code>: the
/// classes of one suite follow the first colon and are separated by a semicolon alone.</p>
/// <ul>
/// <li>Class level: <code>:Class</code>.</li>
/// <li>Method level: <code>:Class:Method</code> (a target without a colon is <code>:Target</code>).</li>
/// <li>Package level: <code>:A;B;C</code>, one colon and then the package's
/// <code>%UnitTest.TestCase</code> classes. A package that holds no test class falls back to
/// <code>:Target</code>.</li>
/// </ul>
ClassMethod BuildTestSpec(pTarget As %String, pLevel As %String) As %String
{
    If pLevel = "class" {
        Quit ":"_pTarget
    }
    If pLevel = "method" {
        If pTarget [ ":" {
            Set tClass = $Piece(pTarget, ":", 1)
            Set tMethod = $Piece(pTarget, ":", 2)
            Quit ":"_tClass_":"_tMethod
        }
        Quit ":"_pTarget
    }
    If pLevel = "package" {
        ; Query class dictionary for all %UnitTest.TestCase subclasses in the package
        Set tSpec = ""
        Set tSQL = "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ? AND Abstract = 0"
        Set tStmt = ##class(%SQL.Statement).%New()
        Set tSC = tStmt.%Prepare(tSQL)
        If $$$ISOK(tSC) {
            Set tRS = tStmt.%Execute(pTarget_".")
            While tRS.%Next() {
                Set tClassName = tRS.%Get("Name")
                Try {
                    If $ClassMethod(tClassName, "%Extends", "%UnitTest.TestCase") {
                        Set tSpec = tSpec _ $Select(tSpec = "": ":", 1: ";") _ tClassName
                    }
                } Catch {}
            }
        }
        If tSpec = "" Quit ":"_pTarget
        Quit tSpec
    }
    Quit ":"_pTarget
}

/// Parse test results from the <code>%UnitTest_Result</code> SQL tables.
ClassMethod ParseTestResults(pMethodFilter As %String = "") As %DynamicObject
{
    Set tResult = {}
    Set tDetails = []
    Set tTotal = 0
    Set tPassed = 0
    Set tFailed = 0
    Set tSkipped = 0
    Set tDuration = 0

    Try {
        Set tInstanceId = ""
        Set tStmt = ##class(%SQL.Statement).%New()
        Set tSC = tStmt.%Prepare("SELECT TOP 1 ID, Duration FROM %UnitTest_Result.TestInstance ORDER BY ID DESC")
        If $$$ISERR(tSC) {
            Do tResult.%Set("total", 0, "number")
            Do tResult.%Set("passed", 0, "number")
            Do tResult.%Set("failed", 0, "number")
            Do tResult.%Set("skipped", 0, "number")
            Do tResult.%Set("duration", 0, "number")
            Do tResult.%Set("details", tDetails)
            Do tResult.%Set("error", "Failed to prepare SQL query for test results")
            Quit
        }
        Set tRS = tStmt.%Execute()
        If tRS.%Next() {
            Set tInstanceId = tRS.%Get("ID")
            Set tDuration = +tRS.%Get("Duration")
        }

        If tInstanceId = "" {
            Do tResult.%Set("total", 0, "number")
            Do tResult.%Set("passed", 0, "number")
            Do tResult.%Set("failed", 0, "number")
            Do tResult.%Set("skipped", 0, "number")
            Do tResult.%Set("duration", 0, "number")
            Do tResult.%Set("details", tDetails)
            Quit
        }

        Set tSQL = "SELECT tm.Name AS MethodName, tm.Status AS MethodStatus, tm.Duration AS MethodDuration, "_
                   "tc.Name AS ClassName "_
                   "FROM %UnitTest_Result.TestMethod tm "_
                   "JOIN %UnitTest_Result.TestCase tc ON tm.TestCase = tc.ID "_
                   "JOIN %UnitTest_Result.TestSuite ts ON tc.TestSuite = ts.ID "_
                   "WHERE ts.TestInstance = ? "_
                   "ORDER BY tc.Name, tm.Name"
        Set tStmt2 = ##class(%SQL.Statement).%New()
        Set tSC = tStmt2.%Prepare(tSQL)
        If $$$ISERR(tSC) {
            Do tResult.%Set("total", 0, "number")
            Do tResult.%Set("passed", 0, "number")
            Do tResult.%Set("failed", 0, "number")
            Do tResult.%Set("skipped", 0, "number")
            Do tResult.%Set("duration", tDuration, "number")
            Do tResult.%Set("details", tDetails)
            Do tResult.%Set("error", "Failed to prepare SQL query for test methods")
            Quit
        }
        Set tRS2 = tStmt2.%Execute(tInstanceId)

        While tRS2.%Next() {
            Set tMethodName = tRS2.%Get("MethodName")
            Set tClassName = tRS2.%Get("ClassName")
            Set tStatus = tRS2.%Get("MethodStatus")
            Set tMethodDur = +tRS2.%Get("MethodDuration")

            If (pMethodFilter '= "") && (tMethodName '= pMethodFilter) {
                Continue
            }

            Set tDetail = {}
            Do tDetail.%Set("class", tClassName)
            Do tDetail.%Set("method", tMethodName)
            Do tDetail.%Set("duration", tMethodDur, "number")

            If tStatus = 1 {
                Do tDetail.%Set("status", "passed")
                Do tDetail.%Set("message", "")
                Set tPassed = tPassed + 1
            } Else {
                Do tDetail.%Set("status", "failed")
                Set tMsg = ..GetFailureMessage(tInstanceId, tClassName, tMethodName)
                Do tDetail.%Set("message", tMsg)
                Set tFailed = tFailed + 1
            }

            Do tDetails.%Push(tDetail)
            Set tTotal = tTotal + 1
        }
    } Catch ex {
        Do tResult.%Set("error", "Error parsing test results: " _ ex.DisplayString())
    }

    Do tResult.%Set("total", tTotal, "number")
    Do tResult.%Set("passed", tPassed, "number")
    Do tResult.%Set("failed", tFailed, "number")
    Do tResult.%Set("skipped", tSkipped, "number")
    Do tResult.%Set("duration", tDuration, "number")
    Do tResult.%Set("details", tDetails)
    Quit tResult
}

/// Get failure messages for a specific test method from assertion results.
ClassMethod GetFailureMessage(pInstanceId As %String, pClassName As %String, pMethodName As %String) As %String [ Private ]
{
    Set tMsg = ""
    Try {
        Set tSQL = "SELECT ta.Description, ta.Status "_
                   "FROM %UnitTest_Result.TestAssert ta "_
                   "JOIN %UnitTest_Result.TestMethod tm ON ta.TestMethod = tm.ID "_
                   "JOIN %UnitTest_Result.TestCase tc ON tm.TestCase = tc.ID "_
                   "JOIN %UnitTest_Result.TestSuite ts ON tc.TestSuite = ts.ID "_
                   "WHERE ts.TestInstance = ? AND tc.Name = ? AND tm.Name = ? AND ta.Status = 0 "_
                   "ORDER BY ta.ID"
        Set tStmt = ##class(%SQL.Statement).%New()
        Set tSC = tStmt.%Prepare(tSQL)
        If $$$ISOK(tSC) {
            Set tRS = tStmt.%Execute(pInstanceId, pClassName, pMethodName)
            While tRS.%Next() {
                Set tDesc = tRS.%Get("Description")
                If tMsg '= "" Set tMsg = tMsg _ "; "
                Set tMsg = tMsg _ tDesc
            }
        }
    } Catch ex {
        Set tMsg = "Error retrieving failure details"
    }
    Quit tMsg
}

}
