/// <p>Pins Story 20.5's refusals end to end against probe lookup tables in <code>USER</code> (AD-12, AD-35, AD-39, AD-54,
/// AD-55, AD-62): each row of the plan's refusal matrix is refused by its own code with its published sentence, before any vendor
/// call, and nothing is written -- a key the table holds, a table held in another letter case, a key that holds a credential, a
/// value the entry already holds, a name, key or value over the vendor's limits (422), a value of the wrong JSON type, an
/// entry or table that is not there (404), a vendor lock held past the wait, a namespace under source control and a namespace
/// that runs no interoperability; and the guards of an import -- source control at its read and its write, the vendor lock, a
/// table that moves between the write's first read and its lock -- and the value the agent sent for a credential key, which its
/// ledger row and step do not carry. The person's Save and row actions, the agent's mint and the port itself are each driven where
/// they can be; the vendor lock is held by this process, so the requests, which run in other processes, wait it out.</p>
/// <p>A namespace under source control, and a table that moves under a write, are arranged in process through
/// <class>OcuPilot.Test.InteropItemSeam</class>, because no throwaway can be put under source control and no second process is
/// there to move a table: those legs drive the port, which both callers reach.</p>
/// <p><b>What it needs from the environment:</b> an interoperability-enabled <code>USER</code> namespace, the HTTP test account
/// and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It removes every table it creates.</p>
Class OcuPilot.Test.InteropLookupRefusals Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropLookupControl";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter TRANSFER = "OcuPilot.Test.InteropLookupTransfer";

Parameter LEDGER = "OcuPilot.Test.Ledger";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The value the agent sends under a credential key: it may reach no ledger row and no step.</p>
Parameter SENT = "ocu-sent-secret-77be";

Parameter ERROR = "OcuPilot.Api.InteropError";

Parameter TABLE = "OcuProbe205Refuse";

Parameter ENTRYSCREEN = "/screens/interop.lookupentries";

