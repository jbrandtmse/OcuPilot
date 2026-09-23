/// <p>Story 5.13's and Story 7.10's suite: the application error log's deletes, by namespace, by
/// date and by error, through both callers, end to end on the instance (AD-48, AD-51, AD-52,
/// AD-53).</p>
/// <p><b>What it pins.</b> The port's enumeration is the identifying id set and resolves either
/// spelling of a namespace; the mint lists every enumerated error as a removal row; the confirm
/// removes <b>exactly</b> those ids and leaves an error logged after the proposal standing; an
/// enumerated id another party removed refuses the confirm 409 rather than deleting a cut set; two
/// spellings of one namespace are one target; and a changed field on this type is refused by the
/// prohibited set.</p>
/// <p>It also measures the per-namespace gate on the <b>confirm</b>: a purpose-built
/// least-privileged principal, holding the screen's two instance pairs and READ but not WRITE on
/// the target namespace's globals database, is refused 403 naming that pair and every error
/// survives (AD-8, AD-29, AD-48). Story 7.10's legs pin the narrower scopes: an agent delete by date
/// or by one error removes exactly its enumerated entries and leaves an error logged after the
/// proposal; a number reused after its date was emptied refuses the confirm; the screen route
/// deletes each scope its id names, ignores the route's <code>?ns=</code>, and refuses a principal
/// short of the namespace's WRITE pair before any read.</p>
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

/// <p>A well-formed date <parameter>TARGETNAMESPACE</parameter> holds no application error on, for
/// the multi-date fan-out leg. It must be in the past and it must parse: the vendor answers
/// <code>1</code> for a date it holds nothing on and an error for one it cannot read as a
/// date.</p>
Parameter EMPTYDATE = "01/01/2020";

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

