/// <p>The egress roster (AD-1, AD-11 rule 5, AD-42): the only shipped OcuPilot code that opens an
/// outbound connection itself is the classes <parameter>ROSTER</parameter> declares. Over every compiled class in
/// package <code>OcuPilot</code> outside <code>OcuPilot.Test</code>, it collects the classes whose
/// method code (comment lines removed) constructs an outbound client or calls a vendor method that
/// fetches, and holds that set equal to the roster in both directions, naming any class that
/// differs.</p>
/// <p><b>The patterns</b> (<method>Constructs</method>, case-insensitive): a
/// <code>##class(%Net.*).%New(</code> or <code>$ClassMethod("%Net.*", "%New"</code> construction of
/// any <code>%Net</code> class, a <code>|TCP|</code> device name, and a call to
/// <code>GetServerMetadata</code> or <code>RefreshJWKS</code>. Measured on
/// <code>ocupilot-b-ci</code> 2026-09-26: the <code>%Net</code> construction matched
/// <class>OcuPilot.Kernel.Provider.Base</class> and <class>OcuPilot.Install.Smoke</class>, the
/// vendor fetchers matched <class>OcuPilot.Port.OAuthServerPort</class> and
/// <class>OcuPilot.Port.OAuthRegisteredClientPort</class>, and <code>|TCP|</code> matched no
/// shipped class. The same scan over <package>OcuPilot.Test</package> finds
/// <class>OcuPilot.Test.Http</class> and <class>OcuPilot.Test.OAuthIssuerFixture</class>, which is
/// the control that the empty answers are a measurement.</p>
/// <p><b>What the scan cannot see.</b> It matches OcuPilot's own method code, so a connection the
/// vendor opens behind an admin-API type OcuPilot sends is outside it. Three ship:
/// <code>Security.SSLConfig/TEST</code> and <code>Security.LDAP/TEST</code>
/// (<class>OcuPilot.Port.AdminPort</class>'s
/// <parameter>OcuPilot.Port.AdminPort.CONNECTIONTESTTYPES</parameter>, each sent only by its editor's
/// own test route, which no tool issues) and <code>REGISTERCLIENT</code>
/// (<class>OcuPilot.Port.OAuthClientPort</class>, a write tool's type, sent only at confirm).</p>
/// <p><b>Live-safe.</b> It reads the class dictionary and writes nothing.</p>
Class OcuPilot.Test.InjectionEgress Extends %UnitTest.TestCase
{

/// <p>One row per shipped class that may open an outbound connection, <code>class=reason</code>,
/// separated by <code>;</code>. A turn reaches only the first; the vendor fetchers are reached only
/// from a user's own request (inference: from their callers, the discover route and confirm).</p>
Parameter ROSTER = "OcuPilot.Install.Smoke=operator-run smoke, from the instance to itself;OcuPilot.Kernel.Provider.Base=the turn's provider call;OcuPilot.Port.OAuthRegisteredClientPort=user-originated route or confirm only;OcuPilot.Port.OAuthServerPort=user-originated route or confirm only";

/// <p>The reasons a row may carry.</p>
Parameter REASONS = "the turn's provider call;user-originated route or confirm only;operator-run smoke, from the instance to itself";

/// <p>Whether one line of method code opens or fetches: a <code>%Net</code> construction, a
/// <code>|TCP|</code> device, or a vendor fetcher call.</p>
ClassMethod Constructs(pLine As %String) As %Boolean
{
    If $Locate(pLine, "(?i)##class\(\s*%Net\.[A-Za-z0-9.]+\s*\)\s*\.\s*%New\(") Quit 1
    If $Locate(pLine, "(?i)\$ClassMethod\(\s*""%Net\.[A-Za-z0-9.]+""\s*,\s*""%New""") Quit 1
    If $Locate(pLine, "(?i)\|TCP\|") Quit 1
    If $Locate(pLine, "(?i)\b(GetServerMetadata|RefreshJWKS)\b") Quit 1
    Quit 0
}

/// <p>The compiled classes in package <code>OcuPilot</code> -- outside <code>OcuPilot.Test</code>
/// unless <var>pTests</var> is 1, and only it when so -- whose own method code
/// <method>Constructs</method>, comma-separated in name order. A class whose definition cannot be
/// opened is reported as <code>name(unreadable)</code>, never scored as no match.</p>
ClassMethod Sites(pTests As %Boolean = 0) As %String
{
    Set tFound = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH 'OcuPilot.' ORDER BY Name")
    If tRS.%SQLCODE < 0 Quit "SQLCODE=" _ tRS.%SQLCODE
    While tRS.%Next() {
        Set tName = tRS.%GetData(1)
        If (tName [ "OcuPilot.Test.") '= ''pTests Continue
        Set tDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(tName, 0, .tSC)
        If '$IsObject(tDefinition) {
            Set tFound = tFound _ $Select(tFound = "": "", 1: ",") _ tName _ "(unreadable)"
            Continue
        }
        Set tHit = 0
        For tI = 1:1:tDefinition.Methods.Count() {
            Set tCode = tDefinition.Methods.GetAt(tI).Implementation
            Do tCode.Rewind()
            While 'tCode.AtEnd && 'tHit {
                Set tLine = tCode.ReadLine()
                Set tTrimmed = $ZStrip(tLine, "<W")
                If ($Extract(tTrimmed) = ";") || ($Extract(tTrimmed, 1, 2) = "//") Continue
                Set tHit = ..Constructs(tLine)
            }
            If tHit Quit
        }
        Set tDefinition = ""
        If tHit Set tFound = tFound _ $Select(tFound = "": "", 1: ",") _ tName
    }
    Quit tFound
}

/// <p>The roster's class names, comma-separated in name order.</p>
ClassMethod RosterClasses() As %String
{
    Set tClasses = ""
    For tI = 1:1:$Length(..#ROSTER, ";") {
        Set tClasses = tClasses _ $Select(tClasses = "": "", 1: ",") _ $Piece($Piece(..#ROSTER, ";", tI), "=", 1)
    }
    Quit tClasses
}

/// <p>The derived set equals the roster; a class in one and not the other is named.</p>
/// <p>Mutation (Rule 19): add a <code>##class(%Net.HttpRequest).%New()</code> to a read tool's
/// class -> this goes red naming it.</p>
Method TestOnlyTheRosterOpensAConnection()
{
    Set tDerived = ..Sites(0)
    Do $$$AssertTrue(tDerived '[ "(unreadable)", "every shipped class's definition was read: " _ tDerived)
    Set tRoster = ..RosterClasses()
    For tI = 1:1:$Length(tDerived, ",") {
        Set tName = $Piece(tDerived, ",", tI)
        If tName = "" Continue
        Do $$$AssertTrue($ListFind($ListFromString(tRoster), tName), tName _ " opens an outbound connection and is not on the egress roster")
    }
    For tI = 1:1:$Length(tRoster, ",") {
        Set tName = $Piece(tRoster, ",", tI)
        Do $$$AssertTrue($ListFind($ListFromString(tDerived), tName), tName _ " is on the egress roster and no longer opens a connection")
    }
    Do $$$AssertEquals(tDerived, tRoster, "the derived set is the roster")
}

/// <p>Each roster row carries exactly one of the declared reasons, and only the provider base
/// carries the turn's.</p>
Method TestEachRowCarriesOneReason()
{
    For tI = 1:1:$Length(..#ROSTER, ";") {
        Set tRow = $Piece(..#ROSTER, ";", tI)
        Set tReason = $Piece(tRow, "=", 2, 99)
        Do $$$AssertTrue($ListFind($ListFromString(..#REASONS, ";"), tReason), $Piece(tRow, "=", 1) _ " carries a declared reason: " _ tReason)
        Do $$$AssertEquals(tReason = "the turn's provider call", $Piece(tRow, "=", 1) = "OcuPilot.Kernel.Provider.Base", $Piece(tRow, "=", 1) _ ": only the provider base is the turn's call")
    }
}

/// <p>The control: the same scan over <package>OcuPilot.Test</package> finds the test package's
/// own HTTP helper and its TCP listener, so an empty shipped answer is a measurement.</p>
Method TestTheScanFindsTheTestPackagesOwnClients()
{
    Set tTests = ..Sites(1)
    Do $$$AssertTrue(("," _ tTests _ ",") [ ",OcuPilot.Test.Http,", "the scan finds OcuPilot.Test.Http's %Net.HttpRequest: " _ tTests)
    Do $$$AssertTrue(("," _ tTests _ ",") [ ",OcuPilot.Test.OAuthIssuerFixture,", "and OcuPilot.Test.OAuthIssuerFixture's |TCP| device: " _ tTests)
}

}
