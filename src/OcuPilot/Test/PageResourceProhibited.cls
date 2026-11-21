/// <p>Pins Story 21.37's Page resources writes against the prohibited set and the port's own rules, in process, over
/// <class>OcuPilot.Test.PageResourceStoreSeam</class>'s store, so no classic page of the instance is read for its resource or written (AD-10, AD-29, AD-39,
/// AD-51, AD-53, AD-64): an assignment to a page that a screen which cannot be adjusted declares is refused <code>PROHIBITED.OCUPILOTSCREEN</code> at the
/// agent's mint and at the person's gate, the declared pages derived from the registry; a change or a clear of a page an OcuPilot screen declares is minted
/// destructive with its consequence code; and a page, a resource or a clear the port refuses is refused on its own field before anything is stored or
/// recorded.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed; the proposals and turns it seeds are removed after each test. It creates no
/// principal and writes no custom resource.</p>
Class OcuPilot.Test.PageResourceProhibited Extends %UnitTest.TestCase
{

Parameter ASSIGN = "permissions.pageresources.assign";

Parameter CLEAR = "permissions.pageresources.clear";

Parameter SEAM = "OcuPilot.Test.PageResourceStoreSeam";

Parameter ASSIGNSEAM = "OcuPilot.Test.PageResourceAssignSeam";

Parameter CLEARSEAM = "OcuPilot.Test.PageResourceClearSeam";

Parameter PROHIBITED = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>A page two Home and Agent co-pilot screens declare, one a Permissions screen (which can be adjusted) declares, and one no screen declares.</p>
Parameter HOME = "%CSP.Portal.Home";

Parameter ADJUSTABLE = "%CSP.UI.Portal.Resources";

Parameter UNDECLARED = "OcuProbe.Page2137";

/// <p>The two resources the seam defines.</p>
Parameter FIRST = "OcuProbe2137ResA";

Parameter SECOND = "OcuProbe2137ResB";

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Define", ..#FIRST)
    Do $ClassMethod(..#SEAM, "Define", ..#SECOND)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Mint <var>pToolClass</var>'s tool for the page <var>pPage</var> with <var>pArgs</var> over the seam's store, on a seeded turn, as the running account.</p>
Method Mint(pToolClass As %String, pPage As %String, pArgs As %DynamicObject, Output pProposal, Output pHttp As %Integer, Output pFault) As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set($Namespace)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    If $$$ISERR(tSC) Quit tSC
    Do pArgs.%Set($ClassMethod(pToolClass, "IdArgument"), pPage, "string")
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), $Username, "", tTurn, pArgs, ..#LIMITS, .pProposal, .pHttp, .pFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pPage, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
}

/// <p>The proposal's stored <code>destructive</code> and <code>consequence</code>, joined by a bar.</p>
ClassMethod Treatment(pProposal As %DynamicObject) As %String
{
    If '$IsObject(pProposal) Quit "<none>"
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposal.%Get("proposalId"), .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit "<absent>"
    Quit +$Get(tValues("destructive")) _ "|" _ $Get(tValues("consequence"))
}

/// <p>The <code>after</code> of the minted proposal's <code>Screen</code> row, or <code>&lt;none&gt;</code> when the card carries no such row.</p>
ClassMethod ScreenRowOf(pProposal As %DynamicObject) As %String
{
    If '$IsObject(pProposal) || '$IsObject(pProposal.%Get("changed")) Quit "<none>"
    Set tAfter = "<none>"
    Set tRows = pProposal.%Get("changed").%GetIterator()
    While tRows.%GetNext(.tKey, .tRow) {
        If tRow.%Get("field") = "Screen" Set tAfter = tRow.%Get("after")
    }
    Quit tAfter
}

