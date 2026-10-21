/// <p>Pins the navigation map's answer for Story 20.32's link screens over HTTP (AD-5, AD-8, AD-47, AD-65; AC1, AC2, AC6): with analytics turned on for
/// <code>USER</code>, <code>GET /api/ocupilot/navigation?ns=USER</code> as <code>_SYSTEM</code> carries <code>href</code> on exactly the three
/// <code>external</code> screens, each the address <class>OcuPilot.Screen.ExternalPage</class> composes (the default application, a slash, the page file and the
/// namespace); the same request for <code>HSCUSTOM</code> carries none; a principal holding the developer floor and nothing of DeepSee is refused Architect and
/// Analyzer naming each one's own pair and is offered the User Portal, a principal that also holds <code>%DeepSee_Architect:USE</code> is refused Analyzer alone, and a
/// principal holding only the <code>%DeepSee_ArchitectEdit</code> and <code>%DeepSee_AnalyzerEdit</code> resources the vendor pages also admit is refused both naming the
/// narrower pairs (Story 20.32's named limit); and <code>shell.privileges.read</code>, which answers the same map, conforms to its result schema there.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes users and roles named
/// <code>OcuP2032*</code> and, through <class>OcuPilot.Test.AnalyticsProbe</class>, turns analytics on for <code>USER</code>. The principals and the probe are removed
/// after the last test. <code>HSCUSTOM</code> is read as the instance ships it, with analytics off; nothing in the suite turns it on.</p>
Class OcuPilot.Test.AnalyticsLinkMap Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter NAMESPACE = "USER";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by <code>;</code>: the developer
/// floor and READ on <code>USER</code>, the same with the Architect's pair, and the same with the two <code>*Edit</code> resources and neither narrower pair.</p>
Parameter PRINCIPALS = "OcuP2032Floor:%Development:U,%DB_USER:R;OcuP2032Architect:%Development:U,%DB_USER:R,%DeepSee_Architect:U;OcuP2032Edit:%Development:U,%DB_USER:R,%DeepSee_ArchitectEdit:U,%DeepSee_AnalyzerEdit:U";

Parameter FLOOR = "OcuP2032Floor";

Parameter ARCHITECT = "OcuP2032Architect";

Parameter EDITONLY = "OcuP2032Edit";

/// <p>The three links, <code>&lt;route&gt;|&lt;tool identifier&gt;|&lt;page file&gt;</code>, separated by <code>;</code>, in position order.</p>
Parameter LINKS = "analytics/architect|analytics.architect|_DeepSee.UI.Architect.zen;analytics/analyzer|analytics.analyzer|_DeepSee.UI.Analyzer.zen;analytics/user-portal|analytics.userportal|_DeepSee.UserPortal.Home.zen";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsLinkMap creates and deletes users and roles and turns analytics on in USER, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP2032Map" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals(..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.AnalyticsLinkMap")
    If $$$ISOK(tSC) {
        For tCase = $ListBuild(..#FLOOR, "%Development", "USE", 1), $ListBuild(..#FLOOR, "%DeepSee_Architect", "USE", 0), $ListBuild(..#FLOOR, "%DeepSee_Analyzer", "USE", 0), $ListBuild(..#ARCHITECT, "%DeepSee_Architect", "USE", 1), $ListBuild(..#ARCHITECT, "%DeepSee_Analyzer", "USE", 0), $ListBuild(..#EDITONLY, "%DeepSee_ArchitectEdit", "USE", 1), $ListBuild(..#EDITONLY, "%DeepSee_AnalyzerEdit", "USE", 1), $ListBuild(..#EDITONLY, "%DeepSee_Architect", "USE", 0), $ListBuild(..#EDITONLY, "%DeepSee_Analyzer", "USE", 0) {
            If $SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) '= $List(tCase, 4) {
                Set tSC = $$$ERROR($$$GeneralError, "the principal " _ $List(tCase, 1) _ "'s " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " did not read back as declared")
                Quit
            }
        }
    }
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the principals, their roles and the probe; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsLinkMap left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsLinkMap left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>The navigation map <var>pUser</var> is served for <var>pNamespace</var>, or <code>""</code> when it does not answer 200. <var>pUser</var> <code>""</code>
/// is the test account the other wire classes use.</p>
Method MapFor(pNamespace As %String, pUser As %String = "") As %DynamicObject
{
    Set tMap = ""
    Set tUser = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestUsername(), 1: pUser)
    Set tPassword = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestPassword(), 1: ..PreparedPassword)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/navigation?ns=" _ pNamespace, tUser, tPassword, .tStatus, .tBody)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit ""
    Try {
        Set tMap = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set tMap = ""
    }
    Quit tMap
}

