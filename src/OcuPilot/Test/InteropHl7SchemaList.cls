/// <p>Pins Story 24.18 Batch 1's reads (AD-5, AD-29, AD-36, AD-62): the HL7 schemas list and its one-schema read through the port, the screen's read route and the agent's read tool, which answer
/// the same rows; the list's cap and one over; and a namespace without the HL7 package. The probes are custom schemas in <code>USER</code>, stored with the classic dialog's own sets; the
/// fourteen standard schemas are the instance's and are only read.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropHl7Case</class> needs.</p>
Class OcuPilot.Test.InteropHl7SchemaList Extends OcuPilot.Test.InteropHl7Case
{

/// <p>The screen is declared as the plan places it: the HL7 schemas list in the Interoperability area at side bar 30, keyed by the schema's name, New HL7 schema as its primary action and Export and
/// Delete beside the import's actions, over <code>%Ens_EDISchema:READ</code>, naming the classic HL7 Schema Structures page and declaring no secret.</p>
/// <p>Mutation (Rule 19): change the screen's <code>sideBarPosition</code> to 29 -- this goes red.</p>
Method TestTheDeclarationsRegister()
{
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropHl7SchemaList).DeclarationJson(.tScreen)
    Do $$$AssertStatusOK(tSC, "the screen declares JSON")
    If '$IsObject($Get(tScreen)) Quit
    Do $$$AssertEquals(tScreen.route _ "|" _ tScreen.sideBarPosition _ "|" _ tScreen.archetype _ "|" _ tScreen.area, "interoperability/hl7-schemas|30|list|interoperability", "the route, place, archetype and area")
    Do $$$AssertEquals(tScreen.entityType _ "|" _ tScreen.id.kind _ "|" _ tScreen.scope _ "|" _ tScreen.toolIdentifier, "interop-hl7-schema|single|namespace|interop.hl7schemas", "the entity type, key, scope and tool identifier")
    Do $$$AssertEquals(tScreen.primaryAction.id _ "|" _ tScreen.rowActions.%Get(0).id _ "," _ tScreen.rowActions.%Get(1).id _ "," _ tScreen.rowActions.%Get(2).id, "add|delete,export,export-browser", "the actions")
    Do $$$AssertEquals(tScreen.classicPage _ "|" _ tScreen.context.secretFields.%ToJSON() _ "|" _ tScreen.privileges.%ToJSON(), "EnsPortal.HL7.SchemaMain|[]|[{""resource"":""%Ens_Portal"",""permission"":""USE""},{""resource"":""%Ens_EDISchema"",""permission"":""READ""}]", "the classic page, no secret field and the classic page's pairs")
    Do $$$AssertTrue($ListFind($ClassMethod(..#PORT, "Endpoints"), ..#ENDPOINT) > 0, "the port serves the endpoint")
}

/// <p>AC1: the list holds every standard schema first and exactly the probes after them, each with its base, description, standard mark, time and namespace; the one-schema read answers the same
/// fields, a standard schema reads as standard, and a name that is not held, or is not one this port takes, is 404; the other namespace holds no probe.</p>
/// <p>Mutation (Rule 19): drop the <code>Standard</code> mark from <method>OcuPilot.Port.InteropPort.Hl7SchemaRow</method> -- this goes red.</p>
Method TestTheListHoldsTheStandardSchemasThenEachProbe()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEA, ..#SOURCE, "2.5", "Alpha schema"), "a probe based on 2.5 is stored")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEB), "and one with no base and no description")
    Kill tQuery
    Do $$$AssertEquals(..Verdict("LIST", .tRows, .tFault, .tQuery), "200 ", "the list answers 200")
    Do $$$AssertEquals($Select($IsObject($Get(tRows)): tRows.%Size(), 1: -1), 16, "fourteen standard schemas and two probes")
    If '$IsObject($Get(tRows)) Quit
    Set tStandard = 0
    For tI = 0:1:13 {
        Set tStandard = tStandard + (tRows.%Get(tI).Standard = 1)
    }
    Do $$$AssertEquals(tStandard _ "|" _ tRows.%Get(14).Category _ "|" _ tRows.%Get(15).Category, "14|" _ ..#NAMEA _ "|" _ ..#NAMEB, "the standard schemas come first and the probes after them, by name")
    Set tA = tRows.%Get(14)
    Set tB = tRows.%Get(15)
    Do $$$AssertEquals(tA.Base _ "|" _ tA.Description _ "|" _ tA.Standard _ "|" _ tA.Namespace, "2.5|Alpha schema|0|USER", "a probe reads its base, description, standard mark and namespace")
    Do $$$AssertEquals(tB.Base _ "|" _ tB.Description _ "|" _ tB.Standard, "||0", "one with neither reads empty")
    Do $$$AssertTrue($Match(tA.Modified, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:.]+$") && $Match(tRows.%Get(0).Modified, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:.]+$"), "each row carries the vendor's time: " _ tA.Modified)
    Do $$$AssertEquals(..Read(..#NAMEA, "", .tOne, .tFault), "200 ", "the one-schema read answers 200")
    Do $$$AssertEquals(tOne.Category _ "|" _ tOne.Base _ "|" _ tOne.Description _ "|" _ tOne.Standard _ "|" _ tOne.Modified _ "|" _ tOne.Namespace, tA.Category _ "|" _ tA.Base _ "|" _ tA.Description _ "|" _ tA.Standard _ "|" _ tA.Modified _ "|" _ tA.Namespace, "and the same fields")
    Do $$$AssertEquals(..Read("2.5", "", .tStd, .tFault) _ "|" _ tStd.Standard, "200 |1", "a standard schema reads as standard")
    Do $$$AssertEquals(..Read("OcuProbe2418zz", "", .tNone, .tFault), "404 PORT.NOTFOUND", "a schema the namespace does not hold is 404")
    Do $$$AssertEquals(..Read("a b", "", .tNone, .tFault), "404 PORT.NOTFOUND", "and so is a name this port does not take")
    Do $$$AssertEquals(..Read($ZConvert(..#NAMEA, "U"), "", .tNone, .tFault), "404 PORT.NOTFOUND", "and a name in another letter case")
    Kill tQuery
    Do $$$AssertEquals(..Verdict("LIST", .tOther, .tFault, .tQuery, "", ..#OTHER) _ "|" _ tOther.%Size(), "200 |14", "the other namespace lists its fourteen standard schemas and none of the probes")
    Kill tQuery
    Set tQuery("maxRows") = "0"
    Do $$$AssertEquals(..Verdict("LIST", .tBad, .tFault, .tQuery), "400 PORT.VALIDATION", "a cap that is not a whole number above zero is refused by name")
}

/// <p>AC1: the list is cut at a named limit when the caller names no cap, and truncation is the caller's to read from the row it asks for beyond its own cap: with the seam's limit of fifteen, one
/// probe makes fifteen rows, all listed, and a second one over is cut; a caller that asks for one row beyond a cap is answered it, and one that asks for fewer gets fewer. The shipped limit is
/// 2,000, measured at 2,019 schemas in 1.3 seconds.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListHl7Schemas</method> ignore its cap -- the over leg goes red.</p>
Method TestTheListStopsAtItsNamedLimit()
{
    Set tCap = ..#CAPSEAM
    Do $$$AssertEquals($Parameter(..#PORT, "HL7SCHEMASMAX") _ "|" _ $Parameter(tCap, "HL7SCHEMASMAX"), "2000|15", "the shipped limit is 2,000 and the seam lowers it to fifteen")
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEA), "one probe is stored")
    Kill tQuery
    Do ..Verdict("LIST", .tAt, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tAt)): tAt.%Size() _ "|" _ tAt.%Get(14).Category, 1: ""), "15|" _ ..#NAMEA, "fourteen standard schemas and a probe, at the limit: all fifteen")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeSchema", ..#NAMEB), "a second probe is stored")
    Kill tQuery
    Do ..Verdict("LIST", .tOver, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tOver)): tOver.%Size() _ "|" _ tOver.%Get(14).Category, 1: ""), "15|" _ ..#NAMEA, "one over the limit: the first fifteen, by the vendor's order")
    Kill tQuery
    Set tQuery("maxRows") = 16
    Do ..Verdict("LIST", .tAsked, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tAsked)): tAsked.%Size(), 1: -1), 16, "a caller whose cap is the limit asks for one row more and is answered it, so it reads the truncation")
    Kill tQuery
    Set tQuery("maxRows") = 2
    Do ..Verdict("LIST", .tFewer, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tFewer)): tFewer.%Size(), 1: -1), 2, "one that asks for fewer gets fewer")
}

