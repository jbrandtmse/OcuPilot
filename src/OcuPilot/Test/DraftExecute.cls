/// <p>The copy-out draft (AD-59, Story 14.1), proven against the vendor: this class is the one in
/// the suite that <b>runs</b> a rendered script rather than reading its text. A <code>rest</code>
/// step is parsed out of the draft's own answer and sent as a real HTTP request to this instance's
/// own admin API; an <code>objectscript</code> step is parsed out the same way and literally
/// <code>XECUTE</code>d in <code>%SYS</code>. Neither goes through
/// <class>OcuPilot.Port.AdminPort</class>'s or <class>OcuPilot.Port.LogSourcePort</class>'s own
/// write path -- <class>OcuPilot.Test.DraftRegistry</class>'s parity test already proves the draft's
/// composed query and body equal what <class>OcuPilot.Kernel.Proposal.Confirm</class> hands its
/// port, in process, through the fixture port; this class pins that the vendor's own admin API and
/// the vendor's own <code>SYS.ApplicationError</code> class accept the exact text a caller would
/// copy out of the card and paste into a shell or a terminal.</p>
/// <p><b>What it needs from the environment.</b> A throwaway container:
/// <parameter>ARMINGVARIABLE</parameter> for the real application-error delete,
/// <parameter>SEEDVARIABLE</parameter> for the real application-error seed
/// (<class>OcuPilot.Test.ErrorLogSeed</class>'s own guard, checked here as well so this class
/// refuses before either test method runs rather than only inside the helper it calls), and
/// <parameter>PRINCIPALVARIABLE</parameter> for the probe web application
/// <class>OcuPilot.Test.ProposalFixture</class> creates and removes. It seeds two real application
/// errors, deletes the one the draft names through the rendered script and the other in cleanup,
/// and it creates and removes one web application, restoring the field it changed before removal.</p>
Class OcuPilot.Test.DraftExecute Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ERROR_DELETE";

Parameter SEEDVARIABLE = "OCUPILOT_ALLOW_ERROR_SEED";

Parameter PRINCIPALVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The namespace the seeded application error is written to and deleted from -- a normal
/// namespace, never the install namespace.</p>
Parameter ERRORNAMESPACE = "USER";

Parameter DRAFT = "OcuPilot.Kernel.Proposal.Draft";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DraftExecute executes a rendered ObjectScript script that deletes a real application error, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing ran. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#SEEDVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DraftExecute seeds a real application error through OcuPilot.Test.ErrorLogSeed. " _ ..#SEEDVARIABLE _ " does not read 1 here, so nothing ran.")
    }
    If $System.Util.GetEnviron(..#PRINCIPALVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DraftExecute creates and modifies a real web application through OcuPilot.Test.ProposalFixture. " _ ..#PRINCIPALVARIABLE _ " does not read 1 here, so nothing ran.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveWriteTarget()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>Seed one live proposal of <var>pTool</var> against <var>pType</var>/<var>pId</var> for the
/// test account, with the stored <var>pPayload</var>, <var>pDiff</var> and <var>pArguments</var>,
/// and answer its id. The same shape <class>OcuPilot.Test.DraftRoute</class>'s own <code>Seed</code>
/// builds.</p>
Method Seed(pTool As %String, pType As %String, pId As %String, pPayload As %String, pDiff As %String = "[]", pArguments As %String = "{}") As %String
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key(pType, "instance", pId, .tTargetRef)
    Do $$$AssertStatusOK(tSC, "the target reference is built")
    Kill tValues
    Set tValues("user") = tUser
    Set tValues("convKey") = ""
    Set tValues("turnKey") = tTurnKey
    Set tValues("toolName") = pTool
    Set tValues("targetRef") = tTargetRef
    Set tValues("fingerprint") = "0"
    Set tValues("arguments") = pArguments
    Set tValues("payload") = pPayload
    Set tValues("diff") = pDiff
    Set tValues("unchangedCount") = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Quit tKey
}