/// <p>The screens of <var>pMap</var> that carry <code>href</code>, as <code>route=href</code> separated by <code>;</code>, in map order.</p>
ClassMethod Addresses(pMap As %DynamicObject) As %String
{
    Set tOut = ""
    If '$IsObject(pMap) Quit "unreadable"
    Set tAreas = pMap.areas.%GetIterator()
    While tAreas.%GetNext(.tAreaIndex, .tArea) {
        Set tScreens = tArea.screens.%GetIterator()
        While tScreens.%GetNext(.tScreenIndex, .tScreen) {
            If tScreen.%IsDefined("href") Set tOut = tOut _ $Select(tOut = "": "", 1: ";") _ tScreen.route _ "=" _ tScreen.href
        }
    }
    Quit tOut
}

/// <p>The screen entry for <var>pRoute</var> in <var>pMap</var>, or <code>""</code>.</p>
ClassMethod EntryFor(pMap As %DynamicObject, pRoute As %String) As %DynamicObject
{
    Set tFound = ""
    If '$IsObject(pMap) Quit tFound
    Set tAreas = pMap.areas.%GetIterator()
    While (tFound = "") && tAreas.%GetNext(.tAreaIndex, .tArea) {
        Set tScreens = tArea.screens.%GetIterator()
        While (tFound = "") && tScreens.%GetNext(.tScreenIndex, .tScreen) {
            If tScreen.route = pRoute Set tFound = tScreen
        }
    }
    Quit tFound
}

/// <p>The address <var>pFile</var> has in <var>pNamespace</var>, composed here from the namespace's default application, so a test of
/// <method>OcuPilot.Screen.ExternalPage.Href</method> does not ask it for its own answer.</p>
ClassMethod Expected(pFile As %String, pNamespace As %String) As %String
{
    Set tApplication = $System.CSP.GetDefaultApp(pNamespace)
    If $Extract(tApplication, 1) '= "/" Set tApplication = "/" _ tApplication
    If $Extract(tApplication, *) '= "/" Set tApplication = tApplication _ "/"
    Quit tApplication _ pFile _ "?$NAMESPACE=" _ pNamespace
}

