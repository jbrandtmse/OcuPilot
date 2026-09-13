/// <p>Test-only subclass of <class>OcuPilot.Install.Smoke</class> whose API reads all fail
/// without issuing a request, so <class>OcuPilot.Test.Smoke</class> can observe that the
/// sign-out check still runs after a failed read.</p>
Class OcuPilot.Test.SmokeReadFault Extends OcuPilot.Install.Smoke
{

ClassMethod CheckApiReads(ByRef pChecks, pAccessToken As %String) [ Private ]
{
    For tI = 1:1:3 {
        Do ..Note(.pChecks, $Piece("instance,namespaces,navigation", ",", tI), "fail", "induced read failure")
    }
}

}
