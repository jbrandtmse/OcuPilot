/// <p>The one corpus both engines of the admin-read privilege rule run (DW-264, AD-2, AD-8):
/// <method>OcuPilot.Screen.Registry.ReadProblem</method> in <class>OcuPilot.Test.ReadTool</class> and
/// <code>readProblem</code> in <file>ui/tools/screen-mirror.test.mjs</file>, which reads this block
/// off disk. Each case replaces the sound declaration's <code>privileges</code> with its own, and
/// names the exact sentence both engines return, or <code>null</code> for a shape neither refuses.
/// A case may also replace the whole <code>read</code> with <code>null</code>, which is how the
/// rule's scope -- admin and path reads only -- is exercised, and may replace <code>read.source.port</code>
/// and set <code>read.source.rowGet</code>, which is how the port vocabulary and the mgmnt and
/// atelier sources' refused detail call are; a <code>path</code> or <code>background</code> case also sets the source's
/// <code>endpoint</code>, <code>type</code>, <code>forEach</code>, <code>query</code> or <code>parts</code>. A later story
/// that changes the rule adds its cases here.</p>
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
    {"name": "the system-read rule names admin and path reads alone, so a mgmnt read is outside it", "readless": false, "port": "mgmnt", "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}], "expected": null},
    {"name": "a mgmnt read declares no per-row detail call", "readless": false, "port": "mgmnt", "rowGet": {"key": "Name", "param": "name", "fields": ["Description"], "derived": []}, "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": "read.source.rowGet is declared on a mgmnt source, which reads whole rows from the management API and has no per-row detail call (AD-36)"},
    {"name": "and the same detail call on an admin read is sound", "readless": false, "rowGet": {"key": "Name", "param": "name", "fields": ["Description"], "derived": []}, "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": null},
    {"name": "a logsource read carrying one pair is sound", "readless": false, "port": "logsource", "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}], "expected": null},
    {"name": "the system-read rule names admin and path reads alone, so a logsource read with no privileges at all is outside it -- it reads a file off disk and never enters %SYS", "readless": false, "port": "logsource", "privileges": [], "expected": null},
    {"name": "a logsource read declares no per-row detail call", "readless": false, "port": "logsource", "rowGet": {"key": "Name", "param": "name", "fields": ["Description"], "derived": []}, "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}], "expected": "read.source.rowGet is declared on a logsource source, which reads whole rows from a log file's bounded tail and has no per-row detail call (AD-36)"},
    {"name": "a port outside the twelve sources is refused", "readless": false, "port": "metrics", "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": "read.source.port 'metrics' is not one of 'admin', 'state', 'mgmnt', 'logsource', 'path', 'timeline', 'background', 'atelier', 'encryption', 'docdb', 'sqlactivity' or 'interop', the twelve sources a declared read names (AD-36)"},
    {"name": "a path read of the roots carrying both pairs is sound", "readless": false, "port": "path", "endpoint": "roots", "privileges": [{"resource": "%Admin_FileSystemAccess", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": null},
    {"name": "a path read without the system read is refused, because the port reads through the admin API in %SYS", "readless": false, "port": "path", "endpoint": "roots", "privileges": [{"resource": "%Admin_FileSystemAccess", "permission": "USE"}], "expected": "read.source.port 'path' requires the declared privileges to include %DB_IRISSYS:READ, because the port reads the allow-list through the admin API in %SYS (AD-2, AD-8, AD-21)"},
    {"name": "a path read names one of the port's sources", "readless": false, "port": "path", "endpoint": "Security.SSLConfig", "privileges": [{"resource": "%Admin_FileSystemAccess", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": "read.source.endpoint 'Security.SSLConfig' is not one of the path port's sources ('roots') (AD-21)"},
    {"name": "a path read is a LIST", "readless": false, "port": "path", "endpoint": "roots", "type": "GET", "privileges": [{"resource": "%Admin_FileSystemAccess", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": "read.source.type 'GET' is declared on a path source, which lists the allowed directories (AD-36)"},
    {"name": "a path read declares no per-row detail call", "readless": false, "port": "path", "endpoint": "roots", "rowGet": {"key": "Name", "param": "name", "fields": ["Description"], "derived": []}, "privileges": [{"resource": "%Admin_FileSystemAccess", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": "read.source.rowGet is declared on a path source, which answers the allowed directories whole (AD-36)"},
    {"name": "a path read lists no parents", "readless": false, "port": "path", "endpoint": "roots", "forEach": {"endpoint": "Security.SSLConfig", "type": "LIST", "key": "Name", "param": "name", "as": "Parent"}, "privileges": [{"resource": "%Admin_FileSystemAccess", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": "read.source.forEach is declared on a path source, which answers the allowed directories whole (AD-36)"},
    {"name": "a path read fixes no query parameter", "readless": false, "port": "path", "endpoint": "roots", "query": {"purpose": "%GUIFileSelector"}, "privileges": [{"resource": "%Admin_FileSystemAccess", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": "read.source.query is declared on a path source, which answers the allowed directories whole (AD-36)"},
    {"name": "a path read declares no parts", "readless": false, "port": "path", "endpoint": "roots", "parts": [{"type": "GET", "as": "Purpose"}], "privileges": [{"resource": "%Admin_FileSystemAccess", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": "read.source.parts is declared on a path source, which answers the allowed directories whole (AD-36)"},
    {"name": "a background read of the port's list is sound", "readless": false, "port": "background", "endpoint": "BackgroundTask", "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": null},
    {"name": "a background read names the port's one endpoint", "readless": false, "port": "background", "endpoint": "Security.SSLConfig", "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": "read.source.endpoint 'Security.SSLConfig' is not the background port's endpoint ('BackgroundTask') (AD-27)"},
    {"name": "a background read is a LIST", "readless": false, "port": "background", "endpoint": "BackgroundTask", "type": "GET", "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": "read.source.type 'GET' is declared on a background source, which lists the background tasks (AD-36)"},
    {"name": "a background read declares no per-row detail call", "readless": false, "port": "background", "endpoint": "BackgroundTask", "rowGet": {"key": "Id", "param": "id", "fields": ["Details"], "derived": []}, "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "expected": "read.source.rowGet is declared on a background source, which answers the background tasks whole (AD-36)"},
    {"name": "an atelier read carrying its one pair is sound, outside the system-read rule", "readless": false, "port": "atelier", "endpoint": "Classes", "privileges": [{"resource": "%Development", "permission": "USE"}], "expected": null},
    {"name": "an atelier read declares no per-row detail call", "readless": false, "port": "atelier", "endpoint": "Classes", "rowGet": {"key": "Name", "param": "name", "fields": ["Description"], "derived": []}, "privileges": [{"resource": "%Development", "permission": "USE"}], "expected": "read.source.rowGet is declared on an atelier source, which reads whole rows from the source code API and has no per-row detail call (AD-36)"}
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
/// <code>read.source</code> <code>port</code>, <code>endpoint</code>, <code>type</code>,
/// <code>rowGet</code>, <code>forEach</code>, <code>query</code> and <code>parts</code> when the case
/// names them, and
/// its <code>read</code> and <code>table</code> set to <code>null</code> when the case is
/// <code>readless</code>, as a new object.</p>
ClassMethod DeclarationFor(pCorpus As %DynamicObject, pCase As %DynamicObject) As %DynamicObject
{
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(pCorpus.declaration.%ToJSON())
    Do tDeclaration.%Set("privileges", ##class(%DynamicAbstractObject).%FromJSON(pCase.privileges.%ToJSON()))
    If pCase.%GetTypeOf("port") = "string" Do tDeclaration.read.source.%Set("port", pCase.port)
    If pCase.%GetTypeOf("endpoint") = "string" Do tDeclaration.read.source.%Set("endpoint", pCase.endpoint)
    If pCase.%GetTypeOf("type") = "string" Do tDeclaration.read.source.%Set("type", pCase.type)
    For tKey = "rowGet", "forEach", "query", "parts" {
        Set tKeyType = pCase.%GetTypeOf(tKey)
        If (tKeyType = "object") || (tKeyType = "array") Do tDeclaration.read.source.%Set(tKey, ##class(%DynamicAbstractObject).%FromJSON(pCase.%Get(tKey).%ToJSON()))
    }
    If ''pCase.readless {
        Do tDeclaration.%Set("read", "", "null")
        Do tDeclaration.%Set("table", "", "null")
    }
    Quit tDeclaration
}

}
