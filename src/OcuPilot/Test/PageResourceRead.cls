/// <p>Pins Story 21.37's Page resources read, gate and declaration (AD-8, AD-13, AD-29, AD-36, AD-44, AD-64): the port and the screen answer one row
/// per classic page that holds a custom resource, each <code>{Page, Resource, Screen}</code> with the titles of the built screens that declare the
/// page, derived from the registry on every call; a page name is normalized as the instance stores it and a name that is no portal page is refused 422
/// on <code>Page</code>; every call is refused to a caller short of a pair before the vendor is read; and the screen declares its page, pairs and read.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because the class plants a custom resource on classic portal pages. <method>OnBeforeAllTests</method> refuses anywhere it does not, records
/// every page it touches and <method>OnAfterOneTest</method> restores each, failing the test when a page does not read its recorded value.
/// Assertions are on the rows it planted, by their marker resource, never on the store's size.</p>
Class OcuPilot.Test.PageResourceRead Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PORT = "OcuPilot.Port.PortalResourcePort";

Parameter SEAM = "OcuPilot.Test.PageResourceSeam";

Parameter ENDPOINT = "PortalResource";

Parameter LIST = "OcuPilot.Screen.Descriptor.PageResourceList";

/// <p>The marker resources planted on the probe pages; the store does not require a resource to be defined.</p>
Parameter MARKER = "OcuProbe2137Marker";

Parameter OTHERMARKER = "OcuProbe2137Other";

/// <p>The pages the probe is taken from, first that the vendor resolves to a portal page and no screen declares.</p>
Parameter CANDIDATES = "%CSP.UI.Portal.About,%UnitTest.Portal.Index";

/// <p>A page one screen declares through its descriptor (<code>%CSP.UI.Portal.Resources</code>, the Resources list), a page that screen's write
/// tools declare, and a page three screens declare.</p>
Parameter DECLARED = "%CSP.UI.Portal.Resources";

Parameter TOOLDECLARED = "%CSP.UI.Portal.Dialog.ExportResource";

Parameter SHARED = "%CSP.UI.Portal.NLS";

/// <p>A page this class only reads, to see the name normalized.</p>
Parameter DIALOG = "%CSP.Portal.ResourceDialog";

/// <p>The probe page chosen for the run.</p>
Property PreparedProbe As %String;

/// <p>Each page's custom resource as it stood before the class ran, keyed by page.</p>
Property PreparedPages [ MultiDimensional ];

