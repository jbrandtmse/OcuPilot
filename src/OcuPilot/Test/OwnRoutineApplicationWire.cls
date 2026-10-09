/// <p>Pins the routine application arm (AD-10 as amended, DW-2239, Story 18.10) over the two routes that reach it: the web
/// applications screen's row actions over <code>POST /screens/webapp.list/action</code>, and the agent's proposal confirmed
/// over <code>POST /proposal/:id/confirm</code>. A delete, a disable and a <code>MatchRoles</code> change of
/// <code>OcuPilotState</code> and of <code>OcuPilotIdentity</code> are each refused 403
/// <code>PROHIBITED.OCUPILOTROUTINEAPP</code> with the published sentence, and the application reads back unchanged.</p>
/// <p>The agent route carries a delete, a disable and a <code>MatchRoles</code> change: <class>OcuPilot.Screen.Tool.WebAppUpdate</class>
/// admits <code>MatchRoles</code> among its settable fields, so an agent proposal can carry it; the mint stores it and its confirm is refused at the arm.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s test account, with both routine applications present. It creates no application and
/// sends no change the arm allows; <method>OnAfterOneTest</method> removes the proposal rows it seeded. Throwaway only: a
/// leg that is not refused would change a routine application.</p>
Class OcuPilot.Test.OwnRoutineApplicationWire Extends %UnitTest.TestCase
{

/// <p>The API base the routes are served under.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>The screen whose row actions the first route carries.</p>
Parameter ACTIONSCREEN = "webapp.list";

/// <p>The routine applications the arm names, one per leg.</p>
Parameter STATEAPP = "OcuPilotState";

Parameter IDENTITYAPP = "OcuPilotIdentity";

/// <p>The code the arm answers.</p>
Parameter CODE = "PROHIBITED.OCUPILOTROUTINEAPP";

/// <p>The sentence the arm answers, as the published text states it.</p>
Parameter REASON = "OcuPilot reads its own protected state through this privileged routine application, so it cannot be deleted or disabled and the roles it grants cannot be changed.";

/// <p>The limits class the agent's mint reads.</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The web application screen's descriptor, the mint's screen.</p>
Parameter SCREEN = "OcuPilot.Screen.Descriptor.WebAppList";

/// <p>The delete and update tools the agent's proposals are minted by.</p>
Parameter DELETETOOL = "OcuPilot.Screen.Tool.WebAppDelete";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.WebAppUpdate";

/// <p>Removes the proposal rows this class seeded.</p>
Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the proposal rows this class seeded are removed")
    Quit $$$OK
}

/// <p>One <code>POST</code> of <var>pAction</var> against <var>pId</var> on the web applications screen, with
/// <var>pValues</var> when given, as the test account: the status and the parsed answer.</p>
ClassMethod Act(pAction As %String, pId As %String, pValues As %DynamicObject = "", Output pStatus As %Integer, Output pBody) As %Status
{
    Set tRequest = {"action": (pAction), "id": (pId)}
    If $IsObject(pValues) Do tRequest.%Set("values", pValues)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/screens/" _ ..#ACTIONSCREEN _ "/action", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Set pBody = ""
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
    Quit tSC
}

/// <p>One <code>POST</code> of the confirm route for <var>pKey</var> as the test account: the status and the parsed answer.</p>
ClassMethod ConfirmKey(pKey As %String, Output pStatus As %Integer, Output pBody) As %Status
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/proposal/" _ pKey _ "/confirm", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders, "", "application/json")
    Set pBody = ""
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
    Quit tSC
}

