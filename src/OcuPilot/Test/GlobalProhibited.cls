/// <p><class>OcuPilot.Kernel.Proposal.Prohibited</class> whose globals arm reads through <class>OcuPilot.Test.GlobalLocationSeam</class>, so
/// <class>OcuPilot.Test.GlobalWrite</class> asks the shipped arm about a global stored where a test says. Nothing else differs from the shipped set.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.GlobalProhibited Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod GlobalPortClass() As %String
{
    Quit "OcuPilot.Test.GlobalLocationSeam"
}

/// <p>Fail the protected-directory lookup (<var>pFail</var> 1), or let it answer as shipped (0).</p>
ClassMethod FailLookup(pFail As %Boolean = 1)
{
    Set ^||OcuPilotProtectedLookupFail = pFail
}

/// <p>The shipped lookup's directories, or an error status while <method>FailLookup</method> is on.</p>
ClassMethod ProtectedDirectories(Output pDirectories As %List) As %Status [ Private ]
{
    If $Get(^||OcuPilotProtectedLookupFail) {
        Set pDirectories = ""
        Quit $$$ERROR($$$GeneralError, "the protected-directory lookup was told to fail")
    }
    Quit ##super(.pDirectories)
}

/// <p>The shipped lookup's directories, for a test to compare with the instance's configuration.</p>
ClassMethod DirectoriesOf(Output pDirectories As %List) As %Status
{
    Quit ..ProtectedDirectories(.pDirectories)
}

}
