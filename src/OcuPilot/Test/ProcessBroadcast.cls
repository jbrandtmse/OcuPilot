/// <p>Pins Story 16.6's broadcast without a receiver (AD-5, AD-10, AD-13, AD-51, AD-52, AD-59):
/// the tool's declarations and governance key, the pid set's canonical spelling at the port, the
/// message rule, the recipients read built from canned list rows and its 404, the card's state row
/// and its refusal, the fingerprint refusing a moved recipient, the port's composed body and its
/// refusals before any vendor call, the agent's mint refusing a bad set, a bad message and an
/// ineligible set, the copy-out script, the published sentence, the process arm
/// skipped for a broadcast and kept for a suspend, and the screen's declared cap.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot compiled in the running namespace and the
/// admin API answering the test account's <code>Process</code> <code>LIST</code>; it seeds one turn
/// and removes it. It sends nothing
/// to any process: every broadcast it asks for names a pid no process carries, or a daemon, which
/// the port refuses before the vendor is called.</p>
Class OcuPilot.Test.ProcessBroadcast Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.ProcessBroadcast";

Parameter PORT = "OcuPilot.Port.ProcessPort";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.ProcessList";

/// <p>A pid no process on this build carries.</p>
Parameter ABSENTPID = 999999999;

/// <p>The sentence EXPERIENCE.md's Fixed strings publish for <code>PROCESS.BROADCAST.RECIPIENT</code>.</p>
Parameter PUBLISHED = "At least one of these processes has ended or is not a terminal session, so nothing was sent.";