/// <p>The refusal of a prohibited-set question about <var>pTool</var> and the page <var>pPage</var>, as <code>prohibits|code</code>.</p>
ClassMethod Judged(pTool As %String, pPage As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("page-resource", ##class(OcuPilot.Kernel.EntityRef).ScopeFor("instance"), pPage, .tRef)
    If $$$ISERR(tSC) Quit "<no reference>"
    Set tSC = $ClassMethod(..#PROHIBITED, "Prohibits", pTool, tRef, "{""Page"":""" _ pPage _ """,""Resource"":""" _ ..#FIRST _ """,""Current"":""""}", "[]", .tProhibits, .tCode, .tReason)
    If $$$ISERR(tSC) Quit "<error>"
    Quit +tProhibits _ "|" _ tCode
}

/// <p>The code of the refusal <var>pFault</var>, and the field of its one violation, as <code>code|field</code>.</p>
ClassMethod Refusal(pFault As %DynamicObject) As %String
{
    If '$IsObject(pFault) Quit "|"
    Set tViolation = $Select($IsObject(pFault.%Get("detail")) && $IsObject(pFault.detail.%Get("violations")): pFault.detail.violations.%Get(0), 1: "")
    Quit pFault.%Get("code") _ "|" _ $Select($IsObject(tViolation): tViolation.%Get("field"), 1: "")
}

/// <p><b>Own screens (AC3).</b> An assignment to a page a Home or Agent co-pilot screen declares is refused <code>PROHIBITED.OCUPILOTSCREEN</code> with the
/// sentence the prohibited set already carries, by the prohibited set (the person's gate), and by the agent's mint, which stores no proposal and makes no
/// store call; a clear of the same page is not refused, and neither is an assignment to a page a Permissions screen declares or to a page nothing declares.
/// The refused pages are every page a built screen that cannot be adjusted declares, read from the registry.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.RefusesPageAssignment</method> skips the <code>Adjustable</code> check -> this goes red on
/// both callers.</p>
Method TestAnAssignToAnOwnScreensPageIsRefusedOnBothCallers()
{
    Set tCode = ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTSCREEN
    Do $$$AssertEquals(..Judged(..#ASSIGN, ..#HOME), "1|" _ tCode, "the prohibited set refuses an assign on Home's page")
    Do $$$AssertEquals(..Judged(..#CLEAR, ..#HOME), "0|", "and does not refuse its clear")
    Do $$$AssertEquals(..Judged(..#ASSIGN, ..#ADJUSTABLE), "0|", "nor an assign on a page a Permissions screen declares")
    Do $$$AssertEquals(..Judged(..#ASSIGN, ..#UNDECLARED), "0|", "nor on a page nothing declares")

    ; The person's gate is the shared operation's, asked with the prohibited set (OcuPilot.Api.ScreenAction.Run).
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#ASSIGN, .tTool)
    Do $$$AssertStatusOK(tSC, "the assign tool resolves")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("page-resource", ##class(OcuPilot.Kernel.EntityRef).ScopeFor("instance"), ..#HOME, .tRef)
    Set tArgs = {"Page": (..#HOME), "Resource": (..#FIRST)}
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Operation).Gate(tTool, tRef, "{""Page"":""" _ ..#HOME _ """,""Resource"":""" _ ..#FIRST _ """,""Current"":""""}", "[]", tArgs.%ToJSON(), $Username, ..#PROHIBITED, "", .tPairs, .tRefused, .tHttp, .tGateCode, .tDetail, .tReason)
    Do $$$AssertStatusOK(tSC, "the person's gate answers")
    Do $$$AssertEquals(tRefused _ "|" _ tHttp _ "|" _ tGateCode, "1|403|" _ tCode, "the person's Save is refused 403 with the code")
    Do $$$AssertEquals(tReason, ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode), "and with the sentence the prohibited set carries")

    ; The agent's mint, over the seam's store: refused before a proposal is stored or anything is written.
    Do $ClassMethod(..#SEAM, "Page", ..#HOME, "")
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#ASSIGN)
    Set tSC = ..Mint(..#ASSIGNSEAM, ..#HOME, {"Resource": (..#FIRST)}, .tProposal, .tMintHttp, .tMintFault)
    Do $$$AssertStatusNotOK(tSC, "the mint refuses an assign on Home's page")
    Do $$$AssertEquals(tMintHttp _ "|" _ $Select($IsObject(tMintFault): tMintFault.%Get("code"), 1: ""), "403|" _ tCode, "403 with the code")
    Do $$$AssertEquals($Select($IsObject(tMintFault): tMintFault.%Get("reason"), 1: ""), ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(tCode), "and the sentence")
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#ASSIGN), tBefore, "no proposal is stored")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "and nothing is written")

    ; Derived, never listed: every page a built screen that cannot be adjusted declares is refused, and no declared page of an adjustable screen alone is.
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tDescriptors)
    Do $$$AssertStatusOK(tSC, "the descriptors list")
    Set tChecked = 0
    Set tWrong = ""
    For tI = 1:1:$ListLength(tDescriptors) {
        Set tClass = $List(tDescriptors, tI)
        If '$ClassMethod(tClass, "IsBuilt") || ($ClassMethod(tClass, "ClassicPage") = "") Continue
        Set tPage = $ClassMethod(tClass, "ClassicPage")
        Set tSC = ##class(OcuPilot.Port.PortalResourcePort).Normalized(tPage, .tNormalized)
        If $$$ISERR(tSC) || (tNormalized = "") Continue
        Set tOwn = '##class(OcuPilot.Screen.Gate).Adjustable(tClass)
        Set tScreens = ##class(OcuPilot.Screen.Registry).ScreensDeclaringPage(tNormalized, .tResolved)
        Set tAnyOwn = 0
        For tJ = 1:1:$ListLength(tScreens) {
            If '##class(OcuPilot.Screen.Gate).Adjustable($List(tScreens, tJ)) Set tAnyOwn = 1
        }
        Set tChecked = tChecked + 1
        If tOwn && (..Judged(..#ASSIGN, tNormalized) '= ("1|" _ tCode)) Set tWrong = tWrong _ " " _ tClass _ " (own, not refused)"
        If 'tAnyOwn && (..Judged(..#ASSIGN, tNormalized) '= "0|") Set tWrong = tWrong _ " " _ tClass _ " (refused though no own screen declares it)"
    }
    Do $$$AssertTrue(tChecked > 100, "the sweep covers the registry's screens with a classic page: " _ tChecked)
    Do $$$AssertEquals(tWrong, "", "each own screen's page is refused and no other is:" _ tWrong)
}

/// <p><b>Lowering (AC4).</b> A change or a clear of a page an OcuPilot screen declares that holds a resource is minted destructive with no typed name and
/// carries <code>PAGERESOURCE.CHANGED</code> or <code>PAGERESOURCE.CLEARED</code>; an assign to a page with none, and a change or a clear of a page no screen
/// declares, are not; and the person's review answers the same consequence and the declaring screens' titles.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method> never selects the page effects -> this goes red.</p>
Method TestAChangeOrAClearOfADeclaredPageIsMintedDestructive()
{
    Set tChanged = ##class(OcuPilot.Kernel.Proposal.Prohibited).#EFFECTPAGERESOURCECHANGED
    Set tCleared = ##class(OcuPilot.Kernel.Proposal.Prohibited).#EFFECTPAGERESOURCECLEARED
    Do $ClassMethod(..#SEAM, "Page", ..#ADJUSTABLE, ..#FIRST)
    Do $ClassMethod(..#SEAM, "Page", ..#UNDECLARED, ..#FIRST)
    Do $ClassMethod(..#SEAM, "Page", ..#HOME, ..#FIRST)
    Set tSC = ..Mint(..#ASSIGNSEAM, ..#ADJUSTABLE, {"Resource": (..#SECOND)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a change of a declared page's resource mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Treatment($Get(tProposal)), "1|" _ tChanged, "it is destructive and names the change")
    Set tTitles = $ListToString(##class(OcuPilot.Port.PortalResourcePort).TitleList(..#ADJUSTABLE), ", ")
    Do $$$AssertTrue(tTitles '= "", "the screens that follow the declared page are named")
    Do $$$AssertEquals(..ScreenRowOf($Get(tProposal)), tTitles, "the change's card carries the titles the consequence sentence names")
    Set tSC = ..Mint(..#CLEARSEAM, ..#ADJUSTABLE, {}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a clear of a declared page mints")
    Do $$$AssertEquals(..Treatment($Get(tProposal)), "1|" _ tCleared, "it is destructive and names the clear")
    Do $$$AssertEquals(..ScreenRowOf($Get(tProposal)), tTitles, "the clear's card carries them too")
    Set tSC = ..Mint(..#CLEARSEAM, ..#HOME, {}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a clear of Home's page mints: only a clear can reach it")
    Do $$$AssertEquals(..Treatment($Get(tProposal)), "1|" _ tCleared, "it is destructive too")
    Set tSC = ..Mint(..#ASSIGNSEAM, ..#UNDECLARED, {"Resource": (..#SECOND)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a change of a page nothing declares mints")
    Do $$$AssertEquals(..Treatment($Get(tProposal)), "0|", "it is not destructive")
    Do $$$AssertEquals(..ScreenRowOf($Get(tProposal)), "<none>", "and its card names no screen")
    Set tSC = ..Mint(..#CLEARSEAM, ..#UNDECLARED, {}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a clear of a page nothing declares mints")
    Do $$$AssertEquals(..Treatment($Get(tProposal)), "0|", "it is not destructive")
    Do $ClassMethod(..#SEAM, "Page", ..#ADJUSTABLE, "")
    Set tSC = ..Mint(..#ASSIGNSEAM, ..#ADJUSTABLE, {"Resource": (..#FIRST)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "an assign to a declared page that holds none mints")
    Do $$$AssertEquals(..Treatment($Get(tProposal)), "0|", "it is not destructive")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "and no mint wrote anything")

    ; The person's review: the screens that follow the page and the same consequence.
    Do $ClassMethod(..#SEAM, "Page", ..#ADJUSTABLE, ..#FIRST)
    Kill tQuery
    Set tQuery("id") = ..#ADJUSTABLE
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "PortalResource", "GET", .tQuery, "", .tFresh, .tFreshHttp, .tFreshFault)
    Do $$$AssertEquals(tFreshHttp, 200, "the page reads")
    Set tReview = $ClassMethod(..#ASSIGNSEAM, "DryRunReview", tFresh)
    Do $$$AssertEquals(tReview.%Get("Consequence"), tChanged, "the review of a change names the consequence")
    Do $$$AssertTrue(tReview.%Get("Screens").%Size() > 0, "and the screens that follow the page")
    Do $$$AssertEquals(tReview.%Get("Screens").%Get(0), ##class(OcuPilot.Screen.Tool.Read).Title($List(##class(OcuPilot.Screen.Registry).ScreensDeclaringPage(..#ADJUSTABLE), 1)), "the first is the registry's first, by title")
    Set tReview = $ClassMethod(..#CLEARSEAM, "DryRunReview", tFresh)
    Do $$$AssertEquals(tReview.%Get("Consequence"), tCleared, "the review of a clear names its own")
    Kill tQuery
    Set tQuery("id") = ..#UNDECLARED
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "PortalResource", "GET", .tQuery, "", .tOther, .tOtherHttp, .tOtherFault)
    Set tReview = $ClassMethod(..#CLEARSEAM, "DryRunReview", tOther)
    Do $$$AssertEquals(tReview.%Get("Consequence") _ "|" _ tReview.%Get("Screens").%Size(), "|0", "a page nothing declares names no consequence and no screen")
}

/// <p><b>An assignment of the held resource.</b> The agent's assign naming the resource the page already holds is refused at the mint, 400 with
/// <parameter>OcuPilot.Screen.Tool.PageResourceAssign.REASONHELD</parameter> as its problem, and stores no proposal, writes nothing and records nothing;
/// an assign naming another resource on the same page mints.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.PageResourceAssign.MergeUpdate</method> sets no problem -> this goes red.</p>
Method TestAnAssignOfTheHeldResourceIsRefusedAtTheMint()
{
    Do $ClassMethod(..#SEAM, "Page", ..#UNDECLARED, ..#FIRST)
    Set tProposal = ""
    Set tSC = ..Mint(..#ASSIGNSEAM, ..#UNDECLARED, {"Resource": (..#FIRST)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "an assign of the resource the page holds is refused")
    Set tProblem = $Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("problem"), 1: "")
    Do $$$AssertEquals(+$Get(tHttp) _ "|" _ tProblem, "400|" _ ##class(OcuPilot.Screen.Tool.PageResourceAssign).#REASONHELD, "400 with the ruled sentence")
    Do $$$AssertTrue('$IsObject(tProposal), "no proposal is stored")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ "|" _ $ClassMethod(..#SEAM, "Audits"), "|", "nothing is written and nothing is recorded")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "HeldBy", ..#UNDECLARED), ..#FIRST, "the page keeps its resource")
    Set tSC = ..Mint(..#ASSIGNSEAM, ..#UNDECLARED, {"Resource": (..#SECOND)}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "an assign of another resource to the same page mints: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
}

/// <p><b>Bad input (AC5) and the write's rules.</b> A page the portal does not have is 422 <code>ACCESS.PAGE.UNKNOWN</code> on <code>Page</code>, an empty
/// resource 422 <code>ACCESS.PAGE.RESOURCEREQUIRED</code> on <code>Resource</code>, and a resource the instance does not define 422
/// <code>ACCESS.RESOURCE.UNKNOWN</code> on <code>Resource</code>; a clear of a page with none is 409 <code>ACCESS.PAGE.NOTASSIGNED</code>. Each is refused
/// before anything is stored or recorded, by the port and by the agent's mint. An accepted assignment and clear store once and record one security change
/// each, and an assignment of the resource the page holds stores and records nothing.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.PortalResourcePort.AssignResource</method> drops its <code>tNormalized = ""</code> check -> the unknown-page leg
/// goes red; <method>OcuPilot.Port.PortalResourcePort.ResourceProblem</method> drops its defined check -> the unknown-resource leg goes red;
/// <method>OcuPilot.Port.PortalResourcePort.AssignResource</method> stores the page as the caller spelled it, or <method>OcuPilot.Port.PortalResourcePort.ClearResource</method>
/// records the event of a refused clear -> the accepted-write and refusal legs go red.</p>
Method TestBadInputIsRefusedOnItsFieldBeforeAnythingIsStored()
{
    Do $ClassMethod(..#SEAM, "Page", ..#UNDECLARED, "")
    Do $ClassMethod(..#SEAM, "Page", ..#ADJUSTABLE, ..#FIRST)
    For tCase = $ListBuild("PUT", "No.Such.Page", ..#FIRST, "ACCESS.PAGE.UNKNOWN|Page"), $ListBuild("PUT", "", ..#FIRST, "ACCESS.PAGE.UNKNOWN|Page"), $ListBuild("PUT", ..#UNDECLARED, "", "ACCESS.PAGE.RESOURCEREQUIRED|Resource"), $ListBuild("PUT", ..#UNDECLARED, "NoSuchResource2137", "ACCESS.RESOURCE.UNKNOWN|Resource"), $ListBuild("DELETE", "No.Such.Page", "", "ACCESS.PAGE.UNKNOWN|Page") {
        Kill tQuery
        Set tQuery("id") = $List(tCase, 2)
        If $List(tCase, 1) = "PUT" Set tQuery("resource") = $List(tCase, 3)
        Set tSC = $ClassMethod(..#SEAM, "Invoke", "PortalResource", $List(tCase, 1), .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 1) _ " '" _ $List(tCase, 2) _ "' / '" _ $List(tCase, 3) _ "': refused")
        Do $$$AssertEquals(tHttp, 422, $List(tCase, 1) _ " '" _ $List(tCase, 2) _ "' / '" _ $List(tCase, 3) _ "': 422")
        Do $$$AssertEquals(..Refusal($Get(tFault)), $List(tCase, 4), $List(tCase, 1) _ " '" _ $List(tCase, 2) _ "' / '" _ $List(tCase, 3) _ "': its code on its own field")
        Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: ""), ##class(OcuPilot.Api.AccessError).ReasonFor($Piece($List(tCase, 4), "|", 1)), $List(tCase, 1) _ " '" _ $List(tCase, 2) _ "': with its published sentence")
    }
    Kill tQuery
    Set tQuery("id") = ..#UNDECLARED
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "PortalResource", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409|ACCESS.PAGE.NOTASSIGNED", "a clear of a page with none is 409")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ "|" _ $ClassMethod(..#SEAM, "Audits"), "|", "nothing was stored or recorded by any refusal")

    ; The composed reads refuse what the writes would refuse.
    Kill tQuery
    Set tQuery("id") = ..#UNDECLARED
    Set tQuery("resource") = ""
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "PortalResource", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Refusal($Get(tFault)), "ACCESS.PAGE.RESOURCEREQUIRED|Resource", "a read composed for an empty resource is refused")
    Kill tQuery
    Set tQuery("id") = ..#UNDECLARED
    Set tQuery("clear") = 1
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "PortalResource", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409|ACCESS.PAGE.NOTASSIGNED", "a read composed for a clear of a page with none is refused")

    ; The agent's mint reads the same refusals before it stores a proposal.
    Set tBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#ASSIGN)
    Set tClearBefore = ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CLEAR)
    For tCase = $ListBuild(..#ASSIGNSEAM, ..#UNDECLARED, "", "ACCESS.PAGE.RESOURCEREQUIRED"), $ListBuild(..#ASSIGNSEAM, ..#UNDECLARED, "NoSuchResource2137", "ACCESS.RESOURCE.UNKNOWN"), $ListBuild(..#ASSIGNSEAM, "No.Such.Page", ..#FIRST, "ACCESS.PAGE.UNKNOWN"), $ListBuild(..#CLEARSEAM, ..#UNDECLARED, "", "ACCESS.PAGE.NOTASSIGNED") {
        Set tArgs = {}
        If $List(tCase, 1) = ..#ASSIGNSEAM Do tArgs.%Set("Resource", $List(tCase, 3), "string")
        Set tSC = ..Mint($List(tCase, 1), $List(tCase, 2), tArgs, .tProposal, .tMintHttp, .tMintFault)
        Do $$$AssertStatusNotOK(tSC, "the mint refuses '" _ $List(tCase, 4) _ "'")
        Do $$$AssertEquals($Select($IsObject($Get(tMintFault)): tMintFault.%Get("code"), 1: ""), $List(tCase, 4), "with its code: " _ $Select($IsObject($Get(tMintFault)): tMintFault.%ToJSON(), 1: ""))
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#ASSIGN) _ "|" _ ##class(OcuPilot.Test.ExplorerSave).ProposalRows(..#CLEAR), tBefore _ "|" _ tClearBefore, "and stores no proposal")

    ; Accepted writes store once and record once, under the normalized class name whatever spelling named the page; a no-change assignment does neither.
    Kill tQuery
    Set tQuery("id") = ..#UNDECLARED _ ".cls"
    Set tQuery("resource") = ..#FIRST
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "PortalResource", "PUT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "an assignment is accepted")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ "|" _ $ClassMethod(..#SEAM, "Audits"), ..#UNDECLARED _ "=" _ ..#FIRST _ "|updated " _ ..#UNDECLARED _ " >" _ ..#FIRST, "it is stored and recorded once, with the resource before and after")
    Do $$$AssertTrue($IsObject($Get(tResult)), "and answers a row")
    If $IsObject($Get(tResult)) Do $$$AssertEquals(tResult.%Get("Resource") _ "|" _ tResult.%Get("Current"), ..#FIRST _ "|" _ ..#FIRST, "and answers the page's row after the write")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "PortalResource", "PUT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Length($ClassMethod(..#SEAM, "Writes"), ";"), "200|1", "an assignment of the resource the page holds is accepted and stores nothing more")
    Kill tQuery
    Set tQuery("id") = ..#UNDECLARED
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "PortalResource", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a clear is accepted")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), ..#UNDECLARED _ "=" _ ..#FIRST _ ";" _ ..#UNDECLARED _ "=", "it stores the empty resource")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Audits"), "updated " _ ..#UNDECLARED _ " >" _ ..#FIRST _ ";deleted " _ ..#UNDECLARED _ " " _ ..#FIRST _ ">", "and records one more security change, and only the two accepted writes are recorded")
}

}
