/// <p>What Page resources' two writes share (AD-51, AD-52, AD-53, AD-64, Story 21.37): an action-style write of one classic page's custom resource
/// through <class>OcuPilot.Port.PortalResourcePort</class>, reached by two callers -- the list's actions through
/// <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. Neither sends a body: the port composes the vendor's call from
/// the page and, for an assignment, the resource.</p>
/// <p><b>The target is the page's class name</b>, which the port normalizes as the instance stores it. <b>The fresh read</b> is the port's <code>GET</code>
/// composed for the write (<method>PortQuery</method>), so a resource the instance does not define, an empty one and a clear of a page that holds none
/// are refused by the port, with their <code>ACCESS.*</code> codes, before anything is stored; it answers <code>{Page, Resource, Screen, Current}</code>,
/// <code>Current</code> being the resource the page holds now. The fingerprint covers the page, the resource the write names and <code>Current</code>, so
/// a confirm whose page moved is refused as stale.</p>
/// <p><b>An OcuPilot screen that declares the page follows its resource</b> (<method>OcuPilot.Screen.Registry.ScreensDeclaringPage</method>): the mint
/// marks a change or a clear destructive and names the consequence (<method>OcuPilot.Kernel.Proposal.Prohibited.PageResourceEffect</method>), and
/// <method>DryRunReview</method> answers the screens and the same consequence code, so the person's dialog shows the line the card shows.</p>
Class OcuPilot.Screen.Tool.PageResourceAction Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.PageResourceList";

/// <p>The port that reads and stores a page's custom resource (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.PortalResourcePort";

Parameter READTYPE = "GET";

/// <p>The read is composed from the write it is read for (<method>PortQuery</method>), at the mint, at a screen action and at a confirm.</p>
Parameter READSVALUES As BOOLEAN = 1;

Parameter READANSWERS = "Page,Resource,Screen,Current";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>A person's action is reviewed through <code>POST /screens/:screen/dryrun</code> before it is sent (<method>DryRunReview</method>).</p>
Parameter DRYRUN As BOOLEAN = 1;

/// <p>The label the card's one row carries.</p>
Parameter STATEFIELD = "Resource";

Parameter PRECONDITIONFIELD = "Current";

Parameter FINGERPRINTSUBJECT = "Page,Resource,Current";

Parameter READBACKFIELDS = "Resource";

/// <p>The templates of a card's title, with <code>&lt;page&gt;</code> and <code>&lt;resource&gt;</code> standing for the page and the resource.</p>
Parameter SUMMARYASSIGN = "Assign <resource> to <page>";

Parameter SUMMARYCHANGE = "Change the resource of <page> to <resource>";

Parameter SUMMARYCLEAR = "Clear the resource of <page>";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.PortalResourcePort).#ENDPOINT
}

/// <p>The page, named by its class.</p>
ClassMethod IdArgument() As %String
{
    Quit "Page"
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.PortalResourcePort).#IDPARAM
}

/// <p>The Page resources screen's own requirement, read on every gate call: the area's pairs, the descriptor's and the custom resource of its classic page
/// (AD-8, AD-44, <method>OcuPilot.Screen.Gate.RequiredPairs</method>). The write needs nothing beyond what the screen needs.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
}

/// <p>The refusals the port's composed read answers with when the page no longer fits the write (AD-51).</p>
ClassMethod PreconditionCodes() As %List
{
    Quit ##class(OcuPilot.Port.PortalResourcePort).PreconditionCodes()
}

/// <p>The identifying property described: the page, named by its class.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The classic portal page, named by its class, such as %CSP.UI.Portal.Users. A name that is not a page of the classic portal is refused.", "string")
    Quit tSchema
}

/// <p>The page the card names: the fresh read's normalized <code>Page</code>, else the id as typed.</p>
ClassMethod PageOf(pFresh, pId As %String) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Page") = "string") && (pFresh.%Get("Page") '= "") Quit pFresh.%Get("Page")
    Quit pId
}

/// <p>The card's title <var>pTemplate</var> with the page and the resource put in.</p>
ClassMethod Summary(pTemplate As %String, pPage As %String, pResource As %String) As %String
{
    Quit $Replace($Replace(pTemplate, "<page>", pPage), "<resource>", pResource)
}

