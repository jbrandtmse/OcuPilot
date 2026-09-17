/// <p>System usage (Story 6.9): the declaration against the read and area grammar; the I/O matrix
/// over the wire as <code>_SYSTEM</code> -- a live read, two reads five seconds apart, and a bare
/// type issued against a different endpoint; a two-part fixture pinning the exact-<code>Total</code>
/// row rule and the whole-read-fails-on-any-part-fault rule (AD-36); and the integration AC, the
/// read tool answering the same row the route does.</p>
/// <p>Needs the API application installed in <code>HSCUSTOM</code>. Issues reads only.</p>
Class OcuPilot.Test.SystemUsage Extends %UnitTest.TestCase
{

/// <p>The descriptor under test.</p>
Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.SystemUsage";

/// <p>The tool identifier the screen read and the derived read tool share.</p>
Parameter TOOL = "osmgmt.systemusage";

/// <p>The four <code>Dashboard.SystemUsage.*</code> status fields, whose value is one of the three
/// words the dashboard answers.</p>
Parameter STATUSFIELDS = "Dashboard.SystemUsage.DatabaseSpace,Dashboard.SystemUsage.JournalSpace,Dashboard.SystemUsage.LockTable,Dashboard.SystemUsage.WriteDaemon";

/// <p>The three words a status field may carry.</p>
Parameter STATUSWORDS = "Normal,Warning,Troubled";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.PortFixture).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Quit $$$OK
}

/// <p>Request <var>pTool</var>'s read at <var>pMaxRows</var>, as <code>_SYSTEM</code>.
/// <var>pAnswer</var> is the parsed body, or <code>""</code> when it does not parse, which is a
/// failed assertion on its own.</p>
Method Read(pTool As %String, pMaxRows As %Integer, Output pStatus As %Integer, Output pAnswer As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ pTool _ "/read?maxRows=" _ pMaxRows, "_SYSTEM", "SYS", .pStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) Quit tSC
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    } Catch {
        Set pAnswer = ""
    }
    Do $$$AssertTrue($IsObject(pAnswer), pTool _ ": the body parses as JSON")
    Quit tSC
}

/// <p><var>pKeys</var> of <var>pObject</var>, in order, comma-separated.</p>
ClassMethod KeysOf(pObject As %DynamicObject) As %String
{
    Set tKeys = ""
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Quit tKeys
}

/// <p>The declaration passes the read grammar; its route and tool identifier resolve to it; it is
/// the OS management area's third entry, on no entity type, at instance scope, with no id, no
/// parent and no criterion, refreshing at the AD-43 roster; it declares eighteen fields and no
/// primary or row action; and the OS management area covers its two-pair set.</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from the descriptor -&gt;
/// <method>OcuPilot.Screen.Registry.ReadProblem</method> refuses it and this goes red naming the
/// missing pair.</p>
Method TestTheDeclarationValidatesAndIsDeclaredAsSystemUsage()
{
    Set tClass = ..#DESCRIPTOR
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read and table are the declared grammar")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and it links out to nothing, meters being a none link-out archetype")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("os-management/system-usage"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool(..#TOOL), tClass, "and so does its tool identifier")

    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "os-management", "in the OS management area")
    Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), 3, "the third entry, after Processes and Locks")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "meters", "on the meters archetype")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType"), "", "administering no entity")
    Do $$$AssertEquals($ClassMethod(tClass, "Scope"), "instance", "at instance scope")
    Do $$$AssertEquals($ClassMethod(tClass, "IdKind"), "none", "with no id")
    Do $$$AssertEquals($ClassMethod(tClass, "ParentScope"), "", "and no parent")
    Do $$$AssertEquals($ClassMethod(tClass, "Refreshes"), 1, "and it refreshes")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "RefreshRates")), "5,10,30,60", "at the AD-43 roster")
    Do $$$AssertEquals(tDeclaration.read.fields.%Size(), 18, "eighteen declared fields")
    Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 0, "with no secret field")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")) + ($ClassMethod(tClass, "PrimaryActionId") '= ""), 0, "because it declares no action")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("os-management", $ClassMethod(tClass, "PrivilegePairs")), "", "and the OS management area covers its pair set")
}

