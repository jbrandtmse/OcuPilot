/// <p>Pins AD-62 item 12: every class OcuPilot ships compiles in a namespace that does not report
/// interoperability, and the install it makes there still serves an interoperability namespace. The shipped
/// classes are every <code>OcuPilot.*</code> class the install namespace holds outside the packages
/// <class>OcuPilot.Install.Roster</class> declares with scope <code>test</code>. They are exported from the
/// install namespace and loaded and compiled in <code>OCUPROBE2028N</code>
/// (<class>OcuPilot.Test.CompileWithoutInteropProbe</class>), a namespace this class creates without
/// interoperability over its own database.</p>
/// <p>Its main pins: the compiled set equals the copied set (a class that regains an
/// <code>Ensemble</code> include, an <code>Ens</code> macro or an interoperability class as a declared type
/// is named); the probe namespace's own navigation map keeps <code>interoperability</code> with
/// <code>applies</code> false (AD-44); and, from the probe namespace, the probe copy's nine
/// interoperability <code>LIST</code> reads and Home's production line answer for <code>USER</code>, an
/// interoperability namespace that holds no OcuPilot class, which fails <code>&lt;CLASS DOES NOT
/// EXIST&gt;</code> if a copy calls another <code>OcuPilot.*</code> class while switched (AD-62 item 3).
/// The probe copy also refuses its own namespace with 409, and the CI runner's leftover check names the probe
/// objects while they exist. The <code>OcuPilot.Test</code> classes are outside it, and none is copied. The copy
/// is also held against the roster's <code>packages</code> list, which names the shipped set positively where the
/// copy takes it as everything outside the test scope: each shipped package is copied whole.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and compiled in the namespace the class
/// runs in, a stock IRIS for Health throwaway (<code>USER</code> reports interoperability and holds no
/// OcuPilot class), <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, and about ten seconds. Every
/// probe object is removed by exact name before all, and after all or at the failure of its own setup.</p>
Class OcuPilot.Test.CompileWithoutInterop Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.CompileWithoutInteropProbe";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter NAVIGATION = "OcuPilot.Kernel.Shell.Navigation";

Parameter SYSTEMINFO = "OcuPilot.Kernel.Shell.SystemInfo";

/// <p>The interoperability namespace the probe copy is asked to serve.</p>
Parameter TARGET = "USER";

/// <p>The <code>LIST</code> endpoints that take no criteria.</p>
Parameter ENDPOINTS = "Productions,Processes,Transforms,Rules,Monitor,Queues,Jobs,LookupTables,BusinessPartners";

/// <p>How many shipped classes were exported and loaded into the probe namespace.</p>
Property PreparedCopied As %Integer [ InitialExpression = 0 ];

/// <p>How many <code>OcuPilot.*</code> classes the probe namespace holds with a current compile.</p>
Property PreparedCompiled As %Integer [ InitialExpression = 0 ];

/// <p>The load and compile status text, <code>""</code> when it was OK.</p>
Property PreparedStatus As %String(MAXLEN = "");

/// <p>The copied classes the probe namespace does not hold with a current compile, comma separated.</p>
Property PreparedMissing As %String(MAXLEN = "");

/// <p>The <code>OcuPilot.*</code> classes of the probe namespace that were not copied, comma separated.</p>
Property PreparedExtra As %String(MAXLEN = "");

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.CompileWithoutInterop creates a database, a resource, a directory and a namespace on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..PrepareProbe()
    If $$$ISERR(tSC) {
        ; A failed setup removes what it made before it returns, rather than leaving that to the after-all call.
        Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tLeft))
    }
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Set tLeft = ##class(OcuPilot.Test.ProbeApps).CompileProbeLeftovers()
    If tLeft '= "" Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "probe objects survive their removal:" _ tLeft))
    Quit tSC
}

