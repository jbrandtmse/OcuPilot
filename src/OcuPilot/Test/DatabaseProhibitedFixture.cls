/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass with two replaced seams
/// (Story 18.3): <method>OwnDatabaseNames</method> answers the shipped set plus the probe database a
/// test names in <code>^||OcuPilotDatabaseOwnProbe</code>, so the directory arm is driven against a
/// probe database's file and never a real protected one; and <method>OwnDatabaseNames</method> or
/// <method>OwnDatabaseDirectories</method> answers an error status when a test names it,
/// <code>names</code> or <code>directories</code>, in <code>^||OcuPilotDatabaseOwnFail</code>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseProhibitedFixture Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod OwnDatabaseNames(pPort As %String, Output pNames As %List) As %Status
{
    Set pNames = ""
    If $Get(^||OcuPilotDatabaseOwnFail) = "names" Quit $$$ERROR($$$GeneralError, "the own database names could not be read")
    Set tSC = ##super(pPort, .pNames)
    If $$$ISERR(tSC) Quit tSC
    Set tProbe = $ZConvert($Get(^||OcuPilotDatabaseOwnProbe), "U")
    If (tProbe '= "") && '$ListFind(pNames, tProbe) Set pNames = pNames _ $ListBuild(tProbe)
    Quit $$$OK
}

ClassMethod OwnDatabaseDirectories(pPort As %String, pOwn As %List, Output pDirectories As %List) As %Status [ Private ]
{
    Set pDirectories = ""
    If $Get(^||OcuPilotDatabaseOwnFail) = "directories" Quit $$$ERROR($$$GeneralError, "the own database directories could not be read")
    Quit ##super(pPort, pOwn, .pDirectories)
}

}
