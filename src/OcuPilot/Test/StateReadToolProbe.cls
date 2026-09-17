/// <p>Test-only <class>OcuPilot.Screen.Tool.Read</class> subclass reading through
/// <class>OcuPilot.Test.StateReadProbe</class>, so a read tool's store fetch is observed.</p>
Class OcuPilot.Test.StateReadToolProbe Extends OcuPilot.Screen.Tool.Read [ Abstract ]
{

ClassMethod ReadClass() As %String
{
    Quit "OcuPilot.Test.StateReadProbe"
}

}