/// <p>The card's rows that name how OcuPilot's screens follow the page, which the consequence sentence reads: <code>Screen</code>, every declaring screen's
/// title, before and after alike, when the fresh read names any, and <code>Action</code>, the write tools that declare the page as
/// <code>&lt;descriptor&gt;#&lt;screen-action id&gt;</code> entries joined by <code>,</code> (<code>""</code> for the id of a tool with no screen action),
/// when any does, followed by one bare <code>&lt;descriptor&gt;</code> entry for each screen that opens the page, so the card can tell the screens
/// the page's resource gates opening from those it gates a write of. A row is omitted when it has nothing to say.</p>
ClassMethod ScreenRows(pFresh As %DynamicObject) As %DynamicArray
{
    Set tRows = []
    If '$IsObject(pFresh) Quit tRows
    If (pFresh.%GetTypeOf("Screen") = "string") && (pFresh.%Get("Screen") '= "") Do ..PushContextRow(tRows, "Screen", pFresh.%Get("Screen"))
    If pFresh.%GetTypeOf("Page") '= "string" Quit tRows
    Do ##class(OcuPilot.Screen.Registry).PageDeclarations(pFresh.%Get("Page"), .tOpens, .tActions)
    If '$ListLength(tActions) Quit tRows
    Set tEntries = ""
    For tI = 1:1:$ListLength(tActions) Set tEntries = tEntries _ $Select(tEntries = "": "", 1: ",") _ $List($List(tActions, tI), 1) _ "#" _ $List($List(tActions, tI), 2)
    For tI = 1:1:$ListLength(tOpens) Set tEntries = tEntries _ "," _ $List(tOpens, tI)
    Do ..PushContextRow(tRows, "Action", tEntries)
    Quit tRows
}

/// <p>One context row of the card, <var>pValue</var> before and after.</p>
ClassMethod PushContextRow(pRows As %DynamicArray, pField As %String, pValue As %String) [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("field", pField, "string")
    Do tRow.%Set("before", pValue, "string")
    Do tRow.%Set("after", pValue, "string")
    Do tRow.%Set("removed", 0, "boolean")
    Do pRows.%Push(tRow)
}

/// <p>What a reviewed action answers beside its rows (AD-53): <code>Screens</code>, the titles of every OcuPilot screen that declares the page in the
/// registry's order; <code>Opens</code>, the titles of those the page's resource gates opening; <code>Actions</code>, one
/// <code>{screen, action}</code> for each write tool that declares the page, <code>screen</code> being the descriptor class and <code>action</code> its
/// screen-action id (<code>""</code> for none); <code>Consequence</code>, the code the card carries for a write that changes the page's resource
/// (<code>""</code> for none); and <code>Current</code>, the resource the page holds now, so the dialog can tell an assignment of that same resource from
/// a change. A read that names no page answers none.</p>
ClassMethod DryRunReview(pFresh As %DynamicObject) As %DynamicObject
{
    Set tReview = {}
    Set tTitles = []
    Set tOpenTitles = []
    Set tActionRefs = []
    Set tConsequence = ""
    Set tCurrent = ""
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Page") = "string") {
        Set tPage = pFresh.%Get("Page")
        Set tList = $ClassMethod(..PortClass(), "TitleList", tPage)
        For tI = 1:1:$ListLength(tList) Do tTitles.%Push($List(tList, tI), "string")
        Do ##class(OcuPilot.Screen.Registry).PageDeclarations(tPage, .tOpens, .tActions)
        Set tOpened = $ClassMethod(..PortClass(), "TitlesOf", tOpens)
        For tI = 1:1:$ListLength(tOpened) Do tOpenTitles.%Push($List(tOpened, tI), "string")
        For tI = 1:1:$ListLength(tActions) {
            Set tRef = {}
            Do tRef.%Set("screen", $List($List(tActions, tI), 1), "string")
            Do tRef.%Set("action", $List($List(tActions, tI), 2), "string")
            Do tActionRefs.%Push(tRef)
        }
        Set tCurrent = pFresh.%Get("Current") _ ""
        Set tConsequence = ##class(OcuPilot.Kernel.Proposal.Prohibited).PageResourceEffect(tPage, tCurrent, "", ..Removes())
    }
    Do tReview.%Set("Screens", tTitles)
    Do tReview.%Set("Opens", tOpenTitles)
    Do tReview.%Set("Actions", tActionRefs)
    Do tReview.%Set("Consequence", tConsequence, "string")
    Do tReview.%Set("Current", tCurrent, "string")
    Quit tReview
}

/// <p>Whether this write clears the resource.</p>
ClassMethod Removes() As %Boolean
{
    Quit (..ChangeAction() = "deleted")
}

}