/// <p>Create the probe namespace, export the shipped classes from this namespace and load them into it with
/// <code>ck</code>, then record which of them it holds compiled. A namespace that reports interoperability is a
/// failure, because a compile there would prove nothing.</p>
Method PrepareProbe() As %Status [ Private ]
{
    Set tSC = $ClassMethod(..#PROBE, "SeedNamespace")
    If $$$ISERR(tSC) Quit tSC
    Set tProbeNs = $Parameter(..#PROBE, "NAMESPACENAME")
    If ##class(%Library.EnsembleMgr).IsEnsembleNamespace(tProbeNs) {
        Quit $$$ERROR($$$GeneralError, "the probe namespace " _ tProbeNs _ " reports interoperability, so compiling in it would prove nothing")
    }
    Set tSC = ..ShippedClasses(.tShipped)
    If $$$ISERR(tSC) Quit tSC
    If tShipped = 0 Quit $$$ERROR($$$GeneralError, "this namespace holds no shipped OcuPilot class to copy")
    Set tName = ""
    For {
        Set tName = $Order(tShipped(tName))
        If tName = "" Quit
        Set tItems(tName _ ".CLS") = ""
    }
    Set tStream = ##class(%Stream.TmpCharacter).%New()
    Set tSC = $System.OBJ.ExportToStream(.tItems, .tStream, "-d")
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedCopied = tShipped
    Set tOrigNS = $NAMESPACE
    Set tLoadSC = $$$OK
    Try {
        Set $NAMESPACE = tProbeNs
        Set tLoadSC = $System.OBJ.LoadStream(tStream, "ck-d", .tErrors, .tLoaded)
        Set tCompiled = 0
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledClass WHERE Name %STARTSWITH 'OcuPilot.' AND (GeneratedBy IS NULL OR GeneratedBy = '')")
        If tRS.%SQLCODE < 0 {
            Set tSC = $$$ERROR($$$GeneralError, "the compiled classes of " _ tProbeNs _ " could not be read: " _ tRS.%Message)
        }
        While $$$ISOK(tSC) && tRS.%Next() {
            Set tHeld = tRS.%GetData(1)
            Set tHeldName(tHeld) = ""
            ; A class whose compile failed keeps a compiled-class row, so only a current compile counts.
            If $System.OBJ.IsUpToDate(tHeld) {
                Set tCompiled = tCompiled + 1
                Set tCompiledName(tHeld) = ""
            }
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedCompiled = tCompiled
    Set ..PreparedStatus = $Select($$$ISOK(tLoadSC): "", 1: $System.Status.GetErrorText(tLoadSC))
    Set tName = ""
    For {
        Set tName = $Order(tShipped(tName))
        If tName = "" Quit
        If '$Data(tCompiledName(tName)) Set ..PreparedMissing = ..PreparedMissing _ $Select(..PreparedMissing = "": "", 1: ",") _ tName
    }
    Set tName = ""
    For {
        Set tName = $Order(tHeldName(tName))
        If tName = "" Quit
        If '$Data(tShipped(tName)) Set ..PreparedExtra = ..PreparedExtra _ $Select(..PreparedExtra = "": "", 1: ",") _ tName
    }
    Quit $$$OK
}

/// <p>What <class>OcuPilot.Install.Roster</class> says about which classes ship, as <code>$ListBuild</code> lists of
/// class-name prefixes. <var>pTest</var> holds the prefix of each resource declared with scope <code>test</code>
/// (<code>OcuPilot.Test.</code>). <var>pShipped</var> holds <code>OcuPilot.&lt;package&gt;.</code> for each entry of the
/// roster's <code>packages</code> that is not one of those. A roster that declares no test-scope package, or lists no
/// package, is an error, because the shipped set could not then be told from the test classes.</p>
Method RosterPrefixes(Output pShipped As %List, Output pTest As %List) As %Status [ Private ]
{
    Set pShipped = ""
    Set pTest = ""
    Set tSC = ##class(OcuPilot.Install.Roster).Get(.tRoster)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject(tRoster.resources) {
        Set tIterator = tRoster.resources.%GetIterator()
        While tIterator.%GetNext(.tKey, .tResource) {
            If $IsObject(tResource) && (tResource.scope = "test") Set pTest = pTest _ $ListBuild($Piece(tResource.name, ".PKG", 1) _ ".")
        }
    }
    If pTest = "" Quit $$$ERROR($$$GeneralError, "the roster declares no test-scope package, so the shipped classes cannot be told from the test classes")
    If $IsObject(tRoster.packages) {
        Set tIterator = tRoster.packages.%GetIterator()
        While tIterator.%GetNext(.tKey, .tPackage) {
            Set tPrefix = "OcuPilot." _ tPackage _ "."
            If '$ListFind(pTest, tPrefix) Set pShipped = pShipped _ $ListBuild(tPrefix)
        }
    }
    If pShipped = "" Quit $$$ERROR($$$GeneralError, "the roster lists no shipped package")
    Quit $$$OK
}

/// <p>The shipped classes this namespace holds: every <code>OcuPilot.*</code> class definition outside the
/// packages the roster declares with scope <code>test</code>, and not generated by another class. They come back
/// as <var>pNames</var>(name), with their count in <var>pNames</var>. A roster that declares no test-scope package
/// is an error, because the shipped set could not then be told from the test classes.</p>
Method ShippedClasses(Output pNames) As %Status [ Private ]
{
    Kill pNames
    Set pNames = 0
    Set tSC = ..RosterPrefixes(.tShippedPrefixes, .tTestPrefixes)
    If $$$ISERR(tSC) Quit tSC
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH 'OcuPilot.' AND (GeneratedBy IS NULL OR GeneratedBy = '')")
    If tRS.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "the class definitions could not be read: " _ tRS.%Message)
    While tRS.%Next() {
        Set tName = tRS.%GetData(1)
        Set tTest = 0
        For tI = 1:1:$ListLength(tTestPrefixes) {
            If $Extract(tName, 1, $Length($List(tTestPrefixes, tI))) = $List(tTestPrefixes, tI) Set tTest = 1
        }
        If 'tTest {
            Set pNames(tName) = ""
            Set pNames = pNames + 1
        }
    }
    Quit $$$OK
}

