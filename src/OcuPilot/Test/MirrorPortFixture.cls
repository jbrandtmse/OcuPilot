/// <p><class>OcuPilot.Port.MirrorPort</class> with its pair set evaluated through <class>OcuPilot.Test.ScreenGate</class>, whose held set
/// a test declares, so <class>OcuPilot.Test.PortGate</class> and <class>OcuPilot.Test.MirrorRead</class> drive the port's refusal in a
/// process holding <code>%All</code>, and with the instance's membership, its license and its member rows armed by <method>Arm</method>
/// until <method>Reset</method>, so a test reads a failover or an async member and a licensed instance that is no member on an instance
/// that is none. <method>Queries</method> counts the vendor member queries an armed port made. Unarmed, it answers as the shipped port
/// does. Nothing else differs from it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MirrorPortFixture Extends OcuPilot.Port.MirrorPort
{

/// <p>The test gate, in place of the instance's own answer.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ScreenGate"
}

/// <p>Answer <var>pMember</var> (0, 1 or 2) and <var>pNoMirror</var> from <method>Membership</method>, and <var>pRowCount</var> rows
/// from <method>MemberRows</method>, until <method>Reset</method>.</p>
ClassMethod Arm(pMember As %Integer, pNoMirror As %Boolean, pRowCount As %Integer = 0)
{
    Kill ^||OcuPilotMirrorArmed
    Set ^||OcuPilotMirrorArmed = 1
    Set ^||OcuPilotMirrorArmed("member") = pMember
    Set ^||OcuPilotMirrorArmed("nomirror") = ''pNoMirror
    Set ^||OcuPilotMirrorArmed("rows") = pRowCount
    Set ^||OcuPilotMirrorArmed("queries") = 0
}

/// <p>The shipped answers again.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotMirrorArmed
}

/// <p>The member queries an armed port has made since <method>Arm</method>.</p>
ClassMethod Queries() As %Integer
{
    Quit +$Get(^||OcuPilotMirrorArmed("queries"))
}

ClassMethod Membership(Output pMember As %Integer, Output pNoMirror As %Boolean)
{
    If '$Data(^||OcuPilotMirrorArmed) {
        Do ##super(.pMember, .pNoMirror)
        Quit
    }
    Set pMember = ^||OcuPilotMirrorArmed("member")
    Set pNoMirror = ^||OcuPilotMirrorArmed("nomirror")
}

ClassMethod MemberRows(pMax As %Integer, Output pRows As %DynamicArray) As %Status
{
    If '$Data(^||OcuPilotMirrorArmed) Quit ##super(pMax, .pRows)
    Set ^||OcuPilotMirrorArmed("queries") = ^||OcuPilotMirrorArmed("queries") + 1
    Set pRows = []
    For tI = 1:1:^||OcuPilotMirrorArmed("rows") {
        If pRows.%Size() >= pMax Quit
        Do pRows.%Push(..RowFor($ListBuild("Member" _ tI, $Select(tI = 1: "Primary", 1: "Backup"), "Active", "Caught up " _ tI, "Caught up " _ tI)))
    }
    Quit $$$OK
}

}
