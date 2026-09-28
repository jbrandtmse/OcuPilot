/// <p>Pins Story 18.14's mapping refusals on the screen's and the agent's callers: an edit of a mapping
/// deleted since its read, a key outside the template, the routine type suffix, a global's base
/// mapping deleted while a subscript-level mapping exists, a name the instance refuses, an absent
/// namespace, a collation that is not a whole number, the form read of what is absent,
/// <class>OcuPilot.Port.NamespacePort</class>'s malformed composite id, and a lower-cased namespace
/// part reaching the vendor upper-cased.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the <code>USER</code>
/// and <code>IRISTEMP</code> databases, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because the class creates and deletes namespaces and mappings
/// (<class>OcuPilot.Test.MappingProbe</class>). Every probe namespace is removed by exact name, with
/// its mappings, before all, after each and after all.</p>
Class OcuPilot.Test.MappingRefusals Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG";

Parameter PROBE = "OcuPilot.Test.MappingProbe";

Parameter WRITE = "OcuPilot.Test.MappingWrite";

Parameter RECORD = "OcuPilot.Test.MappingRecordPort";

Parameter NS = "OCUPROBE1814A";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.MappingRefusals creates and deletes namespaces and mappings on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnBeforeOneTest() As %Status
{
    Quit $ClassMethod(..#PROBE, "Add", ..#NS)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotNamespaceWritePort
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe namespace is removed by exact name, with its mappings")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If '$ClassMethod(..#PROBE, "CpfValid", .tNamesProbe) || tNamesProbe Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the configuration file does not validate, or names a probe namespace, after OcuPilot.Test.MappingRefusals"))
    Quit tSC
}

