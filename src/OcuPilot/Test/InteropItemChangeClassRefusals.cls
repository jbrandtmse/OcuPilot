/// <p>Pins each refusal of Story 20.41's item change of class (AD-6, AD-8, AD-10, AD-16, AD-29, AD-51, AD-52, AD-62) against the probe
/// production in <code>USER</code>, by its code and with nothing written: a class the item's Classes tab does not list (not compiled,
/// abstract, of another kind), the item's own class, a bad class argument before any read, a name held twice, an absent item or
/// production, a namespace under source control or without interoperability, a caller missing a declared pair, and the reviewed set
/// moving between the review and the action or between the mint and the confirm. The change's legs that succeed are
/// <class>OcuPilot.Test.InteropItemChangeClass</class>'.</p>
/// <p>It uses <class>OcuPilot.Test.InteropItemChangeClass</class>'s and <class>OcuPilot.Test.InteropItemControl</class>'s class methods.
/// <b>What it needs from the environment:</b> as <class>OcuPilot.Test.InteropItemChangeClass</class>. One class per run.</p>
Class OcuPilot.Test.InteropItemChangeClassRefusals Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter CHANGE = "OcuPilot.Test.InteropItemChangeClass";

Parameter CONTROL = "OcuPilot.Test.InteropItemControl";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter SEAM = "OcuPilot.Test.InteropItemSeam";

Parameter TOOL = "OcuPilot.Screen.Tool.InteropItemChangeClass";

Parameter SCREEN = "/screens/interop.items";

Parameter ITEM = "OcuPilotProbeChg";

Parameter STORED = "OcuPilotProbe.Interop.Op|Host.HangSeconds=4471,Host.ApiToken=s3cretProbeValue,Host.TearDownSeconds=7";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemChangeClassRefusals compiles and runs a probe production in USER on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

/// <p>Remove the probe production, its classes and its proposals.</p>
Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "Remove")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $ClassMethod(..#CONTROL, "Reset")
}

/// <p>The seam and the fake gate are cleared, the probe's items and settings are put back, and its proposals are removed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Set tSC = $ClassMethod(..#CONTROL, "Reset")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "ResetProduction")
    Do $$$AssertStatusOK(tSC, "the probe production is left stopped with its items and settings as they began")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The code and status of the agent's mint of the change of <var>pName</var> to <var>pClass</var>, <code>status code</code>.</p>
