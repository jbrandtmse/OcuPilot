/// <p>Pins Story 18.25's reads (B1): the screen's declared read and <code>security.superservers.read</code>
/// answer the same rows from one read, with the system default superserver listed on <code>0.0.0.0</code>;
/// <code>GET /superserver/form</code> answers the system default superserver as the one the web gateway connects
/// through, with <code>Enabled</code> and <code>EnableCSP</code> locked and the published sentence, and a new
/// superserver on the vendor's own create defaults.</p>
/// <p><b>Reads only.</b> It needs a stock instance, whose one superserver is the system default, 1972. Nothing is
/// changed.</p>
Class OcuPilot.Test.SuperserverRead Extends %UnitTest.TestCase
{

Parameter SCREEN = "security.superservers";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.SuperserverList";

/// <p>The fifteen settings and <code>SystemDefault</code> the form's row carries beside the id, sorted.</p>
Parameter ROWKEYS = "BindAddress,Description,EnableCSP,EnableCacheDirect,EnableClients,EnableDataCheck,EnableECP,EnableMirror,EnableNodeJS,EnableSNMP,EnableShadows,EnableSharding,EnableWebLink,Enabled,Port,SSLConfig,SSLSupportLevel,SystemDefault";

/// <p>B1: the screen and the tool answer the same rows, each carrying the four list fields, 1972 among them on
/// <code>0.0.0.0</code> as the system default.</p>
/// <p>Mutation (Rule 19): drop <code>Enabled</code> from the descriptor's read fields -- the key set leg goes
/// red.</p>
Method TestTheScreenAndTheReadToolAnswerTheSameRows()
{
    Kill tCriteria
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 100, .tRead, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the screen's read answers (" _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "") _ ")")
    Set tRows = $Select($IsObject($Get(tRead)): tRead.%Get("rows"), 1: [])
    Do $$$AssertTrue(tRows.%Size() > 0, "it lists the instance's superservers")
    Set tSystem = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tRow), "BindAddress,Enabled,Port,SystemDefault", "row " _ tIndex _ " carries the four list fields and nothing else")
        If tRow.%Get("SystemDefault") Set tSystem = tRow
    }
    Do $$$AssertTrue($IsObject(tSystem), "one row is the system default")
    If $IsObject(tSystem) Do $$$AssertEquals(tSystem.%Get("Port") _ " " _ tSystem.%Get("BindAddress") _ " " _ tSystem.%Get("Enabled"), "1972 0.0.0.0 1", "1972, bound to every interface, enabled")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#SCREEN _ ".read", .tTool)
    Do $$$AssertStatusOK(tSC, "security.superservers.read resolves")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"maxRows": 100}, 100, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and answers")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("rows").%ToJSON(), 1: ""), tRows.%ToJSON(), "the screen's rows")
}

/// <p>B1, B4: over the wire the form read answers 200 as JSON for the system default superserver: its fifteen
/// settings, <code>SystemDefault</code>, <code>Port</code> and <code>BindAddress</code>; <code>serving</code>
/// true; <code>Enabled</code> and <code>EnableCSP</code> locked, each with the serving refusal's code and
/// sentence; and <code>windows</code> false on this build. An id the instance does not hold is 404.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.SuperserverLocks</method> answer no
/// field -- the locked leg goes red.</p>
Method TestTheFormReadsTheSystemDefaultAsServing()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("1972", "0.0.0.0"))
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/superserver/form?id=" _ ##class(OcuPilot.Test.SuperserverProbe).QueryId(tId), tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "GET /superserver/form answers: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tForm = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tForm), "locked,row,serving,windows", "the form answers four members")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tForm.%Get("row")), ..#ROWKEYS, "the row carries the settings and the id")
    Do $$$AssertEquals(tForm.%Get("row").%Get("Port") _ " " _ tForm.%Get("row").%Get("BindAddress") _ " " _ tForm.%Get("row").%Get("SystemDefault"), "1972 0.0.0.0 1", "the row is 1972 on every interface, the system default")
    Do $$$AssertEquals(tForm.%Get("serving") _ " " _ tForm.%Get("windows"), "1 0", "serving, and not Windows")
    Set tFields = ""
    Set tIterator = tForm.%Get("locked").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLock) {
        Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ tLock.%Get("field")
        Do $$$AssertEquals(tLock.%Get("code") _ "|" _ tLock.%Get("reason"), "PROHIBITED.SERVINGSUPERSERVER|" _ $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGSUPERSERVERREASON"), tLock.%Get("field") _ " carries the serving refusal and its sentence")
    }
    Do $$$AssertEquals(tFields, "Enabled,EnableCSP", "Enabled and the web connections are locked")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/superserver/form?id=" _ ##class(OcuPilot.Test.SuperserverProbe).QueryId(##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("21829", "0.0.0.0"))), tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 404, "a superserver the instance does not hold is 404: " _ $Extract(tRaw, 1, 200))
}

