/// <p>Pins Story 24.18 Batch 1's gate as real principals in a child process (AD-8, AD-29, AD-39, AD-62): every read and write of the HL7 schemas is refused before any vendor call and before any value is
/// judged, naming the pair that fails: the portal's, the classic page's own resource, the write resource an add, an import and a delete add, and WRITE on the namespace's database. A write an admitted
/// principal makes leaves its roles, user and namespace as they were; a refused one changes nothing. The port's pair sets are the classic page's, PathPort's pairs are asked of a server file alone, and the
/// five tools declare the write pair and the database's WRITE.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropHl7Case</class> needs; it creates and removes five principals.</p>
Class OcuPilot.Test.InteropHl7SchemaGate Extends OcuPilot.Test.InteropHl7Case
{

Parameter GENERATOR = "OcuPilot.Test.InteropArchiveFixture";

/// <p>The schemas the legs read, add and delete.</p>
Parameter HELD = "OcuProbe2418ga";

Parameter DROP = "OcuProbe2418gd";

Parameter NEW = "OcuProbe2418gn";

/// <p>The principals: all the pairs; the classic page's resource at READ; no classic page resource; no portal pair; and READ on <code>USER</code>'s database.</p>
Parameter PRINCIPALS = "OcuProbe2418hAll:%Ens_Portal:U,%Ens_EDISchema:RW,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuProbe2418hNoWrite:%Ens_Portal:U,%Ens_EDISchema:R,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuProbe2418hNoRead:%Ens_Portal:U,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuProbe2418hNoPortal:%Ens_EDISchema:RW,%DB_USER:RW,%DB_HSCUSTOM:RW;OcuProbe2418hDbRead:%Ens_Portal:U,%Ens_EDISchema:RW,%DB_USER:R,%DB_HSCUSTOM:RW";

/// <p>The seven legs of every principal, in order: the list, one schema, an export to this browser, the import file's read, an add, a delete and an import write.</p>
Parameter LEGNAMES = "list,schema,export,importFile,add,delete,import";

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
    Set tSC = ##super()
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = "OcuP2418h" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $$$OK
}

