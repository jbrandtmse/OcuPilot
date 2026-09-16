/// <p>Test-only <class>OcuPilot.Api.Definitions</class> subclass whose wire-field table is missing
/// one of the definition's security properties, so DW-363's conservative fallback can be
/// executed.</p>
/// <p><b>Why a subclass is the only way in.</b>
/// <method>OcuPilot.Kernel.State.Agent.SecurityFields</method> names six properties and
/// <method>OcuPilot.Api.Definitions.Fields</method> maps all six, so
/// <method>OcuPilot.Api.Definitions.SecurityFieldNames</method> reports the translation complete on
/// every call the shipped tree can make. The branch that matters -- a security property the
/// translation silently dropped, which no comparison can then see -- is reachable only by removing
/// a mapping, and removing it here leaves the shipped table alone.</p>
/// <p>It overrides nothing else, so the two readers under test
/// (<method>OcuPilot.Api.Definitions.MatchesStoredSecurityFields</method> and
/// <method>OcuPilot.Api.Definitions.IsSecurityChange</method>) are the shipped methods running
/// over a shortened list.</p>
Class OcuPilot.Test.DefinitionsFieldGapProbe Extends OcuPilot.Api.Definitions
{

/// <p>The state-class property whose wire mapping this probe drops. It is a security property:
/// <method>OcuPilot.Kernel.State.Agent.SecurityFields</method> names it, which is what makes its
/// absence from the table below an incomplete translation rather than an ordinary omission.</p>
Parameter DROPPEDPROPERTY = "CredentialName";

/// <p><method>OcuPilot.Api.Definitions.Fields</method> with the
/// <parameter>DROPPEDPROPERTY</parameter> entry removed. Filtered from the superclass's own list
/// rather than restated, so a field added there is carried here too.</p>
ClassMethod Fields() As %List
{
    Set tOut = ""
    Set tFields = ##super()
    For tI = 1:1:$ListLength(tFields) {
        Set tEntry = $List(tFields, tI)
        If $List(tEntry, 2) = ..#DROPPEDPROPERTY Continue
        Set tOut = tOut _ $ListBuild(tEntry)
    }
    Quit tOut
}

}
