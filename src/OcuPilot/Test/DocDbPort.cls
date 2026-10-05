/// <p>Pins <class>OcuPilot.Port.DocDbPort</class> against the instance's real <code>%SYSTEM.DocDB</code> in
/// <code>USER</code> (AD-7, AD-29, AD-36, Story 19.17): a disabled service refuses every call 409 with no
/// vendor call and one vendor audit row each; the vendor's service check answers 1 enabled and #822
/// disabled; the list answers each database's row and the read tool answers the same rows; a drop
/// reaches a database in any case; a taken class, a taken name, a mapped package and an invalid name are
/// refused in the port's own words, the last two before the service; and an absent database is 404, logged only for a drop.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it enables
/// <code>%Service_DocDB</code> and creates and drops probe databases named <code>OcuProbe1917*</code>.
/// The service is put back as it was found, and read back, after every test, and every probe is removed
/// and read back gone.</p>
Class OcuPilot.Test.DocDbPort Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SERVICE_CONFIG";

Parameter PROBE = "OcuPilot.Test.DocDbProbe";

Parameter PORT = "OcuPilot.Port.DocDbPort";

Parameter NAMESPACE = "USER";

/// <p>Whether <code>%Service_DocDB</code> was enabled before the test, put back after it.</p>
Property PreparedService As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedService = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DocDbPort enables %Service_DocDB and creates and drops document databases on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE)
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tSC = $ClassMethod(..#PROBE, "ServiceEnabled", .tPrior)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedService = tPrior
    Quit $$$OK
}

/// <p>The service is put back and read back, and every probe is removed and read back gone, whether
/// the test passed or failed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreService", ..PreparedService), "%Service_DocDB is put back as it was found")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE), "every probe database and class is removed")
    Quit $$$OK
}

/// <p>One port call of <var>pType</var> on <var>pName</var> in <var>pNamespace</var>, as
/// <code>http code</code>.</p>
ClassMethod Call(pType As %String, pName As %String = "", Output pResult, pNamespace As %String = {..#NAMESPACE}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    If pName '= "" Set tQuery("name") = pName
    Set tQuery("maxRows") = 100
    Set tFault = ""
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Databases", pType, .tQuery, "", .pResult, .tHttp, .tFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject(tFault): tFault.%Get("code"), 1: "")
}

/// <p>AC2: with the service disabled the list, the read, the create and the drop are each refused 409
/// <code>DOCDB.SERVICE.DISABLED</code>, nothing is created or dropped, and each refusal costs exactly
/// one vendor access-denied row.</p>
/// <p>Mutation (Rule 19): skip the <code>ServiceStatus</code> check in
/// <method>OcuPilot.Port.DocDbPort.Invoke</method> -- the vendor is called, the create makes its database
/// and this goes red.</p>
Method TestADisabledServiceRefusesEveryCallWithOneAuditRow()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreService", 0), "%Service_DocDB is disabled for this test")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", ..#NAMESPACE, "OcuProbe1917A"), "a probe database is made directly")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "DeniedCount", .tBefore), "the access-denied rows are counted")
    Set tDisabled = "409 " _ ##class(OcuPilot.Api.DocDbError).#SERVICEDISABLED
    Do $$$AssertEquals(..Call("LIST"), tDisabled, "the list is refused")
    Do $$$AssertEquals(..Call("DATABASE", "OcuProbe1917A"), tDisabled, "the read is refused")
    Do $$$AssertEquals(..Call("CREATE", "OcuProbe1917B"), tDisabled, "the create is refused")
    Do $$$AssertEquals(..Call("DROP", "OcuProbe1917A"), tDisabled, "the drop is refused")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "OcuProbe1917B"), "nothing was created")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "OcuProbe1917A"), "nothing was dropped")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "DeniedCount", .tAfter), "the rows are counted again")
    Do $$$AssertEquals(tAfter - tBefore, 4, "each refusal wrote one vendor access-denied row")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ServiceEnabled", .tEnabled), "the service reads")
    Do $$$AssertEquals(tEnabled, 0, "and stays disabled")
}