/// <p>AC1 as amended -- the write is <code>DeleteByError(ns, date, ids)</code> executed <b>once
/// per enumerated date</b>, which is what the amendment away from <code>DeleteByNamespace</code>
/// bought. Every other leg of this class seeds through <class>OcuPilot.Test.ErrorLogSeed</class>,
/// which stamps each error today, so no other leg puts more than one date in the set and a
/// fan-out that ran only its first date would pass all of them.</p>
/// <p>The set therefore carries a second, earlier date the namespace holds no error on, and
/// carries it <b>first</b>. Measured on <code>ocupilot-ci</code> 2026-09-23:
/// <code>SYS.ApplicationError.DeleteByError</code> answers <code>1</code> for a well-formed date
/// it holds nothing on, so that entry is a real iteration that removes nothing.</p>
/// <p>Mutation (Rule 19): <code>Quit</code> after the first iteration of
/// <method>OcuPilot.Port.LogSourcePort.RemoveErrorIds</method>'s per-date loop -- the dates
/// assertion and the removal assertion both go red, because the seeded error is on the second
/// date.</p>
Method TestTheDeleteReachesTheVendorOncePerEnumeratedDate()
{
    Set tSC = ..Seed(.tDate, .tNumber)
    Do $$$AssertStatusOK(tSC, "the class seeds the error the delete will name")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Seed(.tKeptDate, .tKeptNumber)
    Do $$$AssertStatusOK(tSC, "and a second it does not name, so the namespace still enumerates afterwards")
    If $$$ISERR(tSC) Quit

    Kill tQuery
    Set tQuery($Parameter(..#PORT, "NAMESPACEPARAM")) = ..#TARGETNAMESPACE
    Set tQuery($Parameter(..#PORT, "ENTRIESPARAM")) = "[{""date"":""" _ ..#EMPTYDATE _ """,""errorNumber"":""1""},{""date"":""" _ tDate _ """,""errorNumber"":""" _ tNumber _ """}]"
    Set tSC = $ClassMethod(..#PORT, "Invoke", $Parameter(..#PORT, "ENDPOINTERRORS"), $Parameter(..#PORT, "TYPEDELETE"), .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the two-date delete succeeds (HTTP " _ +$Get(tHttp) _ ")")
    If $$$ISERR(tSC) || '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.%Get("dates"), 2, "the port reached the vendor once for each enumerated date, not once for the set")

    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tAfter, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the namespace still answers, because it still holds the error the set did not name")
    If '$IsObject(tAfter) Quit
    Do $$$AssertTrue('..Holds(tAfter, tDate, tNumber), "the named error, which was on the SECOND date of the set, is gone")
    Do $$$AssertTrue(..Holds(tAfter, tKeptDate, tKeptNumber), "and the one the set did not name survives")
    Do ..Clear()
}

/// <p>The truncated-enumeration refusal in
/// <method>OcuPilot.Screen.Tool.ErrorDelete.StateDiff</method>: a cut set cannot support "the
/// confirm removes exactly these", so the mint is refused rather than proposing one.</p>
/// <p>Driven directly, because no reachable seeding makes this instance answer
/// <code>truncated</code> -- the port's cap is
/// <parameter>OcuPilot.Port.LogSourcePort.DEFAULTMAXROWS</parameter> and this class seeds single
/// figures. Without this leg the branch is executed by nothing and inverting it reddens
/// nothing.</p>
/// <p>Mutation (Rule 19): invert the guard to <code>If '''pFresh.%Get("truncated")</code> -- the
/// truncated leg's two assertions go red while the untruncated leg below stays green.</p>
Method TestATruncatedEnumerationRefusesTheMint()
{
    Set tCut = {"namespace": "USER", "count": 1, "truncated": true}
    Do tCut.%Set("entries", [])
    Do tCut.%Get("entries").%Push({"date": "09/11/2026", "errorNumber": "1"})
    Set tSC = $ClassMethod(..#TOOL, "StateDiff", tCut, .tRows, .tProblem)
    Do $$$AssertStatusOK(tSC, "the tool answers a truncated enumeration")
    Do $$$AssertNotEquals($Get(tProblem), "", "with a problem, so the mint refuses rather than proposing a cut set")
    Do $$$AssertEquals(tRows.%Size(), 0, "and no removal row, so nothing about the card claims a scope it cannot keep")

    Set tWhole = {"namespace": "USER", "count": 1, "truncated": false}
    Do tWhole.%Set("entries", [])
    Do tWhole.%Get("entries").%Push({"date": "09/11/2026", "errorNumber": "1"})
    Set tSC = $ClassMethod(..#TOOL, "StateDiff", tWhole, .tWholeRows, .tWholeProblem)
    Do $$$AssertStatusOK(tSC, "the same enumeration untruncated answers")
    Do $$$AssertEquals($Get(tWholeProblem), "", "with no problem")
    Do $$$AssertEquals(tWholeRows.%Size(), 1, "and one removal row, which is what says the refusal above is the truncation's and not the shape's")
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

/// <p>AD-10's <code>application-error</code> branch, driven through the shipped
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method>: the type is covered, no field
/// of it is one this release has reviewed, so a proposal carrying a changed field is refused
/// <parameter>UNCOVEREDFIELD</parameter> -- while the delete's own removal rows, and the declared
/// fingerprint subject, are not.</p>
/// <p><b>The refusing arm is reached by arming the predicate's input</b>, not by replacing the
/// method and not by reading the declarations it derives from: the delete tool admits no settable
/// field, so no call through it can carry one, and a test that asserted only
/// <method>OcuPilot.Kernel.Proposal.Prohibited.SkippedFields</method>'s answer would leave this
/// branch executed by nothing.</p>
/// <p>Three legs, because three different things must hold. The delete's own shape changes no
/// field. A moved <code>count</code> -- a name the live read answers and the subject does not
/// cover -- is the refusing arm. A moved <code>namespace</code> is the subject's skip: without it
/// the sweep would answer a moved subject 403 with the proposal row left live, where AD-6 requires
/// 409 <code>PROPOSAL.TARGETCHANGED</code> with it closed.</p>
/// <p>Mutation (Rule 19): replace
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ApplicationError</method>'s body with
/// <code>Set pProhibits = 0 Set pCode = "" Quit $$$OK</code> -- the refusing leg's two assertions
/// go red. Drop the fingerprint-subject loop from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.SkippedFields</method> -- the subject leg is
/// refused <code>UNCOVEREDFIELD</code> over a row the fingerprint owns.</p>
Method TestAChangedFieldOnAnApplicationErrorProposalIsRefused()
{
    Do $$$AssertTrue($ListFind($ClassMethod(..#SET, "CoveredTypes"), "application-error") > 0, "the type is covered, so a delete is not refused wholesale")
    Do $$$AssertEquals($ListLength($ClassMethod(..#SET, "PermittedChangeFields", "application-error")), 0, "and no field of it is one this release has reviewed")
    Do $$$AssertEquals($ListLength($ClassMethod(..#TOOL, "SettableFields")), 0, "the tool admits none either, so the refusing arm is reached by arming the input rather than through a call")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "FingerprintSubject")), "namespace,entries", "the declared subject is the namespace and the id set")

    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("application-error", ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE, ..#TARGETNAMESPACE, .tRef)
    Do $$$AssertStatusOK(tSC, "the target reference builds")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Seed(.tDate, .tNumber)
    Do $$$AssertStatusOK(tSC, "the class seeds one error, so the set has a live target to read")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and the namespace enumerates")
    If $$$ISERR(tSC) || '$IsObject(tFresh) Quit

    ; Leg 1 -- the delete's own shape: the stored payload is the subject projection and the rows
    ; are labelled by the error's date, a name neither side answers, so no field reads as changed.
    Set tPayload = {}
    Do tPayload.%Set("namespace", tFresh.%Get("namespace"), "string")
    Do tPayload.%Set("entries", tFresh.%Get("entries"))
    Set tRows = "[{""field"":""" _ tDate _ """,""before"":""" _ tNumber _ """,""after"":"""",""removed"":true}]"
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($Parameter(..#TOOL, "TOOLNAME"), tRef, tPayload.%ToJSON(), tRows, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers the delete's own shape")
    Do $$$AssertEquals(tProhibits, 0, "which is prohibited by nothing, code was '" _ $Get(tCode) _ "'")

    ; Leg 2 -- the refusing arm, reached by arming the input: a payload that really moves a field
    ; the instance holds otherwise, with the diff naming it.
    Set tMoved = ##class(%DynamicAbstractObject).%FromJSON(tFresh.%ToJSON())
    Do tMoved.%Set("count", tFresh.%Get("count") + 1, "number")
    Set tMovedRows = "[{""field"":""count"",""before"":""" _ tFresh.%Get("count") _ """,""after"":""" _ (tFresh.%Get("count") + 1) _ """}]"
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($Parameter(..#TOOL, "TOOLNAME"), tRef, tMoved.%ToJSON(), tMovedRows, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers the armed input")
    Do $$$AssertEquals(tProhibits, 1, "a changed field on an application-error proposal is refused")
    Do $$$AssertEquals($Get(tCode), $Parameter(..#SET, "UNCOVEREDFIELD"), "as a field nobody has reviewed")

    ; Leg 3 -- the declared subject is skipped rather than adjudicated twice. `namespace` is one of
    ; its two names and both sides render it, so this leg fails without the skip.
    Set tSkipped = $ClassMethod(..#SET, "SkippedFields", ..#TOOL)
    Do $$$AssertTrue($ListFind(tSkipped, "namespace") > 0, "the sweep is told to skip the declared subject")
    Do $$$AssertTrue($ListFind(tSkipped, "entries") > 0, "both names of it")
    Set tMovedSubject = ##class(%DynamicAbstractObject).%FromJSON(tFresh.%ToJSON())
    Do tMovedSubject.%Set("namespace", "OCUPILOTPROBEMOVEDNAMESPACE", "string")
    Set tSubjectRows = "[{""field"":""namespace"",""before"":""OCUPILOTPROBEMOVEDNAMESPACE"",""after"":""" _ tFresh.%Get("namespace") _ """}]"
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($Parameter(..#TOOL, "TOOLNAME"), tRef, tMovedSubject.%ToJSON(), tSubjectRows, .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set answers a moved subject named by the diff")
    Do $$$AssertEquals(tProhibits, 0, "which is prohibited by nothing -- a moved subject is the fingerprint's 409, not this set's 403, code was '" _ $Get(tCode) _ "'")
    Do ..Clear()
}

/// <p>AC4 -- the per-namespace gate at the <b>confirm</b>: a principal holding
/// <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>, and READ but not WRITE on
/// <parameter>TARGETNAMESPACE</parameter>'s globals database, is refused 403 naming that pair, and
/// every enumerated error survives (AD-8, AD-29, AD-48).</p>
/// <p>The proposal is minted for that principal and confirmed by it over the shipped route, so
/// <code>$Username</code> and every privilege the confirm's own gate and the port's own gate read
/// are its. Nothing here stands in for <class>OcuPilot.Screen.Gate</class>, the port or the tool's
/// pair set; the principal's grants are read back from the instance rather than predicted.</p>
/// <p>Mutation (Rule 19): answer <code>""</code> from
/// <method>OcuPilot.Screen.Tool.ErrorDelete.ArgumentPairs</method> -- the confirm's combined pair
/// set then carries no per-namespace requirement, the least-privileged principal passes that gate,
/// reaches the prohibited set's live read, and is answered a generic 500 <code>INTERNAL</code>
/// rather than the pair-naming 403: the three assertions on the refusal's shape go red while the
/// survival assertions stay green (confirmed on <code>ocupilot-ci</code> with the package reloaded
/// there; reverted).</p>
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

/// <p>Story 7.10 AC2 -- an agent delete by date lists that date's enumerated errors, and the
/// confirm removes exactly those: an error logged on the same date after the proposal survives.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.LogSourcePort.ErrorSetRun</method>'s delete
/// call <code>DeleteByDate</code> for a date scope -- the later error is removed with the rest and
/// the survival assertion goes red.</p>
Method TestAnAgentDeleteByDateLeavesAnErrorLoggedAfterTheProposal()
{
    Do ..Clear()
    Set tSC = ..Seed(.tDate, .tNumber)
    Do $$$AssertStatusOK(tSC, "the class seeds the error the date's proposal will enumerate")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tArgs = {}
    Do tArgs.%Set("namespace", ..#TARGETNAMESPACE, "string")
    Do tArgs.%Set("date", tDate, "string")
    Set tSC = ..MintScope(tArgs, tTurn, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the by-date proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("target").%Get("id"), $ZConvert(..#TARGETNAMESPACE, "L") _ $Char(1) _ tDate, "its target is the namespace-and-date prefix of the composite id")
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 1, "one removal row per error that date holds")

    Set tSC = ..Seed(.tLaterDate, .tLaterNumber)
    Do $$$AssertStatusOK(tSC, "an error is logged on the same date after the proposal")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tLaterDate, tDate, "on the date the proposal names")

    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm succeeds (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tResult.%Get("auditMarked"), 1, "and is marked")

    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tAfter, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the namespace still answers")
    If '$IsObject($Get(tAfter)) Quit
    Do $$$AssertTrue('..Holds(tAfter, tDate, tNumber), "the enumerated error is gone")
    Do $$$AssertTrue(..Holds(tAfter, tLaterDate, tLaterNumber), "and the one logged after the proposal remains, on the same date")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..Clear()
}

/// <p>Story 7.10 AC2 -- an agent delete by error lists one removal row, and the confirm removes that
/// error alone.</p>
/// <p>Mutation (Rule 19): drop the <code>errorNumber</code> part in
/// <method>OcuPilot.Screen.Tool.ErrorDeleteMint.Mint</method> -- the proposal becomes the date's,
/// lists two rows, and the row-count and survival assertions go red.</p>
Method TestAnAgentDeleteByErrorRemovesThatErrorAlone()
{
    Do ..Clear()
    Set tSC = ..Seed(.tDate, .tNumber)
    Do $$$AssertStatusOK(tSC, "the class seeds the error the proposal names")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Seed(.tOtherDate, .tOtherNumber)
    Do $$$AssertStatusOK(tSC, "and one beside it that it does not")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tArgs = {}
    Do tArgs.%Set("namespace", ..#TARGETNAMESPACE, "string")
    Do tArgs.%Set("date", tDate, "string")
    Do tArgs.%Set("errorNumber", +tNumber, "number")
    Set tSC = ..MintScope(tArgs, tTurn, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the by-error proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 1, "one removal row")
    Do $$$AssertEquals(tProposal.%Get("changed").%Get(0).%Get("before"), tNumber, "naming that error")

    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm succeeds (HTTP " _ +$Get(tHttp) _ " " _ $Get(tCode) _ ")")
    If $$$ISERR(tSC) Quit

    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tAfter, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the namespace still answers")
    If '$IsObject($Get(tAfter)) Quit
    Do $$$AssertTrue('..Holds(tAfter, tDate, tNumber), "the named error is gone")
    Do $$$AssertTrue(..Holds(tAfter, tOtherDate, tOtherNumber), "and the one beside it remains")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..Clear()
}

/// <p>Story 7.10 AC2 -- a date emptied after the mint restarts its numbering, so a new error can
/// take the number the proposal lists. Its <code>time</code> differs, the fingerprint re-read
/// differs, and the confirm is refused 409 with the new error left standing.</p>
/// <p>Mutation (Rule 19): drop <code>time</code> from the entries
/// <method>OcuPilot.Port.LogSourcePort.ErrorIdRows</method> and <code>SurvivingIdRows</code>
/// answer -- the digest matches, the confirm deletes the new error, and this goes red.</p>
Method TestANumberReusedAfterTheDateWasEmptiedRefusesTheConfirm()
{
    Do ..Clear()
    Set tSC = ..Seed(.tDate, .tNumber)
    Do $$$AssertStatusOK(tSC, "the class seeds the error the proposal names")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tArgs = {}
    Do tArgs.%Set("namespace", ..#TARGETNAMESPACE, "string")
    Do tArgs.%Set("date", tDate, "string")
    Do tArgs.%Set("errorNumber", +tNumber, "number")
    Set tSC = ..MintScope(tArgs, tTurn, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit

    ; Another party empties the date, and the next error on it -- logged a second later, so the
    ; vendor's Time differs -- takes the number back.
    Do ..Clear()
    Hang 1.1
    Set tSC = ..Seed(.tReusedDate, .tReusedNumber)
    Do $$$AssertStatusOK(tSC, "a new error is logged on the emptied date")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tReusedDate _ "#" _ tReusedNumber, tDate _ "#" _ tNumber, "and takes the number the proposal lists, which is what this leg is about")

    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "the confirm is refused")
    Do $$$AssertEquals(+$Get(tHttp), 409, "at 409")
    Do $$$AssertEquals($Get(tCode), $Parameter("OcuPilot.Kernel.Proposal.Write", "TARGETCHANGED"), "as a moved target")

    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tAfter, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the namespace still answers")
    If '$IsObject($Get(tAfter)) Quit
    Do $$$AssertTrue(..Holds(tAfter, tReusedDate, tReusedNumber), "and the new error survives")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do ..Clear()
}

/// <p>Story 7.10 AC1 -- the screen route deletes each scope its id names: one error, then a date,
/// then a namespace, each answered <code>deleted</code> with the canonical composite id, and each
/// leaving exactly what its scope does not cover.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.ErrorDelete.SCREENACTIONS</parameter>
/// <code>""</code> -- the route finds no tool for the action, answers 404, and every leg goes
/// red.</p>
Method TestTheScreenRouteDeletesEachScopeItsIdNames()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tSeparator = $Char(1)
    Do ..Clear()
    Set tSC = ..Seed(.tDate, .tFirst)
    Do $$$AssertStatusOK(tSC, "the class seeds two errors")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Seed(.tDate, .tSecond)
    If $$$ISERR(tSC) Quit

    Set tId = ..#TARGETNAMESPACE _ tSeparator _ tDate _ tSeparator _ tFirst
    Set tSC = ..DeleteOnScreen(tId, tUser, tPassword, "", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "the by-error request completes")
    Do $$$AssertEquals(tStatus, 200, "and is answered 200: " _ tBody)
    If tStatus = 200 {
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tAnswer.%Get("action"), "deleted", "announcing a removal")
        Do $$$AssertEquals(tAnswer.%Get("target").%Get("id"), $ZConvert(tId, "L"), "of the canonical composite id")
    }
    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tAfter, .tHttp, .tFault)
    Do $$$AssertTrue('..Holds($Get(tAfter), tDate, tFirst), "the named error is gone")
    Do $$$AssertTrue(..Holds($Get(tAfter), tDate, tSecond), "and the other on its date remains")

    Set tSC = ..DeleteOnScreen(..#TARGETNAMESPACE _ tSeparator _ tDate, tUser, tPassword, "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the by-date request is answered 200: " _ tBody)
    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tAfter, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 404, "and the date's last error is gone with it, so the namespace holds none")

    Set tSC = ..Seed(.tDate, .tThird)
    Do $$$AssertStatusOK(tSC, "a third error is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ..DeleteOnScreen(..#TARGETNAMESPACE, tUser, tPassword, "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the by-namespace request is answered 200: " _ tBody)
    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tAfter, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 404, "and the namespace holds no error")
    Do ..Clear()
}

/// <p>Story 7.10 AC3 -- a screen delete carrying the route's <code>?ns=HSCUSTOM</code> while its id
/// names <parameter>TARGETNAMESPACE</parameter> touches only the id's namespace: every error
/// HSCUSTOM held before is still there.</p>
/// <p>Mutation (Rule 19): resolve the port's namespace from the request's <code>ns</code>
/// parameter rather than the id -- HSCUSTOM's error is removed and this goes red.</p>
Method TestAScreenDeleteIgnoresTheRoutesNamespace()
{
    Do ..Clear()
    Set tSC = ..Seed(.tDate, .tNumber)
    Do $$$AssertStatusOK(tSC, "the class seeds the error the id names")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Enumerate("HSCUSTOM", .tBefore, .tHttp, .tFault)
    Set tBeforeCount = $Select($IsObject($Get(tBefore)): tBefore.%Get("count"), 1: 0)

    Set tId = ..#TARGETNAMESPACE _ $Char(1) _ tDate _ $Char(1) _ tNumber
    Set tSC = ..DeleteOnScreen(tId, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), "?ns=HSCUSTOM", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the request with a conflicting ?ns= is answered 200: " _ tBody)

    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tAfter, .tHttp, .tFault)
    Do $$$AssertTrue('..Holds($Get(tAfter), tDate, tNumber), "the id's namespace lost the named error")
    Set tSC = ..Enumerate("HSCUSTOM", .tOther, .tHttp, .tFault)
    Set tOtherCount = $Select($IsObject($Get(tOther)): tOther.%Get("count"), 1: 0)
    Do $$$AssertTrue(tOtherCount >= tBeforeCount, "HSCUSTOM's count is unchanged or grown by its own faults: " _ tBeforeCount _ " then " _ tOtherCount)
    Set tLost = 0
    If $IsObject($Get(tBefore)) {
        Set tIterator = tBefore.%Get("entries").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If '..Holds($Get(tOther), tEntry.%Get("date"), tEntry.%Get("errorNumber")) Set tLost = tLost + 1
        }
    }
    Do $$$AssertEquals(tLost, 0, "and every error HSCUSTOM held before is still there")
    Do ..Clear()
}

/// <p>Story 7.10 AC4 -- a screen delete by date made as a principal holding READ but not WRITE on
/// <parameter>TARGETNAMESPACE</parameter>'s globals database is refused 403 naming that pair, and
/// the error survives.</p>
/// <p>The route's pair gate and the port's own gate refuse this principal with the same envelope,
/// so this leg pins the refusal and not which of the two gave it; the composite's namespace in
/// <method>OcuPilot.Screen.Tool.ErrorDelete.ArgumentPairs</method> is pinned by
/// <class>OcuPilot.Test.ErrorDeleteScope</class>.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Port.LogSourcePort.ERRORSDATABASEPERMISSIONS</parameter>
/// to <code>READ</code> -- both gates pass, the delete is answered 200 and this goes red.</p>
Method TestAScreenDeleteShortOfTheWritePairIsRefused()
{
    Do $$$AssertNotEquals(..PreparedTargetResource, "", "setup resolved the target namespace's guarding resource")
    Do ..Clear()
    Set tSC = ..Seed(.tDate, .tNumber)
    Do $$$AssertStatusOK(tSC, "the class seeds the error the date holds")
    If $$$ISERR(tSC) Quit

    Set tSC = ..DeleteOnScreen(..#TARGETNAMESPACE _ $Char(1) _ tDate, ..#PRINCIPALUSER, ..PreparedPassword, "", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 403, "and is refused 403: " _ $Extract(tBody, 1, 240))
    Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE, "with the privilege code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ErrorLogDenial).FailedPairOf(tBody), ..PreparedTargetResource _ ":WRITE", "naming the WRITE pair it lacks")

    Set tSC = ..Enumerate(..#TARGETNAMESPACE, .tAfter, .tHttp, .tFault)
    Do $$$AssertTrue(..Holds($Get(tAfter), tDate, tNumber), "and the error survives")
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

/// <p>Mint through the delete tool's own declared mint (Story 7.10), so the scope arguments
/// <var>pArgs</var> are joined into the composite target as the dispatcher's call would join
/// them.</p>
ClassMethod MintScope(pArgs As %DynamicObject, pTurnKey As %String, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit $ClassMethod($ClassMethod(..#TOOL, "MintClass"), "Mint", ..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", pTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttp, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pArgs.%Get($ClassMethod(..#TOOL, "IdArgument")), $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p>One <code>POST</code> of the error log's <code>delete</code> against scope <var>pId</var> on
/// the screen-action route, as <var>pUser</var>, with <var>pQuery</var> appended to the path.</p>
ClassMethod DeleteOnScreen(pId As %String, pUser As %String, pPassword As %String, pQuery As %String, Output pStatus As %Integer, Output pBody As %String) As %Status
{
    Set tRequest = {}
    Do tRequest.%Set("action", "delete", "string")
    Do tRequest.%Set("id", pId, "string")
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/screens/" _ $ClassMethod(..#SCREEN, "ToolIdentifier") _ "/action" _ pQuery, pUser, pPassword, .pStatus, .pBody, .tHeaders, tRequest.%ToJSON(), "application/json")
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
