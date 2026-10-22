/// <p>Test-only <class>OcuPilot.Screen.Tool.MftConnectionUpdate</class> subclass declaring
/// <class>OcuPilot.Test.ScreenSaveMemoryPort</class> as its port. Armed <code>mergeproblem</code>, its merge reports a
/// problem of its own, as a tool whose merge refuses something its rules do not. Outside the tool package, so the
/// registry never lists it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ScreenSaveMftUpdate Extends OcuPilot.Screen.Tool.MftConnectionUpdate
{

Parameter PORTCLASS = "OcuPilot.Test.ScreenSaveMemoryPort";

/// <p>The text of the armed merge problem.</p>
Parameter PROBLEM = "the merge found a problem of its own";

ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    If ##class(OcuPilot.Test.ScreenSaveTrace).Armed("mergeproblem") {
        Set pPayload = ""
        Set pDiff = []
        Set pUnchanged = 0
        Set pProblem = ..#PROBLEM
        Quit $$$OK
    }
    Quit ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

}