/// <p>AD-51, AD-52, AD-22: the tool is an action write on <class>OcuPilot.Port.ProcessPort</class>,
/// read through its <code>RECIPIENTS</code>, writing <code>BROADCAST</code> with no body, admitting
/// the message alone, over the screen's own three pairs, with its governance key enabled; the port
/// admits the pair as mutating and composes its body.</p>
/// <p>Mutation (Rule 19): drop <code>Message</code> from
/// <parameter>OcuPilot.Screen.Tool.ProcessBroadcast.FINGERPRINTSUBJECT</parameter> -- the subject
/// leg goes red (and the confirm would send no message).</p>
Method TestTheToolIsAnActionWriteOverTheScreensThreePairs()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.processes.broadcast", .tTool)
    Do $$$AssertStatusOK(tSC, "the registry resolves the tool by name")
    Do $$$AssertTrue($IsObject(tTool), "and finds it")
    If '$IsObject(tTool) Quit
    Do $$$AssertEquals(tTool.%Get("kind") _ " " _ tTool.%Get("class"), "write " _ ..#TOOL, "a write tool answered by its own class")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "PortClass"), ..#PORT, "reaching its target through the process port")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "ReadType") _ " " _ $ClassMethod(..#TOOL, "WriteType") _ " " _ $ClassMethod(..#TOOL, "SendsBody") _ " " _ $ClassMethod(..#TOOL, "Destructive"), "RECIPIENTS BROADCAST 0 0", "read as recipients, written as the vendor's broadcast with no body, and not destructive")
    Do $$$AssertEquals($ClassMethod(..#TOOL, "Endpoint") _ " " _ $ClassMethod(..#TOOL, "IdArgument") _ " " _ $ClassMethod(..#TOOL, "IdParam"), "Process Pids id", "over the process endpoint, named by the pid set")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "SettableFields")), "Message", "admitting the message alone")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "ScreenActionValueNames", "broadcast")), "Message", "which is the screen action's one value")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "FingerprintSubject")) _ " " _ $ClassMethod(..#TOOL, "PreconditionField"), "Recipients,Absent,Message Recipients", "fingerprinting the recipients, the absent pids and the message")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).FingerprintSubjectProblem(..#TOOL), "", "a subject the registration guard holds adequate")
    Set tPairs = $ClassMethod(..#TOOL, "PrivilegePairs", "", .tResolved)
    Set tSpelled = ""
    For tI = 1:1:$ListLength(tPairs) Set tSpelled = tSpelled _ $Select(tI = 1: "", 1: ",") _ $ListToString($List(tPairs, tI), ":")
    Do $$$AssertEquals(tResolved _ " " _ tSpelled, "1 %Admin_Operate:USE,%Admin_Manage:USE,%DB_IRISSYS:READ", "its pairs are the screen's own three")
    Set tSchema = $ClassMethod(..#TOOL, "InputSchema")
    Do $$$AssertEquals(tSchema.%Get("required").%ToJSON(), "[""Pids"",""Message""]", "the pid set and the message are both required")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Governance.Baseline).Seed("osmgmt.processes.broadcast", .tListed) _ " " _ tListed, "1 1", "the governance baseline lists the key, enabled")
    Do $$$AssertTrue($ListFind($ListFromString($Parameter("OcuPilot.Port.AdminPort", "MUTATINGTYPES")), "Process/BROADCAST") > 0, "the admin port admits the pair as mutating")
    Do $$$AssertEquals($ListFind($ListFromString($Parameter("OcuPilot.Port.AdminPort", "BODYLESSTYPES")), "Process/BROADCAST"), 0, "and not as bodyless")
    Do $$$AssertTrue($ListFind($ListFromString($Parameter(..#PORT, "COMPOSEDTYPES")), "Process/BROADCAST") > 0, "since the process port composes its body")
}

/// <p>AD-13 at the port: every spelling of one set is one canonical set, a single pid reads as the
/// integer rule reads it, and a set that is empty, not numeric, holds zero or is over the cap is
/// refused by the one rule the tool and the port share.</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Port.ProcessPort.PidSetProblem</method> accept 21
/// pids -- the cap leg goes red.</p>
Method TestThePidSetIsCanonicalAndCapped()
{
    Do $$$AssertEquals(##class(OcuPilot.Port.ProcessPort).PidSetProblem(" 907,812, 812", .tPids) _ "|" _ $ListToString(tPids), "|812,907", "a spaced, repeated, unordered set reads as its canonical pids")
    Do $$$AssertEquals(##class(OcuPilot.Port.ProcessPort).PidSetProblem(" 007 ", .tPids) _ "|" _ $ListToString(tPids), "|7", "and a single pid as the integer rule reads it")
    Set tTwenty = ""
    For tI = 1:1:20 Set tTwenty = tTwenty _ $Select(tI = 1: "", 1: ",") _ (100 + tI)
    Do $$$AssertEquals(##class(OcuPilot.Port.ProcessPort).PidSetProblem(tTwenty, .tPids) _ "|" _ $ListLength(tPids), "|20", "twenty pids are a set")
    For tBad = "", "abc", "0", "-7", "812,", "812,abc", tTwenty _ ",121" {
        Do $$$AssertTrue(##class(OcuPilot.Port.ProcessPort).PidSetProblem(tBad, .tPids) '= "", "'" _ tBad _ "' is refused")
        Do $$$AssertTrue($ClassMethod(..#TOOL, "PidsProblem", tBad) '= "", "by the tool's check too")
    }
    Do $$$AssertEquals($ClassMethod(..#TOOL, "PidsProblem", "907, 812"), "", "while a sound set passes it")
}

/// <p>The message rule, per the matrix: empty, spaces only, 256 characters, an escape, a tab, a C1
/// character and either half of a surrogate pair alone are refused; 255 characters, an accented
/// letter and a whole non-BMP pair are sound.</p>
/// <p>Mutation (Rule 19): drop the <code>\p{Cc}</code> check from
/// <method>OcuPilot.Screen.Tool.ProcessBroadcast.MessageProblem</method> -- the escape, tab and C1
/// legs go red.</p>
Method TestTheMessageRuleRefusesPerTheMatrix()
{
    Set tLong = $Translate($Justify("", 255), " ", "x")
    For tBad = $ListBuild("", "empty"), $ListBuild("   ", "spaces only"), $ListBuild(tLong _ "x", "256 characters"), $ListBuild("down" _ $Char(27) _ "[2J", "an escape"), $ListBuild("a" _ $Char(9) _ "b", "a tab"), $ListBuild("a" _ $Char(155) _ "b", "a C1 character"), $ListBuild("a" _ $Char(127), "DEL"), $ListBuild("a" _ $Char(10) _ "b", "a line feed"), $ListBuild("a" _ $Char(55357), "a high surrogate alone"), $ListBuild($Char(56832) _ "a", "a low surrogate alone") {
        Do $$$AssertTrue($ClassMethod(..#TOOL, "MessageProblem", $List(tBad, 1)) '= "", $List(tBad, 2) _ " is refused")
    }
    For tGood = $ListBuild(tLong, "255 characters"), $ListBuild("caf" _ $Char(233), "an accented letter"), $ListBuild("up " _ $Char(55357, 56832), "a whole non-BMP pair"), $ListBuild("Down at 18:00", "a plain line") {
        Do $$$AssertEquals($ClassMethod(..#TOOL, "MessageProblem", $List(tGood, 1)), "", $List(tGood, 2) _ " is sound")
    }
    Set tSC = $ClassMethod(..#TOOL, "ScreenActionDelta", "broadcast", {"Message": ("a" _ $Char(9))}, {}, .tArgs, .tProblem)
    Do $$$AssertTrue(tProblem '= "", "the screen's value is refused by the same rule")
    Set tSC = $ClassMethod(..#TOOL, "ScreenActionDelta", "broadcast", {"Message": " Down at 18:00 "}, {}, .tArgs, .tProblem)
    Do $$$AssertEquals(tProblem _ "|" _ tArgs.%ToJSON(), "|{""Message"":"" Down at 18:00 ""}", "and a sound one is carried exactly as given")
}

/// <p>The <code>RECIPIENTS</code> mapping from canned list rows: each pid the list holds is one
/// recipient carrying its user and flag, each it does not is absent, both in the set's order; a set
/// that is all present and eligible is receivable and no other is. Over the live list, a set no
/// process carries is 404 and an unreadable one 400, and nothing is read for it.</p>
Method TestTheRecipientsReadMapsTheListAndAnswers404()
{
    Set tRows = [{"Pid": 907, "Username": "bob", "CanReceiveBroadcast": false, "State": "RUN"}, {"Pid": 812, "Username": "ann", "CanReceiveBroadcast": true, "State": "RUN"}]
    Set tSC = ##class(OcuPilot.Port.ProcessPort).RecipientsOf($ListBuild("812", "907", "1033"), tRows, .tRecipients, .tAbsent)
    Do $$$AssertStatusOK(tSC, "the rows map")
    Do $$$AssertEquals(tRecipients.%ToJSON() _ " " _ tAbsent.%ToJSON(), "[{""Pid"":812,""Username"":""ann"",""CanReceiveBroadcast"":true},{""Pid"":907,""Username"":""bob"",""CanReceiveBroadcast"":false}] [1033]", "two recipients in the set's order and one absent pid")
    Do $$$AssertEquals(##class(OcuPilot.Port.ProcessPort).Receivable(tRecipients, tAbsent), 0, "which is not receivable")
    Set tSC = ##class(OcuPilot.Port.ProcessPort).RecipientsOf($ListBuild("812"), tRows, .tRecipients, .tAbsent)
    Do $$$AssertEquals(##class(OcuPilot.Port.ProcessPort).Receivable(tRecipients, tAbsent), 1, "while the eligible pid alone is")
    Set tSC = ##class(OcuPilot.Port.ProcessPort).RecipientsOf($ListBuild("907"), tRows, .tRecipients, .tAbsent)
    Do $$$AssertEquals(##class(OcuPilot.Port.ProcessPort).Receivable(tRecipients, tAbsent), 0, "and the ineligible pid alone is not")
    Do $$$AssertStatusNotOK(##class(OcuPilot.Port.ProcessPort).RecipientsOf($ListBuild("812"), {}, .tRecipients, .tAbsent), "a list that is not an array is an error")
    Do ..Port("RECIPIENTS", ..#ABSENTPID, "", "", .tHttp, .tFault, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "a set no process carries is not found")
    Do ..Port("RECIPIENTS", "abc", "", "", .tHttp, .tFault, .tResult)
    Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "400 " _ ##class(OcuPilot.Api.Error).#PORTVALIDATION, "and an unreadable one is refused")
}

/// <p>The card's one state row names the count and the pids, and the tool's merge -- which the mint
/// and the confirm's re-read run -- refuses a set holding an absent or an ineligible pid with the
/// published sentence, and carries a receivable one's message.</p>
/// <p>Mutation (Rule 19): drop the <method>OcuPilot.Port.ProcessPort.Receivable</method> check from
/// <method>OcuPilot.Screen.Tool.ProcessBroadcast.MergeUpdate</method> -- both refusal legs go red.</p>
Method TestTheStateRowNamesTheCountAndTheMergeRefusesAnIneligibleSet()
{
    Set tFresh = {"Recipients": [{"Pid": 812, "Username": "ann", "CanReceiveBroadcast": true}, {"Pid": 907, "Username": "bob", "CanReceiveBroadcast": true}, {"Pid": 1033, "Username": "cy", "CanReceiveBroadcast": true}], "Absent": [], "Message": ""}
    Set tSC = $ClassMethod(..#TOOL, "StateDiff", tFresh, .tRows, .tProblem)
    Do $$$AssertEquals(tProblem _ "|" _ tRows.%ToJSON(), "|[{""field"":""Recipients"",""before"":"""",""after"":""3 processes: 812, 907, 1033""}]", "three recipients read as a count and the pids")
    Set tSC = $ClassMethod(..#TOOL, "StateDiff", {"Recipients": [{"Pid": 812, "Username": "ann", "CanReceiveBroadcast": true}], "Absent": [], "Message": ""}, .tRows, .tProblem)
    Do $$$AssertEquals(tProblem _ "|" _ tRows.%Get(0).%Get("after"), "|1 process: 812", "and one reads in the singular")
    Set tArgs = {"Pids": "812", "Message": "Down at 18:00"}
    Set tSC = ..Merged({"Recipients": [{"Pid": 812, "Username": "ann", "CanReceiveBroadcast": true}], "Absent": [], "Message": ""}, tArgs, .tPayload, .tProblem)
    Do $$$AssertEquals(tProblem _ "|" _ tPayload.%Get("Message"), "|Down at 18:00", "a receivable set's merge carries the message")
    Set tSC = ..Merged({"Recipients": [{"Pid": 812, "Username": "ann", "CanReceiveBroadcast": true}], "Absent": [907], "Message": ""}, tArgs, .tPayload, .tProblem)
    Do $$$AssertEquals(tProblem, ..#PUBLISHED, "a set with an ended pid is refused with the published sentence")
    Set tSC = ..Merged({"Recipients": [{"Pid": 812, "Username": "ann", "CanReceiveBroadcast": false}], "Absent": [], "Message": ""}, tArgs, .tPayload, .tProblem)
    Do $$$AssertEquals(tProblem, ..#PUBLISHED, "and so is one with a pid that cannot receive")
}

/// <p>The tool's own merge of <var>pArgs</var> over <var>pFresh</var>.</p>
Method Merged(pFresh As %DynamicObject, pArgs As %DynamicObject, Output pPayload As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit $ClassMethod(..#TOOL, "MergeUpdate", pFresh, pArgs, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), .pPayload, .tDiff, .tUnchanged, .pProblem)
}

/// <p>AD-6, AD-51: the confirm's re-merge reproduces the stored digest only when nothing moved. A
/// re-read in which a recipient ended or can no longer receive is refused by the merge, and one in
/// which a recipient's <code>Username</code> moved, or a message that differs, digests differently --
/// so a confirm after any of those is refused.</p>
Method TestTheFingerprintRefusesAMovedRecipient()
{
    Set tArgs = {"Pids": "812,907", "Message": "Down at 18:00"}
    Set tBase = {"Recipients": [{"Pid": 812, "Username": "ann", "CanReceiveBroadcast": true}, {"Pid": 907, "Username": "bob", "CanReceiveBroadcast": true}], "Absent": [], "Message": ""}
    Set tDigest = ..Digest(tBase, tArgs)
    Do $$$AssertTrue(tDigest '= "", "the reviewed state digests")
    Do $$$AssertEquals(..Digest(##class(%DynamicObject).%FromJSON(tBase.%ToJSON()), tArgs), tDigest, "and digests alike when nothing moved")
    Set tEnded = {"Recipients": [{"Pid": 812, "Username": "ann", "CanReceiveBroadcast": true}], "Absent": [907], "Message": ""}
    Set tFlag = {"Recipients": [{"Pid": 812, "Username": "ann", "CanReceiveBroadcast": true}, {"Pid": 907, "Username": "bob", "CanReceiveBroadcast": false}], "Absent": [], "Message": ""}
    Set tUser = {"Recipients": [{"Pid": 812, "Username": "ann", "CanReceiveBroadcast": true}, {"Pid": 907, "Username": "eve", "CanReceiveBroadcast": true}], "Absent": [], "Message": ""}
    ; Each fresh read is passed as an object, never through a $List, which would stringify it.
    Set tSC = ..Merged(tEnded, tArgs, .tPayload, .tProblem)
    Do $$$AssertEquals(tProblem, ..#PUBLISHED, "a recipient ended, so the confirm's re-merge refuses")
    Set tSC = ..Merged(tFlag, tArgs, .tPayload, .tProblem)
    Do $$$AssertEquals(tProblem, ..#PUBLISHED, "a recipient's flag moved, so the confirm's re-merge refuses")
    Set tUserDigest = ..Digest(tUser, tArgs)
    Do $$$AssertTrue((tUserDigest '= "") && (tUserDigest '= tDigest), "a recipient's user moved, so the digest differs")
    Set tMessageDigest = ..Digest(tBase, {"Pids": "812,907", "Message": "Up at 19:00"})
    Do $$$AssertTrue((tMessageDigest '= "") && (tMessageDigest '= tDigest), "and so does another message")
}

/// <p>AD-51 at the port: the body is <code>{Message, PidList}</code> with each pid once, as a
/// number; a caller body is refused; and an empty message, a set no process carries and a daemon
/// are each refused before any vendor call -- the last two with the published 409 -- and so is a
/// broadcast asked for inside a transaction, before anything is read.</p>
/// <p>Mutation (Rule 19): skip <method>OcuPilot.Port.ProcessPort.Receivable</method> in
/// <method>OcuPilot.Port.ProcessPort.Invoke</method> -- the vendor answers 200 and both 409 legs go
/// red. Drop its <code>$TLevel</code> refusal -- the transaction leg reads 409 and goes red.</p>
Method TestThePortComposesTheBodyAndRefusesBeforeAnyVendorCall()
{
    Do ##class(OcuPilot.Port.ProcessPort).PidSetProblem("907, 812,812", .tPids)
    Do $$$AssertEquals(##class(OcuPilot.Port.ProcessPort).BroadcastBody("Down at 18:00", tPids).%ToJSON(), "{""Message"":""Down at 18:00"",""PidList"":[812,907]}", "each pid once, as a number, in the canonical order")
    Do ..Port("BROADCAST", ..#ABSENTPID, "hello", {}, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "a caller body is refused")
    Do ..Port("BROADCAST", ..#ABSENTPID, "", "", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "400 " _ ##class(OcuPilot.Api.Error).#PORTVALIDATION, "so is an empty message")
    Do ..Port("BROADCAST", ..#ABSENTPID, "hello", "", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault) _ " " _ $Select($IsObject(tFault): tFault.reason, 1: ""), "409 " _ ##class(OcuPilot.Api.Error).#PROCESSBROADCASTRECIPIENT _ " " _ ..#PUBLISHED, "a set no process carries is the published refusal")
    Set tDaemon = ..DaemonPid()
    Do $$$AssertTrue(tDaemon '= "", "the list carries the control daemon")
    Do ..Port("BROADCAST", tDaemon, "hello", "", .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "409 " _ ##class(OcuPilot.Api.Error).#PROCESSBROADCASTRECIPIENT, "and so is a daemon, which cannot receive one")
    Set tHttp = ""
    Set tFault = ""
    TSTART
    Try {
        Do ..Port("BROADCAST", ..#ABSENTPID, "hello", "", .tHttp, .tFault)
    } Catch {
        Set tHttp = "raised"
    }
    TROLLBACK 1
    Do $$$AssertEquals(tHttp _ " " _ ..CodeOf(tFault), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "a broadcast asked for inside a transaction is refused before anything is read")
}

/// <p>AC3, AC4 at the agent's mint (AD-55): a set that is not 1 to 20 process ids and a message the
/// rule refuses are 400 <code>TOOL.ARGUMENTS</code> before anything is read -- the message leg names
/// a pid no process carries, which a read would answer 404 -- and a set holding the control daemon,
/// which cannot receive one, is refused with the published sentence. Nothing is stored for any of
/// them.</p>
/// <p>Mutation (Rule 19): drop the <method>OcuPilot.Port.ProcessPort.Receivable</method> check from
/// <method>OcuPilot.Screen.Tool.ProcessBroadcast.MergeUpdate</method> -- the daemon leg mints and goes
/// red.</p>
Method TestTheAgentsMintRefusesABadSetABadMessageAndAnIneligibleSet()
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tDaemon = ..DaemonPid()
    Do $$$AssertTrue(tDaemon '= "", "the list carries the control daemon")
    For tCase = $ListBuild("abc", "Down at 18:00", "", "a set that is not process ids"), $ListBuild(..#ABSENTPID, "a" _ $Char(9) _ "b", "", "a message holding a tab"), $ListBuild(tDaemon, "Down at 18:00", ..#PUBLISHED, "a set holding the control daemon") {
        Set tArgs = {}
        Do tArgs.%Set("Pids", $List(tCase, 1), "string")
        Do tArgs.%Set("Message", $List(tCase, 2), "string")
        Set tProposal = ""
        Set tSC = $ClassMethod($ClassMethod(..#TOOL, "MintClass"), "Mint", ..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", tTurn, tArgs, "OcuPilot.Kernel.Agent.Limits", .tProposal, .tHttp, .tFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), $List(tCase, 1), $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
        Do $$$AssertEquals($Get(tHttp) _ " " _ ..CodeOf($Get(tFault)), "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, $List(tCase, 4) _ " is refused at the mint")
        Do $$$AssertTrue('$IsObject(tProposal), "and no proposal is minted for " _ $List(tCase, 4))
        If $List(tCase, 3) '= "" {
            Set tProblem = ""
            If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set tProblem = tFault.%Get("detail").%Get("problem")
            Do $$$AssertEquals(tProblem, $List(tCase, 3), "with the published sentence")
        }
    }
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the seeded turn is removed")
}

/// <p>AD-59: the script is the vendor's own <code>POST /process/broadcast</code> with the composed
/// body and no query, and a set the port would refuse renders no step.</p>
Method TestTheSnippetRendersTheComposedCall()
{
    Kill tQuery
    Set tQuery("id") = "907,812"
    Set tQuery("Message") = "Down at 18:00"
    Set tSteps = ##class(OcuPilot.Port.ProcessPort).Snippet("Process", "BROADCAST", .tQuery, "", {"origin": "https://iris.example", "user": "ann"})
    Do $$$AssertEquals(tSteps.%Size(), 1, "one step")
    Set tText = tSteps.%Get(0).%Get("text")
    Do $$$AssertEquals(tSteps.%Get(0).%Get("kind"), "rest", "a REST call")
    Do $$$AssertTrue(tText [ "-X POST 'https://iris.example/api/admin/v2/process/broadcast'", "against the vendor's route with no query: " _ tText)
    Do $$$AssertTrue(tText [ "{""Message"":""Down at 18:00"",""PidList"":[812,907]}", "carrying the composed body: " _ tText)
    Set tQuery("id") = "abc"
    Do $$$AssertEquals(##class(OcuPilot.Port.ProcessPort).Snippet("Process", "BROADCAST", .tQuery, "", {}).%Size(), 0, "and an unreadable set renders none")
}

/// <p>AD-39, AD-53: the kernel's reason for <code>PROCESS.BROADCAST.RECIPIENT</code> is the
/// sentence EXPERIENCE.md publishes, and names no caller.</p>
Method TestTheRecipientReasonIsThePublishedSentence()
{
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).#REASONPROCESSBROADCASTRECIPIENT, ..#PUBLISHED, "the kernel's reason is the published sentence")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).#PROCESSBROADCASTRECIPIENT, "PROCESS.BROADCAST.RECIPIENT", "under its published code")
}

/// <p>AD-10 as amended: a broadcast is not a process-arm write, so neither the control daemon nor
/// this request's own job is prohibited for it, while a suspend of either is still refused by the
/// arm.</p>
/// <p>Mutation (Rule 19): drop the broadcast early-out from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method> -- the broadcast legs go red.</p>
Method TestABroadcastPassesTheProcessArmWhileASuspendIsRefused()
{
    Set tDaemon = ..DaemonPid()
    Do $$$AssertTrue(tDaemon '= "", "the list carries the control daemon")
    For tCase = $ListBuild(tDaemon, "osmgmt.processes.broadcast", 0, ""), $ListBuild($Job, "osmgmt.processes.broadcast", 0, ""), $ListBuild(tDaemon, "osmgmt.processes.suspend", 1, $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SYSTEMPROCESS")), $ListBuild($Job, "osmgmt.processes.suspend", 1, $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "OCUPILOTPROCESS")) {
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("process", "instance", $List(tCase, 1), .tRef)
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($List(tCase, 2), tRef, "{}", "[]", .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, $List(tCase, 2) _ " of " _ $List(tCase, 1) _ " is answered")
        Do $$$AssertEquals(tProhibits _ " " _ tCode, $List(tCase, 3) _ " " _ $List(tCase, 4), $List(tCase, 2) _ " of " _ $Select($List(tCase, 1) = $Job: "this job", 1: "the daemon"))
    }
}

/// <p>AD-5: the screen declares its one multi-select, sound, over the broadcast action, and its
/// <code>max</code> is the port's own cap.</p>
Method TestTheDeclaredMaxIsThePortsCap()
{
    Set tSC = $ClassMethod(..#SCREEN, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).MultiSelectProblem(tDeclaration), "", "its multiSelect is the declared grammar")
    Do $$$AssertEquals(tDeclaration.multiSelect.%ToJSON(), "{""action"":""broadcast"",""eligible"":""CanReceiveBroadcast"",""max"":20,""ineligibleKey"":""processBroadcastIneligible""}", "over the broadcast action and the vendor's own flag")
    Do $$$AssertEquals(tDeclaration.multiSelect.max, ##class(OcuPilot.Port.ProcessPort).#BROADCASTMAXPIDS, "and its max is the port's cap")
}

/// <p>The digest the confirm compares for fresh read <var>pFresh</var> and stored arguments
/// <var>pArgs</var>: the tool's own merge, over its declared subject.</p>
Method Digest(pFresh As %DynamicObject, pArgs As %DynamicObject) As %String
{
    Set tSC = $ClassMethod(..#TOOL, "MergeUpdate", pFresh, pArgs, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
    If $$$ISERR(tSC) || (tProblem '= "") Quit ""
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tPayload, $ClassMethod(..#SCREEN, "FingerprintExcludes"), .tDigest, $ClassMethod(..#TOOL, "FingerprintSubject"))
    If $$$ISERR(tSC) Quit ""
    Quit tDigest
}

/// <p>One call of the process port's <var>pType</var> for pid set <var>pIds</var>, with message
/// <var>pMessage</var> and caller body <var>pBody</var>.</p>
Method Port(pType As %String, pIds As %String, pMessage As %String, pBody, Output pHttp As %Integer, Output pFault As %DynamicObject, Output pResult)
{
    Kill tQuery
    Set tQuery("id") = pIds
    If pMessage '= "" Set tQuery("Message") = pMessage
    Do ##class(OcuPilot.Port.ProcessPort).Invoke("Process", pType, .tQuery, pBody, .pResult, .pHttp, .pFault)
}

/// <p>The pid of the instance's control daemon, read from the admin API's process list, or
/// <code>""</code>.</p>
Method DaemonPid() As %String
{
    Kill tNone
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Process", "LIST", .tNone, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit ""
    Set tPid = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) && (tRow.%Get("Routine") = "CONTROL") Set tPid = tRow.%Get("Pid") Quit
    }
    Quit tPid
}

/// <p>The code fault <var>pFault</var> carries, or <code>""</code>.</p>
ClassMethod CodeOf(pFault) As %String
{
    If '$IsObject(pFault) Quit ""
    Quit pFault.%Get("code")
}

}
