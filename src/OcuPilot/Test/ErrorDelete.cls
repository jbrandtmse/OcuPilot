/// <p>Story 5.13's suite: the application error log's by-namespace delete, end to end on the
/// instance (AD-48, AD-51, AD-52).</p>
/// <p><b>What it pins.</b> The port's enumeration is the identifying id set and resolves either
/// spelling of a namespace; the mint lists every enumerated error as a removal row; the confirm
/// removes <b>exactly</b> those ids and leaves an error logged after the proposal standing; an
/// enumerated id another party removed refuses the confirm 409 rather than deleting a cut set; two
/// spellings of one namespace are one target; and a changed field on this type is refused by the
/// prohibited set.</p>
/// <p>It also measures the per-namespace gate on the <b>confirm</b>: a purpose-built
/// least-privileged principal, holding the screen's two instance pairs and READ but not WRITE on
/// the target namespace's globals database, is refused 403 naming that pair and every error
/// survives (AD-8, AD-29, AD-48).</p>
/// <p><b>What it needs from the environment.</b> A throwaway container: it writes real application
/// errors and then deletes them, and it creates and deletes one IRIS principal.
/// <parameter>ARMINGVARIABLE</parameter>, <parameter>PRINCIPALVARIABLE</parameter> and
/// <class>OcuPilot.Test.ErrorLogSeed</class>'s own must all read <code>1</code>, and the whole
/// class refuses otherwise. It seeds every error it removes and removes nothing it did not seed --
/// except that a by-namespace delete is by namespace, so it uses
/// <parameter>TARGETNAMESPACE</parameter>, the namespace the seed class already writes to, and
/// clears it. No other class in the sweep depends on errors it did not seed itself.</p>
Class OcuPilot.Test.ErrorDelete Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone. Anything but <code>1</code> -- absent, empty, or a value that reads like a refusal --
/// refuses the whole class.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ERROR_DELETE";

/// <p>The second variable this class needs: it seeds through
/// <class>OcuPilot.Test.ErrorLogSeed</class>, which carries its own guard.</p>
Parameter SEEDVARIABLE = "OCUPILOT_ALLOW_ERROR_SEED";

/// <p>The third variable this class needs: the confirm leg below creates and deletes one IRIS
/// principal, which is what <class>OcuPilot.Test.ErrorLogDenial</class> declares this variable
/// for.</p>
Parameter PRINCIPALVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The namespace this class seeds into and clears. Not the install namespace, so a delete here
/// cannot touch the errors OcuPilot's own faults would leave.</p>
Parameter TARGETNAMESPACE = "USER";

/// <p>A namespace no instance carries, for the port's own unknown-namespace refusal.</p>
Parameter ABSENTNAMESPACE = "OCUPILOTNOSUCHNAMESPACE";

Parameter TOOL = "OcuPilot.Screen.Tool.ErrorDelete";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.LogErrorList";

Parameter PORT = "OcuPilot.Port.LogSourcePort";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The REST application's path from the origin root, which the confirm leg posts to.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>The resource guarding the database <code>SYS.ApplicationError</code> is executed from.</p>
Parameter SYSRESOURCE = "%DB_IRISSYS";

/// <p>The throwaway role and account the confirm leg is made as: the screen's two instance pairs,
/// read on the install namespace's code database, and READ but <b>not</b> WRITE on
/// <parameter>TARGETNAMESPACE</parameter>'s globals database. Both are deleted in
/// <method>OnAfterAllTests</method>.</p>
Parameter PRINCIPALROLE = "OcuPilotErrDeleteRole";

/// <p>See <parameter>PRINCIPALROLE</parameter>.</p>
Parameter PRINCIPALUSER = "OcuPilotErrDelete";

/// <p>The account's password for this run, generated in <method>OnBeforeAllTests</method> and
/// never written to source.</p>
Property PreparedPassword As %String;

