/// <p>Test-only <class>OcuPilot.Api.ScreenAction</class> subclass whose Journals tools are their
/// <code>OcuPilot.Test.SeamJournal*</code> subclasses, so each reaches
/// <class>OcuPilot.Test.JournalIntegrityPort</class>, which records each call and answers the
/// integrity check; the pairs, the fresh read and the prohibited set are the shipped route's. <method>Act</method> runs
/// <method>OcuPilot.Api.ScreenAction.Handle</method> in this process through
/// <class>OcuPilot.Test.DatabaseActionFixture</class>'s capture, and then puts back the current
/// device's mnemonic routine, which the vendor's own capture, nested inside that one by the route's
/// reads, leaves set; left set, the next vendor capture in the process turns redirection back on.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.JournalIntegrityAction Extends OcuPilot.Test.DatabaseActionFixture
{

/// <p>The tool's own declared port, which the seam tool names.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

ClassMethod ToolFor(pDescriptor As %String, pActionId As %String, Output pTool As %DynamicObject, Output pToolClass As %String) As %Status [ Private ]
{
    Set tSC = ##super(pDescriptor, pActionId, .pTool, .pToolClass)
    If $$$ISERR(tSC) Quit tSC
    If $ListFind($ListBuild("JournalIntegrityCheck", "JournalSwitchFile", "JournalSwitchDirectory"), $Piece($Get(pToolClass), "OcuPilot.Screen.Tool.", 2)) Set pToolClass = "OcuPilot.Test.Seam" _ $Piece(pToolClass, "OcuPilot.Screen.Tool.", 2)
    Quit tSC
}

ClassMethod Act(pScreen As %String, pBody As %DynamicObject, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set tRoutine = ##class(%Library.Device).GetMnemonicRoutine()
    Set tSC = ##super(pScreen, pBody, .pAnswer, .pStatus)
    Use $IO::($Select((tRoutine = "") || (tRoutine = "%X364"): "", 1: "^" _ tRoutine))
    Quit tSC
}

}
