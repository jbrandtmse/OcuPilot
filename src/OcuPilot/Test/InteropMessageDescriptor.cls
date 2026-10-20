/// <p>Pins Story 20.9's declarations (and the actions Story 20.31 gave two of them) (AD-5, AD-8, AD-13, AD-29, AD-36, AD-44, AD-62): the three message screens -- the Messages
/// search, and the Header and Contents tabs of one message -- with the values the plan names, the registry's verdict, the port's
/// pairs for each endpoint equal to the screen's, the classic viewer's resource shared with the screen's own pair, and the Queue
/// messages list's link to the message. Story 20.30's Trace tab joins the group as its third member.</p>
/// <p><b>What it needs from the environment:</b> the compiled registries. It reads no message and writes nothing.</p>
Class OcuPilot.Test.InteropMessageDescriptor Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter PREFIX = "OcuPilot.Screen.Descriptor.";

/// <p>The screens, <code>&lt;class&gt;|&lt;route&gt;|&lt;position&gt;|&lt;archetype&gt;|&lt;label key&gt;|&lt;endpoint&gt;|&lt;tool&gt;|&lt;parent&gt;|&lt;tab
/// position&gt;|&lt;tab label key&gt;|&lt;empty key&gt;|&lt;prompt key stem&gt;|&lt;criteria&gt;|&lt;read fields&gt;|&lt;pairs&gt;</code>.</p>
Parameter SCREENS = "InteropMessageList|interoperability/messages|11|list (server criteria)|interopItemTabMessages|Messages|interop.messages||||interopMessagesEmpty|interopMessagesPrompt|beginDateTime,endDateTime,status,type,source,target,bodyClass,session,errors|ID,TimeCreated,Status,Type,Source,Target,BodyClass,SessionId,Error|%Ens_Portal:USE,%Ens_MessageHeader:USE;InteropMessageHeaderTab|interoperability/messages/document|0|detail|logViewerColumnMessage|MessageHeader|interop.messageheader|interoperability/messages|1|interopMessageTabHeader|interopMessageHeaderEmpty|interopMessageHeaderPrompt|message|Message,Position,Name,Value|%Ens_Portal:USE,%Ens_MessageHeader:USE;InteropMessageContentsTab|interoperability/messages/contents|0|detail|interopMessageContentsLabel|MessageContents|interop.messagecontents|interoperability/messages|2|interopMessageTabContents|interopMessageContentsEmpty|interopMessageContentsPrompt|message|Message,Line,Text|%Ens_Portal:USE,%Ens_MessageHeader:USE,%Ens_MessageContent:USE";

/// <p>The classic page all three screens replace.</p>
Parameter CLASSICPAGE = "EnsPortal.MessageViewer";