/// <p>The legs of every principal as the array the child runs.</p>
ClassMethod Legs() As %DynamicArray
{
    Quit [
        {"name": "list", "endpoint": "Hl7Schemas", "type": "LIST"},
        {"name": "schema", "endpoint": "Hl7Schemas", "type": "HL7SCHEMA", "query": {"id": (..#HELD)}},
        {"name": "export", "endpoint": "Hl7Schemas", "type": "EXPORTHL7SCHEMA", "query": {"id": (..#HELD)}},
        {"name": "importFile", "endpoint": "Hl7Schemas", "type": "HL7IMPORTFILE", "query": {"id": "import", "fileName": "g.xml", "content": "not xml"}},
        {"name": "add", "endpoint": "Hl7Schemas", "type": "ADDHL7SCHEMA", "query": {"id": (..#NEW)}, "body": {"Description": "gate"}},
        {"name": "delete", "endpoint": "Hl7Schemas", "type": "DELETEHL7SCHEMA", "query": {"id": (..#DROP)}},
        {"name": "import", "endpoint": "Hl7Schemas", "type": "IMPORTHL7SCHEMA", "query": {"id": "import", "fileName": "g.xml", "content": "not xml"}}
    ]
}

/// <p>The answer a leg is expected to carry, <code>http|code|failedPair</code>: <var>pPair</var> empty is an admitted call.</p>
ClassMethod Expect(pPair As %String = "") As %String
{
    If pPair = "" Quit "200||"
    Quit "403|" _ ##class(OcuPilot.Kernel.Denial).Code() _ "|" _ pPair
}

/// <p>Store the held schema and the one the delete leg removes.</p>
ClassMethod Arrange() As %Status
{
    Set tFx = ..#FIXTURE
    Do $ClassMethod(tFx, "DropSchemas")
    Set tSC = $ClassMethod(tFx, "ProbeSchema", ..#HELD, ..#SOURCE, "2.5", "held")
    Quit $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeSchema", ..#DROP, ..#SOURCE, "2.5", "drop"))
}

/// <p>AC5: the gate, as real principals in a child process, refuses before any vendor call and before any value is judged, naming the pair, and writes nothing when it refuses. A principal holding every pair
/// reads and writes, and an import it has not reviewed is refused as changed, after the gate; one whose classic page resource is READ alone reads and is refused each write naming
/// <code>%Ens_EDISchema:WRITE</code>; one without it is refused every leg naming its READ; one without the portal's pair every leg naming it; one who can only read <code>USER</code>'s database reads and
/// is refused each write naming <code>%DB_USER:WRITE</code>.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Port.InteropPort.HL7WRITEPAIR</parameter> from the endpoint's write pairs in <method>OcuPilot.Port.InteropPort.Pairs</method> -- the <code>NoWrite</code> legs go red;
/// drop the import from <method>OcuPilot.Port.InteropPort.IsAnyWrite</method> -- the <code>DbRead</code> import leg goes red.</p>
Method TestTheGateRefusesEachPrincipalBeforeAnyVendorCall()
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword)
    Do $$$AssertStatusOK(tSC, "the principals are created")
    If $$$ISERR(tSC) Quit
    Set tOk = ..Expect()
    Set tImport = "409|INTEROP.HL7.IMPORTCHANGED|"
    Set tWrite = ..Expect("%Ens_EDISchema:WRITE")
    Set tRead = ..Expect("%Ens_EDISchema:READ")
    Set tPortal = ..Expect("%Ens_Portal:USE")
    Set tDb = ..Expect("%DB_USER:WRITE")
    ; list, schema, export, importFile, add, delete, import
    Set tExpected("OcuProbe2418hAll") = $ListBuild(tOk, tOk, tOk, "409|INTEROP.HL7.IMPORTSHAPE|", tOk, tOk, "409|INTEROP.HL7.IMPORTSHAPE|")
    Set tExpected("OcuProbe2418hNoWrite") = $ListBuild(tOk, tOk, tOk, "409|INTEROP.HL7.IMPORTSHAPE|", tWrite, tWrite, tWrite)
    Set tExpected("OcuProbe2418hNoRead") = $ListBuild(tRead, tRead, tRead, tRead, tRead, tRead, tRead)
    Set tExpected("OcuProbe2418hNoPortal") = $ListBuild(tPortal, tPortal, tPortal, tPortal, tPortal, tPortal, tPortal)
    Set tExpected("OcuProbe2418hDbRead") = $ListBuild(tOk, tOk, tOk, "409|INTEROP.HL7.IMPORTSHAPE|", tDb, tDb, tDb)
    Set tUser = ""
    For {
        Set tUser = $Order(tExpected(tUser))
        If tUser = "" Quit
        Do $$$AssertStatusOK(..Arrange(), tUser _ ": the held and the doomed schema are stored")
        Set tOut = $ClassMethod(..#FIXTURE, "ProbeAs", tUser, ..Legs())
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tUser _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertTrue(tOut.loggedIn, tUser _ ": the principal logged in")
        For tI = 1:1:$Length(..#LEGNAMES, ",") {
            Set tLegName = $Piece(..#LEGNAMES, ",", tI)
            Set tLeg = tOut.legs.%Get(tLegName)
            Set tGot = $Select($IsObject(tLeg): tLeg.http _ "|" _ tLeg.%Get("code") _ "|" _ tLeg.%Get("failedPair"), 1: "no answer")
            Do $$$AssertEquals(tGot, $List(tExpected(tUser), tI), tUser _ ": the " _ tLegName _ " leg is answered as declared")
        }
        Set tAdmitted = (tUser = "OcuProbe2418hAll")
        Set tFx = ..#FIXTURE
        Do $$$AssertEquals($ClassMethod(tFx, "Held", ..#NEW) _ "|" _ $ClassMethod(tFx, "Held", ..#DROP) _ "|" _ $ClassMethod(tFx, "Held", ..#HELD), $Select(tAdmitted: "1|0|1", 1: "0|1|1"), tUser _ ": an admitted add and delete changed the schemas and a refused one did not")
        If tAdmitted {
            Do $$$AssertEquals(tOut.before _ "|" _ tOut.sameUser _ "|" _ tOut.sameNamespace, tOut.after _ "|1|1", tUser _ ": its roles, user and namespace read the same after its writes")
        }
    }
}

/// <p>AC5: the endpoint's pair sets are the classic page's: the list, the one-schema read, the import file's read and an export ask the portal's pair and the page's READ, and each write adds the page's WRITE;
/// the port serves exactly those types, the tools declare the write pair and WRITE on the namespace's database beyond the screen's own, and PathPort's pairs are asked of a server file alone.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Port.InteropPort.HL7WRITEPAIR</parameter> from the endpoint's write pairs in <method>OcuPilot.Port.InteropPort.Pairs</method> -- the write rows go red.</p>
Method TestThePairSetsAreTheClassicPagesAndTheToolsAddTheWritePair()
{
    Set tRead = "%Ens_Portal:USE,%Ens_EDISchema:READ"
    Set tWrite = tRead _ ",%Ens_EDISchema:WRITE"
    For tCase = $ListBuild("LIST", tRead), $ListBuild("HL7SCHEMA", tRead), $ListBuild("HL7IMPORTFILE", tRead), $ListBuild("EXPORTHL7SCHEMA", tRead), $ListBuild("ADDHL7SCHEMA", tWrite), $ListBuild("IMPORTHL7SCHEMA", tWrite), $ListBuild("DELETEHL7SCHEMA", tWrite) {
        Set tPairs = $ClassMethod(..#PORT, "Pairs", "Hl7Schemas", $List(tCase, 1))
        Set tText = ""
        For tI = 1:1:$ListLength(tPairs) {
            Set tText = tText _ $Select(tText = "": "", 1: ",") _ $List($List(tPairs, tI), 1) _ ":" _ $List($List(tPairs, tI), 2)
        }
        Do $$$AssertEquals(tText, $List(tCase, 2), $List(tCase, 1) _ ": the pairs the port asks")
        Do $$$AssertTrue($ClassMethod(..#PORT, "Serves", "Hl7Schemas", $List(tCase, 1)), $List(tCase, 1) _ ": the endpoint serves it")
    }
    Do $$$AssertTrue('$ClassMethod(..#PORT, "Serves", "WorkflowRoles", "ADDHL7SCHEMA") && '$ClassMethod(..#PORT, "Serves", "LookupTables", "IMPORTHL7SCHEMA") && '$ClassMethod(..#PORT, "Serves", "Hl7Schemas", "ADDWORKFLOWROLE") && '$ClassMethod(..#PORT, "Serves", "Hl7Schemas", "IMPORT"), "and no other family's type")
    For tTool = "Add", "Delete", "Import", "Export" {
        Set tClass = ..#TOOLPREFIX _ tTool
        Set tPairs = $ClassMethod(tClass, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue(tResolved && $ListFind(tPairs, $ListBuild("%Ens_EDISchema", "READ")) && $ListFind(tPairs, $ListBuild("%Ens_Portal", "USE")), tClass _ ": the tool declares the screen's pairs")
        If tTool '= "Export" Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%Ens_EDISchema", "WRITE")), tClass _ ": and the write pair")
        Set tWritesDb = 0
        For tI = 1:1:$ListLength(tPairs) {
            If ($List($List(tPairs, tI), 1) [ "%DB_") && ($List($List(tPairs, tI), 2) = $Select(tTool = "Export": "READ", 1: "WRITE")) Set tWritesDb = 1
        }
        Do $$$AssertTrue(tWritesDb, tClass _ ": and " _ $Select(tTool = "Export": "READ", 1: "WRITE") _ " on the namespace's database")
        Do $$$AssertEquals($Parameter(tClass, "CLASSICPAGES"), "EnsPortal.HL7.SchemaMain" _ $Select(tTool = "Add": ",EnsPortal.HL7.Dialog.CustomSchema", 1: ""), tClass _ ": naming the classic page whose resource may be assigned, and for the add its New dialog")
    }
    For tTool = "Import", "Export" {
        Set tClass = ..#TOOLPREFIX _ tTool
        Set tFile = $ClassMethod(tClass, "ArgumentPairs", "", {"root": "/some/dir", "path": "f.xml"}, .tResolved)
        Do $$$AssertTrue(tResolved && $ListFind(tFile, $ListBuild("%Admin_FileSystemAccess", "USE")) && $ListFind(tFile, $ListBuild("%DB_IRISSYS", "READ")), tClass _ ": a server file asks PathPort's pairs")
        Set tNone = $ClassMethod(tClass, "ArgumentPairs", "", {"Name": "T"}, .tResolved)
        Do $$$AssertTrue(tResolved && ($ListLength(tNone) = 0), tClass _ ": a call naming no root asks none")
    }
}

}
