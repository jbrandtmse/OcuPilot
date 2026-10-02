/// <p>Pins <class>OcuPilot.Test.AgentFixture</class>'s set-aside: after
/// <method>OcuPilot.Test.AgentFixture.SetAsideDefinitions</method> and
/// <method>OcuPilot.Test.AgentFixture.RestoreDefinitions</method>, every Agent data node, both Agent
/// index subtrees and every id read back byte-identical; a restore is refused, the copy kept, while
/// an Agent index node remains; a set-aside over a copy a crashed class left restores that copy
/// first; and a set-aside over a copy that cannot come back is refused, the copy and the node
/// blocking it left as they were.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, and an account that writes
/// OcuPilot's protected globals. Every definition it creates is named with
/// <parameter>OcuPilot.Test.AgentFixture.PROBEPREFIX</parameter>, created disabled so none takes the
/// default marker from a definition the instance already holds, and removed after each test; any
/// definition the instance already holds goes aside and comes back with the rest.</p>
Class OcuPilot.Test.AgentAside Extends %UnitTest.TestCase
{

/// <p>The <code>NameIdx</code> subscript of the stray index node the refusal tests write, under id
/// <code>-1</code>, which no row carries.</p>
Parameter ORPHANNAME = " OCUPILOTPROBEAGENTASIDEORPHAN";

Method OnBeforeOneTest() As %Status
{
    Quit ##class(OcuPilot.Test.AgentFixture).RestoreDefinitions()
}

Method OnAfterOneTest() As %Status
{
    Kill ^OcuPilot.Kernel.State.BaseI("NameIdx", ..#ORPHANNAME, -1)
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RestoreDefinitions()
    Do $$$AssertStatusOK(tSC, "whatever a test left aside is put back")
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Do $$$AssertTrue('$Data(^OcuPilotTestAgentAside), "and no holding global is left")
    Quit $$$OK
}

/// <p>Two definitions go aside, leaving no Agent row or index node in place, and come back
/// byte-identical with the holding global gone.</p>
Method TestRoundTripIsByteIdentical()
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..ProbeName("One"))
    Do $$$AssertStatusOK(tSC, "a definition is created")
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..ProbeName("Two"))
    Do $$$AssertStatusOK(tSC, "and a second")
    Set tBefore = ..Flat()
    Do $$$AssertTrue(tBefore '= "", "the instance holds Agent rows and index nodes to move")
    Set tSC = ##class(OcuPilot.Test.AgentFixture).SetAsideDefinitions()
    Do $$$AssertStatusOK(tSC, "the definitions are set aside")
    Do $$$AssertTrue(..Flat() = "", "no Agent row or Agent index node is left in place")
    Do $$$AssertTrue($Data(^OcuPilotTestAgentAside) > 0, "and the holding global holds them")
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RestoreDefinitions()
    Do $$$AssertStatusOK(tSC, "the definitions are restored")
    Do $$$AssertTrue(..Flat() = tBefore, "every Agent data node, index node and id reads back byte-identical")
    Do $$$AssertTrue('$Data(^OcuPilotTestAgentAside), "and the holding global is gone")
}

/// <p>A restore over a stray <code>NameIdx</code> node is refused and the copy kept; once the node
/// is gone the restore completes byte-identical.</p>
Method TestRestoreRefusedWhileAnIndexNodeRemains()
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..ProbeName("Held"))
    Do $$$AssertStatusOK(tSC, "a definition is created")
    Set tBefore = ..Flat()
    Set tSC = ##class(OcuPilot.Test.AgentFixture).SetAsideDefinitions()
    Do $$$AssertStatusOK(tSC, "it is set aside")
    Set ^OcuPilot.Kernel.State.BaseI("NameIdx", ..#ORPHANNAME, -1) = ""
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RestoreDefinitions()
    Do $$$AssertStatusNotOK(tSC, "a restore over a stray NameIdx node is refused")
    Do $$$AssertTrue($Data(^OcuPilotTestAgentAside) > 0, "and the copy is kept")
    Kill ^OcuPilot.Kernel.State.BaseI("NameIdx", ..#ORPHANNAME, -1)
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RestoreDefinitions()
    Do $$$AssertStatusOK(tSC, "once the node is gone the restore completes")
    Do $$$AssertTrue(..Flat() = tBefore, "and reads back byte-identical")
}

/// <p>A class sets the definitions aside, creates a probe and stops without restoring. The next
/// set-aside restores that copy first, so the probe is removed rather than carried into the new
/// copy, and the next restore brings back exactly what was there before.</p>
Method TestSetAsideRestoresALeftCopyFirst()
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..ProbeName("Kept"))
    Do $$$AssertStatusOK(tSC, "a definition is created")
    Set tBefore = ..Flat()
    Set tSC = ##class(OcuPilot.Test.AgentFixture).SetAsideDefinitions()
    Do $$$AssertStatusOK(tSC, "the first class sets it aside")
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..ProbeName("Left"))
    Do $$$AssertStatusOK(tSC, "and creates a probe it never removes")
    Set tSC = ##class(OcuPilot.Test.AgentFixture).SetAsideDefinitions()
    Do $$$AssertStatusOK(tSC, "the next class's set-aside succeeds over the copy left behind")
    Do $$$AssertTrue(..Flat() = "", "and leaves no Agent row or index node in place")
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RestoreDefinitions()
    Do $$$AssertStatusOK(tSC, "its restore succeeds")
    Do $$$AssertTrue(..Flat() = tBefore, "and brings back what was there before, without the left probe")
}

