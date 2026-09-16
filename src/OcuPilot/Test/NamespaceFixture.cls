/// <p>Test-only <class>OcuPilot.Api.Namespaces</class> subclass. It overrides the handler's two
/// seams so the list's rules can be driven in process:</p>
/// <ul>
/// <li><method>GateClass</method> answers from <class>OcuPilot.Test.ScreenGate</class>'s declared
/// set instead of the instance. <code>%UnitTest</code> runs as an account holding
/// <code>%All</code>, for which the real <code>$System.Security.Check</code> answers yes to every
/// resource name, so neither the read filter nor the write verdict could be observed against it.
/// The real check is exercised over the wire by <class>OcuPilot.Test.Wire</class>.</li>
/// <li><method>NamespaceNames</method> can be given a fixture roster, so the implicit-namespace
/// filter can be exercised on an instance that has none. Unarmed, it answers the instance's own
/// roster.</li>
/// </ul>
/// <p>The armed roster lives in a process-private global, cleared by <method>Reset</method>, so
/// nothing survives the process that armed it.</p>
Class OcuPilot.Test.NamespaceFixture Extends OcuPilot.Api.Namespaces
{

/// <p>Forget the armed roster, so <method>NamespaceNames</method> answers the instance again.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotNamespaceRoster
}

/// <p>Arm the roster: <var>pNames</var> is a comma-separated list of namespace names, used
/// verbatim and in the order given.</p>
ClassMethod Arm(pNames As %String)
{
    Kill ^||OcuPilotNamespaceRoster
    Set ^||OcuPilotNamespaceRoster = pNames
}

ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.ScreenGate"
}

ClassMethod NamespaceNames(Output pList As %List) As %Status
{
    Set tArmed = $Get(^||OcuPilotNamespaceRoster)
    If tArmed = "" Quit ##super(.pList)
    Set pList = ""
    For tI = 1:1:$Length(tArmed, ",") {
        Set tName = $Piece(tArmed, ",", tI)
        If tName '= "" Set pList = pList _ $ListBuild(tName)
    }
    Quit $$$OK
}

}
