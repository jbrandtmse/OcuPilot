/// <p>Pins each pair the four item write tools declare, one at a time, in a namespace whose routines database is
/// not its globals database (AD-8, AD-44, AD-62, Story 20.3). In <code>USER</code> the two databases share one
/// resource, so the pair the tools add for the routines database cannot be told from the globals database's;
/// here the namespace is a configuration over two existing databases (globals <code>USER</code>, routines
/// <code>HSCUSTOM</code>), so a caller can hold the one write and not the other. For each tool and each pair of
/// <parameter>PAIRS</parameter>, a caller holding every pair but that one is refused naming that pair, and a
/// caller holding all of them is admitted; and the port's own routines-database lookup names the routines
/// database there.</p>
/// <p>The caller is the fake gate <class>OcuPilot.Test.ScreenGate</class>, because the test account holds
/// <code>%All</code>; the real gate over real principals is <class>OcuPilot.Test.InteropItemGate</class>'s, for
/// the pairs a throwaway can withhold singly.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because it creates and deletes a namespace configuration on the instance. It starts and compiles nothing.
/// One class per run.</p>
Class OcuPilot.Test.InteropItemGateSplit Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter GATE = "OcuPilot.Test.ScreenGate";

Parameter SPLITNAMESPACE = "OCUP203SPLIT";

/// <p>The tools whose pairs are evaluated.</p>
Parameter TOOLS = "InteropItemEnable,InteropItemDisable,InteropItemRemove,InteropItemAdd";

/// <p>The pairs an item write tool declares in <parameter>SPLITNAMESPACE</parameter>, <code>resource:permission</code>,
/// comma-separated: Interoperability's menu, Productions' read, an item write's configuration write, and WRITE on
/// the globals database's resource and on the routines database's.</p>
Parameter PAIRS = "%Ens_Portal:USE,%Ens_ProductionConfig:READ,%Ens_ProductionConfig:WRITE,%DB_USER:WRITE,%DB_HSCUSTOM:WRITE";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemGateSplit creates a namespace on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Quit ..CreateSplit()
}

/// <p>Delete the split namespace; a failing status when it survives.</p>
Method OnAfterAllTests() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#GATE, "Reset")
    Quit ..DeleteSplit()
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#GATE, "Reset")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#GATE, "Reset")
    Quit $$$OK
}

/// <p>Create <parameter>SPLITNAMESPACE</parameter> over <code>USER</code> (globals) and <code>HSCUSTOM</code>
/// (routines), after removing one an earlier run left, and read back that the instance reports the two
/// databases' resources as <parameter>PAIRS</parameter> names them.</p>
Method CreateSplit() As %Status
{
    Set tSC = ..DeleteSplit()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("Globals") = "USER"
        Set tProps("Routines") = "HSCUSTOM"
        Set tSC = ##class(Config.Namespaces).Create(..#SPLITNAMESPACE, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    Set tGlobals = ""
    Set tRoutines = ""
    Set tHaveGlobals = ##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase(..#SPLITNAMESPACE, .tGlobals, .tReadOnly)
    Set tHaveRoutines = ##class(OcuPilot.Kernel.Shell.Namespaces).RoutineDatabase(..#SPLITNAMESPACE, .tRoutines, .tReadOnly)
    If 'tHaveGlobals || 'tHaveRoutines || (tGlobals '= "%DB_USER") || (tRoutines '= "%DB_HSCUSTOM") {
        ; %UnitTest skips OnAfterAllTests when setup fails, so the namespace just made is deleted here.
        Quit $$$ADDSC($$$ERROR($$$GeneralError, "the split namespace's databases read " _ tGlobals _ " and " _ tRoutines _ ", not %DB_USER and %DB_HSCUSTOM"), ..DeleteSplit())
    }
    Quit $$$OK
}