/// <p>Asserts one refusal: 403, the arm's code, the published sentence, and the application <var>pName</var> reading back as
/// <var>pBefore</var>. <var>pLabel</var> names the leg in each message.</p>
Method AssertRefused(pLabel As %String, pName As %String, pBefore As %String, pStatus As %Integer, pBody)
{
    Do $$$AssertEquals(pStatus, 403, pLabel _ " is refused 403: " _ $Select($IsObject(pBody): pBody.%ToJSON(), 1: $Get(pBody)))
    Set tCode = ""
    Set tReason = ""
    If $IsObject(pBody) {
        Set tCode = pBody.%Get("code")
        Set tReason = pBody.%Get("reason")
    }
    Do $$$AssertEquals(tCode, ..#CODE, pLabel _ " is refused the routine application code")
    Do $$$AssertEquals(tReason, ..#REASON, pLabel _ " carries the published sentence")
    Do $$$AssertEquals(##class(OcuPilot.Test.OwnRoutineApplication).WebAppJSON(pName), pBefore, pLabel _ " leaves " _ pName _ " as it was")
}

/// <p>Screen route: a delete, a disable and a <code>MatchRoles</code> change of each routine application are refused over
/// the wire, and each application reads back unchanged.</p>
/// <p>Mutation (Rule 19): drop the <code>MatchRoles</code> and <code>Roles</code> arm's branch in
/// <class>OcuPilot.Kernel.Proposal.Prohibited</class>'s <method>RoutineApplicationChanges</method> -- the matching-role leg
/// goes red.</p>
Method TestTheScreenRouteRefusesEveryArmedAction()
{
    For tName = ..#STATEAPP, ..#IDENTITYAPP {
        Set tBefore = ##class(OcuPilot.Test.OwnRoutineApplication).WebAppJSON(tName)
        Do $$$AssertNotEquals(tBefore, "", tName _ " is present to begin with")
        If tBefore = "" Continue

        Set tSC = ..Act("delete", tName, "", .tStatus, .tBody)
        Do $$$AssertStatusOK(tSC, "the delete of " _ tName _ " is sent")
        Do ..AssertRefused("the screen delete of " _ tName, tName, tBefore, tStatus, tBody)

        Set tSC = ..Act("disable", tName, "", .tStatus2, .tBody2)
        Do $$$AssertStatusOK(tSC, "the disable of " _ tName _ " is sent")
        Do ..AssertRefused("the screen disable of " _ tName, tName, tBefore, tStatus2, tBody2)

        Set tSC = ..Act("add-matching-role", tName, {"MatchRole": "%Operator", "Role": "%SQL"}, .tStatus3, .tBody3)
        Do $$$AssertStatusOK(tSC, "the matching-role change of " _ tName _ " is sent")
        Do ..AssertRefused("the screen matching-role change of " _ tName, tName, tBefore, tStatus3, tBody3)
    }
}

/// <p>Agent route: the mint of a delete of each routine application is refused 403 before its precondition, and a delete
/// stored before that refusal is refused 403 at its confirm; a disable and a <code>MatchRoles</code> change are minted and
/// their confirms are refused 403. Each application reads back unchanged.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Kernel.Proposal.Prohibited</class>'s <parameter>ROUTINEAPPLICATIONFIELDS</parameter>
/// <code>"MatchRoles,Roles"</code> to <code>"Roles"</code> -- the agent's confirmed <code>MatchRoles</code> leg goes red.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Kernel.Proposal.Prohibited.RefusesDeleteBeforeState</code> answers 0 -- the mint's delete
/// leg answers 400 from the precondition and goes red.</p>
Method TestTheAgentConfirmRefusesEveryArmedAction()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(##class(OcuPilot.Test.Http).GetTestUsername(), "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a completed turn is seeded for the agent's proposals")
    If $$$ISERR(tSC) Quit

    For tName = ..#STATEAPP, ..#IDENTITYAPP {
        Set tBefore = ##class(OcuPilot.Test.OwnRoutineApplication).WebAppJSON(tName)
        Do $$$AssertNotEquals(tBefore, "", tName _ " is present to begin with")
        If tBefore = "" Continue

        Set tSC = ..MintFor(..#DELETETOOL, tTurn, {"Name": (tName)}, .tProposal, .tHttp, .tFault)
        Do ..AssertRefused("the agent's mint of a delete of " _ tName, tName, tBefore, tHttp, tFault)

        Set tSC = ..SeedDelete(tName, tTurn, .tDeleteKey)
        Do $$$AssertStatusOK(tSC, "a delete of " _ tName _ " is stored, as a mint the arm did not refuse would store it")
        If $$$ISOK(tSC) {
            Set tSC = ..ConfirmKey(tDeleteKey, .tStatus, .tBody)
            Do $$$AssertStatusOK(tSC, "the confirm of the stored delete of " _ tName _ " is sent")
            Do ..AssertRefused("the agent's confirmed delete of " _ tName, tName, tBefore, tStatus, tBody)
        }

        Set tSC = ..MintFor(..#UPDATETOOL, tTurn, {"Name": (tName), "Enabled": false}, .tProposal2, .tHttp2, .tFault2)
        Do $$$AssertStatusOK(tSC, "the agent's disable of " _ tName _ " mints")
        If $$$ISOK(tSC) {
            Set tSC = ..ConfirmKey(tProposal2.%Get("proposalId"), .tStatus2, .tBody2)
            Do $$$AssertStatusOK(tSC, "the confirm of the disable of " _ tName _ " is sent")
            Do ..AssertRefused("the agent's confirmed disable of " _ tName, tName, tBefore, tStatus2, tBody2)
        }

        Set tSC = ..MintFor(..#UPDATETOOL, tTurn, {"Name": (tName), "MatchRoles": [{"MatchRole": "", "TargetRoles": ["%All"]}]}, .tProposal3, .tHttp3, .tFault3)
        Do $$$AssertStatusOK(tSC, "the agent's MatchRoles change of " _ tName _ " mints: the arm answers at the confirm, as for a disable")
        If $$$ISOK(tSC) {
            Set tSC = ..ConfirmKey(tProposal3.%Get("proposalId"), .tStatus3, .tBody3)
            Do $$$AssertStatusOK(tSC, "the confirm of the MatchRoles change of " _ tName _ " is sent")
            Do ..AssertRefused("the agent's confirmed MatchRoles change of " _ tName, tName, tBefore, tStatus3, tBody3)
        }
    }
}

/// <p>Stores one delete proposal of <var>pName</var> over the turn <var>pTurn</var>, the row a mint stored before the arm
/// refused the delete at the mint; its confirm is what the caller asserts.</p>
ClassMethod SeedDelete(pName As %String, pTurn As %String, Output pKey As %String) As %Status
{
    Do ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", pName, .tTargetRef)
    Kill tValues
    Set tValues("user") = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tValues("convKey") = ""
    Set tValues("turnKey") = pTurn
    Set tValues("toolName") = $Parameter(..#DELETETOOL, "TOOLNAME")
    Set tValues("targetRef") = tTargetRef
    Set tValues("fingerprint") = "0"
    Set tValues("arguments") = {"Name": (pName)}.%ToJSON()
    Set tValues("payload") = "{}"
    Set tValues("diff") = "[]"
    Set tValues("unchangedCount") = 0
    Quit ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .pKey, .tToken)
}

/// <p>One proposal of <var>pToolClass</var> over the turn <var>pTurn</var> with <var>pArgs</var>, minted the way the agent's
/// dispatch mints it: the id is the argument <code>Name</code>.</p>
ClassMethod MintFor(pToolClass As %String, pTurn As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tName = pArgs.%Get("Name")
    Quit $ClassMethod($ClassMethod(pToolClass, "MintClass"), "Mint", ..#SCREEN, $Parameter(pToolClass, "TOOLNAME"), ##class(OcuPilot.Test.Http).GetTestUsername(), "", pTurn, pArgs, ..#LIMITS, .pProposal, .pHttp, .pFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), tName, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
}

}
