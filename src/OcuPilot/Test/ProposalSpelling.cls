/// <p>AD-34 over two spellings of one web application (DW-1359): the atomic transition has one
/// winner per <b>target</b>, not per spelling of one, so a second confirm of a re-cased or
/// slash-suffixed id neither wins nor reaches the vendor write.</p>
/// <p>Two mechanisms carry that, and a method each drives one. The sibling cancel needs the two
/// rows to hold one <property>OcuPilot.Kernel.State.Propose.TargetRef</property>, which is
/// <method>OcuPilot.Kernel.EntityRef.Key</method>'s normalization. The per-target lock needs the
/// ref a row stored to be read as the target it names even when the row holds a second spelling,
/// which is <method>OcuPilot.Kernel.EntityRef.Canonical</method> at the point of use. Neither is
/// pinned by two refs producing one key -- <method>OcuPilot.Test.EntityRef.
/// TestAWebApplicationIdReachesAKeyInOneSpelling</method> asserts that, and it is the necessary
/// condition only; what is asserted here is that the second write is absent.</p>
/// <p>Two further methods carry the ends that normalization is only useful between: the shipped
/// mint stores the canonical target for a non-canonical id, and a confirm whose stored target is
/// the canonical id still writes to an application the instance holds under a different
/// spelling.</p>
/// <p><b>What it needs from the environment:</b> an account holding <code>%All</code>, the
/// instance's own administration API through the shipped port, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not, because this class creates and
/// deletes web applications -- <method>OcuPilot.Test.ProposalFixture.EnsureWriteTarget</method>'s
/// own and <method>EnsureCaseTarget</method>'s, each of which refuses to adopt one it did not
/// make. Only <file>scripts/ci-throwaway.sh</file> sets the variable.</p>
/// <p>It writes to that probe application through a real confirm and reads it back through the
/// shipped port; every proposal it seeds names a turn <method>OnAfterOneTest</method> removes.</p>
Class OcuPilot.Test.ProposalSpelling Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter TOOL = "webapp.list.update";

/// <p>The probe application's path as the instance holds it,
/// <class>OcuPilot.Test.ProposalFixture</class>'s own.</p>
Parameter TARGET = "/csp/ocupilotprobeconfirm";

/// <p>The same application, spelled the way an agent might name it: re-cased and
/// slash-suffixed. The instance resolves it to <parameter>TARGET</parameter>, which
/// <method>OcuPilot.Test.ProhibitedRoute.TestTheSetNormalizesAPathTheWayTheInstanceResolvesIt</method>
/// pins against the port's own answers.</p>
Parameter OTHERSPELLING = "/CSP/OcuPilotProbeConfirm/";

/// <p>The change both proposals carry: setting a resource where none was set, the one
/// authorization change AD-10 permits. Observable on the instance, and the same end state from
/// either row so that the second row's fingerprint still covers the target after the first has
/// written -- what refuses it is then the claim, and nothing behind it.</p>
Parameter HARDENRESOURCE = "%Development";

/// <p>A second probe application, created under a spelling of its own that is not the canonical
/// one: the instance keeps a web application's name as it was created, so this is a target whose
/// own spelling differs from the id a reference to it carries.</p>
Parameter CASETARGET = "/csp/OcuPilotProbeSpellingCase";

/// <p>The Description <method>EnsureCaseTarget</method> stamps its own application with, and the
/// only one <method>RemoveCaseTarget</method> will delete.</p>
Parameter CASEMARKER = "OcuPilot spelling case probe";

/// <p>Where <method>ConfirmInSecondProcess</method> leaves its answer. A real global, not a
/// process-private one, because the two processes are the point.</p>
Parameter RESULTGLOBAL = "OcuPilotProbeSpellingResult";

/// <p>How long <method>TestASecondSpellingCannotWriteWhileAnotherConfirmIsInFlight</method> waits
/// for the jobbed confirm. It has to outlast
/// <parameter>OcuPilot.Kernel.State.Propose.CLAIMLOCKSECONDS</parameter>, which is what refuses
/// that claim.</p>
Parameter RACEWAITSECONDS = 40;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ProposalSpelling creates and deletes a web application on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ##class(OcuPilot.Test.ProposalFixture).EnsureWriteTarget($Namespace, .tCreated)
}

Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.ProposalFixture).RemoveWriteTarget()
}