/// <p>Matrix "Live" -- <code>_SYSTEM</code> reads 200 with one row: all eighteen fields are
/// non-null scalar keys of at most 1,000 characters, <code>Usage.BlockReads</code> and
/// <code>SharedMemory.SMHAllocated</code> are JSON numbers, and the four status fields are one of
/// Normal, Warning or Troubled.</p>
Method TestALiveSystemUsageReadsOverTheWire()
{
    Set tSC = ..Read(..#TOOL, 5, .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.rows.%Size(), 1, "exactly one row")
    If tAnswer.rows.%Size() '= 1 Quit
    Set tRow = tAnswer.rows.%Get(0)

    Set tFieldIterator = $ClassMethod(..#DESCRIPTOR, "Read").fields.%GetIterator()
    While tFieldIterator.%GetNext(.tIndex, .tField) {
        Set tType = tRow.%GetTypeOf(tField)
        Do $$$AssertTrue((tType '= "unassigned") && (tType '= "null") && (tType '= "object") && (tType '= "array"), "declared field '" _ tField _ "' is a non-null scalar, not " _ tType)
        If tType = "string" Do $$$AssertTrue($Length(tRow.%Get(tField)) <= 1000, tField _ " is at most 1,000 characters")
    }
    Do $$$AssertEquals(tRow.%GetTypeOf("Usage.BlockReads"), "number", "Usage.BlockReads is a JSON number")
    Do $$$AssertEquals(tRow.%GetTypeOf("SharedMemory.SMHAllocated"), "number", "and so is SharedMemory.SMHAllocated")

    Set tWords = $ListFromString(..#STATUSWORDS)
    Set tFields = $ListFromString(..#STATUSFIELDS)
    For tI = 1:1:$ListLength(tFields) {
        Set tField = $List(tFields, tI)
        Do $$$AssertTrue($ListFind(tWords, tRow.%Get(tField)) > 0, tField _ " is one of " _ ..#STATUSWORDS _ ", not '" _ tRow.%Get(tField) _ "'")
    }
}

/// <p>Matrix "Tick" -- two reads five seconds apart: <code>Usage.AllGlobalReferences</code> does not
/// decrease. A real wall-clock wait: the vendor counter is monotonic for the life of the
/// instance and this is what proves it, not an assumption about it.</p>
Method TestTwoReadsFiveSecondsApartAreNonDecreasing()
{
    Set tSC = ..Read(..#TOOL, 5, .tStatus, .tFirst)
    Do $$$AssertStatusOK(tSC, "the first request completes")
    Do $$$AssertEquals(tStatus, 200, "the first read answers")
    If (tStatus '= 200) || (tFirst.rows.%Size() '= 1) Quit
    Set tBefore = tFirst.rows.%Get(0).%Get("Usage.AllGlobalReferences")

    Hang 5

    Set tSC = ..Read(..#TOOL, 5, .tStatus2, .tSecond)
    Do $$$AssertStatusOK(tSC, "the second request completes")
    Do $$$AssertEquals(tStatus2, 200, "the second read answers")
    If (tStatus2 '= 200) || (tSecond.rows.%Size() '= 1) Quit
    Set tAfter = tSecond.rows.%Get(0).%Get("Usage.AllGlobalReferences")

    Do $$$AssertTrue(tAfter >= tBefore, "AllGlobalReferences did not decrease: " _ tBefore _ " then " _ tAfter)
}

/// <p>Matrix "Bare type elsewhere" -- <code>AdminPort.Invoke("Process", "SYSTEMUSAGE", ...)</code>
/// is 501 <code>PORT.NOTIMPLEMENTED</code>: <code>OcuPilot.Port.AdminPort</code>'s
/// <code>BARETYPES</code> map is per endpoint, so a bare type it names for <code>Monitor</code>
/// resolves nothing for a different endpoint, which also carries no such
/// <code>TYPESYSTEMUSAGE</code> parameter of its own.</p>
Method TestABareTypeIsNotImplementedOnADifferentEndpoint()
{
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Process", "SYSTEMUSAGE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the call is refused")
    Do $$$AssertEquals(tHttp, 501, "not implemented")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "naming the port's own code")
}

/// <p>The parts merge (AD-36, Story 6.9), over <class>OcuPilot.Test.ReadSource.Parts</class>: an
/// object part (<code>Usage</code>) and an array part (<code>SharedMemory</code>) merge into one
/// row keyed by each part's <code>as</code>, the array part's row being the one whose
/// <code>Description</code> is exactly <code>Total</code> -- a same-named row that is merely a
/// prefix match, or an <code>Available SMT &amp; GST</code> trailer row, is never mistaken for
/// it. A part with no such row, and a part answering any non-2xx status (404 included), each fail
/// the whole read with that fault, never a partial row.</p>
/// <p>Mutation: loosen the <code>Total</code> match in <method>OcuPilot.Screen.Read.TotalRow</method>
/// to a prefix -&gt; the "a Total-prefixed row is not the Total row" case merges the wrong row and
/// goes red.</p>
Method TestTwoPartsMergeAndTheTotalRowAndWholeReadFaultRules()
{
    Set tDescriptor = "OcuPilot.Test.ReadSource.Parts"
    Do ##class(OcuPilot.Test.PortFixture).SetEndpointClass("OcuPilot.Test.ReadSource.Endpoint")

    ; SYSTEMUSAGE (15) answers an object; SYSTEMUSAGESHM (14) answers an array whose exact-Total
    ; row is not first, alongside a look-alike prefixed row and a real vendor trailer row.
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("byType", {"AllGlobalReferences": 42}.%ToJSON(), "15")
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("byType", [{"Description": "Total (old)", "SMHUsed": 999}, {"Description": "Total", "SMHUsed": 7}, {"Description": "Available SMT & GST", "SMHUsed": 0}].%ToJSON(), "14")
    Set tSC = ##class(OcuPilot.Test.Read.ReadFixture).Execute(tDescriptor, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the merged read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.rows.%Size(), 1, "exactly one row")
    If tResult.rows.%Size() '= 1 Quit
    Do $$$AssertEquals(tResult.rows.%Get(0).%Get("Usage.AllGlobalReferences"), 42, "the object part's own field")
    Do $$$AssertEquals(tResult.rows.%Get(0).%Get("SharedMemory.SMHUsed"), 7, "the array part's exact-Total row, not the look-alike prefixed row or the trailer row")

    ; No row is exactly "Total": the whole read fails, even though the object part succeeded.
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("byType", {"AllGlobalReferences": 42}.%ToJSON(), "15")
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("byType", [{"Description": "Total (old)", "SMHUsed": 999}].%ToJSON(), "14")
    Set tSC2 = ##class(OcuPilot.Test.Read.ReadFixture).Execute(tDescriptor, "", .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusNotOK(tSC2, "a part with no exact Total row fails the whole read")
    Do $$$AssertEquals(tHttp2, 500, "as an internal fault")
    Do $$$AssertEquals(tResult2, "", "with no partial row")

    ; The first part (Usage) faults; the second (SharedMemory) is never reached and its own
    ; success does not rescue the read.
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("byTypeFault", "notfound", "15")
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("byType", [{"Description": "Total", "SMHUsed": 7}].%ToJSON(), "14")
    Set tSC3 = ##class(OcuPilot.Test.Read.ReadFixture).Execute(tDescriptor, "", .tResult3, .tHttp3, .tFault3)
    Do $$$AssertStatusNotOK(tSC3, "a 404 on one part fails the whole read -- parts take no 404-as-empty exception")
    Do $$$AssertEquals(tHttp3, 404, "with that part's own status")
    Do $$$AssertEquals(tResult3, "", "and no partial row")

    ; A non-404 part fault fails the same way.
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Clear()
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("byType", {"AllGlobalReferences": 42}.%ToJSON(), "15")
    Do ##class(OcuPilot.Test.ReadSource.Endpoint).Arm("byTypeFault", "errorstatus", "14")
    Set tSC4 = ##class(OcuPilot.Test.Read.ReadFixture).Execute(tDescriptor, "", .tResult4, .tHttp4, .tFault4)
    Do $$$AssertStatusNotOK(tSC4, "an error-status part fault fails the whole read")
    Do $$$AssertEquals(tHttp4, 500, "at 500")
    Do $$$AssertEquals(tResult4, "", "and no partial row")
}

/// <p>The integration AC -- the read tool, called in process, answers the same eighteen field keys
/// and one row the route's own read does, every value scalar and at most 1,000 characters.</p>
Method TestTheReadToolAnswersTheSameRowAsTheRoute()
{
    Set tArgs = {}
    Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#DESCRIPTOR, tArgs, 1000, .tView)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(tSC, "the tool reads")
    If $$$ISERR(tSC) || '$IsObject(tView) Quit
    Do $$$AssertEquals(tView.rows.%Size(), 1, "the tool answers one row")

    Set tRouteSC = ..Read(..#TOOL, 1000, .tStatus, .tRoute)
    Do $$$AssertStatusOK(tRouteSC, "the route request completes")
    Do $$$AssertEquals(tStatus, 200, "the route answers the same read")
    If (tStatus '= 200) || '$IsObject(tRoute) Quit

    Do $$$AssertEquals(tView.fields.%Size(), 18, "the tool's view carries all eighteen declared fields")
    Do $$$AssertEquals(tView.fields.%ToJSON(), tRoute.fields.%ToJSON(), "the same declared fields")
    Do $$$AssertEquals(tRoute.rows.%Size(), 1, "the route answers one row too")
    If (tView.rows.%Size() '= 1) || (tRoute.rows.%Size() '= 1) Quit
    Do $$$AssertEquals(..KeysOf(tView.rows.%Get(0)), ..KeysOf(tRoute.rows.%Get(0)), "the tool's row carries the route row's keys, in order")

    Set tIterator = tView.rows.%Get(0).%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue, .tType) {
        Do $$$AssertTrue((tType '= "object") && (tType '= "array"), tKey _ " is scalar in the tool's view, not " _ tType)
        If tType = "string" Do $$$AssertTrue($Length(tValue) <= 1000, tKey _ " is at most 1,000 characters in the tool's view")
    }
}

}