/// <p>Deleted since the read: the screen's edit of a mapping that is gone answers 404
/// <code>MAPPING.NAME.ABSENT</code> and sends no upsert; the agent's edit minted before the delete is
/// refused at its confirm as a target that changed, and nothing is re-created.</p>
Method TestAnEditOfAMappingDeletedSinceItsReadCreatesNothing()
{
    Set tName = "OcuProbe1814GN"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#NS, tName), "a probe mapping is seeded")
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..Tool("Update"), {"Namespace": (..#NS), "Name": (tName), "Database": "IRISTEMP"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's edit is minted while the mapping exists " _ tProblem)
    Do $$$AssertEquals(..Act("delete", tName), "200 ", "the mapping is deleted")
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    Set tSC = $ClassMethod(..#WRITE, "Save", "global", "update", ..#NS, tName, {"Database": "IRISTEMP"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "404 " _ ##class(OcuPilot.Api.Error).#MAPPINGNAMEABSENT, "the screen's edit answers 404 naming the absent mapping")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends no upsert")
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Confirm", tProposal), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the agent's confirm is refused as a target that changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and sends no upsert either")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsMapping", "global", ..#NS, tName), 0, "the mapping stays deleted")
}

/// <p>A key outside the template: the screen's edit carrying one answers 400
/// <code>PORT.FIELD.UNEXPECTED</code> naming it, and the agent's schema refuses it, each before any
/// write.</p>
Method TestAKeyOutsideTheTemplateIsRefused()
{
    Set tName = "OcuProbe1814GK"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "routine", ..#NS, tName), "a probe routine mapping is seeded")
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    Set tSC = $ClassMethod(..#WRITE, "Save", "routine", "update", ..#NS, tName, {"Database": "IRISTEMP", "Collation": 5}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "a routine edit carrying Collation is refused")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "before any write")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(##class(OcuPilot.Screen.Tool.RoutineMappingUpdate).InputSchema(), {"Namespace": (..#NS), "Name": (tName), "Collation": 5}, .tProblem)
    Do $$$AssertTrue($$$ISERR(tSC) && (tProblem [ "Collation"), "the agent's schema refuses it too: " _ tProblem)
}

/// <p>The routine type suffix: the rule refuses a suffix holding a lower-case letter and accepts one
/// in capitals, which the instance then creates.</p>
Method TestARoutineSuffixIsWrittenInCapitals()
{
    For tName = "OcuProbe1814R_mac", "OcuProbe1814R_Mac", "OcuProbe1814R*_int" {
        Kill tViolations
        Do ##class(OcuPilot.Area.OsMgmt.MappingRules).NameViolation("routine", tName, .tViolations)
        Do $$$AssertEquals($Select($Get(tViolations): $List(tViolations(1), 2), 1: ""), ##class(OcuPilot.Api.Error).#MAPPINGNAMESHAPE, tName _ ": refused on Name")
    }
    Kill tViolations
    Do ##class(OcuPilot.Area.OsMgmt.MappingRules).NameViolation("global", "OcuProbe1814R_mac", .tViolations)
    Do $$$AssertEquals(+$Get(tViolations), 0, "a global's name is not a routine's, and the rule leaves it to the instance")
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    Set tSC = $ClassMethod(..#WRITE, "Save", "routine", "create", ..#NS, "OcuProbe1814R_MAC", {"Database": "USER"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "201 ", "a suffix in capitals is created")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "routine", ..#NS), "OcuProbe1814R_MAC", "as sent")
}

/// <p>A global's base mapping deleted while a subscript-level mapping of it exists: the vendor refuses
/// it with nothing changed, and both callers answer 422 <code>MAPPING.VALIDATION</code>, the screen's
/// naming <code>MAPPING.NAME.SUBSCRIPTS</code> on Name; both mappings survive.</p>
/// <p>Mutation (Rule 19): drop the <code>Namespace.GlobalMappings:451</code> entry from
/// <parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter> -> the refusal names no field and
/// answers as an internal error, and this goes red.</p>
Method TestABaseMappingWithSubscriptMappingsIsRefusedOnName()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#NS, "OcuProbe1814S(""a""):(""m"")"), "a subscript-level mapping is seeded, and the instance creates its base")
    Set tBoth = "OcuProbe1814S,OcuProbe1814S(""a""):(""m"")"
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "global", ..#NS), tBoth, "both mappings are present")
    Set tBody = {}
    Do tBody.%Set("action", "delete", "string")
    Do tBody.%Set("id", $ClassMethod(..#PROBE, "Id", ..#NS, "OcuProbe1814S"), "string")
    Set ^||OcuPilotNamespaceWritePort = "OcuPilot.Port.NamespacePort"
    Set tSC = ##class(OcuPilot.Test.MappingActionFixture).Act("osmgmt.globalmappings", tBody, .tAnswer, .tStatus)
    Set tEnvelope = ""
    Try { Set tEnvelope = ##class(%DynamicObject).%FromJSON(tAnswer) } Catch {}
    Do $$$AssertEquals(tStatus _ " " _ ..Named(tEnvelope), "422 MAPPING.VALIDATION Name:MAPPING.NAME.SUBSCRIPTS", "the screen's delete is refused on Name: " _ tAnswer)
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..Tool("Delete"), {"Namespace": (..#NS), "Name": "OcuProbe1814S"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted " _ tProblem)
    If $IsObject(tProposal) {
        Set tSC = ##class(OcuPilot.Test.NamespaceConfirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Get(tCode), "422 MAPPING.VALIDATION", "and the agent's confirm is refused as a validation failure")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "global", ..#NS), tBoth, "both mappings survive")
}

/// <p><class>OcuPilot.Port.NamespacePort</class>'s composite id: an id that is not exactly two
/// non-empty parts answers 404 <code>PORT.NOTFOUND</code> with no vendor call, and a lower-cased
/// namespace part reaches the vendor upper-cased while the name keeps its case.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.NamespacePort.MappingQuery</method> does not split ->
/// every call reaches the vendor without a namespace, and this goes red.</p>
Method TestTheCompositeIdIsSplitAndItsNamespaceUpperCased()
{
    Do $ClassMethod(..#RECORD, "Clear")
    For tId = "OcuProbe1814", $ClassMethod(..#PROBE, "Id", ..#NS, ""), $ClassMethod(..#PROBE, "Id", "", "OcuProbe1814"), ..#NS _ $Char(1) _ "a" _ $Char(1) _ "b" {
        Kill tQuery
        Set tQuery("name") = tId
        Set tSC = ##class(OcuPilot.Port.NamespacePort).Invoke("Namespace.GlobalMappings", "GET", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404 PORT.NOTFOUND", $Translate(tId, $Char(1), "|") _ ": answers 404 naming no mapping")
    }
    Kill tQuery
    Set tQuery("name") = $ClassMethod(..#PROBE, "Id", $ZConvert(..#NS, "L"), "OcuProbe1814Mixed")
    Do $$$AssertTrue(##class(OcuPilot.Port.NamespacePort).MappingQuery(.tQuery, .tSplit), "a two-part id splits")
    Do $$$AssertEquals($Get(tSplit("namespace")) _ "|" _ $Get(tSplit("name")), ..#NS _ "|OcuProbe1814Mixed", "the namespace upper-cased and the name as it is")
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    Set tSC = $ClassMethod(..#WRITE, "Save", "global", "create", $ZConvert(..#NS, "L"), "OcuProbe1814Mixed", {"Database": "USER"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "201 ", "a create in the lower-cased namespace answers 201")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "global", ..#NS), "OcuProbe1814Mixed", "and the instance holds the mapping, its name's case kept, in the namespace")
}

/// <p>A name the instance refuses: for each kind, a name the vendor rejects -- an unclosed subscript
/// for a global, a hyphen for a routine and a package -- answers on Name on both callers, the
/// screen's create Save 422 with <code>MAPPING.NAME.SHAPE</code> on Name and the agent's confirm 422
/// <code>MAPPING.VALIDATION</code>, and nothing is created.</p>
/// <p>Mutation (Rule 19): empty <method>OcuPilot.Area.OsMgmt.MappingSave.PortViolations</method> -> the
/// Save's refusal names no field, and this goes red.</p>
Method TestANameTheInstanceRefusesAnswersOnName()
{
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    For tCase = $ListBuild("global", "OcuProbe1814V(""a"), $ListBuild("routine", "OcuProbe1814-R"), $ListBuild("package", "OcuProbe1814-P") {
        Set tKind = $List(tCase, 1)
        Set tName = $List(tCase, 2)
        Set tSC = $ClassMethod(..#WRITE, "Save", tKind, "create", ..#NS, tName, {"Database": "USER"}, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Name:" _ ##class(OcuPilot.Api.Error).#MAPPINGNAMESHAPE, tKind _ " " _ tName _ ": the screen's Save is refused on Name")
        Set tSC = $ClassMethod(..#WRITE, "Mint", ##class(OcuPilot.Area.OsMgmt.MappingRules).ToolClass(tKind, "Create"), {"Namespace": (..#NS), "Name": (tName), "Database": "USER"}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, tKind _ ": the agent's create is minted " _ tProblem)
        Do $$$AssertEquals($ClassMethod(..#WRITE, "Confirm", tProposal), "422 " _ ##class(OcuPilot.Api.Error).#MAPPINGVALIDATION, tKind _ ": and its confirm is refused as a validation failure")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", tKind, ..#NS), "", tKind _ ": and nothing is created")
    }
}

/// <p>The rules the instance is never asked about: a Save into a namespace the instance does not hold
/// is refused 422 on Namespace, and a collation that is not a whole number 422 on Collation, each
/// with no write reaching the port (<class>OcuPilot.Test.MappingAcceptPort</class>, which sends none);
/// the form's read of an absent namespace answers 404 <code>MAPPING.NAMESPACE.ABSENT</code>, and of a
/// mapping the namespace does not hold 404 <code>MAPPING.NAME.ABSENT</code>.</p>
/// <p>Mutation (Rule 19): drop the namespace arm of
/// <method>OcuPilot.Area.OsMgmt.MappingRules.Validate</method> -> the Save into the absent namespace
/// is accepted, and this goes red.</p>
Method TestAnAbsentNamespaceAndABadCollationAreRefused()
{
    Set tAccept = "OcuPilot.Test.MappingAcceptPort"
    Set ^||OcuPilotNamespaceWritePort = tAccept
    Do $ClassMethod(tAccept, "Clear")
    Set tSC = $ClassMethod(..#WRITE, "Save", "global", "create", "OCUPROBE1814Z", "OcuProbe1814NA", {"Database": "USER"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Namespace:" _ ##class(OcuPilot.Api.Error).#MAPPINGNAMESPACEABSENT, "a Save into a namespace the instance does not hold is refused on Namespace")
    Set tSC = $ClassMethod(..#WRITE, "Save", "global", "create", ..#NS, "OcuProbe1814CV", {"Database": "USER", "Collation": "five"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Collation:" _ ##class(OcuPilot.Api.Error).#MAPPINGCOLLATIONVALUE, "a collation that is not a whole number is refused on Collation")
    Do $$$AssertEquals($ClassMethod(tAccept, "Writes"), "", "and no write reached the port")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/mapping/global/form"
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    For tCase = $ListBuild("?namespace=OCUPROBE1814Z", ##class(OcuPilot.Api.Error).#MAPPINGNAMESPACEABSENT), $ListBuild("?namespace=" _ ..#NS _ "&name=OcuProbe1814Absent", ##class(OcuPilot.Api.Error).#MAPPINGNAMEABSENT) {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ $List(tCase, 1), tUser, tPassword, .tStatus, .tBody, .tHeaders)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody), "404 " _ $List(tCase, 2), "the form read " _ $List(tCase, 1) _ " answers 404 naming what is absent: " _ $Extract(tBody, 1, 200))
    }
}

/// <p><var>pBody</var>'s envelope code, or <code>""</code>.</p>
ClassMethod Code(pBody As %String) As %String
{
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(pBody).%Get("code") } Catch {}
    Quit tCode
}

/// <p>The global mapping row action <var>pAction</var> for mapping <var>pName</var> of the probe
/// namespace, through the shipped port, as <code>http code</code>.</p>
Method Act(pAction As %String, pName As %String) As %String
{
    Set ^||OcuPilotNamespaceWritePort = "OcuPilot.Port.NamespacePort"
    Set tAnswer = $ClassMethod(..#WRITE, "Act", "osmgmt.globalmappings", pAction, $ClassMethod(..#PROBE, "Id", ..#NS, pName))
    Kill ^||OcuPilotNamespaceWritePort
    Quit tAnswer
}

/// <p><var>pEnvelope</var>'s code and first violation as <code>code field:code</code>, or, with
/// <var>pWithCode</var> 0, the violation alone.</p>
ClassMethod Named(pEnvelope As %DynamicObject, pWithCode As %Boolean = 1) As %String
{
    If '$IsObject(pEnvelope) Quit "(no envelope)"
    Set tRow = ""
    Try { Set tRow = pEnvelope.%Get("detail").%Get("violations").%Get(0) } Catch {}
    Set tNamed = $Select($IsObject(tRow): tRow.%Get("field") _ ":" _ tRow.%Get("code"), 1: "(no violation)")
    If 'pWithCode Quit tNamed
    Quit pEnvelope.%Get("code") _ " " _ tNamed
}

/// <p>The global mapping tool for <var>pVerb</var>.</p>
ClassMethod Tool(pVerb As %String) As %String
{
    Quit ##class(OcuPilot.Area.OsMgmt.MappingRules).ToolClass("global", pVerb)
}

}