/// <p>The three declarations carry the values <parameter>SCREENS</parameter> names: route, side-bar position, archetype, labels,
/// the interoperability port's endpoint, tool identifier, parent and tab, empty state, three prompts, criteria in order, read fields,
/// the pairs and the classic page; the tabs share the group <code>interoperability/messages/document</code> and its one criterion; and
/// the registry validates every descriptor and each declaration.</p>
/// <p>Mutation (Rule 19): point the list's read at <code>ItemMessages</code> -- the endpoint leg goes red; drop
/// <code>%Ens_MessageContent:USE</code> from the Contents tab and from the port's <code>Pairs</code> -- the pairs legs go red.</p>
Method TestTheThreeDeclarationsRegister()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the registry validates every descriptor: " _ $Get(tProblem))
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tList)
    Do $$$AssertStatusOK(tSC, "the registry enumerates the descriptors")
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tRow = $Piece(..#SCREENS, ";", tI)
        Set tClass = ..#PREFIX _ $Piece(tRow, "|", 1)
        Do $$$AssertTrue($ListFind(tList, tClass) > 0, tClass _ " is among the registry's descriptors")
        Kill tDeclaration
        Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
        Do $$$AssertStatusOK(tSC, tClass _ " declares JSON")
        If '$IsObject($Get(tDeclaration)) Continue
        Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.labelKey, $Piece(tRow, "|", 2) _ "|" _ $Piece(tRow, "|", 3) _ "|" _ $Piece(tRow, "|", 4) _ "|" _ $Piece(tRow, "|", 5), tClass _ ": route, position, archetype and label")
        Do $$$AssertEquals(tDeclaration.area _ "|" _ tDeclaration.built _ "|" _ tDeclaration.refreshes _ "|" _ tDeclaration.entityType _ "|" _ tDeclaration.scope _ "|" _ tDeclaration.id.kind _ "|" _ tDeclaration.parentScope, "interoperability|1|0|interop-message|namespace|single|" _ $Piece(tRow, "|", 8), tClass _ ": interoperability, built, never refreshing, one message header, namespace-scoped, a single id")
        Do $$$AssertEquals(tDeclaration.read.source.port _ "|" _ tDeclaration.read.source.endpoint _ "|" _ tDeclaration.read.source.type _ "|" _ tDeclaration.toolIdentifier _ "|" _ tDeclaration.classicPage, "interop|" _ $Piece(tRow, "|", 6) _ "|LIST|" _ $Piece(tRow, "|", 7) _ "|" _ ..#CLASSICPAGE, tClass _ ": an interop LIST on its endpoint, its tool and the classic viewer")
        ; Story 20.31: the search resends its checked rows, and the Header tab resends and edits and resends the message it shows.
        Do $$$AssertEquals(tDeclaration.rowActions.%Size() _ "|" _ tDeclaration.primaryAction.id _ "|" _ tDeclaration.commandAliases.%Size(), $Case($Piece(tRow, "|", 1), "InteropMessageList": "1||0", "InteropMessageHeaderTab": "2|resend|0", : "0||0"), tClass _ ": its actions and no command alias")
        Do $$$AssertEquals(tDeclaration.emptyStateKey, $Piece(tRow, "|", 11), tClass _ ": its empty sentence")
        ; The search also offers the resend and trace guided workflows after its three own prompts (Story 20.12).
        Set tPromptCount = $Select($Piece(tRow, "|", 1) = "InteropMessageList": 5, 1: 3)
        Do $$$AssertEquals(tDeclaration.suggestedPrompts.%Size(), tPromptCount, tClass _ ": its suggested prompts, at least three")
        For tJ = 1:1:3 {
            Set tPrompt = tDeclaration.suggestedPrompts.%Get(tJ - 1)
            Do $$$AssertEquals($Select($IsObject(tPrompt): tPrompt.groupKey _ "|" _ tPrompt.textKey, 1: ""), "promptGroupTroubleshooting|" _ $Piece(tRow, "|", 12) _ tJ, tClass _ ": prompt " _ tJ _ " is its own")
        }
        If tPromptCount = 5 {
            Set tResend = tDeclaration.suggestedPrompts.%Get(3)
            Set tTrace = tDeclaration.suggestedPrompts.%Get(4)
            Do $$$AssertEquals(tResend.groupKey _ "|" _ tResend.textKey _ "|" _ tResend.workflow, "promptGroupTroubleshooting|interopMessagesWorkflowResend|resendmessages", tClass _ ": the fourth prompt starts the resend workflow")
            Do $$$AssertEquals(tTrace.groupKey _ "|" _ tTrace.textKey _ "|" _ tTrace.workflow, "promptGroupTroubleshooting|interopMessagesWorkflowTrace|tracemessage", tClass _ ": the fifth starts the trace workflow")
        }
        Set tParams = ""
        Set tFields = tDeclaration.read.criteria.fields.%GetIterator()
        While tFields.%GetNext(.tAt, .tField) {
            Set tParams = tParams _ $Select(tParams = "": "", 1: ",") _ tField.param
        }
        Do $$$AssertEquals(tParams, $Piece(tRow, "|", 13), tClass _ ": its criteria, in order")
        Set tReadFields = ""
        Set tFields = tDeclaration.read.fields.%GetIterator()
        While tFields.%GetNext(.tAt, .tField) {
            Set tReadFields = tReadFields _ $Select(tReadFields = "": "", 1: ",") _ tField
        }
        Do $$$AssertEquals(tReadFields, $Piece(tRow, "|", 14), tClass _ ": the fields it reads")
        Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostDescriptor).PairText(tDeclaration.privileges), $Piece(tRow, "|", 15), tClass _ ": its pairs")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tDeclaration), "", tClass _ ": the declaration validates")
        Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool($Piece(tRow, "|", 7)), tClass, tClass _ ": its tool identifier resolves to it")
        If $Piece(tRow, "|", 9) '= "" {
            Do $$$AssertEquals(tDeclaration.tab.group _ "|" _ tDeclaration.tab.position _ "|" _ tDeclaration.tab.labelKey, "interoperability/messages/document|" _ $Piece(tRow, "|", 9) _ "|" _ $Piece(tRow, "|", 10), tClass _ ": its place in the group of the message's tabs")
            Do $$$AssertEquals(tDeclaration.read.criteria.fields.%Get(0).kind _ "|" _ tDeclaration.read.criteria.fields.%Get(0).maxLength, "text|19", tClass _ ": its one criterion is the message's id")
        } Else {
            Do $$$AssertEquals(tDeclaration.%IsDefined("tab"), 0, tClass _ ": the search is no tab")
        }
    }
    Set tSearch = ..Declaration("InteropMessageList")
    Do $$$AssertEquals(tSearch.read.criteria.fields.%Get(0).defaultHoursAgo _ "|" _ tSearch.read.criteria.fields.%Get(0).kind, "24|datetime", "the search opens on the last 24 hours")
    Do $$$AssertEquals(tSearch.read.criteria.fields.%Get(2).options.%Size() _ "|" _ tSearch.read.criteria.fields.%Get(2).options.%Get(7), "9|Error", "its status choice holds the nine words")
    Do $$$AssertEquals(tSearch.read.criteria.fields.%Get(8).options.%Get(0) _ "," _ tSearch.read.criteria.fields.%Get(8).options.%Get(1) _ "|" _ tSearch.read.criteria.fields.%Get(8).labelKey, "yes,no|interopMessagesCriterionErrors", "and the error flag is a yes or no")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("interoperability/messages/document"), ..#PREFIX _ "InteropMessageHeaderTab", "the group's route resolves to the Header tab")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("EnsPortal.MessageViewer.zen"), "EnsPortal.MessageViewer", "the portal's own resolver answers the classic viewer for its page")
}

