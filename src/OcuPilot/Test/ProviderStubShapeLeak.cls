/// <p>Test-only <class>OcuPilot.Test.ProviderStub</class> subclass whose
/// <method>IsApiKeyShapeValid</method> forces a real <code>^ERRORS</code> entry before answering,
/// so an entry is written while <method>OcuPilot.Api.Definitions.KeyShapeAccepted</method> -- the
/// one OcuPilot frame that moves a posted key onto an adapter -- is still live on the stack.</p>
/// <p><b>Why a second leaking adapter.</b>
/// <class>OcuPilot.Test.ProviderStub</class>'s own forced entries are raised from
/// <method>ApplyAuth</method> and <method>IssueHttpsPost</method>, which are reached only by a
/// credential being <i>used</i>; the store path never enters either.
/// <class>OcuPilot.Test.SecretStoreProbe</class> covers
/// <method>OcuPilot.Kernel.Secret.Ladder.Store</method>. This class covers the third frame, the
/// shape gate, which is where the value is assigned onto
/// <property>OcuPilot.Kernel.Provider.Base.ApiKey</property>.</p>
/// <p>The shape verdict itself is the inherited one, so what the gate answers is unchanged by the
/// instrumentation and a test can assert both the verdict and the clean entry.</p>
/// <p><b>Guarded on its own</b>, through the inherited
/// <method>OcuPilot.Test.ProviderStub.ArmErrorLog</method>: nothing is forced unless that method's
/// own arming variable reads <code>1</code>, and the inherited
/// <method>OcuPilot.Test.ProviderStub.ForceErrorLog</method> re-reads it besides. An application
/// error cannot be un-logged.</p>
Class OcuPilot.Test.ProviderStubShapeLeak Extends OcuPilot.Test.ProviderStub
{

/// <p>The identity this stub reports, so a test can tell it from its parent.</p>
Parameter STUBIDENTITY = "stub-shape-leak";

/// <p>Force one real <code>^ERRORS</code> entry in this frame when armed, then answer the shape
/// question the inherited adapter answers. The entry is written with this method's caller --
/// <method>OcuPilot.Api.Definitions.KeyShapeAccepted</method> -- live, so
/// <code>^%ETN</code> captures that frame's locals exactly as it would on a real fault.</p>
Method IsApiKeyShapeValid() As %Boolean
{
    If +$Get(^||OcuPilotProviderStubLog("armed")) Do ..ForceErrorLog()
    Quit ##super()
}

}