/// <p>Whether <method>OnBeforeAllTests</method> recorded the pages; the teardown restores only then.</p>
Property PreparedTaken As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedProbe = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PageResourceRead assigns custom resources to classic portal pages and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was assigned.")
    }
    For tI = 1:1:$Length(..#CANDIDATES, ",") {
        Set tCandidate = $Piece(..#CANDIDATES, ",", tI)
        Set tSC = $ClassMethod(..#PORT, "Normalized", tCandidate, .tNormalized)
        If $$$ISERR(tSC) Quit
        If tNormalized = "" Continue
        Set tDeclaring = ##class(OcuPilot.Screen.Registry).ScreensDeclaringPage(tNormalized, .tResolved)
        If tResolved && ($ListLength(tDeclaring) = 0) {
            Set ..PreparedProbe = tNormalized
            Quit
        }
    }
    If $$$ISERR($Get(tSC, $$$OK)) Quit tSC
    If ..PreparedProbe = "" Quit $$$ERROR($$$GeneralError, "none of the candidate pages (" _ ..#CANDIDATES _ ") resolves to a portal page that no screen declares")
    For tPage = ..PreparedProbe, ..#DECLARED, ..#TOOLDECLARED, ..#SHARED, ..#DIALOG {
        Set ..PreparedPages(tPage) = ##class(%CSP.Portal.Utils).%GetCustomResource($ZConvert(tPage, "O", "URL"))
    }
    Set ..PreparedTaken = 1
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Clear")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertStatusOK(..RestorePages(), "every page reads its recorded custom resource again")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If '..PreparedTaken Quit $$$OK
    Quit ..RestorePages()
}

/// <p>Put every recorded page back to its recorded custom resource; an error when one does not read it afterwards.</p>
Method RestorePages() As %Status
{
    Set tSC = $$$OK
    Set tPage = ""
    For {
        Set tPage = $Order(..PreparedPages(tPage), 1, tRecorded)
        If tPage = "" Quit
        Set tEncoded = $ZConvert(tPage, "O", "URL")
        If ##class(%CSP.Portal.Utils).%GetCustomResource(tEncoded) '= tRecorded Set tSC = $$$ADDSC(tSC, ##class(%CSP.Portal.Utils).%SetCustomResource(tEncoded, tRecorded))
        If ##class(%CSP.Portal.Utils).%GetCustomResource(tEncoded) '= tRecorded Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, tPage _ " does not read its recorded custom resource '" _ tRecorded _ "'"))
    }
    Quit tSC
}

/// <p>Assign <var>pResource</var> to <var>pPage</var> as the classic dialog does, and read it back.</p>
Method Plant(pPage As %String, pResource As %String) As %Status
{
    Set tEncoded = $ZConvert(pPage, "O", "URL")
    Set tSC = ##class(%CSP.Portal.Utils).%SetCustomResource(tEncoded, pResource)
    If $$$ISERR(tSC) Quit tSC
    If ##class(%CSP.Portal.Utils).%GetCustomResource(tEncoded) '= pResource Quit $$$ERROR($$$GeneralError, pPage _ " does not read '" _ pResource _ "' after its assignment")
    Quit $$$OK
}

/// <p>The port's call <var>pType</var> of <var>pClass</var> with the query key <var>pKey</var> set to <var>pValue</var>.</p>
ClassMethod Call(pClass As %String, pType As %String, pKey As %String, pValue As %String, Output pResult, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill tQuery
    If pKey '= "" Set tQuery(pKey) = pValue
    Quit $ClassMethod(pClass, "Invoke", ..#ENDPOINT, pType, .tQuery, "", .pResult, .pHttp, .pFault)
}

/// <p>The first row of <var>pRows</var> whose <code>Page</code> is <var>pPage</var>, or <code>""</code>.</p>
ClassMethod RowFor(pRows As %DynamicArray, pPage As %String) As %DynamicObject
{
    Set tFound = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Page") = pPage {
            Set tFound = tRow
            Quit
        }
    }
    Quit tFound
}

/// <p>The fault code of <var>pFault</var>, <code>""</code> when it is not an object.</p>
ClassMethod CodeOf(pFault As %DynamicObject) As %String
{
    Quit $Select($IsObject(pFault): pFault.%Get("code"), 1: "")
}

/// <p>The <var>pPairs</var> list as <code>resource:permission</code> entries joined by <code>,</code>.</p>
ClassMethod PairsText(pPairs As %List) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ $List($List(pPairs, tI), 1) _ ":" _ $List($List(pPairs, tI), 2)
    }
    Quit tText
}

/// <p>The titles of the descriptors <var>pScreens</var>, joined by <code>, </code>.</p>
ClassMethod TitlesOf(pScreens As %List) As %String
{
    Set tTitles = ""
    For tI = 1:1:$ListLength(pScreens) {
        Set tTitles = tTitles _ $Select(tTitles = "": "", 1: ", ") _ ##class(OcuPilot.Screen.Tool.Read).Title($List(pScreens, tI))
    }
    Quit tTitles
}