/// <p>AC1: the screen's read route and the agent's read tool answer the rows the port answers, for the same probes.</p>
/// <p>Mutation (Rule 19): rename the <code>Base</code> field in <class>OcuPilot.Screen.Descriptor.InteropHl7SchemaList</class>'s read -- the route and the tool answer no base and this goes red.</p>
Method TestTheReadRouteAndTheReadToolAnswerTheSameRows()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeSchema", ..#NAMEA, ..#SOURCE, "2.5.1", "Alpha schema"), "a probe is stored")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#SOURCE)
    Kill tQuery
    Do ..Verdict("LIST", .tPort, .tPortFault, .tQuery)
    Set tClass = "OcuPilot.Screen.Descriptor.InteropHl7SchemaList"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(tClass, 1000, .tAnswer, .tHttp, .tFault, .tNone)
    Do $$$AssertEquals(tHttp, 200, "the route answers")
    Set tToolHttp = 0
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($ClassMethod(tClass, "ToolIdentifier") _ ".read", .tTool)
    Do $$$AssertTrue($IsObject($Get(tTool)), "interop.hl7schemas.read is a registered read tool")
    If $IsObject($Get(tTool)) Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 1000, .tResult, .tToolHttp, .tToolFault)
    Do $$$AssertEquals(tToolHttp, 200, "and so does the tool")
    If '$IsObject($Get(tAnswer)) || '$IsObject($Get(tResult)) Quit
    Set tFields = "Category,Base,Description,Standard,Modified"
    Do $$$AssertEquals(tPort.%Size() _ "|" _ tAnswer.rows.%Size() _ "|" _ tResult.rows.%Size(), "15|15|15", "each answers the fourteen standard schemas and the probe")
    Set tPortA = ..RowOf(tPort, ..#NAMEA)
    Set tRouteA = ..RowOf(tAnswer.rows, ..#NAMEA)
    Set tToolA = ..RowOf(tResult.rows, ..#NAMEA)
    For tField = "Base", "Description", "Standard", "Modified" {
        Do $$$AssertEquals(tRouteA.%Get(tField) _ "|" _ tToolA.%Get(tField), tPortA.%Get(tField) _ "|" _ tPortA.%Get(tField), "the route's and the tool's " _ tField _ " is the port's")
    }
}

/// <p>AC1: a namespace that does not carry the HL7 package is answered 501 <code>PORT.NOTIMPLEMENTED</code> for the list and each typed call, before any vendor call.</p>
/// <p>Mutation (Rule 19): drop the <method>OcuPilot.Port.InteropPort.Hl7Installed</method> test from <method>OcuPilot.Port.InteropPort.InvokeHl7Schema</method> -- this goes red.</p>
Method TestANamespaceWithoutTheHl7PackageIsNotImplemented()
{
    Set ^IRIS.Temp.OcuProbe2417wMode = "nohl7"
    Kill tQuery
    Do $$$AssertEquals(..Verdict("LIST", .tRows, .tFault, .tQuery, "", ..#SOURCE, ..#SEAM), "501 PORT.NOTIMPLEMENTED", "the list is not implemented")
    Do $$$AssertEquals(..Put("DELETEHL7SCHEMA", ..#NAMEA, {}, .tResult, .tFault, ..#SOURCE, ..#SEAM), "501 PORT.NOTIMPLEMENTED", "and so is a delete")
    Do $$$AssertEquals($Get(^IRIS.Temp.OcuProbe2417wMode("ran"), 0), 0, "and no vendor call ran")
}

}