/// <p>The resource guarding <parameter>TARGETNAMESPACE</parameter>'s globals database, resolved
/// from the instance rather than spelled here.</p>
Property PreparedTargetResource As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedTargetResource = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ErrorDelete deletes real application errors from this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was deleted. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#SEEDVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ErrorDelete seeds every error it removes and runs on a throwaway container only. " _ ..#SEEDVARIABLE _ " does not read 1 here, so nothing was written.")
    }
    If $System.Util.GetEnviron(..#PRINCIPALVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ErrorDelete creates and deletes one IRIS principal on this instance and runs on a throwaway container only. " _ ..#PRINCIPALVARIABLE _ " does not read 1 here, so no principal was created.")
    }
    Quit ..PreparePrincipal()
}

/// <p>Resolve the two databases the confirm leg's principal needs, create it, and <b>read its
/// grants back from the instance</b> rather than predicting them: the screen's two instance pairs
/// and READ on the target namespace's globals database, without the WRITE half the delete
/// requires. A principal whose grants do not read that way refuses the class, because a leg that
/// measures the gate against an account nobody checked measures nothing.</p>
Method PreparePrincipal() As %Status
{
    Set tSC = $$$OK
    Try {
        If '##class(OcuPilot.Api.Namespaces).GlobalDatabase(..#TARGETNAMESPACE, .tTargetResource, .tTargetReadOnly) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not resolve the globals-database resource for " _ ..#TARGETNAMESPACE)
            Quit
        }
        Set ..PreparedTargetResource = tTargetResource
        Set ..PreparedPassword = "OcuPilotDel" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
        Set tSC = ..CodeResource(.tCodeResource)
        If $$$ISERR(tSC) Quit
        If tCodeResource = tTargetResource {
            Set tSC = $$$ERROR($$$GeneralError, "The install namespace's code database and " _ ..#TARGETNAMESPACE _ "'s globals database share one resource (" _ tCodeResource _ "), so no principal can read the code and lack WRITE on the target")
            Quit
        }
        ; READ, not RW, on the target namespace: NamespaceList only offers a namespace the caller
        ; can read, so a principal without READ is refused 404 by the enumeration and the gate is
        ; never reached. READ without WRITE is where the delete's own half of the set bites.
        Set tSpec = tCodeResource _ ":R,%Admin_Operate:U," _ ..#SYSRESOURCE _ ":R," _ tTargetResource _ ":R"
        Set tSC = ##class(OcuPilot.Test.ErrorLogDenial).EnsurePrincipal(..#PRINCIPALROLE, ..#PRINCIPALUSER, ##class(OcuPilot.Test.ErrorLogDenial).MergedResources(tSpec), ..PreparedPassword)
        If $$$ISERR(tSC) Quit

        Set tHolds = ($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%Admin_Operate", "USE") = 1) && ($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, ..#SYSRESOURCE, "READ") = 1) && ($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, tTargetResource, "READ") = 1) && ($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, tTargetResource, "WRITE") '= 1)
        If 'tHolds {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the least-privileged principal's grants on " _ tTargetResource)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The resource guarding the install namespace's own code database, which the principal needs
/// read on or IRIS cannot load the dispatch class for its request at all.</p>
/// <p>One explicit <code>%SYS</code> window, restored on both paths and as the first line of the
/// <code>Catch</code>; nothing inside it dispatches an <code>OcuPilot</code> class (AD-16).</p>
Method CodeResource(Output pResource As %String) As %Status
{
    Set pResource = ""
    Set tSC = $$$OK
    Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tNsObj = ##class(Config.Namespaces).Open(tInstallNs)
        If '$IsObject(tNsObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open namespace configuration for " _ tInstallNs)
            Quit
        }
        Set tDbObj = ##class(Config.Databases).Open(tNsObj.Routines)
        If '$IsObject(tDbObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open the routine database " _ tNsObj.Routines)
            Quit
        }
        Set tSysDb = ##class(SYS.Database).%OpenId(tDbObj.Directory)
        If '$IsObject(tSysDb) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open SYS.Database for the routine database directory")
            Quit
        }
        Set pResource = tSysDb.ResourceName
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

/// <p>Leave the namespace holding no application errors, which is how this class found it on a
/// throwaway and what stops a later class in the sweep reading a residue it did not seed.</p>
Method OnAfterAllTests() As %Status
{
    Do ..Clear()
    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 404, "the namespace this class seeded records no application errors when it is done")
    Quit ..RemovePrincipal()
}

