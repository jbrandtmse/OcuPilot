/// <p>Pins Story 24.17 Batch 3a's reads (AD-5, AD-29, AD-36, AD-62): the Workflow users list, the one-user read and the user choices, through the port, the screen's read route and the agent's
/// read tool, which answer the same rows; the lists' caps and one over; the instance users the choices offer; and that a read writes nothing. The probes are
/// <code>EnsLib.Workflow.UserDefinition</code> rows in <code>USER</code>, saved through the vendor's own calls.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs; the test account lists every instance user, as an administrator does.</p>
Class OcuPilot.Test.InteropWorkflowUserList Extends OcuPilot.Test.InteropWorkflowCase
{

/// <p>The probe users and the two probe roles.</p>
Parameter USERA = "OcuP2417wLa";

Parameter USERB = "OcuP2417wLb";

Parameter USERC = "OcuP2417wLc";

Parameter ROLEA = "OcuP2417wRa";

Parameter ROLEB = "OcuP2417wRb";

/// <p>Store three probe users in <code>USER</code>: an active one with a full name, an inactive one with none, and an active one in both probe roles.</p>
ClassMethod Arrange() As %Status
{
    Set tFx = ..#FIXTURE
    Set tSC = $ClassMethod(tFx, "ProbeUser", ..#USERA, "Ada Lovelace", 1)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeUser", ..#USERB, "", 0))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeUser", ..#USERC, "Cy Young", 1))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeRole", ..#ROLEA))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeRole", ..#ROLEB))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeMember", ..#ROLEA, ..#USERC))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeMember", ..#ROLEB, ..#USERC))
    Quit tSC
}

/// <p>The screen is declared as the plan places it: in the Interoperability area at side bar 25 with the user's name as its key, New workflow user as its primary action and Edit and Remove as its row
/// actions, over <code>%Ens_WorkflowConfig:READ</code>, naming the entity type <code>interop-workflow-user</code> and the classic page it replaces, and declaring no secret.</p>
/// <p>Mutation (Rule 19): change the screen's <code>sideBarPosition</code> to 24 -- this goes red.</p>
Method TestTheDeclarationRegisters()
{
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropWorkflowUserList).DeclarationJson(.tDeclaration)
    Do $$$AssertStatusOK(tSC, "the screen declares JSON")
    If '$IsObject($Get(tDeclaration)) Quit
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.area, "interoperability/workflow-users|25|list|interoperability", "its route, place, archetype and area")
    Do $$$AssertEquals(tDeclaration.entityType _ "|" _ tDeclaration.id.kind _ "|" _ tDeclaration.id.parts.%ToJSON() _ "|" _ tDeclaration.toolIdentifier, "interop-workflow-user|composite|[""Name""]|interop.workflowusers", "its entity type, its key and its tool identifier")
    Do $$$AssertEquals(tDeclaration.primaryAction.id _ "|" _ tDeclaration.rowActions.%Get(0).id _ "," _ tDeclaration.rowActions.%Get(1).id, "add|edit,remove", "its actions")
    Do $$$AssertEquals(tDeclaration.classicPage _ "|" _ tDeclaration.context.secretFields.%ToJSON(), "EnsPortal.WFUsers|[]", "its classic page and no secret field")
    Do $$$AssertEquals(tDeclaration.privileges.%ToJSON(), "[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_WorkflowConfig"",""permission"":""READ""}]", "its pairs are the classic page's")
    Do $$$AssertTrue($ListFind($ClassMethod(..#PORT, "Endpoints"), ..#ENDPOINT) > 0, "the port serves the endpoint")
}

/// <p>AC1: the list answers every probe of the namespace by name, with its full name, active state and the count of the roles it belongs to, and the namespace; the user choices stay out of it;
/// another namespace's users are not listed; and the one-user read answers the same fields for the exact name and 404 for any other spelling.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListWorkflowUsers</method> read <code>Roles</code> as 0 -- this goes red.</p>
Method TestTheListAnswersEveryProbeByNameWithItsFacts()
{
    Do $$$AssertStatusOK(..Arrange(), "three probe users and two roles are stored")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeUser", "OcuP2417wLz", "Zed", 1, ..#OTHER), "and one in HSCUSTOM alone")
    Kill tQuery
    Set tVerdict = ..Verdict("LIST", .tRows, .tFault, .tQuery)
    Do $$$AssertEquals(tVerdict, "200 ", "the list answers 200")
    Do $$$AssertEquals(..Names(tRows), ..#USERA _ "," _ ..#USERB _ "," _ ..#USERC, "exactly the probes of USER, by name")
    If '$IsObject($Get(tRows)) Quit
    Set tText = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ tRow.FullName _ "|" _ tRow.IsActive _ "|" _ tRow.Roles _ "|" _ tRow.Namespace _ ";"
    }
    Do $$$AssertEquals(tText, "Ada Lovelace|1|0|USER;|0|0|USER;Cy Young|1|2|USER;", "each row carries its full name, active state, role count and namespace")
    Kill tQuery
    Do $$$AssertEquals(..Verdict("LIST", .tOther, .tFault, .tQuery, "", ..#OTHER), "200 ", "HSCUSTOM's list answers 200")
    Do $$$AssertEquals(..Names(tOther), "OcuP2417wLz", "and holds its own probe alone")
    Set tOne = ..Read(..#USERC, "", .tRow, .tFault)
    Do $$$AssertEquals(tOne _ "|" _ tRow.Name _ "|" _ tRow.FullName _ "|" _ tRow.IsActive _ "|" _ tRow.Roles _ "|" _ tRow.Namespace, "200 |" _ ..#USERC _ "|Cy Young|1|2|USER", "the one-user read answers the same fields")
    Do $$$AssertEquals(..Read($ZConvert(..#USERC, "L"), "", .tRow, .tFault), "404 PORT.NOTFOUND", "a name in another letter case is not held")
    Do $$$AssertEquals(..Read("OcuP2417wNobody", "", .tRow, .tFault), "404 PORT.NOTFOUND", "and a name no one holds")
}

/// <p>AC1: the screen's read route and the agent's read tool answer the rows the port answers, in the fields the screen declares.</p>
/// <p>Mutation (Rule 19): rename the <code>FullName</code> field in <class>OcuPilot.Screen.Descriptor.InteropWorkflowUserList</class>'s read -- the route and the tool answer no full name and this
/// goes red.</p>
Method TestTheReadRouteAndTheReadToolAnswerTheSameRows()
{
    Do $$$AssertStatusOK(..Arrange(), "three probe users are stored")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#SOURCE)
    Kill tQuery
    Do ..Verdict("LIST", .tPortRows, .tPortFault, .tQuery)
    Set tClass = "OcuPilot.Screen.Descriptor.InteropWorkflowUserList"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(tClass, 1000, .tAnswer, .tRouteHttp, .tRouteFault, .tCriteria)
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($ClassMethod(tClass, "ToolIdentifier") _ ".read", .tTool)
    Do $$$AssertTrue($IsObject($Get(tTool)), "interop.workflowusers.read is a registered read tool")
    Set tToolHttp = 0
    If $IsObject($Get(tTool)) Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 1000, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertEquals(tRouteHttp _ "|" _ tToolHttp, "200|200", "the route and the tool answer")
    If '$IsObject($Get(tPortRows)) || '$IsObject($Get(tAnswer)) || '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tPortRows.%Size(), 3, "the port answers the three probes")
    Set tCanon = ..Canon(tPortRows)
    Do $$$AssertEquals(..Canon(tAnswer.rows), tCanon, "the route's rows are the port's")
    Do $$$AssertEquals(..Canon(tResult.rows), tCanon, "and so are the tool's")
}

/// <p><var>pRows</var> reduced to the four declared fields, one line for each row, in order.</p>
ClassMethod Canon(pRows As %DynamicArray) As %String
{
    Set tText = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ tRow.Name _ "=" _ tRow.FullName _ "=" _ tRow.IsActive _ "=" _ tRow.Roles _ $Char(10)
    }
    Quit tText
}

/// <p>AC1: both lists are cut at a named limit when the caller names no cap, and truncation is the caller's to read from the row it asks for beyond its own cap: three users at the limit of three
/// are all listed, a fourth one over answers the limit, a caller that asks for one row beyond a cap is answered it, and one that asks for fewer gets fewer; the user choices, which the instance holds
/// more than three of, answer the limit. The shipped limits are 10,000 each, measured.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowCap</method> answer no more than <var>pLimit</var> -- the row asked for beyond the cap is lost and this goes red.</p>
Method TestTheListAndTheChoicesStopAtTheirNamedLimit()
{
    Set tCap = ..#CAPSEAM
    Do $$$AssertEquals($Parameter(..#PORT, "WORKFLOWUSERSMAX") _ "|" _ $Parameter(..#PORT, "WORKFLOWUSERCHOICESMAX"), "10000|10000", "the shipped limits are 10,000 users and 10,000 choices")
    Do $$$AssertEquals($Parameter(tCap, "WORKFLOWUSERSMAX") _ "|" _ $Parameter(tCap, "WORKFLOWUSERCHOICESMAX"), "3|3", "the seam lowers both to three")
    Set tFx = ..#FIXTURE
    For tI = 1:1:3 {
        Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", "OcuP2417wC" _ tI, "user " _ tI), "probe user " _ tI _ " is stored")
    }
    Kill tQuery
    Do ..Verdict("LIST", .tAt, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals(..Names(tAt), "OcuP2417wC1,OcuP2417wC2,OcuP2417wC3", "three users at the limit: all three")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", "OcuP2417wC4", "user 4"), "a fourth is stored")
    Kill tQuery
    Do ..Verdict("LIST", .tOver, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals(..Names(tOver), "OcuP2417wC1,OcuP2417wC2,OcuP2417wC3", "four users, one over: the limit, the first three by name")
    Kill tQuery
    Set tQuery("maxRows") = 4
    Do ..Verdict("LIST", .tAsked, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tAsked)): tAsked.%Size(), 1: -1), 4, "a caller whose cap is the limit asks for one row more and is answered it, so it reads the truncation")
    Kill tQuery
    Set tQuery("maxRows") = 2
    Do ..Verdict("LIST", .tFewer, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tFewer)): tFewer.%Size(), 1: -1), 2, "and one that asks for fewer gets fewer")
    Kill tQuery
    Do ..Verdict("WORKFLOWUSERCHOICES", .tChoices, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tChoices)): tChoices.%Size(), 1: -1), 3, "the choices, which the instance holds more than three of, stop at the limit")
    Kill tQuery
    Do ..Verdict("WORKFLOWUSERCHOICES", .tAll, .tFault, .tQuery)
    Set tTotal = $Select($IsObject($Get(tAll)): tAll.%Size(), 1: -1)
    Do $$$AssertTrue(tTotal > 3, "the instance offers more than three users: " _ tTotal)
    Kill tQuery
    Set tQuery("maxRows") = tTotal
    Do ..Verdict("WORKFLOWUSERCHOICES", .tExact, .tFault, .tQuery)
    Do $$$AssertEquals($Select($IsObject($Get(tExact)): tExact.%Size(), 1: -1), tTotal, "a caller whose cap equals the count is answered every user")
    Kill tQuery
    Set tQuery("maxRows") = tTotal - 1
    Do ..Verdict("WORKFLOWUSERCHOICES", .tShort, .tFault, .tQuery)
    Do $$$AssertEquals($Select($IsObject($Get(tShort)): tShort.%Size(), 1: -1), tTotal - 1, "and one cap below it is answered that many")
    Kill tQuery
    Set tQuery("maxRows") = "0"
    Do $$$AssertEquals(..Verdict("LIST", .tBad, .tFault, .tQuery), "400 PORT.VALIDATION", "a cap that is not a whole number above zero is refused by name")
}

/// <p>AC1: the user choices are the users of the instance as the classic Name selector lists them, spelled as the instance holds them, and the same in every namespace: a probe instance user is
/// offered whether or not it is a workflow user, the five names the selector leaves out are not offered, and each row names the namespace asked. Reading the list, one user and the choices writes
/// no node of the workflow globals and no data document timestamp.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListWorkflowChoices</method> read the users of the other namespace -- the namespace leg goes red; make it read
/// <code>Security.Users</code> directly -- the left-out names are offered and this goes red.</p>
Method TestTheChoicesAreTheInstancesUsersTheClassicSelectorOffersAndReadingWritesNothing()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFx, "InstanceUser", "OcuP2417wChoiceA"), "an instance user that is no workflow user is created")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", "OcuP2417wChoiceB", "Bea"), "and one that is")
    Set tBefore = ..Footprint(..#SOURCE, .tStamp) _ "/" _ ..Footprint(..#OTHER)
    Do $$$AssertTrue(tStamp '= "", "the probe's save set the data document's timestamp, so that half of the snapshot can move")
    Do $$$AssertTrue($Piece(tBefore, "|", 1) > 0, "and the workflow globals hold the probe's nodes: " _ tBefore)
    Kill tQuery
    Set tVerdict = ..Verdict("WORKFLOWUSERCHOICES", .tRows, .tFault, .tQuery)
    Do $$$AssertEquals(tVerdict, "200 ", "the choices answer 200")
    Set tNames = "," _ ..Names(tRows) _ ","
    Do $$$AssertTrue((tNames [ ",OcuP2417wChoiceA,") && (tNames [ ",OcuP2417wChoiceB,"), "both probe instance users are offered, spelled as the instance holds them: " _ tNames)
    Do $$$AssertTrue((tNames '[ ",_SYSTEM,") && (tNames '[ ",_PUBLIC,") && (tNames '[ ",_Ensemble,") && (tNames '[ ",CSPSystem,") && (tNames '[ ",UnknownUser,"), "the five names the classic selector leaves out are not offered")
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Get(0).Namespace, 1: ""), ..#SOURCE, "each row names the namespace asked")
    Kill tQuery
    Do ..Verdict("WORKFLOWUSERCHOICES", .tOther, .tFault, .tQuery, "", ..#OTHER)
    Do $$$AssertEquals("," _ ..Names(tOther) _ ",", tNames, "HSCUSTOM is offered the same users")
    Kill tQuery
    Do ..Verdict("LIST", .tList, .tFault, .tQuery)
    Do ..Read("OcuP2417wChoiceB", "", .tRow, .tFault)
    Do $$$AssertEquals(..Footprint(..#SOURCE) _ "/" _ ..Footprint(..#OTHER), tBefore, "no read wrote a node of the workflow globals or the data document's timestamp")
}

/// <p>What <var>pNamespace</var> holds that a workflow user write would change, as <code>nodes|digest</code>: every node of the user, role, membership and worklist data and index globals, and the
/// timestamp of the user data document in <var>pStamp</var>, which is part of the digest. <code>&lt;unreadable&gt;</code> when it cannot be read.</p>
ClassMethod Footprint(pNamespace As %String, Output pStamp As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set pStamp = ""
    Set tNodes = 0
    Set tText = ""
    Set tRead = 0
    Try {
        Set $NAMESPACE = pNamespace
        For tRoot = "^EnsLib.W.UserDefinitionD", "^EnsLib.W.UserDefinitionI", "^EnsLib.W.RoleDefinitionD", "^EnsLib.W.RoleDefinitionI", "^EnsLib.W.RoleMembershipD", "^EnsLib.W.RoleMembershipI", "^EnsLib.W.WorklistD", "^EnsLib.W.WorklistI" {
            Set tText = tText _ tRoot _ "=" _ $Select($Data(@tRoot) # 2: $Get(@tRoot), 1: "<none>") _ $Char(10)
            Set tNode = $Query(@tRoot)
            While tNode '= "" {
                Set tNodes = tNodes + 1
                Set tText = tText _ tNode _ "=" _ @tNode _ $Char(10)
                Set tNode = $Query(@tNode)
            }
        }
        Set pStamp = $Get(^Ens.Configuration("sdd", "EnsLib.Workflow.UserDefinition", "time"))
        Set tText = tText _ pStamp
        Set $NAMESPACE = tOrigNS
        Set tRead = 1
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    If 'tRead Quit "<unreadable>"
    Quit tNodes _ "|" _ $System.Encryption.Base64Encode($System.Encryption.SHA1Hash(tText))
}

}
