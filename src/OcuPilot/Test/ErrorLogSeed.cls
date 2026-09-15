/// <p>The one assertion in this story that needs a <b>write</b>: an application error seeded into a
/// second namespace is observed through <code>SYS.ApplicationError</code>'s own queries -- the
/// namespace list grows to carry it, its date's count rises by exactly one, and the entry itself
/// reads back at the errors level.</p>
/// <p><b>It writes to <code>^ERRORS</code>, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>, <code>ocupilot-ci</code>).
/// <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does
/// not arm it, and <method>SeedInto</method> -- the one method in the tree that writes an
/// application error for a test -- refuses on its own besides, so a caller that reached it another
/// way writes nothing either.</p>
/// <p><b>A doc comment does not keep a writing class off a development instance.</b> Test classes
/// are selected by package, so a runner pointed at an instance someone cares about would otherwise
/// append to that instance's own error log. An application error cannot be un-logged: the delete is
/// Epic 5's, and there is nothing here to undo it with.</p>
/// <p><b>The seed is raised inline, and dispatches nothing.</b> <code>^ERRORS</code> is written by
/// <code>$$LOG^%ETN()</code> in the <i>current</i> namespace, so the seed has to run with
/// <code>$NAMESPACE</code> set to the target -- where an <code>OcuPilot.*</code> class does not
/// resolve at all. The shape is <method>OcuPilot.Install.Fixture.SeedApplicationError</method>'s: a
/// real <code>&lt;DIVIDE&gt;</code>, never a <code>Throw</code>, because a <code>Throw</code> leaves
/// <code>$ZError</code> empty and records the useless <code>&lt;LOG ENTRY&gt;</code> placeholder.
/// The divisor is read out of a variable, not written as a literal, because the compiler folds the
/// literal form.</p>
Class OcuPilot.Test.ErrorLogSeed Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class and <method>SeedInto</method>, and the one
/// value that arms them: <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it, so an
/// application error is written on the container that script builds and nowhere else. Anything else
/// -- absent, empty, or a value that reads like a refusal such as <code>0</code> -- refuses.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ERROR_SEED";

/// <p>The namespace the seed goes to: a normal namespace that is not the install namespace, so the
/// namespace list is observed to <b>grow</b> rather than merely to hold what install already put
/// there.</p>
Parameter TARGETNAMESPACE = "USER";

/// <p>The port the levels are read through.</p>
Parameter PORT = "OcuPilot.Port.LogSourcePort";

/// <p>Refuse to run at all unless this instance is armed for an application-error write.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ErrorLogSeed writes an application error to this instance's own ^ERRORS and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>Raise one genuine, controlled runtime error in <var>pNamespace</var> and log it to that
/// namespace's <code>^ERRORS</code>, answering the entry's identity in <var>pDay</var> (a
/// <code>$H</code> day number) and <var>pNumber</var> (that day's entry number).</p>
/// <p><b>The one method in the tree that writes an application error for a test</b>, and it carries
/// its own arming guard rather than trusting its callers': a class-level check protects the class
/// that declares it, not a sibling that calls it.
/// <class>OcuPilot.Test.ErrorLogDenial</class> is the other caller, which needs a second
/// error-holding namespace to measure the per-namespace gate against.</p>
/// <p>Restores <code>$NAMESPACE</code> on both paths and as the first line of its
/// <code>Catch</code> (AD-16), with a bare assignment -- a dispatch into
/// <class>OcuPilot.Kernel.Utils</class> from inside the switched region is the
/// <code>&lt;CLASS DOES NOT EXIST&gt;</code> trap itself.</p>
ClassMethod SeedInto(pNamespace As %String, Output pDay As %Integer, Output pNumber As %Integer) As %Status
{
    Set pDay = ""
    Set pNumber = ""
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ErrorLogSeed.SeedInto writes an application error and is armed on a throwaway container only; " _ ..#ARMINGVARIABLE _ " does not read 1 here")
    }
    Set tSC = $$$OK
    Set tLogged = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Try {
            Set tZero = 0
            Set tUnreachable = 1 / tZero
            ; Not reached: the line above always raises <DIVIDE>. Kept assigned so the compiler
            ; cannot discard the expression as unused.
            Set tSC = $$$ERROR($$$GeneralError, "the application error seed did not raise its own deliberate error")
        } Catch inner {
            Set tLogged = $$LOG^%ETN()
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    If tLogged = "" {
        Quit $$$ERROR($$$GeneralError, "the application error seed raised its deliberate error but the %ETN trap recorded no entry in " _ pNamespace)
    }
    Set pDay = $List(tLogged, 1)
    Set pNumber = $List(tLogged, 2)
    Quit $$$OK
}

