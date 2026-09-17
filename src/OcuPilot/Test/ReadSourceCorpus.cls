/// <p>The one corpus both engines of the <code>read.source</code> type and <code>forEach</code> grammar
/// run (AD-36): <method>OcuPilot.Screen.Registry.ReadProblem</method> in
/// <class>OcuPilot.Test.ReadTool</class> and <code>readProblem</code> in
/// <file>ui/tools/screen-mirror.test.mjs</file>, which reads this block off disk. Each case replaces
/// <code>declaration.read.source</code> with its own <code>source</code>, sets
/// <code>declaration.read.criteria</code> when it carries one, and names the exact sentence both
/// engines return, or <code>null</code> for a sound shape.</p>
Class OcuPilot.Test.ReadSourceCorpus Extends %RegisteredObject
{

XData Cases
{
{
  "declaration": {
    "route": "security/source-corpus", "area": "security", "labelKey": "oauthTabClients", "sideBarPosition": 0,
    "archetype": "detail", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%Admin_OAuth2_Client", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}], "entityType": "oauth2-client-configuration", "secondaryEntityTypes": [],
    "scope": "instance", "parentScope": "", "id": {"kind": "single", "parts": []},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Name", "ServerDefinitionID", "IssuerEndpoint", "Metadata.scopes_supported"], "secretFields": []},
    "emptyStateKey": "oauthClientsEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST"},
      "fields": ["Name", "ServerDefinitionID", "IssuerEndpoint", "Metadata.scopes_supported"],
      "filter": ["Name"],
      "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
      "paging": "cap"
    },
    "table": {
      "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}, {"field": "Metadata.scopes_supported", "labelKey": "oauthColumnScopes", "kind": "text"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "toolIdentifier": "security.sourcecorpus"
  },
  "cases": [
    {"name": "a LIST source is sound", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST"}, "expected": null},
    {"name": "a GET source reading a member field is sound", "source": {"port": "admin", "endpoint": "Security.OAuth2.Server", "type": "GET"}, "expected": null},
    {"name": "a per-parent LIST source is sound", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": [{"field": "ServerDefinitionID", "from": "ID"}, {"field": "IssuerEndpoint", "from": "IssuerEndpoint"}]}}, "expected": null},
    {"name": "a per-parent source that copies no field is sound", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": []}}, "expected": null},
    {"name": "a null forEach lists no parents", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": null}, "expected": null},
    {"name": "a type outside the two", "source": {"port": "admin", "endpoint": "Security.OAuth2.Server", "type": "POST"}, "expected": "read.source.type 'POST' is not 'LIST' or 'GET'"},
    {"name": "a type is spelled exactly", "source": {"port": "admin", "endpoint": "Security.OAuth2.Server", "type": "get"}, "expected": "read.source.type 'get' is not 'LIST' or 'GET'"},
    {"name": "a detail type is not a source type", "source": {"port": "admin", "endpoint": "Security.X509Credential", "type": "CERTINFO"}, "expected": "read.source.type 'CERTINFO' is not 'LIST' or 'GET'"},
    {"name": "a missing type", "source": {"port": "admin", "endpoint": "Security.OAuth2.Server"}, "expected": "read.source.type '' is not 'LIST' or 'GET'"},
    {"name": "a GET on the management port", "source": {"port": "mgmnt", "endpoint": "Applications", "type": "GET"}, "expected": "read.source.type 'GET' is declared on a 'mgmnt' source, and a single-object read issues an admin endpoint's GET (AD-36)"},
    {"name": "a GET on a state source", "source": {"port": "state", "endpoint": "Agent", "type": "GET"}, "expected": "read.source.type 'GET' is declared on a 'state' source, and a single-object read issues an admin endpoint's GET (AD-36)"},
    {"name": "a GET with a detail call", "source": {"port": "admin", "endpoint": "Security.OAuth2.Server", "type": "GET", "rowGet": {"key": "Name", "param": "name", "fields": ["IssuerEndpoint"], "derived": []}}, "expected": "read.source.rowGet is declared on a GET source, which reads one object and has no rows to issue a detail call for (AD-36)"},
    {"name": "a GET with a parent list", "source": {"port": "admin", "endpoint": "Security.OAuth2.Server", "type": "GET", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": []}}, "expected": "read.source.forEach is declared on a GET source, which reads one object and lists no parents (AD-36)"},
    {"name": "a GET with server criteria", "source": {"port": "admin", "endpoint": "Security.OAuth2.Server", "type": "GET"}, "criteria": {"fields": [{"param": "serverId", "labelKey": "tableColumnName", "kind": "text", "maxLength": 64}]}, "expected": "read.criteria is declared on a GET source, whose one object takes no server search (AD-36)"},
    {"name": "an array is not a parent list", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": []}, "expected": "read.source.forEach is not an object declaring its endpoint, key, param and fields (AD-36)"},
    {"name": "an endpoint name alone is not a parent list", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": "Security.OAuth2.Client.ServerDefinition"}, "expected": "read.source.forEach is not an object declaring its endpoint, key, param and fields (AD-36)"},
    {"name": "a parent list with an unknown key", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": [], "maxRows": 5}}, "expected": "read.source.forEach declares the unknown key 'maxRows'"},
    {"name": "a parent list on the management port", "source": {"port": "mgmnt", "endpoint": "Applications", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": []}}, "expected": "read.source.forEach is declared on a 'mgmnt' source, and a per-parent list issues admin endpoints (AD-36)"},
    {"name": "a parent list on a state source", "source": {"port": "state", "endpoint": "Agent", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": []}}, "expected": "read.source.forEach is declared on a 'state' source, and a per-parent list issues admin endpoints (AD-36)"},
    {"name": "a parent list beside a detail call", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "rowGet": {"key": "Name", "param": "name", "fields": ["IssuerEndpoint"], "derived": []}, "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": []}}, "expected": "read.source.forEach is declared with read.source.rowGet, and a per-parent list copies its parent's fields rather than a detail call's (AD-36)"},
    {"name": "a parent list beside server criteria", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": []}}, "criteria": {"fields": [{"param": "applicationName", "labelKey": "tableColumnName", "kind": "text", "maxLength": 64}]}, "expected": "read.source.forEach is declared with read.criteria, and a per-parent list sets its one parameter from each parent (AD-36)"},
    {"name": "a parent endpoint that is not a package-relative name", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security/OAuth2", "key": "ID", "param": "serverId", "fields": []}}, "expected": "read.source.forEach.endpoint 'Security/OAuth2' is not a package-relative endpoint name"},
    {"name": "a missing parent endpoint", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"key": "ID", "param": "serverId", "fields": []}}, "expected": "read.source.forEach.endpoint '' is not a package-relative endpoint name"},
    {"name": "an empty key", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "", "param": "serverId", "fields": []}}, "expected": "read.source.forEach.key is empty, and a per-parent list reads each parent's key by name"},
    {"name": "a missing key", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "param": "serverId", "fields": []}}, "expected": "read.source.forEach.key is empty, and a per-parent list reads each parent's key by name"},
    {"name": "a param that is not a name", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "server-id", "fields": []}}, "expected": "read.source.forEach.param 'server-id' is not a query parameter name"},
    {"name": "fields that are not an array", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": "ID"}}, "expected": "read.source.forEach.fields is not an array of parent fields"},
    {"name": "a fields entry that is not an object", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": ["ServerDefinitionID"]}}, "expected": "read.source.forEach.fields entry #1 is not an object declaring its field and from"},
    {"name": "a fields entry with an unknown key", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": [{"field": "ServerDefinitionID", "from": "ID", "type": "number"}]}}, "expected": "read.source.forEach.fields entry #1 declares the unknown key 'type'"},
    {"name": "a field outside the read's fields", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": [{"field": "ID", "from": "ID"}]}}, "expected": "read.source.forEach.fields entry #1 field 'ID' is not one of read.fields"},
    {"name": "a repeated field", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": [{"field": "IssuerEndpoint", "from": "IssuerEndpoint"}, {"field": "IssuerEndpoint", "from": "ID"}]}}, "expected": "read.source.forEach.fields entry #2 names the field 'IssuerEndpoint' twice"},
    {"name": "an empty from", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": [{"field": "ServerDefinitionID", "from": ""}]}}, "expected": "read.source.forEach.fields entry #1 from is empty, and a parent field is copied from a named key of the parent"},
    {"name": "a missing from", "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ClientConfiguration", "type": "LIST", "forEach": {"endpoint": "Security.OAuth2.Client.ServerDefinition", "key": "ID", "param": "serverId", "fields": [{"field": "ServerDefinitionID"}]}}, "expected": "read.source.forEach.fields entry #1 from is empty, and a parent field is copied from a named key of the parent"}
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

/// <p>The corpus declaration with <var>pCase</var>'s <code>source</code> in place, and its
/// <code>criteria</code> when it carries one, as a new object.</p>
ClassMethod DeclarationFor(pCorpus As %DynamicObject, pCase As %DynamicObject) As %DynamicObject
{
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(pCorpus.declaration.%ToJSON())
    Do tDeclaration.read.%Set("source", ##class(%DynamicObject).%FromJSON(pCase.source.%ToJSON()))
    If pCase.%GetTypeOf("criteria") = "object" Do tDeclaration.read.%Set("criteria", ##class(%DynamicObject).%FromJSON(pCase.criteria.%ToJSON()))
    Quit tDeclaration
}

}