ClassMethod MintText(pName As %String, pClass As %String, pArgs As %DynamicObject = "") As %String
{
    If '$IsObject(pArgs) Set pArgs = $ClassMethod(..#CHANGE, "ChangeArgs", pName, pClass)
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, pArgs, ##class(OcuPilot.Test.Http).GetTestUsername(), .tProposal, .tHttp, .tFault, .tTurn)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>A person's action or dry run of the change, <var>pRoute</var> <code>action</code> or <code>dryrun</code>, as <code>status code</code>;
/// <var>pValues</var> are the values, sent as given.</p>
ClassMethod Person(pRoute As %String, pValues As %DynamicObject, Output pAnswer, pName As %String = {..#ITEM}) As %String
{
    Set tBody = {"action": "changeclass"}
    Do tBody.%Set("values", pValues)
    Do tBody.%Set("id", $ClassMethod(..#CONTROL, "IdOf", pName), "string")
    Do $ClassMethod(..#CONTROL, "Call", "POST", ..#SCREEN _ "/" _ pRoute, tBody, .tStatus, .pAnswer)
    Quit tStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>AC3: a class the item's Classes tab does not list -- one that is not compiled, an abstract one, a class of another kind -- and the
/// class the item already has are refused 409 by <code>INTEROP.ITEM.NEWCLASS</code> and <code>INTEROP.ITEM.SAMECLASS</code> at the
/// composed read and again at the write, and the agent's mint and the person's dry run and action are refused the same, each with
/// nothing written.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.CandidateClasses</method> admit an abstract class -- the abstract row
/// goes red; drop the <code>SAMECLASS</code> refusal from <method>OcuPilot.Port.InteropPort.JudgeChange</method> -- the same-class
/// rows go red.</p>
Method TestAClassTheTabDoesNotListAndTheItemsOwnClassAreRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#CHANGE, "Prepare"), "the probe item and its three settings are stored")
    Do $$$AssertStatusOK(..MakeOtherClasses(), "an abstract operation class is compiled and another is defined and left uncompiled")
    For tCase = $ListBuild("OcuPilotProbe.No.Such.Class", "NEWCLASS"), $ListBuild("OcuPilotProbe.Interop.AbstractOp", "NEWCLASS"), $ListBuild("OcuPilotProbe.Interop.UncompiledOp", "NEWCLASS"), $ListBuild("Ens.BusinessOperation", "NEWCLASS"), $ListBuild("OcuPilotProbe.Interop.Svc", "NEWCLASS"), $ListBuild("EnsLib.MsgRouter.RoutingEngine", "NEWCLASS"), $ListBuild("ocupilotprobe.interop.tearop", "NEWCLASS"), $ListBuild("OcuPilotProbe.Interop.Op", "SAMECLASS") {
        Set tClass = $List(tCase, 1)
        Set tCode = "INTEROP.ITEM." _ $List(tCase, 2)
        Do $ClassMethod(..#CHANGE, "Dry", ..#ITEM, tClass, .tText)
        Do $$$AssertEquals(tText, "409 " _ tCode, tClass _ ": the composed read refuses it")
        Do $$$AssertEquals($ClassMethod(..#CHANGE, "PortChange", "OcuPilot.Port.InteropPort", ..#ITEM, tClass), "409 " _ tCode, tClass _ ": and the write refuses it again")
        Do $$$AssertEquals(..MintText(..#ITEM, tClass), "409 " _ tCode, tClass _ ": and the agent's mint")
        Set tValues = {}
        Do tValues.%Set("NewClass", tClass, "string")
        Do $$$AssertEquals(..Person("dryrun", tValues, .tAnswer), "409 " _ tCode, tClass _ ": and the person's dry run")
        Do tValues.%Set("Reviewed", "0000", "string")
        Do $$$AssertEquals(..Person("action", tValues, .tAnswer), "409 " _ tCode, tClass _ ": and the action, before the review is judged")
        Do $$$AssertEquals($ClassMethod(..#CHANGE, "Stored"), ..#STORED, tClass _ ": nothing was written")
    }
}

/// <p>AC3: a class argument that is empty, not a string, longer than 128 characters or not shaped like a class name is refused as a bad
/// argument before the instance is read: the agent's mint is 400 <code>TOOL.ARGUMENTS</code>, the person's dry run and action are refused
/// the same, and the port refuses one that reaches it by <code>INTEROP.ITEM.NEWCLASS</code>; the agent's schema offers no <code>Reviewed</code>.</p>
/// <p>Mutation (Rule 19): drop the <code>ArgumentProblem</code> call from <method>OcuPilot.Screen.Tool.InteropItemChangeClassMint.Mint</method> --
/// the mint rows go red.</p>
Method TestABadClassArgumentIsRefusedBeforeAnyRead()
{
    Do $$$AssertStatusOK($ClassMethod(..#CHANGE, "Prepare"), "the probe item and its three settings are stored")
    Set tLong = $Translate($Justify("", 129), " ", "A")
    Set tNew = $Parameter(..#CHANGE, "NEWCLASS")
    For tCase = $ListBuild(""), $ListBuild(tLong), $ListBuild("1BadName"), $ListBuild("Bad Name"), $ListBuild("Bad;Name") {
        Set tClass = $List(tCase, 1)
        Set tText = ..MintText(..#ITEM, tClass)
        Do $$$AssertEquals(tText, "400 TOOL.ARGUMENTS", "the mint of '" _ $Extract(tClass, 1, 20) _ "' is refused as an argument")
        Set tValues = {}
        Do tValues.%Set("NewClass", tClass, "string")
        Set tText = ..Person("dryrun", tValues, .tAnswer)
        Do $$$AssertTrue(($Extract(tText, 1, 1) = "4") && (tText '= "409 INTEROP.ITEM.NEWCLASS"), "the person's dry run of '" _ $Extract(tClass, 1, 20) _ "' is refused by the value rule, before the port reads the item: " _ tText)
        Do $ClassMethod(..#TOOL, "ConfirmProblem", "", {"NewClass": (tClass)}, .tConfirm)
        Do $$$AssertTrue(tConfirm '= "", "and a confirm of a stored payload carrying it is refused before the claim")
        Do $$$AssertEquals($ClassMethod(..#CHANGE, "PortChange", "OcuPilot.Port.InteropPort", ..#ITEM, tClass), "409 INTEROP.ITEM.NEWCLASS", "and the port refuses it too")
    }
    Set tArgs = $ClassMethod(..#CHANGE, "ChangeArgs", ..#ITEM, 5)
    Do tArgs.%Set("NewClass", 5, "number")
    Do $$$AssertEquals(..MintText(..#ITEM, "", tArgs), "400 TOOL.ARGUMENTS", "a class that is a number is refused")
    Set tValues = {"NewClass": 5}
    Set tText = ..Person("dryrun", tValues, .tAnswer)
    Do $$$AssertTrue(($Extract(tText, 1, 1) = "4") && (tText '= "409 INTEROP.ITEM.NEWCLASS"), "and the person's dry run of it is refused by the value rule: " _ tText)
    Do $ClassMethod(..#TOOL, "ConfirmProblem", "", {"NewClass": (tNew)}, .tConfirm)
    Do $$$AssertEquals(tConfirm, "", "while a confirm of a class the port may list passes the value rule")
    Set tArgs = $ClassMethod(..#CHANGE, "ChangeArgs", ..#ITEM, $Parameter(..#CHANGE, "NEWCLASS"))
    Do tArgs.%Set("Reviewed", "0000", "string")
    Do $$$AssertEquals(..MintText(..#ITEM, "", tArgs), "400 TOOL.ARGUMENTS", "an agent that sends the digest only a person's action carries is refused")
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Do $$$AssertEquals(tSchema.required.%ToJSON() _ "|" _ (tSchema.properties.%GetTypeOf("Reviewed") = "unassigned") _ "|" _ tSchema.properties.NewClass.type, "[""Name"",""Production"",""NewClass""]|1|string", "the schema requires the new class and offers no Reviewed")
    Do $$$AssertEquals($ClassMethod(..#CHANGE, "Stored"), ..#STORED, "nothing was written")
}

/// <p>AC3: the reviewed set is the written set for a value too. A person's dry run, then the value of a setting the change drops edited,
/// then the action or the port's write carrying that run's digest: 409 <code>INTEROP.ITEM.REVIEWCHANGED</code> with nothing written.</p>
/// <p>Mutation (Rule 19): leave a dropped setting's value out of <method>OcuPilot.Port.InteropPort.ChangeDigest</method> -- both rows go red.</p>
Method TestAValueThatMovedAfterTheReviewIsRefusedAndNothingIsWritten()
{
    Set tNew = $Parameter(..#CHANGE, "NEWCLASS")
    Do $$$AssertStatusOK($ClassMethod(..#CHANGE, "Prepare"), "the probe item and its three settings are stored")
    Set tValues = {"NewClass": (tNew)}
    Do $$$AssertEquals(..Person("dryrun", tValues, .tAnswer), "200 ", "the person's dry run is answered")
    Set tDigest = $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("review")): tAnswer.review.%Get("Digest"), 1: "")
    Do $$$AssertTrue(tDigest '= "", "and carries its digest")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Host", "HangSeconds", "9"), "the value of a setting the change drops is edited after the review")
    Set tStored = $ClassMethod(..#CHANGE, "Stored")
    Do $$$AssertTrue(tStored [ "Host.HangSeconds=9", "it is held: " _ tStored)
    Do tValues.%Set("Reviewed", tDigest, "string")
    Do $$$AssertEquals(..Person("action", tValues, .tDone), "409 INTEROP.ITEM.REVIEWCHANGED", "the action carrying the old digest is refused")
    Do $$$AssertEquals($ClassMethod(..#CHANGE, "PortChange", "OcuPilot.Port.InteropPort", ..#ITEM, tNew, tDigest), "409 INTEROP.ITEM.REVIEWCHANGED", "and so is the write with it")
    Do $$$AssertEquals($ClassMethod(..#CHANGE, "Stored"), tStored, "nothing was written")
}

/// <p>AC3: a name the production holds twice is refused 409 <code>INTEROP.ITEM.AMBIGUOUS</code> at the composed read, the mint and the write,
/// an item the production does not hold, and a production the namespace does not hold, are 404, a namespace without interoperability is 409
/// <code>INTEROP.NAMESPACE</code>, each with nothing written.</p>
/// <p>Mutation (Rule 19): drop the held-twice refusal under the lock in <method>OcuPilot.Port.InteropPort.ChangeStep</method> -- the write row
/// goes red.</p>
Method TestAnAmbiguousAbsentOrForeignItemIsRefused()
{
    Set tNew = $Parameter(..#CHANGE, "NEWCLASS")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", "OcuPilotProbeTwin", $Parameter(..#CHANGE, "OLDCLASS"), 1, 0), "an item named Twin is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddItem", "OcuPilotProbeTwin", $Parameter(..#CHANGE, "OLDCLASS"), 1, 0), "and a second item of its name")
    Do $ClassMethod(..#CHANGE, "Dry", "OcuPilotProbeTwin", tNew, .tText)
    Do $$$AssertEquals(tText, "409 INTEROP.ITEM.AMBIGUOUS", "the composed read refuses a name held twice")
    Do $$$AssertEquals($ClassMethod(..#CHANGE, "PortChange", "OcuPilot.Port.InteropPort", "OcuPilotProbeTwin", tNew), "409 INTEROP.ITEM.AMBIGUOUS", "and so does the write")
    Do $$$AssertEquals(..MintText("OcuPilotProbeTwin", tNew), "409 INTEROP.ITEM.AMBIGUOUS", "and the mint")
    Do $ClassMethod(..#CHANGE, "Dry", "OcuPilotProbeNone", tNew, .tText)
    Do $$$AssertEquals(tText, "404 PORT.NOTFOUND", "an item the production does not hold is not found")
    Do $$$AssertEquals($ClassMethod(..#CHANGE, "PortChange", "OcuPilot.Port.InteropPort", "OcuPilotProbeNone", tNew), "404 PORT.NOTFOUND", "at the write too")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = "OcuPilotProbe.No.Such" _ $Char(1) _ "OcuPilotProbeOp"
    Set tQuery("newClass") = tNew
    Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke("Items", "CHANGECLASS", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404 PORT.NOTFOUND", "a production the namespace does not hold is not found")
    Set tQuery("namespace") = "%SYS"
    Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke("Items", "CHANGECLASS", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 INTEROP.NAMESPACE", "a namespace without interoperability is refused for it")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Items"), $Parameter(..#CONTROL, "BASELINE") _ ",OcuPilotProbeTwin:0,OcuPilotProbeTwin:0", "nothing was written")
}

/// <p>AC3: the reviewed set is the written set. A person's dry run, then a setting the new class does not take added to the item, then the
/// action carrying that run's digest: 409 <code>INTEROP.ITEM.REVIEWCHANGED</code> with nothing written, and so is the port's write with a stale
/// digest; the agent's proposal minted, then the same change, then confirmed: closed target-changed, nothing written; a digest of the new
/// state is applied.</p>
/// <p>Mutation (Rule 19): drop the digest comparison from <method>OcuPilot.Port.InteropPort.ChangeStep</method> -- the person's and the
/// write's rows go red.</p>
Method TestASettingThatMovedAfterTheReviewIsRefusedAndNothingIsWritten()
{
    Set tNew = $Parameter(..#CHANGE, "NEWCLASS")
    Do $$$AssertStatusOK($ClassMethod(..#CHANGE, "Prepare"), "the probe item and its three settings are stored")
    Set tValues = {"NewClass": (tNew)}
    Do $$$AssertEquals(..Person("dryrun", tValues, .tAnswer), "200 ", "the person's dry run is answered")
    Set tDigest = $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("review")): tAnswer.review.%Get("Digest"), 1: "")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", ..#TOOL, $ClassMethod(..#CHANGE, "ChangeArgs", ..#ITEM, tNew), tUser, .tProposal, .tHttp, .tFault, .tTurn)
    Do $$$AssertStatusOK(tSC, "the agent's change mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "PutItemSetting", ..#ITEM, "Host", "InitSeconds", "3"), "another setting the new class does not take is stored after the review")
    Set tStored = $ClassMethod(..#CHANGE, "Stored")
    Do $$$AssertTrue(tStored [ "Host.InitSeconds=3", "it is held: " _ tStored)
    Do tValues.%Set("Reviewed", tDigest, "string")
    Do $$$AssertEquals(..Person("action", tValues, .tDone), "409 INTEROP.ITEM.REVIEWCHANGED", "the action carrying the old digest is refused")
    Do $$$AssertEquals($ClassMethod(..#CHANGE, "PortChange", "OcuPilot.Port.InteropPort", ..#ITEM, tNew, tDigest), "409 INTEROP.ITEM.REVIEWCHANGED", "and so is the write with it")
    Do $$$AssertEquals($ClassMethod(..#CHANGE, "Stored"), tStored, "nothing was written")
    If $IsObject($Get(tProposal)) {
        Set tSC = $ClassMethod(..#CHANGE, "KeyOn", .tPolicy)
        Do $$$AssertStatusOK(tSC, "the tool's key is turned on, so the proposal's own state is what the confirm judges")
        Try {
            Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .tAnswer2)
        } Catch ex {
            Do $$$AssertStatusOK(ex.AsStatus(), "the confirm raised")
        }
        Do $$$AssertStatusOK($ClassMethod(..#CHANGE, "KeyRestore", .tPolicy), "the policy found before the test is put back")
        Do $$$AssertEquals($Select($IsObject(tAnswer2): tStatus _ " " _ tAnswer2.%Get("code"), 1: tStatus), "409 PROPOSAL.TARGETCHANGED", "the agent's confirm closes the proposal target-changed: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#CHANGE, "Stored"), tStored, "and writes nothing")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    }
    Set tFresh = $ClassMethod(..#CHANGE, "Dry", ..#ITEM, tNew, .tText)
    Do $$$AssertEquals(tFresh.Dropped.%Size(), 3, "a read of the new state lists the third setting")
    Do $$$AssertEquals($ClassMethod(..#CHANGE, "PortChange", "OcuPilot.Port.InteropPort", ..#ITEM, tNew, tFresh.Digest), "200 ", "and its digest is applied")
    Do $$$AssertEquals($ClassMethod(..#CHANGE, "Stored"), tNew _ "|Host.TearDownSeconds=7", "dropping all three")
}

/// <p>AC3, AC5: a namespace under source control refuses a change by <code>INTEROP.ITEM.SOURCECONTROL</code> before anything is read, an
/// item write needs WRITE on the routines database as every item write does, and a caller missing one of the pairs the change
/// declares -- the Interoperability menu's, Production items' read, the configuration write, WRITE on the globals database -- is refused
/// naming it; the tool declares the add's pairs and the classic dialog's page.</p>
/// <p>Mutation (Rule 19): drop <code>CHANGECLASS</code> from <method>OcuPilot.Port.InteropPort.IsItemWrite</method> -- the routines row
/// goes red; set <parameter>OcuPilot.Screen.Tool.InteropItemChangeClass.ROUTINESDATABASE</parameter> to 0 -- the declaration row goes red.</p>
Method TestASourceControlledNamespaceAndAMissingPairAreRefused()
{
    Set tSeam = ..#SEAM
    Set tNew = $Parameter(..#CHANGE, "NEWCLASS")
    Do $$$AssertStatusOK($ClassMethod(..#CHANGE, "Prepare"), "the probe item and its three settings are stored")
    For tHeld = $ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_ProductionConfig", "READ"), $ListBuild("%Ens_ProductionConfig", "WRITE"), $ListBuild("%DB_USER", "READ"), $ListBuild("%DB_USER", "WRITE") {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tHeld, 1), $List(tHeld, 2))
    }
    Do $ClassMethod(tSeam, "Arm", "%DB_OCUP2041ROUTINES")
    Do $$$AssertEquals(..SeamChange(tSeam, tNew, .tFault), "403 AUTH.NOPRIVILEGE %DB_OCUP2041ROUTINES:WRITE", "a change without the routines database's WRITE is refused for it")
    Do $ClassMethod(tSeam, "Arm", "", 1)
    Do $$$AssertEquals(..SeamChange(tSeam, tNew, .tFault), "409 INTEROP.ITEM.SOURCECONTROL", "a change in a namespace under source control is refused for it")
    Do $ClassMethod(tSeam, "Arm", "", 0)
    For tMissing = $ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_ProductionConfig", "READ"), $ListBuild("%Ens_ProductionConfig", "WRITE"), $ListBuild("%DB_USER", "WRITE") {
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        For tHeld = $ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_ProductionConfig", "READ"), $ListBuild("%Ens_ProductionConfig", "WRITE"), $ListBuild("%DB_USER", "READ"), $ListBuild("%DB_USER", "WRITE") {
            If tHeld '= tMissing Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tHeld, 1), $List(tHeld, 2))
        }
        Do $$$AssertEquals(..SeamChange(tSeam, tNew, .tFault), "403 AUTH.NOPRIVILEGE " _ $List(tMissing, 1) _ ":" _ $List(tMissing, 2), $List(tMissing, 1) _ ":" _ $List(tMissing, 2) _ " missing: the change is refused naming it")
    }
    Do $$$AssertEquals($ClassMethod(..#CHANGE, "Stored"), ..#STORED, "no refused change wrote anything")
    Set tPairs = $ClassMethod(..#TOOL, "PrivilegePairs", "", .tResolved)
    Set tAddPairs = $ClassMethod("OcuPilot.Screen.Tool.InteropItemAdd", "PrivilegePairs", "", .tAddResolved)
    Do $$$AssertTrue(tResolved && tAddResolved, "both tools' pairs resolve")
    Set tMissingCount = 0
    For tI = 1:1:$ListLength(tAddPairs) {
        If '$ListFind(tPairs, $List(tAddPairs, tI)) Set tMissingCount = tMissingCount + 1
    }
    Do $$$AssertEquals(tMissingCount, 0, "the tool declares every pair the add does")
    Do $$$AssertEquals($Parameter(..#TOOL, "ROUTINESDATABASE") _ "|" _ $Parameter(..#TOOL, "DESTRUCTIVE") _ "|" _ $Parameter(..#TOOL, "WRITETYPE") _ "|" _ $Parameter(..#TOOL, "CLASSICPAGES") _ "|" _ $Parameter(..#TOOL, "CONSEQUENCECODE"), "1|1|CHANGECLASS|EnsPortal.Dialog.ChangeClass|INTEROP.ITEM.CHANGECLASS", "it writes the routines database too, is destructive, and declares the classic dialog and its consequence")
}

/// <p>Define two more operation classes in the probe package, which <class>OcuPilot.Test.ProductionProbe</class>'s remove deletes with the
/// rest: <code>AbstractOp</code>, abstract and compiled, and <code>UncompiledOp</code>, concrete and not compiled.</p>
ClassMethod MakeOtherClasses() As %Status
{
    Set tNL = $Char(13, 10)
    Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString("USER", "OcuPilotProbe.Interop.AbstractOp", "Class OcuPilotProbe.Interop.AbstractOp Extends Ens.BusinessOperation [ Abstract ]" _ tNL _ "{" _ tNL _ "Parameter INVOCATION = ""Queue"";" _ tNL _ "}" _ tNL)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(%Compiler.UDL.TextServices).SetTextFromString("USER", "OcuPilotProbe.Interop.UncompiledOp", "Class OcuPilotProbe.Interop.UncompiledOp Extends Ens.BusinessOperation" _ tNL _ "{" _ tNL _ "Parameter INVOCATION = ""Queue"";" _ tNL _ "}" _ tNL)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "USER"
        Set tSC = $System.OBJ.Compile("OcuPilotProbe.Interop.AbstractOp", "ck-d")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The change of <parameter>ITEM</parameter> to <var>pClass</var> through <var>pSeam</var> as <code>status code failedPair</code>.</p>
ClassMethod SeamChange(pSeam As %String, pClass As %String, Output pFault) As %String
{
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = $ClassMethod(..#CONTROL, "IdOf", ..#ITEM)
    Set tQuery("newClass") = pClass
    Set tSC = $ClassMethod(pSeam, "Invoke", "Items", "CHANGECLASS", .tQuery, "", .tResult, .tHttp, .pFault)
    Set tText = +$Get(tHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
    If $IsObject($Get(pFault)) && $IsObject(pFault.%Get("detail")) && (pFault.detail.%Get("failedPair") '= "") Set tText = tText _ " " _ pFault.detail.%Get("failedPair")
    Quit tText
}

}