/// <p>Parse one <code>rest</code> step's <var>pText</var> into <var>pVerb</var>, <var>pUrl</var> and
/// <var>pBody</var> (the JSON body, or <code>""</code> when the step sends none).</p>
/// <p>This reads <method>OcuPilot.Port.AdminPort.RestStep</method>'s own template rather than
/// reconstructing the request independently: the template quotes every value with
/// <method>OcuPilot.Port.AdminPort.ShellQuoted</method>, which wraps in a single quote and escapes
/// none in a value with no single quote of its own -- true of every probe name and JSON payload this
/// class renders -- so splitting <var>pText</var> on <code>'</code> reads the caller name, the URL
/// and, when present, the body as fixed pieces 2, 4 and 8.</p>
ClassMethod ParseRestStep(pText As %String, Output pVerb As %String, Output pUrl As %String, Output pBody As %String) [ Private ]
{
    Set pVerb = $Piece($Piece(pText, "'", 3), " ", 3)
    Set pUrl = $Piece(pText, "'", 4)
    Set pBody = $Select($Length(pText, "'") >= 8: $Piece(pText, "'", 8), 1: "")
}

/// <p>AC1, run for real: every step the draft renders for a live <code>webapp.list.update</code>
/// merge write is run exactly as rendered -- the two <code>objectscript</code> steps
/// <code>XECUTE</code>d and the <code>rest</code> step parsed out and sent as an actual HTTP
/// request to this instance's own admin API -- never through
/// <class>OcuPilot.Port.AdminPort.Invoke</class> and never reconstructed from the stored row. A
/// plain <code>WebApp.App</code> merge write renders three steps, not one (AD-27's kept-type
/// completion: the wire body never carries <code>Type</code>, so the draft brackets the PUT with a
/// step that reads the current value and a step that re-applies it): a text-only assertion would
/// not catch a script that runs the PUT alone and silently resets the application's type. The
/// third step's <code>&lt;Type&gt;</code> placeholder is not a secret, and a caller pasting this
/// into a shell fills it from the first step's own <code>ZWrite</code> output.
/// This test fills it the same value read the same way, and proves the application ends up holding
/// exactly the description the draft named <b>and</b> its original type -- the state a confirm of
/// an identical proposal would have produced.</p>
/// <p>Mutation (Rule 19): change one character of the URL <method>OcuPilot.Port.AdminPort.RestStep</method>
/// renders (for example, drop the query string) -- the admin API answers a 4xx here and this test
/// goes red, where a text-only assertion would not notice the route was unreachable.</p>
Method TestARenderedRestScriptIsAcceptedByTheAdminApi()
{
    Set tTarget = ##class(OcuPilot.Test.ProposalFixture).#WRITETARGET
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).EnsureWriteTarget(, .tCreated)
    Do $$$AssertStatusOK(tSC, "the probe application is created: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit

    Kill tQuery
    Set tQuery("name") = tTarget
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the application reads before the change")
    If $$$ISERR(tSC) Quit

    ; The value the third step's <Type> placeholder needs, read the way a human would read it off
    ; the first step's own ZWrite -- a plain, non-XECUTEd read of the same call.
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Applications).Get(tTarget, .tTypeProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Do $$$AssertStatusOK(tSC, "the application's current type reads")
    If $$$ISERR(tSC) Quit
    Set tOriginalType = $Get(tTypeProps("Type"))

    Set tBefore = ##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Description")
    Set tNewValue = "changed by the real-execution draft probe"
    Do tFresh.%Set("Description", tNewValue, "string")
    Set tDiff = [{"field": "Description", "before": (tBefore), "after": (tNewValue)}]
    Set tArguments = {"Name": (tTarget), "Description": (tNewValue)}
    Set tKey = ..Seed("webapp.list.update", "web-application", tTarget, tFresh.%ToJSON(), tDiff.%ToJSON(), tArguments.%ToJSON())
    If tKey = "" Quit

    Set tOrigin = "http://" _ ##class(OcuPilot.Test.Http).GetTestServer() _ ":" _ ##class(OcuPilot.Test.Http).GetTestPort()
    Set tSC = $ClassMethod(..#DRAFT, "Take", tKey, ##class(OcuPilot.Test.Http).GetTestUsername(), tOrigin, .tAnswer, .tDraftHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the draft is taken: " _ tCode)
    If $$$ISERR(tSC) Quit
    Set tSteps = tAnswer.%Get("draft").%Get("steps")
    Do $$$AssertEquals(tSteps.%Size(), 3, "AD-27's kept-type completion brackets the PUT with a read and a restore step")
    If tSteps.%Size() '= 3 Quit
    Set tReadStep = tSteps.%Get(0)
    Set tRestStep = tSteps.%Get(1)
    Set tRestoreStep = tSteps.%Get(2)
    Do $$$AssertEquals(tReadStep.%Get("kind"), "objectscript", "the first step reads the current type")
    Do $$$AssertEquals(tRestStep.%Get("kind"), "rest", "the second step is the REST script")
    Do $$$AssertEquals(tRestoreStep.%Get("kind"), "objectscript", "the third step restores the type")

    ; Step 1, run for real: a read, so it changes nothing this test must undo.
    Do ..RunObjectScriptStep(tReadStep.%Get("text"), .tStep1SC)
    Do $$$AssertStatusOK(tStep1SC, "the type-reading step executes without raising")

    Do ..ParseRestStep(tRestStep.%Get("text"), .tVerb, .tUrl, .tBody)
    Do $$$AssertEquals(tVerb, "PUT", "the parsed verb")
    Do $$$AssertEquals($Extract(tUrl, 1, $Length(tOrigin)), tOrigin, "the parsed url carries the request's own origin: " _ tUrl)
    Set tPath = $Extract(tUrl, $Length(tOrigin) + 1, *)
    Do $$$AssertNotEquals(tBody, "", "the parsed body is not empty")

    ; Step 2, run for real: the actual write, going to the instance's own admin API, never through
    ; OcuPilot.Port.AdminPort -- exactly the request a caller would make by pasting the card's own
    ; text into a shell.
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(tVerb, tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tExecStatus, .tExecBody, .tExecHeaders, tBody, "application/json")
    Do $$$AssertStatusOK(tSC, "the rendered script's request completes")
    Do $$$AssertTrue((tExecStatus >= 200) && (tExecStatus < 300), "the admin API accepts the rendered script's own request: " _ tExecStatus _ " " _ tExecBody)

    ; Step 3, run for real, with <Type> filled from the same read a human would use: the restore
    ; the wire PUT cannot carry on its own.
    Set tRestoreText = $Replace(tRestoreStep.%Get("text"), "<Type>", tOriginalType)
    Do ..RunObjectScriptStep(tRestoreText, .tStep3SC)
    Do $$$AssertStatusOK(tStep3SC, "the type-restoring step executes without raising")

    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Description"), tNewValue, "running the rendered script changed the application exactly as the drafted value named -- the state a confirm of an identical proposal would have produced")
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Applications).Get(tTarget, .tTypePropsAfter)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Do $$$AssertStatusOK(tSC, "the application's type reads back after the run")
    Do $$$AssertEquals($Get(tTypePropsAfter("Type")), tOriginalType, "and its type survived the round trip, restored by the third step")

    ; This test made the real change, not a confirm, so it undoes the description before
    ; OnAfterOneTest removes the application -- through AdminPort.Invoke this time, since restoring
    ; is not part of what is under test.
    Kill tRestoreQuery
    Set tRestoreQuery("name") = tTarget
    Do tFresh.%Set("Description", tBefore, "string")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("WebApp.App", "PUT", .tRestoreQuery, tFresh, .tRestored, .tRestoreHttp, .tRestoreFault)
    Do $$$AssertStatusOK(tSC, "the probe application's field is restored after the real execution")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Description"), tBefore, "and reads back as it was before this test")
}

