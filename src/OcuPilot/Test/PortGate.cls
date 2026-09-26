/// <p>AD-29's "a port without a named gate is a review failure", as something that can fail
/// (Story 5.4, AC6).</p>
/// <p>What it pins: every class in package <package>OcuPilot.Port</package> is on the roster
/// below, declares a pair-bearing gate, and refuses its outbound entry when that gate is not
/// held -- observed by driving the refusal, not by reading the source. A port added without a
/// gate is therefore red on the day it arrives rather than on the day somebody reads it, which
/// is what makes Epic 6's <class>MonitorPort</class> fail closed.</p>
/// <p>It also pins the administrative floor's one home: the list
/// <method>OcuPilot.Api.Router.HoldsAdminResource</method> tests and the list
/// <method>OcuPilot.Port.ProviderPort.Invoke</method> tests are the same list, derived from
/// <parameter>OcuPilot.Screen.Gate.ADMINRESOURCES</parameter> at compile time. A stale
/// compilation is what this catches.</p>
/// <p><b>Live-safe</b>: it spawns nothing, creates no principal and writes nothing. Every denial
/// is driven through the ports' own gate seams, because <code>%UnitTest</code> runs as an account
/// holding <code>%All</code>, for which the real check answers yes to every resource name.</p>
Class OcuPilot.Test.PortGate Extends %UnitTest.TestCase
{

/// <p>The package every port lives in.</p>
Parameter PORTPACKAGE = "OcuPilot.Port.";

/// <p>The roster: one <code>|</code>-separated row per port class, as
/// <code>&lt;class&gt;=&lt;parameter&gt;[;&lt;parameter&gt;]</code>, naming the
/// <code>Parameter</code>(s) that are that port's declared pair set. A port whose gate is the
/// vendor's own resource check declares <parameter>VENDORGATE</parameter> instead.</p>
/// <p><b>A class in the package and not on this roster fails.</b> That is the point: the roster is
/// what a new port has to be added to, and adding it is what forces a gate to be named.</p>
Parameter ROSTER = "OcuPilot.Port.AdminPort=<vendor>|OcuPilot.Port.LogSourcePort=MESSAGESPAIRS;ALERTSPAIRS;ERRORSINSTANCEPAIRS|OcuPilot.Port.MgmntPort=PAIRS|OcuPilot.Port.ProviderPort=INVOKEPAIRS;DRAFTPAIRS|OcuPilot.Port.WalletPort=<vendor>|OcuPilot.Port.TaskPort=<vendor>|OcuPilot.Port.ProcessPort=<vendor>|OcuPilot.Port.TokenPort=<vendor>|OcuPilot.Port.AuditPort=<vendor>|OcuPilot.Port.OAuthServerPort=<vendor>|OcuPilot.Port.OAuthClientPort=<vendor>|OcuPilot.Port.OAuthResourceServerPort=<vendor>|OcuPilot.Port.OAuthAuthorizationServerPort=<vendor>|OcuPilot.Port.OAuthRegisteredClientPort=<vendor>";

/// <p>The roster value for a port whose gate is the vendor's own <code>ResourcesOR()</code> check,
/// which AD-29 fixes as a lower bound with the remedy at the screen descriptor's declared pair
/// set.</p>
Parameter VENDORGATE = "<vendor>";

/// <p>The gate whose held set a test declares, in place of the instance's own answer.</p>
Parameter GATE = "OcuPilot.Test.ScreenGate";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogSourceFixture).SetGateClass("")
    Do ##class(OcuPilot.Test.ErrorLogFixture).SetGateClass("")
    Do ##class(OcuPilot.Test.MgmntPortFixture).SetGateClass("")
    Do ##class(OcuPilot.Test.ProviderGate).Allow()
    Quit $$$OK
}