Method OnAfterOneTest() As %Status
{
    Kill @("^" _ ..#RESULTGLOBAL)
    Do $$$AssertStatusOK(..Unharden(), "the probe application's resource is cleared again, so the next method starts where this one did")
    Do $$$AssertStatusOK(..RemoveCaseTarget(), "and the mixed-case probe application is gone")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>Clear the probe application's guarding resource. Only ever called for
/// <parameter>TARGET</parameter>, which this suite created.</p>
Method Unharden() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("Resource") = ""
        Set tSC = ##class(Security.Applications).Modify(..#TARGET, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create <parameter>CASETARGET</parameter> as a minimal CSP application in this namespace.</p>
/// <p><b>Its own application, never one the instance had</b>, on the same pairing
/// <method>OcuPilot.Test.ProposalFixture.EnsureWriteTarget</method> keeps: one that already
/// answers that name is a refusal rather than a silent adoption, because
/// <method>RemoveCaseTarget</method> would otherwise delete it.</p>
Method EnsureCaseTarget() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(..#CASETARGET) {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ERROR($$$GeneralError, "an application already answers " _ ..#CASETARGET _ " on this instance; this class creates its own and will not adopt one it did not make")
            Quit
        }
        Kill tProps
        Set tProps("NameSpace") = tOrigNS
        Set tProps("Description") = ..#CASEMARKER
        Set tProps("Enabled") = 1
        Set tProps("AutheEnabled") = 32
        Set tSC = ##class(Security.Applications).Create(..#CASETARGET, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove <parameter>CASETARGET</parameter> again. An application that is not there is not an
/// error; one carrying a Description other than <parameter>CASEMARKER</parameter> is, and is left
/// alone.</p>
Method RemoveCaseTarget() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Applications).Exists(..#CASETARGET, .tRow) {
            If $IsObject(tRow) && (tRow.Description = ..#CASEMARKER) {
                Set tRow = ""
                Set tSC = ##class(Security.Applications).Delete(..#CASETARGET)
            } Else {
                Set tRow = ""
                Set tSC = $$$ERROR($$$GeneralError, "the application at " _ ..#CASETARGET _ " is not this class's own, so it was left alone")
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many web applications answer the name <var>pName</var> on this instance, with the last
/// one's stored spelling in <var>pStored</var> and its guarding resource in <var>pResource</var>;
/// <code>-1</code> when that could not be read.</p>
/// <p>The predicate is SQL's own string comparison, which is case-insensitive -- which is the
/// question being asked: how many applications answer that one name, whatever spelling each is
/// stored under. A write addressed by a canonical id that failed to resolve would leave two.</p>
Method CaseRows(pName As %String, Output pStored As %String, Output pResource As %String) As %Integer
{
    Set pStored = ""
    Set pResource = ""
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name, Resource FROM Security.Applications WHERE Name = ?", pName)
        Set tCount = 0
        While tRS.%Next() {
            Set tCount = tCount + 1
            Set pStored = tRS.%Get("Name")
            Set pResource = tRS.%Get("Resource")
            If pResource = $Char(0) Set pResource = ""
        }
        If tRS.%SQLCODE < 0 Set tCount = -1
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>The scoped target <method>OcuPilot.Kernel.EntityRef.Key</method> builds for
/// <var>pPath</var> -- the ref a mint stores.</p>
ClassMethod Reference(pPath As %String) As %String
{
    Do ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", pPath, .tKey)
    Quit tKey
}

/// <p>A reference key carrying <var>pPath</var> as it came, joined by hand rather than built.</p>
/// <p>It stands for the row nothing enforced the canonical spelling on: one stored directly into
/// OcuPilot's tables, or minted before that normalization existed. Built here rather than through
/// <method>Reference</method> because that method is what normalizes.</p>
ClassMethod StoredReference(pPath As %String) As %String
{
    Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityRef).#REFSEPARATOR)
    Quit "web-application" _ tSeparator _ "instance" _ tSeparator _ pPath
}

/// <p>The probe application as the shipped port answers it now, in <var>pFresh</var>, and its
/// complete property set as one comparable string.</p>
Method Snapshot(Output pFresh As %DynamicObject) As %String
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery("name") = ..#TARGET
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the probe application reads back through the port")
    If $$$ISERR(tSC) || '$IsObject(tFresh) Quit ""
    Set pFresh = tFresh
    Quit tFresh.%ToJSON()
}

/// <p>Seed one completed turn and one live proposal against <var>pTargetRef</var> whose payload is
/// <var>pFresh</var> with <parameter>HARDENRESOURCE</parameter> set, and answer its id.</p>
/// <p>The row is built the way a mint builds one: one <method>OcuPilot.Kernel.Proposal.Mint.Merge</method>
/// over one real argument supplies the payload, the diff and the unchanged count, and the
/// fingerprint is that payload's own digest -- the relationship
/// <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> stores, so both digests
/// <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> compares match and what
/// refuses the second confirm is the claim rather than a gate in front of it.</p>
/// <p><var>pTargetRef</var> is passed rather than derived, because which spelling a row stored is
/// the whole subject here.</p>
Method Seed(pFresh As %DynamicObject, pTargetRef As %String) As %String
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Do $$$AssertNotEquals(pTargetRef, "", "the row names a scoped target")
    If pTargetRef = "" Quit ""

    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#TOOL, .tTool)
    Do $$$AssertStatusOK(tSC, "the write tool resolves")
    If $$$ISERR(tSC) || '$IsObject(tTool) Quit ""
    Set tClass = tTool.%Get("class")
    Set tArgs = {}
    Do tArgs.%Set("Resource", ..#HARDENRESOURCE, "string")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, tArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "the shipped merge runs over the fresh read")
    Do $$$AssertEquals(tProblem, "", "with no argument problem")
    If $$$ISERR(tSC) Quit ""
    Set tDiffText = tDiff.%ToJSON()
    Do $$$AssertNotEquals(tDiffText, "[]", "and the merge moved the resource, so this row is one a mint could have written")
    Set tExcludes = ""
    Set tDescriptor = $Parameter(tClass, "DESCRIPTORCLASS")
    If tDescriptor '= "" Set tExcludes = $ClassMethod(tDescriptor, "FingerprintExcludes")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tPayload, tExcludes, .tFingerprint)
    Do $$$AssertStatusOK(tSC, "and the digest is taken")
    If $$$ISERR(tSC) Quit ""

    Kill tValues
    Set tValues("user") = $Username
    Set tValues("convKey") = ""
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = ..#TOOL
    Set tValues("targetRef") = pTargetRef
    Set tValues("fingerprint") = tFingerprint
    Set tValues("arguments") = tArgs.%ToJSON()
    Set tValues("payload") = tPayload.%ToJSON()
    Set tValues("diff") = tDiffText
    Set tValues("unchangedCount") = tUnchanged
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "TargetRef"), pTargetRef, "storing the scoped target it was given")
    Quit tKey
}

/// <p>DW-1359 at the producer: the shipped mint stores the canonical target for a non-canonical
/// id, so a real tool call naming a re-cased, slash-suffixed application does not open a second
/// scoped target on it. Every other assertion here builds its reference itself; this one reads
/// back what the mint wrote.</p>
/// <p>It drives <method>OcuPilot.Screen.Tool.Write.View</method>, the one method the model
/// reaches, and writes nothing to the instance: a mint reads its target and stores a row. The row
/// names the turn seeded here, so <method>OnAfterOneTest</method> removes it.</p>
/// <p>Mutation: assemble the key by hand from <var>pIdValue</var> in
/// <method>OcuPilot.Kernel.Proposal.Mint.Mint</method>, in place of
/// <method>OcuPilot.Kernel.EntityRef.Key</method>'s answer -- the stored target is then the
/// spelling the call carried.</p>
Method TestAMintOfASecondSpellingStoresTheCanonicalTarget()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "running", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#TOOL, .tTool)
    Do $$$AssertStatusOK(tSC, "the write tool resolves")
    If $$$ISERR(tSC) || '$IsObject(tTool) Quit
    Set tClass = tTool.%Get("class")

    Set tArgs = {}
    Do tArgs.%Set($ClassMethod(tClass, "IdArgument"), ..#OTHERSPELLING, "string")
    Do tArgs.%Set("Resource", ..#HARDENRESOURCE, "string")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = $ClassMethod(tClass, "View", "", tArgs, 200, .tResult, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(tSC, "the shipped write tool mints against the second spelling")
    Do $$$AssertEquals(tHttp, 200, "answering 200")
    If $$$ISERR(tSC) || '$IsObject(tResult) Quit

    Set tKey = tResult.%Get("proposalId")
    Do $$$AssertNotEquals(..Reference(..#TARGET), ..StoredReference(..#OTHERSPELLING), "the canonical reference and the spelling the call carried are different strings")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "TargetRef"), ..Reference(..#TARGET), "and the row the mint stored carries the canonical one")
}

/// <p>DW-1359's write half: a stored reference carries the canonical id, the instance's own
/// spelling of the application need not match it, and the confirm's vendor write must still
/// address that application. <method>%Api.Admin.Endpoints.WebApp.App</method>'s
/// <code>PUT</code> modifies a name that exists and <b>creates</b> one that does not, answering
/// success either way, so an id that failed to resolve would read as a successful write while a
/// second application appeared beside the target.</p>
/// <p>The probe application every other method here uses is all lower case, so its canonical id
/// is its own spelling and this never runs. This one is created mixed-case for that reason, and
/// removed in <method>OnAfterOneTest</method>.</p>
/// <p>Mutation: canonicalize to a spelling the instance does not resolve -- strip the leading
/// slash as well as the trailing ones in
/// <method>OcuPilot.Kernel.EntityRef.NormalizedId</method>'s web-application arm -- and the
/// confirm no longer reaches this application at all.</p>
Method TestACanonicalIdStillAddressesAMixedCaseApplication()
{
    Set tSC = ..EnsureCaseTarget()
    Do $$$AssertStatusOK(tSC, "a probe application is created under a mixed-case name of its own")
    If $$$ISERR(tSC) Quit
    Set tCanonical = ##class(OcuPilot.Kernel.EntityRef).NormalizedId("web-application", ..#CASETARGET)
    Do $$$AssertNotEquals(tCanonical, ..#CASETARGET, "whose canonical id is not the spelling the instance stores it under")

    Kill tQuery
    Set tQuery("name") = tCanonical
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the canonical id reads that application back through the shipped port")
    If $$$ISERR(tSC) || '$IsObject(tFresh) Quit
    Set tRows = ..CaseRows(tCanonical, .tStored, .tBefore)
    Do $$$AssertEquals(tRows, 1, "one application answers that id before the write")
    Do $$$AssertNotEquals(tBefore, ..#HARDENRESOURCE, "and it does not carry the resource yet, so a write of it is visible")

    Set tKey = ..Seed(tFresh, ..Reference(..#CASETARGET))
    If tKey = "" Quit
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm of a row whose target is the canonical id runs")
    Do $$$AssertEquals(tHttp, 200, "and is applied: " _ tCode)

    Set tRows = ..CaseRows(tCanonical, .tAfterName, .tAfter)
    Do $$$AssertEquals(tRows, 1, "still one application answers that id, so no second one was created at the canonical spelling")
    Do $$$AssertEquals(tAfterName, ..#CASETARGET, "it is the one the instance already held, under its own spelling")
    Do $$$AssertEquals(tAfter, ..#HARDENRESOURCE, "and that application's own properties moved")
}

/// <p>DW-1359, AD-34: two live proposals against one application through two spellings are one
/// scoped target, so confirming either closes the other as its sibling and only one write goes
/// out.</p>
/// <p>The second confirm is refused at the claim -- the row is no longer live -- and its token is
/// unspent, which is what says the vendor write never followed: the port call is the first thing
/// after the claim commits.</p>
/// <p>Mutation: answer <var>pId</var> verbatim from
/// <method>OcuPilot.Kernel.EntityRef.NormalizedId</method>'s web-application arm -> the two rows
/// hold two refs, the first confirm cancels nothing, and the second confirm wins, burns its token
/// and writes. The one-target assertion, all three sibling assertions and all three refusal
/// assertions go red together.</p>
Method TestTwoSpellingsOfOneApplicationAreOneScopedTarget()
{
    Set tBefore = ..Snapshot(.tFresh)
    If tBefore = "" Quit
    Do $$$AssertNotEquals(..#TARGET, ..#OTHERSPELLING, "the two spellings are different strings")
    Set tRefOne = ..Reference(..#TARGET)
    Set tRefTwo = ..Reference(..#OTHERSPELLING)
    Do $$$AssertNotEquals(tRefOne, "", "the canonical spelling builds a ref")
    Do $$$AssertEquals(tRefTwo, tRefOne, "and both spellings name one scoped target")

    Set tFirst = ..Seed(tFresh, tRefOne)
    Set tSecond = ..Seed(tFresh, tRefTwo)
    If (tFirst = "") || (tSecond = "") Quit
    Do $$$AssertNotEquals(tFirst, tSecond, "the two rows are two proposals")

    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tFirst, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the first confirm runs")
    Do $$$AssertEquals(tHttp, 200, "and is applied: " _ tCode)
    Do ..Snapshot(.tAfterFresh)
    Set tWritten = ..ResourceOf(tAfterFresh)
    Do $$$AssertEquals(tWritten, ..#HARDENRESOURCE, "its write reached the instance")

    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSecond, "State"), "canceled", "the proposal on the other spelling closed with it")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSecond, "ClosedReason"), "sibling", "as a sibling of the target that moved")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSecond, "Burned"), 0, "with its own token unspent")

    Set tSecondSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tSecond, "", $Username, .tResultTwo, .tHttpTwo, .tCodeTwo, .tDetailTwo)
    Do $$$AssertStatusNotOK(tSecondSC, "confirming it afterwards is refused")
    Do $$$AssertEquals(tHttpTwo, 409, "at 409")
    Do $$$AssertEquals(tCodeTwo, ##class(OcuPilot.Kernel.Proposal.Write).#BURNED, "because that target has already been decided")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSecond, "Burned"), 0, "and its token is still unspent, so no second write followed")
}

/// <p>Run the shipped confirm of <var>pKey</var> for <var>pUser</var> in a second process and leave
/// its answer under <parameter>RESULTGLOBAL</parameter> as
/// <code>$ListBuild(portRead, ok, httpStatus, code, error)</code>.</p>
/// <p><var>portRead</var> is whether this process can read the target through the shipped port at
/// all, taken before the confirm. Without it a confirm that never reached the claim -- a port the
/// jobbed process could not use answers 500 with the same code a refused claim does -- would read
/// as the lock refusing the write.</p>
/// <p>JOBbed by <method>TestASecondSpellingCannotWriteWhileAnotherConfirmIsInFlight</method>; not a
/// test method, and the name deliberately does not begin with <code>Test</code>.</p>
ClassMethod ConfirmInSecondProcess(pKey As %String, pUser As %String, pSlot As %String)
{
    Set tRead = 0
    Set tHttpStatus = 0
    Set tCode = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery("name") = ..#TARGET
        Set tRead = $$$ISOK(##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)) && $IsObject(tFresh)
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(pKey, "", pUser, .tResult, .tHttpStatus, .tCode, .tDetail)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set @("^" _ ..#RESULTGLOBAL)@(pSlot) = $ListBuild(''tRead, ''$$$ISOK(tSC), +$Get(tHttpStatus), $Get(tCode), $Select($$$ISOK(tSC): "", 1: $System.Status.GetErrorText(tSC)))
    Quit
}

/// <p>DW-1359, AD-34 (the interleaving DW-1250 closed for one spelling): a confirm of a row whose
/// stored ref is a second spelling of a target another confirm is already transitioning does not
/// win, and its write does not reach the port.</p>
/// <p>The rival is played as <class>OcuPilot.Test.ProposalRace</class> plays one, and for the same
/// reason: it holds the target lock and has already run its own claim, so its row reads
/// <code>confirmed</code> from an <b>uncommitted</b> transaction. At IRIS's READ UNCOMMITTED
/// default the jobbed confirm's sibling update reads that state, matches nothing and asks for no
/// row lock, so only the target lock can order the two -- and the two rows hold two different
/// <property>OcuPilot.Kernel.State.Propose.TargetRef</property> strings here, which is the case the
/// sibling cancel's exact compare cannot reach at all. The rival's claim is raw SQL because the
/// rival must stay in flight, which the real method, which commits, cannot do.</p>
/// <p>Mutations, each reddening this alone: drop the
/// <method>OcuPilot.Kernel.EntityRef.Canonical</method> call from
/// <method>OcuPilot.Kernel.State.Propose.GuardedClaimAndClose</method>, or answer <var>pId</var>
/// verbatim from <method>OcuPilot.Kernel.EntityRef.NormalizedId</method>'s web-application arm. In
/// either case the jobbed confirm takes a lock nobody holds, wins, burns its token and writes,
/// so the untouched-application clause and the row clauses go red.</p>
Method TestASecondSpellingCannotWriteWhileAnotherConfirmIsInFlight()
{
    Kill @("^" _ ..#RESULTGLOBAL)
    Set tBefore = ..Snapshot(.tFresh)
    If tBefore = "" Quit
    Set tStartingResource = ..ResourceOf(tFresh)
    Do $$$AssertNotEquals(tStartingResource, ..#HARDENRESOURCE, "the probe application does not carry the resource yet, so a write of it is visible")

    Set tRivalRef = ..Reference(..#TARGET)
    Set tOtherRef = ..StoredReference(..#OTHERSPELLING)
    Do $$$AssertNotEquals(tOtherRef, tRivalRef, "the second row's stored ref is a second spelling of the first row's target")
    Set tRival = ..Seed(tFresh, tRivalRef)
    Set tOther = ..Seed(tFresh, tOtherRef)
    If (tRival = "") || (tOther = "") Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedRowVersion(tRival, .tRivalVersion), "the rival's version reads")

    Set tLockKey = ##class(OcuPilot.Kernel.State.Propose).TargetLockKey(tRivalRef)
    Do $$$AssertNotEquals(tLockKey, "", "the scoped target names a lock")
    Lock +^OcuPilotProposalTarget(tLockKey):5
    Set tHeld = $Test
    Do $$$AssertTrue(tHeld, "which the rival holds, as its own claim does")
    ; Without that lock there is no rival, and the jobbed confirm below wins and writes for
    ; reasons that have nothing to do with the spelling -- so stop rather than read that as the
    ; serialization working.
    If 'tHeld Quit

    TSTART
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Proposal SET Burned = 1, State = 'confirmed', RowVersion = ? WHERE %EXACT(ProposalKey) = ? AND Burned = 0 AND %EXACT(State) = 'live' AND COALESCE(RowVersion, 0) = ?", tRivalVersion + 1, tRival, tRivalVersion)
    Set tRivalClaimed = $Select(tRS.%SQLCODE < 0: -1, 1: +tRS.%ROWCOUNT)

    Job ##class(OcuPilot.Test.ProposalSpelling).ConfirmInSecondProcess(tOther, $Username, "other")::10
    Set tJobbed = $Test
    Set tWaited = 0
    While '$Data(@("^" _ ..#RESULTGLOBAL)@("other")) && (tWaited < ..#RACEWAITSECONDS) {
        Hang 1
        Set tWaited = tWaited + 1
    }
    Set tAnswer = $Get(@("^" _ ..#RESULTGLOBAL)@("other"))
    ; The rival withdraws: its row goes back to live, so what is read below is the jobbed confirm's
    ; doing and nothing else.
    TROLLBACK
    Lock -^OcuPilotProposalTarget(tLockKey)

    Do $$$AssertEquals(tRivalClaimed, 1, "the rival's own claim took its row")
    Do $$$AssertTrue(tJobbed, "a second process runs the other confirm")
    Do $$$AssertTrue(tAnswer '= "", "and answers inside the wait")
    If tAnswer = "" Quit
    Do $$$AssertEquals($ListGet(tAnswer, 1), 1, "that process can read the target through the shipped port, so its confirm reached the claim")
    Do $$$AssertEquals($ListGet(tAnswer, 2), 0, "a confirm made while another confirm of this target is in flight is refused: " _ $ListGet(tAnswer, 4) _ " " _ $ListGet(tAnswer, 5))
    Do $$$AssertEquals($ListGet(tAnswer, 3), 500, "at the status a claim that could not be taken answers")
    Do $$$AssertEquals($ListGet(tAnswer, 4), ##class(OcuPilot.Api.Error).#INTERNAL, "carrying that code")
    Do $$$AssertTrue($ListGet(tAnswer, 5) [ "another confirm of this target is in flight", "and the claim is what refused it, not a gate in front of it: " _ $ListGet(tAnswer, 5))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tOther, "Burned"), 0, "and its token is not spent")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tOther, "State"), "live", "and its row is left live for whoever claims next")
    Do $$$AssertEquals(..Snapshot(.tAfter), tBefore, "the application's properties on the instance are what they were, so the second write never reached the port")

    ; The refusal is the lock's, not the path's: released, the same row confirms and writes.
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tOther, "", $Username, .tResult, .tHttp, .tCode, .tDetail), "the same confirm then runs on its own")
    Do $$$AssertEquals(tHttp, 200, "and is applied: " _ tCode)
    Do ..Snapshot(.tFinalFresh)
    Set tFinalResource = ..ResourceOf(tFinalFresh)
    Do $$$AssertEquals(tFinalResource, ..#HARDENRESOURCE, "so the row was confirmable all along and the lock is what refused it")
}

/// <p><var>pFresh</var>'s guarding resource, or <code>""</code> when the read answered no
/// object.</p>
Method ResourceOf(pFresh As %DynamicObject) As %String
{
    If '$IsObject(pFresh) Quit ""
    Quit pFresh.%Get("Resource")
}

}
