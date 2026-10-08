/// <p><class>OcuPilot.Port.ScreenAccessPort</class> with its pair set evaluated through
/// <class>OcuPilot.Test.ScreenGate</class>, whose held set a test declares, so
/// <class>OcuPilot.Test.PortGate</class> drives the port's refusal in a process holding <code>%All</code>.
/// When <code>^||OcuPilotAccessRace</code> names a screen, the first resource check a change makes stores
/// another writer's pair on that screen first, so <class>OcuPilot.Test.ScreenAccessGate</class> drives a
/// stored set that moves under a write. Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ScreenAccessPortGateSeam Extends OcuPilot.Port.ScreenAccessPort
{

/// <p>The test gate, in place of the instance's own answer.</p>
ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ScreenGate"
}

/// <p>The real answer, after storing <code>^||OcuPilotAccessRace("pair")</code> on the screen
/// <code>^||OcuPilotAccessRace("screen")</code> names, once, as another writer would.</p>
ClassMethod ResourceDefined(pName As %String) As %Boolean
{
    Set tScreen = $Get(^||OcuPilotAccessRace("screen"))
    If tScreen '= "" {
        Set tPair = $Get(^||OcuPilotAccessRace("pair"))
        Kill ^||OcuPilotAccessRace
        Set tSC = ##class(OcuPilot.Kernel.State.Access).GuardedGet(tScreen, .tPairs, .tVersion, .tFound)
        If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Kernel.State.Access).GuardedPut(tScreen, $Select(tFound: tPairs _ ",", 1: "") _ tPair, tVersion, "race")
        Set ^||OcuPilotAccessRace("stored") = $$$ISOK(tSC)
    }
    Quit ##super(pName)
}

}