/// <p>The names of the fields of <var>pArray</var>, comma-separated, in order.</p>
ClassMethod Joined(pArray As %DynamicArray) As %String
{
    Set tText = ""
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tAt, .tValue) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tValue
    }
    Quit tText
}

/// <p>Story 20.30's Trace tab carries the values the plan names -- its route, labels, pairs (the viewer's and the Visual Trace's), the
/// group it joins as the third tab, the read on the interoperability port's MessageTrace endpoint with its one criterion, fields,
/// filter, sort, note and table, its context, its empty sentence (the Header tab's), three prompts and the classic Visual Trace as its
/// page -- the registry validates it, the group reads Header, Contents, Trace in order, the portal's own resolver answers the Visual
/// Trace for its page, and the port's pairs for the endpoint are the descriptor's.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_MessageTrace:USE</code> from the descriptor and from
/// <method>OcuPilot.Port.InteropPort.Pairs</method> -- this goes red, and so does
/// <method>OcuPilot.Test.InteropFloor.TestEveryOpenScreenMatchesItsClassicPage</method>.</p>
Method TestTheTraceTabJoinsTheMessageGroup()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the registry validates every descriptor: " _ $Get(tProblem))
    Set tD = ..Declaration("InteropMessageTraceTab")
    Do $$$AssertTrue($IsObject(tD), "the Trace tab declares JSON")
    If '$IsObject(tD) Quit
    Do $$$AssertEquals(tD.route _ "|" _ tD.labelKey _ "|" _ tD.area _ "|" _ tD.archetype _ "|" _ tD.sideBarPosition, "interoperability/messages/trace|interopMessageTraceLabel|interoperability|detail|0", "route, label, area, archetype and no side-bar position")
    Do $$$AssertEquals(tD.built _ "|" _ tD.refreshes _ "|" _ tD.refreshRates.%Size(), "1|0|0", "built, never refreshing")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostDescriptor).PairText(tD.privileges), "%Ens_Portal:USE,%Ens_MessageHeader:USE,%Ens_MessageTrace:USE", "its pairs are the viewer's and the Visual Trace's")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostDescriptor).PairText(tD.ownPrivileges), "%Ens_MessageHeader:USE,%Ens_MessageTrace:USE", "and its own pairs are the two beyond the area's")
    Do $$$AssertEquals(tD.entityType _ "|" _ tD.scope _ "|" _ tD.id.kind _ "|" _ tD.parentScope, "interop-message|namespace|single|interoperability/messages", "one message header, namespace-scoped, a single id, under Messages")
    Do $$$AssertEquals(tD.read.source.port _ "|" _ tD.read.source.endpoint _ "|" _ tD.read.source.type _ "|" _ tD.toolIdentifier _ "|" _ tD.classicPage, "interop|MessageTrace|LIST|interop.messagetrace|EnsPortal.VisualTrace", "an interop LIST on MessageTrace, its tool and the Visual Trace")
    Do $$$AssertEquals(tD.read.criteria.fields.%Size() _ "|" _ tD.read.criteria.fields.%Get(0).param _ "|" _ tD.read.criteria.fields.%Get(0).kind _ "|" _ tD.read.criteria.fields.%Get(0).maxLength _ "|" _ tD.read.criteria.fields.%Get(0).labelKey, "1|message|text|19|interopColumnId", "one criterion, the message's id")
    Do $$$AssertEquals(tD.read.criteria.fields.%Get(0).hint, "One message, as interop.messages.read answers its ID; the trace is that message's whole session.", "with its hint")
    Do $$$AssertEquals(..Joined(tD.read.fields), "Message,Step,ID,TimeCreated,Type,Status,Source,Target,BodyClass,Error,SessionId", "the fields it reads")
    Do $$$AssertEquals(..Joined(tD.read.filter), "Type,Status,Source,Target,BodyClass", "its filter")
    Do $$$AssertEquals(..Joined(tD.read.sort.fields) _ "|" _ tD.read.sort.default _ "|" _ tD.read.sort.direction _ "|" _ tD.read.paging, "Step|Step|asc|cap", "sorted by step, ascending, capped")
    Do $$$AssertEquals(tD.read.note.key _ "|" _ tD.read.note.text, "interopMessageTraceNote|OcuPilot draws this session's messages. The classic Visual Trace also shows its event, rule and I/O log entries.", "its note states the named limit")
    Set tColumns = ""
    Set tIterator = tD.table.columns.%GetIterator()
    While tIterator.%GetNext(.tAt, .tColumn) {
        Set tColumns = tColumns _ $Select(tColumns = "": "", 1: ",") _ tColumn.field _ ":" _ tColumn.kind _ ":" _ tColumn.labelKey
    }
    Do $$$AssertEquals(tColumns, "ID:name:interopColumnId,TimeCreated:text:journalColumnCreated,Type:text:tableColumnType,Status:status:taskHistoryColumnStatus,Source:text:auditEventFieldSource,Target:text:agentLedgerColumnTarget,BodyClass:identifier:interopColumnBodyClass", "the table a read declares")
    Do $$$AssertEquals(tD.table.emptyNextKey _ "|" _ tD.emptyStateKey, "tableReadOnlyEmptyNext|interopMessageHeaderEmpty", "and the Header tab's empty sentence")
    Do $$$AssertEquals(..Joined(tD.context.fields), "Step,ID,TimeCreated,Type,Status,Source,Target,BodyClass,Error", "its context")
    Do $$$AssertEquals(tD.tab.group _ "|" _ tD.tab.position _ "|" _ tD.tab.labelKey, "interoperability/messages/document|3|interopMessageTabTrace", "the third tab of the message group")
    Do $$$AssertEquals(tD.rowActions.%Size() _ "|" _ tD.primaryAction.id _ "|" _ tD.commandAliases.%Size(), "0||0", "no action and no command alias")
    Do $$$AssertEquals(tD.suggestedPrompts.%Size(), 3, "three suggested prompts")
    For tJ = 1:1:3 {
        Set tPrompt = tD.suggestedPrompts.%Get(tJ - 1)
        Do $$$AssertEquals($Select($IsObject(tPrompt): tPrompt.groupKey _ "|" _ tPrompt.textKey, 1: ""), "promptGroupTroubleshooting|interopMessageTracePrompt" _ tJ, "prompt " _ tJ _ " is its own")
    }
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DeclarationProblem(tD), "", "the declaration validates")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool("interop.messagetrace"), ..#PREFIX _ "InteropMessageTraceTab", "its tool identifier resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("interoperability/messages/trace"), ..#PREFIX _ "InteropMessageTraceTab", "and its route")
    Set tSC = ##class(OcuPilot.Screen.Registry).TabMembersFor(..#PREFIX _ "InteropMessageHeaderTab", .tMembers)
    Do $$$AssertStatusOK(tSC, "the group's members are read from its head")
    Do $$$AssertEquals($ListToString(tMembers), ..#PREFIX _ "InteropMessageContentsTab," _ ..#PREFIX _ "InteropMessageTraceTab", "the group reads Header, Contents, Trace in order")
    Do $$$AssertEquals(##class(%SYS.Portal.Resources).NormalizePage("EnsPortal.VisualTrace.zen"), "EnsPortal.VisualTrace", "the portal's own resolver answers the Visual Trace for its page")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostDescriptor).PairText($ClassMethod(..#PORT, "Pairs", "MessageTrace", "LIST")), ##class(OcuPilot.Test.InteropHostDescriptor).PairText(tD.privileges), "the port's pairs for MessageTrace are the descriptor's")
    Do $$$AssertEquals(+$ClassMethod(..#PORT, "Serves", "MessageTrace", "LIST") _ "|" _ +$ClassMethod(..#PORT, "Serves", "MessageTrace", "SENDTEST"), "1|0", "MessageTrace serves LIST and nothing else")
    Do $$$AssertTrue($ListFind($ClassMethod(..#PORT, "RuntimeEndpoints"), "MessageTrace") > 0, "it is among the port's runtime reads")
}

/// <p>The declaration of the descriptor <var>pShortName</var> in the Screen.Descriptor package.</p>
ClassMethod Declaration(pShortName As %String) As %DynamicObject
{
    Set tSC = $ClassMethod(..#PREFIX _ pShortName, "DeclarationJson", .tDeclaration)
    Quit $Get(tDeclaration)
}

/// <p>The classic viewer's compiled <code>RESOURCE</code> holds a member each screen declares as its own pair, read as the classic
/// portal reads a member (<code>resource[:permission]</code>, <code>USE</code> when none is given), so every role that opens the
/// classic viewer also holds the pair the screen asks (AD-8, AD-44). It is <code>%Ens_MessageHeader:USE</code>, the Operator role's.</p>
/// <p>Mutation (Rule 19): declare <code>%Ens_MessageHeader:READ</code> as the list's own pair -- this goes red naming the viewer.</p>
Method TestTheClassicPageSharesTheScreensPair()
{
    Do $$$AssertTrue(##class(OcuPilot.Test.DeveloperFloor).Compiled(..#CLASSICPAGE), "the classic viewer " _ ..#CLASSICPAGE _ " is compiled")
    Set tResource = ##class(OcuPilot.Test.DeveloperFloor).ClassicResource(..#CLASSICPAGE, .tHasResource)
    Do $$$AssertTrue(tHasResource, ..#CLASSICPAGE _ " compiles a RESOURCE parameter: '" _ tResource _ "'")
    Do $$$AssertEquals(tResource, "%Ens_MessageHeader:USE", "which is the message header resource")
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tClass = ..#PREFIX _ $Piece($Piece(..#SCREENS, ";", tI), "|", 1)
        Set tShared = 0
        For tJ = 1:1:$Length(tResource, ",") {
            Set tMember = $Piece($Piece(tResource, ",", tJ), ":", 1)
            Set tPermission = $Piece($Piece(tResource, ",", tJ), ":", 2)
            If tMember = "" Continue
            If tPermission = "" Set tPermission = "USE"
            If $ListFind($ClassMethod(tClass, "OwnPrivilegePairs"), $ListBuild(tMember, tPermission)) Set tShared = 1
        }
        Do $$$AssertTrue(tShared, tClass _ ": its own pair is a member of the viewer's RESOURCE '" _ tResource _ "'")
    }
}

/// <p>The port's pairs for each endpoint, for <code>LIST</code>, are the pairs the screen on it declares, in order, so the screen
/// and the port gate on the same set (AD-29); the three endpoints are among the port's and the Messages endpoint alone is
/// searchable.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_MessageContent:USE</code> from <method>OcuPilot.Port.InteropPort.Pairs</method>' Contents
/// branch alone -- this goes red; with the descriptor too, <class>OcuPilot.Test.InteropFloor</class> goes red.</p>
Method TestThePortDeclaresEachScreensPairs()
{
    For tI = 1:1:$Length(..#SCREENS, ";") {
        Set tRow = $Piece(..#SCREENS, ";", tI)
        Set tEndpoint = $Piece(tRow, "|", 6)
        Do $$$AssertTrue($ListFind($ClassMethod(..#PORT, "Endpoints"), tEndpoint) > 0, tEndpoint _ " is among the port's endpoints")
        Do $$$AssertTrue($ListFind($ClassMethod(..#PORT, "RuntimeEndpoints"), tEndpoint) > 0, tEndpoint _ " is among its runtime reads")
        Do $$$AssertEquals(+$ClassMethod(..#PORT, "Serves", tEndpoint, "LIST"), 1, tEndpoint _ " serves LIST")
        Do $$$AssertEquals(+$ClassMethod(..#PORT, "Serves", tEndpoint, "SENDTEST"), 0, tEndpoint _ " serves nothing else")
        Do $$$AssertEquals(##class(OcuPilot.Test.InteropHostDescriptor).PairText($ClassMethod(..#PORT, "Pairs", tEndpoint, "LIST")), $Piece(tRow, "|", 15), tEndpoint _ ": the port's pairs are the screen's")
    }
    Do $$$AssertEquals($Parameter(..#PORT, "SEARCHENDPOINTS"), "Messages", "the Messages endpoint alone takes search criteria of its own")
}

/// <p>A Queue messages row's message id opens that message's Header tab: the list declares the <code>rowTarget</code> on
/// <code>MessageId</code>, and its route is a built screen keyed by an id.</p>
/// <p>Mutation (Rule 19): remove the <code>rowTarget</code> from <class>OcuPilot.Screen.Descriptor.InteropQueueMessageList</class> --
/// this goes red.</p>
Method TestTheQueueMessagesListLinksToTheMessage()
{
    Set tQueue = ..Declaration("InteropQueueMessageList")
    Do $$$AssertTrue($IsObject(tQueue.rowTarget), "Queue messages declares a row target")
    If '$IsObject(tQueue.rowTarget) Quit
    Do $$$AssertEquals(tQueue.rowTarget.route _ "|" _ tQueue.rowTarget.field, "interoperability/messages/document|MessageId", "the Header tab, by the message id")
    Set tTarget = ##class(OcuPilot.Screen.Registry).DescriptorForRoute(tQueue.rowTarget.route)
    Do $$$AssertEquals(tTarget, ..#PREFIX _ "InteropMessageHeaderTab", "its route resolves to the Header tab")
    Set tDeclaration = ..Declaration("InteropMessageHeaderTab")
    Do $$$AssertEquals(tDeclaration.built _ "|" _ tDeclaration.id.kind, "1|single", "which is built and keyed by an id")
    Do $$$AssertEquals(tDeclaration.sideBarPosition, 0, "and unlisted")
}

}
