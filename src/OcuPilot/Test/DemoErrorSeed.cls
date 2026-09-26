/// <p>Pins <method>OcuPilot.Install.Fixture.EnsureErrorEntry</method>: a start that finds the demo's
/// own <code>&lt;DIVIDE&gt;</code> entry in the install namespace's application error log seeds no
/// second one, and a start that finds none seeds exactly one. Each leg counts the demo's entries
/// itself, through <code>SYS.ApplicationError</code>'s own queries, rather than trusting the method's
/// answer.</p>
/// <p>It deletes the demo's entries from the install namespace's <code>^ERRORS</code> and writes new
/// ones, so it runs only where <parameter>ARMINGVARIABLE</parameter> and
/// <code>OCUPILOT_ALLOW_ERROR_DELETE</code> both read <code>1</code>, on a throwaway container. It leaves
/// one demo entry present when it finishes, as a container start would.</p>
Class OcuPilot.Test.DemoErrorSeed Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class for writing an application error, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ERROR_SEED";

/// <p>Refuse to run at all unless this instance is armed both to write and to delete application
/// errors.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DemoErrorSeed writes application errors to this instance's own ^ERRORS and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron("OCUPILOT_ALLOW_ERROR_DELETE") '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DemoErrorSeed deletes application errors from this instance's own ^ERRORS and runs on a throwaway container only. OCUPILOT_ALLOW_ERROR_DELETE does not read 1 here, so nothing was deleted. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>Leave the demo's entry present, as every container start does.</p>
Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Install.Fixture).EnsureErrorEntry(..InstallNamespace(), .tDay, .tNumber, .tSeeded)
}

/// <p>The namespace the demo's entry lives in, which is the one this suite runs in.</p>
ClassMethod InstallNamespace() As %String
{
    Quit ##class(OcuPilot.Install.Installer).ResolveNamespace()
}

/// <p>The demo's entries in <var>pNamespace</var>, as <code>pIds(n) = "&lt;$H day&gt;,&lt;number&gt;"</code>
/// in the order the queries answer, and their count. An entry is the demo's when its error text
/// names both <code>SeedApplicationError+</code> and <code>^OcuPilot.Install.Fixture</code>.</p>
ClassMethod DemoEntries(pNamespace As %String, Output pIds) As %Integer
{
    Kill pIds
    Set pIds = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDates = ##class(%ResultSet).%New("SYS.ApplicationError:DateList")
        If $$$ISOK(tDates.Execute(pNamespace)) {
            While tDates.Next() {
                Set tDate = tDates.Get("Date")
                Set tList = ##class(%ResultSet).%New("SYS.ApplicationError:ErrorList")
                If $$$ISOK(tList.Execute(pNamespace, tDate)) {
                    While tList.Next() {
                        Set tText = tList.Get("Error message")
                        If (tText [ "SeedApplicationError+") && (tText [ "^OcuPilot.Install.Fixture") {
                            Set pIds($Increment(pIds)) = $ZDateH(tDate, 1) _ "," _ (+tList.Get("Error #"))
                        }
                    }
                }
                Do tList.Close()
            }
        }
        Do tDates.Close()
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pIds = -1
    }
    Quit pIds
}

/// <p>Delete every demo entry in <var>pNamespace</var>, answering how many the deletes reported.</p>
ClassMethod RemoveDemoEntries(pNamespace As %String) As %Integer
{
    Set tRemoved = 0
    Do ..DemoEntries(pNamespace, .tIds)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:+$Get(tIds) {
            Set tRemoved = tRemoved + ##class(SYS.ApplicationError).DeleteByError(pNamespace, $ZDate($Piece(tIds(tI), ",", 1), 1), $Piece(tIds(tI), ",", 2))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Quit tRemoved
}

/// <p>A present demo entry is answered and not seeded again: the count stays at one, and the
/// identity answered is the entry already there.</p>
/// <p>Mutation (Rule 19): make the find step always answer not-found (drop the match in
/// <method>OcuPilot.Install.Fixture.EnsureErrorEntry</method>) -- a second entry is seeded, and the
/// count and <var>pSeeded</var> assertions go red.</p>
Method TestAPresentEntryIsNotSeededAgain()
{
    Set tNs = ..InstallNamespace()
    Do ..RemoveDemoEntries(tNs)
    Do $$$AssertEquals(..DemoEntries(tNs, .tBefore), 0, "setup removed every demo entry")
    Do $$$AssertStatusOK(##class(OcuPilot.Install.Fixture).SeedApplicationError(.tDay, .tNumber), "setup logged one demo entry")
    Do $$$AssertEquals(..DemoEntries(tNs, .tSeededIds), 1, "and exactly one is present")

    Set tSC = ##class(OcuPilot.Install.Fixture).EnsureErrorEntry(tNs, .tFoundDay, .tFoundNumber, .tSeeded)
    Do $$$AssertStatusOK(tSC, "EnsureErrorEntry completes")
    Do $$$AssertEquals(tSeeded, 0, "a present entry is not seeded again")
    Do $$$AssertEquals(tFoundDay _ "," _ tFoundNumber, tDay _ "," _ tNumber, "the entry answered is the one already present")
    Do $$$AssertEquals(..DemoEntries(tNs, .tAfter), 1, "the demo entry count stays at one")

    Set tSC = ##class(OcuPilot.Install.Fixture).EnsureErrorEntry(tNs, .tAgainDay, .tAgainNumber, .tAgainSeeded)
    Do $$$AssertStatusOK(tSC, "a second start completes too")
    Do $$$AssertEquals(tAgainSeeded, 0, "and seeds nothing either")
    Do $$$AssertEquals(..DemoEntries(tNs, .tAfterAgain), 1, "so the count is still one")
}

/// <p>With no demo entry present -- another routine's <code>&lt;DIVIDE&gt;</code> in the same log
/// does not count -- exactly one is seeded, and its identity is the one answered.</p>
/// <p>Mutation (Rule 19): make the find step always answer found (return before the seed in
/// <method>OcuPilot.Install.Fixture.EnsureErrorEntry</method>) -- nothing is seeded, and the
/// <var>pSeeded</var> and count assertions go red.</p>
Method TestAnAbsentEntryIsSeededOnce()
{
    Set tNs = ..InstallNamespace()
    Do ..RemoveDemoEntries(tNs)
    Do $$$AssertEquals(..DemoEntries(tNs, .tBefore), 0, "setup removed every demo entry")
    Set tOtherSC = ##class(OcuPilot.Test.ErrorLogSeed).SeedInto(tNs, .tOtherDay, .tOtherNumber)
    Do $$$AssertStatusOK(tOtherSC, "setup logged another routine's <DIVIDE> in the same namespace")

    Set tSC = ##class(OcuPilot.Install.Fixture).EnsureErrorEntry(tNs, .tDay, .tNumber, .tSeeded)
    Do $$$AssertStatusOK(tSC, "EnsureErrorEntry completes")
    Do $$$AssertEquals(tSeeded, 1, "an absent entry is seeded")
    Do $$$AssertEquals(..DemoEntries(tNs, .tIds), 1, "exactly one demo entry is present")
    Do $$$AssertEquals($Get(tIds(1)), tDay _ "," _ tNumber, "and it is the one answered")

    If $$$ISOK(tOtherSC) {
        Set tOrigNS = $NAMESPACE
        Try {
            Set $NAMESPACE = "%SYS"
            Do ##class(SYS.ApplicationError).DeleteByError(tNs, $ZDate(tOtherDay, 1), tOtherNumber)
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
        }
    }
}

}
