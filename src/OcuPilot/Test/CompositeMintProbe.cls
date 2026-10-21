/// <p>Test-only stand-in for both things a mint is handed besides its arguments: the tool class
/// (<code>pToolClass</code>) and the port that tool's fresh read goes through. Its
/// <method>PortClass</method> answers this class, and <method>Invoke</method> answers every read as
/// the <method>SetMode</method> in force says, so a mint's target is absent, present, or refused by
/// the port with the target's own id in the refusal text. It declares no row key and no read type, so
/// the kernel's defaults apply.</p>
/// <p>Used by <class>OcuPilot.Test.CompositeMintSweep</class> to drive each shipped composite-id mint to
/// a refusal with no instance state behind it. <method>Calls</method> counts the reads, which is what
/// shows the refusal came from the read and not from an earlier argument check.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.CompositeMintProbe Extends %RegisteredObject
{

/// <p>The mode in which every read is a 404: the target is absent.</p>
Parameter ABSENT = "absent";

/// <p>The mode in which every read answers an empty object: the target is present, and the tool creates.</p>
Parameter PRESENT = "present";

/// <p>The mode in which the port refuses the read with a 409 whose <code>detail.problem</code> names the
/// target's id as the read was asked it.</p>
Parameter REFUSED = "refused";

/// <p>The port this tool's target lives behind: this class.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.CompositeMintProbe"
}

/// <p>Whether the tool creates its target: only in <parameter>PRESENT</parameter> mode, where a create of a
/// target that is there is what is refused.</p>
ClassMethod Creates() As %Boolean
{
    Quit (..Mode() = ..#PRESENT)
}

/// <p>The create check <class>OcuPilot.Screen.Tool.EncryptionKeyFileMint</class> asks its port before the read:
/// the name is admitted.</p>
ClassMethod CheckCreate(pRoot As %String, pPath As %String, Output pResolved As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResolved = pRoot _ pPath
    Set pHttpStatus = 0
    Set pFault = ""
    Quit $$$OK
}

/// <p>Answer the read of <var>pEndpoint</var> as the mode in force says. The signature is the shape
/// <method>OcuPilot.Kernel.Proposal.Operation.ReadTarget</method> calls a port with.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pUser As %String = "") As %Status
{
    Set ^||OcuPilotCompositeMintProbe("calls") = $Get(^||OcuPilotCompositeMintProbe("calls")) + 1
    Set pResult = ""
    Set pFault = ""
    Set tMode = ..Mode()
    If tMode = ..#PRESENT {
        Set pResult = {}
        Set pHttpStatus = 200
        Quit $$$OK
    }
    If tMode = ..#REFUSED {
        Set pHttpStatus = 409
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#PORTCONFLICT, "The probe port refused the read.")
        Do pFault.%Set("detail", {"problem": ("the probe port refused '" _ $Get(pQuery("id")) _ "'")})
        Quit $$$ERROR($$$GeneralError, "the probe port refused the read")
    }
    Set pHttpStatus = 404
    Quit $$$ERROR($$$GeneralError, "the probe holds no target")
}

/// <p>Set the mode every later read answers in: <parameter>ABSENT</parameter>, <parameter>PRESENT</parameter> or
/// <parameter>REFUSED</parameter>.</p>
ClassMethod SetMode(pMode As %String)
{
    Set ^||OcuPilotCompositeMintProbe("mode") = pMode
}

/// <p>The mode in force: <parameter>ABSENT</parameter> until <method>SetMode</method> says otherwise.</p>
ClassMethod Mode() As %String
{
    Quit $Get(^||OcuPilotCompositeMintProbe("mode"), ..#ABSENT)
}

/// <p>How many reads <method>Invoke</method> has answered since <method>Reset</method>.</p>
ClassMethod Calls() As %Integer
{
    Quit +$Get(^||OcuPilotCompositeMintProbe("calls"))
}

/// <p>Zero the count and return to <parameter>ABSENT</parameter> mode.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotCompositeMintProbe
}

}
