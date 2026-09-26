/// <p>Pins the read-back over real HTTP requests against real instance objects (AD-58, Story
/// 16.17): a web application Save and a row action answer <code>matches</code>, a row action's
/// delete answers <code>notFound</code>, and an agent's confirmed role update whose
/// <code>GrantedRoles</code> the vendor sorts and whose <code>"WR"</code> grant it stores
/// <code>"RW"</code> answers <code>matches</code> through the declared modes, on the confirm's
/// answer and on the proposal's wire row.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the suite's HTTP
/// account holding <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because it creates and deletes two web applications and one role by exact name.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not.</p>
Class OcuPilot.Test.ReadBackRoute Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter APIBASE = "/api/ocupilot";

Parameter WEBAPPACTIONPATH = "/screens/webapp.list/action";

/// <p>The application the Save and the row action edit.</p>
Parameter PROBEAPP = "/csp/ocupilotprobereadback";

/// <p>The application the row action deletes.</p>
Parameter DOOMEDAPP = "/csp/ocupilotprobereadbackdelete";

/// <p>The description the probe applications are created with, which is how they are recognised
/// as this class's own before they are deleted.</p>
Parameter PROBEMARKER = "OcuPilot read-back probe";

/// <p>The role the agent's confirmed update edits.</p>
Parameter PROBEROLE = "OcuPilotProbeReadBackRole";

Parameter ROLETOOL = "OcuPilot.Screen.Tool.RoleUpdate";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ReadBackRoute creates and deletes web applications and a role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.WebAppSave).EnsureApp(..#PROBEAPP, ..#PROBEMARKER, ..AppBody())
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.WebAppSave).EnsureApp(..#DOOMEDAPP, ..#PROBEMARKER, ..AppBody())
    If $$$ISOK(tSC) Set tSC = ..EnsureRole()
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.WebAppSave).RemoveApp(..#PROBEAPP, ..#PROBEMARKER)
    Set tDoomedSC = ##class(OcuPilot.Test.WebAppSave).RemoveApp(..#DOOMEDAPP, ..#PROBEMARKER)
    Set tRoleSC = ..RemoveRole()
    Set tSeededSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    If $$$ISERR(tSC) Quit tSC
    If $$$ISERR(tDoomedSC) Quit tDoomedSC
    If $$$ISERR(tRoleSC) Quit tRoleSC
    Quit tSeededSC
}

/// <p>AD-58 over the editor's Save: <code>Timeout</code> sent as <code>"0900"</code> and a new
/// description read back as sent, so the answer carries <code>matches</code> beside the name.</p>
/// <p>Mutation (Rule 19): drop the <code>readBack</code> member from
/// <method>OcuPilot.Area.WebApp.WebAppSave.HandleUpdate</method>'s answer -- this goes red.</p>
Method TestAWebApplicationSaveReadsBackMatches()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/web-applications/" _ ##class(OcuPilot.Kernel.EntityId).Encode(..#PROBEAPP), .tStatus, .tBody, {"Description": (..#PROBEMARKER _ " saved"), "Timeout": "0900"}.%ToJSON(), "application/json")
    Do $$$AssertStatusOK(tSC, "the Save completes")
    Do $$$AssertEquals(tStatus, 200, "at 200: " _ $Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: ""))
    Set tReadBack = ..ReadBackOf(.tBody)
    Do $$$AssertEquals(tReadBack.%Get("verdict"), "matches", "the application reads back as saved: " _ tReadBack.%ToJSON())
    Do $$$AssertEquals(tReadBack.%Get("fields").%Size(), 0, "with no field differing")
}

