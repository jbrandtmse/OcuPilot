/// <p>DW-1309, AD-31: <method>OcuPilot.Port.ProviderPort.Invoke</method>'s gate answers on the
/// <b>turn owner's live grants</b>, not on the calling process.</p>
/// <p>A <code>JOB</code> inherits <code>$ROLES</code> at the moment of the spawn and keeps that
/// copy for its whole life, so a grant revoked while a turn ran would still admit the provider
/// call if the gate asked the process. The port therefore asks
/// <code>$SYSTEM.Security.CheckUserPermission</code> about the account the turn belongs to, which
/// is the question AD-31 names.</p>
/// <p><b>What it needs from the environment:</b> an account holding <code>%All</code> and nothing
/// else. It opens no socket: every call names a definition or a provider the instance does not
/// hold, so the port refuses <code>PROVIDER.UNCONFIGURED</code> before any transport exists. It
/// creates no principal, writes nothing to the instance and spawns nothing.</p>
Class OcuPilot.Test.ProviderPortOwner Extends %UnitTest.TestCase
{

/// <p>The probe whose per-user answer is a switch, so a revoked grant is driven without changing
/// one on the instance.</p>
Parameter PROBE = "OcuPilot.Test.ProviderOwnerProbe";

/// <p>The account a turn in these methods belongs to. Never created: the port asks about it by
/// name, and the probe answers.</p>
Parameter OWNER = "OcuPilotProbeTurnOwner";

/// <p>An account the instance does not hold. Never created -- that is the point.</p>
Parameter ABSENTUSER = "OcuPilotProbeNoSuchAccount";

/// <p>A resource the instance does not declare. Never created, for the same reason.</p>
Parameter ABSENTRESOURCE = "OcuPilotProbeNoSuchResource";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Quit $$$OK
}

/// <p>One minimal message array, which is all the port needs to reach its gate.</p>
ClassMethod Messages(Output pMessages)
{
    Set pMessages = []
    Do pMessages.%Push({"role": "user", "content": "probe"})
}

/// <p>The first pair <parameter>OcuPilot.Port.ProviderPort.INVOKEPAIRS</parameter> declares,
/// spelled <code>resource:permission</code> -- the one this suite asks the shipped per-user check
/// about. Derived rather than written down, so a change to the administrative floor does not
/// turn this into a test of a literal.</p>
ClassMethod FirstPair() As %String
{
    Quit $Piece($Parameter("OcuPilot.Port.ProviderPort", "INVOKEPAIRS"), ",", 1)
}