/// <p>The vendor's service check, which the port calls by name, answers 1 while
/// <code>%Service_DocDB</code> is enabled and an error status carrying #822 while it is disabled.</p>
Method TestTheServiceCheckSignature()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreService", 0), "the service is disabled")
    Set tStatus = $$CheckServiceStatus^%SYS.DOCDB("OcuProbe1917A", ..#NAMESPACE)
    Do $$$AssertEquals($Select(tStatus = 1: "1", 1: $System.Status.GetErrorCodes(tStatus)), "822", "disabled answers #822")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableService", .tPrior), "the service is enabled")
    Do $$$AssertEquals($$CheckServiceStatus^%SYS.DOCDB("OcuProbe1917A", ..#NAMESPACE), 1, "enabled answers 1")
    Do $$$AssertEquals(##class(OcuPilot.Port.DocDbPort).ServiceStatus("OcuProbe1917A", ..#NAMESPACE), 1, "as the port reads it")
}

/// <p>AC1: with the service enabled, the list answers each probe database as a row -- its name, its
/// class, an empty document type and an empty resource -- and the screen's declared read and its read
/// tool answer the same rows.</p>
/// <p>Mutation (Rule 19): drop <code>Class</code> from <method>OcuPilot.Port.DocDbPort.Row</method> --
/// this goes red.</p>
Method TestTheListAnswersEachDatabase()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableService", .tPrior), "the service is enabled")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", ..#NAMESPACE, "OcuProbe1917A"), "an unqualified probe is made")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", ..#NAMESPACE, "OcuProbe1917.Q"), "and a qualified one")
    Do $$$AssertEquals(..Call("LIST", "", .tRows), "200 ", "the list answers")
    Do $$$AssertEquals(..Probes($Get(tRows)), "OcuProbe1917.Q/OcuProbe1917.Q//;OcuProbe1917A/ISC.DM.OcuProbe1917A//", "each probe's name, class, document type and resource")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.ExplorerDocDbList", "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the screen's read answers")
    Do $$$AssertEquals(..Probes($Select($IsObject($Get(tAnswer)): tAnswer.rows, 1: "")), "OcuProbe1917.Q/OcuProbe1917.Q//;OcuProbe1917A/ISC.DM.OcuProbe1917A//", "the same rows")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("explorer.docdb.read", .tTool, 1)
    Do $$$AssertStatusOK(tSC, "the read tool resolves")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp), 200, "the read tool answers")
    Do $$$AssertEquals(..Probes($Select($IsObject($Get(tResult)): tResult.rows, 1: "")), "OcuProbe1917.Q/OcuProbe1917.Q//;OcuProbe1917A/ISC.DM.OcuProbe1917A//", "the same rows")
}

