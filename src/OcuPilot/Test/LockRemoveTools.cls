/// <p>Pins Story 16.12's three lock removals, their port and the kernel's lock arm on canned reads
/// (AD-3, AD-8, AD-10, AD-22, AD-44, AD-51, AD-52, AD-59): each tool registers as an action-style
/// write over <class>OcuPilot.Port.LockPort</class> with no field list; each requires the screen's
/// pairs and <code>%DB_IRISSYS:WRITE</code> and declares the classic Manage Locks page; the three keys
/// ship enabled; the port query asks the vendor's in-transaction check for a local owner unless
/// overridden and never for a remote one; the owner tools refuse the wrong owner kind and a set above
/// 200; an override on a local owner carries the consequence; the arm refuses a lock on OcuPilot's own
/// globals and permits a system process's; the script is one <code>DELETE</code> step per stored id;
/// and the port sends only an id its latest listing holds, lists an owner's locks again after each
/// <code>DELETE</code>, stops at the vendor's 409, sends a remote owner's lock without the check, and
/// reads an owner one row beyond the cap; and the Locks list
/// sends each row's owner kind as context.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed. Every read is canned; nothing is
/// sent to the instance's lock table (<class>OcuPilot.Test.LockRecordPort</class>).</p>
Class OcuPilot.Test.LockRemoveTools Extends %UnitTest.TestCase
{

Parameter REMOVE = "OcuPilot.Screen.Tool.LockRemove";

Parameter PROCESS = "OcuPilot.Screen.Tool.LockRemoveProcess";

Parameter CLIENT = "OcuPilot.Screen.Tool.LockRemoveClient";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.LockList";

Parameter PORT = "OcuPilot.Port.LockPort";

/// <p>A canned local and remote <code>DeleteID</code>.</p>
Parameter LOCALID = "313131008,13,P905,";

Parameter REMOTEID = "313131009,2,C4,";

/// <p>AD-3, AD-51, AD-52, AC3: each tool is a registered, bodyless, destructive write through the lock
/// port, reading its own composed type and writing its own, fingerprinted over its declared subject
/// with its precondition, which the registration guard holds adequate. It admits
/// <code>RemoveInTransaction</code> alone, which travels in the port query, has no field row and no
/// entry in the generated tool field lists, and <code>Lock</code> publishes no template. The port
/// composes each write pair, issues <code>Lock/DELETE</code> itself, and the admin port admits that
/// pair as a bodyless write whose 409 it does not log.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Screen.Tool.LockRemove.SENDSBODY</parameter> to 1 --
/// the bodyless legs go red.</p>
Method TestEachToolIsAnActionWriteOverTheLockPort()
{
    Set tToolFields = ..XDataJson("OcuPilot.Screen.Tool.ToolFields", "Tools")
    Set tFieldLists = ..XDataJson("OcuPilot.Screen.Tool.FieldLists", "Lists")
    Do $$$AssertTrue($IsObject(tToolFields) && $IsObject(tFieldLists), "the generated field lists read")
    For tCase = $ListBuild("osmgmt.locks.remove", ..#REMOVE, "ROW REMOVE", "remove", "DeleteID,RemoteOwner,RemoveInTransaction DeleteID"), $ListBuild("osmgmt.locks.removeprocess", ..#PROCESS, "OWNER REMOVEOWNER", "removeprocess", "Owner,DeleteIDs,RemoteOwner,RemoveInTransaction DeleteIDs"), $ListBuild("osmgmt.locks.removeclient", ..#CLIENT, "OWNER REMOVEOWNER", "removeclient", "Owner,DeleteIDs,RemoteOwner,RemoveInTransaction DeleteIDs") {
        Set tName = $List(tCase, 1)
        Set tClass = $List(tCase, 2)
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool)
        Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)) && (tTool.class = tClass) && (tTool.kind = "write"), tName _ " is registered as a write")
        Do $$$AssertEquals($ClassMethod(tClass, "PortClass") _ " " _ $ClassMethod(tClass, "Endpoint") _ " " _ $ClassMethod(tClass, "ReadType") _ " " _ $ClassMethod(tClass, "WriteType"), ..#PORT _ " Lock " _ $List(tCase, 3), tName _ ": reads and writes its own composed types through the lock port")
        Do $$$AssertEquals($ClassMethod(tClass, "SendsBody") _ " " _ $ClassMethod(tClass, "Destructive") _ " " _ $ClassMethod(tClass, "ChangeAction"), "0 1 deleted", tName _ ": sends no body, is destructive and publishes a delete")
        Do $$$AssertEquals($ClassMethod(tClass, "IdArgument") _ " " _ $ClassMethod(tClass, "IdParam"), "DeleteID id", tName _ ": its target is the DeleteID, sent as id")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "FingerprintSubject")) _ " " _ $ClassMethod(tClass, "PreconditionField"), $List(tCase, 5), tName _ ": fingerprinted over its declared subject and precondition")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(tClass), "", tName _ ": which the registration guard holds adequate")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SettableFields")), "RemoveInTransaction", tName _ ": admitting RemoveInTransaction alone")
        Set tRowsSC = $ClassMethod(tClass, "FieldRows", .tRows)
        Do $$$AssertEquals($System.Status.IsOK(tRowsSC) _ " " _ +$Get(tRows), "1 0", tName _ ": its field list is empty by derivation")
        Do $$$AssertEquals($Select($IsObject(tToolFields): tToolFields.%GetTypeOf(tName), 1: "-"), "unassigned", tName _ ": no tool field list names it")
        Do $$$AssertEquals($ListToString($ClassMethod(tClass, "ScreenActionIds")), $List(tCase, 4), tName _ ": carrying the screen's " _ $List(tCase, 4))
        Do $$$AssertEquals($Parameter(tClass, "SCREENVALUES"), $List(tCase, 4) _ "=RemoveInTransaction", tName _ ": whose one value is RemoveInTransaction")
        Set tPair = "Lock/" _ $Piece($List(tCase, 3), " ", 2)
        Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating("Lock", $Piece($List(tCase, 3), " ", 2)) && $ListFind($ListFromString($Parameter(..#PORT, "COMPOSEDTYPES")), tPair), tName _ ": " _ tPair _ " is a mutating pair the lock port composes")
        Set tSchema = $ClassMethod(tClass, "InputSchema")
        Do $$$AssertEquals(tSchema.%Get("required").%ToJSON(), "[""DeleteID"",""RemoveInTransaction""]", tName _ ": the schema requires the DeleteID and RemoveInTransaction")
        Do $$$AssertEquals(tSchema.%Get("properties").%Get("RemoveInTransaction").%Get("type"), "boolean", tName _ ": RemoveInTransaction is a boolean")
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, {"DeleteID": (..#LOCALID), "RemoveInTransaction": false, "Reference": "^X"}, .tProblem)
        Do $$$AssertStatusNotOK(tSC, tName _ ": a field of the lock is refused as an argument")
    }
    Set tList = $Select($IsObject(tFieldLists): tFieldLists.%Get("Lock"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tList): tList.source _ " " _ tList.rows.%Size(), 1: ""), "none 0", "Lock's derived list records no template and no row")
    Do $$$AssertEquals($Parameter(..#PORT, "DELEGATEDTYPES"), "Lock/DELETE", "the port issues Lock/DELETE itself")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsMutating("Lock", "DELETE") && ##class(OcuPilot.Port.AdminPort).IsBodyless("Lock", "DELETE"), "which the admin port admits as a bodyless write")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsUnloggedRefusal("Lock", "DELETE", 409) && '##class(OcuPilot.Port.AdminPort).IsUnloggedRefusal("Lock", "DELETE", 500) && '##class(OcuPilot.Port.AdminPort).IsUnloggedRefusal("Lock", "DELETE", 404), "whose 409 alone it does not log (AD-2)")
}

/// <p>AD-8, AD-44 as amended 2026-09-30: each tool requires the Locks screen's two pairs, then
/// <code>%DB_IRISSYS:WRITE</code>, and declares the classic Manage Locks page, whose normalized key is
/// its class name.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Screen.Tool.LockRemove.WRITERESOURCE</parameter>'s
/// append from <method>OcuPilot.Screen.Tool.LockRemove.PrivilegePairs</method> -- the pair leg goes
/// red.</p>
Method TestEachToolRequiresTheWritePairAndTheClassicPage()
{
    Set tScreen = ..Pairs(##class(OcuPilot.Screen.Gate).RequiredPairs(..#SCREEN, .tResolved))
    Do $$$AssertEquals(tScreen, "%Admin_Operate:USE,%DB_IRISSYS:READ", "the screen's own pairs")
    For tClass = ..#REMOVE, ..#PROCESS, ..#CLIENT {
        Do $$$AssertEquals(..Pairs($ClassMethod(tClass, "PrivilegePairs", "", .tResolved)), tScreen _ ",%DB_IRISSYS:WRITE", $Parameter(tClass, "TOOLNAME") _ " requires the write pair beyond them")
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), "%CSP.UI.Portal.Locks", $Parameter(tClass, "TOOLNAME") _ " declares the Manage Locks page")
    }
    Do $$$AssertEquals(..NormalizedPage("%CSP.UI.Portal.Locks.zen"), "%CSP.UI.Portal.Locks", "whose normalized key is its class name, read on the instance")
}

/// <p>AD-22: the three keys join the baseline, enabled.</p>
Method TestTheThreeKeysShipEnabled()
{
    For tKey = "osmgmt.locks.remove", "osmgmt.locks.removeprocess", "osmgmt.locks.removeclient" {
        Set tSeed = ##class(OcuPilot.Kernel.Governance.Baseline).Seed(tKey, .tListed)
        Do $$$AssertEquals(tListed _ " " _ tSeed, "1 1", tKey _ " is listed, enabled")
    }
}

/// <p>AD-51, AD-52, DW-1073: the port query asks the vendor's in-transaction check for a local owner
/// unless <code>RemoveInTransaction</code> is true, never for a remote owner, and carries the stored
/// ids -- the owner set's <code>DeleteIDs</code>, else the one <code>DeleteID</code>.</p>
/// <p>Mutation (Rule 19): answer <code>checkTxn</code> 1 for a remote owner in
/// <method>OcuPilot.Screen.Tool.LockRemove.PortQuery</method> -- the remote legs go red.</p>
Method TestThePortQueryAsksTheCheckForALocalOwnerUnlessOverridden()
{
    For tCase = $ListBuild(0, 0, 1), $ListBuild(0, 1, 0), $ListBuild(1, 0, 0), $ListBuild(1, 1, 0) {
        Set tPayload = {"DeleteID": (..#LOCALID)}
        Do tPayload.%Set("RemoteOwner", $List(tCase, 1), "boolean")
        Do tPayload.%Set("RemoveInTransaction", $List(tCase, 2), "boolean")
        Kill tQuery
        Do ##class(OcuPilot.Screen.Tool.LockRemove).PortQuery(tPayload, .tQuery)
        Do $$$AssertEquals($Get(tQuery("checkTxn")), $List(tCase, 3), "remote " _ $List(tCase, 1) _ ", override " _ $List(tCase, 2) _ ": checkTxn " _ $List(tCase, 3))
        Do $$$AssertEquals($Get(tQuery("ids")), "[""" _ ..#LOCALID _ """]", "and the one stored id")
    }
    Set tPayload = {"Owner": "P905", "DeleteIDs": [(..#LOCALID), "313131010,1,P905,"], "RemoteOwner": false, "RemoveInTransaction": false}
    Kill tQuery
    Do ##class(OcuPilot.Screen.Tool.LockRemoveProcess).PortQuery(tPayload, .tQuery)
    Do $$$AssertEquals($Get(tQuery("checkTxn")) _ " " _ $Get(tQuery("ids")), "1 " _ tPayload.%Get("DeleteIDs").%ToJSON(), "an owner set's ids travel whole")
    Set tIds = ##class(OcuPilot.Port.LockPort).IdsOf(.tQuery)
    Do $$$AssertEquals($ListToString(tIds, "|"), ..#LOCALID _ "|313131010,1,P905,", "and the port reads them back in order")
}

/// <p>AD-51, AD-56 (ii): the screen's value is <code>true</code> or <code>false</code>, carried as a
/// boolean, and any other spelling is refused.</p>
Method TestTheScreenValueIsTrueOrFalse()
{
    For tCase = $ListBuild("true", "{""RemoveInTransaction"":true}"), $ListBuild("false", "{""RemoveInTransaction"":false}") {
        Set tSC = ##class(OcuPilot.Screen.Tool.LockRemove).ScreenActionDelta("remove", {"RemoveInTransaction": ($List(tCase, 1))}, {}, .tArgs, .tProblem)
        Do $$$AssertEquals(tProblem _ " " _ tArgs.%ToJSON(), " " _ $List(tCase, 2), "'" _ $List(tCase, 1) _ "' is carried as a boolean")
    }
    For tValue = "yes", "", "TRUEish" {
        Set tSC = ##class(OcuPilot.Screen.Tool.LockRemove).ScreenActionDelta("remove", {"RemoveInTransaction": (tValue)}, {}, .tArgs, .tProblem)
        Do $$$AssertTrue(tProblem '= "", "'" _ tValue _ "' is refused")
    }
}

/// <p>AD-39, AD-51: the removal's rows are one removed row per lock; the owner tools refuse an owner of
/// the other kind and a set above 200 with their published sentences, and a read that enumerated no
/// set with an unpublished problem.</p>
/// <p>Mutation (Rule 19): drop the owner-kind check from
/// <method>OcuPilot.Screen.Tool.LockRemoveProcess.OwnerProblem</method> -- the wrong-kind legs go
/// red.</p>
Method TestTheOwnerToolsRefuseTheWrongKindAndTooMany()
{
    Set tRow = {"DeleteID": (..#LOCALID), "Pid": 905, "Owner": "P905", "RemoteOwner": false, "Reference": ("^OcuProbeLock(""a"")"), "ModeCount": "Exclusive", "Directory": "/d/", "System": "", "RemoveInTransaction": null}
    Set tSC = ##class(OcuPilot.Screen.Tool.LockRemove).StateDiff(tRow, .tRows, .tProblem)
    Do $$$AssertEquals(tProblem _ " " _ tRows.%ToJSON(), " [{""field"":""^OcuProbeLock(\""a\"")"",""before"":""Exclusive"",""after"":"""",""removed"":true}]", "one removed row for the lock")
    Set tSC = ##class(OcuPilot.Screen.Tool.LockRemove).StateDiff({}, .tRows, .tProblem)
    Do $$$AssertTrue(tProblem '= "", "a read naming no lock is refused")

    For tCase = $ListBuild(..#PROCESS, "P905", 0, 2, ""), $ListBuild(..#PROCESS, "C4", 1, 2, $Parameter(..#REMOVE, "REMOTEREASON")), $ListBuild(..#CLIENT, "C4", 1, 2, ""), $ListBuild(..#CLIENT, "P905", 0, 2, $Parameter(..#REMOVE, "LOCALREASON")), $ListBuild(..#PROCESS, "P905", 0, 201, $Parameter(..#REMOVE, "TOOMANYREASON")), $ListBuild(..#PROCESS, "P905", 0, 200, "") {
        Set tRead = ..Owner($List(tCase, 2), $List(tCase, 3), $List(tCase, 4))
        Set tSC = $ClassMethod($List(tCase, 1), "StateDiff", tRead, .tRows, .tProblem)
        Do $$$AssertEquals(tProblem, $List(tCase, 5), $Parameter($List(tCase, 1), "TOOLNAME") _ " over " _ $List(tCase, 2) _ " with " _ $List(tCase, 4) _ " locks")
        If $List(tCase, 5) = "" Do $$$AssertEquals(tRows.%Size(), $List(tCase, 4), "one removed row per lock")
    }
    Set tSC = ##class(OcuPilot.Screen.Tool.LockRemoveProcess).StateDiff({"DeleteID": (..#LOCALID)}, .tRows, .tProblem)
    Do $$$AssertTrue((tProblem '= "") && '$ListFind($ListBuild($Parameter(..#REMOVE, "REMOTEREASON"), $Parameter(..#REMOVE, "LOCALREASON"), $Parameter(..#REMOVE, "TOOMANYREASON")), tProblem), "a read that enumerated no set is refused with an unpublished problem: " _ tProblem)
    Do $$$AssertEquals($Parameter(..#REMOVE, "REMOTEREASON") _ "|" _ $Parameter(..#REMOVE, "LOCALREASON") _ "|" _ $Parameter(..#REMOVE, "TOOMANYREASON"), "Its owner is a remote client, not a process on this instance.|Its owner is a process on this instance, not a remote client.|This owner holds more than 200 locks, and one removal names at most 200.", "the three sentences are the published ones")
}

/// <p>DW-1073: an override on a local owner carries <code>LOCK.INTRANSACTION</code>, which the error
/// class answers with the published sentence; no override, and a remote owner, carry none.</p>
Method TestAnOverrideOnALocalOwnerCarriesTheConsequence()
{
    Set tCode = ##class(OcuPilot.Api.LockError).#INTRANSACTION
    For tCase = $ListBuild(0, 1, tCode), $ListBuild(0, 0, ""), $ListBuild(1, 1, ""), $ListBuild(1, 0, "") {
        Set tPayload = {"DeleteID": (..#LOCALID)}
        Do tPayload.%Set("RemoteOwner", $List(tCase, 1), "boolean")
        Do tPayload.%Set("RemoveInTransaction", $List(tCase, 2), "boolean")
        For tClass = ..#REMOVE, ..#PROCESS {
            Do $$$AssertEquals($ClassMethod(tClass, "Consequence", tPayload, 0, ""), $List(tCase, 3), $Parameter(tClass, "TOOLNAME") _ ": remote " _ $List(tCase, 1) _ ", override " _ $List(tCase, 2))
        }
    }
    Do $$$AssertEquals(tCode, "LOCK.INTRANSACTION", "the code")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), "Its owner is in an open transaction. Removing the lock leaves that transaction running without it.", "whose sentence reaches a Confirm's refusal")
    Do $$$AssertEquals(##class(OcuPilot.Api.LockError).ReasonFor("LOCK.OTHER"), "", "and no other LOCK code has one")
}

/// <p>AD-10 as amended 2026-09-30: a reference on a global beginning <code>OcuPilot</code>, with or
/// without an extended-reference prefix, is OcuPilot's own; a system process's lock and a name that
/// only differs in case are not. The arm reads a single lock's <code>Reference</code> and every member
/// of an owner's <code>Locks</code>, and fails closed on a target it cannot read.</p>
/// <p>Mutation (Rule 19): skip the extended-reference prefix in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.GlobalName</method> -- the install lock's leg goes
/// red; drop its quote toggle -- the legs whose quoted directory holds the prefix's own closing
/// character go red.</p>
Method TestTheLockArmReadsOcuPilotsOwnGlobals()
{
    Set tSet = "OcuPilot.Kernel.Proposal.Prohibited"
    For tCase = $ListBuild("^OcuPilotTurnSlot(""_SYSTEM"")", 1), $ListBuild("^OcuPilotProposalTarget", 1), $ListBuild("^[""^^/durable/iris/mgr/""]OcuPilotInstallLock(""probe"")", 1), $ListBuild("^|""^^/a]b/""|OcuPilotStateCap(1)", 1), $ListBuild("^[""^^/a]b/""]OcuPilotInstallLock(1)", 1), $ListBuild("^|""^^/a|b/""|OcuPilotStateCap(1)", 1), $ListBuild("^OcuPilot.Kernel.State.BaseD(5)", 1), $ListBuild("^TASKMGR", 0), $ListBuild("^ISC.LMFMON(""License Monitor"")", 0), $ListBuild("^ocupilotTurnSlot", 0), $ListBuild("^[""^^/durable/OcuPilot/""]Other(1)", 0), $ListBuild("^OcuProbeLock(""a"",1)", 0), $ListBuild("OcuPilotLocal", 0) {
        Do $$$AssertEquals($ClassMethod(tSet, "IsOcuPilotLock", $List(tCase, 1)), $List(tCase, 2), $List(tCase, 1))
    }
    Do $$$AssertEquals($ClassMethod(tSet, "HoldsOcuPilotLock", {"Reference": ("^OcuPilotTurnSlot(""x"")")}), 1, "a single own lock is held")
    Do $$$AssertEquals($ClassMethod(tSet, "HoldsOcuPilotLock", {"Reference": "^TASKMGR"}), 0, "a Task Manager daemon's lock is permitted")
    Do $$$AssertEquals($ClassMethod(tSet, "HoldsOcuPilotLock", {"Locks": [{"Reference": "^OcuProbeLock(1)"}, {"Reference": "^OcuPilotStateCap"}]}), 1, "an own lock among an owner's set is held")
    Do $$$AssertEquals($ClassMethod(tSet, "HoldsOcuPilotLock", {"Locks": [{"Reference": "^OcuProbeLock(1)"}, {"Reference": "^TASKMGR"}]}), 0, "a set without one is permitted")
    Do $$$AssertEquals($ClassMethod(tSet, "HoldsOcuPilotLock", ""), 1, "an unreadable target fails closed")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Kernel.Proposal.Prohibited).CoveredTypes(), "lock") > 0, "lock is a covered type")
    Set tReason = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTLOCK)
    Do $$$AssertTrue((tReason '= "") && (tReason = ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTLOCKREASON), "whose refusal is its own parameter, which ui/tools/self-protection.test.mjs pins to the published sentence")
}

/// <p>AD-59: the script of a removal is one <code>Lock</code> <code>DELETE</code> step per stored id, in
/// order, each carrying the stored in-transaction check; both write types have a script form.</p>
/// <p>Mutation (Rule 19): render only the first id in <method>OcuPilot.Port.LockPort.Snippet</method>
/// -- the owner leg goes red.</p>
Method TestTheScriptIsOneDeleteStepPerStoredId()
{
    Set tContext = {"origin": "https://example.test", "user": "tester"}
    Kill tQuery
    Set tQuery("id") = ..#LOCALID
    Set tIds = []
    Do tIds.%Push(..#LOCALID, "string")
    Do tIds.%Push("313131010,1,P905,", "string")
    Set tQuery("ids") = tIds.%ToJSON()
    Set tQuery("checkTxn") = 1
    Set tSteps = ##class(OcuPilot.Port.LockPort).Snippet("Lock", "REMOVEOWNER", .tQuery, "", tContext)
    Do $$$AssertEquals(tSteps.%Size(), 2, "one step per stored id")
    If tSteps.%Size() = 2 {
        Do $$$AssertTrue((tSteps.%Get(0).text [ "-X DELETE") && (tSteps.%Get(0).text [ "/api/admin/v2/lock?checkTxn=1&id=313131008%2C13%2CP905%2C"), "the first deletes the first id with the check: " _ tSteps.%Get(0).text)
        Do $$$AssertTrue(tSteps.%Get(1).text [ "id=313131010%2C1%2CP905%2C", "the second the second: " _ tSteps.%Get(1).text)
    }
    Set tQuery("checkTxn") = 0
    Set tSteps = ##class(OcuPilot.Port.LockPort).Snippet("Lock", "REMOVE", .tQuery, "", tContext)
    Do $$$AssertEquals(tSteps.%Size(), 1, "a single removal is one step")
    If tSteps.%Size() = 1 Do $$$AssertTrue(tSteps.%Get(0).text [ "checkTxn=0&id=313131008%2C13%2CP905%2C", "carrying the override: " _ tSteps.%Get(0).text)
    Do $$$AssertEquals(##class(OcuPilot.Port.LockPort).SnippetForm("Lock", "REMOVE") _ " " _ ##class(OcuPilot.Port.LockPort).SnippetForm("Lock", "REMOVEOWNER"), "rest rest", "both write types have a script form")
}

/// <p>AD-52 as amended 2026-09-30, DW-1073: the port's writes, over canned listings that nothing sends to
/// the instance (<class>OcuPilot.Test.LockRecordPort</class>). A stored id the fresh listing no longer
/// holds is never sent, and a <code>REMOVE</code> of one answers 404 <code>PORT.NOTFOUND</code>; an
/// owner-scope removal sends exactly the stored ids the listing holds for that owner, in order, and
/// none of a row whose text merely carries the owner key, and sends nothing, answering 404, once its
/// target is no longer listed; the vendor's 409 answers
/// <code>LOCK.INTRANSACTION</code> and stops the sequence; and a row the listing reports held by a remote
/// owner is sent with <code>checkTxn</code> 0 whatever the query asked.</p>
/// <p>Mutation (Rule 19): drop the fresh-listing guard (<code>If '$Data(tByDeleteID(tDeleteID))
/// Continue</code>) from <method>OcuPilot.Port.LockPort.Invoke</method> -- the released id is sent and
/// this goes red; drop the target's own listing check before the writes -- the released target's
/// owner locks are sent and this goes red.</p>
Method TestThePortSendsOnlyWhatItsFreshListingHolds()
{
    Set tPort = "OcuPilot.Test.LockRecordPort"
    Set tA = ..#LOCALID
    Set tB = "313131010,1,P905,"
    Set tGone = "313131012,1,P905,"
    Set tDecoy = "313131011,1,P77,"
    Set tRows = []
    Do tRows.%Push({"DeleteID": (tA), "Pid": 905, "RemoteOwner": false, "Reference": "^OcuProbeLock(1)", "ModeCount": "Exclusive", "Directory": "/d/", "System": ""})
    Do tRows.%Push({"DeleteID": (tB), "Pid": 905, "RemoteOwner": false, "Reference": "^OcuProbeLock(2)", "ModeCount": "Exclusive", "Directory": "/d/", "System": ""})
    Do tRows.%Push({"DeleteID": (tDecoy), "Pid": 77, "RemoteOwner": false, "Reference": ("^OcuProbeLock("",P905,"")"), "ModeCount": "Exclusive", "Directory": "/d/", "System": ""})
    Do tRows.%Push({"DeleteID": (..#REMOTEID), "Pid": "", "RemoteOwner": true, "Reference": "^OcuProbeLock(3)", "ModeCount": "Exclusive", "Directory": "/d/", "System": "client"})

    ; A REMOVE of a lock its owner has since released is 404, and nothing is sent.
    Do $ClassMethod(tPort, "Reset")
    Do $ClassMethod(tPort, "Arm", tRows)
    Kill tQuery
    Set tQuery("id") = tGone
    Set tQuery("checkTxn") = 1
    Set tSC = $ClassMethod(tPort, "Invoke", "Lock", "REMOVE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISERR(tSC) _ " " _ +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "1 404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "a released lock's REMOVE answers 404 PORT.NOTFOUND")
    Do $$$AssertEquals($ListLength($ClassMethod(tPort, "Calls", "DELETE")), 0, "and sends no DELETE")

    ; An owner removal sends exactly the stored ids the listing holds for that owner.
    Do $ClassMethod(tPort, "Reset")
    Do $ClassMethod(tPort, "Arm", tRows)
    Kill tQuery
    Set tQuery("id") = tA
    Set tQuery("ids") = "[""" _ tA _ """,""" _ tGone _ """,""" _ tDecoy _ """,""" _ tB _ """]"
    Set tQuery("checkTxn") = 1
    Set tSC = $ClassMethod(tPort, "Invoke", "Lock", "REMOVEOWNER", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the owner removal succeeds")
    Do $$$AssertEquals($ListToString($ClassMethod(tPort, "Calls", "LIST"), ","), "||,P905,|201,||,P905,|201", "it lists before A's DELETE and again after it, each time asking the vendor for the owner key and one row beyond the cap")
    Do $$$AssertEquals($ListToString($ClassMethod(tPort, "Calls", "DELETE"), ","), tA _ "|1||," _ tB _ "|1||", "it sends A and B with the check, and neither the released id nor another owner's")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("removed"), 1: ""), 2, "answering two removed")

    ; An owner removal whose target its owner has released is 404, and sends none of the owner's other
    ; locks: the prohibited set judged the target's set, which no longer exists.
    Do $ClassMethod(tPort, "Reset")
    Do $ClassMethod(tPort, "Arm", tRows)
    Kill tQuery
    Set tQuery("id") = tGone
    Set tQuery("ids") = "[""" _ tA _ """,""" _ tB _ """]"
    Set tQuery("checkTxn") = 1
    Set tSC = $ClassMethod(tPort, "Invoke", "Lock", "REMOVEOWNER", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISERR(tSC) _ " " _ +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "1 404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "an owner removal whose target was released answers 404 PORT.NOTFOUND")
    Do $$$AssertEquals($ListLength($ClassMethod(tPort, "Calls", "DELETE")), 0, "and sends none of the owner's listed locks")

    ; The vendor's 409 answers LOCK.INTRANSACTION, and nothing further is sent.
    Kill tQuery
    Set tQuery("id") = tA
    Set tQuery("ids") = "[""" _ tA _ """,""" _ tGone _ """,""" _ tDecoy _ """,""" _ tB _ """]"
    Set tQuery("checkTxn") = 1
    Do $ClassMethod(tPort, "Reset")
    Do $ClassMethod(tPort, "Arm", tRows)
    Do $ClassMethod(tPort, "ArmStatus", tA, 409)
    Set tSC = $ClassMethod(tPort, "Invoke", "Lock", "REMOVEOWNER", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISERR(tSC) _ " " _ +$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ " " _ tFault.reason, 1: ""), "1 409 " _ ##class(OcuPilot.Api.LockError).#INTRANSACTION _ " " _ ##class(OcuPilot.Api.LockError).#REASONINTRANSACTION, "a 409 answers LOCK.INTRANSACTION with its sentence")
    Do $$$AssertEquals($ListToString($ClassMethod(tPort, "Calls", "DELETE"), ","), tA _ "|1||", "and stops after it")

    ; A remote owner's lock is sent without the check, whatever the query asked.
    Do $ClassMethod(tPort, "Reset")
    Do $ClassMethod(tPort, "Arm", tRows)
    Kill tQuery
    Set tQuery("id") = ..#REMOTEID
    Set tQuery("checkTxn") = 1
    Set tSC = $ClassMethod(tPort, "Invoke", "Lock", "REMOVE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a remote owner's lock is removed")
    Do $$$AssertEquals($ListToString($ClassMethod(tPort, "Calls", "DELETE"), ","), ..#REMOTEID _ "|0||", "with checkTxn 0")
    Do $ClassMethod(tPort, "Reset")
}

/// <p>AD-52: an owner-scope removal lists the owner's locks again after each <code>DELETE</code> and
/// judges the next stored id against that listing, over canned listings that nothing sends to the
/// instance (<class>OcuPilot.Test.LockRecordPort</class>). When the owner renumbers its second lock
/// between the first and second <code>DELETE</code> -- the second listing answers a different
/// <code>DeleteID</code> for the same reference -- no <code>DELETE</code> carries the stale id; a later
/// stored id that listing still holds is sent, and the id after it is judged against a third listing,
/// taken after that <code>DELETE</code>, in which the owner has renumbered it too.</p>
/// <p>Mutation (Rule 19): drop the re-listing from <method>OcuPilot.Port.LockPort.Invoke</method>, so
/// the first listing judges every stored id -- the stale ids are sent and this goes red; re-list only
/// after the first <code>DELETE</code> -- the fourth id is sent and this goes red.</p>
Method TestAnOwnerRemovalReListsBeforeEachDelete()
{
    Set tPort = "OcuPilot.Test.LockRecordPort"
    Set tA = ..#LOCALID
    Set tB = "313131010,1,P905,"
    Set tRenumbered = "313131020,1,P905,"
    Set tC = "313131012,1,P905,"
    Set tD = "313131014,1,P905,"
    Set tRenumberedD = "313131024,1,P905,"
    Set tFirst = []
    Do tFirst.%Push({"DeleteID": (tA), "Pid": 905, "RemoteOwner": false, "Reference": "^OcuProbeLock(1)", "ModeCount": "Exclusive", "Directory": "/d/", "System": ""})
    Do tFirst.%Push({"DeleteID": (tB), "Pid": 905, "RemoteOwner": false, "Reference": "^OcuProbeLock(2)", "ModeCount": "Exclusive", "Directory": "/d/", "System": ""})
    Do tFirst.%Push({"DeleteID": (tC), "Pid": 905, "RemoteOwner": false, "Reference": "^OcuProbeLock(3)", "ModeCount": "Exclusive", "Directory": "/d/", "System": ""})
    Do tFirst.%Push({"DeleteID": (tD), "Pid": 905, "RemoteOwner": false, "Reference": "^OcuProbeLock(4)", "ModeCount": "Exclusive", "Directory": "/d/", "System": ""})
    ; After A's DELETE the owner holds its second lock under a new DeleteID, and C and D unchanged.
    Set tSecond = []
    Do tSecond.%Push({"DeleteID": (tRenumbered), "Pid": 905, "RemoteOwner": false, "Reference": "^OcuProbeLock(2)", "ModeCount": "Exclusive", "Directory": "/d/", "System": ""})
    Do tSecond.%Push({"DeleteID": (tC), "Pid": 905, "RemoteOwner": false, "Reference": "^OcuProbeLock(3)", "ModeCount": "Exclusive", "Directory": "/d/", "System": ""})
    Do tSecond.%Push({"DeleteID": (tD), "Pid": 905, "RemoteOwner": false, "Reference": "^OcuProbeLock(4)", "ModeCount": "Exclusive", "Directory": "/d/", "System": ""})
    ; After C's DELETE it holds its fourth lock under a new DeleteID as well.
    Set tThird = []
    Do tThird.%Push({"DeleteID": (tRenumbered), "Pid": 905, "RemoteOwner": false, "Reference": "^OcuProbeLock(2)", "ModeCount": "Exclusive", "Directory": "/d/", "System": ""})
    Do tThird.%Push({"DeleteID": (tRenumberedD), "Pid": 905, "RemoteOwner": false, "Reference": "^OcuProbeLock(4)", "ModeCount": "Exclusive", "Directory": "/d/", "System": ""})
    Do $ClassMethod(tPort, "Reset")
    Do $ClassMethod(tPort, "ArmListing", 1, tFirst)
    Do $ClassMethod(tPort, "ArmListing", 2, tSecond)
    Do $ClassMethod(tPort, "ArmListing", 3, tThird)
    Kill tQuery
    Set tQuery("id") = tA
    Set tQuery("ids") = "[""" _ tA _ """,""" _ tB _ """,""" _ tC _ """,""" _ tD _ """]"
    Set tQuery("checkTxn") = 1
    Set tSC = $ClassMethod(tPort, "Invoke", "Lock", "REMOVEOWNER", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the owner removal succeeds")
    Do $$$AssertEquals($ListToString($ClassMethod(tPort, "Calls", "DELETE"), ","), tA _ "|1||," _ tC _ "|1||", "it sends A, then C, and no DELETE for the second or fourth lock's stale id")
    Do $$$AssertEquals($ListToString($ClassMethod(tPort, "Calls", "LIST"), ","), "||,P905,|201,||,P905,|201,||,P905,|201", "listing the owner's locks before A's DELETE and again after each DELETE, by the same owner query")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("removed"), 1: ""), 2, "answering two removed")
    Do $ClassMethod(tPort, "Reset")
}

/// <p>AD-51, Story 16.12: the owner read lists one row beyond the 200-lock cap, so an owner holding more
/// than 200 locks reads as more than 200 and its removal is refused with the published sentence.</p>
/// <p>Mutation (Rule 19): send <code>maxRows</code> <parameter>OcuPilot.Port.LockPort.MAXOWNERLOCKS</parameter>
/// rather than one more from <method>OcuPilot.Port.LockPort.Listing</method> -- the owner reads 200 locks
/// and this goes red.</p>
Method TestAnOwnerBeyondTheCapIsRefused()
{
    Set tPort = "OcuPilot.Test.LockRecordPort"
    Set tRows = []
    For tI = 1:1:250 {
        Do tRows.%Push({"DeleteID": ((313131000 + tI) _ ",1,P905,"), "Pid": 905, "RemoteOwner": false, "Reference": ("^OcuProbeLock(" _ tI _ ")"), "ModeCount": "Exclusive", "Directory": "/d/", "System": ""})
    }
    Do $ClassMethod(tPort, "Reset")
    ; The canned vendor answers at most the maxRows the port asks for, as the instance does.
    Do $ClassMethod(tPort, "Arm", tRows)
    Kill tQuery
    Set tQuery("id") = tRows.%Get(0).DeleteID
    Set tSC = $ClassMethod(tPort, "Invoke", "Lock", "OWNER", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the owner read answers")
    Do $$$AssertEquals($ListToString($ClassMethod(tPort, "Calls", "LIST"), ","), "||,P905,|201", "asking the vendor for one row beyond the cap")
    Do $$$AssertEquals($Select($IsObject($Get(tRead)): tRead.%Get("Locks").%Size(), 1: ""), 201, "so an owner of 250 locks reads as 201")
    Set tSC = ##class(OcuPilot.Screen.Tool.LockRemoveProcess).StateDiff(tRead, .tDiff, .tProblem)
    Do $$$AssertEquals(tProblem, $Parameter(..#REMOVE, "TOOMANYREASON"), "and a set beyond 200 is refused with the published sentence")
    Do $ClassMethod(tPort, "Reset")
}

/// <p>AD-24, Story 16.12: the Locks list sends each row's owner kind to the agent as context, so the
/// agent can tell which owner scope fits, and its empty state invites the agent's removal.</p>
/// <p>Mutation (Rule 19): drop <code>RemoteOwner</code> from the Locks list's
/// <code>context.fields</code> -- this goes red.</p>
Method TestTheLocksListSendsTheOwnerKindAsContext()
{
    Set tDeclaration = ..XDataJson(..#SCREEN, "Declaration")
    Do $$$AssertTrue($IsObject(tDeclaration), "the Locks list's declaration reads")
    If '$IsObject(tDeclaration) Quit
    Do $$$AssertEquals(tDeclaration.%Get("context").%Get("fields").%ToJSON(), "[""Pid"",""OSUserName"",""RoutineInfo"",""ModeCount"",""Reference"",""Directory"",""System"",""DeleteID"",""RemoteOwner""]", "its context carries RemoteOwner beside the read's other fields")
    Do $$$AssertEquals(tDeclaration.%Get("table").%Get("emptyAgentKey") _ "|" _ tDeclaration.%Get("table").%Get("emptyNextKey"), "lockListEmptyAgent|", "its empty state invites the agent's removal")
}

/// <p>A canned <code>OWNER</code> read for owner <var>pOwner</var> holding <var>pCount</var> locks.</p>
ClassMethod Owner(pOwner As %String, pRemote As %Boolean, pCount As %Integer) As %DynamicObject
{
    Set tIds = []
    Set tLocks = []
    For tI = 1:1:pCount {
        Set tId = (313131000 + tI) _ ",1," _ pOwner _ ","
        Do tIds.%Push(tId, "string")
        Do tLocks.%Push({"DeleteID": (tId), "Reference": ("^OcuProbeLock(" _ tI _ ")"), "ModeCount": "Exclusive", "Directory": "/d/"})
    }
    Set tRead = {"Owner": (pOwner), "DeleteIDs": (tIds), "Locks": (tLocks), "RemoveInTransaction": null}
    Do tRead.%Set("DeleteID", tIds.%Get(0), "string")
    Do tRead.%Set("RemoteOwner", pRemote, "boolean")
    Quit tRead
}

/// <p>The classic page key <var>pPage</var> normalizes to, as the instance's own
/// <code>%SYS.Portal.Resources</code> answers it.</p>
ClassMethod NormalizedPage(pPage As %String) As %String
{
    Set tKey = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tKey = ##class(%SYS.Portal.Resources).NormalizePage(pPage)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Quit tKey
}

/// <p><var>pPairs</var>, a <class>%List</class> of <code>$ListBuild(resource, permission)</code>, as
/// comma-separated <code>resource:permission</code>.</p>
ClassMethod Pairs(pPairs As %List) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tPair = $List(pPairs, tI)
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ $List(tPair, 1) _ ":" _ $List(tPair, 2)
    }
    Quit tText
}

/// <p>XData block <var>pBlock</var> of <var>pClass</var> as JSON, or <code>""</code>.</p>
ClassMethod XDataJson(pClass As %String, pBlock As %String) As %DynamicAbstractObject
{
    Set tJson = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(pClass, pBlock, , .tSC)
        If '$IsObject(tXData) Quit
        Do tXData.Data.Rewind()
        Set tJson = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
    } Catch {
        Set tJson = ""
    }
    Quit tJson
}

}
