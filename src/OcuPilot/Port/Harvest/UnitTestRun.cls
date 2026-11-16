/// <p>The unit-test run body (AD-23): one <code>%UnitTest.Manager</code> run of the tests a target names, in the
/// request's own process and namespace, with the vendor's colon form and <code>/noload/nodelete/norecursive</code>,
/// answering <code>{run, passed, failed}</code>. A harvested handler body, called only through
/// <class>OcuPilot.Port.HarvestPort</class> by <class>OcuPilot.Port.DevToolPort</class>, which has already checked the
/// caller, resolved the target and taken the run lock, and which sets and restores the namespace's root global.</p>
Class OcuPilot.Port.Harvest.UnitTestRun Extends OcuPilot.Port.Harvest.UnitTest
{

/// <p>Run the tests <code>target</code> names at <code>level</code> (<code>package</code>, <code>class</code> or
/// <code>method</code>, where a method target reads <code>Class:Method</code>) in <code>namespace</code>, which the
/// body switches to by save and restore. The answer is <code>{run, passed, failed}</code>, <code>run</code> the index
/// of the run the manager recorded, or <code>0</code> when it recorded none. A method-level run counts only that
/// method.</p>
ClassMethod Run() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tErrored = 0
    Set tResult = ""
    Try {
        Set tTarget = $Get(%request.Data("target",1))
        Set tLevel = $Get(%request.Data("level",1))
        Set tNamespace = $Get(%request.Data("namespace",1))
        If tNamespace '= "" {
            Set tSwitchSC = ..SwitchNamespace(tNamespace, .tOrigNS)
            If $$$ISERR(tSwitchSC) {
                Set tErrored = 1
                Set tCmdStatus = tSwitchSC
                Quit
            }
        }
        Set tFilter = $Select(tLevel = "method": $Piece(tTarget, ":", 2), 1: "")
        Set tBefore = +$Order(^UnitTest.Result(""), -1)
        Do ##class(%UnitTest.Manager).RunTest(..BuildTestSpec(tTarget, tLevel), "/noload/nodelete/norecursive")
        Set tAfter = +$Order(^UnitTest.Result(""), -1)
        Set tResult = {}
        If tAfter <= tBefore {
            Do tResult.%Set("run", 0, "number")
            Do tResult.%Set("passed", 0, "number")
            Do tResult.%Set("failed", 0, "number")
        } Else {
            Set tParsed = ..ParseTestResults(tFilter)
            Set tPassed = +tParsed.%Get("passed")
            Set tFailed = +tParsed.%Get("failed")
            If tParsed.%Get("error") '= "" {
                Do ..CountResults(tAfter, tFilter, .tPassed, .tFailed)
            }
            Do tResult.%Set("run", tAfter, "number")
            Do tResult.%Set("passed", tPassed, "number")
            Do tResult.%Set("failed", tFailed, "number")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tErrored = 1
        Set tCmdStatus = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If tErrored {
        Do ..RenderResponseBody(..SanitizeError(tCmdStatus))
    } Else {
        Do ..RenderResponseBody($$$OK, , tResult)
    }
    Quit tSC
}

/// <p>The passed and failed methods of run <var>pRun</var>, only the method <var>pFilter</var> names when it is not
/// <code>""</code>, in <var>pPassed</var> and <var>pFailed</var>, by two fixed statements that bind every value and are
/// issued without a privilege check: the caller has passed the port's gate, and holding <code>%Development:USE</code>
/// and WRITE on the routines database does not grant SQL privileges on the vendor's result tables, which
/// <method>ParseTestResults</method> needs. A skipped method is neither.</p>
ClassMethod CountResults(pRun As %Integer, pFilter As %String, Output pPassed As %Integer, Output pFailed As %Integer)
{
    Set pPassed = 0
    Set pFailed = 0
    Set tFrom = "SELECT COUNT(*) FROM %UnitTest_Result.TestMethod tm JOIN %UnitTest_Result.TestCase tc ON tm.TestCase = tc.ID JOIN %UnitTest_Result.TestSuite ts ON tc.TestSuite = ts.ID WHERE ts.TestInstance = ? AND tm.Status = ?"
    For tStatus = 1, 0 {
        Set tStatement = ##class(%SQL.Statement).%New()
        If pFilter = "" {
            Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(.tStatement, tFrom, pRun, tStatus)
        } Else {
            Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(.tStatement, tFrom _ " AND tm.Name = ?", pRun, tStatus, pFilter)
        }
        If '$IsObject(tResult) || (tResult.%SQLCODE < 0) Continue
        If tResult.%Next() {
            If tStatus = 1 Set pPassed = +tResult.%GetData(1)
            If tStatus = 0 Set pFailed = +tResult.%GetData(1)
        }
    }
}

}