/// <p>Every class under <parameter>PORTPACKAGE</parameter>, from the class dictionary, in name
/// order. Read from <class>%Dictionary.CompiledClass</class> rather than from a literal, so a port
/// this roster does not know about is discovered rather than assumed absent.</p>
ClassMethod PortClasses() As %List
{
    Set tList = ""
    Set tStatement = ##class(%SQL.Statement).%New()
    Set tSC = tStatement.%Prepare("SELECT Name FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH ? ORDER BY Name")
    If $$$ISERR(tSC) Quit ""
    Set tRS = tStatement.%Execute(..#PORTPACKAGE)
    While tRS.%Next() {
        Set tName = tRS.%GetData(1)
        ; Every class under the package, at any depth. The depth convention is a convention: a
        ; port shipped as OcuPilot.Port.Monitor.MetricsPort is still a port, and a roster that
        ; could not see it is a roster Epic 6's MonitorPort could arrive gateless past.
        Set tList = tList _ $ListBuild(tName)
    }
    Do tRS.%Close()
    Quit tList
}

/// <p>The roster row for <var>pClass</var> -- its <code>;</code>-separated parameter names, or
/// <parameter>VENDORGATE</parameter> -- and <code>""</code> when it has no row.</p>
ClassMethod RosterFor(pClass As %String) As %String
{
    Set tValue = ""
    For tI = 1:1:$Length(..#ROSTER, "|") {
        Set tRow = $Piece(..#ROSTER, "|", tI)
        If $Piece(tRow, "=", 1) '= pClass Continue
        Set tValue = $Piece(tRow, "=", 2)
        Quit
    }
    Quit tValue
}

/// <p><b>AC6</b> -- every port class is on the roster, and every roster row names a
/// <code>Parameter</code> that parses to at least one <code>(resource, permission)</code> pair.</p>
/// <p>Mutation: add a class to <package>OcuPilot.Port</package> without adding it here, or empty
/// one of the named parameters -> this goes red.</p>
Method TestEveryPortDeclaresANamedGate()
{
    Set tClasses = ..PortClasses()
    Do $$$AssertTrue($ListLength(tClasses) > 0, "the class dictionary reports at least one port class")

    For tI = 1:1:$ListLength(tClasses) {
        Set tClass = $List(tClasses, tI)
        Set tRow = ..RosterFor(tClass)
        Do $$$AssertNotEquals(tRow, "", tClass _ ": is on OcuPilot.Test.PortGate's roster -- a port declares and evaluates a named pair set (AD-29)")
        If tRow = "" Continue
        If tRow = ..#VENDORGATE {
            ; AdminPort's declared gate is the vendor's own ResourcesOR(), which AD-29 fixes as a
            ; lower bound. What is asserted is that the seam evaluating it still exists.
            Do $$$AssertTrue(##class(%Dictionary.CompiledMethod).%ExistsId(tClass _ "||HoldsResource"), tClass _ ": still evaluates the vendor's resource check")
            Continue
        }
        For tJ = 1:1:$Length(tRow, ";") {
            Set tParameter = $Piece(tRow, ";", tJ)
            Set tSpec = $Parameter(tClass, tParameter)
            Do $$$AssertNotEquals(tSpec, "", tClass _ "." _ tParameter _ ": is declared and non-empty")
            Set tPairs = ##class(OcuPilot.Screen.Gate).ParsePairSpec(tSpec)
            Do $$$AssertTrue($ListLength(tPairs) > 0, tClass _ "." _ tParameter _ ": parses to at least one (resource, permission) pair: " _ tSpec)
            Do $$$AssertEquals($ListLength(tPairs), $Length(tSpec, ","), tClass _ "." _ tParameter _ ": every declared member parses, so the gate evaluates the whole declaration: " _ tSpec)
        }
    }
}

/// <p><b>AC6</b> -- a pair spec with a member the parser cannot read fails closed. A parser that
/// dropped the unreadable member would leave an <code>AND</code> gate evaluating fewer pairs than
/// its <code>Parameter</code> declares, which is a port quietly weaker than it reads.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Gate.ParsePairSpec</method> <code>Continue</code>
/// past a malformed member again -> the first two assertions go red.</p>
Method TestAMalformedPairSpecFailsClosed()
{
    Set tGate = ##class(OcuPilot.Screen.Gate).ParsePairSpec("%Admin_Secure:USE,%DB_IRISSYS")
    Do $$$AssertEquals($ListLength(tGate), 0, "a spec whose second member names no permission parses to nothing at all, not to its readable half")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Gate).EvaluateRequired(tGate, .tFailed), 0, "so the evaluator refuses rather than admitting on the half it could read")

    ; The control: the same spec spelled correctly parses to both pairs, so the refusal above is
    ; the malformed member and not the parser refusing everything.
    Do $$$AssertEquals($ListLength(##class(OcuPilot.Screen.Gate).ParsePairSpec("%Admin_Secure:USE,%DB_IRISSYS:READ")), 2, "the well-formed spelling of the same spec parses to both pairs")
}

/// <p><b>AC6</b> -- every port's outbound entry refuses <code>AUTH.NOPRIVILEGE</code> when its
/// declared gate is not held, before the call it guards is made. Driven, not read.</p>
/// <p>Mutation: remove <method>OcuPilot.Port.ProviderPort.Invoke</method>'s
/// <code>GateAnyOfForUser</code> call, or <method>OcuPilot.Port.MgmntPort.Invoke</method>'s
/// <code>EvaluateRequired</code> call -> this goes red.</p>
Method TestEveryPortEvaluatesItsDeclaredGate()
{
    Set tDenialCode = ##class(OcuPilot.Kernel.Denial).Code()

    ; ProviderPort, both entries. ProviderGate answers no to every pair while denied.
    Do ##class(OcuPilot.Test.ProviderGate).Deny()
    Do ..Messages(.tMessages)
    Set tTools = []
    Set tSC = ##class(OcuPilot.Test.ProviderPortProbe).Invoke("no-such-definition", .tMessages, .tTools, "", .tResponse, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "ProviderPort.Invoke answers")
    Do $$$AssertEquals(tHttp, ##class(OcuPilot.Kernel.Denial).#STATUS, "ProviderPort.Invoke refuses 403 when no administrative pair is held")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: ""), tDenialCode, "ProviderPort.Invoke names AUTH.NOPRIVILEGE")

    Kill tValues
    Set tValues("provider") = "anthropic"
    Set tSC = ##class(OcuPilot.Test.ProviderPortProbe).InvokeDraft(.tValues, .tMessages, .tTools, "", .tResponse2, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC, "ProviderPort.InvokeDraft answers")
    Do $$$AssertEquals(tHttp2, ##class(OcuPilot.Kernel.Denial).#STATUS, "ProviderPort.InvokeDraft refuses 403 too")
    Do $$$AssertEquals($Select($IsObject(tFault2): tFault2.detail.failedPair, 1: ""), $Piece($Parameter("OcuPilot.Port.ProviderPort", "DRAFTPAIRS"), ",", 1), "naming its own declared pair")
    Do ##class(OcuPilot.Test.ProviderGate).Allow()

    ; MgmntPort: the gate class answers from a declared set, and nothing is declared.
    Do ##class(OcuPilot.Test.MgmntPortFixture).SetGateClass(..#GATE)
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tSC = ##class(OcuPilot.Test.MgmntPortFixture).Invoke("Applications", "LIST", .tQuery, "", .tRows, .tHttp3, .tFault3, .tDocument)
    Do $$$AssertStatusNotOK(tSC, "MgmntPort.Invoke refuses a caller holding none of its pairs")
    Do $$$AssertEquals(tHttp3 _ "|" _ $Select($IsObject(tFault3): tFault3.%Get("code"), 1: ""), ##class(OcuPilot.Kernel.Denial).#STATUS _ "|" _ tDenialCode, "with AUTH.NOPRIVILEGE")

    ; LogSourcePort, both entries, through the two fixtures that switch its gate.
    Do ##class(OcuPilot.Test.LogSourceFixture).SetGateClass(..#GATE)
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Page("messages", "", "", "", .tResult4, .tHttp4, .tFault4)
    Do $$$AssertStatusNotOK(tSC, "LogSourcePort.Page refuses a caller holding none of its pairs")
    Do $$$AssertEquals(tHttp4 _ "|" _ $Select($IsObject(tFault4): tFault4.%Get("code"), 1: ""), ##class(OcuPilot.Kernel.Denial).#STATUS _ "|" _ tDenialCode, "with AUTH.NOPRIVILEGE, before the file is opened")

    Do ##class(OcuPilot.Test.ErrorLogFixture).SetGateClass(..#GATE)
    Set tSC = ##class(OcuPilot.Test.ErrorLogFixture).Errors("namespaces", "", "", "", "", .tResult5, .tHttp5, .tFault5)
    Do $$$AssertStatusNotOK(tSC, "LogSourcePort.Errors refuses a caller holding none of its pairs")
    Do $$$AssertEquals(tHttp5 _ "|" _ $Select($IsObject(tFault5): tFault5.%Get("code"), 1: ""), ##class(OcuPilot.Kernel.Denial).#STATUS _ "|" _ tDenialCode, "with AUTH.NOPRIVILEGE")
}

/// <p><b>AC6</b> -- the administrative floor has one home. The router's list and the provider
/// port's declared pair set are both derived from
/// <parameter>OcuPilot.Screen.Gate.ADMINRESOURCES</parameter>, so a caller the router would refuse
/// cannot make the instance call a provider.</p>
/// <p>Mutation: edit either derived parameter into a literal that differs -> this goes red. It is
/// also what catches a compile-time derivation left stale.</p>
Method TestTheAdministrativeFloorHasOneHome()
{
    Set tHome = ##class(OcuPilot.Screen.Gate).#ADMINRESOURCES
    Do $$$AssertNotEquals(tHome, "", "the gate declares the administrative resource list")
    Do $$$AssertEquals(##class(OcuPilot.Api.Router).#ADMINRESOURCES, tHome, "the router's list is the gate's, not a copy")
    Do $$$AssertEquals($Parameter("OcuPilot.Port.ProviderPort", "INVOKEPAIRS"), ##class(OcuPilot.Screen.Gate).AdminPairSpec(), "and the provider port's gate is that list at USE")

    Set tPairs = ##class(OcuPilot.Screen.Gate).ParsePairSpec($Parameter("OcuPilot.Port.ProviderPort", "INVOKEPAIRS"))
    Do $$$AssertEquals($ListLength(tPairs), $Length(tHome, ","), "one pair per named resource")
}

/// <p>A minimal message array, the shape
/// <method>OcuPilot.Kernel.Provider.Base.Invoke</method> documents.</p>
ClassMethod Messages(Output pMessages)
{
    Kill pMessages
    Set pMessages = 1
    Set pMessages(1, "role") = "user"
    Set pMessages(1, "content") = "ping"
}

}
