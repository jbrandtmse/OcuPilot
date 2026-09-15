/// <p>Test-only <class>OcuPilot.Kernel.Secret.Ladder</class> subclass that replaces
/// <method>LogCodes</method> to force a real application-error entry (<code>$$LOG^%ETN()</code>)
/// from inside that frame, instead of capturing the call the way
/// <class>OcuPilot.Test.SecretProbe</class>'s override does. <method>Store</method> and every
/// other method are inherited unchanged, so the entry is forced while the <b>shipped</b>
/// <method>Store</method> frame -- and whatever called it -- is still live on the stack.</p>
/// <p><b>Why this measures the write path and <class>OcuPilot.Test.ProviderSecret</class> does
/// not.</b> That class forces its entries from two provider-transport frames reached only by a
/// resolved credential being <i>used</i>; nothing on that path ever calls
/// <method>Store</method> or <method>OcuPilot.Api.Definitions.KeyShapeAccepted</method>, so
/// neither is ever on the stack when an entry is written. Driving a refused
/// <method>Store</method> through this class -- the shipped body calls
/// <code>..LogCodes(...)</code> on its failure branch, after the property assignment
/// <code>Set $Property(tRow, "Password") = pBody.%Get(pField)</code> has already run -- puts
/// <method>Store</method>'s own frame on the stack at the moment the entry is forced, with
/// <code>^%ETN</code> free to capture every local at every level below it exactly as it would
/// for a real refusal.</p>
/// <p><b>Guarded on its own</b>, the same discipline
/// <method>OcuPilot.Test.ProviderStub.ArmErrorLog</method> uses:
/// <parameter>ARMINGVARIABLE</parameter> must read <code>1</code>, or nothing is forced and the
/// call reports so through <var>pArmed</var>. An application error cannot be un-logged.</p>
Class OcuPilot.Test.SecretStoreProbe Extends OcuPilot.Kernel.Secret.Ladder
{

/// <p>The environment variable that arms <method>ForceErrorLog</method>, and the one value that
/// arms it: <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ERROR_SEED";

/// <p>Arm this class for the next call into <method>LogCodes</method>. Refuses through
/// <var>pArmed</var> when <parameter>ARMINGVARIABLE</parameter> does not read <code>1</code>.</p>
ClassMethod Arm(Output pArmed As %Boolean)
{
    Set pArmed = ($System.Util.GetEnviron(..#ARMINGVARIABLE) = 1)
    If 'pArmed Quit
    Set ^||OcuPilotSecretStoreProbeLog("armed") = 1
}

/// <p>Forget the arming and every entry forced so far.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotSecretStoreProbeLog
}

/// <p>Called by the shipped <method>Store</method> on its failure branches. Forces one real
/// <code>^ERRORS</code> entry <b>in this frame</b> when armed; production's own line is not
/// written in its place, which is the same trade
/// <class>OcuPilot.Test.SecretProbe</class>'s override makes.</p>
ClassMethod LogCodes(pMessage As %String, pStatus As %Status)
{
    If '+$Get(^||OcuPilotSecretStoreProbeLog("armed")) Quit
    Do ..ForceErrorLog()
}

/// <p>Raise one genuine, controlled runtime error inside this frame and log it to this
/// namespace's <code>^ERRORS</code> -- the same shape
/// <method>OcuPilot.Test.ProviderStub.ForceErrorLog</method> uses: a real <code>&lt;DIVIDE&gt;</code>
/// rather than a <code>Throw</code>, because a <code>Throw</code> leaves <code>$ZError</code>
/// empty and records the useless <code>&lt;LOG ENTRY&gt;</code> placeholder.</p>
ClassMethod ForceErrorLog() [ Private ]
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit
    Try {
        Set tZero = 0
        Set tUnreachable = 1 / tZero
    } Catch inner {
        Set ^||OcuPilotSecretStoreProbeLog("entry", $Increment(^||OcuPilotSecretStoreProbeLog("entry"))) = $$LOG^%ETN()
    }
}

/// <p>How many <code>^ERRORS</code> entries <method>ForceErrorLog</method> wrote.</p>
ClassMethod EntryCount() As %Integer
{
    Quit +$Get(^||OcuPilotSecretStoreProbeLog("entry"))
}

/// <p>The identity of entry <var>pIndex</var>, as the <code>$ListBuild(day, number)</code> the
/// trap answered, or <code>""</code>.</p>
ClassMethod Entry(pIndex As %Integer = 1) As %String
{
    Quit $Get(^||OcuPilotSecretStoreProbeLog("entry", pIndex))
}

}