/// <p><b>Declaration.</b> The screen is Permissions' fifth entry, a built list whose pairs are the port's and the area's, whose classic page and entity
/// type are the ones the story names, and whose read is the portal resource source's one endpoint; its derived read tool is registered.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Descriptor.PageResourceList</class>'s <code>sideBarPosition</code> becomes 6 -> the first assertion goes red.</p>
Method TestTheScreenDeclaresItsPagePairsAndRead()
{
    Set tClass = ..#LIST
    Do $$$AssertEquals($ClassMethod(tClass, "Route") _ "|" _ $ClassMethod(tClass, "AreaKey") _ "|" _ $ClassMethod(tClass, "SideBarPosition") _ "|" _ $ClassMethod(tClass, "Archetype") _ "|" _ $ClassMethod(tClass, "IsBuilt"), "permissions/pageresources|permissions|5|list|1", "the fifth Permissions entry, a built list")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage") _ "|" _ $ClassMethod(tClass, "PrimaryEntityType") _ "|" _ $ClassMethod(tClass, "ToolIdentifier"), "%CSP.Portal.ResourceDialog|page-resource|permissions.pageresources", "its classic page, entity type and tool identifier")
    Set tPairs = ..PairsText($ClassMethod(tClass, "PrivilegePairs"))
    Do $$$AssertEquals(tPairs, $Parameter(..#PORT, "PAIRS"), "its pairs are the port's, in the port's order")
    Do $$$AssertEquals(tPairs, ..PairsText(##class(OcuPilot.Screen.Area).PrivilegePairs("permissions")), "and the Permissions area's")
    Do $$$AssertEquals($ClassMethod(tClass, "Read").source.%ToJSON(), "{""port"":""portalresource"",""endpoint"":""" _ $Parameter(..#PORT, "ENDPOINT") _ """,""type"":""LIST""}", "its read is the portal resource source's one endpoint")
    Do $$$AssertEquals($Parameter(..#PORT, "ENDPOINT"), ..#ENDPOINT, "which is the port's own pseudo-endpoint")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the tools list")
    Set tFound = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If tTool.%Get("name") = "permissions.pageresources.read" Set tFound = tTool.%Get("kind") _ "|" _ tTool.%Get("descriptor")
    }
    Do $$$AssertEquals(tFound, "read|" _ tClass, "its read tool is registered, derived from the descriptor")
}

/// <p>The list answers one row per page that holds a custom resource, ordered by page; a planted page's row carries its marker resource and the
/// titles of the screens that declare it, and a page no screen declares has none. Every row has exactly the three members, as text.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.PortalResourcePort</class>'s <code>Listed</code> reads the resource from the wrong column -> the marker
/// assertion goes red.</p>
Method TestAPlantedRowIsListedByItsMarkerWithItsDeclaringScreens()
{
    Do $$$AssertStatusOK(..Plant(..PreparedProbe, ..#MARKER), "the probe page is assigned its marker")
    Do $$$AssertStatusOK(..Plant(..#DECLARED, ..#OTHERMARKER), "a page one screen declares is assigned another")
    Do $$$AssertStatusOK(..Plant(..#TOOLDECLARED, ..#OTHERMARKER), "and a page that screen's tools declare")
    Set tSC = ..Call(..#PORT, "LIST", "maxRows", 100000, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the list answers")
    If '$IsObject($Get(tRows)) Quit
    Set tProbe = ..RowFor(tRows, ..PreparedProbe)
    Do $$$AssertTrue($IsObject(tProbe), "the probe page is listed")
    If $IsObject(tProbe) {
        Do $$$AssertEquals(tProbe.%Get("Resource") _ "|" _ tProbe.%Get("Screen"), ..#MARKER _ "|", "with its marker and no screen")
        Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Keys(tProbe), "Page,Resource,Screen", "and exactly its three members")
        Do $$$AssertEquals(tProbe.%GetTypeOf("Resource") _ "|" _ tProbe.%GetTypeOf("Screen"), "string|string", "as text")
    }
    Set tDeclared = ..RowFor(tRows, ..#DECLARED)
    Do $$$AssertTrue($IsObject(tDeclared), "the declared page is listed")
    If $IsObject(tDeclared) Do $$$AssertEquals(tDeclared.%Get("Resource") _ "|" _ tDeclared.%Get("Screen"), ..#OTHERMARKER _ "|Resources", "with its marker and the title of the screen that declares it")
    Set tTool = ..RowFor(tRows, ..#TOOLDECLARED)
    Do $$$AssertTrue($IsObject(tTool), "the page a tool declares is listed")
    If $IsObject(tTool) Do $$$AssertEquals(tTool.%Get("Resource") _ "|" _ tTool.%Get("Screen"), ..#OTHERMARKER _ "|Resources", "with the title of that tool's screen")
    Set tPrevious = ""
    Set tSorted = 1
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tUpper = $ZConvert(tRow.%Get("Page"), "U")
        If (tPrevious '= "") && (tPrevious ] tUpper) Set tSorted = 0
        Set tPrevious = tUpper
    }
    Do $$$AssertTrue(tSorted, "the rows are ordered by page")
}

/// <p>A page several screens declare shows every one of their titles, in the registry's order, joined by <code>, </code>.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.PortalResourcePort</class>'s <code>ScreenTitles</code> stops after the first title -> the assertion
/// goes red.</p>
Method TestAPageSeveralScreensDeclareShowsEveryTitle()
{
    Set tScreens = ##class(OcuPilot.Screen.Registry).ScreensDeclaringPage(..#SHARED, .tResolved)
    Do $$$AssertTrue(tResolved && ($ListLength(tScreens) > 1), "the shared page is declared by more than one screen: " _ $ListLength(tScreens))
    Do $$$AssertStatusOK(..Plant(..#SHARED, ..#MARKER), "the shared page is assigned its marker")
    Set tSC = ..Call(..#PORT, "GET", "id", ..#SHARED, .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the page reads")
    If '$IsObject($Get(tRow)) Quit
    Do $$$AssertEquals(tRow.%Get("Screen"), ..TitlesOf(tScreens), "its Screen is every declaring screen's title, joined")
    Do $$$AssertTrue($Length(tRow.%Get("Screen"), ", ") >= $ListLength(tScreens), "and names each of them")
}

/// <p>The registry's declaring screens are derived on every call, never listed: every built screen is among the screens that declare its own
/// classic page, a write tool's page names that tool's screen, and a page nothing declares answers none from a registry that was read.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Registry</class>'s <code>ScreensDeclaringPage</code> ignores a write tool's <code>CLASSICPAGES</code> -> the
/// tool assertion goes red.</p>
Method TestTheDeclaringScreensAreDerivedFromTheRegistry()
{
    Set tSC = ##class(OcuPilot.Screen.Registry).Descriptors(.tDescriptors)
    Do $$$AssertStatusOK(tSC, "the descriptors list")
    Set tBad = ""
    Set tChecked = 0
    For tI = 1:1:$ListLength(tDescriptors) {
        Set tClass = $List(tDescriptors, tI)
        If '$ClassMethod(tClass, "IsBuilt") Continue
        Set tPage = $ClassMethod(tClass, "ClassicPage")
        If tPage = "" Continue
        Set tChecked = tChecked + 1
        Set tScreens = ##class(OcuPilot.Screen.Registry).ScreensDeclaringPage(tPage, .tResolved)
        If 'tResolved || '$ListFind(tScreens, tClass) Set tBad = tBad _ " " _ tClass
    }
    Do $$$AssertTrue(tChecked > 100, "the sweep covers the registry's built screens: " _ tChecked)
    Do $$$AssertEquals(tBad, "", "every built screen is among the screens declaring its own classic page")
    Set tScreens = ##class(OcuPilot.Screen.Registry).ScreensDeclaringPage(..#TOOLDECLARED, .tResolved)
    Do $$$AssertTrue(tResolved && $ListFind(tScreens, $Parameter("OcuPilot.Screen.Tool.ResourceExport", "DESCRIPTORCLASS")), "a page only a write tool declares names that tool's screen")
    Set tNone = ##class(OcuPilot.Screen.Registry).ScreensDeclaringPage(..PreparedProbe, .tResolved)
    Do $$$AssertEquals(tResolved _ "|" _ $ListLength(tNone), "1|0", "a page nothing declares answers none from a registry that was read")
    Set tNone = ##class(OcuPilot.Screen.Registry).ScreensDeclaringPage("", .tResolved)
    Do $$$AssertEquals(tResolved _ "|" _ $ListLength(tNone), "0|0", "and no page answers none from a registry that was not read")
}

/// <p>One page by name: the name is normalized as the instance stores it, so a <code>.cls</code> suffix reads the same row; a page with a marker
/// answers it, and once cleared answers an empty resource, never an error.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.PortalResourcePort</class>'s <code>Normalized</code> passes the caller's name to <code>Held</code>
/// as it came -> the <code>.cls</code> assertion goes red.</p>
Method TestOnePageIsReadByItsNormalizedName()
{
    Do $$$AssertStatusOK(..Plant(..PreparedProbe, ..#MARKER), "the probe page is assigned its marker")
    Set tSC = ..Call(..#PORT, "GET", "id", ..PreparedProbe _ ".cls", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "a name with its .cls suffix reads")
    If $IsObject($Get(tRow)) Do $$$AssertEquals(tRow.%Get("Page") _ "|" _ tRow.%Get("Resource") _ "|" _ tRow.%Get("Screen"), ..PreparedProbe _ "|" _ ..#MARKER _ "|", "as the normalized page with its marker")
    Set tSC = ..Call(..#PORT, "GET", "id", ..#DIALOG _ ".cls", .tDialog, .tDialogHttp, .tDialogFault)
    Do $$$AssertEquals(tDialogHttp, 200, "the classic dialog's own page reads")
    If $IsObject($Get(tDialog)) Do $$$AssertEquals(tDialog.%Get("Page") _ "|" _ tDialog.%Get("Resource"), ..#DIALOG _ "|" _ ..PreparedPages(..#DIALOG), "under its normalized class name, with the resource the instance holds")
    Do $$$AssertStatusOK(..Plant(..PreparedProbe, ""), "the probe page's resource is cleared")
    Set tSC = ..Call(..#PORT, "GET", "id", ..PreparedProbe, .tNone, .tNoneHttp, .tNoneFault)
    Do $$$AssertEquals(tNoneHttp, 200, "a page with none reads")
    If $IsObject($Get(tNone)) Do $$$AssertEquals(tNone.%Get("Resource"), "", "with an empty resource")
}

/// <p>A name that is no portal page is refused 422 <code>ACCESS.PAGE.UNKNOWN</code> on <code>Page</code> with its published sentence: a name of the wrong
/// shape or too long before the vendor is asked at all, and a well-shaped name the vendor does not resolve before the resource is read.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.PortalResourcePort</class>'s <code>Normalized</code> skips the shape check -> the shape legs go red on
/// the vendor read they then record.</p>
Method TestAnUnknownPageIsRefusedOnPageBeforeAnyResourceIsRead()
{
    Set tLong = "%CSP.UI.Portal." _ $Translate($Justify("", 250), " ", "A")
    For tCase = $ListBuild("", ""), $ListBuild("a b", ""), $ListBuild("1Page", ""), $ListBuild("Nope.Nada;kill", ""), $ListBuild(tLong, ""), $ListBuild("Nope.Nada", "RESOLVE"), $ListBuild("%Library.String", "RESOLVE") {
        Set tName = $List(tCase, 1)
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = ..Call(..#SEAM, "GET", "id", tName, .tRow, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 422, "'" _ $Extract(tName, 1, 20) _ "': refused 422")
        Do $$$AssertEquals(..CodeOf(tFault), ##class(OcuPilot.Api.AccessError).#PAGEUNKNOWN, "'" _ $Extract(tName, 1, 20) _ "': ACCESS.PAGE.UNKNOWN")
        If '$IsObject($Get(tFault)) Continue
        Do $$$AssertEquals(tFault.%Get("reason"), ##class(OcuPilot.Api.AccessError).ReasonFor(##class(OcuPilot.Api.AccessError).#PAGEUNKNOWN), "'" _ $Extract(tName, 1, 20) _ "': its published sentence")
        Set tViolation = $Select($IsObject(tFault.%Get("detail")) && $IsObject(tFault.detail.%Get("violations")): tFault.detail.violations.%Get(0), 1: "")
        Do $$$AssertEquals($Select($IsObject(tViolation): tViolation.%Get("field") _ "|" _ tViolation.%Get("code"), 1: ""), "Page|" _ ##class(OcuPilot.Api.AccessError).#PAGEUNKNOWN, "'" _ $Extract(tName, 1, 20) _ "': one violation on Page")
        Set tWanted = $List(tCase, 2)
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), tWanted, "'" _ $Extract(tName, 1, 20) _ "': " _ $Select(tWanted = "": "no vendor read was made", 1: "only the resolution was made"))
    }
}

/// <p>A caller short of either pair is refused 403 on the first pair it lacks, for the list and for one page, before the vendor is read.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.PortalResourcePort</class>'s <code>PAIRS</code> loses <code>%DB_IRISSYS:READ</code> -> the second leg goes red.</p>
Method TestACallerShortOfAPairIsRefusedBeforeAnyRead()
{
    Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tVendorText)
    Do $$$AssertEquals(tMapped.code, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED, "the gate's refusal is PORT.ACCESSDENIED")
    Set tPairs = $ListFromString($Parameter(..#PORT, "PAIRS"))
    Do $$$AssertEquals($ListLength(tPairs), 2, "the port declares two pairs")
    For tI = 1:1:$ListLength(tPairs) {
        Set tPair = $List(tPairs, tI)
        For tType = "LIST", "GET" {
            Do $ClassMethod(..#SEAM, "Clear")
            Do $ClassMethod(..#SEAM, "DenyPair", tPair)
            Set tSC = ..Call(..#SEAM, tType, "id", ..PreparedProbe, .tResult, .tHttp, .tFault)
            Do $$$AssertEquals(tHttp, 403, tType _ " without " _ tPair _ ": refused 403")
            Do $$$AssertEquals(..CodeOf(tFault), tMapped.code, tType _ " without " _ tPair _ ": the gate's refusal")
            Do $$$AssertEquals($Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: ""), tPair, tType _ " without " _ tPair _ ": it names the pair")
            Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", tType _ " without " _ tPair _ ": no vendor read was made")
        }
    }
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "DenyPair", $List(tPairs, 2))
    Set tSC = ..Call(..#SEAM, "LIST", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: ""), $List(tPairs, 2), "a caller holding the first pair is refused the second")
}

/// <p>Any other request type is 501, a body is refused, and a cap that is not a whole number above zero is 500; each before a page is read.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.PortalResourcePort</class>'s <code>Rows</code> admits a cap of zero -> the cap assertion goes red.</p>
Method TestOtherTypesAndAnInvalidCapAreRefused()
{
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = ..Call(..#SEAM, "SET", "id", ..PreparedProbe, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ ..CodeOf(tFault), "501|" _ ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "a type the port does not serve is 501")
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "LIST", .tQuery, {"a": 1}, .tResult, .tBodyHttp, .tBodyFault)
    Do $$$AssertEquals(tBodyHttp _ "|" _ ..CodeOf(tBodyFault), "500|" _ ##class(OcuPilot.Api.Error).#INTERNAL, "a body is refused")
    For tCap = 0, -1, "x", "1.5" {
        Set tSC = ..Call(..#SEAM, "LIST", "maxRows", tCap, .tCapResult, .tCapHttp, .tCapFault)
        Do $$$AssertEquals(tCapHttp, 500, "a cap of '" _ tCap _ "' is refused")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "none of them read a page")
}

/// <p>The screen's own read answers the planted rows through the executor, capped, and reports the cut when it left a row out.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Read</class> asks the portal resource port for no more than the cap -> the truncation assertion goes red.</p>
Method TestTheScreenReadsTheSameRowsCappedAndReportsACut()
{
    Do $$$AssertStatusOK(..Plant(..PreparedProbe, ..#MARKER), "the probe page is assigned its marker")
    Do $$$AssertStatusOK(..Plant(..#DECLARED, ..#OTHERMARKER), "and a second page")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 100000, .tScreen, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the screen's read answers")
    If '$IsObject($Get(tScreen)) Quit
    Set tProbe = ..RowFor(tScreen.%Get("rows"), ..PreparedProbe)
    Do $$$AssertTrue($IsObject(tProbe) && (tProbe.%Get("Resource") = ..#MARKER), "it carries the planted row with its marker")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 1, .tCapped, .tCappedHttp, .tCappedFault)
    Do $$$AssertEquals(tCappedHttp, 200, "a read at a cap of one answers")
    If '$IsObject($Get(tCapped)) Quit
    Do $$$AssertEquals(tCapped.%Get("rows").%Size() _ "|" _ ''tCapped.%Get("truncated"), "1|1", "one row, and the cut is reported")
}

}