/// <p>Delete <parameter>SPLITNAMESPACE</parameter> when it exists; a failing status when it still does.</p>
Method DeleteSplit() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Config.Namespaces).Exists(..#SPLITNAMESPACE) Set tSC = ##class(Config.Namespaces).Delete(..#SPLITNAMESPACE)
        If $$$ISOK(tSC) && ##class(Config.Namespaces).Exists(..#SPLITNAMESPACE) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropItemGateSplit left the namespace " _ ..#SPLITNAMESPACE)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>AC4: each of the four tools, scoped to the split namespace, declares exactly the pairs of
/// <parameter>PAIRS</parameter>; a caller holding every pair is admitted, and a caller holding every pair but
/// one is refused naming that one, for each of the five. The routines database's write is the pair
/// <class>OcuPilot.Test.InteropItemGate</class> cannot withhold singly in <code>USER</code>.</p>
/// <p>Mutation (Rule 19): iterate only the globals database in
/// <method>OcuPilot.Screen.Tool.InteropItemAction.PrivilegePairs</method> (<code>For tResource = tGlobals</code>) -- each
/// tool's routines-database row goes red.</p>
Method TestEachDeclaredPairOfEachToolIsRefusedByNameWhenItAloneIsMissing()
{
    Set tGate = ..#GATE
    Do ##class(OcuPilot.Kernel.Scope).Set(..#SPLITNAMESPACE)
    Set tCount = $Length(..#PAIRS, ",")
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece(..#TOOLS, ",", tI)
        Set tName = $Parameter(tTool, "TOOLNAME")
        Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
        Do $$$AssertEquals(tResolved, 1, tName _ ": its pairs resolve in the split namespace")
        Set tText = ""
        For tJ = 1:1:$ListLength(tPairs) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $ListToString($List(tPairs, tJ), ":")
        }
        Do $$$AssertEquals(tText, ..#PAIRS, tName _ ": it declares the five pairs")
        Do $ClassMethod(tGate, "Reset")
        For tJ = 1:1:tCount {
            Do ..Hold($Piece(..#PAIRS, ",", tJ))
        }
        Set tAdmitted = $ClassMethod(tGate, "EvaluateRequired", tPairs, .tFailed)
        Do $$$AssertEquals(tAdmitted _ "|" _ $Get(tFailed), "1|", tName _ ": a caller holding all five is admitted")
        For tMissing = 1:1:tCount {
            Do $ClassMethod(tGate, "Reset")
            For tJ = 1:1:tCount {
                If tJ '= tMissing Do ..Hold($Piece(..#PAIRS, ",", tJ))
            }
            Set tFailed = ""
            Set tAdmitted = $ClassMethod(tGate, "EvaluateRequired", tPairs, .tFailed)
            Do $$$AssertEquals(tAdmitted _ "|" _ $Get(tFailed), "0|" _ $Piece(..#PAIRS, ",", tMissing), tName _ ": a caller missing only " _ $Piece(..#PAIRS, ",", tMissing) _ " is refused naming it")
        }
    }
}

/// <p>AC4: the port's own routines-database lookup, which its gate asks WRITE on for an item write, names the
/// routines database's resource in the split namespace, not the globals database's.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.RoutineResource</method> call
/// <code>GlobalDatabase</code> -- this goes red.</p>
Method TestThePortNamesTheRoutinesDatabaseItsGateAsksFor()
{
    Set tFound = ##class(OcuPilot.Port.InteropPort).RoutineResource(..#SPLITNAMESPACE, .tResource)
    Do $$$AssertEquals(tFound _ "|" _ $Get(tResource), "1|%DB_HSCUSTOM", "the port names the routines database's resource")
}

/// <p>Declare that the fake gate's caller holds <var>pPair</var>, <code>resource:permission</code>.</p>
ClassMethod Hold(pPair As %String)
{
    Do $ClassMethod(..#GATE, "Hold", $Piece(pPair, ":", 1), $Piece(pPair, ":", 2))
}

}
