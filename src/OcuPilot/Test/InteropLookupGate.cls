/// <p>Pins <class>OcuPilot.Port.InteropPort</class>'s gate on the lookup and partner endpoints and the six lookup write and transfer
/// tools' pairs against real principals (AD-8, AD-29, AD-44, AD-62, Story 20.5): a principal missing one pair -- the Interoperability
/// menu's <code>%Ens_Portal:USE</code>, the classic Lookup Tables page's <code>%Ens_LookupTables:READ</code> or
/// <code>:WRITE</code>, the partners page's <code>%Ens_ProductionConfig:READ</code>, the export's <code>%Admin_FileSystemAccess:USE</code>,
/// READ on <code>USER</code>'s database or, for a write, WRITE on it (a principal holding READ only) -- is refused 403 naming that pair
/// through the port, on the screen routes, on the Save route and on each tool's pairs, before any vendor call, so a refused call changes
/// no table; a principal holding exactly the set lists, reads, exports and writes through the port and the screen. An export or an import
/// that names a server file is also asked PathPort's pairs, which refuse it by name too.</p>
/// <p>The port legs run in a child process (<method>Probe</method>) that logs in as the principal, so this process never changes
/// identity. It reuses <class>OcuPilot.Test.InteropItemGate</class>'s <code>FailedPair</code>.</p>
/// <p><b>What it needs from the environment:</b> an interoperability-enabled <code>USER</code> namespace and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes users and roles named
/// <code>OcuP205*</code> and writes a probe lookup table in <code>USER</code>. Each principal also holds READ on the install
/// namespace's code database and <code>%Development:USE</code>, as every caller of a route must. The principals and the table
/// are removed after the last test.</p>
Class OcuPilot.Test.InteropLookupGate Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropLookupFixture";

Parameter NAMESPACE = "USER";

Parameter TABLE = "OcuProbe205Gate";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by
/// <code>;</code>: exactly the lookup set (with the file system's pair, which only the export needs), exactly the partner set, then each
/// missing one; <code>OcuP205DbReadOnly</code> holds the file system's pair too, so the export alone is open to a principal that reads
/// the database and cannot write it.</p>
Parameter PRINCIPALS = "OcuP205Lookup:%Development:U,%Ens_Portal:U,%Ens_LookupTables:RW,%DB_USER:RW,%Admin_FileSystemAccess:U;OcuP205Partner:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%DB_USER:R;OcuP205NoPortal:%Development:U,%Ens_LookupTables:RW,%DB_USER:RW;OcuP205NoLookRead:%Development:U,%Ens_Portal:U,%Ens_LookupTables:W,%DB_USER:RW;OcuP205NoLookWrite:%Development:U,%Ens_Portal:U,%Ens_LookupTables:R,%DB_USER:RW;OcuP205NoRead:%Development:U,%Ens_Portal:U,%Ens_LookupTables:RW;OcuP205DbReadOnly:%Development:U,%Ens_Portal:U,%Ens_LookupTables:RW,%DB_USER:R,%Admin_FileSystemAccess:U;OcuP205NoCfgRead:%Development:U,%Ens_Portal:U,%DB_USER:R;OcuP205NoFile:%Development:U,%Ens_Portal:U,%Ens_LookupTables:RW,%DB_USER:RW";

/// <p>The port legs a probe runs, in order, <code>&lt;endpoint&gt;|&lt;type&gt;</code>, with <code>|file</code> after an export that
/// names a server file. The export comes first so the import legs hold its text; the add is followed by the set and the remove, and
/// the delete takes the table the probe's fixture keeps, so a principal admitted to all leaves nothing behind.</p>
Parameter LEGS = "LookupTables|LIST,LookupEntries|LIST,BusinessPartners|LIST,LookupTables|EXPORT,LookupTables|EXPORT|file,LookupTables|IMPORTTABLE,LookupTables|IMPORT,LookupEntries|ADDENTRY,LookupEntries|SETENTRY,LookupEntries|REMOVEENTRY,LookupTables|DELETETABLE";

