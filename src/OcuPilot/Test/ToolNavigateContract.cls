/// <p>The literal contract of <code>shell.screen.open</code>'s two id arguments (AD-5, AD-13,
/// DW-1462): which screens take <code>parentId</code>, which refuse both arguments, and the
/// model-read wording the owner ruled. <class>OcuPilot.Test.ToolNavigate</class>'s sweep derives its
/// partition from the registry's declarations, so a declaration that moves moves the sweep with it;
/// the rosters here are written out and do not move.</p>
/// <p>Live-safe: reads the real descriptor registry and the advertised tool set, writes nothing and
/// needs no arming variable.</p>
Class OcuPilot.Test.ToolNavigateContract Extends %UnitTest.TestCase
{

Parameter TOOL = "OcuPilot.Screen.Tool.Navigate";

/// <p>The screens that were refused an id while their own id was read in place of their parent's,
/// and take <code>parentId</code> now. Each has a parent whose id is one part and an own id of
/// more than one.</p>
Parameter NEWLYOPENABLE = "tasks/schedule/history,analytics/term-lists/entries,interoperability/lookup-tables/entries,interoperability/productions/items,web-applications/routine-applications/routines,os-management/namespaces/global-mappings,os-management/namespaces/package-mappings,os-management/namespaces/routine-mappings";

/// <p>The screens whose parent's id is two parts, so no id the model supplies can name them: the
/// four item tabs, which took a model-composed two-part parent id as <code>entityId</code>, and the
/// items' own settings, document and test screens.</p>
Parameter PARENTIDTWOPARTS = "interoperability/productions/items/jobs,interoperability/productions/items/log,interoperability/productions/items/messages,interoperability/productions/items/queue,interoperability/productions/items/settings,interoperability/productions/items/document,interoperability/productions/items/test";

/// <p>The ruled wording, owner-kept (U-7): a change here is a deliberate edit of the model-read text,
/// never a drive-by.</p>
Parameter DESCRIPTION = "Open a screen for the user: optionally select one of its rows by the row's id, or open a screen that belongs to one item (such as a task's history) for that item. Announces the move before it happens, then waits about a second before the browser moves; the departing screen may refuse the move (for example, unsaved changes), and the user may always return with Back.";

Parameter ENTITYIDTEXT = "The row to select, once resolved from the row's own identifying value, on a screen of its own rows. Refused on a screen that belongs to an item (send parentId there), and on a screen whose id is none or has more than one part.";

Parameter PARENTIDTEXT = "The item a screen belongs to, by that item's own identifying value: a task's id for its history or details, a database's directory for its volumes. Accepted only on a screen that belongs to an item, and refused where that item's id is none or has more than one part.";

Parameter RESULTPARENTIDTEXT = "The item the screen was opened for, when one was.";

Parameter REFUSALTEXT = "This screen cannot be opened on that item.";

/// <p>Each of the eight screens that became openable for their parent takes <code>parentId</code>
/// and answers it as the parent, and refuses <code>entityId</code> naming it.</p>
/// <p>Mutation (Rule 19): make a parent screen's declared id two parts, so the derived sweep follows
/// it and stays green -- this goes red on that parent's child.</p>
Method TestTheEightScreensOpenableForTheirParentTakeParentId()
{
    Set tRoutes = $ListFromString(..#NEWLYOPENABLE, ",")
    Do $$$AssertEquals($ListLength(tRoutes), 8, "the roster names eight screens")
    For tI = 1:1:$ListLength(tRoutes) {
        Set tRoute = $List(tRoutes, tI)
        Set tDescriptor = ##class(OcuPilot.Screen.Registry).DescriptorForRoute(tRoute)
        Do $$$AssertNotEquals(tDescriptor, "", tRoute _ " is a built screen")
        If tDescriptor = "" Continue
        Set tParentRoute = $ClassMethod(tDescriptor, "ParentScope")
        Do $$$AssertNotEquals(tParentRoute, "", tRoute _ " belongs to a parent screen")
        Do $$$AssertTrue($ListLength($ClassMethod(tDescriptor, "IdParts")) > 1, tRoute _ "'s own id is more than one part, so only its parent's id can name it")

        Set tSC = ##class(OcuPilot.Test.ToolNavigateParent).Ask({"route": (tRoute), "parentId": "1"}, .tOut, .tEntity, .tParent, .tFault)
        Do $$$AssertStatusOK(tSC, tRoute _ " accepts a parentId")
        Do $$$AssertEquals(tOut _ "|" _ tEntity _ "|" _ tParent, tRoute _ "||1", tRoute _ " answers it as the parent, no row")

        Set tSC2 = ##class(OcuPilot.Test.ToolNavigateParent).Ask({"route": (tRoute), "entityId": "1"}, .tOut2, .tEntity2, .tParent2, .tFault2)
        Do $$$AssertStatusNotOK(tSC2, tRoute _ " refuses an entityId")
        Do $$$AssertEquals($Select($IsObject(tFault2): tFault2.code _ "|" _ tFault2.detail.argument, 1: ""), "NAV.ENTITYNOTALLOWED|entityId", tRoute _ " names the code and the argument")
    }
}

/// <p>Each of the seven screens whose parent's id is two parts refuses both arguments, for an id
/// of one part and for the model-composed two-part spelling alike: the second composite grammar AD-5
/// forbids. The four item tabs took the composed spelling as <code>entityId</code> before.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.Navigate.AcceptsEntityId</method> ignore
/// the parent scope -- this goes red on the four item tabs.</p>
Method TestTheSevenScreensWhoseParentIdIsTwoPartsRefuseBothArguments()
{
    Set tRoutes = $ListFromString(..#PARENTIDTWOPARTS, ",")
    Do $$$AssertEquals($ListLength(tRoutes), 7, "the roster names seven screens")
    For tI = 1:1:$ListLength(tRoutes) {
        Set tRoute = $List(tRoutes, tI)
        Set tDescriptor = ##class(OcuPilot.Screen.Registry).DescriptorForRoute(tRoute)
        Do $$$AssertNotEquals(tDescriptor, "", tRoute _ " is a built screen")
        If tDescriptor = "" Continue
        Set tParent = ##class(OcuPilot.Screen.Registry).DescriptorForRoute($ClassMethod(tDescriptor, "ParentScope"))
        Do $$$AssertEquals($ClassMethod(tParent, "IdKind") _ "/" _ $ListLength($ClassMethod(tParent, "IdParts")), "composite/2", tRoute _ "'s parent's id really has two parts")
        For tArgument = "entityId", "parentId" {
            For tValue = "1", "Prod||Item" {
                Set tArgs = {"route": (tRoute)}
                Do tArgs.%Set(tArgument, tValue, "string")
                Set tSC = ##class(OcuPilot.Test.ToolNavigateParent).Ask(tArgs, .tOut, .tEntity, .tParentOut, .tFault)
                Do $$$AssertStatusNotOK(tSC, tRoute _ " refuses " _ tArgument _ " " _ tValue)
                Do $$$AssertEquals($Select($IsObject(tFault): tFault.code _ "|" _ tFault.detail.argument, 1: ""), "NAV.ENTITYNOTALLOWED|" _ tArgument, tRoute _ " names the code and " _ tArgument)
                Do $$$AssertEquals(tOut _ tEntity _ tParentOut, "", tRoute _ " validates nothing")
            }
        }
    }
}

/// <p>The model reads the ruled wording: the tool's description and the two id arguments' texts as
/// the advertised tool set carries them, the settled result's <code>parentId</code> text, and the
/// sentence a refusal's trace shows. The advertised property text is the ruled text followed by the
/// emitter's length note.</p>
/// <p>Mutation (Rule 19): reword <parameter>OcuPilot.Screen.Tool.Navigate.DESCRIPTION</parameter>,
/// either id argument's text or <parameter>OcuPilot.Api.Error.REASONNAVENTITYNOTALLOWED</parameter>
/// by one word -- the matching assertion goes red.</p>
Method TestTheModelReadTextsAreTheRuledWording()
{
    Set tInput = $ClassMethod(..#TOOL, "InputSchema", "")
    Do $$$AssertEquals(tInput.properties.entityId.description, ..#ENTITYIDTEXT, "entityId's text in the input schema")
    Do $$$AssertEquals(tInput.properties.parentId.description, ..#PARENTIDTEXT, "parentId's text in the input schema")
    Set tResult = $ClassMethod(..#TOOL, "ResultSchema", "")
    Do $$$AssertEquals(tResult.properties.parentId.description, ..#RESULTPARENTIDTEXT, "parentId's text in the result schema")
    Do $$$AssertEquals($Parameter(..#TOOL, "DESCRIPTION"), ..#DESCRIPTION, "the class description")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Agent.Dispatch).Advertise(.tTools), "the tool set advertises")
    Set tFound = 0
    For tI = 1:1:tTools {
        If tTools(tI, "name") '= "shell_screen_open" Continue
        Set tFound = 1
        Do $$$AssertEquals(tTools(tI, "description"), ..#DESCRIPTION, "the advertised description")
        Set tEmitted = ##class(%DynamicAbstractObject).%FromJSON(tTools(tI, "inputSchema"))
        Set tEntityText = tEmitted.properties.entityId.description
        Do $$$AssertEquals($Extract(tEntityText, 1, $Length(..#ENTITYIDTEXT)), ..#ENTITYIDTEXT, "the advertised entityId text begins with the ruled text: " _ tEntityText)
        Set tParentText = tEmitted.properties.parentId.description
        Do $$$AssertEquals($Extract(tParentText, 1, $Length(..#PARENTIDTEXT)), ..#PARENTIDTEXT, "the advertised parentId text begins with the ruled text: " _ tParentText)
    }
    Do $$$AssertTrue(tFound, "shell_screen_open is advertised")

    Do $$$AssertEquals(##class(OcuPilot.Api.Error).#REASONNAVENTITYNOTALLOWED, ..#REFUSALTEXT, "the refusal's sentence")
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForNav("NAV.ENTITYNOTALLOWED"), ..#REFUSALTEXT, "and the vocabulary answers it for the code")
}

}