/// <p>Remove the throwaway account and its role, and <b>return a failing status</b> if either
/// survives. Reported through the status rather than assertions, which
/// <code>%UnitTest.Manager</code> does not record from this method.</p>
Method RemovePrincipal() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        If ##class(Security.Users).Exists(..#PRINCIPALUSER, .tU, .tUS) Do ##class(Security.Users).Delete(..#PRINCIPALUSER)
        If ##class(Security.Users).Exists(..#PRINCIPALUSER, .tU2, .tUS2) Set tLeft = "user " _ ..#PRINCIPALUSER
        If ##class(Security.Roles).Exists(..#PRINCIPALROLE, .tR, .tRS) Do ##class(Security.Roles).Delete(..#PRINCIPALROLE)
        If ##class(Security.Roles).Exists(..#PRINCIPALROLE, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ ..#PRINCIPALROLE
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.ErrorDelete teardown left throwaway objects on the instance: " _ tLeft)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>AC1, AC7 -- the fresh read is the enumerated <code>(date, errorNumber)</code> set, it
/// carries no error text, routine, line or captured payload, and the namespace it resolves is the
/// instance's own spelling whichever spelling the caller sent (AD-13, AD-48).</p>
/// <p>Mutation (Rule 19): compare the namespace exactly in
/// <method>OcuPilot.Port.LogSourcePort.NamespaceSpelling</method> instead of folding case -- the
/// lower-case leg is refused 404 and this goes red, which is the confirm path failing, since the
/// confirm is handed the canonical lower-case id.</p>
Method TestTheEnumerationIsTheIdSetAndResolvesEitherSpelling()
{
    Set tSC = ..Seed(.tDate, .tNumber)
    Do $$$AssertStatusOK(tSC, "the class seeds one application error it will later remove")
    If $$$ISERR(tSC) Quit

    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tUpper, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the port enumerates for the instance's own spelling: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(+$Get(tHttp), 200, "at 200")
    If '$IsObject(tUpper) Quit
    Do $$$AssertEquals(tUpper.%Get("namespace"), ..#TARGETNAMESPACE, "answering the namespace the instance names")
    Do $$$AssertTrue(tUpper.%Get("count") > 0, "with at least the entry just seeded: " _ tUpper.%Get("count"))
    Do $$$AssertEquals(tUpper.%Get("entries").%Size(), tUpper.%Get("count"), "and a count that is the id set's own size")
    Do $$$AssertEquals(tUpper.%Get("truncated"), 0, "untruncated, which is what lets a proposal promise to remove exactly these")
    Do $$$AssertTrue(..Holds(tUpper, tDate, tNumber), "the seeded entry is one of them: " _ tDate _ " #" _ tNumber)

    Set tEntry = tUpper.%Get("entries").%Get(0)
    Do $$$AssertEquals(tEntry.%GetTypeOf("errorText"), "unassigned", "an entry carries no error text")
    Do $$$AssertEquals(tEntry.%GetTypeOf("line"), "unassigned", "no code line")
    Do $$$AssertEquals(tEntry.%GetTypeOf("variables"), "unassigned", "and no captured variable table (AD-48)")

    Set tSC = ..Enumerate($ZConvert(..#TARGETNAMESPACE, "L"), .tLower, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the port enumerates for the canonical lower-case spelling too")
    If '$IsObject(tLower) Quit
    Do $$$AssertEquals(tLower.%Get("namespace"), tUpper.%Get("namespace"), "answering the same instance spelling, so both ends of a proposal digest one value")
    Do $$$AssertEquals(tLower.%Get("entries").%ToJSON(), tUpper.%Get("entries").%ToJSON(), "over the same id set")

    Set tSC = ..Enumerate(..#ABSENTNAMESPACE, .tAbsent, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a namespace the log does not answer is refused")
    Do $$$AssertEquals(+$Get(tHttp), 404, "at 404")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#LOGNAMESPACE, "with the port's own namespace code")
}

/// <p>AC5 -- the card's rows are removals: the identifying pair of each enumerated error, no
/// after-state, and the tool's destructive declaration on the stored row. Nothing is sent, so
/// nothing is disclosed as unchanged (AD-51).</p>
/// <p>Mutation (Rule 19): drop the <code>removed</code> flag from
/// <method>OcuPilot.Screen.Tool.ErrorDelete.StateDiff</method> -- the removal assertion goes red
/// and the card would draw a delete as an ordinary change to an empty value.</p>
Method TestTheMintListsEveryEnumeratedErrorAsARemovalRow()
{
    Set tSC = ..Seed(.tDate, .tNumber)
    Do $$$AssertStatusOK(tSC, "the class seeds one application error")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint(..#TARGETNAMESPACE, tTurn, .tProposal)
    Do $$$AssertStatusOK(tSC, "the proposal mints against the instance: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit

    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tRead, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the enumeration answers")
    If '$IsObject(tRead) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), tRead.%Get("count"), "one row per enumerated error, which is what the residue sentence counts")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "and nothing is sent, so nothing is disclosed as unchanged")
    Set tFound = 0
    Set tIterator = tProposal.%Get("changed").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $$$AssertEquals(tRow.%Get("removed"), 1, "every row is a removal")
        Do $$$AssertEquals(tRow.%Get("after"), "", "with no after-state")
        If (tRow.%Get("field") = tDate) && (tRow.%Get("before") = tNumber) Set tFound = 1
    }
    Do $$$AssertEquals(tFound, 1, "and the seeded entry's own identifying pair is one of them: " _ tDate _ " #" _ tNumber)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.%Get("proposalId"), "Destructive"), 1, "the stored row carries the tool's destructive declaration")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>AC3, AC6 -- the confirm removes exactly the enumerated ids through
/// <code>SYS.ApplicationError</code>, an error logged after the proposal survives it, and the
/// ledger row reads marked (AD-15, AD-48).</p>
/// <p>Mutation (Rule 19): call <code>DeleteByNamespace</code> in place of
/// <method>OcuPilot.Port.LogSourcePort.RemoveErrorIds</method>'s per-date
/// <code>DeleteByError</code> -- the residue assertion goes red, because the error logged after
/// the proposal is destroyed too.</p>
Method TestTheConfirmRemovesExactlyTheEnumeratedIdsAndLeavesTheResidue()
{
    Set tSC = ..Seed(.tDate, .tNumber)
    Do $$$AssertStatusOK(tSC, "the class seeds the error the proposal will enumerate")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint(..#TARGETNAMESPACE, tTurn, .tProposal)
    Do $$$AssertStatusOK(tSC, "the proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tEnumerated = tProposal.%Get("changed").%Size()

    ; The residue: an error logged after the proposal, which the confirm must leave standing.
    Set tSC = ..Seed(.tResidueDate, .tResidueNumber)
    Do $$$AssertStatusOK(tSC, "a second error is logged between the proposal and the confirm")
    If $$$ISERR(tSC) Quit

    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm succeeds (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tResult.%Get("auditMarked"), 1, "the answer reports the marker landed")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditingUpdate).LedgerColumn(tTurn, "auditMarked"), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the ledger row reads marked")

    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tAfter, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the namespace still answers, because it still holds the residue")
    If '$IsObject(tAfter) Quit
    Do $$$AssertTrue('..Holds(tAfter, tDate, tNumber), "the enumerated error is gone")
    Do $$$AssertTrue(..Holds(tAfter, tResidueDate, tResidueNumber), "the one logged after the proposal remains, which is the residue AD-48 requires")
    Do $$$AssertEquals(tAfter.%Get("count"), 1, "and exactly the enumerated " _ tEnumerated _ " were removed")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..Clear()
}

/// <p>AC2's refusing direction -- an enumerated id another party removed moves the declared
/// fingerprint subject, so the confirm is refused 409 with the row closed and nothing is
/// deleted.</p>
/// <p>Mutation (Rule 19): empty
/// <parameter>OcuPilot.Screen.Tool.ErrorDelete.FINGERPRINTSUBJECT</parameter> -- registration
/// refuses the tool outright, and with the guard's DW-1476 condition removed as well the digest
/// would cover a live re-query and this refusal would not fire.</p>
Method TestAnEnumeratedErrorRemovedByAnotherPartyRefusesTheConfirm()
{
    Set tSC = ..Seed(.tFirstDate, .tFirstNumber)
    Do $$$AssertStatusOK(tSC, "the class seeds the first error")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Seed(.tSecondDate, .tSecondNumber)
    Do $$$AssertStatusOK(tSC, "and a second, so one can be removed under the proposal")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint(..#TARGETNAMESPACE, tTurn, .tProposal)
    Do $$$AssertStatusOK(tSC, "the proposal mints over both: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit

    Set tSC = ..RemoveDirect(..#TARGETNAMESPACE, tSecondDate, tSecondNumber)
    Do $$$AssertStatusOK(tSC, "another party removes one of the enumerated errors")
    If $$$ISERR(tSC) Quit

    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(+$Get(tHttp), 409, "at 409")
    Do $$$AssertEquals($Get(tCode), $Parameter("OcuPilot.Kernel.Proposal.Write", "TARGETCHANGED"), "with the moved-target code, not a privilege or prohibition refusal")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.%Get("proposalId"), "State"), $Parameter("OcuPilot.Kernel.State.Propose", "STATECANCELED"), "the row is closed, so Re-propose is the only way on")

    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tAfter, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the namespace still answers")
    If '$IsObject(tAfter) Quit
    Do $$$AssertTrue(..Holds(tAfter, tFirstDate, tFirstNumber), "and the error the confirm would have removed is still there")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..Clear()
}

/// <p>AD-13, AD-34 -- two spellings of one namespace build one target key, so the second proposal
/// is the first's sibling and confirming one cancels the other.</p>
/// <p>Mutation (Rule 19): drop <code>application-error:foldcase</code> from
/// <parameter>OcuPilot.Kernel.EntityRef.IDRULES</parameter> -- the two keys differ, the sibling
/// survives, and two concurrent confirms could both win.</p>
Method TestTwoSpellingsOfOneNamespaceAreOneTarget()
{
    Set tSC = ..Seed(.tDate, .tNumber)
    Do $$$AssertStatusOK(tSC, "the class seeds one application error")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint(..#TARGETNAMESPACE, tTurn, .tFirst)
    Do $$$AssertStatusOK(tSC, "the first proposal mints from the instance's own spelling")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint($ZConvert(..#TARGETNAMESPACE, "L"), tTurn, .tSecond)
    Do $$$AssertStatusOK(tSC, "and a second from the lower-case one")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tFirst.%Get("target").%Get("id"), $ZConvert(..#TARGETNAMESPACE, "L"), "the recorded target is the canonical spelling")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tFirst.%Get("proposalId"), "TargetRef"), ##class(OcuPilot.Test.ProposalFixture).Field(tSecond.%Get("proposalId"), "TargetRef"), "and both rows carry one target reference")

    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tSecond.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "confirming one of them succeeds (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tFirst.%Get("proposalId"), "State"), $Parameter("OcuPilot.Kernel.State.Propose", "STATECANCELED"), "and its sibling on the same target is cancelled in the same transition")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..Clear()
}

/// <p>AD-10's <code>application-error</code> branch: the type is covered, no field of it is one
/// this release has reviewed, and the tool's declared fingerprint subject is skipped by
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Changed</method> rather than adjudicated twice --
/// which is what keeps a moved id set a 409 with the row closed instead of a 403 with it live.</p>
/// <p>Mutation (Rule 19): remove <code>application-error</code> from
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.COVEREDTYPES</parameter> -- every confirm of this
/// tool is refused <code>UNCOVERED</code> and the coverage assertion goes red.</p>
Method TestAChangedFieldOnAnApplicationErrorProposalIsRefused()
{
    Do $$$AssertTrue($ListFind($ClassMethod(..#SET, "CoveredTypes"), "application-error") > 0, "the type is covered, so a delete is not refused wholesale")
    Do $$$AssertEquals($ListLength($ClassMethod(..#SET, "PermittedChangeFields", "application-error")), 0, "and no field of it is one this release has reviewed")
    Do $$$AssertEquals($ListLength($ClassMethod(..#TOOL, "SettableFields")), 0, "the tool admits none either, so the refusing arm is reached by arming the input rather than through a call")

    Set tRef = ##class(OcuPilot.Kernel.EntityRef).Key("application-error", ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, ..#TARGETNAMESPACE, .tKey)
    Do $$$AssertStatusOK(tRef, "the target reference builds")
    Set tSubject = $ListToString($ClassMethod(..#TOOL, "FingerprintSubject"))
    Do $$$AssertEquals(tSubject, "namespace,entries", "the declared subject is the identity and the id set")
    Set tSkipped = $ClassMethod(..#SET, "SkippedFields", ..#TOOL)
    Do $$$AssertTrue($ListFind(tSkipped, "entries") > 0, "which the prohibited sweep skips, so a moved id set is the fingerprint's answer and not a 403")
    Do $$$AssertTrue($ListFind(tSkipped, "namespace") > 0, "both names of it")
}

/// <p>AC4 -- the per-namespace gate at the <b>confirm</b>: a principal holding
/// <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>, and READ but not WRITE on
/// <parameter>TARGETNAMESPACE</parameter>'s globals database, is refused 403 naming that pair, and
/// every enumerated error survives (AD-8, AD-29, AD-48).</p>
/// <p>The proposal is minted for that principal and confirmed by it over the shipped route, so
/// <code>$Username</code> and every privilege the confirm's own gate and the port's own gate read
/// are its. Nothing here stands in for <class>OcuPilot.Screen.Gate</class>, the port or the tool's
/// pair set; the principal's grants are read back from the instance rather than predicted.</p>
/// <p>Mutation (Rule 19): MUTATIONLINE</p>
Method TestALeastPrivilegedPrincipalIsRefusedAtTheConfirm()
{
    Do $$$AssertNotEquals(..PreparedTargetResource, "", "setup resolved the target namespace's guarding resource")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, "%Admin_Operate", "USE"), 1, "the principal holds the screen's administrative pair")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, ..#SYSRESOURCE, "READ"), 1, "and read on the database SYS.ApplicationError is executed from")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, ..PreparedTargetResource, "READ"), 1, "and READ on the target namespace's own globals database")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PRINCIPALUSER, ..PreparedTargetResource, "WRITE"), 0, "and not the WRITE half this delete requires")

    Set tSC = ..Seed(.tDate, .tNumber)
    Do $$$AssertStatusOK(tSC, "the class seeds the error the proposal will enumerate")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PRINCIPALUSER, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded for that principal")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint(..#TARGETNAMESPACE, tTurn, .tProposal, ..#PRINCIPALUSER)
    Do $$$AssertStatusOK(tSC, "the proposal mints for it: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tEnumerated = tProposal.%Get("changed").%Size()
    Do $$$AssertTrue(tEnumerated > 0, "over at least one enumerated error: " _ tEnumerated)

    Set tSC = ..ConfirmAs(tProposal.%Get("proposalId"), ..#PRINCIPALUSER, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the confirm request completes")
    Do $$$AssertEquals(+$Get(tStatus), 403, "it is refused on the pair rather than answered 409 or 500: " _ $Extract($Get(tBody), 1, 240))
    Do $$$AssertEquals(($Get(tBody) [ "}{"), 0, "exactly one envelope")
    Set tFault = ##class(%DynamicObject).%FromJSON($Get(tBody))
    Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "with the privilege code, never the generic internal one a refused live read produces")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogDenial).FailedPairOf($Get(tBody)), ..PreparedTargetResource _ ":WRITE", "naming the pair this principal lacks")

    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tAfter, .tHttp, .tReadFault)
    Do $$$AssertStatusOK(tSC, "the namespace still answers, because it still holds every error")
    If '$IsObject(tAfter) Quit
    Do $$$AssertEquals(tAfter.%Get("count"), tEnumerated, "and every enumerated error survives the refusal")
    Do $$$AssertTrue(..Holds(tAfter, tDate, tNumber), "the seeded one among them: " _ tDate _ " #" _ tNumber)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForUser(..#PRINCIPALUSER)
    Do ..Clear()
}

/// <p>Seed one application error into <parameter>TARGETNAMESPACE</parameter>, answering its
/// identifying pair as the port spells it: the <code>MM/DD/YYYY</code> date and the entry
/// number.</p>
ClassMethod Seed(Output pDate As %String, Output pNumber As %String) As %Status
{
    Set pDate = ""
    Set pNumber = ""
    Set tSC = ##class(OcuPilot.Test.ErrorLogSeed).SeedInto(..#TARGETNAMESPACE, .tDay, .tNumber)
    If $$$ISERR(tSC) Quit tSC
    Set pDate = $ZDate(tDay, 1)
    Set pNumber = tNumber
    Quit $$$OK
}

/// <p>Enumerate <var>pNamespace</var>'s ids through the shipped port's own
/// <method>OcuPilot.Port.LogSourcePort.Invoke</method>, exactly as the mint does.</p>
ClassMethod Enumerate(pNamespace As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill tQuery
    Set tQuery($Parameter(..#PORT, "NAMESPACEPARAM")) = pNamespace
    Quit $ClassMethod(..#PORT, "Invoke", $Parameter(..#PORT, "ENDPOINTERRORS"), $Parameter(..#PORT, "TYPEENUMERATE"), .tQuery, "", .pResult, .pHttpStatus, .pFault)
}

/// <p>Whether the enumeration <var>pResult</var> carries <var>pDate</var> / <var>pNumber</var>.</p>
ClassMethod Holds(pResult As %DynamicObject, pDate As %String, pNumber As %String) As %Boolean
{
    Set tHeld = 0
    If '$IsObject(pResult) Quit 0
    If pResult.%GetTypeOf("entries") '= "array" Quit 0
    Set tIterator = pResult.%Get("entries").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If '$IsObject(tEntry) Continue
        If (tEntry.%Get("date") = pDate) && (tEntry.%Get("errorNumber") = pNumber) Set tHeld = 1
    }
    Quit tHeld
}

/// <p>Mint one proposal for <var>pNamespace</var> through the <b>shipped</b> mint, so the port,
/// the fresh read and the fingerprint are the instance's own. <var>pUser</var> is the user the
/// stored row is minted for, defaulting to this process's own; only that user can confirm it.</p>
ClassMethod Mint(pNamespace As %String, pTurnKey As %String, Output pProposal As %DynamicObject, pUser As %String = "") As %Status
{
    Set tUser = pUser
    If tUser = "" Set tUser = $Username
    Set tArgs = {}
    Do tArgs.%Set($ClassMethod(..#TOOL, "IdArgument"), pNamespace, "string")
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint(..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), tUser, "", pTurnKey, tArgs, ..#LIMITS, .pProposal, .tHttp, .tFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pNamespace, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p>Confirm proposal <var>pProposalId</var> over the wire as <var>pUser</var>, so
/// <code>$Username</code> and every privilege the port's own gate reads are that principal's and
/// not this process's.</p>
Method ConfirmAs(pProposalId As %String, pUser As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/proposal/" _ pProposalId _ "/confirm", pUser, ..PreparedPassword, .pStatus, .pBody, .pHeaders, "", "application/json")
}

/// <p>Remove one error directly through the vendor's own method, standing in for another party.
/// Restores <code>$NAMESPACE</code> on both paths and as the first line of its
/// <code>Catch</code> (AD-16).</p>
ClassMethod RemoveDirect(pNamespace As %String, pDate As %String, pNumber As %String) As %Status
{
    Set tSC = $$$OK
    ; Resolved out here: a $Parameter on an OcuPilot class from inside the %SYS window is the
    ; <CLASS DOES NOT EXIST> trap AD-16 exists for.
    Set tErrorsNamespace = $Parameter(..#PORT, "ERRORSNAMESPACE")
    Set tQueryClass = $Parameter(..#PORT, "ERRORSQUERYCLASS")
    Set tMethod = $Parameter(..#PORT, "DELETEBYERRORMETHOD")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = tErrorsNamespace
        Set tSC = $ClassMethod(tQueryClass, tMethod, pNamespace, pDate, pNumber)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove every application error this class's namespace still holds, so a method leaves the
/// throwaway as it found it. Read back by the caller through <method>Enumerate</method>.</p>
ClassMethod Clear()
{
    If $$$ISERR(..Enumerate(..#TARGETNAMESPACE, .tResult, .tHttp, .tFault)) Quit
    If '$IsObject(tResult) Quit
    Set tIterator = tResult.%Get("entries").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If '$IsObject(tEntry) Continue
        Do ..RemoveDirect(..#TARGETNAMESPACE, tEntry.%Get("date"), tEntry.%Get("errorNumber"))
    }
}

}