/// <p>The read of one database answers its row and the namespace, in any case of its name, and a drop
/// in another case reaches it: its class, the global holding its documents and its row are gone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.DocDbPort.Drop</method> answer 1 without calling
/// the vendor -- the database, its class and its documents survive and this goes red.</p>
Method TestADropInAnyCaseReachesTheDatabase()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableService", .tPrior), "the service is enabled")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", ..#NAMESPACE, "OcuProbe1917A"), "a probe is made")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddDocument", ..#NAMESPACE, "OcuProbe1917A", {"probe": 1917}), "a document is saved into it")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "DataGlobal", ..#NAMESPACE, "ISC.DM.OcuProbe1917A", .tGlobal), "its class's storage reads")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "HasData", ..#NAMESPACE, $Get(tGlobal)), "the document sits in the class's data global '" _ $Get(tGlobal) _ "'")
    Do $$$AssertEquals(..Call("DATABASE", "ocuprobe1917a", .tRow), "200 ", "the read answers in another case")
    Do $$$AssertEquals($Select($IsObject($Get(tRow)): tRow.Name _ "|" _ tRow.Class _ "|" _ tRow.Namespace, 1: ""), "OcuProbe1917A|ISC.DM.OcuProbe1917A|USER", "with the stored name, its class and the namespace")
    Do $$$AssertEquals(..Call("DROP", "OCUPROBE1917A"), "200 ", "the drop answers in another case")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "OcuProbe1917A"), "the database is gone")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "ClassExists", ..#NAMESPACE, "ISC.DM.OcuProbe1917A"), "and its class")
    Do $$$AssertTrue(($Get(tGlobal) '= "") && '$ClassMethod(..#PROBE, "HasData", ..#NAMESPACE, tGlobal), "and its data global '" _ $Get(tGlobal) _ "' holds nothing")
}

/// <p>A create of a name the namespace holds in another case is 409
/// <code>DOCDB.NAME.TAKEN</code>, and of a class that exists 409 <code>DOCDB.CLASS.TAKEN</code>; neither
/// creates anything. A create of a free name answers 201 with its row.</p>
Method TestATakenNameOrClassIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableService", .tPrior), "the service is enabled")
    Do $$$AssertEquals(..Call("CREATE", "OcuProbe1917A", .tRow), "201 ", "a free name is created")
    Do $$$AssertEquals($Select($IsObject($Get(tRow)): tRow.Class _ "|" _ tRow.DocumentType _ "|" _ tRow.Resource, 1: ""), "ISC.DM.OcuProbe1917A||", "with no document type and no resource")
    Do $$$AssertEquals(..Call("CREATE", "ocuprobe1917a"), "409 " _ ##class(OcuPilot.Api.DocDbError).#NAMETAKEN, "a case variant is a taken name")
    Do $$$AssertEquals(..Call("CREATE", "ISC.DM.OcuProbe1917A"), "409 " _ ##class(OcuPilot.Api.DocDbError).#CLASSTAKEN, "the class's own name is a taken class")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "ISC.DM.OcuProbe1917A"), "neither created a database")
}

/// <p>A name whose package the namespace keeps in another database is 422
/// <code>DOCDB.NAME.MAPPED</code> on a create and on a read, and an invalid name 422
/// <code>DOCDB.NAME.INVALID</code>; both are refused before the service check, so with the service
/// disabled they cost no audit row, and nothing is created.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.DocDbPort.Invoke</method> skip
/// <method>OcuPilot.Port.DocDbPort.NameProblem</method> -- the invalid names reach the service check and
/// this goes red.</p>
Method TestAMappedOrInvalidNameIsRefusedBeforeTheService()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreService", 0), "the service is disabled")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "DeniedCount", .tBefore), "the access-denied rows are counted")
    Do $$$AssertEquals(..Call("CREATE", "Ens.OcuProbe1917"), "422 " _ ##class(OcuPilot.Api.DocDbError).#NAMEMAPPED, "a mapped package is refused on a create")
    Do $$$AssertEquals(..Call("DATABASE", "Ens.OcuProbe1917"), "422 " _ ##class(OcuPilot.Api.DocDbError).#NAMEMAPPED, "and on a read")
    For tName = "OcuProbe1917_a", "1OcuProbe1917", "OcuProbe1917.", "%OcuProbe1917", "OcuProbe1917" _ $Translate($Justify("", 202), " ", "b") {
        Do $$$AssertEquals(..Call("CREATE", tName), "422 " _ ##class(OcuPilot.Api.DocDbError).#NAMEINVALID, "'" _ $Extract(tName, 1, 30) _ "' (" _ $Length(tName) _ ") is refused")
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "DeniedCount", .tAfter), "the rows are counted again")
    Do $$$AssertEquals(tAfter - tBefore, 0, "no refusal reached the vendor's service check")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableService", .tPrior), "the service is enabled")
    Do $$$AssertEquals(..Call("CREATE", "Ens.OcuProbe1917"), "422 " _ ##class(OcuPilot.Api.DocDbError).#NAMEMAPPED, "a mapped package is refused with the service enabled")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "Exists", ..#NAMESPACE, "Ens.OcuProbe1917") && '$ClassMethod(..#PROBE, "ClassExists", ..#NAMESPACE, "Ens.OcuProbe1917"), "and nothing is created in ENSLIB")
}

/// <p>A drop or a read of a database the namespace does not hold is 404 <code>PORT.NOTFOUND</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.DocDbPort.Drop</method> answer 200 when the vendor
/// answers 0 -- this goes red.</p>
Method TestAnAbsentDatabaseIsNotFound()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableService", .tPrior), "the service is enabled")
    Do $$$AssertEquals(..Call("DROP", "OcuProbe1917Gone"), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "a drop of an absent database")
    Do $$$AssertEquals(..Call("DATABASE", "OcuProbe1917Gone"), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "and a read of one")
}

/// <p>AD-2: a read that finds no database logs nothing, because every agent create's fresh read finds
/// none; a drop that finds none is logged once, as a write's 404 is.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.DocDbPort.Database</method> log its absent answer --
/// the read leg goes red.</p>
Method TestAnAbsentReadIsUnloggedAndAnAbsentDropLogged()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableService", .tPrior), "the service is enabled")
    Set tNotFound = ##class(OcuPilot.Api.Error).#PORTNOTFOUND
    Kill ^||OcuPilotDocDbLog
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("name") = "OcuProbe1917Gone"
    Set tSC = ##class(OcuPilot.Test.DocDbLogSeam).Invoke("Databases", "DATABASE", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "") _ " " _ +$Get(^||OcuPilotDocDbLog), "404 " _ tNotFound _ " 0", "a read of an absent database is not found and logs nothing")
    Set tSC = ##class(OcuPilot.Test.DocDbLogSeam).Invoke("Databases", "DROP", .tQuery, "", .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "") _ " " _ +$Get(^||OcuPilotDocDbLog) _ " " _ $Get(^||OcuPilotDocDbLog(1)), "404 " _ tNotFound _ " 1 " _ tNotFound, "a drop of one is not found and logged once")
    Kill ^||OcuPilotDocDbLog
}

/// <p>The probe rows of <var>pRows</var>, sorted by name, as
/// <code>Name/Class/DocumentType/Resource</code> joined by <code>;</code>.</p>
ClassMethod Probes(pRows) As %String
{
    If '$IsObject(pRows) Quit "no rows"
    Kill tSorted
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || ($ZConvert(tRow.Name, "U") '[ "OCUPROBE1917") Continue
        Set tSorted(" " _ tRow.Name) = tRow.Name _ "/" _ tRow.Class _ "/" _ tRow.DocumentType _ "/" _ tRow.Resource
    }
    Set tText = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey), 1, tValue)
        If tKey = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ";") _ tValue
    }
    Quit tText
}

}
