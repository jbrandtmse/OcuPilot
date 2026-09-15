/// <p>The namespace list and the request's resolved scope (AD-44, AD-21, AD-48): what
/// <code>GET /api/ocupilot/namespaces</code> reports, and that it reports it from
/// <class>OcuPilot.Kernel.Scope</class> rather than from <code>$Namespace</code>.</p>
/// <p><b>Every privilege answer here comes from a fixture seam.</b> <code>%UnitTest</code> runs
/// as an account holding <code>%All</code>, for which <code>$System.Security.Check</code>
/// answers yes to every resource name, so neither the read filter nor the write verdict could
/// be observed against the real check. <class>OcuPilot.Test.NamespaceFixture</class> points the
/// handler at <class>OcuPilot.Test.ScreenGate</class>'s declared set instead. The real check is
/// exercised over the wire by <class>OcuPilot.Test.Wire</class>, as a throwaway principal.</p>
/// <p>The mount state is <b>not</b> fixtured: it is read from the instance, and this image's
/// <code>HSLIB</code> is the read-only namespace the no-failed-pair row needs.</p>
Class OcuPilot.Test.Namespaces Extends %UnitTest.TestCase
{

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.NamespaceFixture).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.NamespaceFixture).Reset()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>AC1 -- the list is the set the caller can read, and nothing else. A principal holding
/// <code>READ</code> on one namespace's global-database resource sees that namespace and no
/// other, however many the instance has.</p>
/// <p>Mutation: drop the <code>Continue</code> after the read check in
/// <method>OcuPilot.Api.Namespaces.Payload</method> -> every namespace on the instance is
/// listed and the count assertion goes red.</p>
Method TestOnlyNamespacesTheCallerCanReadAreListed()
{
    Set tNs = $Namespace
    Do $$$AssertTrue(##class(OcuPilot.Api.Namespaces).GlobalDatabase(tNs, .tResource, .tReadOnly), "the namespace under test reports a guarding resource")

    Do ##class(OcuPilot.Test.ScreenGate).Hold(tResource, "READ")
    Set tSC = ##class(OcuPilot.Test.NamespaceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(tObject.namespaces.%Size(), 1, "exactly the one namespace whose resource is held is listed")
    Do $$$AssertEquals(tObject.namespaces.%Get(0).name, tNs, "and it is that namespace")

    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Set tEmptySC = ##class(OcuPilot.Test.NamespaceFixture).Payload(.tEmpty)
    Do $$$AssertStatusOK(tEmptySC, "the payload still builds for a principal holding nothing")
    Do $$$AssertEquals(tEmpty.namespaces.%Size(), 0, "and lists nothing rather than everything")
}

/// <p><b>DW-7</b> -- a namespace the caller can read but not write is <b>listed</b>, with
/// <code>writable:false</code> and the pair that failed, so a route already scoped there is
/// honoured and the switch has the verdict it filters on. Granting the write turns the verdict
/// over and drops the key rather than sending it empty.</p>
/// <p>Mutation: set <code>writable</code> from the read check instead of the write check in
/// <method>OcuPilot.Api.Namespaces.Payload</method> -> the first verdict and the failed-pair
/// assertion go red.</p>
Method TestAReadableNamespaceThatIsNotWritableIsListedWithItsFailedPair()
{
    Set tNs = $Namespace
    Do $$$AssertTrue(##class(OcuPilot.Api.Namespaces).GlobalDatabase(tNs, .tResource, .tReadOnly), "the namespace under test reports a guarding resource")
    Do $$$AssertEquals(tReadOnly, 0, "and is not a read-only mount, which is the other reason to refuse a write")

    Do ##class(OcuPilot.Test.ScreenGate).Hold(tResource, "READ")
    Set tSC = ##class(OcuPilot.Test.NamespaceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Set tEntry = tObject.namespaces.%Get(0)
    Do $$$AssertEquals(''tEntry.writable, 0, "read without write is not writable")
    Do $$$AssertEquals(tEntry.%Get("failedPair"), tResource _ ":WRITE", "and the entry names the pair that failed")

    Do ##class(OcuPilot.Test.ScreenGate).Hold(tResource, "WRITE")
    Set tSC2 = ##class(OcuPilot.Test.NamespaceFixture).Payload(.tObject2)
    Do $$$AssertStatusOK(tSC2, "the payload builds again")
    Set tEntry2 = tObject2.namespaces.%Get(0)
    Do $$$AssertEquals(''tEntry2.writable, 1, "holding the write makes it writable")
    Do $$$AssertEquals(''tEntry2.%IsDefined("failedPair"), 0, "and a writable entry omits the key rather than sending it empty")
}

/// <p>A read-only <b>mount</b> is not writable and carries <b>no</b> failed pair: no grant would
/// make it writable, so naming a privilege there would send the user to change something that is
/// not the reason. <code>HSLIB</code> is this image's read-only namespace.</p>
/// <p>Mutation: drop the <code>ReadOnly</code> branch from
/// <method>OcuPilot.Api.Namespaces.Payload</method> -> the entry becomes writable with the write
/// armed, and both assertions go red.</p>
Method TestAReadOnlyMountIsNotWritableAndNamesNoPair()
{
    Set tSC = ##class(OcuPilot.Api.Namespaces).NamespaceNames(.tNames)
    Do $$$AssertStatusOK(tSC, "the instance's namespace roster reads")

    Set tReadOnlyNs = ""
    Set tReadOnlyResource = ""
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        If $Extract(tName) = "^" Continue
        If '##class(OcuPilot.Api.Namespaces).GlobalDatabase(tName, .tResource, .tReadOnly) Continue
        If 'tReadOnly Continue
        Set tReadOnlyNs = tName
        Set tReadOnlyResource = tResource
        Quit
    }
    Do $$$AssertTrue(tReadOnlyNs '= "", "this image mounts at least one namespace read-only (HSLIB), which is what this row is about")
    If tReadOnlyNs = "" Quit

    ; Both permissions armed: the refusal below can then only be the mount.
    Do ##class(OcuPilot.Test.ScreenGate).Hold(tReadOnlyResource, "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold(tReadOnlyResource, "WRITE")
    Set tPayloadSC = ##class(OcuPilot.Test.NamespaceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tPayloadSC, "the payload builds")
    Do $$$AssertEquals(tObject.namespaces.%Size(), 1, "the read-only namespace is listed, because the caller can read it")
    Set tEntry = tObject.namespaces.%Get(0)
    Do $$$AssertEquals(tEntry.name, tReadOnlyNs, "and it is that namespace")
    Do $$$AssertEquals(''tEntry.writable, 0, "a read-only mount is not writable however the privileges read")
    Do $$$AssertEquals(''tEntry.%IsDefined("failedPair"), 0, "and names no pair, because the reason is the mount")
}

/// <p>An implicit namespace -- <method>%SYS.Namespace.ListAll</method> returns one
/// <code>^</code>-prefixed -- is a database addressed directly, not something a route can be
/// scoped to, and is dropped before its information is even read.</p>
/// <p>Mutation: drop the <parameter>OcuPilot.Api.Namespaces.IMPLICITPREFIX</parameter> filter ->
/// the count assertion goes red.</p>
Method TestAnImplicitNamespaceIsNotOffered()
{
    Set tNs = $Namespace
    Do $$$AssertTrue(##class(OcuPilot.Api.Namespaces).GlobalDatabase(tNs, .tResource, .tReadOnly), "the namespace under test reports a guarding resource")
    Do ##class(OcuPilot.Test.ScreenGate).Hold(tResource, "READ")

    Do ##class(OcuPilot.Test.NamespaceFixture).Arm("^^/durable/iris/mgr/," _ tNs)
    Set tSC = ##class(OcuPilot.Test.NamespaceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds over the armed roster")
    Do $$$AssertEquals(tObject.namespaces.%Size(), 1, "the implicit namespace is dropped")
    Do $$$AssertEquals(tObject.namespaces.%Get(0).name, tNs, "and the real one survives")
}

/// <p><b>DW-33</b> -- <code>scope</code> is read from <class>OcuPilot.Kernel.Scope</class>, not
/// from <code>$Namespace</code>. The stash is set to a namespace the handler is not executing
/// in, and that is what the body carries; cleared, the answer falls back to the namespace in
/// effect.</p>
/// <p>Mutation: read <code>scope</code> from <code>$Namespace</code> in
/// <method>OcuPilot.Api.Namespaces.Payload</method> -> the first assertion goes red while the
/// fallback one stays green, which is what shows the stash is what carries it.</p>
Method TestTheScopeIsReadFromTheStashAndNotFromTheExecutingNamespace()
{
    Set tExecuting = $Namespace
    Set tOther = "%SYS"
    Do $$$AssertNotEquals(tOther, tExecuting, "the stashed namespace is not the one this test executes in")

    Do ##class(OcuPilot.Kernel.Scope).Set(tOther)
    Set tSC = ##class(OcuPilot.Test.NamespaceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload builds")
    Do $$$AssertEquals(tObject.scope, tOther, "the body echoes the request's resolved scope")
    Do $$$AssertEquals($Namespace, tExecuting, "and nothing switched namespace to produce it")

    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tSC2 = ##class(OcuPilot.Test.NamespaceFixture).Payload(.tObject2)
    Do $$$AssertStatusOK(tSC2, "the payload builds with nothing stashed")
    Do $$$AssertEquals(tObject2.scope, tExecuting, "and falls back to the namespace in effect")
}

/// <p><b>DW-33</b>, through the real router -- <code>GET /namespaces?ns=%SYS</code> dispatched
/// against <class>OcuPilot.Api.Router</class> itself answers a body whose <code>scope</code> is
/// the requested namespace, resolved and stashed by the real
/// <method>OcuPilot.Api.Router.OnPreDispatch</method> and read back by the real handler. This is
/// the matrix row "the stash is consumable", end to end in one process.</p>
/// <p>The privileges are the real ones here (<code>%UnitTest</code> holds <code>%All</code>), so
/// what this pins is the resolution and the hand-off, not the refusal.</p>
/// <p>Mutation: delete the <method>OcuPilot.Kernel.Scope.Set</method> call from
/// <method>OcuPilot.Api.Router.OnPreDispatch</method> -> the scope assertion goes red with the
/// install namespace.</p>
Method TestTheResolvedNamespaceReachesTheHandlerThroughTheRouter()
{
    Set tExecuting = $Namespace
    Set tOther = "%SYS"
    Do $$$AssertNotEquals(tOther, tExecuting, "the requested namespace is not the one the application runs in")
    Do $$$AssertTrue(##class(%SYS.Namespace).Exists(tOther), "and it exists on this instance")

    Set tParams = {"ns": (tOther)}
    Set tSC = ##class(OcuPilot.Test.Dispatch).Invoke("OcuPilot.Api.Router", "/namespaces", "GET", tParams, .tBody, .tStatus)
    Do $$$AssertStatusOK(tSC, "dispatch completes")
    Do $$$AssertEquals(tStatus, 200, "the namespaces route answers")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope reaches the wire")
    Set tObject = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tObject.scope, tOther, "and the body carries the namespace the request was scoped to")
    Do $$$AssertEquals($Namespace, tExecuting, "while the process stayed in the namespace it started in")
}

/// <p><method>OcuPilot.Api.Namespaces.MayEnter</method> is the entry check the router applies,
/// and it is <code>READ</code> alone: a namespace the caller can read but not write is still
/// enterable (DW-7), and a refusal names the pair.</p>
/// <p>Mutation: require <parameter>OcuPilot.Api.Namespaces.WRITEPERMISSION</parameter> as well ->
/// the read-only-principal assertion goes red, and with it every route scoped to a namespace the
/// user may only read.</p>
Method TestEntryRequiresReadAloneAndNamesTheFailedPair()
{
    Set tNs = $Namespace
    Do $$$AssertTrue(##class(OcuPilot.Api.Namespaces).GlobalDatabase(tNs, .tResource, .tReadOnly), "the namespace under test reports a guarding resource")

    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.NamespaceFixture).MayEnter(tNs, .tFailed), "a principal holding nothing may not enter")
    Do $$$AssertEquals(tFailed, tResource _ ":READ", "and the refusal names the pair that failed")

    Do ##class(OcuPilot.Test.ScreenGate).Hold(tResource, "READ")
    Set tFailed = "unset"
    Do $$$AssertTrue(##class(OcuPilot.Test.NamespaceFixture).MayEnter(tNs, .tFailed), "the read alone admits it")
    Do $$$AssertEquals(tFailed, "", "and names nothing")
}

/// <p>A namespace whose global database reports no guarding resource cannot be verified, so it is
/// neither offered nor enterable -- the one answer that must not be read as "no privilege
/// required".</p>
Method TestANamespaceWithNoResourceIsNeitherOfferedNorEnterable()
{
    Set tAbsent = "OCUPILOTNOSUCHNS12345"
    Do $$$AssertTrue('##class(%SYS.Namespace).Exists(tAbsent), "the probe name is not a namespace on this instance")
    Do $$$AssertTrue('##class(OcuPilot.Api.Namespaces).GlobalDatabase(tAbsent, .tResource, .tReadOnly), "and reports no guarding resource")

    Set tFailed = "unset"
    Do $$$AssertTrue('##class(OcuPilot.Test.NamespaceFixture).MayEnter(tAbsent, .tFailed), "it is not enterable")
    Do $$$AssertEquals(tFailed, "", "and no pair is named, because there is no requirement to report")

    Do ##class(OcuPilot.Test.NamespaceFixture).Arm(tAbsent)
    Set tSC = ##class(OcuPilot.Test.NamespaceFixture).Payload(.tObject)
    Do $$$AssertStatusOK(tSC, "the payload still builds")
    Do $$$AssertEquals(tObject.namespaces.%Size(), 0, "and it is not offered")
}

}