/// <p>AD-58 over a row action, the screen's own caller of the one operation (AD-53): disabling the
/// application reads back <code>matches</code>, and deleting the other reads back
/// <code>notFound</code>, the expected result.</p>
/// <p>Mutation (Rule 19): drop <code>readBack</code> from
/// <method>OcuPilot.Api.ScreenAction.Run</method>'s answer -- both legs go red.</p>
Method TestARowActionReadsBackMatchesAndADeleteNotFound()
{
    Set tSC = ..Action("disable", ..#PROBEAPP, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the disable answers 200: " _ $Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: ""))
    Set tReadBack = ..ReadBackOf(.tBody)
    Do $$$AssertEquals(tReadBack.%Get("verdict"), "matches", "the disabled application reads back as sent: " _ tReadBack.%ToJSON())

    Set tSC = ..Action("delete", ..#DOOMEDAPP, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the delete answers 200: " _ $Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: ""))
    Set tReadBack = ..ReadBackOf(.tBody)
    Do $$$AssertEquals(tReadBack.%Get("verdict"), "notFound", "the deleted application reads back not found: " _ tReadBack.%ToJSON())
    Do $$$AssertTrue('##class(OcuPilot.Test.WebAppWire).Exists(..#DOOMEDAPP), "and it is gone")
}

/// <p>AD-58 over the agent's confirm: a role update whose <code>GrantedRoles</code> and
/// <code>Resources</code> are sent in reverse name order, which the vendor stores sorted, with a
/// grant sent <code>"WR"</code>, which it stores <code>"RW"</code>, reads back <code>matches</code>
/// because <code>permissions.roles.update</code> declares both fields <code>unordered</code> and
/// <code>Resources[].Permissions</code> <code>letters</code>. The confirm's answer carries it, and so
/// does the proposal's wire row afterwards.</p>
/// <p>Mutation (Rule 19): remove <code>GrantedRoles</code> from the entry's <code>compare</code> in
/// <class>OcuPilot.Screen.Tool.Classification</class> and regenerate -- this reads
/// <code>differs</code> and goes red.</p>
Method TestAConfirmedRoleUpdateReadsBackAReorderedListAsMatching()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "completed", .tTurn), "a completed turn is seeded")
    Set tTool = ..#ROLETOOL
    Set tArgs = {"Name": (..#PROBEROLE), "GrantedRoles": ["%Operator", "%Developer"], "Resources": [{"Name": "%Development", "Permissions": "U"}, {"Name": "%DB_USER", "Permissions": "WR"}]}
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(tTool, "DESCRIPTORCLASS"), $Parameter(tTool, "TOOLNAME"), tUser, "", tTurn, tArgs, "OcuPilot.Kernel.Agent.Limits", .tProposal, .tHttp, .tFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), ..#PROBEROLE, $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
    Do $$$AssertStatusOK(tSC, "the role update is minted: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tKey = tProposal.%Get("proposalId")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#APIBASE _ "/proposal/" _ tKey _ "/confirm", tUser, ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tText, .tHeaders, "", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the confirm answers 200: " _ $Extract($Get(tText), 1, 300))
    Set tBody = ""
    Try {
        Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tText)
    } Catch {
        Set tBody = ""
    }
    Set tReadBack = ..ReadBackOf(.tBody)
    Do $$$AssertEquals(tReadBack.%Get("verdict"), "matches", "the sorted GrantedRoles and the RW grant read back as sent: " _ tReadBack.%ToJSON())
    Do $$$AssertEquals(..Granted(), "%Developer,%Operator", "which the instance holds sorted")
    Do $$$AssertEquals(..Granted("Resources"), "%DB_USER:RW,%Development:U", "and the database grant as RW")

    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurn, tUser, .tRows)
    Set tWire = $Select($IsObject($Get(tRows)) && (tRows.%Size() > 0): tRows.%Get(0).%Get("readBack"), 1: "")
    Do $$$AssertTrue($IsObject(tWire), "the proposal's wire row carries the read-back")
    If $IsObject(tWire) Do $$$AssertEquals(tWire.%ToJSON(), tReadBack.%ToJSON(), "the same one the confirm answered")
}

/// <p><var>pBody</var>'s <code>readBack</code>, or an empty object when it carries none.</p>
ClassMethod ReadBackOf(ByRef pBody) As %DynamicObject
{
    If $IsObject($Get(pBody)) && pBody.%IsA("%Library.DynamicObject") && (pBody.%GetTypeOf("readBack") = "object") Quit pBody.%Get("readBack")
    Quit {"verdict": "", "fields": [], "written": []}
}

/// <p>Send row action <var>pAction</var> for <var>pId</var> on the web applications list.</p>
ClassMethod Action(pAction As %String, pId As %String, Output pStatus As %Integer, Output pBody) As %Status
{
    Quit ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#WEBAPPACTIONPATH, .pStatus, .pBody, {"action": (pAction), "id": (pId)}.%ToJSON(), "application/json")
}

/// <p>A probe application's creation body.</p>
ClassMethod AppBody() As %DynamicObject
{
    Quit {"NameSpace": ($Namespace), "Description": (..#PROBEMARKER), "AutheEnabled": 32, "Enabled": true, "Timeout": 900}
}

/// <p>The probe role's granted roles as the instance holds them, comma-joined.</p>
ClassMethod Granted(pProperty As %String = "GrantedRoles") As %String
{
    Set tGranted = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If $$$ISOK(##class(Security.Roles).Get(..#PROBEROLE, .tProps)) Set tGranted = $Get(tProps(pProperty))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tGranted
}

/// <p>Create <parameter>PROBEROLE</parameter> afresh, granting <code>%Developer</code>.</p>
ClassMethod EnsureRole() As %Status
{
    Set tSC = ..RemoveRole()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Roles).Create(..#PROBEROLE, ..#PROBEMARKER, "", "%Developer")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete <parameter>PROBEROLE</parameter> when its description is this class's marker; a role
/// of that name that is anybody else's is an error and is left alone.</p>
ClassMethod RemoveRole() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Roles).Exists(..#PROBEROLE) {
            Set tSC = ##class(Security.Roles).Get(..#PROBEROLE, .tProps)
            If $$$ISOK(tSC) && ($Get(tProps("Description")) '= ..#PROBEMARKER) Set tSC = $$$ERROR($$$GeneralError, "the role " _ ..#PROBEROLE _ " is not this suite's own, so it was left alone")
            If $$$ISOK(tSC) Set tSC = ##class(Security.Roles).Delete(..#PROBEROLE)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
