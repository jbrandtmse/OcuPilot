/// <p>What Story 24.18 Batch 1's armed HL7 schema suites share: <class>OcuPilot.Test.InteropWorkflowCase</class>'s arming check, HTTP calls, mint and confirm, port calls and own audit rows,
/// aimed at the HL7 schemas screen, its Save route and tools, and the probe schemas <class>OcuPilot.Test.InteropHl7Fixture</class> stores in <code>USER</code> and <code>HSCUSTOM</code> and removes
/// before and after every test. The class refuses to start while either namespace holds a custom schema that is not a probe. The probes live in <code>USER</code>; <code>HSCUSTOM</code> holds the
/// install, so the two namespaces tell a confirm's namespace apart. <b>No production is started.</b></p>
/// <p><b>Not run itself</b>: it declares no test.</p>
Class OcuPilot.Test.InteropHl7Case Extends OcuPilot.Test.InteropWorkflowCase [ Abstract ]
{

Parameter FIXTURE = "OcuPilot.Test.InteropHl7Fixture";

Parameter SEAM = "OcuPilot.Test.InteropHl7Seam";

Parameter CAPSEAM = "OcuPilot.Test.InteropHl7CapSeam";

Parameter SCREEN = "/screens/interop.hl7schemas";

Parameter SAVE = "/interop/hl7-schemas";

Parameter ENDPOINT = "Hl7Schemas";

Parameter TOOLPREFIX = "OcuPilot.Screen.Tool.InteropHl7Schema";

Parameter ENTITY = "interop-hl7-schema";

Parameter READTYPE = "HL7SCHEMA";

/// <p>The probe schemas' names.</p>
Parameter NAMEA = "OcuProbe2418a";

Parameter NAMEB = "OcuProbe2418b";

/// <p>The governance policy found before a test, put back after it.</p>
Property StoredPolicy [ MultiDimensional ];

/// <p>Keep the stored governance policy and clear it, so every key reads its baseline.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = ##super()
    If $$$ISERR(tSC) Quit tSC
    Kill ..StoredPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..StoredPolicy = tRows
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Kill tRows
    Merge tRows = ..StoredPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the policy found before the test is put back")
    Quit ##super()
}

/// <p>Turn on the baseline-off keys <var>pKeys</var> (comma-separated).</p>
ClassMethod EnableKeys(pKeys As %String) As %Status
{
    Kill tSettings
    For tI = 1:1:$Length(pKeys, ",") {
        Set tSettings($Piece(pKeys, ",", tI)) = "enabled"
    }
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>The text of the lines <var>pLines</var> (an array of strings) joined by line feeds, as a browser saves them.</p>
ClassMethod JoinLines(pLines As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject(pLines) Quit tText
    Set tIterator = pLines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tText = tText _ $Select(tIndex = 0: "", 1: $Char(10)) _ tLine
    }
    Quit tText
}

/// <p>The row of <var>pRows</var> whose <code>Category</code> is <var>pName</var>, or <code>""</code>.</p>
ClassMethod RowOf(pRows As %DynamicArray, pName As %String) As %DynamicObject
{
    Set tFound = ""
    If '$IsObject(pRows) Quit tFound
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Category") = pName {
            Set tFound = tRow
            Quit
        }
    }
    Quit tFound
}

/// <p>How many of the vendor's own <code>%Ensemble/%Schema/Modify</code> audit rows since <var>pSince</var> name the schema <var>pName</var> (a moment after they are written, so the read is
/// made again for up to five seconds until it finds <var>pExpect</var>).</p>
ClassMethod VendorRows(pSince As %String, pName As %String, pExpect As %Integer = 1) As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tCount = 0
    For tTry = 1:1:20 {
        Set tCount = 0
        Try {
            Set $NAMESPACE = "%SYS"
            Set tRS = ##class(%ResultSet).%New("%SYS.Audit:List")
            Set tSC = tRS.Execute(pSince, "", "%Ensemble", "%Schema", "Modify")
            While $$$ISOK(tSC) && tRS.Next() {
                If tRS.Get("Description") = ("HL7 " _ pName) Set tCount = tCount + 1
            }
            Set $NAMESPACE = tOrigNS
        } Catch {
            Set $NAMESPACE = tOrigNS
        }
        If tCount '< pExpect Quit
        Hang 0.25
    }
    Quit tCount
}

/// <p>The UTC time now as the audit lists take it.</p>
ClassMethod AuditNow() As %String
{
    Quit $ZDateTime($ZTimeStamp, 3, 1)
}

}
