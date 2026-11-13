/// <p>Pins that a test class's <method>OnAfterAllTests</method> undoes only what its own
/// <method>OnBeforeAllTests</method> did: a teardown that runs when the setup refused (unarmed, or failed
/// before its snapshot) leaves the shared governance policy as it found it, and every teardown that
/// restores the policy, deletes the egress row or reinstalls OcuPilot opens with a guard.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and the test classes compiled. Not
/// armed: it writes only the stored governance policy, which each test sets aside and puts back.</p>
Class OcuPilot.Test.TeardownGuard Extends %UnitTest.TestCase
{

/// <p>A write key the baseline enables.</p>
Parameter KEY = "osmgmt.devices.delete";

/// <p>The guard a teardown that reads an arming variable opens with.</p>
Parameter ARMINGGUARD = "^\s*If .*GetEnviron\(.*\) '= 1.* Quit \$\$\$OK\s*$";

/// <p>The guard a teardown that waits on its setup's snapshot opens with.</p>
Parameter FLAGGUARD = "^\s*If '\.\.PreparedPolicyTaken Quit \$\$\$OK\s*$";

Method OnBeforeOneTest() As %Status
{
    Set tAnswer = ##class(OcuPilot.Test.GovernanceFixture).SetAside()
    If tAnswer '= "ok" Quit $$$ERROR($$$GeneralError, "the stored policy could not be set aside: " _ tAnswer)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals(##class(OcuPilot.Test.GovernanceFixture).PutBack(), "ok", "the policy set aside is put back")
    Quit $$$OK
}

/// <p>A class whose setup never ran, which is what a refused setup leaves, runs its teardown over
/// a stored policy and leaves every row in place.</p>
Method TestATeardownWithoutItsSetupLeavesTheStoredPolicy()
{
    Kill tSettings
    Set tSettings(..#KEY) = "disabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("read-only", .tSettings)
    Do $$$AssertStatusOK(tSC, "a read-only preset and a disabled key are stored")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tSeeded)
    Do $$$AssertStatusOK(tSC, "the stored rows are read")
    Do $$$AssertEquals($Get(tSeeded(..#KEY)), "disabled", "holding the disabled key")
    Set tTest = ##class(OcuPilot.Test.AuthOptionsWrite).%New("")
    Set tSC = tTest.OnAfterAllTests()
    Do $$$AssertStatusOK(tSC, "the teardown of a class whose setup never ran answers ok")
    Do $$$AssertTrue(##class(OcuPilot.Test.GovernanceFixture).Matches(.tSeeded), "and every stored row reads as it did")
}

/// <p>Every <class>OcuPilot.Test</class> test case whose teardown restores the policy, deletes the
/// egress row or reinstalls OcuPilot opens that teardown with a guard: its setup's flag, or the
/// arming variables its setup checks. The classes are derived from the compiled dictionary, so a class
/// written later is held to the same line.</p>
Method TestEveryTeardownThatTouchesSharedStateOpensWithAGuard()
{
    Set tClasses = ..ListTestClasses()
    Do $$$AssertTrue($ListLength(tClasses) > 0, "the compiled test classes are listed")
    Set tDerived = 0
    Set tUnguarded = ""
    For tIdx = 1:1:$ListLength(tClasses) {
        Set tName = $List(tClasses, tIdx)
        Set tFirst = ..FirstTeardownLine(tName, .tTouches)
        If 'tTouches Continue
        Set tDerived = tDerived + 1
        If '$Match(tFirst, ..#ARMINGGUARD) && '$Match(tFirst, ..#FLAGGUARD) Set tUnguarded = tUnguarded _ $ListBuild(tName)
    }
    Do $$$AssertTrue(tDerived > 0, "the test cases whose teardown touches shared state are found")
    Do $$$AssertEquals($ListLength(tUnguarded), 0, "every such teardown opens with a guard; without one: " _ $ListToString(tUnguarded, ", "))
}

/// <p>Every teardown that opens with the setup flag has a setup that sets the flag directly after it
/// merges the policy snapshot, so the flag is true only once the snapshot exists.</p>
Method TestEveryFlagGuardHasItsFlagSetRightAfterTheSnapshot()
{
    Set tClasses = ..ListTestClasses()
    Set tDerived = 0
    Set tMisplaced = ""
    For tIdx = 1:1:$ListLength(tClasses) {
        Set tName = $List(tClasses, tIdx)
        Set tFirst = ..FirstTeardownLine(tName, .tTouches)
        If '$Match(tFirst, ..#FLAGGUARD) Continue
        Set tDerived = tDerived + 1
        If '..FlagFollowsSnapshot(tName) Set tMisplaced = tMisplaced _ $ListBuild(tName)
    }
    Do $$$AssertTrue(tDerived > 0, "the teardowns that open with the setup flag are found")
    Do $$$AssertEquals($ListLength(tMisplaced), 0, "every such setup sets the flag right after the snapshot merge; without it: " _ $ListToString(tMisplaced, ", "))
}

/// <p>The names of the compiled <class>OcuPilot.Test</class> classes, as a list.</p>
ClassMethod ListTestClasses() As %List
{
    Set tNames = ""
    Set tStmt = ##class(%SQL.Statement).%New()
    Set tSC = tStmt.%Prepare("SELECT %EXACT(Name) AS ClassName FROM %Dictionary.CompiledClass WHERE %EXACT(Name) LIKE 'OcuPilot.Test.%' ORDER BY %EXACT(Name)")
    If $$$ISERR(tSC) Quit tNames
    Set tRS = tStmt.%Execute()
    While tRS.%Next() {
        Set tNames = tNames _ $ListBuild(tRS.%Get("ClassName"))
    }
    Quit tNames
}

/// <p>Whether <var>pClass</var>'s <method>OnBeforeAllTests</method> sets the flag on the line directly after
/// the one that merges the policy snapshot. A setup that cannot be read answers false.</p>
ClassMethod FlagFollowsSnapshot(pClass As %String) As %Boolean
{
    Set tFollows = 0
    Try {
        Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId(pClass _ "||OnBeforeAllTests")
        If '$IsObject(tMethod) Quit
        Set tStream = tMethod.Implementation
        Do tStream.Rewind()
        Set tPrior = ""
        While 'tStream.AtEnd {
            Set tLine = tStream.ReadLine()
            If $ZStrip(tLine, "<>W") = "" Continue
            If $ZStrip(tLine, "<>W") = "Set ..PreparedPolicyTaken = 1" Set tFollows = (tPrior [ "Merge ..PreparedPolicy = ")
            Set tPrior = tLine
        }
    } Catch ex {
        Set tFollows = 0
    }
    Quit tFollows
}

/// <p>The first executable line of <var>pClass</var>'s <method>OnAfterAllTests</method>, and whether
/// <var>pTouches</var> that teardown calls the policy restore, an egress delete or the installer.
/// A class that is not a test case, or has no such method, answers no touch; a teardown that cannot be
/// read answers a touch with no guard, so it is named rather than skipped.</p>
ClassMethod FirstTeardownLine(pClass As %String, Output pTouches As %Boolean) As %String
{
    Set pTouches = 0
    Set tFirst = ""
    Try {
        If '$ClassMethod(pClass, "%Extends", "%UnitTest.TestCase") Quit
        Set tId = pClass _ "||OnAfterAllTests"
        If '##class(%Dictionary.CompiledMethod).%ExistsId(tId) Quit
        Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId(tId)
        If '$IsObject(tMethod) Quit
        Set tStream = tMethod.Implementation
        Do tStream.Rewind()
        While 'tStream.AtEnd {
            Set tLine = tStream.ReadLine()
            If $ZStrip(tLine, "<>W") = "" Continue
            If $Extract($ZStrip(tLine, "<W"), 1) = ";" Continue
            If tFirst = "" Set tFirst = tLine
            If (tLine [ "GovernanceFixture).Restore(") || (tLine [ "Egress).Delete") || (tLine [ "Installer).Install(") Set pTouches = 1
        }
    } Catch ex {
        Set pTouches = 1
        Set tFirst = "teardown could not be read: " _ ex.Name
    }
    Quit tFirst
}

}
