/// <p>AD-37's ownership bound on credential entries: OcuPilot overwrites only an entry it created
/// (DW-342), matches references exactly as the vendor keys them (DW-408), says what became of an
/// entry a definition stopped naming (DW-411), and hands its mark on so an entry it created does
/// not outlive every definition that named it (DW-428).</p>
/// <p>The writes are driven over HTTP through the shipped <code>/api/ocupilot</code> routes as the
/// suite's own account; <method>OcuPilot.Api.Definitions.ClearOwnedCredential</method>'s outcomes
/// are driven in process through <class>OcuPilot.Test.DefinitionsProbe</class>, whose credential
/// seam reaches the unreachable and failing rungs no request can.</p>
/// <p><b>Self-cleaning</b>: every definition is named with <parameter>PROBEPREFIX</parameter> and
/// every credential entry with one of this class's own references, and both are removed before
/// and after each method with an assertion that none survives.</p>
Class OcuPilot.Test.CredentialOwnership Extends %UnitTest.TestCase
{

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>The reference most legs share.</p>
Parameter OWNEDCREDENTIAL = "OcuPilotProbeOwnedCredential";

/// <p>A second reference, for the leg that repoints a definition.</p>
Parameter OTHERCREDENTIAL = "OcuPilotProbeOtherCredential";

/// <p>Two references that differ only in case.</p>
Parameter UPPERCREDENTIAL = "OcuPilotProbeCaseCredential";

/// <p>See <parameter>UPPERCREDENTIAL</parameter>.</p>
Parameter LOWERCREDENTIAL = "ocupilotprobecasecredential";

/// <p>An operator's key, shaped for the shipped <code>anthropic</code> row.</p>
Parameter OPERATORKEY = "sk-ant-ocupilotoperatorprobe000000";

/// <p>A key posted through the route.</p>
Parameter POSTEDKEY = "sk-ant-ocupilotpostedprobe00000000";

/// <p>A second key posted through the route.</p>
Parameter SECONDKEY = "sk-ant-ocupilotsecondprobe00000000";

/// <p>A key that does not begin with the shipped <code>anthropic</code> row's prefix.</p>
Parameter WRONGSHAPEKEY = "not-an-anthropic-key-ocupilotprobe";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.DefinitionsProbe).Forget()
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Do ..RemoveEntries()
    Quit ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.DefinitionsProbe).Forget()
    Do ##class(OcuPilot.Test.SecretProbe).Forget()
    Do ##class(OcuPilot.Test.FakeCredentialRow).Clear()
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no " _ ..#PROBEPREFIX _ " definition survives this class")
    Do ..RemoveEntries()
    For tName = ..#OWNEDCREDENTIAL, ..#OTHERCREDENTIAL, ..#UPPERCREDENTIAL, ..#LOWERCREDENTIAL {
        Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(tName), 0, "no credential entry " _ tName _ " survives this class")
    }
    Quit $$$OK
}

/// <p>Remove every credential entry this class names.</p>
ClassMethod RemoveEntries()
{
    For tName = ..#OWNEDCREDENTIAL, ..#OTHERCREDENTIAL, ..#UPPERCREDENTIAL, ..#LOWERCREDENTIAL {
        Do ##class(OcuPilot.Test.CredentialFixture).Remove(tName)
    }
}

/// <p>One request to the definitions surface as the suite's own credentials.</p>
ClassMethod Call(pMethod As %String, pSuffix As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ "/agent/definitions" _ pSuffix, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .tHeaders, pBody, "application/json")
}