/// <p>B1: a new superserver's form read is the vendor's own create defaults -- Enabled and Clients on, every
/// other flag off, level 0 -- with no port, no lock and not serving.</p>
/// <p>Mutation (Rule 19): drop <code>EnableClients</code> from
/// <parameter>OcuPilot.Area.Security.SuperserverRules.DEFAULTFLAGSON</parameter> -- the flags leg goes red.</p>
Method TestANewSuperserverStartsFromTheVendorDefaults()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/superserver/form", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the new form answers: " _ $Extract(tRaw, 1, 300))
    Set tForm = ##class(%DynamicObject).%FromJSON(tRaw)
    Set tRow = tForm.%Get("row")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tRow), ..#ROWKEYS, "the row carries the same members")
    Set tOn = ""
    Set tIterator = tRow.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If (tRow.%GetTypeOf(tKey) = "boolean") && tValue Set tOn = tOn _ $Select(tOn = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tOn, "Enabled,EnableClients", "only Enabled and the client connections are on")
    Do $$$AssertEquals(tRow.%Get("Port") _ "|" _ tRow.%Get("SSLSupportLevel") _ "|" _ tRow.%Get("SSLConfig"), "|0|", "no port, level 0, no configuration")
    Do $$$AssertEquals(tForm.%Get("serving") _ " " _ tForm.%Get("locked").%Size(), "0 0", "not serving, nothing locked")
}

/// <p>AD-13, AD-52: the port splits a composite id into the vendor's two query parameters, a bare port is read
/// as every interface, and an id that names no superserver -- a port that is no whole number, a third part --
/// is 404 <code>PORT.NOTFOUND</code> with no vendor call. A call that already carries <code>bindAddress</code>
/// and a <code>LIST</code> pass through unchanged. The seam is read-only here: only reads are sent.</p>
/// <p>Mutation (Rule 19): send the composite id whole in <method>OcuPilot.Port.SuperserverPort.Invoke</method>
/// -- the split legs go red.</p>
Method TestThePortSplitsTheCompositeIdAndRefusesAMalformedOne()
{
    Set tSeam = "OcuPilot.Test.SuperserverSeamPort"
    Set tSep = $Char(1)
    Do $ClassMethod(tSeam, "Clear")
    For tCase = $ListBuild("1972" _ tSep _ "0.0.0.0", "1972|0.0.0.0"), $ListBuild("1972", "1972|"), $ListBuild("01972" _ tSep _ "127.0.0.1", "1972|127.0.0.1") {
        Do $ClassMethod(tSeam, "ClearCalls")
        Kill tQuery
        Set tQuery("port") = $List(tCase, 1)
        Set tSC = $ClassMethod(tSeam, "Invoke", "Security.Superserver", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
        Do $$$AssertEquals($ClassMethod(tSeam, "Calls") _ " " _ $ClassMethod(tSeam, "QueryOf", 1), "Security.Superserver/GET " _ $List(tCase, 2), "'" _ $List(tCase, 1) _ "' is split into the vendor's two parameters")
    }
    For tMalformed = "abc", "", "1972" _ tSep _ "0.0.0.0" _ tSep _ "extra", "123456" _ tSep _ "0.0.0.0", "-1" {
        Do $ClassMethod(tSeam, "ClearCalls")
        Kill tQuery
        Set tQuery("port") = tMalformed
        Set tSC = $ClassMethod(tSeam, "Invoke", "Security.Superserver", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $ClassMethod(tSeam, "Calls"), "404 ", "'" _ $TRANSLATE(tMalformed, tSep, "|") _ "' names no superserver and no vendor call is made")
    }
    Do $ClassMethod(tSeam, "ClearCalls")
    Kill tQuery
    Set tSC = $ClassMethod(tSeam, "Invoke", "Security.Superserver", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals($ClassMethod(tSeam, "Calls") _ " " _ tHttp, "Security.Superserver/LIST 200", "a list passes through with no id")
    Do $ClassMethod(tSeam, "Clear")
}

/// <p>AD-59: the copy-out script of a write is the vendor call with the split query, a bare port reading as
/// every interface, and an id that cannot be split renders no step.</p>
/// <p>Mutation (Rule 19): drop the split from <method>OcuPilot.Port.SuperserverPort.Snippet</method> -- the
/// script names no port and this goes red.</p>
Method TestTheScriptRendersTheSplitQuery()
{
    Set tPort = "OcuPilot.Port.SuperserverPort"
    Kill tQuery
    Set tQuery("port") = "21825" _ $Char(1) _ "0.0.0.0"
    Set tSteps = $ClassMethod(tPort, "Snippet", "Security.Superserver", "PUT", .tQuery, {"Description": "x"}, "")
    Do $$$AssertEquals(tSteps.%Size(), 1, "one step")
    Set tText = tSteps.%Get(0).%Get("text")
    Do $$$AssertTrue((tText [ "-X PUT") && (tText [ "/security/superserver?bindAddress=0.0.0.0&port=21825") && (tText [ """Description"":""x"""), "a PUT with the split query and the body: " _ tText)
    Kill tQuery
    Set tQuery("port") = "21825"
    Set tSteps = $ClassMethod(tPort, "Snippet", "Security.Superserver", "DELETE", .tQuery, "", "")
    Do $$$AssertTrue(tSteps.%Get(0).%Get("text") [ "-X DELETE '/api/admin/v2/security/superserver?port=21825'", "a bare port is sent with no bind address: " _ tSteps.%Get(0).%Get("text"))
    Kill tQuery
    Set tQuery("port") = "abc"
    Do $$$AssertEquals($ClassMethod(tPort, "Snippet", "Security.Superserver", "PUT", .tQuery, {}, "").%Size(), 0, "an id that cannot be split renders no step")
}

}