/// <p>Run one <code>objectscript</code> step's own <var>pText</var> exactly as rendered --
/// <code>XECUTE</code>d line by line -- answering only whether it raised, in <var>pRunSC</var>.
/// AD-16: <code>$NAMESPACE</code> is restored on both paths, first in the <code>Catch</code>.</p>
/// <p>Nothing the step's own lines assign is read back here. A name a compiled caller also
/// references elsewhere resolves, inside a compiled routine, through storage <code>XECUTE</code>
/// does not share (measured on this build): the read answers a stale value, never
/// <code>&lt;UNDEFINED&gt;</code>, so
/// the trap is a silent wrong answer, never a caught one. Every real assertion this class makes is
/// therefore the functional, externally observable outcome, never a variable a step's own text
/// happened to set.</p>
ClassMethod RunObjectScriptStep(pText As %String, Output pRunSC As %Status) [ Private ]
{
    Set tOrigNS = $NAMESPACE
    Set pRunSC = $$$OK
    Try {
        Set tLines = $ListFromString(pText, $Char(10))
        For tI = 1:1:$ListLength(tLines) {
            Set tLine = $Extract($List(tLines, tI), 2, *)
            If tLine '= "" XECUTE tLine
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pRunSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>The matrix's <code>%SYS</code> completion (AD-48), run for real: this test seeds two genuine
/// application errors in one namespace, drafts the delete of the second, and literally
/// <code>XECUTE</code>s the drafted <code>objectscript</code> step's own text -- never
/// <class>OcuPilot.Port.LogSourcePort.RemoveErrorIds</class> and no reconstruction. Each entry is
/// read by its own id (namespace, date and number) at the port's <code>detail</code> level: the
/// named entry reads 200 before and 404 <code>LOG.ENTRY</code> after, and the other still reads 200
/// after -- exactly the one entry removed, whatever else the namespace holds. The other entry is
/// deleted in cleanup.</p>
/// <p>Mutation (Rule 19): have <method>OcuPilot.Port.LogSourcePort.Snippet</method> render
/// <code>DeleteByNamespace</code> for the namespace instead of <code>DeleteByError</code> -- the
/// other entry's read answers 404 and the named one's <code>LOG.NAMESPACE</code>, and this test goes
/// red.</p>
Method TestARenderedObjectScriptScriptDeletesTheErrorItNames()
{
    Set tSC = ##class(OcuPilot.Test.ErrorLogSeed).SeedInto(..#ERRORNAMESPACE, .tOtherDay, .tOtherNumber)
    Do $$$AssertStatusOK(tSC, "a second real application error is seeded, to survive the delete: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tOtherDate = $ZDate(tOtherDay, 1)
    Do {
        Set tSC = ##class(OcuPilot.Test.ErrorLogSeed).SeedInto(..#ERRORNAMESPACE, .tDay, .tNumber)
        Do $$$AssertStatusOK(tSC, "the real application error the draft names is seeded: " _ $System.Status.GetErrorText(tSC))
        If $$$ISERR(tSC) Quit
        Set tDate = $ZDate(tDay, 1)

        Set tSC = ##class(OcuPilot.Port.LogSourcePort).Errors("detail", ..#ERRORNAMESPACE, tDate, tNumber, "", .tBefore, .tBeforeHttp, .tBeforeFault)
        Do $$$AssertStatusOK(tSC, "the named entry reads by its own id before the delete: #" _ tNumber)
        Do $$$AssertEquals(tBeforeHttp, 200, "at 200")
        If $$$ISERR(tSC) Quit

        Set tPayload = {"namespace": (..#ERRORNAMESPACE), "entries": [{"date": (tDate), "errorNumber": (tNumber)}]}
        Set tKey = ..Seed("logs.applicationerrors.delete", "application-error", ..#ERRORNAMESPACE, tPayload.%ToJSON())
        If tKey = "" Quit

        Set tSC = $ClassMethod(..#DRAFT, "Take", tKey, ##class(OcuPilot.Test.Http).GetTestUsername(), "http://localhost", .tAnswer, .tDraftHttp, .tCode)
        Do $$$AssertStatusOK(tSC, "the draft is taken: " _ tCode)
        If $$$ISERR(tSC) Quit
        Set tSteps = tAnswer.%Get("draft").%Get("steps")
        Do $$$AssertEquals(tSteps.%Size(), 1, "one script step for a single-entry delete")
        If tSteps.%Size() '= 1 Quit
        Set tIterator = tSteps.%GetIterator()
        Do tIterator.%GetNext(.tIndex, .tStep)
        Do $$$AssertEquals(tStep.%Get("kind"), "objectscript", "the step is ObjectScript")
        Set tText = tStep.%Get("text")
        Do $$$AssertTrue(tText [ ("##class(SYS.ApplicationError).DeleteByError(""" _ $ZConvert(..#ERRORNAMESPACE, "U") _ """, """ _ tDate _ """, """ _ tNumber _ """)"), "naming the vendor call for exactly the named entry: " _ tText)

        ; The real proof: these lines are XECUTEd exactly as rendered, never through
        ; OcuPilot.Port.LogSourcePort.RemoveErrorIds. The functional checks below -- the named entry
        ; is gone and the other is not -- are what prove it, per RunObjectScriptStep's own doc comment.
        Do ..RunObjectScriptStep(tText, .tRunSC)
        Do $$$AssertStatusOK(tRunSC, "the rendered script executes without raising: " _ $Select($$$ISOK(tRunSC): "", 1: $System.Status.GetErrorText(tRunSC)))
        If $$$ISERR(tRunSC) Quit

        Set tSC = ##class(OcuPilot.Port.LogSourcePort).Errors("detail", ..#ERRORNAMESPACE, tDate, tNumber, "", .tAfter, .tAfterHttp, .tAfterFault)
        Set tAfterCode = $Select($IsObject(tAfterFault): tAfterFault.%Get("code"), 1: "")
        Set tGoneCode = $Select(tOtherDate = tDate: ##class(OcuPilot.Api.Error).#LOGENTRY, 1: ##class(OcuPilot.Api.Error).#LOGDATE)
        Do $$$AssertEquals(tAfterHttp, 404, "the named entry's id read answers 404 after the delete: " _ $System.Status.GetErrorText(tSC))
        Do $$$AssertEquals(tAfterCode, tGoneCode, "on the code for that one entry, so it alone is gone")

        Set tSC = ##class(OcuPilot.Port.LogSourcePort).Errors("detail", ..#ERRORNAMESPACE, tOtherDate, tOtherNumber, "", .tOther, .tOtherHttp, .tOtherFault)
        Do $$$AssertStatusOK(tSC, "the other entry still reads by its own id after the delete: #" _ tOtherNumber)
        Do $$$AssertEquals(tOtherHttp, 200, "at 200 -- exactly the state a confirm of an identical proposal would leave")

        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "canceled", "the proposal closes")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "ClosedReason"), "draft", "with the draft reason")
    } While 0
    Do $$$AssertStatusOK(..DeleteError(tOtherDate, tOtherNumber), "the other seeded entry is removed in cleanup")
}

/// <p>Delete one application error in <parameter>ERRORNAMESPACE</parameter> by its date and number
/// through the vendor's <code>SYS.ApplicationError.DeleteByError</code>, in <code>%SYS</code>.</p>
ClassMethod DeleteError(pDate As %String, pNumber As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(SYS.ApplicationError).DeleteByError($ZConvert(..#ERRORNAMESPACE, "U"), pDate, pNumber)
        Set $NAMESPACE = tOrigNS
    }
    Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