/// <p>The legs of <parameter>LEGS</parameter> that write a table, delimited by commas.</p>
Parameter WRITELEGS = ",LookupTables|IMPORT,LookupEntries|ADDENTRY,LookupEntries|SETENTRY,LookupEntries|REMOVEENTRY,LookupTables|DELETETABLE,";

/// <p>The tools whose pairs the probe evaluates.</p>
Parameter TOOLS = "InteropLookupEntryAdd,InteropLookupEntrySet,InteropLookupEntryRemove,InteropLookupTableDelete,InteropLookupTableExport,InteropLookupTableImport";

/// <p>The pair a refused leg of each principal names, one per leg of <parameter>LEGS</parameter>, <code>,</code>-separated
/// (empty for an admitted leg), after <code>=</code>; and the first pair each principal fails on for each of
/// <parameter>TOOLS</parameter>, <code>,</code>-separated, after the <code>/</code>.</p>
Parameter EXPECTED = "OcuP205Lookup=,,%Ens_ProductionConfig:READ,,%DB_IRISSYS:READ,,,,,,/,,,,,;OcuP205Partner=%Ens_LookupTables:READ,%Ens_LookupTables:READ,,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ/%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ;OcuP205NoPortal=%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE/%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE,%Ens_Portal:USE;OcuP205NoLookRead=%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_ProductionConfig:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ/%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ;OcuP205NoLookWrite=,,%Ens_ProductionConfig:READ,,%Admin_FileSystemAccess:USE,,%Ens_LookupTables:WRITE,%Ens_LookupTables:WRITE,%Ens_LookupTables:WRITE,%Ens_LookupTables:WRITE,%Ens_LookupTables:WRITE/%Ens_LookupTables:WRITE,%Ens_LookupTables:WRITE,%Ens_LookupTables:WRITE,%Ens_LookupTables:WRITE,%Admin_FileSystemAccess:USE,%Ens_LookupTables:WRITE;OcuP205NoRead=%DB_USER:READ,%DB_USER:READ,%Ens_ProductionConfig:READ,%DB_USER:READ,%DB_USER:READ,%DB_USER:READ,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE/%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE,%Admin_FileSystemAccess:USE,%DB_USER:WRITE;OcuP205DbReadOnly=,,%Ens_ProductionConfig:READ,,%DB_IRISSYS:READ,,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE/%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE,%DB_USER:WRITE,,%DB_USER:WRITE;OcuP205NoCfgRead=%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_ProductionConfig:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ/%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ,%Ens_LookupTables:READ;OcuP205NoFile=,,%Ens_ProductionConfig:READ,,%Admin_FileSystemAccess:USE,,,,,,/,,,,%Admin_FileSystemAccess:USE,";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropLookupGate creates and deletes users and roles and writes a probe lookup table on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP205Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#FIXTURE, "Clear")
    If $$$ISOK(tSC) Set tSC = ..EnsurePrincipals()
    ; %UnitTest skips OnAfterAllTests when this method fails, so a failed setup removes what it made here.
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

/// <p>Remove the principals and their roles and the probe table; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#FIXTURE, "Clear")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropLookupGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $ClassMethod(..#FIXTURE, "Clear")
}

