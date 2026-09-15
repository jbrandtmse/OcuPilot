/// <p>The corpus <method>OcuPilot.Port.AdminPort.QueryPairsProblem</method> runs (DW-305, DW-274).
/// Each case is a whole <parameter>OcuPilot.Port.AdminPort.QUERYPAIRS</parameter> string and the
/// exact sentence the rule returns for it, or <code>null</code> for a declaration it admits.</p>
/// <p><b>One engine, unlike the descriptor corpora.</b> The backing-query pair table is read by the
/// port alone: it never crosses the mirror, so there is no <file>ui/tools/screen-mirror.mjs</file>
/// half to keep identical and nothing on the client reads this block. A later story that declares
/// a second endpoint's set adds its cases here.</p>
Class OcuPilot.Test.QueryPairCorpus Extends %RegisteredObject
{

XData Cases
{
{
  "cases": [
    {"name": "the shipped single entry is sound", "declared": "Process/LIST=%Admin_Manage:USE|%DB_IRISSYS:WRITE", "expected": null},
    {"name": "so is an empty table, which is what every endpoint had before DW-274", "declared": "", "expected": null},
    {"name": "and two entries keyed by different request types", "declared": "Process/LIST=%Admin_Manage:USE,Process/GET=%Admin_Manage:USE", "expected": null},
    {"name": "an entry with no '=' names no pair set", "declared": "Process/LIST", "expected": "queryPairs entry 'Process/LIST' declares no '=', so it names no pair set"},
    {"name": "a key with no type is refused", "declared": "Process=%Admin_Manage:USE", "expected": "queryPairs entry 'Process=%Admin_Manage:USE' declares the key 'Process', which is not <endpoint>/<type>"},
    {"name": "and so is a key with no endpoint", "declared": "/LIST=%Admin_Manage:USE", "expected": "queryPairs entry '/LIST=%Admin_Manage:USE' declares the key '/LIST', which is not <endpoint>/<type>"},
    {"name": "an endpoint that is not dotted identifiers cannot resolve a class", "declared": "Process List/LIST=%Admin_Manage:USE", "expected": "queryPairs entry 'Process List/LIST=%Admin_Manage:USE' names the endpoint 'Process List', which is not dotted identifiers"},
    {"name": "a misspelt request type declares nothing, so it is refused by name", "declared": "Process/LST=%Admin_Manage:USE", "expected": "queryPairs entry 'Process/LST=%Admin_Manage:USE' names the unknown request type 'LST'"},
    {"name": "a write type is outside this port's suffixes", "declared": "Process/PUT=%Admin_Manage:USE", "expected": "queryPairs entry 'Process/PUT=%Admin_Manage:USE' names the unknown request type 'PUT'"},
    {"name": "a key declared twice is refused, because QueryPairs reads the last", "declared": "Process/LIST=%Admin_Manage:USE,Process/LIST=%DB_IRISSYS:WRITE", "expected": "queryPairs declares the key 'Process/LIST' twice, and only the last would be read"},
    {"name": "an empty pair set refuses nobody and is refused", "declared": "Process/LIST=", "expected": "queryPairs entry 'Process/LIST=' declares an empty pair set"},
    {"name": "a pair with no colon is inert in HoldsPair, so the grammar names it", "declared": "Process/LIST=%Admin_Manage", "expected": "queryPairs entry 'Process/LIST=%Admin_Manage' declares the pair '%Admin_Manage', which is not resource:permission"},
    {"name": "a pair with no permission is the same fault", "declared": "Process/LIST=%Admin_Manage:", "expected": "queryPairs entry 'Process/LIST=%Admin_Manage:' declares the pair '%Admin_Manage:', which is not resource:permission"},
    {"name": "a pair with no resource is too", "declared": "Process/LIST=:USE", "expected": "queryPairs entry 'Process/LIST=:USE' declares the pair ':USE', which is not resource:permission"},
    {"name": "and a malformed pair after a sound one is still found", "declared": "Process/LIST=%Admin_Manage:USE|%DB_IRISSYS", "expected": "queryPairs entry 'Process/LIST=%Admin_Manage:USE|%DB_IRISSYS' declares the pair '%DB_IRISSYS', which is not resource:permission"},
    {"name": "a trailing separator leaves an empty pair, which is not a pair", "declared": "Process/LIST=%Admin_Manage:USE|", "expected": "queryPairs entry 'Process/LIST=%Admin_Manage:USE|' declares the pair '', which is not resource:permission"}
  ]
}
}

/// <p>The corpus as a <class>%DynamicObject</class>: <code>{cases}</code>.</p>
ClassMethod Corpus(Output pCorpus As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pCorpus = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Cases", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the corpus XData block is missing")
            Quit
        }
        Do tXData.Data.Rewind()
        Set pCorpus = ##class(%DynamicObject).%FromJSON(tXData.Data)
    } Catch ex {
        Set pCorpus = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