/// <p>Create a definition on the credentials rung naming <var>pReference</var>, over the wire;
/// its id, or <code>""</code>.</p>
Method Create(pSuffix As %String, pReference As %String) As %String
{
    Set tSC = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ pSuffix _ """,""provider"":""anthropic"",""credType"":""creds"",""credentialName"":""" _ pReference _ """}", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, pSuffix _ ": the create request completes")
    Do $$$AssertEquals(tStatus, 201, pSuffix _ ": the definition is created (" _ tBody _ ")")
    If tStatus '= 201 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tBody).id
}

/// <p>Post <var>pKey</var> to definition <var>pId</var>; the HTTP status, and the body in
/// <var>pBody</var>.</p>
Method Store(pId As %String, pKey As %String, Output pBody As %String) As %Integer
{
    Set tSC = ..Call("POST", "/" _ pId _ "/credential", ##class(OcuPilot.Test.CredentialFixture).PayloadText(pKey), .tStatus, .pBody)
    Do $$$AssertStatusOK(tSC, pId _ ": the store request completes")
    Do $$$AssertEquals(pBody [ pKey, 0, pId _ ": and its answer carries no part of the key")
    Quit tStatus
}

/// <p>Delete definition <var>pId</var> over the wire, asserting it was accepted.</p>
Method Delete(pId As %String)
{
    Set tSC = ..Call("DELETE", "/" _ pId, "", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, pId _ ": the delete request completes")
    Do $$$AssertEquals(tStatus, 200, pId _ ": and is accepted (" _ tBody _ ")")
}

/// <p><code>Enabled|ConnectionVerified|CredentialCreated</code> for definition <var>pId</var>.</p>
ClassMethod FlagsOf(pId As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) || '$IsObject(tRow) Quit "unreadable"
    Quit tRow.Enabled _ "|" _ tRow.ConnectionVerified _ "|" _ tRow.CredentialCreated
}

/// <p><b>DW-342, reference only</b> -- naming an entry OcuPilot did not create, on a create and on
/// an update, writes nothing to it and claims nothing.</p>
Method TestNamingAnExistingEntryWritesNothing()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Secret.Ladder).Store(..#OWNEDCREDENTIAL, ##class(OcuPilot.Test.CredentialFixture).Payload(..#OPERATORKEY), "apiKey"), "an operator's own entry exists")
    Set tCreated = ..Create("RefCreate", ..#OWNEDCREDENTIAL)
    Set tUpdated = ..Create("RefUpdate", ..#OTHERCREDENTIAL)
    If (tCreated = "") || (tUpdated = "") Quit
    Set tSC = ..Call("PUT", "/" _ tUpdated, "{""credentialName"":""" _ ..#OWNEDCREDENTIAL _ """}", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "the update request completes")
    Do $$$AssertEquals(tStatus, 200, "and a definition repointed at the operator's entry is accepted: " _ tBody)
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#OWNEDCREDENTIAL) = ..#OPERATORKEY, "the operator's entry still holds the operator's key")
    Do $$$AssertEquals($Piece(..FlagsOf(tCreated), "|", 3), 0, "and neither the created definition")
    Do $$$AssertEquals($Piece(..FlagsOf(tUpdated), "|", 3), 0, "nor the updated one claims it")
}

/// <p><b>DW-342, store refused</b> -- a key posted to a definition whose reference names an entry
/// no definition owns is refused <code>AGENT.CREDENTIAL.NOTOWNED</code> with its published
/// sentence, before any write: the entry keeps its value, and neither the posted definition nor its
/// sibling is disabled. A key of the wrong shape is refused on its shape first.</p>
/// <p>Mutation: pass may-overwrite unconditionally from
/// <method>OcuPilot.Api.Definitions.HandleStoreCredential</method> -- this goes red at 200, the
/// operator's entry overwritten and both definitions disabled.</p>
Method TestAStoreOverAnEntryNoDefinitionOwnsIsRefused()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Secret.Ladder).Store(..#OWNEDCREDENTIAL, ##class(OcuPilot.Test.CredentialFixture).Payload(..#OPERATORKEY), "apiKey"), "an operator's own entry exists")
    Set tPosted = ..Create("NotOwnedPosted", ..#OWNEDCREDENTIAL)
    Set tSibling = ..Create("NotOwnedSibling", ..#OWNEDCREDENTIAL)
    If (tPosted = "") || (tSibling = "") Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tPosted, 1, 1), "the posted definition is enabled and verified")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tSibling, 1, 1), "and so is its sibling")

    Set tShapeStatus = ..Store(tPosted, ..#WRONGSHAPEKEY, .tShapeBody)
    Do $$$AssertEquals(tShapeStatus, 422, "a key of the wrong shape is refused: " _ tShapeBody)
    If tShapeStatus = 422 {
        Set tShapeViolations = ##class(%DynamicObject).%FromJSON(tShapeBody).detail.violations
        Do $$$AssertEquals($Select($IsObject(tShapeViolations): tShapeViolations.%Get(0).code, 1: ""), "AGENT.KEY.SHAPE", "on its shape, which is judged before ownership: " _ tShapeBody)
    }

    Set tStatus = ..Store(tPosted, ..#POSTEDKEY, .tBody)
    Do $$$AssertEquals(tStatus, 422, "the store is refused: " _ tBody)
    If tStatus = 422 {
        Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).code, "AGENT.VALIDATION", "under the agent validation code")
        Do $$$AssertEquals(##class(OcuPilot.Test.AgentWire).ViolationsOf(tBody), ##class(OcuPilot.Test.AgentWire).ViolationsText($ListBuild($ListBuild("apiKey", "AGENT.CREDENTIAL.NOTOWNED", ##class(OcuPilot.Api.Error).#REASONAGENTCREDENTIALNOTOWNED))), "with one violation on apiKey carrying its published sentence")
    }
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#OWNEDCREDENTIAL) = ..#OPERATORKEY, "the operator's entry still holds the operator's key")
    Do $$$AssertEquals(..FlagsOf(tPosted), "1|1|0", "the posted definition is unchanged")
    Do $$$AssertEquals(..FlagsOf(tSibling), "1|1|0", "and so is its sibling")
}