/// <p>The entry of <parameter>EXPECTED</parameter> for <var>pUser</var>: the legs' pairs in <var>pLegs</var> and the tools' first
/// failed pairs in <var>pTools</var>, each a <code>%List</code>.</p>
ClassMethod ExpectedFor(pUser As %String, Output pLegs As %List, Output pTools As %List)
{
    For tI = 1:1:$Length(..#EXPECTED, ";") {
        Set tEntry = $Piece(..#EXPECTED, ";", tI)
        If $Piece(tEntry, "=", 1) = pUser Quit
    }
    Set tBody = $Piece(tEntry, "=", 2)
    Set pLegs = $ListFromString($Piece(tBody, "/", 1), ",")
    Set pTools = $ListFromString($Piece(tBody, "/", 2), ",")
}

/// <p>The code a refusal naming <var>pPair</var> carries: PathPort's own pairs, asked of an export or import that names a server
/// file, are refused <code>PORT.ACCESSDENIED</code>, every other pair <code>AUTH.NOPRIVILEGE</code>.</p>
ClassMethod CodeFor(pPair As %String) As %String
{
    Quit $Select((pPair = "%Admin_FileSystemAccess:USE") || (pPair = "%DB_IRISSYS:READ"): "PORT.ACCESSDENIED", 1: "AUTH.NOPRIVILEGE")
}

/// <p>The probe table with one entry, as every probe starts.</p>
ClassMethod Arrange() As %Status
{
    Quit $ClassMethod(..#FIXTURE, "Put", ..#TABLE, "base", "1")
}

/// <p>AC5: each principal's eleven port legs are admitted or refused naming the pair <parameter>EXPECTED</parameter> says, with
/// 403 <code>AUTH.NOPRIVILEGE</code> on a refusal (<code>PORT.ACCESSDENIED</code> for PathPort's pairs, asked of an export to a
/// server file); a refused leg changes no table, and the exact principal's import, add, set, remove and delete leave only the
/// table's own entry in place before the delete takes it.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_LookupTables:WRITE</code> from
/// <parameter>OcuPilot.Port.InteropPort.LOOKUPWRITEPAIR</parameter> -- the no-write principal's lookup writes reach the vendor and
/// this goes red; drop <code>TYPEIMPORT</code> from <method>OcuPilot.Port.InteropPort.IsLookupWrite</method> -- the import legs of the
/// no-write and read-only principals do; skip <method>OcuPilot.Port.InteropPort.ExportFile</method> in the export -- the server
/// file leg does.</p>
Method TestEachMissingPairIsRefusedByNameThroughThePort()
{
    For tI = 1:1:$Length(..#PRINCIPALS, ";") {
        Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
        Do $$$AssertStatusOK(..Arrange(), tUser _ ": the probe table is arranged")
        Set tBefore = $ClassMethod(..#FIXTURE, "Snapshot")
        Set tProbe = ..ProbeAs(tUser)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal: " _ tProbe.%ToJSON())
        Do ..ExpectedFor(tUser, .tExpected)
        Set tWrites = 0
        For tJ = 1:1:$Length(..#LEGS, ",") {
            Set tLeg = $Piece(..#LEGS, ",", tJ)
            Set tWanted = $List(tExpected, tJ)
            Do $$$AssertEquals(##class(OcuPilot.Test.InteropItemGate).LegText(tProbe, tLeg), $Select(tWanted = "": "200  ", 1: "403 " _ ..CodeFor(tWanted) _ " " _ tWanted), tUser _ ": " _ tLeg)
            If (tWanted = "") && (..#WRITELEGS [ ("," _ tLeg _ ",")) Set tWrites = 1
        }
        If 'tWrites Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Snapshot"), tBefore, tUser _ ": a refused leg changed no table")
        Do $ClassMethod(..#FIXTURE, "Clear")
    }
}

/// <p>AC5: each of the six tools' pairs, evaluated for each principal in the namespace the request is scoped to, fail naming
/// the first pair the principal lacks, in the order screen pairs, the tool's own resource (the lookup write pair, or the file
/// system's pair for the export), database permission; the exact principal holds every pair, and a principal that reads the database
/// and cannot write it holds the export's.</p>
/// <p>Mutation (Rule 19): drop <code>%Ens_LookupTables:WRITE</code> from
/// <method>OcuPilot.Screen.Tool.InteropLookupEntryAction.PrivilegePairs</method> -- the no-write row goes red; make the export's
/// <code>DATABASEPERMISSION</code> WRITE -- the read-only principal's export row does; make its own resource the Interoperability
/// menu's -- the rows of the principals without the file system's pair do; make the import's <code>WRITEPERMISSION</code> READ -- the
/// no-write principal's import row does.</p>
Method TestEachMissingPairIsRefusedByNameOnEachTool()
{
    For tI = 1:1:$Length(..#PRINCIPALS, ";") {
        Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
        Set tProbe = ..ProbeAs(tUser)
        Do ..ExpectedFor(tUser, .tExpected, .tWanted)
        Do $$$AssertEquals(tProbe.%Get("error") _ "|" _ tProbe.%Get("username"), "|" _ tUser, tUser _ ": the probe ran as the principal")
        For tJ = 1:1:$Length(..#TOOLS, ",") {
            Set tTool = $Piece(..#TOOLS, ",", tJ)
            Do $$$AssertEquals($Select($IsObject(tProbe.%Get("tools")): tProbe.tools.%Get(tTool), 1: "absent"), $List(tWanted, tJ), tUser _ ": " _ tTool _ " fails on " _ $Select($List(tWanted, tJ) = "": "nothing", 1: $List(tWanted, tJ)))
        }
        Do $ClassMethod(..#FIXTURE, "Clear")
    }
}

/// <p>AC5: on the screen routes each principal is refused naming the pair its read or action needs, before the table is read or
/// written: the tables list's read, the entries list's read, the partners list's read, the Set value and Delete row actions and the
/// Save, the last also for a body the rules after the gate would refuse, so the refusal is the Save's own gate and not a later
/// one; the tables list's export and import actions, to the browser, from this computer and from a server file, which also ask
/// PathPort's pairs; and the exact principals read, write and transfer through the screen.</p>
/// <p>Mutation (Rule 19): delete the <code>..Gate</code> call from <method>OcuPilot.Area.Interop.ItemSave.HandleCreate</method>
/// -- the illegal-name Save rows go red; make the export's <code>DATABASEPERMISSION</code> WRITE -- the read-only principal's export
/// does; make the import's <code>WRITEPERMISSION</code> READ -- the no-write principal's import does.</p>
Method TestEachMissingPairIsRefusedByNameOnTheScreenRoutes()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Do $$$AssertStatusOK(..Arrange(), "the probe table is arranged")
    For tCase = $ListBuild("OcuP205NoPortal", "/screens/interop.lookuptables", "%Ens_Portal:USE"), $ListBuild("OcuP205NoLookRead", "/screens/interop.lookuptables", "%Ens_LookupTables:READ"), $ListBuild("OcuP205NoRead", "/screens/interop.lookuptables", "%DB_USER:READ"), $ListBuild("OcuP205NoLookRead", "/screens/interop.lookupentries", "%Ens_LookupTables:READ"), $ListBuild("OcuP205NoCfgRead", "/screens/interop.businesspartners", "%Ens_ProductionConfig:READ"), $ListBuild("OcuP205NoPortal", "/screens/interop.businesspartners", "%Ens_Portal:USE") {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ $List(tCase, 2) _ "/read?ns=" _ ..#NAMESPACE _ "&table=" _ ..#TABLE _ "&maxRows=5", $List(tCase, 1), ..PreparedPassword, .tStatus, .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.InteropItemGate).FailedPair(tRaw), "403 " _ $List(tCase, 3), $List(tCase, 1) _ ": " _ $List(tCase, 2) _ " is refused naming the pair: " _ $Get(tRaw))
    }
    Set tId = ##class(OcuPilot.Test.InteropLookupControl).Id(..#TABLE, "base")
    For tCase = $ListBuild("OcuP205NoPortal", "%Ens_Portal:USE"), $ListBuild("OcuP205NoLookRead", "%Ens_LookupTables:READ"), $ListBuild("OcuP205NoLookWrite", "%Ens_LookupTables:WRITE"), $ListBuild("OcuP205DbReadOnly", "%DB_USER:WRITE"), $ListBuild("OcuP205NoRead", "%DB_USER:READ") {
        Set tRequest = {"action": "set", "values": {"Value": "gate"}}
        Do tRequest.%Set("id", tId, "string")
        Set tStatus = ..Post("/screens/interop.lookupentries/action", tRequest, $List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.InteropItemGate).FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the Set value row action is refused naming the pair: " _ $Get(tRaw))
        Set tRequest = {"action": "delete"}
        Do tRequest.%Set("id", ..#TABLE, "string")
        Set tStatus = ..Post("/screens/interop.lookuptables/action", tRequest, $List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.InteropItemGate).FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the Delete row action is refused naming the pair: " _ $Get(tRaw))
        Set tSave = {"Table": (..#TABLE), "Key": "gk", "Value": "v"}
        Set tStatus = ..Post("/interop/lookup-entries", tSave, $List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.InteropItemGate).FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": the Save is refused naming the pair: " _ $Get(tRaw))
        Set tSave = {"Table": (..#TABLE), "Key": "", "Value": "v"}
        Set tStatus = ..Post("/interop/lookup-entries", tSave, $List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.InteropItemGate).FailedPair(tRaw), "403 " _ $List(tCase, 2), $List(tCase, 1) _ ": a Save of an empty key is refused naming the pair, not the key: " _ $Get(tRaw))
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Entries", ..#TABLE), "base=1", "no refused request changed the table")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/interop.lookupentries/read?ns=" _ ..#NAMESPACE _ "&table=" _ ..#TABLE _ "&maxRows=5", "OcuP205Lookup", ..PreparedPassword, .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the exact principal reads the entries: " _ $Get(tRaw))
    Set tRequest = {"action": "set", "values": {"Value": "gate"}}
    Do tRequest.%Set("id", tId, "string")
    Do $$$AssertEquals(..Post("/screens/interop.lookupentries/action", tRequest, "OcuP205Lookup", .tRaw), 200, "and its Set value is admitted: " _ $Get(tRaw))
    Do $$$AssertEquals(..Post("/interop/lookup-entries", {"Table": (..#TABLE), "Key": "gk", "Value": "v"}, "OcuP205Lookup", .tRaw), 201, "and its Save: " _ $Get(tRaw))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Entries", ..#TABLE), "base=gate;gk=v", "which wrote what they sent")
    Set tTableText = ##class(OcuPilot.Test.InteropLookupTransfer).ExportText(..#TABLE _ ".LUT")
    Set tFile = {"root": "/ocupilot-gate-probe/", "path": "gate.xml"}
    Set tLocal = {"fileName": "gate.xml", "content": (tTableText)}
    ; <principal>|<action>|<the pair it is refused naming>
    For tCase = $ListBuild("OcuP205NoPortal", "export-browser", "%Ens_Portal:USE"), $ListBuild("OcuP205NoLookRead", "export-browser", "%Ens_LookupTables:READ"), $ListBuild("OcuP205NoFile", "export-browser", "%Admin_FileSystemAccess:USE"), $ListBuild("OcuP205NoFile", "export", "%Admin_FileSystemAccess:USE"), $ListBuild("OcuP205NoPortal", "import-local", "%Ens_Portal:USE"), $ListBuild("OcuP205NoLookRead", "import-local", "%Ens_LookupTables:READ"), $ListBuild("OcuP205NoRead", "import-local", "%DB_USER:READ"), $ListBuild("OcuP205NoLookWrite", "import-local", "%Ens_LookupTables:WRITE"), $ListBuild("OcuP205DbReadOnly", "import-local", "%DB_USER:WRITE"), $ListBuild("OcuP205NoFile", "import", "%Admin_FileSystemAccess:USE"), $ListBuild("OcuP205Lookup", "import", "%DB_IRISSYS:READ"), $ListBuild("OcuP205NoLookWrite", "import", "%Ens_LookupTables:WRITE") {
        Set tAction = $List(tCase, 2)
        Set tRequest = {"action": (tAction)}
        Do tRequest.%Set("id", $Select(tAction = "export-browser": ..#TABLE, tAction = "export": ..#TABLE, 1: "import"), "string")
        Do tRequest.%Set("values", $Select(tAction = "import-local": tLocal, tAction = "export-browser": {}, 1: tFile))
        Set tStatus = ..Post("/screens/interop.lookuptables/action", tRequest, $List(tCase, 1), .tRaw)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.InteropItemGate).FailedPair(tRaw), "403 " _ $List(tCase, 3), $List(tCase, 1) _ ": " _ tAction _ " is refused naming the pair: " _ $Extract($Get(tRaw), 1, 300))
    }
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Entries", ..#TABLE), "base=gate;gk=v", "no refused transfer changed the table")
    Set tRequest = {"action": "export-browser", "id": (..#TABLE), "values": {}}
    Set tStatus = ..Post("/screens/interop.lookuptables/action", tRequest, "OcuP205DbReadOnly", .tRaw)
    Do $$$AssertEquals(tStatus, 200, "a principal that reads the database and cannot write it exports to the browser: " _ $Extract($Get(tRaw), 1, 300))
    Set tRequest = {"action": "import-local", "id": "import", "values": (tLocal)}
    Set tStatus = ..Post("/screens/interop.lookuptables/action", tRequest, "OcuP205Lookup", .tRaw)
    Do $$$AssertEquals(tStatus, 200, "and the exact principal imports from this computer: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Entries", ..#TABLE), "base=gate;gk=v", "replacing the table with its own export")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutPartner"), "a probe partner is arranged")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/interop.businesspartners/read?ns=" _ ..#NAMESPACE _ "&maxRows=50", "OcuP205Partner", ..PreparedPassword, .tStatus, .tRaw)
    Do $$$AssertEquals(tStatus, 200, "the exact partner principal reads the partners: " _ $Extract($Get(tRaw), 1, 200))
    Do $$$AssertTrue($Get(tRaw) [ $Parameter(..#FIXTURE, "PARTNER"), "and sees the probe partner")
}

/// <p>The person's POST to <var>pPath</var> as <var>pUser</var>: the HTTP status; the raw body in <var>pRaw</var>.</p>
Method Post(pPath As %String, pBody As %DynamicObject, pUser As %String, Output pRaw) As %Integer
{
    Kill tExtra
    Set tUrl = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ pPath _ "?ns=" _ ..#NAMESPACE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tUrl, pUser, ..PreparedPassword, .tStatus, .pRaw, .tHeaders, pBody.%ToJSON(), "application/json", .tExtra, 90)
    Quit +$Get(tStatus)
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropLookupGate).Probe($Job, pUser, ..#NAMESPACE)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 180)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 180 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of <parameter>LEGS</parameter>
/// through <class>OcuPilot.Port.InteropPort</class> in <var>pNamespace</var> against the probe table (the import legs carrying the
/// export the export leg answered), evaluate each of
/// <parameter>TOOLS</parameter>' pairs for a request scoped to <var>pNamespace</var>, and signal <code>{loggedIn, username,
/// "&lt;endpoint&gt;|&lt;type&gt;": {http, code, failedPair}, tools: {&lt;tool&gt;: failed pair}}</code> to process
/// <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String, pNamespace As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        ; The export the export leg answered and the import it reviews, which the import legs carry.
        Set tText = ""
        Set tDigest = ""
        Set tEntries = ""
        Set tModified = ""
        For tI = 1:1:$Length(..#LEGS, ",") {
            Set tLegName = $Piece(..#LEGS, ",", tI)
            Set tEndpoint = $Piece(tLegName, "|", 1)
            Set tType = $Piece(tLegName, "|", 2)
            Set tVariant = $Piece(tLegName, "|", 3)
            Kill tQuery
            Set tQuery("namespace") = pNamespace
            Set tBody = ""
            If tType = "LIST" {
                Set tQuery("table") = ..#TABLE
                Set tQuery("maxRows") = 5
            } ElseIf (tType = "DELETETABLE") || (tType = "EXPORT") {
                Set tQuery("id") = ..#TABLE
                If tVariant = "file" {
                    Set tQuery("root") = "/ocupilot-gate-probe/"
                    Set tQuery("path") = "gate.xml"
                }
            } ElseIf (tType = "IMPORTTABLE") || (tType = "IMPORT") {
                Set tQuery("id") = "import"
                Set tQuery("fileName") = "gate.xml"
                Set tQuery("content") = tText
                If tType = "IMPORT" {
                    Set tQuery("digest") = tDigest
                    Set tQuery("entries") = tEntries
                    Set tQuery("modified") = tModified
                }
            } Else {
                Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(..#TABLE, $Case(tType, "ADDENTRY": "gk", "SETENTRY": "gk", : "gk")))
                If tType '= "REMOVEENTRY" Set tBody = {"Value": "gate"}
            }
            If (tType = "SETENTRY") Set tBody = {"Value": "gate2"}
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke(tEndpoint, tType, .tQuery, tBody, .tResult, .tHttp, .tFault)
            If (tType = "EXPORT") && (tVariant = "") && $IsObject($Get(tResult)) && $IsObject(tResult.%Get("lines")) {
                Set tIterator = tResult.lines.%GetIterator()
                While tIterator.%GetNext(.tIndex, .tLine) {
                    Set tText = tText _ $Select(tIndex = 0: "", 1: $Char(10)) _ tLine
                }
            }
            If (tType = "IMPORTTABLE") && $IsObject($Get(tResult)) {
                Set tDigest = tResult.%Get("Digest")
                Set tEntries = tResult.%Get("Entries")
                Set tModified = tResult.%Get("Modified")
            }
            Set tLeg = {}
            Do tLeg.%Set("http", +tHttp, "number")
            If $IsObject(tFault) {
                Do tLeg.%Set("code", tFault.%Get("code"))
                If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
            }
            Do tOut.%Set(tLegName, tLeg)
        }
        Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
        Set tTools = {}
        For tI = 1:1:$Length(..#TOOLS, ",") {
            Set tTool = $Piece(..#TOOLS, ",", tI)
            Set tPairs = $ClassMethod("OcuPilot.Screen.Tool." _ tTool, "PrivilegePairs", "", .tResolved)
            Set tFailed = ""
            If 'tResolved {
                Set tFailed = "unresolved"
            } Else {
                If ##class(OcuPilot.Screen.Gate).EvaluateRequired(tPairs, .tFailed) Set tFailed = ""
            }
            Do tTools.%Set(tTool, tFailed)
        }
        Do tOut.%Set("tools", tTools)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Create each of <parameter>PRINCIPALS</parameter> with a role of its own holding its pairs and READ on the install
/// namespace's code database, then read the decisive grants back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Do ##class(OcuPilot.Port.AtelierPort).DatabaseResources(tOrigNS, .tHome, .tGlobals, .tMapped, .tResolved)
        If 'tResolved || (tHome = "") {
            Set tSC = $$$ERROR($$$GeneralError, "the install namespace's code database could not be resolved")
            Quit
        }
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tEntry = $Piece(..#PRINCIPALS, ";", tI)
            Set tUser = $Piece(tEntry, ":", 1)
            Set tRole = tUser _ "Role"
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the lookup endpoints' gate (throwaway)", tHome _ ":R," _ $Piece(tEntry, ":", 2, *), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot lookup gate test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.InteropLookupGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) Quit
        For tCase = $ListBuild("OcuP205Lookup", "%Ens_LookupTables", "WRITE", 1), $ListBuild("OcuP205NoLookWrite", "%Ens_LookupTables", "WRITE", 0), $ListBuild("OcuP205NoLookRead", "%Ens_LookupTables", "READ", 0), $ListBuild("OcuP205DbReadOnly", "%DB_USER", "WRITE", 0), $ListBuild("OcuP205DbReadOnly", "%DB_USER", "READ", 1), $ListBuild("OcuP205NoPortal", "%Ens_Portal", "USE", 0), $ListBuild("OcuP205NoCfgRead", "%Ens_ProductionConfig", "READ", 0), $ListBuild("OcuP205Partner", "%Ens_ProductionConfig", "READ", 1), $ListBuild("OcuP205Lookup", "%Admin_FileSystemAccess", "USE", 1), $ListBuild("OcuP205DbReadOnly", "%Admin_FileSystemAccess", "USE", 1), $ListBuild("OcuP205NoFile", "%Admin_FileSystemAccess", "USE", 0), $ListBuild("OcuP205NoLookWrite", "%Admin_FileSystemAccess", "USE", 0) {
            If $SYSTEM.Security.CheckUserPermission($List(tCase, 1), $List(tCase, 2), $List(tCase, 3)) '= $List(tCase, 4) {
                Set tSC = $$$ERROR($$$GeneralError, "the principal " _ $List(tCase, 1) _ "'s " _ $List(tCase, 2) _ ":" _ $List(tCase, 3) _ " did not read back as declared")
                Quit
            }
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
