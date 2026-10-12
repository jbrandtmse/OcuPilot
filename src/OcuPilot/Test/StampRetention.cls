/// <p>The retention sweep keeps each install profile's newest <parameter>OcuPilot.Kernel.State.Stamp.KEEPRUNS</parameter>
/// stamps and deletes the rest (Story 18.13, AD-37, DW-423): a named profile is one group, the
/// production profile -- whose rows read back as SQL <code>NULL</code> -- another, and one profile's
/// rows never count against another's.</p>
/// <p><b>The sweep is instance-wide and this class seeds install stamps, so
/// <method>OnBeforeAllTests</method> refuses to run unless <parameter>ARMINGVARIABLE</parameter>
/// reads 1</b>, as <class>OcuPilot.Test.Retention</class> does; each test refuses to sweep when
/// another suite's expired rows are on the instance (<method>OcuPilot.Test.Retention.ForeignExpired</method>),
/// and removes every row it seeded by its marker.</p>
Class OcuPilot.Test.StampRetention Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The two named profiles the tests seed. A profile name is at most 16 characters.</p>
Parameter PROFILEA = "probestmp1813a";

Parameter PROFILEB = "probestmp1813b";

/// <p>Stored in each seeded row's <property>OcuPilot.Kernel.State.Stamp.DatabaseName</property>, so
/// the production-profile rows this class seeds are found and removed by it.</p>
Parameter MARKER = "StampRetention1813";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.StampRetention runs the instance-wide retention sweep over seeded install stamps, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was seeded.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Quit ..OnAfterOneTest()
}

/// <p>Remove every row this class seeds, whether this test or an earlier, aborted run left it.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.State.Stamp).DeleteByProfile(..#PROFILEA)
    Do ##class(OcuPilot.Kernel.State.Stamp).DeleteByProfile(..#PROFILEB)
    Do ..Exec("DELETE FROM OcuPilot_Kernel_State.Stamp WHERE DatabaseName = ?", ..#MARKER)
    Quit $$$OK
}

/// <p>Seed <var>pCount</var> stamps for <var>pProfile</var> (<code>""</code> is the production
/// profile), oldest first, each carrying its sequence number in
/// <property>OcuPilot.Kernel.State.Stamp.Timestamp</property> and <parameter>MARKER</parameter> in
/// its database name.</p>
Method Seed(pProfile As %String, pCount As %Integer)
{
    For tI = 1:1:pCount {
        Set tStamp = ##class(OcuPilot.Kernel.State.Stamp).%New()
        Set tStamp.Timestamp = $Translate($Justify(tI, 4), " ", "0")
        Set tStamp.Profile = pProfile
        Set tStamp.DatabaseName = ..#MARKER
        Set tSC = ##class(OcuPilot.Kernel.State.Stamp).GuardedSave(tStamp)
        If $$$ISERR(tSC) {
            Do $$$AssertStatusOK(tSC, "seeded stamp " _ tI _ " of profile '" _ pProfile _ "'")
            Quit
        }
        Set tStamp = ""
    }
}

ClassMethod Exec(pSql As %String, pArgs...) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pArgs...)
    Quit tRS.%SQLCODE
}

ClassMethod Count(pSql As %String, pArgs...) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pArgs...)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>The oldest and the newest sequence number among the seeded stamps of <var>pProfile</var>
/// that remain, as <code>oldest-newest</code>, or <code>none</code>.</p>
ClassMethod Range(pProfile As %String) As %String
{
    If pProfile = "" {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT MIN(Timestamp), MAX(Timestamp) FROM OcuPilot_Kernel_State.Stamp WHERE Profile IS NULL AND DatabaseName = ?", ..#MARKER)
    } Else {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT MIN(Timestamp), MAX(Timestamp) FROM OcuPilot_Kernel_State.Stamp WHERE Profile = ? AND DatabaseName = ?", pProfile, ..#MARKER)
    }
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() || (tRS.%GetData(1) = "") Quit "none"
    Quit +tRS.%GetData(1) _ "-" _ +tRS.%GetData(2)
}

/// <p>Run the sweep, unless another suite's rows are expired on this instance; answers whether it
/// ran.</p>
Method Sweep() As %Boolean
{
    Set tForeign = ##class(OcuPilot.Test.Retention).ForeignExpired()
    Do $$$AssertEquals(tForeign, "", "this instance holds no expired row another suite created, so the sweep removes only this class's own")
    If tForeign '= "" Quit 0
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Retention).Sweep(..#LIMITS), "the sweep runs")
    Quit 1
}

/// <p><b>A named profile keeps its newest hundred.</b> One profile holds 103 stamps and another
/// 40, the second seeded first so that a bound on the whole table, not on each profile, would
/// remove it. After the sweep the first holds stamps 4 to 103 and the second all 40.</p>
/// <p>Mutation (Rule 19): remove the stamp step from <method>OcuPilot.Kernel.Retention.Sweep</method>
/// -- the first profile keeps 103 and this goes red. Make
/// <method>OcuPilot.Kernel.State.Stamp.GuardedSweep</method> keep the newest hundred of the whole
/// table -- the second profile loses its rows and this goes red.</p>
Method TestANamedProfileKeepsItsNewestHundred()
{
    Do ..Seed(..#PROFILEB, 40)
    Do ..Seed(..#PROFILEA, 103)
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Stamp WHERE Profile = ?", ..#PROFILEA), 103, "the profile holds 103 stamps before the sweep")
    If '..Sweep() Quit
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Stamp WHERE Profile = ?", ..#PROFILEA), ##class(OcuPilot.Kernel.State.Stamp).#KEEPRUNS, "the profile keeps its newest hundred")
    Do $$$AssertEquals(..Range(..#PROFILEA), "4-103", "they are the newest: the three oldest went")
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Stamp WHERE Profile = ?", ..#PROFILEB), 40, "another profile's forty stamps are all kept")
}

/// <p><b>The production profile is a group of its own.</b> Its rows read back as SQL
/// <code>NULL</code>; 103 of them leave exactly the newest hundred in that group, every one of them
/// seeded here (the older production stamps on the instance go with the rest), and a named
/// profile's few stamps are not counted into it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.State.Stamp.GuardedSweep</method> skip the
/// group whose profile is empty -- the group keeps 103 and this goes red.</p>
Method TestTheProductionProfileIsAGroupOfItsOwn()
{
    Do ..Seed(..#PROFILEA, 5)
    Do ..Seed("", 103)
    Do $$$AssertTrue(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Stamp WHERE Profile IS NULL") >= 103, "the production group holds at least the 103 seeded stamps")
    If '..Sweep() Quit
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Stamp WHERE Profile IS NULL"), ##class(OcuPilot.Kernel.State.Stamp).#KEEPRUNS, "the production group keeps its newest hundred")
    Do $$$AssertEquals(..Range(""), "4-103", "all of them seeded here, the newest")
    Do $$$AssertEquals(..Count("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Stamp WHERE Profile = ? AND DatabaseName = ?", ..#PROFILEA, ..#MARKER), 5, "and a named profile's five stamps are left alone")
}

}