/// <p><b>DW-342, owned overwrite</b> -- once a definition has created the entry, it may store over
/// it again, and so may a sibling naming the same reference.</p>
Method TestAnOwnedEntryMayBeOverwrittenByItsOwnerOrASibling()
{
    Set tOwner = ..Create("OwnedOwner", ..#OWNEDCREDENTIAL)
    Set tSibling = ..Create("OwnedSibling", ..#OWNEDCREDENTIAL)
    If (tOwner = "") || (tSibling = "") Quit
    Do $$$AssertEquals(..Store(tOwner, ..#POSTEDKEY, .tFirst), 200, "the first store creates the entry: " _ tFirst)
    Do $$$AssertEquals($Piece(..FlagsOf(tOwner), "|", 3), 1, "and marks its definition the owner")
    Do $$$AssertEquals(..Store(tOwner, ..#SECONDKEY, .tSecond), 200, "the owner may store over it: " _ tSecond)
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#OWNEDCREDENTIAL) = ..#SECONDKEY, "and the entry holds the owner's new key")
    Do $$$AssertEquals(..Store(tSibling, ..#POSTEDKEY, .tThird), 200, "a sibling naming the owned entry may store over it too: " _ tThird)
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#OWNEDCREDENTIAL) = ..#POSTEDKEY, "and the entry holds the sibling's key")
}

/// <p><b>DW-408</b> -- two references that differ only in case are two entries to the vendor, so
/// they are not siblings: a store through one does not disable the other, and deleting one does
/// not keep the other's entry alive.</p>
/// <p>Mutation: drop <code>%EXACT</code> from
/// <method>OcuPilot.Kernel.State.Agent.GuardedIdsByCredentialName</method> -- the flag assertion goes
/// red, the other definition swept, and so does the entry assertion, the other definition counted
/// as a survivor.</p>
Method TestReferencesDifferingOnlyInCaseAreNotSiblings()
{
    Set tPayload = ##class(OcuPilot.Test.CredentialFixture).Payload(..#POSTEDKEY)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Secret.Ladder).Store(..#UPPERCREDENTIAL, tPayload, "apiKey"), "the vendor accepts an entry under one case")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Secret.Ladder).Store(..#LOWERCREDENTIAL, ##class(OcuPilot.Test.CredentialFixture).Payload(..#SECONDKEY), "apiKey"), "and a second under the other, as a new entry rather than an overwrite")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#UPPERCREDENTIAL) = ..#POSTEDKEY, "the first holds its own key")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#LOWERCREDENTIAL) = ..#SECONDKEY, "and the second its own: the vendor keeps two distinct entries")
    Do ..RemoveEntries()

    Set tUpper = ..Create("CaseUpper", ..#UPPERCREDENTIAL)
    Set tLower = ..Create("CaseLower", ..#LOWERCREDENTIAL)
    If (tUpper = "") || (tLower = "") Quit
    Do $$$AssertEquals(..Store(tUpper, ..#POSTEDKEY, .tUpperBody), 200, "one definition creates its entry: " _ tUpperBody)
    Do $$$AssertEquals(..Store(tLower, ..#SECONDKEY, .tLowerBody), 200, "and the other creates its own: " _ tLowerBody)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tLower, 1, 1), "the second definition is enabled and verified")

    Do $$$AssertEquals(..Store(tUpper, ..#SECONDKEY, .tAgain), 200, "a second store through the first definition is accepted: " _ tAgain)
    Do $$$AssertEquals(..FlagsOf(tLower), "1|1|1", "and the other definition is not swept, because it names a different entry")

    Do ..Delete(tUpper)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#UPPERCREDENTIAL), 0, "deleting the first removes its entry: the other definition does not name it")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#LOWERCREDENTIAL), 1, "and leaves the other entry alone")
}

/// <p><b>DW-342 with case</b> -- ownership is matched exactly as well: a definition owning one
/// entry does not license a store over an operator's entry whose reference differs from it only in
/// case.</p>
/// <p>Mutation: drop <code>%EXACT</code> from
/// <method>OcuPilot.Kernel.State.Agent.GuardedCredentialOwned</method> -- this goes red at 200, the
/// operator's entry overwritten.</p>
Method TestOwningAnEntryDoesNotLicenseOneDifferingOnlyInCase()
{
    Set tOwner = ..Create("OwnCaseOwner", ..#UPPERCREDENTIAL)
    Set tOther = ..Create("OwnCaseOther", ..#LOWERCREDENTIAL)
    If (tOwner = "") || (tOther = "") Quit
    Do $$$AssertEquals(..Store(tOwner, ..#POSTEDKEY, .tOwnerBody), 200, "one definition creates and owns its entry: " _ tOwnerBody)
    Do $$$AssertEquals($Piece(..FlagsOf(tOwner), "|", 3), 1, "and carries the mark")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Secret.Ladder).Store(..#LOWERCREDENTIAL, ##class(OcuPilot.Test.CredentialFixture).Payload(..#OPERATORKEY), "apiKey"), "an operator's own entry exists under the reference differing only in case")

    Set tStatus = ..Store(tOther, ..#SECONDKEY, .tBody)
    Do $$$AssertEquals(tStatus, 422, "a store through the definition naming the operator's entry is refused: " _ tBody)
    If tStatus = 422 Do $$$AssertEquals(##class(OcuPilot.Test.AgentWire).ViolationsOf(tBody), ##class(OcuPilot.Test.AgentWire).ViolationsText($ListBuild($ListBuild("apiKey", "AGENT.CREDENTIAL.NOTOWNED", ##class(OcuPilot.Api.Error).#REASONAGENTCREDENTIALNOTOWNED))), "as not owned")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#LOWERCREDENTIAL) = ..#OPERATORKEY, "the operator's entry still holds the operator's key")
    Do $$$AssertTrue(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#UPPERCREDENTIAL) = ..#POSTEDKEY, "and the owned entry still holds its own")
}

/// <p><b>DW-428</b> -- when the owner of an entry leaves, by deletion or by being repointed, the
/// ownership mark moves to the lowest-id surviving definition, so the entry is still removed with
/// the last definition that names it.</p>
/// <p>Mutation: remove the mark move from
/// <method>OcuPilot.Api.Definitions.ClearOwnedCredential</method> -- the entry survives the second
/// delete and this goes red. Drop the mark reset on a changed reference from
/// <method>OcuPilot.Kernel.State.Agent.GuardedUpdate</method> -- the repointed former owner still
/// carries the mark and this goes red.</p>
Method TestTheMarkMovesWhenTheOwnerLeaves()
{
    Set tOwner = ..Create("MarkOwner", ..#OWNEDCREDENTIAL)
    Set tSurvivor = ..Create("MarkSurvivor", ..#OWNEDCREDENTIAL)
    If (tOwner = "") || (tSurvivor = "") Quit
    Do $$$AssertEquals(..Store(tOwner, ..#POSTEDKEY, .tBody), 200, "the owner creates the entry: " _ tBody)
    Do ..Delete(tOwner)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#OWNEDCREDENTIAL), 1, "the entry is kept while a definition still names it")
    Do $$$AssertEquals($Piece(..FlagsOf(tSurvivor), "|", 3), 1, "and the survivor now carries the mark")
    Do ..Delete(tSurvivor)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#OWNEDCREDENTIAL), 0, "so deleting the last definition that names it removes it")

    Set tRepointed = ..Create("MarkRepointed", ..#OWNEDCREDENTIAL)
    Set tHeir = ..Create("MarkHeir", ..#OWNEDCREDENTIAL)
    If (tRepointed = "") || (tHeir = "") Quit
    Do $$$AssertEquals(..Store(tRepointed, ..#POSTEDKEY, .tRepointBody), 200, "a second owner creates the entry again: " _ tRepointBody)
    Set tSC = ..Call("PUT", "/" _ tRepointed, "{""credentialName"":""" _ ..#OTHERCREDENTIAL _ """}", .tStatus, .tPutBody)
    Do $$$AssertStatusOK(tSC, "the repoint request completes")
    Do $$$AssertEquals(tStatus, 200, "and is accepted: " _ tPutBody)
    Do $$$AssertEquals($Piece(..FlagsOf(tHeir), "|", 3), 1, "and the definition still naming the entry carries the mark")
    Do $$$AssertEquals($Piece(..FlagsOf(tRepointed), "|", 3), 0, "while the repointed former owner no longer does")
}

/// <p><b>DW-411</b> -- <method>OcuPilot.Api.Definitions.ClearOwnedCredential</method> answers what
/// became of the entry in each of its six cases, so the change record can say it: kept, not owned,
/// removed, absent, unreachable, failed -- and nothing for a reference that names nothing.</p>
/// <p>Driven in process through <class>OcuPilot.Test.DefinitionsProbe</class>, whose credential
/// seam selects <class>OcuPilot.Test.SecretNotInterop</class> for the unreachable rung,
/// <class>OcuPilot.Test.SecretProbe</class> armed to raise for a store that raises, and
/// <class>OcuPilot.Test.SecretFakeRung</class>, whose entries refuse every delete, for a store that
/// refuses.</p>
/// <p>Mutation: drop the <code>CLEARFAILED</code> outcome from
/// <method>OcuPilot.Kernel.Secret.Ladder.Clear</method>'s refused-delete branch -- the refusing leg
/// goes red, answering <code>absent</code>.</p>
Method TestClearingAnEntryAnswersWhatBecameOfIt()
{
    Set tProbe = "OcuPilot.Test.DefinitionsProbe"
    Set tNamer = ..Create("ClearNamer", ..#OWNEDCREDENTIAL)
    If tNamer = "" Quit
    Do $$$AssertEquals($ClassMethod(tProbe, "ClearOwnedCredential", "", "", 1), "", "a reference that names nothing answers nothing")
    Do $$$AssertEquals($ClassMethod(tProbe, "ClearOwnedCredential", ..#OWNEDCREDENTIAL, "", 0), "kept", "a surviving definition keeps the entry")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Secret.Ladder).Store(..#OTHERCREDENTIAL, ##class(OcuPilot.Test.CredentialFixture).Payload(..#OPERATORKEY), "apiKey"), "an entry no definition names exists")
    Do $$$AssertEquals($ClassMethod(tProbe, "ClearOwnedCredential", ..#OTHERCREDENTIAL, "", 0), "notOwned", "an entry OcuPilot did not create is not its to remove")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#OTHERCREDENTIAL), 1, "and it is still there")

    Do ##class(OcuPilot.Test.DefinitionsProbe).SetSecretClass("OcuPilot.Test.SecretNotInterop")
    Do $$$AssertEquals($ClassMethod(tProbe, "ClearOwnedCredential", ..#OTHERCREDENTIAL, "", 1), "unreachable", "a rung this namespace cannot reach removes nothing and says so")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#OTHERCREDENTIAL), 1, "and the entry is still there")

    Do ##class(OcuPilot.Test.DefinitionsProbe).SetSecretClass("OcuPilot.Test.SecretProbe")
    Do ##class(OcuPilot.Test.SecretProbe).SetRungAvailable("raise")
    Do $$$AssertEquals($ClassMethod(tProbe, "ClearOwnedCredential", ..#OTHERCREDENTIAL, "", 1), "failed", "a store that raises on the delete answers failed")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#OTHERCREDENTIAL), 1, "and the entry is still there")
    Do ##class(OcuPilot.Test.SecretProbe).Forget()

    Do ##class(OcuPilot.Test.DefinitionsProbe).SetSecretClass("OcuPilot.Test.SecretFakeRung")
    Do ##class(OcuPilot.Test.FakeCredentialRow).SetPassword(..#OTHERCREDENTIAL, "unused")
    Do $$$AssertEquals($ClassMethod(tProbe, "ClearOwnedCredential", ..#OTHERCREDENTIAL, "", 1), "failed", "a store that refuses the delete answers failed")
    Do $$$AssertEquals(##class(OcuPilot.Test.FakeCredentialRow).%ExistsId(..#OTHERCREDENTIAL), 1, "and its entry is still there")
    Do ##class(OcuPilot.Test.FakeCredentialRow).Clear()
    Do ##class(OcuPilot.Test.DefinitionsProbe).SetSecretClass("OcuPilot.Test.SecretProbe")

    Do $$$AssertEquals($ClassMethod(tProbe, "ClearOwnedCredential", ..#OTHERCREDENTIAL, "", 1), "removed", "an owned entry no definition names is removed")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#OTHERCREDENTIAL), 0, "and is gone")
    Do $$$AssertEquals($ClassMethod(tProbe, "ClearOwnedCredential", ..#OTHERCREDENTIAL, "", 1), "absent", "and a second attempt finds it absent")
}

}
