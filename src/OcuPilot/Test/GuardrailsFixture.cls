/// <p><class>OcuPilot.Kernel.Shell.Guardrails</class> over a fixture prohibited set, verdict and
/// registry, for <class>OcuPilot.Test.Guardrails</class>. The set is the shipped one with one probe
/// code appended; the verdict is a kill switch held for the caller with enforced read-only on; the
/// registry is the shipped one. <code>^||OcuGuardrailsFault</code> makes one part fail:
/// <code>"verdict"</code> the verdict, <code>"tools"</code> the registry's list, and
/// <code>"secrets"</code> the secret-argument declaration of <parameter>UNDECLAREDTOOL</parameter>.</p>
Class OcuPilot.Test.GuardrailsFixture Extends OcuPilot.Kernel.Shell.Guardrails
{

/// <p>The code the fixture set appends.</p>
Parameter PROBECODE = "GUARDRAILS.PROBE";

/// <p>The probe code's sentence.</p>
Parameter PROBEREASON = "The guardrails fixture refuses its probe change.";

/// <p>The advertised write tool whose secret arguments answer undeclared under the
/// <code>"secrets"</code> fault.</p>
Parameter UNDECLAREDTOOL = "permissions.users.delete";

/// <p>This class answers the set itself.</p>
ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Test.GuardrailsFixture"
}

/// <p>The shipped codes, then <parameter>PROBECODE</parameter>.</p>
ClassMethod Codes() As %List
{
    Quit ##class(OcuPilot.Kernel.Proposal.Prohibited).Codes() _ $ListBuild(..#PROBECODE)
}

/// <p><parameter>PROBEREASON</parameter> for the probe code, and the shipped sentence for any
/// other.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#PROBECODE Quit ..#PROBEREASON
    Quit ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(pCode)
}

/// <p>This class answers the registry itself.</p>
ClassMethod RegistryClass() As %String
{
    Quit "OcuPilot.Test.GuardrailsFixture"
}

/// <p>The shipped registry's tools, or an error under the <code>"tools"</code> fault.</p>
ClassMethod ListTools(Output pTools As %DynamicArray) As %Status
{
    Set pTools = ""
    If $Get(^||OcuGuardrailsFault) = "tools" Quit $$$ERROR($$$GeneralError, "the fixture registry could not list its tools")
    Quit ##class(OcuPilot.Screen.Tool.Registry).ListTools(.pTools)
}

/// <p>The shipped registry's answer, except that <parameter>UNDECLAREDTOOL</parameter> answers no
/// names and <var>pDeclared</var> 0 under the <code>"secrets"</code> fault.</p>
ClassMethod SecretArguments(pTool As %DynamicObject, Output pDeclared As %Boolean) As %List
{
    If ($Get(^||OcuGuardrailsFault) = "secrets") && (pTool.%Get("name") = ..#UNDECLAREDTOOL) {
        Set pDeclared = 0
        Quit ""
    }
    Quit ##class(OcuPilot.Screen.Tool.Registry).SecretArguments(pTool, .pDeclared)
}

/// <p>A kill switch held for <var>pUser</var> with enforced read-only on, or an error under the
/// <code>"verdict"</code> fault.</p>
ClassMethod Verdict(pUser As %String, Output pVerdict) As %Status
{
    Kill pVerdict
    If $Get(^||OcuGuardrailsFault) = "verdict" Quit $$$ERROR($$$GeneralError, "the fixture verdict could not be read")
    Set pVerdict("blocked") = 1
    Set pVerdict("killSwitch") = 1
    Set pVerdict("killSwitchAudience") = ##class(OcuPilot.Kernel.Restraint).#AUDIENCEYOU
    Set pVerdict("enforcedReadOnly") = 1
    Quit $$$OK
}

}
