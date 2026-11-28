/// <p>Test-only fixture for Story 24.14 Batch 4's PMML export suites: <class>OcuPilot.Port.AnalyticsPort</class> with four seams a test arms through <method>Arm</method>, so that each step of
/// <method>OcuPilot.Port.AnalyticsPort.PerformPmmlExport</method> can fail without a vendor fault: <code>vendor</code> <code>error</code>, the vendor's own run answering an error status once the result class is saved; <code>bound</code>, the seconds the export's own test is bounded to (a test over a slow source is then
/// stopped); <code>cubetext</code> <code>bad</code>, which makes the cube class name a property the result class does not hold, so the compiler refuses it; and <code>copy</code> <code>fail</code>, which copies the
/// rows as the port does and then fails, so that rows are left in the result class for the restore to remove. Unarmed, it is the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.PmmlPortExport Extends OcuPilot.Port.AnalyticsPort
{

/// <p>Forget every armed seam.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotPmmlExportSeam
}

/// <p>Arm <var>pKey</var> with <var>pValue</var>.</p>
ClassMethod Arm(pKey As %String, pValue As %String = 1)
{
    Set ^||OcuPilotPmmlExportSeam(pKey) = pValue
}

/// <p>The shipped vendor run, or, when <code>vendor</code> is <code>error</code>, the vendor's error status without running anything.</p>
ClassMethod PmmlVendor(pNamespace As %String, pClass As %String, pModel As %String, pSource As %String, pDataSource As %String, pSQL As %String, pBound As %Numeric, pId As %Integer, Output pMode As %String, Output pStatus As %Status)
{
    If $Get(^||OcuPilotPmmlExportSeam("vendor")) = "error" {
        Set pMode = ""
        Set pStatus = $$$ERROR($$$GeneralError, "the armed vendor error")
        Quit
    }
    Do ##super(pNamespace, pClass, pModel, pSource, pDataSource, pSQL, pBound, pId, .pMode, .pStatus)
}

/// <p>The armed bound, or the test's own.</p>
ClassMethod PmmlExportBound() As %Numeric
{
    If $Data(^||OcuPilotPmmlExportSeam("bound")) Quit ^||OcuPilotPmmlExportSeam("bound")
    Quit ##super()
}

/// <p>The shipped cube class text, or, when <code>cubetext</code> is <code>bad</code>, one whose second level names a property the result class does not hold.</p>
ClassMethod PmmlCubeClassText(pClass As %String, pCube As %String, pResult As %String, pTestId As %Integer) As %String
{
    Set tText = ##super(pClass, pCube, pResult, pTestId)
    If $Get(^||OcuPilotPmmlExportSeam("cubetext")) = "bad" Quit $Replace(tText, "sourceProperty=""PredictedValue""", "sourceProperty=""NoSuchProperty""")
    Quit tText
}

/// <p>The shipped copy, which, when <code>copy</code> is <code>fail</code>, then answers an error.</p>
ClassMethod PmmlCopy(pNamespace As %String, pTestId As %Integer, pClass As %String, Output pCount As %Integer) As %Status
{
    Set tSC = ##super(pNamespace, pTestId, pClass, .pCount)
    If $Get(^||OcuPilotPmmlExportSeam("copy")) = "fail" Quit $$$ERROR($$$GeneralError, "the armed copy failure")
    Quit tSC
}

}