Parameter TABLESCREEN = "/screens/interop.lookuptables";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropLookupRefusals writes probe lookup tables in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "Clear"), "the probe tables are removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The published sentence of the code <var>pName</var> names (a parameter of <class>OcuPilot.Api.InteropError</class>).</p>
ClassMethod Reason(pName As %String) As %String
{
    Quit $Parameter(..#ERROR, "REASON" _ pName)
}

/// <p>The person's Save of an entry, the body as given: <code>status code</code>, the answer in <var>pAnswer</var>.</p>
ClassMethod SaveBody(pBody As %DynamicObject, Output pAnswer) As %String
{
    Do $ClassMethod("OcuPilot.Test.InteropItemControl", "Call", "POST", "/interop/lookup-entries", pBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The agent's mint of <var>pTool</var> for <var>pArgs</var>: <code>status code</code> of the refusal, <code>minted</code>
/// when it was not refused. The fault's reason is in <var>pReason</var>.</p>
ClassMethod MintVerdict(pTool As %String, pArgs As %DynamicObject, Output pReason As %String) As %String
{
    Set pReason = ""
    Set tSC = $ClassMethod(..#CONTROL, "Mint", pTool, pArgs, .tProposal, .tFault, .tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    If $IsObject($Get(tProposal)) Quit "minted"
    If '$IsObject($Get(tFault)) Quit "refused"
    Set pReason = tFault.%Get("reason")
    Quit tFault.%Get("code")
}

/// <p>Declare the pairs of every lookup read and write held, so the port driven in process through the seam passes its gate for
/// <code>USER</code>.</p>
ClassMethod HoldLookupPairs()
{
    For tPair = $ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_LookupTables", "READ"), $ListBuild("%Ens_LookupTables", "WRITE"), $ListBuild("%DB_USER", "READ"), $ListBuild("%DB_USER", "WRITE") {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tPair, 1), $List(tPair, 2))
    }
}

/// <p>The import query for the local file <var>pText</var> into <var>pQuery</var>, naming the import's own target.</p>
ClassMethod ImportQuery(pText As %String, Output pQuery)
{
    Kill pQuery
    Set pQuery("namespace") = "USER"
    Set pQuery("id") = "import"
    Set pQuery("fileName") = "t.xml"
    Set pQuery("content") = pText
}

/// <p>The write query for the import <var>pQuery</var> names, carrying the reviewed digest, entry count and stamp the port's own
/// read of it answers (through the shipped port, which the process's privileges admit), into <var>pWrite</var>; the read's HTTP
/// status.</p>
ClassMethod Reviewed(ByRef pQuery, Output pWrite) As %Integer
{
    Kill tReview
    Merge tReview = pQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", "LookupTables", "IMPORTTABLE", .tReview, "", .tRow, .tHttp, .tFault)
    Kill pWrite
    Merge pWrite = pQuery
    If $IsObject($Get(tRow)) {
        Set pWrite("digest") = tRow.Digest
        Set pWrite("entries") = tRow.Entries
        Set pWrite("modified") = tRow.Modified
    }
    Quit +$Get(tHttp)
}

/// <p>AC4: an add of a key the table holds is <code>TAKEN</code>, an add into a table held in another letter case is
/// <code>TABLECASE</code>, and an add or set of a key that holds a credential is <code>SECRET</code> -- each from the person's
/// Save or row action and from the agent's mint, with its published sentence, and nothing is written.</p>
/// <p>Mutation (Rule 19): drop the <code>TABLECASE</code> test from <method>OcuPilot.Port.InteropPort.LookupWriteToken</method>,
/// or the credential test from <method>OcuPilot.Port.InteropPort.ReadLookupEntry</method> -- its leg goes red.</p>
Method TestTakenTableCaseAndSecretAreRefusedFromBothCallers()
{
    Set tFixture = ..#FIXTURE
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "held", "value")
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "dbpassword", "hunter2")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Set tControl = ..#CONTROL
    Do $$$AssertEquals(..SaveBody({"Table": (..#TABLE), "Key": "held", "Value": "other"}, .tAnswer), "409 INTEROP.LOOKUP.TAKEN", "the Save of a held key is taken")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.reason, 1: ""), ..Reason("LOOKUPTAKEN"), "with the published sentence")
    Do $$$AssertEquals(..MintVerdict("InteropLookupEntryAdd", $ClassMethod(tControl, "ArgsFor", ..#TABLE, "held", "other"), .tReason) _ "|" _ tReason, "INTEROP.LOOKUP.TAKEN|" _ ..Reason("LOOKUPTAKEN"), "and so is the agent's")
    Set tOther = $ZConvert(..#TABLE, "U")
    Do $$$AssertEquals(..SaveBody({"Table": (tOther), "Key": "new", "Value": "v"}, .tAnswer), "409 INTEROP.LOOKUP.TABLECASE", "the Save into a table held in another letter case is refused for it")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.reason, 1: ""), ..Reason("LOOKUPTABLECASE"), "with the published sentence")
    Do $$$AssertEquals(..MintVerdict("InteropLookupEntryAdd", $ClassMethod(tControl, "ArgsFor", tOther, "new", "v"), .tReason) _ "|" _ tReason, "INTEROP.LOOKUP.TABLECASE|" _ ..Reason("LOOKUPTABLECASE"), "and so is the agent's")
    Do $$$AssertEquals(..SaveBody({"Table": (..#TABLE), "Key": "apiPassword", "Value": "v"}, .tAnswer), "409 INTEROP.LOOKUP.SECRET", "the Save of a credential key is refused")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.reason, 1: ""), ..Reason("LOOKUPSECRET"), "with the published sentence")
    Do $$$AssertEquals(..MintVerdict("InteropLookupEntryAdd", $ClassMethod(tControl, "ArgsFor", ..#TABLE, "apiPassword", "v"), .tReason) _ "|" _ tReason, "INTEROP.LOOKUP.SECRET|" _ ..Reason("LOOKUPSECRET"), "and so is the agent's add")
    Set tText = $ClassMethod(tControl, "Act", ..#ENTRYSCREEN, "set", $ClassMethod(tControl, "Id", ..#TABLE, "dbpassword"), "changed", .tAnswer)
    Do $$$AssertEquals(tText, "409 INTEROP.LOOKUP.SECRET", "the person's Set value of a credential key is refused")
    Do $$$AssertEquals(..MintVerdict("InteropLookupEntrySet", $ClassMethod(tControl, "ArgsFor", ..#TABLE, "dbpassword", "changed"), .tReason) _ "|" _ tReason, "INTEROP.LOOKUP.SECRET|" _ ..Reason("LOOKUPSECRET"), "and so is the agent's set")
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "nothing was written")
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "dbpassword=hunter2;held=value", "the credential key's value stands, unread by any refusal")
}

/// <p>AC4: a set of the value the entry holds is <code>SAME</code>, from the row action and from the agent's mint, each with the
/// published sentence; a set, remove or delete of what the table does not hold is 404; and nothing is written.</p>
/// <p>Mutation (Rule 19): drop the <code>SAME</code> test from <method>OcuPilot.Port.InteropPort.LookupWriteToken</method> --
/// the person's leg goes red; drop the check from <method>OcuPilot.Screen.Tool.InteropLookupEntryMint.Mint</method> -- the agent's
/// leg does.</p>
Method TestSameAndAbsentAreRefusedFromBothCallers()
{
    Set tFixture = ..#FIXTURE
    Set tControl = ..#CONTROL
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "held", "value")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Set tId = $ClassMethod(tControl, "Id", ..#TABLE, "held")
    Do $$$AssertEquals($ClassMethod(tControl, "Act", ..#ENTRYSCREEN, "set", tId, "value", .tAnswer), "409 INTEROP.LOOKUP.SAME", "the person's Set value to the value held is refused")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.reason, 1: ""), ..Reason("LOOKUPSAME"), "with the published sentence")
    Do $$$AssertEquals(..MintVerdict("InteropLookupEntrySet", $ClassMethod(tControl, "ArgsFor", ..#TABLE, "held", "value"), .tReason) _ "|" _ tReason, "INTEROP.LOOKUP.SAME|" _ ..Reason("LOOKUPSAME"), "and so is the agent's set to the value held, at the mint")
    Set tGone = $ClassMethod(tControl, "Id", ..#TABLE, "gone")
    Do $$$AssertEquals($ClassMethod(tControl, "Act", ..#ENTRYSCREEN, "set", tGone, "v", .tAnswer), "404 PORT.NOTFOUND", "a Set value of an entry the table does not hold is not found")
    Do $$$AssertEquals($ClassMethod(tControl, "Act", ..#ENTRYSCREEN, "remove", tGone, $Char(0), .tAnswer), "404 PORT.NOTFOUND", "so is a Remove")
    Do $$$AssertEquals($ClassMethod(tControl, "Act", ..#TABLESCREEN, "delete", "OcuProbe205NoSuch", $Char(0), .tAnswer), "404 PORT.NOTFOUND", "and a Delete of a table that is not there")
    Set tArgs = {}
    Do tArgs.%Set("Name", "OcuProbe205NoSuch", "string")
    Do $$$AssertEquals(..MintVerdict("InteropLookupTableDelete", tArgs), "TOOL.ARGUMENTS", "the agent's delete of a table that is not there is refused: it names no table of this instance")
    Do $$$AssertEquals(..MintVerdict("InteropLookupEntryRemove", $ClassMethod(tControl, "ArgsFor", ..#TABLE, "gone")), "TOOL.ARGUMENTS", "so is its remove of an entry the table does not hold")
    Do $$$AssertEquals(..MintVerdict("InteropLookupEntrySet", $ClassMethod(tControl, "ArgsFor", ..#TABLE, "gone", "v")), "TOOL.ARGUMENTS", "and its set")
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "nothing was written")
}

/// <p>AC4: a table name, key or value over the vendor's limits, an empty table or key, and a value that is not a string are
/// each a 422 from the Save with the violation's code and published sentence naming its field, and the agent's mint refuses the
/// same call; nothing is written.</p>
/// <p>Mutation (Rule 19): raise <code>KEYMAX</code> in <class>OcuPilot.Port.InteropPort</class> to 256 -- the key leg goes red.</p>
Method TestFieldsOverTheVendorsLimitsAreRefusedWithTheirViolations()
{
    Set tFixture = ..#FIXTURE
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Set tLong = $Justify("", 256)
    Set tLong = $Translate(tLong, " ", "x")
    Do $$$AssertEquals(..SaveBody({"Table": (..#TABLE), "Key": (tLong), "Value": "v"}, .tAnswer), "422 INTEROP.LOOKUP.KEY", "a 256-character key is refused")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.detail.violations.%Get(0).field _ "|" _ tAnswer.detail.violations.%Get(0).reason, 1: ""), "Key|" _ ..Reason("LOOKUPKEY"), "naming the key with its sentence")
    Do $$$AssertEquals(..SaveBody({"Table": (tLong), "Key": "k", "Value": "v"}, .tAnswer), "422 INTEROP.LOOKUP.TABLENAME", "a 256-character table name is refused")
    Set tBig = $Translate($Justify("", 32001), " ", "v")
    Do $$$AssertEquals(..SaveBody({"Table": (..#TABLE), "Key": "k", "Value": (tBig)}, .tAnswer), "422 INTEROP.LOOKUP.VALUE", "a 32,001-character value is refused")
    Do $$$AssertEquals(..SaveBody({"Table": (..#TABLE), "Key": "", "Value": "v"}, .tAnswer), "422 INTEROP.LOOKUP.KEY", "an empty key is refused")
    Do $$$AssertEquals(..SaveBody({"Table": "", "Key": "k", "Value": "v"}, .tAnswer), "422 INTEROP.LOOKUP.TABLENAME", "and an empty table")
    Do $$$AssertEquals(..SaveBody({"Table": (..#TABLE), "Key": ("k" _ $Char(9)), "Value": "v"}, .tAnswer), "422 INTEROP.LOOKUP.KEY", "a control character in a key is refused")
    Do $$$AssertEquals(..SaveBody({"Table": (..#TABLE), "Key": "k", "Value": 5}, .tAnswer), "422 PORT.FIELD.SHAPE", "a value that is not a string is refused for its shape")
    Do $$$AssertEquals(..SaveBody({"Table": (..#TABLE), "Key": "k", "Value": "v", "Other": "x"}, .tAnswer), "400 PORT.FIELD.UNEXPECTED", "a field the add does not settle is refused")
    Do $$$AssertEquals(..SaveBody({"Table": (..#TABLE), "Key": "k", "Value": "v"}, .tAnswer), "201 ", "and the same entry within the limits is added")
    Set tControl = ..#CONTROL
    Do $$$AssertNotEquals(..MintVerdict("InteropLookupEntryAdd", $ClassMethod(tControl, "ArgsFor", ..#TABLE, tLong, "v")), "minted", "the agent's add of a 256-character key is refused at the mint")
    Do $$$AssertNotEquals(..MintVerdict("InteropLookupEntryAdd", $ClassMethod(tControl, "ArgsFor", ..#TABLE, "k2", tBig)), "minted", "so is a 32,001-character value")
    Do $ClassMethod(tFixture, "Clear")
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "no refused call wrote a thing")
}

/// <p>AC4: a vendor lock held past the wait is <code>LOCKED</code> from the Save, the row actions and the port, with nothing
/// written; the lock is held by this process, so the requests, which run in other processes, wait the three seconds out.</p>
/// <p>Mutation (Rule 19): skip <code>LockTable</code> in <method>OcuPilot.Port.InteropPort.PerformLookup</method> -- every
/// leg here goes red, since the write then goes ahead.</p>
Method TestAHeldVendorLockIsRefusedLockedAndNothingIsWritten()
{
    Set tFixture = ..#FIXTURE
    Set tControl = ..#CONTROL
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "held", "value")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Set tOrigNS = $NAMESPACE
    Set tLocked = 0
    Try {
        Set $NAMESPACE = "USER"
        Lock +^Ens.LookupTable(..#TABLE):5
        Set tLocked = $Test
        Set $NAMESPACE = tOrigNS
        Do $$$AssertTrue(tLocked, "this process holds the table's vendor lock")
        If tLocked {
            Do $$$AssertEquals(..SaveBody({"Table": (..#TABLE), "Key": "new", "Value": "v"}, .tAnswer), "409 INTEROP.LOOKUP.LOCKED", "the Save is refused while the lock is held")
            Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.reason, 1: ""), ..Reason("LOOKUPLOCKED"), "with the published sentence")
            Do $$$AssertEquals($ClassMethod(tControl, "Act", ..#ENTRYSCREEN, "set", $ClassMethod(tControl, "Id", ..#TABLE, "held"), "changed", .tAnswer), "409 INTEROP.LOOKUP.LOCKED", "so is the row action Set value")
            Do $$$AssertEquals($ClassMethod(tControl, "Act", ..#TABLESCREEN, "delete", ..#TABLE, $Char(0), .tAnswer), "409 INTEROP.LOOKUP.LOCKED", "and Delete")
            Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "and nothing was written")
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the lock leg raised")
    }
    Set $NAMESPACE = "USER"
    Lock -^Ens.LookupTable(..#TABLE)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(..SaveBody({"Table": (..#TABLE), "Key": "new", "Value": "v"}, .tAnswer), "201 ", "once the lock is released the same Save goes ahead")
}

/// <p>AC4: a namespace under source control refuses every lookup write by <code>SOURCECONTROL</code> before the vendor is called,
/// the composed reads of a write included, while the lists stay readable; and a namespace that runs no interoperability is
/// refused <code>INTEROP.NAMESPACE</code>. Both are driven through the port both callers reach.</p>
/// <p>Mutation (Rule 19): drop the <code>SourceControlled</code> refusal from
/// <method>OcuPilot.Port.InteropPort.PerformLookup</method> -- the write rows go red.</p>
Method TestASourceControlledNamespaceAndAPlainOneAreRefusedByTheirCodes()
{
    Set tFixture = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "held", "value")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Do ..HoldLookupPairs()
    Do $ClassMethod(tSeam, "Arm", "", 1)
    Kill tList
    Set tList("namespace") = "USER"
    Set tSC = $ClassMethod(tSeam, "Invoke", "LookupTables", "LIST", .tList, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the tables list is readable under source control")
    For tWrite = $ListBuild("LookupEntries", "ADDENTRY", $ClassMethod("OcuPilot.Test.InteropLookupControl", "Id", ..#TABLE, "new"), {"Value": "v"}), $ListBuild("LookupEntries", "SETENTRY", $ClassMethod("OcuPilot.Test.InteropLookupControl", "Id", ..#TABLE, "held"), {"Value": "changed"}), $ListBuild("LookupEntries", "REMOVEENTRY", $ClassMethod("OcuPilot.Test.InteropLookupControl", "Id", ..#TABLE, "held"), ""), $ListBuild("LookupTables", "DELETETABLE", ..#TABLE, "") {
        Kill tQuery
        Set tQuery("namespace") = "USER"
        Set tQuery("id") = $List(tWrite, 3)
        Set tSC = $ClassMethod(tSeam, "Invoke", $List(tWrite, 1), $List(tWrite, 2), .tQuery, $List(tWrite, 4), .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "409 INTEROP.LOOKUP.SOURCECONTROL", $List(tWrite, 2) _ " is refused for source control")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.reason, 1: ""), ..Reason("LOOKUPSOURCECONTROL"), "with the published sentence")
    }
    For tAction = "ADDENTRY", "SETENTRY", "REMOVEENTRY" {
        Kill tQuery
        Set tQuery("namespace") = "USER"
        Set tQuery("id") = $ClassMethod("OcuPilot.Test.InteropLookupControl", "Id", ..#TABLE, "held")
        Set tQuery("action") = tAction
        Set tSC = $ClassMethod(tSeam, "Invoke", "LookupEntries", "LOOKUPENTRY", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "409 INTEROP.LOOKUP.SOURCECONTROL", "the entry read composed for " _ tAction _ " is refused too")
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "nothing was written")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "and nothing was logged as a fault")
    Do $ClassMethod(tSeam, "Disarm")
    Kill tQuery
    Set tQuery("namespace") = "%SYS"
    Set tSC = $ClassMethod(tSeam, "Invoke", "LookupTables", "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "409 INTEROP.NAMESPACE", "a namespace that runs no interoperability is refused for it")
}

/// <p>AC4: dispatched through the agent's tool loop, an add or a set whose key matches the credential pattern is refused, and
/// neither its ledger row nor its step carries the value the agent sent for it, which reads as the redaction mark while the table's
/// name is kept; a value sent beside an ordinary key is kept in both, so the value's redaction is the key's doing and not every call's.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropLookupEntryAction.CallSecretNames</method> quit <code>""</code>
/// -- the two credential rows go red.</p>
Method TestAValueTheAgentSentForACredentialKeyIsRedactedInTheLedgerRowAndTheStep()
{
    Set tFixture = ..#FIXTURE
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "dbpassword", "hunter2")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    For tCase = $ListBuild("interop.lookupentries.add", "apiPassword", 1), $ListBuild("interop.lookupentries.set", "dbpassword", 1), $ListBuild("interop.lookupentries.set", "ordinaryKey", 0) {
        Set tName = $List(tCase, 1)
        Set tLabel = tName _ " for " _ $List(tCase, 2)
        Set tTurn = $ClassMethod(..#LEDGER, "NewTurnKey")
        Set tUse = {"id": "toolu_lookup"}
        Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(tName), "string")
        Do tUse.%Set("input", $ClassMethod(..#CONTROL, "ArgsFor", ..#TABLE, $List(tCase, 2), ..#SENT))
        Set tUses = []
        Do tUses.%Push(tUse)
        Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurn, $Username, "1", tUses, ..#LIMITS, .tResults, .tNames, , , .tDetails, "interoperability/lookup-tables/entries")
        Do $$$AssertStatusOK(tSC, tLabel _ ": the dispatcher answers the call")
        Do $$$AssertEquals(tResults.%Size() _ "|" _ tResults.%Get(0).%Get("is_error"), "1|1", tLabel _ ": the call is refused")
        Set tText = $ClassMethod(..#LEDGER, "RowText", tTurn)
        Set tStepArgs = $Select(tDetails.%Size() = 1: tDetails.%Get(0).arguments, 1: "")
        Do $$$AssertTrue(tText '= "", tLabel _ ": the row was stored: " _ tText)
        If $List(tCase, 3) {
            Do $$$AssertEquals(tText [ ..#SENT, 0, tLabel _ ": no column of the ledger row carries the value sent: " _ tText)
            Do $$$AssertEquals(tStepArgs [ ..#SENT, 0, tLabel _ ": and the step's arguments do not: " _ tStepArgs)
            Do $$$AssertTrue((tText [ "[redacted]") && (tStepArgs [ "[redacted]"), tLabel _ ": the value reads as redacted in both")
            Do $$$AssertTrue((tText [ ..#TABLE) && (tStepArgs [ ..#TABLE), tLabel _ ": while the table's name is kept")
        } Else {
            Do $$$AssertTrue((tText [ ..#SENT) && (tStepArgs [ ..#SENT), tLabel _ ": a value sent beside an ordinary key is kept in the row and the step")
        }
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "no refused call wrote a thing")
}

/// <p>AC4, AC9: an import is refused <code>SOURCECONTROL</code> in a namespace under source control, at the read composed for it
/// and at the write, before the file is loaded: the table keeps an entry the file lacks, which a load would remove. The import's
/// read without an action stays readable.</p>
/// <p>Mutation (Rule 19): delete the <code>SourceControlled</code> line from <method>OcuPilot.Port.InteropPort.ReadImportTable</method>
/// -- the read leg goes red; delete it from <method>OcuPilot.Port.InteropPort.PerformImport</method> -- the write leg does.</p>
Method TestAnImportIsRefusedForSourceControlAtItsReadAndItsWrite()
{
    Set tFixture = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "held", "value")
    Set tText = $ClassMethod(..#TRANSFER, "ExportText", ..#TABLE _ ".LUT")
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "extra", "not in the file")
    Do ..ImportQuery(tText, .tQuery)
    Do $$$AssertEquals(..Reviewed(.tQuery, .tWrite), 200, "the import is reviewed before the namespace is put under source control")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Do ..HoldLookupPairs()
    Do $ClassMethod(tSeam, "Arm", "", 1)
    Kill tRead
    Merge tRead = tQuery
    Set tSC = $ClassMethod(tSeam, "Invoke", "LookupTables", "IMPORTTABLE", .tRead, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the import's read without an action is readable under source control")
    Kill tRead
    Merge tRead = tQuery
    Set tRead("action") = "IMPORT"
    Set tSC = $ClassMethod(tSeam, "Invoke", "LookupTables", "IMPORTTABLE", .tRead, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ "|" _ tFault.reason, 1: ""), "409 INTEROP.LOOKUP.SOURCECONTROL|" _ ..Reason("LOOKUPSOURCECONTROL"), "the read composed for the import is refused for source control, with the published sentence")
    Set tSC = $ClassMethod(tSeam, "Invoke", "LookupTables", "IMPORT", .tWrite, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ "|" _ tFault.reason, 1: ""), "409 INTEROP.LOOKUP.SOURCECONTROL|" _ ..Reason("LOOKUPSOURCECONTROL"), "and so is the write")
    Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "nothing was loaded: the table keeps the entry the file lacks")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "and nothing was logged as a fault")
}

/// <p>AC4, AC9: an import is refused <code>LOCKED</code> while another process holds the table's vendor lock, from the screen's
/// local-file action, and loads nothing; the same action goes ahead once the lock is released and replaces the table with the
/// file's entries. The lock is held by this process, so the request, which runs in another, waits the three seconds out.</p>
/// <p>Mutation (Rule 19): skip the lock in <method>OcuPilot.Port.InteropPort.PerformImport</method> -- the locked leg goes red.</p>
Method TestAnImportIsRefusedLockedWhileTheVendorLockIsHeld()
{
    Set tFixture = ..#FIXTURE
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "held", "value")
    Set tText = $ClassMethod(..#TRANSFER, "ExportText", ..#TABLE _ ".LUT")
    Do $ClassMethod(tFixture, "Put", ..#TABLE, "extra", "not in the file")
    Set tBefore = $ClassMethod(tFixture, "Snapshot")
    Set tValues = {"fileName": "t.xml", "content": (tText)}
    Set tOrigNS = $NAMESPACE
    Set tLocked = 0
    Try {
        Set $NAMESPACE = "USER"
        Lock +^Ens.LookupTable(..#TABLE):5
        Set tLocked = $Test
        Set $NAMESPACE = tOrigNS
        Do $$$AssertTrue(tLocked, "this process holds the table's vendor lock")
        If tLocked {
            Do $ClassMethod(..#TRANSFER, "Act", "import-local", "import", tValues, .tStatus, .tBody)
            Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tBody): tBody.%Get("code") _ "|" _ tBody.%Get("reason"), 1: ""), "409 INTEROP.LOOKUP.LOCKED|" _ ..Reason("LOOKUPLOCKED"), "the import is refused while the lock is held, with the published sentence")
            Do $$$AssertEquals($ClassMethod(tFixture, "Snapshot"), tBefore, "and nothing was loaded")
        }
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the lock leg raised")
    }
    Set $NAMESPACE = "USER"
    Lock -^Ens.LookupTable(..#TABLE)
    Set $NAMESPACE = tOrigNS
    Do $ClassMethod(..#TRANSFER, "Act", "import-local", "import", tValues, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "once the lock is released the same import goes ahead: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), "held=value", "and replaces the table with the file's entries")
}

/// <p>AC9: an import whose table moves between the write's first read and the vendor lock -- its stamp alone (a value set), or its
/// stamp and its entry count (an entry added) -- is refused <code>IMPORTCHANGED</code> with nothing loaded: the table keeps the entry
/// the file lacks, and the move.</p>
/// <p>Mutation (Rule 19): drop the stamp and count comparison made under the lock from
/// <method>OcuPilot.Port.InteropPort.PerformImport</method> -- both legs go red.</p>
Method TestAnImportIsRefusedChangedWhenTheTableMovesBetweenItsReadAndItsLock()
{
    Set tFixture = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do ..HoldLookupPairs()
    ; <label>|<key moved>|<value moved to>|<entries left>
    For tCase = $ListBuild("its stamp moves", "held", "moved", "held=moved;keep=me"), $ListBuild("its stamp and its entry count move", "added", "1", "added=1;held=value;keep=me") {
        Do $ClassMethod(tFixture, "Clear")
        Do $ClassMethod(tFixture, "Put", ..#TABLE, "held", "value")
        Set tText = $ClassMethod(..#TRANSFER, "ExportText", ..#TABLE _ ".LUT")
        Do $ClassMethod(tFixture, "Put", ..#TABLE, "keep", "me")
        Do ..ImportQuery(tText, .tQuery)
        Do $$$AssertEquals(..Reviewed(.tQuery, .tWrite), 200, $List(tCase, 1) _ ": the import is reviewed")
        Do $ClassMethod(tSeam, "MoveTableBeforeLock", ..#TABLE, $List(tCase, 2), $List(tCase, 3))
        Set tSC = $ClassMethod(tSeam, "Invoke", "LookupTables", "IMPORT", .tWrite, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ "|" _ tFault.reason, 1: ""), "409 INTEROP.LOOKUP.IMPORTCHANGED|" _ ..Reason("LOOKUPIMPORTCHANGED"), $List(tCase, 1) _ ": the import is refused as changed since review, with the published sentence")
        Do $$$AssertEquals($ClassMethod(tFixture, "Entries", ..#TABLE), $List(tCase, 4), $List(tCase, 1) _ ": nothing was loaded")
    }
}

}
