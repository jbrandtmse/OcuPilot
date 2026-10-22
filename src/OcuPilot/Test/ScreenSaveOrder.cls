/// <p>Pins the order <class>OcuPilot.Kernel.Proposal.ScreenSave</class> runs a Save in (AD-53, AD-55, AD-10, AD-34, AD-58),
/// once, for every screen Save that extends it: the gate, the body, the identity, the target's hold; the unexpected keys,
/// the rules, the state read; the merge, AD-10's set, the port write and the read-back, with the hold kept through the
/// answer and released on every exit. The steps are read from a trace the shared template and its hooks write
/// (<class>OcuPilot.Test.ScreenSaveOrderFixture</class>), so a step moved, dropped or doubled is a different string, and
/// the lock table says whether the hold was taken at each one.</p>
/// <p>The Save under test is the managed file transfer connection's over a port that keeps its connections in process
/// memory (<class>OcuPilot.Test.ScreenSaveMemoryPort</class>) and a prohibited set that answers from a switch
/// (<class>OcuPilot.Test.ScreenSaveSet</class>), so nothing reaches the instance. A step ends in <code>*</code> when this
/// process held a target lock as it ran.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, and a caller who holds the managed file transfer
/// screen's declared pairs, as the in-process Save legs of <class>OcuPilot.Test.MftConnectionWrite</class> do. It sets no
/// governance policy and creates no instance object, so it is not armed.</p>
Class OcuPilot.Test.ScreenSaveOrder Extends %UnitTest.TestCase
{

Parameter SAVE = "OcuPilot.Test.ScreenSaveOrderFixture";

Parameter TRACE = "OcuPilot.Test.ScreenSaveTrace";

Parameter ERRORS = "OcuPilot.Api.MftConnectionError";

/// <p>The steps every create takes up to AD-10's question: the gate, the body, the identity, then the hold, the unexpected
/// keys, the rules and the look-up of the name.</p>
Parameter CREATEHEAD = "gate,body,identity,unexpected*,rules:create:full*,ssl*,taken*,read*";

/// <p>The same for an edit: through the rules that need no read, the fresh read and the merge.</p>
Parameter EDITHEAD = "gate,body,identity,unexpected*,rules:update:shape*,read*,merge*";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#TRACE, "Reset")
    Do $$$AssertEquals($ClassMethod(..#TRACE, "Holding"), 0, "no Save target lock is held when the test starts")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#TRACE, "Reset")
    Quit $$$OK
}

/// <p>A create runs its steps in order: gate, body and identity before the hold; the unexpected keys, the rules and the
/// name's look-up with it held; then AD-10's set, the write and the read-back, and the answer, still held, answers the
/// identity and the read-back and no consequence. The target holds its stored fields.</p>
/// <p>Mutation (Rule 19): release the hold before <code>Answer</code> in
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.HandleCreate</method> -- <code>answer</code> reads unheld and this goes red;
/// drop AD-10's call from <method>OcuPilot.Kernel.Proposal.ScreenSave.Create</method> -- <code>prohibited*</code> is
/// missing.</p>
Method TestACreateRunsItsStepsInOrderWithTheHoldKeptThroughTheAnswer()
{
    Set tSteps = ..Save("", ..CreateBody("ocu-order-new"), .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, ..#CREATEHEAD _ ",prohibited*,write*,read*,answer*", "the create's steps, the hold taken after the identity and kept to the answer")
    Do $$$AssertEquals(tStatus _ " " _ ..Keys(tAnswer) _ " " _ tAnswer.%Get("id") _ " " _ tAnswer.%Get("readBack").%Get("verdict"), "201 id,readBack ocu-order-new matches", "answers 201 with the identity and the read-back alone")
    Do $$$AssertEquals($ClassMethod(..#TRACE, "Writes"), 1, "one write")
    Do $$$AssertEquals(..Keys($ClassMethod(..#TRACE, "Stored", "ocu-order-new")), "ApplicationName,SSLConfiguration,Service,URL,Username", "and the connection holds the five fields, the name being the key")
}

/// <p>An edit runs its steps in order: the unexpected keys, the rules that need no read, the fresh read and the merge, then
/// AD-10's set, the effect the change carries, the write and the read-back, the hold kept to the answer, which names the
/// identity and the read-back and no consequence, the default hook answering none.</p>
/// <p>Mutation (Rule 19): read the fresh state before the rules in
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.Update</method> -- <code>read*</code> moves ahead of
/// <code>rules:update:shape*</code>; ask <method>OcuPilot.Kernel.Proposal.ScreenSave.Consequence</method> before AD-10's
/// set -- <code>consequence*</code> moves ahead of <code>prohibited*</code>.</p>
Method TestAnEditRunsItsStepsInOrderWithTheHoldKeptThroughTheAnswer()
{
    Do $ClassMethod(..#TRACE, "Seed", "ocu-order-a", ..Fields())
    Set tSteps = ..Save("ocu-order-a", {"URL": "https://changed.example.com/files/"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, ..#EDITHEAD _ ",prohibited*,consequence*,write*,read*,answer*", "the edit's steps, the hold taken after the identity and kept to the answer")
    Do $$$AssertEquals(tStatus _ " " _ ..Keys(tAnswer) _ " " _ tAnswer.%Get("id") _ " " _ tAnswer.%Get("readBack").%Get("verdict"), "200 id,readBack ocu-order-a matches", "answers 200 with the identity and the read-back alone")
    Do $$$AssertEquals($ClassMethod(..#TRACE, "Stored", "ocu-order-a").%Get("URL") _ " " _ $ClassMethod(..#TRACE, "Stored", "ocu-order-a").%Get("Username"), "https://changed.example.com/files/ " _ ..Fields().%Get("Username"), "the change is stored over the fields the read answered")
    Do $$$AssertEquals($ClassMethod(..#TRACE, "AskedOf", "tool"), "security.mftconnections.update", "AD-10's set was asked as the update tool")
}

/// <p>An edit that changes nothing stops after the merge: AD-10's set is not asked, nothing is written or read back, and
/// the answer is the identity alone.</p>
/// <p>Mutation (Rule 19): drop the <code>tDiff.%Size() = 0</code> exit from
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.Update</method> -- the write and its steps appear and this goes red.</p>
Method TestAnEditThatChangesNothingStopsAfterTheMerge()
{
    Do $ClassMethod(..#TRACE, "Seed", "ocu-order-a", ..Fields())
    Set tSteps = ..Save("ocu-order-a", {"URL": (..Fields().%Get("URL"))}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, ..#EDITHEAD _ ",answer*", "the steps stop after the merge")
    Do $$$AssertEquals(tStatus _ " " _ ..Keys(tAnswer), "200 id", "the answer is the identity alone")
    Do $$$AssertEquals($ClassMethod(..#TRACE, "Writes"), 0, "and nothing was written")
}

/// <p>A caller the gate refuses is answered before the body is read, on both routes: only the gate runs, and the answer is
/// the denial.</p>
/// <p>Mutation (Rule 19): read the body before the gate in <method>OcuPilot.Kernel.Proposal.ScreenSave.HandleCreate</method>
/// and <method>OcuPilot.Kernel.Proposal.ScreenSave.HandleUpdate</method> -- <code>body</code> follows the gate.</p>
Method TestAGateRefusalIsAnsweredBeforeTheBodyIsRead()
{
    Do $ClassMethod(..#TRACE, "Arm", "gate")
    For tId = "", "ocu-order-a" {
        Set tSteps = ..Save(tId, [1], .tAnswer, .tStatus)
        Do $$$AssertEquals(tSteps, "gate", $Select(tId = "": "a create", 1: "an edit") _ ": only the gate ran")
        Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code"), "403 " _ $ClassMethod("OcuPilot.Kernel.Denial", "Code"), $Select(tId = "": "a create", 1: "an edit") _ ": it is refused with the denial")
    }
}

/// <p>A body that is not a JSON object is 400 <code>AGENT.BADBODY</code> after the gate and before the identity, the hold
/// and every rule, on both routes.</p>
/// <p>Mutation (Rule 19): read the identity before the body in
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.HandleCreate</method> -- the Save fails on a body it never read and
/// answers 500, so this goes red.</p>
Method TestABodyThatIsNotAnObjectIsRefusedBeforeTheIdentity()
{
    For tId = "", "ocu-order-a" {
        Set tSteps = ..Save(tId, [1], .tAnswer, .tStatus)
        Do $$$AssertEquals(tSteps, "gate,body", $Select(tId = "": "a create", 1: "an edit") _ ": the gate and the body ran, and no more")
        Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code"), "400 " _ ##class(OcuPilot.Api.Error).#AGENTBADBODY, $Select(tId = "": "a create", 1: "an edit") _ ": the body is refused")
    }
}

/// <p>An identity the Save cannot read is answered before the hold: a create whose identifying member has the wrong shape is
/// 422 <code>PORT.FIELD.SHAPE</code>, and an edit of an id that names no whole target is 404 <code>PORT.NOTFOUND</code>,
/// each while this process holds no lock, though the fixture's identity gives each a target the hold could take.</p>
/// <p>Mutation (Rule 19): take the hold before the shape check in
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.HandleCreate</method>, or before the identity check in
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.HandleUpdate</method> -- <code>violations*</code> or
/// <code>notfound*</code> reads held.</p>
Method TestAnIdentityThatNamesNoTargetIsAnsweredBeforeTheHold()
{
    Set tSteps = ..Save("", {"Name": 123}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, "gate,body,identity,violations", "a create with a name that is not text stops at the identity")
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code") _ " " _ ..ViolationOf(tAnswer, "Name"), "422 " _ $Parameter(..#ERRORS, "VALIDATION") _ " " _ ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE, "and is the shape violation, 422")
    Set tSteps = ..Save($Parameter(..#SAVE, "NOTWHOLE"), {"URL": "https://changed.example.com/files/"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, "gate,body,identity,notfound", "an edit of an id that names no whole target stops at the identity")
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code"), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "and is 404")
    Do $$$AssertEquals($ClassMethod(..#TRACE, "Writes"), 0, "with nothing written")
}

/// <p>A key the tool does not settle is 400 <code>PORT.FIELD.UNEXPECTED</code> before the rules and before anything is
/// read or sent, on both routes, though the same body breaks a rule: the answer names the key, not the rule.</p>
/// <p>Mutation (Rule 19): ask the rules before the unexpected keys in
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.Create</method> or
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.Update</method> -- the steps gain <code>rules</code> and the answer is 422.</p>
Method TestAnUnexpectedKeyIsRefusedBeforeTheRulesOnBothRoutes()
{
    Set tBody = ..CreateBody("ocu-order-new")
    Do tBody.%Set("URL", "not a url")
    Do tBody.%Set("Bogus", 1)
    Set tSteps = ..Save("", tBody, .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, "gate,body,identity,unexpected*,answer*", "a create stops at the unexpected keys")
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code") _ " " _ tAnswer.%Get("detail").%Get("violations").%Get(0).%Get("field"), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED _ " Bogus", "and names the key")
    Do $ClassMethod(..#TRACE, "Seed", "ocu-order-a", ..Fields())
    Set tSteps = ..Save("ocu-order-a", {"URL": 5, "Bogus": 1}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, "gate,body,identity,unexpected*,answer*", "an edit stops at the unexpected keys")
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code"), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "and is the same refusal")
}

/// <p>The rules come before any read of the state: a create that breaks a rule is 422 on that rule alone and never asks
/// whether its name is taken, though the name is, and an edit of a target the instance does not hold whose body breaks a
/// shape rule is 422, not 404, with no read made.</p>
/// <p>Mutation (Rule 19): ask <code>RulesTaken</code> whatever the rules found in
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.Create</method> -- the taken name joins the violations and the steps gain
/// <code>taken</code>; read the fresh state before the rules in <method>OcuPilot.Kernel.Proposal.ScreenSave.Update</method>
/// -- the edit answers 404.</p>
Method TestTheRulesAreAskedBeforeAnyStateRead()
{
    Do $ClassMethod(..#TRACE, "Seed", "ocu-order-held", ..Fields())
    Set tBody = ..CreateBody("ocu-order-held")
    Do tBody.%Remove("URL")
    Set tSteps = ..Save("", tBody, .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, "gate,body,identity,unexpected*,rules:create:full*,ssl*,answer*,violations*", "a create that breaks a rule stops after the rules, before the look-up of its name")
    Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, "URL") _ " " _ ..ViolationOf(tAnswer, "Name"), "422 " _ $Parameter(..#ERRORS, "URL") _ " ", "and is that rule alone: its name, which is taken, is not named")
    Set tSteps = ..Save("ocu-order-absent", {"URL": 5}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, "gate,body,identity,unexpected*,rules:update:shape*,answer*,violations*", "an edit of an absent target that breaks a shape rule stops after the rules, before the read")
    Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, "URL"), "422 " _ ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE, "and is 422, not 404")
}

/// <p>A name taken since is refused by the look-up that follows the rules and precedes AD-10's set and the write: 422 on
/// <code>Name</code> with <code>MFT.TAKEN</code>, and nothing is asked or written.</p>
/// <p>Mutation (Rule 19): drop the taken check from <method>OcuPilot.Kernel.Proposal.ScreenSave.Create</method> -- the
/// create writes and this goes red.</p>
Method TestATakenNameIsRefusedAfterTheRulesAndBeforeAnyWrite()
{
    Do $ClassMethod(..#TRACE, "Seed", "ocu-order-held", ..Fields())
    Set tSteps = ..Save("", ..CreateBody("ocu-order-held"), .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, ..#CREATEHEAD _ ",answer*,violations*", "the steps stop after the look-up")
    Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, "Name"), "422 " _ $Parameter(..#ERRORS, "TAKEN"), "422 on Name, taken")
    Do $$$AssertEquals($ClassMethod(..#TRACE, "Writes"), 0, "and nothing was written")
}

/// <p>An edit of a target the instance does not hold is 404 <code>PORT.NOTFOUND</code> once the fresh read has said so, before
/// any merge, AD-10's set or write, with the hold kept to the answer; so is one whose read succeeds and answers nothing.</p>
/// <p>The answer is rendered from the handler's own branch, so the hold is released on that exit too.</p>
/// <p>Mutation (Rule 19): release the hold in <method>OcuPilot.Kernel.Proposal.ScreenSave.HandleUpdate</method> only on the
/// path that reaches <code>Answer</code> -- the 404 leaves it held and this goes red; drop the not-an-object test of the
/// fresh read in <method>OcuPilot.Kernel.Proposal.ScreenSave.Update</method> -- the merge runs over nothing and this goes red.</p>
Method TestAnEditOfAnAbsentTargetIsNotFoundAfterTheFreshRead()
{
    Set tSteps = ..Save("ocu-order-absent", {"URL": "https://changed.example.com/files/"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, "gate,body,identity,unexpected*,rules:update:shape*,read*,notfound*", "the steps stop at the read")
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code"), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "the answer is 404")
    Do $ClassMethod(..#TRACE, "Arm", "emptyread")
    Do $ClassMethod(..#TRACE, "Seed", "ocu-order-a", ..Fields())
    Set tSteps = ..Save("ocu-order-a", {"URL": "https://changed.example.com/files/"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, "gate,body,identity,unexpected*,rules:update:shape*,read*,notfound*", "a read that succeeds and answers nothing stops at the read as well")
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code") _ " " _ $ClassMethod(..#TRACE, "Writes"), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND _ " 0", "and is 404 with nothing written")
}

/// <p>AD-10's set is asked of a create as it is of an edit, after the state read and before the port write, with the tool's
/// name and the composed change, and its refusal is 403 with its own code and nothing written; the create's question
/// names the new connection and the edit's names only what changed.</p>
/// <p>Mutation (Rule 19): drop the <code>Prohibited</code> call from <method>OcuPilot.Kernel.Proposal.ScreenSave.Create</method>
/// -- the create writes and the steps lose <code>prohibited</code>; drop it from
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.Update</method> likewise.</p>
Method TestTheProhibitedSetIsAskedOfACreateAndAnEditBeforeTheWrite()
{
    Set tCode = ##class(OcuPilot.Kernel.Proposal.Prohibited).#SERVINGSUPERSERVER
    Do $ClassMethod(..#TRACE, "Arm", "prohibit", tCode)
    Set tSteps = ..Save("", ..CreateBody("ocu-order-new"), .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, ..#CREATEHEAD _ ",prohibited*,answer*", "a create is refused after the look-up, before the write")
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code") _ " " _ $ClassMethod(..#TRACE, "Writes"), "403 " _ tCode _ " 0", "with the set's code and nothing written")
    Set tAsked = ##class(%DynamicObject).%FromJSON($ClassMethod(..#TRACE, "AskedOf", "diff"))
    Do $$$AssertEquals($ClassMethod(..#TRACE, "AskedOf", "tool") _ " " _ tAsked.%Size(), "security.mftconnections.create 5", "it was asked as the create tool, over the five fields the create sets")
    Do $$$AssertTrue($ClassMethod(..#TRACE, "AskedOf", "ref") [ "ocu-order-new", "and of the new connection: " _ $ClassMethod(..#TRACE, "AskedOf", "ref"))

    Do $ClassMethod(..#TRACE, "Seed", "ocu-order-a", ..Fields())
    Set tSteps = ..Save("ocu-order-a", {"URL": "https://changed.example.com/files/"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, ..#EDITHEAD _ ",prohibited*,answer*", "an edit is refused after the merge, before the write")
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code") _ " " _ $ClassMethod(..#TRACE, "Writes"), "403 " _ tCode _ " 0", "with the set's code and nothing written")
    Set tAsked = ##class(%DynamicObject).%FromJSON($ClassMethod(..#TRACE, "AskedOf", "diff"))
    Do $$$AssertEquals($ClassMethod(..#TRACE, "AskedOf", "tool") _ " " _ tAsked.%Size() _ " " _ tAsked.%Get(0).%Get("field"), "security.mftconnections.update 1 URL", "it was asked as the update tool, over the one field that changes")
    Do $$$AssertEquals($ClassMethod(..#TRACE, "Stored", "ocu-order-a").%Get("URL"), ..Fields().%Get("URL"), "and the stored connection is as it was")
}

/// <p>A merge problem is a 400 <code>TOOL.ARGUMENTS</code> carrying the problem unless the rules explain it: a problem the
/// merge reports for a change the rules accept is 400 with <code>detail.problem</code>, and one the rules' fuller reading
/// finds a broken rule behind -- an SSL/TLS configuration the instance does not hold -- is that rule's 422, each with
/// nothing written.</p>
/// <p>Mutation (Rule 19): answer the merge problem without the rules' second reading in
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.Merge</method> -- the second leg answers 400 and goes red.</p>
Method TestAMergeProblemIsA400UnlessARuleExplainsIt()
{
    Do $ClassMethod(..#TRACE, "Seed", "ocu-order-a", ..Fields())
    Do $ClassMethod(..#TRACE, "Arm", "mergeproblem")
    Set tSteps = ..Save("ocu-order-a", {"URL": "https://changed.example.com/files/"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, ..#EDITHEAD _ ",rules:update:full*,answer*", "a problem the rules do not explain is answered after the rules' second reading")
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code") _ " " _ tAnswer.%Get("detail").%Get("problem"), "400 " _ ##class(OcuPilot.Api.Error).#TOOLARGUMENTS _ " " _ $Parameter("OcuPilot.Test.ScreenSaveMftUpdate", "PROBLEM"), "it is 400, carrying the problem")
    Do $ClassMethod(..#TRACE, "Arm", "mergeproblem", "")
    Do $ClassMethod(..#TRACE, "ClearSteps")
    Set tSteps = ..Save("ocu-order-a", {"SSLConfiguration": ($Parameter("OcuPilot.Test.ScreenSaveMemoryPort", "ABSENTTLS"))}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, "SSLConfiguration"), "422 " _ $Parameter(..#ERRORS, "SSLCONFIG"), "a configuration the instance does not hold is that rule's 422: " _ tSteps)
    Do $$$AssertEquals($ClassMethod(..#TRACE, "Writes"), 0, "with nothing written")
}

/// <p>After a port that fails the write and one that raises an exception the Save answers 500 <code>INTERNAL</code> with
/// the write the last step: nothing is read back, and no lock is left held.</p>
/// <p>Mutation (Rule 19): read the write back whether or not it succeeded in
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.Create</method> -- <code>read*</code> follows <code>write*</code> and this goes
/// red.</p>
Method TestAFailedWriteAnswers500AndStillReleasesTheHold()
{
    For tArm = "fail", "throw" {
        Do $ClassMethod(..#TRACE, "Arm", tArm)
        Do $ClassMethod(..#TRACE, "Seed", "ocu-order-a", ..Fields())
        Set tSteps = ..Save("", ..CreateBody("ocu-order-new"), .tAnswer, .tStatus)
        Do $$$AssertEquals(tSteps, ..#CREATEHEAD _ ",prohibited*,write*,answer*", tArm _ ": a create ends at the write")
        Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code"), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, tArm _ ": it is 500")
        Set tSteps = ..Save("ocu-order-a", {"URL": "https://changed.example.com/files/"}, .tAnswer, .tStatus)
        Do $$$AssertEquals(tSteps, ..#EDITHEAD _ ",prohibited*,consequence*,write*,answer*", tArm _ ": an edit ends at the write")
        Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code"), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, tArm _ ": and is 500")
        Do $ClassMethod(..#TRACE, "Arm", tArm, "")
    }
}

/// <p>An exception that escapes into the handler once the hold is taken is answered 500 <code>INTERNAL</code>, and the
/// hold is still released, on both routes.</p>
/// <p>Mutation (Rule 19): release the hold as the last statement inside the <code>Try</code> of
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.HandleCreate</method> and
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.HandleUpdate</method> -- the exception skips it, the lock stays held and
/// this goes red.</p>
Method TestAnExceptionAfterTheHoldIsAnswered500AndReleasesIt()
{
    Do $ClassMethod(..#TRACE, "Seed", "ocu-order-a", ..Fields())
    Do $ClassMethod(..#TRACE, "Arm", "throwanswer")
    Set tSteps = ..Save("", ..CreateBody("ocu-order-new"), .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, ..#CREATEHEAD _ ",prohibited*,write*,read*,answer*", "a create raises in its answer, held")
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code"), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "and is 500")
    Set tSteps = ..Save("ocu-order-a", {"URL": "https://changed.example.com/files/"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, ..#EDITHEAD _ ",prohibited*,consequence*,write*,read*,answer*", "an edit raises in its answer, held")
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("code"), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "and is 500")
}

/// <p>A Save that judges the payload its edit would send (<method>OcuPilot.Kernel.Proposal.ScreenSave.CheckMerged</method>,
/// as the superserver's does) asks the rules over it after the merge and before AD-10's set.</p>
/// <p>Mutation (Rule 19): move the <code>CheckMerged</code> block below the <code>Prohibited</code> call in
/// <method>OcuPilot.Kernel.Proposal.ScreenSave.Update</method> -- <code>prohibited*</code> comes first and this goes
/// red.</p>
Method TestTheMergedPayloadIsJudgedBeforeTheProhibitedSet()
{
    Do $ClassMethod(..#TRACE, "Seed", "ocu-order-a", ..Fields())
    Do $ClassMethod(..#TRACE, "Arm", "checkmerged")
    Set tSteps = ..Save("ocu-order-a", {"URL": "https://changed.example.com/files/"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tSteps, ..#EDITHEAD _ ",rules:update:full*,prohibited*,consequence*,write*,read*,answer*", "the rules judge the merged payload between the merge and AD-10's set: " _ tSteps)
    Do $$$AssertEquals(tStatus, 200, "and the edit is saved")
}

/// <p>The four screen Saves are the one template: each extends <class>OcuPilot.Kernel.Proposal.ScreenSave</class>, runs
/// every step from it -- the handlers, <code>Create</code>, <code>Update</code> and their helpers -- leaves the port and
/// AD-10's set to it (production overrides neither, only a test seam does), and names rules that extend
/// <class>OcuPilot.Kernel.Proposal.ScreenSaveRules</class>. Its create tool declares the port its update tool does, the
/// one the template writes a create through. The base is abstract.</p>
/// <p>Mutation (Rule 19): let <class>OcuPilot.Area.WebApp.DocDbAppSave</class> override <code>ProhibitedClass</code> -- its
/// origin and its routine application subclass's read their own class and this goes red; give
/// <class>OcuPilot.Area.Security.SuperserverSave</class> its own <code>Body</code>, or a create tool another port --
/// likewise.</p>
Method TestTheFourSavesShareTheKernelTemplate()
{
    Set tBase = "OcuPilot.Kernel.Proposal.ScreenSave"
    Do $$$AssertEquals(##class(%Dictionary.CompiledClass).%OpenId(tBase).Abstract, 1, "the template is abstract")
    Set tSaves = $ListBuild("OcuPilot.Area.Security.SuperserverSave", "OcuPilot.Area.Security.MftConnectionSave", "OcuPilot.Area.WebApp.DocDbAppSave", "OcuPilot.Area.WebApp.RoutineAppSave")
    For tI = 1:1:$ListLength(tSaves) {
        Set tSave = $List(tSaves, tI)
        Do $$$AssertTrue($ClassMethod(tSave, "%Extends", tBase), tSave _ " extends the template")
        For tMethod = "HandleCreate", "HandleUpdate", "Create", "Update", "Unexpected", "Prohibited", "Send", "Answer", "Body", "CallerFields", "Add", "Gate", "PortClass", "ProhibitedClass" {
            Do $$$AssertEquals(##class(%Dictionary.CompiledMethod).%OpenId(tSave _ "||" _ tMethod).Origin, tBase, tSave _ "." _ tMethod _ " is the template's own")
        }
        Do $$$AssertTrue($ClassMethod($Parameter(tSave, "RULES"), "%Extends", "OcuPilot.Kernel.Proposal.ScreenSaveRules"), tSave _ " names rules that extend the shared rules")
        Do $$$AssertEquals($ClassMethod(tSave, "PortClass"), $ClassMethod($Parameter(tSave, "UPDATETOOL"), "PortClass"), tSave _ " goes to the port its update tool declares")
        Do $$$AssertEquals($ClassMethod($Parameter(tSave, "CREATETOOL"), "PortClass"), $ClassMethod($Parameter(tSave, "UPDATETOOL"), "PortClass"), tSave _ "'s create tool declares that port too")
        Do $$$AssertEquals($ClassMethod(tSave, "ProhibitedClass"), "OcuPilot.Kernel.Proposal.Prohibited", tSave _ " asks the shipped prohibited set")
    }
}

/// <p>Run the Save in this process with <var>pBody</var> -- a create when <var>pId</var> is empty, else an edit of
/// <var>pId</var> -- answering the steps it took, comma-joined, the parsed answer in <var>pAnswer</var> and the status in
/// <var>pStatus</var>. Asserts the Save returned, left no lock of its own held, and, with the answer an object, that it is
/// one.</p>
Method Save(pId As %String, pBody As %DynamicAbstractObject, Output pAnswer As %DynamicObject, Output pStatus As %Integer) As %String
{
    Do $ClassMethod(..#TRACE, "ClearSteps")
    Set tSC = $ClassMethod(..#SAVE, "Handle", pId, pBody, .tRaw, .pStatus)
    Do $$$AssertStatusOK(tSC, "the Save ran in this process")
    Set pAnswer = {}
    Try {
        If tRaw '= "" Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    } Catch {
        Do $$$AssertTrue(0, "the answer is a JSON object: " _ $Extract(tRaw, 1, 200))
    }
    Do $$$AssertEquals($ClassMethod(..#TRACE, "Holding"), 0, "the hold is released when the Save returns")
    Quit $ClassMethod(..#TRACE, "Steps")
}

/// <p>A create's body for the connection <var>pName</var>: the five fields every create must carry.</p>
ClassMethod CreateBody(pName As %String) As %DynamicObject
{
    Set tBody = ..Fields()
    Do tBody.%Set("Name", pName)
    Quit tBody
}

/// <p>The five fields a stored connection holds.</p>
ClassMethod Fields() As %DynamicObject
{
    Quit {"Service": "Box", "URL": "https://api.example.com/files/", "SSLConfiguration": "OcuProbeTLS", "Username": "probe@example.com", "ApplicationName": "OcuProbeApp"}
}

/// <p>The keys of <var>pObject</var>, sorted and comma-joined, <code>""</code> for anything that is not an object.</p>
ClassMethod Keys(pObject) As %String
{
    If '$IsObject(pObject) Quit ""
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tNames(tKey) = ""
    }
    Set tOut = ""
    Set tName = ""
    For {
        Set tName = $Order(tNames(tName))
        If tName = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tName
    }
    Quit tOut
}

/// <p>The code of the violation on <var>pField</var> in the envelope <var>pAnswer</var>, or <code>""</code>.</p>
ClassMethod ViolationOf(pAnswer As %DynamicObject, pField As %String) As %String
{
    If '$IsObject(pAnswer) || '$IsObject(pAnswer.%Get("detail")) || (pAnswer.%Get("detail").%GetTypeOf("violations") '= "array") Quit ""
    Set tIterator = pAnswer.%Get("detail").%Get("violations").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("field") = pField Quit
        Set tRow = ""
    }
    Quit $Select($IsObject($Get(tRow)): tRow.%Get("code"), 1: "")
}

}
