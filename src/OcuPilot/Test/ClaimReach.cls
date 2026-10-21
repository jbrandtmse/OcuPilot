/// <p>Pins which shipped classes name the proposal claim (AD-6, AD-34, AD-40): the
/// claim is <method>OcuPilot.Kernel.Proposal.Write.Claim</method> and <method>ClaimById</method>,
/// and <method>OcuPilot.Kernel.State.Propose.GuardedClaimAndClose</method> beneath them, and the
/// only shipped class that names them is <class>OcuPilot.Kernel.Proposal.Confirm</class>, which
/// only the confirm handler and the install smoke check call.</p>
/// <p>Each token is read over every compiled shipped class with
/// <method>OcuPilot.Test.AsTheUser.SitesNaming</method>, which reports a class whose source it
/// cannot read rather than scoring it as no match. The rows that name a site are the scan's
/// positive control: a scan that found nothing would fail them, so the empty rows are a
/// measurement. A path to the claim is asked in each spelling a source names it by: a static call,
/// a quoted class or method name, a call through an object, the confirm path's short class name
/// inside its own package, and a shipped subclass of the gate, the store or the confirm path. A
/// name assembled at run time is outside what a source scan sees.</p>
/// <p><b>What it needs from the environment:</b> the shipped classes compiled on the instance. It
/// writes nothing.</p>
Class OcuPilot.Test.ClaimReach Extends %UnitTest.TestCase
{

/// <p>The confirm path's class: the one shipped class that names the claim.</p>
Parameter CONFIRM = "OcuPilot.Kernel.Proposal.Confirm";

/// <p>The classes that hold the claim: the gate and the store beneath it.</p>
Parameter CLAIMCLASSES = "OcuPilot.Kernel.Proposal.Write,OcuPilot.Kernel.State.Propose";

/// <p>Only the confirm path names the claim, and only the confirm handler and the install smoke
/// check name the confirm path.</p>
/// <p>Mutation (Rule 19): add <code>If 0 Do ##class(OcuPilot.Kernel.Proposal.Write).ClaimById("",
/// "", .tR, .tC)</code> to a <class>OcuPilot.Kernel.Proposal.Caller</class> method -- this goes red
/// on its first token.</p>
Method TestOnlyTheConfirmPathNamesTheClaim()
{
    ; Each row is the token and the comma-separated classes expected to name it, in name order.
    Set tCases($Increment(tCases)) = $ListBuild("Proposal.Write).Claim", ..#CONFIRM)
    Set tCases($Increment(tCases)) = $ListBuild("""OcuPilot.Kernel.Proposal.Write""", "")
    Set tCases($Increment(tCases)) = $ListBuild("""GuardedClaimAndClose""", ..#CONFIRM)
    Set tCases($Increment(tCases)) = $ListBuild(").GuardedClaimAndClose(", "")
    Set tCases($Increment(tCases)) = $ListBuild("Kernel.Proposal.Confirm)", "OcuPilot.Api.Confirm,OcuPilot.Install.Smoke")
    Set tCases($Increment(tCases)) = $ListBuild("""OcuPilot.Kernel.Proposal.Confirm""", "")
    For tI = 1:1:tCases {
        Set tToken = $List(tCases(tI), 1)
        Set tSites = ##class(OcuPilot.Test.AsTheUser).SitesNaming(tToken)
        Do $$$AssertEquals(tSites, $List(tCases(tI), 2), "the shipped classes naming <" _ tToken _ "> are exactly the expected ones: " _ tSites)
    }
}

/// <p>The claim cannot be reached by a spelling the first test's tokens do not read: the confirm
/// path calls the store through a class name it holds in a variable, so a call written as
/// <code>$ClassMethod(tClass, "ClaimById", ...)</code> names neither class. No shipped class
/// names <code>Claim</code> or <code>ClaimById</code> as a quoted method name or calls
/// <code>Claim</code> as a static method of any class; the confirm path alone calls
/// <code>ClaimById</code>, whether statically or through an object; none calls
/// <code>GuardedClaimAndClose</code> through an object or from inside the store, makes a gate
/// object, or names the confirm path by its short class name; and no shipped class extends the
/// gate, the store or the confirm path, which would inherit the claim. The quoted-name scan and
/// the subclass query are each shown to find something they are known to hold.</p>
/// <p>Mutation (Rule 19): add a shipped class that extends
/// <class>OcuPilot.Kernel.Proposal.Write</class> and calls
/// <code>$ClassMethod(pClass, "ClaimById", ...)</code> -- this goes red on the quoted name and on
/// the subclass query, while the first test stays green.</p>
Method TestNoOtherSpellingOrSubclassReachesTheClaim()
{
    Set tScan = ##class(OcuPilot.Test.AsTheUser).SitesNaming("""GuardedClaimAndClose""")
    Do $$$AssertEquals(tScan, ..#CONFIRM, "control: the quoted-method-name scan finds the confirm path's own call: " _ tScan)
    Set tScan = ##class(OcuPilot.Test.AsTheUser).SitesNaming("""Claim""")
    Do $$$AssertEquals(tScan, "", "no shipped class names Claim as a quoted method name: " _ tScan)
    Set tScan = ##class(OcuPilot.Test.AsTheUser).SitesNaming("""ClaimById""")
    Do $$$AssertEquals(tScan, "", "nor ClaimById: " _ tScan)
    Set tScan = ##class(OcuPilot.Test.AsTheUser).SitesNaming(").Claim(")
    Do $$$AssertEquals(tScan, "", "no shipped class calls Claim as a static method of any class: " _ tScan)
    Set tScan = ##class(OcuPilot.Test.AsTheUser).SitesNaming(".ClaimById(")
    Do $$$AssertEquals(tScan, ..#CONFIRM, "the confirm path alone calls ClaimById, statically or through an object: " _ tScan)
    Set tScan = ##class(OcuPilot.Test.AsTheUser).SitesNaming(".GuardedClaimAndClose(")
    Do $$$AssertEquals(tScan, "", "none calls GuardedClaimAndClose through an object or from inside the store: " _ tScan)
    Set tScan = ##class(OcuPilot.Test.AsTheUser).SitesNaming("Proposal.Write).%New(")
    Do $$$AssertEquals(tScan, "", "none makes a gate object to call the claim through: " _ tScan)
    Set tScan = ##class(OcuPilot.Test.AsTheUser).SitesNaming("(Confirm).")
    Do $$$AssertEquals(tScan, "", "none names the confirm path by its short class name: " _ tScan)

    Set tScan = ..SubclassesOf("OcuPilot.Screen.Tool.Write", 0)
    Do $$$AssertTrue(tScan [ "OcuPilot.Screen.Tool.WebAppUpdate", "control: the subclass query finds a known subclass: " _ tScan)
    Set tClasses = ..#CLAIMCLASSES _ "," _ ..#CONFIRM
    For tI = 1:1:$Length(tClasses, ",") {
        Set tClass = $Piece(tClasses, ",", tI)
        Set tScan = ..SubclassesOf(tClass, 0)
        Do $$$AssertEquals(tScan, "", "no shipped class extends " _ tClass _ ", which would inherit the claim: " _ tScan)
    }
}

/// <p>The compiled <code>OcuPilot.*</code> classes whose <code>Extends</code> list names exactly
/// <var>pClass</var>, comma-separated in name order; <var>pIncludeTests</var> 1 keeps
/// <package>OcuPilot.Test</package> in the population. A failed query answers its SQLCODE, which
/// no class name equals.</p>
ClassMethod SubclassesOf(pClass As %String, pIncludeTests As %Boolean = 0) As %String
{
    Set tFound = ""
    Set tExclude = $Select(pIncludeTests: "", 1: " AND NOT (Name %STARTSWITH 'OcuPilot.Test')")
    Set tStatement = ##class(%SQL.Statement).%New()
    Set tSC = tStatement.%Prepare("SELECT Name, Super FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH 'OcuPilot.'" _ tExclude _ " AND Super [ ? ORDER BY Name")
    If $$$ISERR(tSC) Quit "prepare failed: " _ $System.Status.GetErrorText(tSC)
    Set tRS = tStatement.%Execute(pClass)
    If tRS.%SQLCODE < 0 Quit "SQLCODE=" _ tRS.%SQLCODE
    While tRS.%Next() {
        If $ListFind($ListFromString(tRS.%GetData(2), ","), pClass) Set tFound = tFound _ $Select(tFound = "": "", 1: ",") _ tRS.%GetData(1)
    }
    Quit tFound
}

}
