/// <p>The one corpus both engines of the admin-read privilege rule run (DW-264, AD-2, AD-8):
/// <method>OcuPilot.Screen.Registry.ReadProblem</method> in <class>OcuPilot.Test.ReadTool</class> and
/// <code>readProblem</code> in <file>ui/tools/screen-mirror.test.mjs</file>, which reads this block
/// off disk. Each case replaces the sound declaration's <code>privileges</code> with its own, and
/// names the exact sentence both engines return, or <code>null</code> for a shape neither refuses.
/// A case may also replace the whole <code>read</code> with <code>null</code>, which is how the
/// rule's scope -- admin reads only -- is exercised, and may replace <code>read.source.port</code>
/// and set <code>read.source.rowGet</code>, which is how the port vocabulary and the mgmnt source's
/// refused detail call are. A later story that changes the rule adds its cases here.</p>
Class OcuPilot.Test.AdminPairCorpus Extends %RegisteredObject
{

XData Cases
{
{
  "declaration": {
    "route": "security/pair-corpus", "area": "security", "labelKey": "sslListLabel", "sideBarPosition": 1,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
    "entityType": "ssl-configuration", "secondaryEntityTypes": [],
    "scope": "instance", "parentScope": "", "id": {"kind": "single", "parts": []},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Name", "Description", "Enabled", "Type"], "secretFields": []},
    "emptyStateKey": "sslListEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "admin", "endpoint": "Security.SSLConfig", "type": "LIST"},
      "fields": ["Name", "Description", "Enabled", "Type"],
      "filter": ["Name", "Description", "Type"],
      "sort": {"fields": ["Name", "Description", "Type"], "default": "Name", "direction": "asc"},
      "paging": "cap"
    },
    "table": {
      "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}, {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "toolIdentifier": "security.paircorpus"
  },
  "cases": [
    {"name": "both pairs are the sound shape", "readless": false, "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": null},
    {"name": "the system read alone is sound, since this rule names only that pair", "readless": false, "privileges": [{"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": null},
    {"name": "the pair declared after another is found", "readless": false, "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": null},
    {"name": "the administrative resource alone is refused", "readless": false, "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}], "expected": "read.source.port 'admin' requires the declared privileges to include %DB_IRISSYS:READ, because the port runs every endpoint in %SYS (AD-2, AD-8)"},
    {"name": "an empty privilege set is refused", "readless": false, "privileges": [], "expected": "read.source.port 'admin' requires the declared privileges to include %DB_IRISSYS:READ, because the port runs every endpoint in %SYS (AD-2, AD-8)"},
    {"name": "the right resource with the wrong permission is refused", "readless": false, "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "WRITE"}], "expected": "read.source.port 'admin' requires the declared privileges to include %DB_IRISSYS:READ, because the port runs every endpoint in %SYS (AD-2, AD-8)"},
    {"name": "another database's read is not this one's", "readless": false, "privileges": [{"resource": "%DB_IRISSECURITY", "permission": "READ"}], "expected": "read.source.port 'admin' requires the declared privileges to include %DB_IRISSYS:READ, because the port runs every endpoint in %SYS (AD-2, AD-8)"},
    {"name": "a declaration with no read is outside the rule", "readless": true, "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}], "expected": null},
    {"name": "and so is a read-less declaration with no privileges at all", "readless": true, "privileges": [], "expected": null},
    {"name": "a mgmnt read carrying both pairs is sound", "readless": false, "port": "mgmnt", "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": null},
    {"name": "the system-read rule names admin reads alone, so a mgmnt read is outside it", "readless": false, "port": "mgmnt", "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}], "expected": null},
    {"name": "a mgmnt read declares no per-row detail call", "readless": false, "port": "mgmnt", "rowGet": {"key": "Name", "param": "name", "fields": ["Description"], "derived": []}, "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": "read.source.rowGet is declared on a mgmnt source, which reads whole rows from the management API and has no per-row detail call (AD-36)"},
    {"name": "and the same detail call on an admin read is sound", "readless": false, "rowGet": {"key": "Name", "param": "name", "fields": ["Description"], "derived": []}, "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": null},
    {"name": "a port outside the three sources is refused", "readless": false, "port": "monitor", "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": "read.source.port 'monitor' is not one of 'admin', 'state' or 'mgmnt', the three sources a declared read names (AD-36)"}
  ]
}
}

/// <p>The corpus as a <class>%DynamicObject</class>: <code>{declaration, cases}</code>.</p>
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

/// <p>The corpus declaration with <var>pCase</var>'s <code>privileges</code> in place, its
/// <code>read.source.port</code> and <code>read.source.rowGet</code> when the case names them, and
/// its <code>read</code> and <code>table</code> set to <code>null</code> when the case is
/// <code>readless</code>, as a new object.</p>
ClassMethod DeclarationFor(pCorpus As %DynamicObject, pCase As %DynamicObject) As %DynamicObject
{
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(pCorpus.declaration.%ToJSON())
    Do tDeclaration.%Set("privileges", ##class(%DynamicAbstractObject).%FromJSON(pCase.privileges.%ToJSON()))
    If pCase.%GetTypeOf("port") = "string" Do tDeclaration.read.source.%Set("port", pCase.port)
    If pCase.%GetTypeOf("rowGet") = "object" Do tDeclaration.read.source.%Set("rowGet", ##class(%DynamicAbstractObject).%FromJSON(pCase.rowGet.%ToJSON()))
    If ''pCase.readless {
        Do tDeclaration.%Set("read", "", "null")
        Do tDeclaration.%Set("table", "", "null")
    }
    Quit tDeclaration
}

}
