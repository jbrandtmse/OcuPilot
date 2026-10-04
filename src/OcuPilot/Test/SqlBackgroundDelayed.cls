/// <p><class>OcuPilot.Area.Explorer.SqlBackground</class> whose job runs its statement through
/// <class>OcuPilot.Test.SqlPortDelayed</class>, so a cancel sent as soon as the run begins reaches a
/// job that runs no statement yet. Everything else, the instance cap among it, is the production
/// class's.</p>
Class OcuPilot.Test.SqlBackgroundDelayed Extends OcuPilot.Area.Explorer.SqlBackground
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.SqlPortDelayed"
}

}