/// <p>AC1, AC6: as <code>_SYSTEM</code>, the map for <code>USER</code>, which reports analytics, carries <code>href</code> on exactly the three links, in map order,
/// each the address composed from <code>USER</code>'s default application; and the map for <code>HSCUSTOM</code>, which does not, carries none.</p>
/// <p>Mutation (Rule 19): set <code>href</code> in <method>OcuPilot.Kernel.Shell.Navigation.Payload</method> on every screen entry, to any address -- the exactly-three leg goes red.
/// Drop the trailing <code>/</code> normalization from <method>OcuPilot.Screen.ExternalPage.Href</method> -- the address legs go red.</p>
Method TestTheMapAnswersEachAddress()
{
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Reports"), "USER reports analytics for this test")
    Set tMap = ..MapFor(..#NAMESPACE)
    Do $$$AssertTrue($IsObject(tMap), "the map for USER answers 200 and parses")
    If '$IsObject(tMap) Quit
    Set tWant = ""
    For tI = 1:1:$Length(..#LINKS, ";") {
        Set tLink = $Piece(..#LINKS, ";", tI)
        Set tWant = tWant _ $Select(tWant = "": "", 1: ";") _ $Piece(tLink, "|", 1) _ "=" _ ..Expected($Piece(tLink, "|", 3), ..#NAMESPACE)
        Set tClass = ##class(OcuPilot.Screen.Registry).DescriptorForRoute($Piece(tLink, "|", 1))
        Do $$$AssertNotEquals(tClass, "", $Piece(tLink, "|", 1) _ " is a registered route")
        If tClass '= "" Do $$$AssertEquals($ClassMethod(tClass, "ToolIdentifier"), $Piece(tLink, "|", 2), $Piece(tLink, "|", 1) _ " declares the tool identifier the vocabulary is keyed by")
        Do $$$AssertEquals(##class(OcuPilot.Screen.ExternalPage).Href($Piece(tLink, "|", 2), ..#NAMESPACE), ..Expected($Piece(tLink, "|", 3), ..#NAMESPACE), $Piece(tLink, "|", 2) _ ": ExternalPage.Href is the default application's address")
    }
    Do $$$AssertEquals(..Addresses(tMap), tWant, "exactly the three links carry an address, each composed from USER's default application")
    Set tArchitect = ..EntryFor(tMap, "analytics/architect")
    Do $$$AssertEquals($Select($IsObject(tArchitect): tArchitect.allowed _ "|" _ tArchitect.href, 1: ""), "1|/csp/user/_DeepSee.UI.Architect.zen?$NAMESPACE=USER", "and Architect, to _SYSTEM, is allowed with the address the story's matrix gives")

    Set tMap = ..MapFor("HSCUSTOM")
    Do $$$AssertTrue($IsObject(tMap), "the map for HSCUSTOM answers 200 and parses")
    If '$IsObject(tMap) Quit
    Do $$$AssertEquals(..Addresses(tMap), "", "HSCUSTOM does not report analytics, so no entry carries an address")
    Set tAnalytics = ##class(OcuPilot.Test.Descriptor).AreaEntry(tMap.areas, "analytics")
    Do $$$AssertTrue($IsObject(tAnalytics) && (tAnalytics.applies = 0), "and its Analytics area does not apply")
}

/// <p>AC2: a principal holding the developer floor and nothing of DeepSee is refused Architect and Analyzer, each naming its own pair, and is offered the User
/// Portal with its address; a principal that also holds <code>%DeepSee_Architect:USE</code> is offered Architect and refused Analyzer alone.</p>
/// <p>Mutation (Rule 19): drop <code>%DeepSee_Analyzer:USE</code> from <code>AnalyticsAnalyzerLink</code> -- the floor principal then opens Analyzer and this goes red.</p>
Method TestAPrincipalWithoutAnOwnPairIsRefusedNamingIt()
{
    Set tAddress = ..Expected("_DeepSee.UserPortal.Home.zen", ..#NAMESPACE)
    Set tMap = ..MapFor(..#NAMESPACE, ..#FLOOR)
    Do $$$AssertTrue($IsObject(tMap), "the map for USER answers the developer-floor principal")
    If '$IsObject(tMap) Quit
    Set tArchitect = ..EntryFor(tMap, "analytics/architect")
    Set tAnalyzer = ..EntryFor(tMap, "analytics/analyzer")
    Set tPortal = ..EntryFor(tMap, "analytics/user-portal")
    Do $$$AssertEquals($Select($IsObject(tArchitect): tArchitect.allowed _ "|" _ tArchitect.failedPair, 1: ""), "0|%DeepSee_Architect:USE", "Architect is refused naming its own pair")
    Do $$$AssertEquals($Select($IsObject(tAnalyzer): tAnalyzer.allowed _ "|" _ tAnalyzer.failedPair, 1: ""), "0|%DeepSee_Analyzer:USE", "Analyzer is refused naming its own pair")
    Do $$$AssertEquals($Select($IsObject(tPortal): tPortal.allowed _ "|" _ tPortal.%Get("failedPair") _ "|" _ tPortal.href, 1: ""), "1||" _ tAddress, "the User Portal is allowed, with its address")

    Set tMap = ..MapFor(..#NAMESPACE, ..#ARCHITECT)
    Do $$$AssertTrue($IsObject(tMap), "the map for USER answers the principal holding the Architect's pair")
    If '$IsObject(tMap) Quit
    Set tArchitect = ..EntryFor(tMap, "analytics/architect")
    Set tAnalyzer = ..EntryFor(tMap, "analytics/analyzer")
    Do $$$AssertEquals($Select($IsObject(tArchitect): tArchitect.allowed _ "|" _ tArchitect.%Get("failedPair"), 1: ""), "1|", "Architect is allowed once its own pair is held")
    Do $$$AssertEquals($Select($IsObject(tAnalyzer): tAnalyzer.allowed _ "|" _ tAnalyzer.failedPair, 1: ""), "0|%DeepSee_Analyzer:USE", "and Analyzer stays refused naming its own")
}

/// <p>AC2, Story 20.32's named limit: a principal holding the developer floor and only <code>%DeepSee_ArchitectEdit:USE</code> and <code>%DeepSee_AnalyzerEdit:USE</code>,
/// the resources the vendor pages' own <code>RESOURCE</code> lists also admit, is refused Architect and Analyzer naming the narrower pair each screen declares
/// (<code>%DeepSee_Architect:USE</code>, <code>%DeepSee_Analyzer:USE</code>), is offered the User Portal with its address, and a refused entry stays on the map with its
/// address, so the side bar draws it unavailable rather than hiding it.</p>
/// <p>Mutation (Rule 19): declare <code>%DeepSee_ArchitectEdit:USE</code> in place of <code>%DeepSee_Architect:USE</code> as <code>AnalyticsArchitectLink</code>'s own pair -- the
/// Architect leg goes red, because the Edit-only principal then opens it.</p>
Method TestAnEditOnlyHolderIsRefusedNamingTheNarrowerPair()
{
    Set tMap = ..MapFor(..#NAMESPACE, ..#EDITONLY)
    Do $$$AssertTrue($IsObject(tMap), "the map for USER answers the principal holding only the Edit resources")
    If '$IsObject(tMap) Quit
    Set tArchitect = ..EntryFor(tMap, "analytics/architect")
    Set tAnalyzer = ..EntryFor(tMap, "analytics/analyzer")
    Set tPortal = ..EntryFor(tMap, "analytics/user-portal")
    Do $$$AssertEquals($Select($IsObject(tArchitect): tArchitect.allowed _ "|" _ tArchitect.failedPair _ "|" _ tArchitect.href, 1: ""), "0|%DeepSee_Architect:USE|" _ ..Expected("_DeepSee.UI.Architect.zen", ..#NAMESPACE), "Architect is refused naming the narrower pair, though %DeepSee_ArchitectEdit:USE is held, and stays on the map with its address")
    Do $$$AssertEquals($Select($IsObject(tAnalyzer): tAnalyzer.allowed _ "|" _ tAnalyzer.failedPair _ "|" _ tAnalyzer.href, 1: ""), "0|%DeepSee_Analyzer:USE|" _ ..Expected("_DeepSee.UI.Analyzer.zen", ..#NAMESPACE), "Analyzer is refused naming the narrower pair, though %DeepSee_AnalyzerEdit:USE is held, and stays on the map with its address")
    Do $$$AssertEquals($Select($IsObject(tPortal): tPortal.allowed _ "|" _ tPortal.%Get("failedPair") _ "|" _ tPortal.href, 1: ""), "1||" _ ..Expected("_DeepSee.UserPortal.Home.zen", ..#NAMESPACE), "and the User Portal, whose pair is the Analytics menu's alone, is allowed with its address")
}

/// <p>AC6: <code>shell.privileges.read</code>, which answers the navigation map, conforms to its declared result schema where the links carry
/// addresses: scoped to <code>USER</code>, its answer carries the three <code>href</code>s and passes the schema the tool registry holds for it.</p>
/// <p>Mutation (Rule 19): drop <code>href</code> from the screen items of <method>OcuPilot.Kernel.Shell.PrivilegesRead.ResultSchema</method> -- the
/// conformance leg goes red, naming the undeclared property.</p>
Method TestThePrivilegesToolConformsWhereLinksCarryAddresses()
{
    Set tRegistry = "OcuPilot.Screen.Tool.Registry"
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Try {
        Do $$$AssertStatusOK($ClassMethod(tRegistry, "Resolve", "shell.privileges.read", .tTool), "the registry lists shell.privileges.read")
        If '$IsObject($Get(tTool)) Quit
        Do $$$AssertStatusOK($ClassMethod(tRegistry, "InvokeTool", tTool, {}, 200, .tResult, .tHttp, .tFault), "it answers in USER")
        If '$IsObject($Get(tResult)) Quit
        Do $$$AssertEquals($Length(..Addresses(tResult), ";"), 3, "its answer carries the three links' addresses: " _ ..Addresses(tResult))
        Do $$$AssertStatusOK($ClassMethod(tRegistry, "ValidateArguments", $ClassMethod(tRegistry, "ResultSchemaOf", tTool), tResult, .tProblem), "and conforms to its declared result schema " _ $Get(tProblem))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the tool runs in USER")
    }
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

}