/// <p><b>DW-1309.</b> The gate is evaluated against the turn owner named in the call, and a
/// revoked grant refuses even where the calling process would have passed.</p>
/// <p>This account holds <code>%All</code>, so the process check answers yes to every pair. That
/// is what makes the refusal below load-bearing: only a question about the <b>owner</b> can
/// produce it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.ProviderPort.GateAnyOfForUser</method> ask
/// <method>OcuPilot.Screen.Gate.HoldsPrivilege</method> about the calling process in place of
/// <method>HoldsPairForUser</method> -- and the refusal leg goes red, because the shipped gate
/// answers yes for this <code>%All</code> process whatever the owner holds. Set
/// <var>pFailedPair</var> to the set's first pair on a refusal -- the no-detail assertion goes
/// red.</p>
Method TestTheGateReadsTheTurnOwnersLiveGrants()
{
    Set tDenial = ##class(OcuPilot.Kernel.Denial).Code()

    ; The owner still holds the administrative floor: the call passes the gate and is refused
    ; further in, for a reason that is not a privilege refusal.
    Do $ClassMethod(..#PROBE, "Grant", ..#OWNER)
    Do ..Messages(.tMessages)
    Set tTools = []
    Set tSC = $ClassMethod(..#PROBE, "Invoke", "no-such-definition", .tMessages, .tTools, "", .tResponse, .tHttp, .tFault, ..#OWNER)
    Do $$$AssertStatusOK(tSC, "the port answers")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, "a granted owner passes the gate and is refused on the definition instead")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "AskedUsers"), ..#OWNER, "and the port asked about the turn owner, not about this process: " _ $ClassMethod(..#PROBE, "AskedUsers"))
    Do $$$AssertNotEquals(..#OWNER, $Username, "which is a different account from the one running this test, or the assertion above would say nothing")

    ; The same owner, the grant revoked while the turn ran. The process still holds %All.
    Do $ClassMethod(..#PROBE, "Reset")
    Do ..Messages(.tMessages2)
    Set tTools2 = []
    Set tSC2 = $ClassMethod(..#PROBE, "Invoke", "no-such-definition", .tMessages2, .tTools2, "", .tResponse2, .tHttp2, .tFault2, ..#OWNER)
    Do $$$AssertStatusOK(tSC2, "the port answers")
    Do $$$AssertEquals(tHttp2, ##class(OcuPilot.Kernel.Denial).#STATUS, "a revoked owner is refused 403")
    Do $$$AssertEquals($Select($IsObject(tFault2): tFault2.%Get("code"), 1: ""), tDenial, "with AUTH.NOPRIVILEGE")
    Do $$$AssertEquals($Select($IsObject(tFault2): tFault2.%GetTypeOf("detail"), 1: ""), "unassigned", "and no failedPair detail, because every pair of the OR-set failed rather than one")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "AskedUsers"), ..#OWNER, "and the refusal is about the owner, not the process")
}

/// <p><b>The shipped per-user check reaches the instance and discriminates.</b> Every other method
/// here answers through <class>OcuPilot.Test.ProviderOwnerProbe</class>'s switch, which is what lets
/// a revoked grant be driven at all -- but it also means
/// <code>$SYSTEM.Security.CheckUserPermission</code>, the one new system call this story makes, is
/// asked by nothing. This method asks it directly, on the shipped class.</p>
/// <p>It creates no principal: the discriminating case is an account the instance does not hold,
/// which holds nothing by definition. The positive case is this suite's own account, which holds
/// <code>%All</code> -- and <code>%All</code> answers yes even for a resource the instance does not
/// declare (measured on this build), so the account is the discriminator here and the resource name
/// is not.</p>
/// <p>Mutation (Rule 19): make
/// <method>OcuPilot.Port.ProviderPort.HoldsPairForUser</method> answer <code>1</code>
/// unconditionally -- the absent-account assertion goes red.</p>
Method TestTheShippedPerUserCheckAsksTheInstance()
{
    Set tPair = ..FirstPair()
    Do $$$AssertNotEquals(tPair, "", "the port declares at least one administrative pair")
    Set tResource = $Piece(tPair, ":", 1)
    Set tPermission = $Piece(tPair, ":", 2)

    Do $$$AssertEquals(##class(OcuPilot.Port.ProviderPort).HoldsPairForUser($Username, tResource, tPermission), 1, "this suite's own account holds " _ tPair)
    ; An account the instance does not hold. Not created, and deliberately not %Operator, which
    ; carries %DB_IRISSYS:RW and would answer yes to more than it should.
    Do $$$AssertEquals(##class(OcuPilot.Port.ProviderPort).HoldsPairForUser(..#ABSENTUSER, tResource, tPermission), 0, "an account the instance does not hold holds nothing")
    ; Measured on this build rather than assumed: an %All holder answers 1 for a resource the
    ; instance does not declare, so an undeclared name is no discriminator here. The absent account
    ; above is, and it is the one this method turns on.
    Do $$$AssertEquals(##class(OcuPilot.Port.ProviderPort).HoldsPairForUser(..#ABSENTUSER, ..#ABSENTRESOURCE, tPermission), 0, "and an absent account holds nothing whatever resource is named")
}

/// <p>The caller with no turn behind it is the process itself: <code>""</code> falls back to
/// <method>ResolvedUsername</method>, so a direct call is gated on the account making it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.ProviderPort.Invoke</method> pass
/// <var>pUser</var> straight through instead of falling back -- the gate is then asked about
/// <code>""</code>, which holds nothing, and this goes red at 403.</p>
Method TestNoOwnerNamedFallsBackToTheCallingProcess()
{
    Do $ClassMethod(..#PROBE, "Grant", $Username)
    Do ..Messages(.tMessages)
    Set tTools = []
    Set tSC = $ClassMethod(..#PROBE, "Invoke", "no-such-definition", .tMessages, .tTools, "", .tResponse, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the port answers")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, "a caller that named no owner is gated on its own account")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "AskedUsers"), $Username, "and that is the account the port asked about")
}

/// <p><b>Test connection is unchanged</b> (DW-1309): its caller <b>is</b> the user, so there is no
/// frozen role set to go stale and no owner to name, and <method>InvokeDraft</method> still asks
/// the calling process through the shipped gate.</p>
/// <p>The probe grants nothing to anybody, so a draft call that asked the per-user question would
/// be refused. It is not, because that entry asks a different question -- which is the whole
/// assertion.</p>
/// <p>Mutation (Rule 19): point <method>InvokeDraft</method>'s gate at
/// <method>GateAnyOfForUser</method> -- this goes red at 403.</p>
Method TestTheDraftEntryStillAsksTheCallingProcess()
{
    Do ..Messages(.tMessages)
    Set tTools = []
    Kill tValues
    Set tValues("provider") = "no-such-provider"
    Set tSC = $ClassMethod(..#PROBE, "InvokeDraft", .tValues, .tMessages, .tTools, "", .tResponse, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the draft entry answers")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#PROVIDERUNCONFIGURED, "and passes its gate as this %All process, reaching the catalog refusal")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "AskedUsers"), "", "having asked the per-user question about nobody")
}

}