/// <p>Read one level through the port.</p>
ClassMethod Read(pLevel As %String, pNamespace As %String = "", pDate As %String = "", pNumber As %String = "", Output pResult As %DynamicObject, Output pStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit $ClassMethod(..#PORT, "Errors", pLevel, pNamespace, pDate, pNumber, "", .pResult, .pStatus, .pFault)
}

/// <p>Whether <var>pNamespace</var> is one the namespaces level answers with, and how many errors
/// it records for <var>pDate</var> -- <code>-1</code> when the namespace is absent from the list,
/// which is a different answer from a date with no errors.</p>
ClassMethod CountFor(pNamespace As %String, pDate As %String) As %Integer
{
    Set tSC = ..Read("namespaces", "", "", "", .tNamespaces, .tStatus, .tFault)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit -1
    Set tListed = 0
    Set tIterator = tNamespaces.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.namespace = pNamespace Set tListed = 1
    }
    If 'tListed Quit -1
    Set tSC = ..Read("dates", pNamespace, "", "", .tDates, .tDateStatus, .tFault)
    If $$$ISERR(tSC) || (tDateStatus '= 200) Quit -1
    Set tCount = 0
    Set tDateIterator = tDates.rows.%GetIterator()
    While tDateIterator.%GetNext(.tIndex, .tRow) {
        If tRow.date = pDate Set tCount = tRow.count
    }
    Quit tCount
}

/// <p>AC1, AC7 -- an application error written to a namespace the list did not carry is observed
/// through the supported queries: the namespace joins the list, that date's count rises by exactly
/// one, and the entry reads back at the errors level with the identity the trap answered.</p>
/// <p><b>Deterministic whether or not the namespace already held errors.</b> The delta is what is
/// asserted, not the absolute count -- <class>OcuPilot.Test.ErrorLogDenial</class> seeds the same
/// namespace earlier in a full run, and an absolute figure would make this pass or fail on run
/// order.</p>
/// <p>Mutation: read the namespaces level from a static list instead of
/// <code>NamespaceList</code> -&gt; the "joins the list" assertion goes red. Mutation: drop the
/// entry's own row from the errors projection -&gt; the identity assertion goes red.</p>
Method TestASeededEntryIsObservedThroughTheSupportedQueries()
{
    Set tToday = $ZDate($Horolog, 1)
    Set tBefore = ..CountFor(..#TARGETNAMESPACE, tToday)

    Set tSC = ..SeedInto(..#TARGETNAMESPACE, .tDay, .tNumber)
    Do $$$AssertStatusOK(tSC, "the seed raises and logs one application error in " _ ..#TARGETNAMESPACE)
    If $$$ISERR(tSC) Quit
    Do $$$AssertNotEquals(tNumber, "", "and the trap answers the entry's own number: " _ tNumber)

    Set tDate = $ZDate(tDay, 1)
    Do $$$AssertEquals(tDate, tToday, "the entry is recorded under today's date on the instance clock: " _ tDate)

    Set tAfter = ..CountFor(..#TARGETNAMESPACE, tDate)
    Do $$$AssertNotEquals(tAfter, -1, "the namespace is in the list the instance's own NamespaceList answers with")
    If tAfter = -1 Quit
    Do $$$AssertEquals(tAfter, $Select(tBefore = -1: 1, 1: tBefore + 1), "and that date's count rose by exactly one, from " _ tBefore _ " to " _ tAfter)

    Set tSC = ..Read("list", ..#TARGETNAMESPACE, tDate, "", .tErrors, .tStatus, .tFault)
    Do $$$AssertEquals(tStatus, 200, "the errors level answers for the seeded namespace and date")
    If tStatus '= 200 Quit
    Set tFound = ""
    Set tIterator = tErrors.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.errorNumber = tNumber Set tFound = tRow
    }
    Do $$$AssertTrue($IsObject(tFound), "carrying the entry the trap named: #" _ tNumber)
    If '$IsObject(tFound) Quit
    Do $$$AssertTrue(tFound.errorText [ "<DIVIDE>", "with the instance's own error text: " _ tFound.errorText)
    Do $$$AssertNotEquals(tFound.routine, "", "and the routine its text names: " _ tFound.routine)

    Set tSC = ..Read("detail", ..#TARGETNAMESPACE, tDate, tNumber, .tDetail, .tDetailStatus, .tFault)
    Do $$$AssertEquals(tDetailStatus, 200, "and its captured detail reads back at the detail level")
    If tDetailStatus '= 200 Quit
    Do $$$AssertTrue(tDetail.variables.%Size() > 0, "with every local at every stack level: " _ tDetail.variables.%Size())
}

}