/// <p>Every shipped class compiles in the namespace without interoperability: the load and compile status is
/// OK, every copied class is held compiled there (any that is not is named), and the compiled set equals the
/// copied set, which is not empty.</p>
/// <p>Mutation (Rule 19): <code>Include Ensemble</code> returned to the top of
/// <code>OcuPilot.Port.InteropPort</code> -&gt; this goes red naming it; so does an argument typed
/// <code>Ens.Config.Item</code> in it.</p>
Method TestEveryShippedClassCompilesThere()
{
    Do $$$AssertTrue(..PreparedCopied > 0, "the copied set is not empty: " _ ..PreparedCopied)
    Do $$$AssertEquals(..PreparedMissing, "", "every copied class is compiled in the probe namespace; not compiled: " _ ..PreparedMissing)
    Do $$$AssertEquals(..PreparedStatus, "", "the load and compile report no error: " _ ..PreparedStatus)
    Do $$$AssertEquals(..PreparedExtra, "", "the probe namespace holds no compiled OcuPilot class that was not copied: " _ ..PreparedExtra)
    Do $$$AssertEquals(..PreparedCompiled, ..PreparedCopied, "the compiled set equals the copied set")
}

/// <p>The copy is every class of every shipped package: for each package the roster's <code>packages</code> lists
/// that is not test scope, the probe namespace holds as many class definitions as this namespace does. The roster
/// names the shipped set positively, where <method>ShippedClasses</method> takes it as everything outside the test
/// scope, so a copy that leaves classes out cannot pass because the compiled set equals a copied set that was too
/// small.</p>
/// <p>Mutation (Rule 19): <method>ShippedClasses</method> leaving out one package, such as
/// <code>OcuPilot.Area.</code> -&gt; this goes red naming that package; the compile test stays green.</p>
Method TestTheCopyIsEveryClassOfEveryShippedPackage()
{
    Set tProbeNs = $Parameter(..#PROBE, "NAMESPACENAME")
    Set tSC = ..RosterPrefixes(.tShipped, .tTest)
    Do $$$AssertStatusOK(tSC, "the roster names the shipped packages: " _ $Select($$$ISERR(tSC): $System.Status.GetErrorText(tSC), 1: ""))
    If $$$ISERR(tSC) Quit
    Set tTotal = 0
    For tI = 1:1:$ListLength(tShipped) {
        Set tPrefix = $List(tShipped, tI)
        Set tHere = ..DefinitionsIn($NAMESPACE, tPrefix)
        Set tThere = ..DefinitionsIn(tProbeNs, tPrefix)
        Do $$$AssertTrue(tHere >= 0, tPrefix _ " could be counted in " _ $NAMESPACE)
        Do $$$AssertEquals(tThere, tHere, tPrefix _ " is copied whole: " _ tHere _ " here, " _ tThere _ " in " _ tProbeNs)
        Set tTotal = tTotal + tHere
    }
    Do $$$AssertTrue(tTotal > 0, "the shipped packages hold classes: " _ tTotal)
}

/// <p>No test-scope class is copied: this namespace holds classes under each prefix the roster declares with scope
/// <code>test</code> (this class is one), and the probe namespace holds none. A test class may include
/// <code>Ensemble</code> (<class>OcuPilot.Test.InteropItemSeam</class> does), and the guard never refuses one.</p>
/// <p>Mutation (Rule 19): <method>ShippedClasses</method> not leaving out the test-scope prefixes -&gt; this goes red
/// naming <code>OcuPilot.Test.</code>.</p>
Method TestNoTestScopeClassIsCopied()
{
    Set tProbeNs = $Parameter(..#PROBE, "NAMESPACENAME")
    Set tSC = ..RosterPrefixes(.tShipped, .tTest)
    Do $$$AssertStatusOK(tSC, "the roster names the test-scope packages: " _ $Select($$$ISERR(tSC): $System.Status.GetErrorText(tSC), 1: ""))
    If $$$ISERR(tSC) Quit
    For tI = 1:1:$ListLength(tTest) {
        Set tPrefix = $List(tTest, tI)
        Do $$$AssertTrue(..DefinitionsIn($NAMESPACE, tPrefix) > 0, $NAMESPACE _ " holds classes under " _ tPrefix)
        Do $$$AssertEquals(..DefinitionsIn(tProbeNs, tPrefix), 0, tProbeNs _ " holds none under " _ tPrefix)
    }
}

/// <p>In the probe namespace, its own navigation map keeps the <code>interoperability</code> area on the wire
/// with <code>applies</code> false (AD-44), so the category is drawn nowhere.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Shell.NamespaceFeatures.Reports</method> answering 1 for
/// <code>interoperability</code> -&gt; this goes red.</p>
Method TestInteroperabilityIsHiddenThere()
{
    Set tProbeNs = $Parameter(..#PROBE, "NAMESPACENAME")
    Set tFound = 0
    Set tApplies = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Do ##class(OcuPilot.Kernel.Scope).Set(tProbeNs)
        Set $NAMESPACE = tProbeNs
        Set tSC = $ClassMethod(..#NAVIGATION, "Payload", .tPayload)
        If $$$ISOK(tSC) {
            Set tIterator = tPayload.areas.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tArea) {
                If tArea.key = "interoperability" {
                    Set tFound = 1
                    Set tApplies = $Select(tArea.%GetTypeOf("applies") = "boolean": tArea.%Get("applies"), 1: "not a boolean")
                }
            }
        }
        Set tPayload = ""
        Set tArea = ""
        Set tIterator = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(tSC, "the probe copy builds the navigation map in " _ tProbeNs _ ": " _ $Select($$$ISERR(tSC): $System.Status.GetErrorText(tSC), 1: ""))
    Do $$$AssertTrue(tFound, "the map keeps the interoperability area on the wire")
    Do $$$AssertEquals(tApplies, 0, "and its applies is false in a namespace without interoperability")
}

/// <p>From the probe namespace, the probe copy serves <code>USER</code>, an interoperability namespace that
/// holds no OcuPilot class: its nine <code>LIST</code> reads that take no criteria answer 200, and Home's
/// production line returns a state word. Each runs its vendor calls while switched to <code>USER</code>, where
/// another <code>OcuPilot.*</code> class does not exist.</p>
/// <p>Mutation (Rule 19): a call to <code>OcuPilot.Kernel.Audit.Log.Warn</code> inside
/// <code>OcuPilot.Port.InteropPort.ListProductions</code>'s switched block -&gt; this goes red on the
/// <code>Productions</code> read.</p>
Method TestItServesAnInteroperabilityNamespace()
{
    Set tProbeNs = $Parameter(..#PROBE, "NAMESPACENAME")
    Set tTarget = ..#TARGET
    Do $$$AssertEquals(##class(%Library.EnsembleMgr).IsEnsembleNamespace(tTarget), 1, tTarget _ " reports interoperability")
    Do $$$AssertEquals(..DefinitionsIn(tTarget, "OcuPilot."), 0, tTarget _ " holds no OcuPilot class, so a copy that calls one while switched fails")
    Do $$$AssertEquals(..ClassExistsIn(tProbeNs, ..#PORT), 1, tProbeNs _ " holds the copy this test drives")
    For tI = 1:1:$Length(..#ENDPOINTS, ",") {
        Set tEndpoint = $Piece(..#ENDPOINTS, ",", tI)
        Set tHttp = 0
        Set tFault = ""
        Set tCaught = ""
        Kill tQuery
        Set tQuery("namespace") = tTarget
        Set tOrigNS = $NAMESPACE
        Try {
            Set $NAMESPACE = tProbeNs
            Set tSC = $ClassMethod(..#PORT, "Invoke", tEndpoint, "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
            If $IsObject(tFault) Set tFault = tFault.%ToJSON()
            Set tResult = ""
            Set $NAMESPACE = tOrigNS
        } Catch ex {
            Set $NAMESPACE = tOrigNS
            Set tCaught = ex.DisplayString()
        }
        Do $$$AssertEquals(tCaught, "", tEndpoint _ " raised nothing in " _ tProbeNs)
        Do $$$AssertEquals(tHttp, 200, tEndpoint _ " answers 200 for " _ tTarget _ ": " _ tFault)
    }
    Set tState = ""
    Set tCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Do ##class(OcuPilot.Kernel.Scope).Set(tTarget)
        Set $NAMESPACE = tProbeNs
        Set tState = $ClassMethod(..#SYSTEMINFO, "ProductionState")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex.DisplayString()
    }
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertEquals(tCaught, "", "Home's production line raised nothing for " _ tTarget)
    Do $$$AssertTrue(tState '= "", "and answers a state word: " _ tState)
}

/// <p>The probe copy refuses the namespace it runs in, which runs no interoperability, as the install does:
/// a <code>Productions</code> read that names it answers 409 <code>INTEROP.NAMESPACE</code> (the answer
/// <class>OcuPilot.Test.InteropHostRead</class> pins from the install namespace).</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.InteropPort.Invoke</code> not refusing a namespace that
/// <code>NamespaceFeatures.Reports</code> says runs no interoperability -&gt; this goes red.</p>
Method TestItRefusesItsOwnNamespace()
{
    Set tProbeNs = $Parameter(..#PROBE, "NAMESPACENAME")
    Set tHttp = 0
    Set tCode = ""
    Set tCaught = ""
    Kill tQuery
    Set tQuery("namespace") = tProbeNs
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = tProbeNs
        Set tSC = $ClassMethod(..#PORT, "Invoke", "Productions", "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
        If $IsObject(tFault) Set tCode = tFault.%Get("code")
        Set tResult = ""
        Set tFault = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex.DisplayString()
    }
    Do $$$AssertEquals(tCaught, "", "the read raised nothing in " _ tProbeNs)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 INTEROP.NAMESPACE", "a read naming " _ tProbeNs _ " from inside it is refused, not answered")
}

/// <p>While the probe objects exist, <method>OcuPilot.Test.ProbeApps.CompileProbeLeftovers</method> names the
/// namespace, the database and the directory, and so does <method>OcuPilot.Test.ProbeApps.Existing</method>,
/// which the CI runner reads before and after every class. The tokens are literals, so a change to how they
/// are computed is seen.</p>
/// <p>Mutation (Rule 19): <code>CompileProbeLeftovers</code> answering <code>""</code>, or computing the
/// directory leaf wrongly -&gt; this goes red.</p>
Method TestTheLeftoverCheckSeesTheProbeObjects()
{
    Set tLeftovers = ##class(OcuPilot.Test.ProbeApps).CompileProbeLeftovers()
    Set tExisting = ##class(OcuPilot.Test.ProbeApps).Existing()
    For tToken = " namespace:OCUPROBE2028N", " database:OCUPROBE2028D", " directory:ocuprobe2028d" {
        Do $$$AssertTrue(tLeftovers [ tToken, "the probe check names" _ tToken _ ": " _ tLeftovers)
        Do $$$AssertTrue(tExisting [ $ZStrip(tToken, "<W"), "the runner's check names" _ tToken _ ": " _ tExisting)
    }
}

/// <p>How many class definitions namespace <var>pNamespace</var> holds whose name starts with <var>pPrefix</var> and
/// that no other class generated, read there by explicit save and restore. <code>-1</code> when it could not be read.</p>
ClassMethod DefinitionsIn(pNamespace As %String, pPrefix As %String) As %Integer [ Private ]
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH ? AND (GeneratedBy IS NULL OR GeneratedBy = '')", pPrefix)
        If tRS.%SQLCODE >= 0 && tRS.%Next() Set tCount = tRS.%GetData(1)
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Whether namespace <var>pNamespace</var> holds a compiled class <var>pClass</var>, read there by explicit
/// save and restore.</p>
ClassMethod ClassExistsIn(pNamespace As %String, pClass As %String) As %Boolean [ Private ]
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tExists = ''##class(%Dictionary.CompiledClass).%ExistsId(pClass)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tExists = -1
    }
    Quit tExists
}

}