/// <p>A set-aside over a held copy whose restore is refused is refused itself: the copy is kept
/// node for node and the stray <code>NameIdx</code> node stays in place, so the instance's rows are
/// never folded into the copy.</p>
Method TestSetAsideRefusedOverACopyThatCannotComeBack()
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(..ProbeName("Stuck"))
    Do $$$AssertStatusOK(tSC, "a definition is created")
    Set tBefore = ..Flat()
    Set tSC = ##class(OcuPilot.Test.AgentFixture).SetAsideDefinitions()
    Do $$$AssertStatusOK(tSC, "it is set aside")
    Set ^OcuPilot.Kernel.State.BaseI("NameIdx", ..#ORPHANNAME, -1) = ""
    Set tHeld = ..Walk($Name(^OcuPilotTestAgentAside))
    Set tSC = ##class(OcuPilot.Test.AgentFixture).SetAsideDefinitions()
    Do $$$AssertStatusNotOK(tSC, "a set-aside over a copy the stray node keeps from coming back is refused")
    Do $$$AssertTrue(..Walk($Name(^OcuPilotTestAgentAside)) = tHeld, "and the copy is kept node for node")
    Do $$$AssertTrue($Data(^OcuPilot.Kernel.State.BaseI("NameIdx", ..#ORPHANNAME, -1)) # 2, "and the stray node stays in place")
    Kill ^OcuPilot.Kernel.State.BaseI("NameIdx", ..#ORPHANNAME, -1)
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RestoreDefinitions()
    Do $$$AssertStatusOK(tSC, "once the node is gone the restore completes")
    Do $$$AssertTrue(..Flat() = tBefore, "and reads back byte-identical")
}

/// <p>A probe definition's name.</p>
ClassMethod ProbeName(pSuffix As %String) As %String [ Private ]
{
    Quit ##class(OcuPilot.Test.AgentFixture).#PROBEPREFIX _ "Aside" _ pSuffix
}

/// <p>Every Agent row's data node with its subtree, then the subtree of every index Agent compiles
/// other than its IDKEY, as one <code>$ListBuild</code> of reference and value pairs: two calls
/// answer the same string only when every node, subscript and value is the same. Rows are read by
/// SQL from the master map and indexes from the class dictionary, not from the fixture's row
/// marker or index list, so a wrong marker or a missing index shows here.</p>
ClassMethod Flat() As %String [ Private ]
{
    Set tFlat = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT %ID FROM %IGNOREINDEX * OcuPilot_Kernel_State.Agent ORDER BY %ID")
    If tRS.%SQLCODE < 0 Quit "the Agent rows could not be read: SQLCODE " _ tRS.%SQLCODE
    While tRS.%Next() {
        Set tFlat = tFlat _ ..Walk($Name(^OcuPilot.Kernel.State.BaseD(tRS.%GetData(1))))
    }
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledIndex WHERE parent = ? AND IdKey = 0 ORDER BY Name", "OcuPilot.Kernel.State.Agent")
    If tRS.%SQLCODE < 0 Quit "the Agent indexes could not be read: SQLCODE " _ tRS.%SQLCODE
    While tRS.%Next() {
        Set tFlat = tFlat _ ..Walk($Name(^OcuPilot.Kernel.State.BaseI(tRS.%GetData(1))))
    }
    Quit tFlat
}

/// <p>The global node <var>pRoot</var> and every node under it, as reference and value pairs.</p>
ClassMethod Walk(pRoot As %String) As %String [ Private ]
{
    Set tFlat = ""
    If $Data(@pRoot) # 2 Set tFlat = $ListBuild(pRoot, @pRoot)
    Set tDepth = $QLength(pRoot)
    Set tRef = pRoot
    For {
        Set tRef = $Query(@tRef)
        If tRef = "" Quit
        If ($QLength(tRef) <= tDepth) || ($Name(@tRef, tDepth) '= pRoot) Quit
        Set tFlat = tFlat _ $ListBuild(tRef, @tRef)
    }
    Quit tFlat
}

}
