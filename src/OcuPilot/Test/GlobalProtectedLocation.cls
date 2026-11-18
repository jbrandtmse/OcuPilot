/// <p>Pins how the globals arm finds the protected directories (Story 21.5, AD-10): the lookup holds the directory of OcuPilot's own database and of each of
/// the seven system databases, read independently from the database configuration, and a lookup that fails refuses the write. Both are asked of
/// <class>OcuPilot.Test.GlobalProhibited</class>.</p>
/// <p><b>What it needs from the environment:</b> an instance with OcuPilot installed, and the test's user able to read the database configuration in
/// <code>%SYS</code>. It writes nothing.</p>
Class OcuPilot.Test.GlobalProtectedLocation Extends %UnitTest.TestCase
{

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.GlobalProhibited).FailLookup(0)
    Do ##class(OcuPilot.Test.GlobalLocationSeam).Reset()
    Quit $$$OK
}

/// <p>The directory <var>pDatabase</var> is configured with, read in <code>%SYS</code>; <code>""</code> when it is not configured.</p>
ClassMethod ConfiguredDirectory(pDatabase As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tDirectory = ""
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Config.Databases).Get(pDatabase, .tProps)
        If $$$ISOK(tSC) Set tDirectory = $Get(tProps("Directory"))
    } Catch {
        Set tDirectory = ""
    }
    Set $NAMESPACE = tOrigNS
    Quit tDirectory
}

/// <p>The lookup holds one directory per database, for OcuPilot's own database and every database of <code>SYSTEMDATABASES</code>, each equal to the one the
/// configuration names, and no two of the eight are the same place.</p>
/// <p>Mutation (Rule 19): leave one probe global, <code>%cspSession</code>, out of <method>OcuPilot.Kernel.Proposal.Prohibited.ProtectedDirectories</method>
/// -> the database it stands for is not found and this goes red.</p>
Method TestTheLookupHoldsEveryProtectedDatabasesDirectory()
{
    Set tSC = ##class(OcuPilot.Test.GlobalProhibited).DirectoriesOf(.tDirectories)
    Do $$$AssertStatusOK(tSC, "the lookup answers for a caller that can read the configuration too")
    Set tNames = $ListBuild(##class(OcuPilot.Kernel.State.Base).#DATABASENAME) _ $ListFromString(##class(OcuPilot.Kernel.Proposal.Prohibited).#SYSTEMDATABASES)
    Set tSeen = ""
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tExpected = ..ConfiguredDirectory(tName)
        Do $$$AssertTrue(tExpected '= "", tName _ " is configured here")
        Set tFound = 0
        For tJ = 1:1:$ListLength($Get(tDirectories)) {
            If ##class(OcuPilot.Port.DatabasePort).SameDirectory($List(tDirectories, tJ), tExpected) Set tFound = 1
        }
        Do $$$AssertTrue(tFound, "the lookup holds " _ tName _ "'s directory " _ tExpected)
        If '$ListFind(tSeen, $ZConvert($ZStrip(tExpected, ">", "/\"), "L")) Set tSeen = tSeen _ $ListBuild($ZConvert($ZStrip(tExpected, ">", "/\"), "L"))
    }
    Do $$$AssertEquals($ListLength(tSeen), $ListLength(tNames), "the eight databases are eight different places")
}

/// <p>A write the arm cannot judge because its lookup failed is refused as an error, not let through as unprotected; the same write is judged normally when
/// the lookup answers.</p>
/// <p>Mutation (Rule 19): drop the <code>$$$ISERR</code> quit after the <code>ProtectedDirectories</code> call in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ProtectedLocation</method> -> the failing leg answers <code>0</code> and goes red.</p>
Method TestALookupThatFailsRefusesTheWrite()
{
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("global", "HSCUSTOM", "ZZOcuGlbLookup", .tRef)
    Do $$$AssertStatusOK(tSC, "the target's key")
    Do ##class(OcuPilot.Test.GlobalLocationSeam).Arm($ListBuild("/ordinary/directory/"))
    Set tSC = ##class(OcuPilot.Test.GlobalProhibited).Prohibits("explorer.globals.delete", tRef, "{}", "[]", .tProhibits, .tCode)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tProhibits _ "|" _ tCode, 1: "error"), "0|", "a global stored in an ordinary directory is not prohibited while the lookup answers")
    Do ##class(OcuPilot.Test.GlobalProhibited).FailLookup(1)
    Set tSC = ##class(OcuPilot.Test.GlobalProhibited).Prohibits("explorer.globals.delete", tRef, "{}", "[]", .tProhibits, .tCode)
    Do $$$AssertStatusNotOK(tSC, "and it is an error while the lookup fails")
}

}
